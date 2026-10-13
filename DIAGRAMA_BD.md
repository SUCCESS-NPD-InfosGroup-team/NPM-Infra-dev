# Diagrama relacional de la base de datos (propuesta)

Modelo propuesto como corrección al PR `feature/postgres-flyway` (`V1__create_catalogs.sql`, `V2__create_resource.sql`). Se basa en:

- La hoja `PLANIFICADOR` del Excel `PLANIFICACION DE RECURSOS NPD__Operaciones.xlsx`. Sus problemas y cómo se resolvieron están en [`inconsistencias-excel.md`](inconsistencias-excel.md).
- Los mockups de Figma `NPD-InfosGroup` (Recursos, Registrar recurso, Historial, Auditoría, Vacaciones, Avisos, Usuarios y Tablero).

Idea central: separar **lo que es del empleado** (`employee`) de **lo que es de su asignación** a un proyecto (`assignment`). La fila del planificador ("recurso") la arma la vista `resource_v`. La aplicación es la fuente de verdad; los Excel posteriores son exportaciones.

## 1. Núcleo: planificador

```mermaid
erDiagram
    employee {
        bigint id PK
        varchar(20) code UK "COD EMPL / COD LIDER (admite T001, SP11)"
        varchar(150) full_name "NOMBRE (NULL hasta tener el maestro)"
        varchar(254) email UK "CORREO RECURSO; llave para emparejar"
        smallint gender_id FK "GENERO"
        bigint job_title_id FK "PUESTO"
        bigint job_position_id FK "POSICION"
        smallint level "NIVEL"
        smallint business_unit_id FK "UEN"
        smallint work_modality_id FK "MODALIDAD LABORAL"
        date hire_date "FECHA DE INICIO"
        date probation_end_date "generada: hire_date + 90"
        smallint vacation_month "generada: mes 11 desde hire_date"
        date termination_date "baja (reporte mensual)"
        smallint status_id FK "ESTADO"
        integer version "bloqueo optimista"
        timestamptz created_at
        timestamptz updated_at
    }
    assignment {
        bigint id PK
        bigint employee_id FK "recurso"
        bigint project_id FK "PROYECTO; NULL = sin proyecto"
        bigint leader_id FK "LIDER NPD (es un employee)"
        bigint client_role_id FK "ROL ACTUAL EN CLIENTE"
        varchar(254) client_contact_email "CONTACTO POR CLIENTE (por persona)"
        date start_date "inicio de la asignacion"
        date end_date "FECHA FINAL; NULL = INDEFINIDO"
        smallint equipment_provider_id FK "EQUIPO / LAPTOP"
        boolean is_current "una vigente por empleado"
        integer version "bloqueo optimista"
        timestamptz created_at
        timestamptz updated_at
    }
    client {
        bigint id PK
        varchar(150) name UK "CLIENTE"
        boolean is_internal "NPD-ADMINISTRACION"
    }
    project {
        bigint id PK
        bigint client_id FK
        varchar(150) name "unico por cliente"
        date contract_end_date "fin de contrato con el cliente (aviso a Sales)"
    }
    resource_status {
        smallint id PK
        varchar code UK
        varchar name
    }
    gender {
        smallint id PK
        varchar code UK
        varchar name
    }
    job_title {
        bigint id PK
        varchar name UK
    }
    job_position {
        bigint id PK
        varchar name UK
    }
    business_unit {
        smallint id PK
        varchar code UK
        varchar name
    }
    work_modality {
        smallint id PK
        varchar code UK
        varchar name
    }
    client_role {
        bigint id PK
        varchar name UK
    }
    equipment_provider {
        smallint id PK
        varchar code UK
        varchar name
    }

    client             ||--o{ project    : "tiene"
    project            |o--o{ assignment : "tiene muchos empleados"
    employee           ||--o{ assignment : "es asignado"
    employee           |o--o{ assignment : "lidera"
    resource_status    ||--o{ employee   : "estado"
    gender             |o--o{ employee   : "genero"
    job_title          |o--o{ employee   : "puesto"
    job_position       |o--o{ employee   : "posicion"
    business_unit      |o--o{ employee   : "UEN"
    work_modality      |o--o{ employee   : "modalidad"
    client_role        |o--o{ assignment : "rol"
    equipment_provider |o--o{ assignment : "laptop"
```

## 2. Módulos de soporte (según los mockups)

