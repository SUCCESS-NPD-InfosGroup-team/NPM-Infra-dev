# Observaciones al PR `feature/postgres-flyway`

Commit revisado: `25f8a2d` — *Add Flyway migrations and initial planner data model* (`db/migration/V1__create_catalogs.sql`, `db/migration/V2__create_resource.sql`, `README.md`, `docker-compose.yaml`).

**Estado: cambios solicitados.** La configuración de Flyway en `docker-compose.yaml` está bien y se mantiene. Lo que hay que rehacer es el modelo de datos.

Documentos de referencia, en la raíz del proyecto:

- [`DIAGRAMA_BD.md`](DIAGRAMA_BD.md): modelo objetivo (diagramas ER y decisiones).
- [`inconsistencias-excel.md`](inconsistencias-excel.md): problemas del Excel y reglas de migración que el modelo tiene que soportar.
- Mockups de Figma `NPD-InfosGroup`, páginas *NPD · Pantallas*, *NPD · Estados* y *NPD · Fase 2*.

Como las migraciones todavía no se han aplicado en ningún entorno compartido, se pueden **reescribir V1 y V2** en lugar de agregar una V3.

## Qué se mantiene

- El servicio `flyway` en `docker-compose.yaml` y `SPRING_FLYWAY_LOCATIONS` apuntando a `db/migration`.
- La función `set_updated_at()` y los triggers `BEFORE UPDATE`.
- Los nombres únicos sin distinguir mayúsculas (`lower(name)`) en los catálogos abiertos.
- Los catálogos `business_unit`, `gender`, `equipment_provider`, `work_modality`, `client_role`, `job_title`, `job_position` y `client`.
- `project` con `client_id` y nombre único por cliente.

## Qué hay que cambiar

### 1. `resource` se divide en `employee` + `assignment`

`resource` mezcla datos de la persona con datos de su asignación. Un recurso es el resultado de unir el empleado con su asignación y los catálogos. Se reemplaza por:

- **`employee`**: los datos de la persona (maestro de RR. HH.).
- **`assignment`**: un empleado en un proyecto.
- **Vista `resource_v`**: reproduce las 22 columnas del planificador para Roster, Tabla y exportación. Son unas 160 filas unidas por llave primaria, así que no hace falta desnormalizar. Si algún día se mide que es lenta, se pasa a vista materializada.

| Columna actual en `resource` | Va a |
|---|---|
| `employee_code`, `full_name`, `email`, `gender_id`, `start_date` (→ `hire_date`), `job_title_id`, `job_position_id`, `level`, `business_unit_id`, `work_modality_id`, `status_id` | `employee` |
| `project_id`, `leader_id`, `client_role_id`, `client_contact_email`, `project_end_date` (→ `end_date`), `equipment_provider_id` | `assignment` |
| `client_id` | Se elimina: el cliente sale de `project`. Ya no hacen falta `resource_project_fk` compuesta, `UNIQUE (id, client_id)` en `project` ni `resource_project_needs_client`. |
| `probation_month`, `vacation_month` | Se eliminan como columnas editables. Se calculan a partir de `hire_date`: probatoria = `hire_date + 90` (fecha exacta, no mes; el `CHECK` de día 1 rompe con datos reales) y vacaciones = mes 11 desde la contratación. |
| `project_end_month` | Se calcula a partir de `assignment.end_date`. |

### 2. Se elimina `npd_leader`

El líder NPD **es un empleado** y comparte el código. `assignment.leader_id` apunta a `employee`. Una tabla aparte duplica nombre y código, y en el Excel ya están cruzados (ver sección 4 de `inconsistencias-excel.md`).

### 3. `employee.code` es texto, con id interno

`employee_code integer NOT NULL UNIQUE` rechaza los códigos `SP11` y `T001`–`T008` que trae el Excel. Hay que usar `id bigint` como llave primaria y `code varchar(20) UNIQUE`. Así un código temporal se reemplaza por el definitivo sin tocar ninguna llave foránea.

