-- One row per employee, mirroring a row of the planner (ordered by COD EMPL).
-- Every one of the planner's 22 columns maps to a column here or to a catalog;
-- see the COMMENTs and README for the mapping.

CREATE TABLE resource (
    id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_code         integer      NOT NULL UNIQUE,
    full_name             varchar(150) NOT NULL,
    email                 varchar(254),
    gender_id             smallint     REFERENCES gender (id),
    start_date            date,
    job_title_id          bigint       REFERENCES job_title (id),
    job_position_id       bigint       REFERENCES job_position (id),
    level                 smallint     CHECK (level > 0),
    business_unit_id      smallint     REFERENCES business_unit (id),
    probation_month       date         CHECK (extract(day FROM probation_month) = 1),
    vacation_month        date         CHECK (extract(day FROM vacation_month) = 1),
    equipment_provider_id smallint     REFERENCES equipment_provider (id),
    work_modality_id      smallint     REFERENCES work_modality (id),
    status_id             smallint     NOT NULL REFERENCES resource_status (id),

    -- Current assignment
    client_id             bigint       REFERENCES client (id),
    project_id            bigint,
    leader_id             bigint       REFERENCES npd_leader (id),
    client_role_id        bigint       REFERENCES client_role (id),
    client_contact_email  varchar(254),
    -- NULL = INDEFINIDO
    project_end_date      date,
    project_end_month     date GENERATED ALWAYS AS (date_trunc('month', project_end_date::timestamp)::date) STORED,

    created_at            timestamptz  NOT NULL DEFAULT now(),
    updated_at            timestamptz  NOT NULL DEFAULT now(),

    -- A project implies its client; the client may be set alone (e.g. internal work)
    CONSTRAINT resource_project_fk FOREIGN KEY (project_id, client_id) REFERENCES project (id, client_id),
    CONSTRAINT resource_project_needs_client CHECK (project_id IS NULL OR client_id IS NOT NULL)
);

CREATE UNIQUE INDEX resource_email_uk ON resource (lower(email));
CREATE INDEX resource_client_idx ON resource (client_id);
CREATE INDEX resource_project_idx ON resource (project_id);
CREATE INDEX resource_leader_idx ON resource (leader_id);
CREATE INDEX resource_status_idx ON resource (status_id);
CREATE INDEX resource_project_end_month_idx ON resource (project_end_month);

CREATE TRIGGER resource_set_updated_at BEFORE UPDATE ON resource
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE resource IS 'NPD resource (employee), one row per planner row';
COMMENT ON COLUMN resource.client_id IS 'CLIENTE';
COMMENT ON COLUMN resource.project_id IS 'PROYECTO ASIGNADO';
COMMENT ON COLUMN resource.leader_id IS 'LIDER NPD + COD LIDER';
COMMENT ON COLUMN resource.employee_code IS 'COD EMPL';
COMMENT ON COLUMN resource.full_name IS 'NOMBRE DE EMPLEADO';
COMMENT ON COLUMN resource.job_title_id IS 'PUESTO';
COMMENT ON COLUMN resource.job_position_id IS 'POSICIÓN';
COMMENT ON COLUMN resource.client_role_id IS 'ROL ACTUAL EN CLIENTE';
COMMENT ON COLUMN resource.level IS 'NIVEL';
COMMENT ON COLUMN resource.start_date IS 'FECHA DE INICIO';
COMMENT ON COLUMN resource.business_unit_id IS 'UEN';
COMMENT ON COLUMN resource.gender_id IS 'GENERO';
COMMENT ON COLUMN resource.equipment_provider_id IS 'EQUIPO / LAPTOP';
COMMENT ON COLUMN resource.probation_month IS 'MES DE PROBATORIA (first day of the month)';
COMMENT ON COLUMN resource.vacation_month IS 'MES DE VACACIONES (first day of the month)';
COMMENT ON COLUMN resource.project_end_date IS 'FECHA FINAL PROYECTO; NULL means INDEFINIDO';
COMMENT ON COLUMN resource.project_end_month IS 'MES FINAL DE PROYECTO, derived from project_end_date';
COMMENT ON COLUMN resource.status_id IS 'ESTADO';
COMMENT ON COLUMN resource.email IS 'CORREO RECURSO';
COMMENT ON COLUMN resource.client_contact_email IS 'CONTACTO POR CLIENTE';
COMMENT ON COLUMN resource.work_modality_id IS 'MODALIDAD LABORAL DEL RECURSO';
