# Inconsistencias del Excel

Fuente: `PLANIFICACION DE RECURSOS NPD__Operaciones.xlsx`, hoja `PLANIFICADOR` (encabezados en la fila 4, 161 filas de datos: filas 5–165).

Estas inconsistencias se tomaron en cuenta para el modelado (ver `DIAGRAMA_BD.md`) y para las reglas de la **migración**: la carga única que hacen los desarrolladores con un componente dedicado. No confundir con la **importación** que hará el usuario desde la aplicación, que es más sensible a errores y tendrá sus propias validaciones.

Reglas generales de la migración:

- La aplicación es la fuente de verdad. Los Excel posteriores son exportaciones de la aplicación; un cambio hecho en un Excel solo es legítimo si se pasa a la aplicación.
- Un empleado se empareja por **correo**. Si una fila no tiene correo válido, **no se migra** y se reporta con el motivo.
- Las columnas que se calculan (nombre, fecha de inicio y género del maestro de empleados, probatoria, vacaciones y mes final) no se toman tal cual del Excel: se recalculan o se dejan vacías hasta tener la fuente.

## 1. Datos que vienen de otro libro (`#REF!`)

| Columna | Fórmula | Filas | Decisión |
|---|---|---|---|
| NOMBRE DE EMPLEADO | `=VLOOKUP($E, #REF!, 2, 0)` | 157 (las filas 31, 113, 117 y 165 tienen el nombre escrito a mano) | Va en `employee.full_name`. El Excel no guarda valores en caché (todos dan `#REF!`), así que solo se migran los 3 nombres escritos a mano de filas válidas. `full_name` queda NULL hasta tener el maestro de empleados (DATA_INFOSWEB). Los líderes toman su nombre de LIDER NPD. |
| FECHA DE INICIO | `=VLOOKUP($E, #REF!, 4, 0)` | 161 | Va en `employee.hire_date`. Queda NULL hasta tener el maestro (el valor en caché también es `#REF!`). |
| GENERO | `=VLOOKUP($E, #REF!, 8, 0)` | 160 | Va en `employee.gender_id`. Queda NULL hasta tener el maestro. |

### FECHA DE INICIO = fecha de contratación (deducido, no confirmado)

La fecha de contratación **no está en el Excel actual**. La columna FECHA DE INICIO es una fórmula que da `#REF!` y no guarda ningún valor en caché. Se modela como `employee.hire_date` (fecha de contratación) y no como inicio de la asignación por tres indicios:

1. Se busca con `VLOOKUP` por COD EMPL en el mismo libro externo que el nombre (columna 2) y el género (columna 8). Es decir, sale del maestro de empleados, no de la asignación.
2. MES DE PROBATORIA = FECHA DE INICIO + 90. El período de prueba corre desde la contratación (Código de Trabajo de Panamá), no desde que la persona entra a un proyecto.
3. MES DE VACACIONES se calcula del mismo dato, y las vacaciones también dependen de la antigüedad.

El nombre de la columna no dice "contratación". Hay que confirmarlo cuando llegue el maestro de empleados. El inicio de cada asignación (el que muestra el roster de los mockups) es otro dato: `assignment.start_date`, que tampoco está en el Excel. En la migración se deja NULL o igual a `hire_date` cuando se tenga.

El encabezado de la hoja dice `DATA_INFOSWEB`: el libro de origen parece ser la exportación de Infosweb, el módulo "En desarrollo" de los mockups.

## 2. Columnas calculadas

| Columna | Fórmula | Problema | Decisión |
|---|---|---|---|
| MES DE PROBATORIA | `=FECHA_INICIO + 90` | Es una fecha exacta (día 90), no un mes. El Código de Trabajo de Panamá habla de un período de prueba de hasta 3 meses. | Se calcula: `employee.probation_end_date = hire_date + 90`. No se migra. |
| MES DE VACACIONES | `CHOOSE(MONTH(FECHA_INICIO), "DIC", "ENE", …)` | Es el mes anterior al aniversario, a los 11 meses (30 días de vacaciones por cada 11 meses trabajados). La fila 165 no tiene la fórmula. | Se calcula a partir de `hire_date`. No se migra. Las vacaciones reales se registran en `vacation`. |
| MES FINAL DE PROYECTO | Texto escrito a mano | No coincide con FECHA FINAL en las filas 124 (31/12/2026 → "MARZO 2026"), 130 (31/12/2026 → "MARZO 2026"), 139 (31/12/2026 → "AGOSTO 2026") y 147 (31/10/2026 → "MARZO 2026"). | Se calcula a partir de `assignment.end_date`. Manda FECHA FINAL. |

## 3. Códigos de empleado

| Inconsistencia | Filas | Decisión |
|---|---|---|
| Códigos que no son números: `SP11`, `T001`–`T008` (ingresos sin código definitivo). | SP11 y T001–T008 | `employee.code` es texto. Cuando reciban el código definitivo se actualiza `code` (el id interno no cambia). |
| T006 y T008 tienen correo `-`. | 162, 164 | **No se migran** (no hay correo para emparejar). Se reportan. |
| Rosemary Carrasco no tiene COD EMPL, ni correo, ni casi ninguna columna. | 165 | **No se migra.** Se reporta. |

## 4. Líder NPD (nombre y código cruzados)

Regla: **manda COD LIDER**. El nombre del líder sale del empleado con ese código.