### 4. Datos que todavía no tenemos: columnas que aceptan vacío

El nombre, la fecha de inicio y el género vienen de otro libro (`#REF!` en el Excel, sin valores en caché). `employee.full_name` y `employee.hire_date` tienen que aceptar NULL hasta tener el maestro de empleados. El correo es la llave para emparejar empleados entre cargas: `UNIQUE (lower(email))`, y una fila sin correo no se migra.

### 5. `assignment` permite historial

- Relación 1:N con `employee`, con un índice único parcial `(employee_id) WHERE is_current` (una asignación vigente por persona).
- `project_id` acepta NULL: es el caso "sin proyecto".
- `start_date` (inicio de la asignación, lo muestra el roster) y `end_date` (NULL = INDEFINIDO).
- `leader_id` acepta NULL a nivel de base de datos, porque la migración deja sin líder las filas de Maribel Escala (código `1`). La aplicación lo exige al registrar.

### 6. Estados y "SIN PROYECTO"

- "SIN PROYECTO" **no es cliente ni proyecto**: es una asignación con `project_id NULL` y el estado `Activo-Sin proyecto`.
- `resource_status` (en `employee`) arranca con: `ACTIVO_ASIGNADO` "Activo-Proyecto Asignado", `ACTIVO_SIN_PROYECTO` "Activo-Sin proyecto", `LICENCIA` "Licencia" y `BAJA` "Baja".
- `client.is_internal` marca a `NPD-ADMINISTRACION`, que sí es cliente.

### 7. Campos que piden los mockups

- `project.contract_end_date`: el aviso "Fin de contrato de cliente" es por proyecto.
- `employee.termination_date`: para las bajas del reporte mensual.
- `version integer` en `employee` y `assignment`: bloqueo optimista para la pantalla "Editar recurso · Conflicto de edición".
- Columnas de autoría (`created_by` / `updated_by`) o un `audit_log`: cada cambio queda en la auditoría con usuario, fecha, valor anterior y valor nuevo.

Los módulos de soporte (`app_user`, `app_role`, `audit_log`, `history_entry`, `vacation`, `notification_rule`, `notification_log`) están en la sección 2 de `DIAGRAMA_BD.md`. Pueden ir en migraciones posteriores, pero el núcleo tiene que quedar listo para recibirlos (sobre todo `employee.id` como destino de las llaves foráneas).

### 8. Restricciones que hay que revisar

- `CHECK (level > 0)`: está bien, pero el Excel trae `*` en 71 filas. La migración debe convertirlo a NULL (no es un problema del esquema).
- `UNIQUE (lower(email))` sobre un correo que acepta NULL: está bien en Postgres (permite varios NULL). Se traslada a `employee`.
- `status_id NOT NULL`: se mantiene en `employee`, con valor por defecto `ACTIVO_ASIGNADO` o asignado explícitamente por la migración.

### 9. README

Hay que actualizar la tabla *Initial data model* (columna del planificador → dónde se guarda) con el nuevo destino de cada columna, y aclarar que probatoria, vacaciones y mes final son columnas calculadas.

## Checklist para el PR corregido

- [ ] `V1`: catálogos y `resource_status` con sus valores iniciales. Se quitan `npd_leader` y el `UNIQUE (id, client_id)` de `project`. Se agregan `client.is_internal` y `project.contract_end_date`.
- [ ] `V2`: `employee` (id + `code` de texto, `hire_date`, probatoria y vacaciones calculadas, `termination_date`, `version`).
- [ ] `V2`: `assignment` (1:N, índice único parcial de la vigente, `project_id` y `leader_id` que aceptan vacío, `start_date`, `end_date`, `version`).
- [ ] `V2`: vista `resource_v` con las 22 columnas del planificador.
- [ ] README actualizado.
- [ ] `docker compose down -v && docker compose up` aplica las migraciones sin errores.
