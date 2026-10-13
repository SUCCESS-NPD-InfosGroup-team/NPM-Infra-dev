-- A planner row ("resource") is an employee plus one of their assignments.
-- employee holds what belongs to the person, assignment what belongs to their
-- work on a project. An employee can have several active assignments at once.
-- resource_v rebuilds the 22 planner columns from both.

CREATE TABLE employee (
    id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- Text so temporary codes (T001, SP11) fit; replacing one with the final
    -- code touches no foreign key
    code               varchar(20)  NOT NULL UNIQUE,
    -- Name, hire date and gender come from the HR master (Infosweb) and stay
    -- empty until it is available
    full_name          varchar(150),
    email              varchar(254) NOT NULL,
    gender_id          smallint     REFERENCES gender (id),
    job_title_id       bigint       REFERENCES job_title (id),
    job_position_id    bigint       REFERENCES job_position (id),
    level              smallint     CHECK (level > 0),
    business_unit_id   smallint     REFERENCES business_unit (id),
    work_modality_id   smallint     REFERENCES work_modality (id),
    hire_date          date,
    probation_end_date date GENERATED ALWAYS AS (hire_date + 90) STORED,
    vacation_month     smallint GENERATED ALWAYS AS
                           (extract(month FROM hire_date + interval '11 months')::smallint) STORED,
    termination_date   date,
    status_id          smallint     NOT NULL REFERENCES resource_status (id),
    version            integer      NOT NULL DEFAULT 0,
    created_at         timestamptz  NOT NULL DEFAULT now(),
    updated_at         timestamptz  NOT NULL DEFAULT now(),

    CONSTRAINT employee_termination_after_hire CHECK (termination_date >= hire_date)
);

-- Email is the key that matches an employee across loads
CREATE UNIQUE INDEX employee_email_uk ON employee (lower(email));
CREATE INDEX employee_status_idx ON employee (status_id);
CREATE INDEX employee_probation_end_idx ON employee (probation_end_date);

CREATE TRIGGER employee_set_updated_at BEFORE UPDATE ON employee
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE employee IS 'NPD collaborator: the person, independent of their assignments';
COMMENT ON COLUMN employee.code IS 'COD EMPL / COD LIDER';
COMMENT ON COLUMN employee.full_name IS 'NOMBRE DE EMPLEADO';
COMMENT ON COLUMN employee.email IS 'CORREO RECURSO';
COMMENT ON COLUMN employee.gender_id IS 'GENERO';
COMMENT ON COLUMN employee.job_title_id IS 'PUESTO';
COMMENT ON COLUMN employee.job_position_id IS 'POSICIÓN';
COMMENT ON COLUMN employee.level IS 'NIVEL';
COMMENT ON COLUMN employee.business_unit_id IS 'UEN';
COMMENT ON COLUMN employee.work_modality_id IS 'MODALIDAD LABORAL DEL RECURSO';
COMMENT ON COLUMN employee.hire_date IS 'FECHA DE INICIO: hire date at Infosgroup';
COMMENT ON COLUMN employee.probation_end_date IS 'MES DE PROBATORIA: day 90 after hire_date, weekends included';
COMMENT ON COLUMN employee.vacation_month IS 'MES DE VACACIONES: month (1-12) when 11 months since hire_date are completed';
COMMENT ON COLUMN employee.termination_date IS 'Departure date';
COMMENT ON COLUMN employee.status_id IS 'ESTADO: employment status';
COMMENT ON COLUMN employee.version IS 'Optimistic locking for concurrent edits';

CREATE TABLE assignment (
    id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id           bigint       NOT NULL REFERENCES employee (id),
    -- NULL = without project
    project_id            bigint       REFERENCES project (id),
    -- The NPD lead is an employee too
    leader_id             bigint       REFERENCES employee (id),
    client_role_id        bigint       REFERENCES client_role (id),
    equipment_provider_id smallint     REFERENCES equipment_provider (id),
    client_contact_email  varchar(254),
    start_date            date,
    -- NULL = INDEFINIDO
    end_date              date,
    -- Stays true after end_date passes until someone confirms the extension
    -- or closes the assignment; meanwhile it reads as pending confirmation
    is_active             boolean      NOT NULL DEFAULT true,
    version               integer      NOT NULL DEFAULT 0,
    created_at            timestamptz  NOT NULL DEFAULT now(),
    updated_at            timestamptz  NOT NULL DEFAULT now(),

    CONSTRAINT assignment_end_after_start CHECK (end_date >= start_date),
    CONSTRAINT assignment_not_own_leader CHECK (leader_id <> employee_id)
);