| Inconsistencia | Filas | Decisión |
|---|---|---|
| DAYANA ALCOCER aparece con el código 1005, que es de ERIKA ESCALA (12 filas). Dayana es la 1027 (16 filas). | 134 (emp. 1022, MERCANTIL) | Líder = 1005 (Erika Escala). Coincide con que Erika lleva MERCANTIL. |
| JORGE RUIZ aparece con el código 759, que es de KATHIA BERMUDEZ (9 filas). Jorge es el 798 (7 filas). | 143 (emp. 1036, COPA AIRLINES-COMERCIAL) | Líder = 759 (Kathia Bermudez), por la regla. Ojo: Jorge sí lleva COMERCIAL con el 798 y Kathia no, así que puede que aquí el error esté en el código. Revisar en la aplicación tras migrar. |
| GEORGINA RANGEL aparece sin código (por nombre sería el 755). | 165 | La fila no se migra (ver sección 3). |
| MARIBEL ESCALA tiene el código `1`, que parece un valor de relleno, y no existe como empleado. | 5 (emp. 34), 137 (emp. 1028) | Se descarta como líder: las asignaciones se migran **sin líder** y se reportan para asignarlo en la aplicación. |
| 731 (VANESSA GILL) no está como empleado en el planificador. Es líder de 631 (Jahzeelys Rangel). En CONTACTO POR CLIENTE aparece como `vanessa.gil@` (una sola L). | 28 | Se crea `employee` 731 con el nombre de LIDER NPD y sin más datos. |
| Los líderes son a su vez recursos con líder: casi todos los líderes tienen a 631 como líder, y 631 tiene a 731. | — | Se modela como `assignment.leader_id → employee`. No se modela jerarquía aparte. |

## 5. Contacto por cliente

El contacto es **por persona** (va en `assignment.client_contact_email`), pero hay contactos de un cliente puestos en otro:

| Fila | Emp. | Cliente | Contacto |
|---|---|---|---|
| 6 | 72 | SIN PROYECTO | mmedina@**banesco**.com |
| 40 | 762 | CAJA DE AHORROS | dayana.alcocer@**bancoaliado**.com |
| 65 | 856 | SURA | derivera@**copaair**.com |
| 68 | 950 | BANESCO | derivera@**copaair**.com |
| 79 | 892 | TIGO | derivera@**copaair**.com |
| 127 | 1012 | NPD-ADMINISTRACION | yadaleth.mela@**tigo**.com.pa |
| 156 | — | PALIG | jahzeelys.rangel@**infosgroup**.com |

Decisión: se migran tal cual (es texto libre) y se reportan para corregirlos en la aplicación. En NPD-ADMINISTRACION y TRIBUNAL ELECTORAL el contacto es un correo `@infosgroup.com`, lo cual es coherente con un cliente interno.

## 6. Valores de relleno en vez de vacío

| Valor | Columna | Filas | Decisión |
|---|---|---|---|
| `*` | PUESTO | 57 | NULL. Se muestra como "No especificado". |
| `*` | ROL ACTUAL EN CLIENTE | 45 | NULL. |
| `*` | NIVEL | 71 | NULL. |
| `-` | CONTACTO POR CLIENTE | 16 | NULL. |
| `-` | CORREO RECURSO | 2 (T006, T008) | La fila no se migra (sección 3). |
| `-` | MODALIDAD LABORAL | 2 (filas 137, 145) | NULL. |
| `INDEFINIDO` | FECHA FINAL PROYECTO | 7 | `end_date` NULL. |

## 7. Catálogos sucios

| Catálogo | Problema | Decisión |
|---|---|---|
| Cliente | `MERCANTIL` (fila 134) y `BANCO MERCANTIL` (4 filas) son el mismo cliente; el proyecto MERCANTIL cuelga de los dos. | Mapeo fijo en la migración: `MERCANTIL` → `BANCO MERCANTIL`. |
| Cliente/Proyecto | `SIN PROYECTO` aparece como cliente y proyecto (filas 6 y 93), con estado "Activo-Proyecto Asignado". | No es cliente ni proyecto: asignación con `project_id = NULL` y estado "Activo-Sin proyecto". Ojo: el Tablero del mockup lo cuenta como "cliente interno". |
| Cliente | `NPD-ADMINISTRACION` | Es cliente real, marcado como interno (`client.is_internal`). |
| Posición | 39 valores para 15 puestos, con errores: `SISTENAS`, `ADIMINISTRADOR`, `JR`/`JR.`, `PRUEBA`/`PRUEBAS`, `NEGOCIO`/`NEGOCIOS`, `SR`/`SR.`. | Tabla de normalización en la migración (valor original → valor canónico). |
| Modalidad | `PESENCIAL - L/S` (32), `HIBRIDO . 1 AL MES` (3). | Normalizar a `PRESENCIAL - L/S` e `HIBRIDO - 1 AL MES`. |
| Rol en cliente | `NPD-ADMNISTRACION` (fila 28). | Normalizar a `NPD-ADMINISTRACION`. |
| Estado | Un solo valor: `Activo-Proyecto Asignado ` (con espacio al final), incluso en las filas SIN PROYECTO. | Catálogo con los estados probables (ver diagrama). Las filas SIN PROYECTO pasan a "Activo-Sin proyecto". |
| Texto en general | Espacios al inicio o al final (`SIN PROYECTO `, `JAHZEELYS RANGEL `, `ERIKA ESCALA `) y mayúsculas mezcladas. | `trim` y comparación sin distinguir mayúsculas al migrar. |