```mermaid
erDiagram
    app_user {
        bigint id PK
        varchar(254) email UK
        varchar(150) full_name
        smallint role_id FK
        bigint employee_id FK "NPD Lead: ve solo a su equipo"
        boolean active
        timestamptz last_login_at
    }
    app_role {
        smallint id PK
        varchar code UK "OPS_ADMIN, NPD_LEAD, CUSTOMER_SUCCESS, GUEST"
        varchar name
    }
    audit_log {
        bigint id PK
        varchar entity "employee, assignment, ..."
        bigint entity_id
        varchar action "CREATE, UPDATE, EXPORT, VIEW_RESTRICTED"
        varchar field
        text old_value
        text new_value
        jsonb detail "p. ej. filtros de la exportacion"
        bigint user_id FK
        timestamptz created_at
    }
    history_entry {
        bigint id PK
        bigint employee_id FK
        varchar type "EVALUATION, RECOGNITION, INCIDENT, ROLE_CHANGE"
        date event_date
        varchar title
        date period_from
        date period_to
        varchar talent_review "provisional (Q23)"
        smallint rating "1-5, provisional (Q23)"
        varchar severity "solo incidentes"
        text comment
        boolean restricted "incidentes: cada consulta se audita"
        bigint created_by FK
        timestamptz created_at
    }
    vacation {
        bigint id PK
        bigint employee_id FK
        date start_date
        date end_date
        boolean confirmed "confirmado por el colaborador"
        bigint created_by FK
        timestamptz created_at
    }
    notification_rule {
        smallint id PK
        varchar type "FIN_CONTRATO, FIN_PROBATORIA, FIN_ASIGNACION, RESUMEN_VACACIONES"
        smallint_array days_before "p. ej. 30 y 15"
        jsonb recipients "roles y correos (Para / CC)"
        varchar subject
        text body "plantilla con marcadores"
        bigint updated_by FK
        timestamptz updated_at
    }
    notification_log {
        bigint id PK
        smallint rule_id FK
        varchar entity
        bigint entity_id
        date due_date
        timestamptz sent_at
        jsonb recipients
    }

    app_role          ||--o{ app_user          : "rol"
    employee          |o--o| app_user          : "cuenta"
    app_user          ||--o{ audit_log         : "autor"
    employee          ||--o{ history_entry     : "historial"
    app_user          ||--o{ history_entry     : "registra"
    employee          ||--o{ vacation          : "vacaciones"
    app_user          ||--o{ vacation          : "registra"
    notification_rule ||--o{ notification_log  : "envios"
    app_user          |o--o{ notification_rule : "edita"
```

## Decisiones

- **`employee`**: id interno + `code` de texto único. Los códigos temporales (`T001`, `SP11`) entran sin romper nada y, cuando reciban el definitivo, se actualiza `code` sin tocar ninguna FK. El emparejamiento entre cargas se hace por `email`.
- **El líder NPD es un `employee`** (`assignment.leader_id`). Se elimina `npd_leader`. Regla de migración: manda COD LIDER.
- **`assignment` es 1:N con `employee`**, con un índice único parcial `(employee_id) WHERE is_current`. Hoy hay una asignación vigente por persona; el historial ("Cambio de rol", "Raúl Batista: baja", roster "desde nov 2024") queda guardado sin migrar el esquema.
- **Sin `client_id` en `assignment`**: el cliente sale de `project`. Sin proyecto = `project_id NULL` y estado "Activo-Sin proyecto".
- **Por persona (en `assignment`)**: fecha final, rol, contacto y laptop. En el Excel cambian entre personas del mismo proyecto.
- **`hire_date` (contratación) y `assignment.start_date` son fechas distintas.** Ninguna está en el Excel actual; la primera se deduce de la columna FECHA DE INICIO (ver `inconsistencias-excel.md`). Nivel, UEN, modalidad y estado son del empleado (confirmado).
- **Probatoria y vacaciones se calculan** a partir de `hire_date`, según el Código de Trabajo de Panamá (prueba de hasta 3 meses; vacaciones tras 11 meses de trabajo). Las vacaciones que se toman de verdad van en `vacation`.
- **`version`** en `employee` y `assignment` sirve para el bloqueo optimista de la pantalla "Editar recurso · Conflicto de edición".
- **`audit_log`** guarda un cambio por campo (valor anterior → nuevo), las exportaciones con sus filtros y las consultas a información restringida.
- **`resource_status`** (catálogo inicial): `ACTIVO_ASIGNADO` "Activo-Proyecto Asignado", `ACTIVO_SIN_PROYECTO` "Activo-Sin proyecto", `LICENCIA` "Licencia", `BAJA` "Baja".
- **`resource_v`** (vista) reproduce las 22 columnas del planificador para Roster, Tabla y exportación. Si se mide que es lenta, se pasa a vista materializada sin cambiar las tablas.
- **Fase 3 (fuera de este modelo)**: riesgo de rotación (IA) e integración con Infosweb.