CREATE INDEX assignment_employee_active_idx ON assignment (employee_id) WHERE is_active;
CREATE INDEX assignment_project_idx ON assignment (project_id);
CREATE INDEX assignment_leader_idx ON assignment (leader_id);
CREATE INDEX assignment_end_date_idx ON assignment (end_date);

CREATE TRIGGER assignment_set_updated_at BEFORE UPDATE ON assignment
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE assignment IS 'An employee working on a project. Closed assignments are kept as history';
COMMENT ON COLUMN assignment.project_id IS 'PROYECTO ASIGNADO (its client is CLIENTE); NULL = without project';
COMMENT ON COLUMN assignment.leader_id IS 'LIDER NPD + COD LIDER';
COMMENT ON COLUMN assignment.client_role_id IS 'ROL ACTUAL EN CLIENTE';
COMMENT ON COLUMN assignment.equipment_provider_id IS 'EQUIPO / LAPTOP';
COMMENT ON COLUMN assignment.client_contact_email IS 'CONTACTO POR CLIENTE';
COMMENT ON COLUMN assignment.start_date IS 'Start on this project';
COMMENT ON COLUMN assignment.end_date IS 'FECHA FINAL PROYECTO; NULL = INDEFINIDO';
COMMENT ON COLUMN assignment.version IS 'Optimistic locking for concurrent edits';

-- The planner as the client knows it: one row per active assignment, plus one
-- row for each employee with no active assignment.
CREATE VIEW resource_v AS
SELECT e.id                    AS employee_id,
       a.id                    AS assignment_id,
       c.name                  AS client,
       p.name                  AS project,
       l.full_name             AS npd_leader,
       l.code                  AS leader_code,
       e.code                  AS employee_code,
       e.full_name,
       jt.name                 AS job_title,
       jp.name                 AS job_position,
       cr.name                 AS client_role,
       e.level,
       e.hire_date,
       bu.code                 AS business_unit,
       g.name                  AS gender,
       ep.name                 AS equipment_provider,
       e.probation_end_date,
       e.vacation_month,
       a.start_date            AS assignment_start_date,
       a.end_date              AS project_end_date,
       date_trunc('month', a.end_date::timestamp)::date AS project_end_month,
       rs.code                 AS employment_status_code,
       rs.name                 AS employment_status,
       CASE
           WHEN a.project_id IS NULL                      THEN 'SIN_PROYECTO'
           WHEN a.end_date < current_date                 THEN 'PENDIENTE_CONFIRMACION'
           ELSE 'ASIGNADO'
       END                     AS assignment_situation,
       e.email,
       a.client_contact_email,
       wm.name                 AS work_modality
FROM employee e
JOIN resource_status rs           ON rs.id = e.status_id
LEFT JOIN assignment a            ON a.employee_id = e.id AND a.is_active
LEFT JOIN project p               ON p.id = a.project_id
LEFT JOIN client c                ON c.id = p.client_id
LEFT JOIN employee l              ON l.id = a.leader_id
LEFT JOIN job_title jt            ON jt.id = e.job_title_id
LEFT JOIN job_position jp         ON jp.id = e.job_position_id
LEFT JOIN client_role cr          ON cr.id = a.client_role_id
LEFT JOIN business_unit bu        ON bu.id = e.business_unit_id
LEFT JOIN gender g                ON g.id = e.gender_id
LEFT JOIN equipment_provider ep   ON ep.id = a.equipment_provider_id
LEFT JOIN work_modality wm        ON wm.id = e.work_modality_id;

COMMENT ON VIEW resource_v IS 'The 22 planner columns rebuilt from employee and assignment, for the roster, the table view and exports';
COMMENT ON COLUMN resource_v.assignment_situation IS 'ASIGNADO, PENDIENTE_CONFIRMACION (end date passed, not yet confirmed) or SIN_PROYECTO';
