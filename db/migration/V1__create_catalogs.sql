-- Catalogs (lookup tables) for the fields of the client's planner
-- (PLANIFICACION DE RECURSOS NPD, sheet PLANIFICADOR) that hold a closed or
-- repeated set of values. Names are unique case-insensitively so the importer
-- can't create "QA Funcional" next to "QA FUNCIONAL".

CREATE FUNCTION set_updated_at() RETURNS trigger
    LANGUAGE plpgsql AS
$$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- Fixed-domain catalogs: id + short code + display name

CREATE TABLE business_unit (
    id         smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code       varchar(20)  NOT NULL UNIQUE,
    name       varchar(100) NOT NULL,
    active     boolean      NOT NULL DEFAULT true,
    created_at timestamptz  NOT NULL DEFAULT now(),
    updated_at timestamptz  NOT NULL DEFAULT now()
);
COMMENT ON TABLE business_unit IS 'UEN';

CREATE TABLE gender (
    id         smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code       varchar(20)  NOT NULL UNIQUE,
    name       varchar(100) NOT NULL,
    active     boolean      NOT NULL DEFAULT true,
    created_at timestamptz  NOT NULL DEFAULT now(),
    updated_at timestamptz  NOT NULL DEFAULT now()
);
COMMENT ON TABLE gender IS 'GENERO';

CREATE TABLE equipment_provider (
    id         smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code       varchar(20)  NOT NULL UNIQUE,
    name       varchar(100) NOT NULL,
    active     boolean      NOT NULL DEFAULT true,
    created_at timestamptz  NOT NULL DEFAULT now(),
    updated_at timestamptz  NOT NULL DEFAULT now()
);
COMMENT ON TABLE equipment_provider IS 'EQUIPO / LAPTOP: who provides the resource''s laptop';

CREATE TABLE work_modality (
    id         smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code       varchar(40)  NOT NULL UNIQUE,
    name       varchar(100) NOT NULL,
    active     boolean      NOT NULL DEFAULT true,
    created_at timestamptz  NOT NULL DEFAULT now(),
    updated_at timestamptz  NOT NULL DEFAULT now()
);
COMMENT ON TABLE work_modality IS 'MODALIDAD LABORAL DEL RECURSO';

CREATE TABLE resource_status (
    id         smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code       varchar(40)  NOT NULL UNIQUE,
    name       varchar(100) NOT NULL,
    active     boolean      NOT NULL DEFAULT true,
    created_at timestamptz  NOT NULL DEFAULT now(),
    updated_at timestamptz  NOT NULL DEFAULT now()
);
COMMENT ON TABLE resource_status IS 'ESTADO';

-- Open catalogs: values grow as the importer / users add them

CREATE TABLE client (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       varchar(150) NOT NULL,
    active     boolean      NOT NULL DEFAULT true,
    created_at timestamptz  NOT NULL DEFAULT now(),
    updated_at timestamptz  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX client_name_uk ON client (lower(name));
COMMENT ON TABLE client IS 'CLIENTE';

CREATE TABLE project (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id  bigint       NOT NULL REFERENCES client (id),
    name       varchar(150) NOT NULL,
    active     boolean      NOT NULL DEFAULT true,
    created_at timestamptz  NOT NULL DEFAULT now(),
    updated_at timestamptz  NOT NULL DEFAULT now(),
    -- Target of resource's composite FK, keeps resource.client_id consistent with its project
    UNIQUE (id, client_id)
);
CREATE UNIQUE INDEX project_client_name_uk ON project (client_id, lower(name));
COMMENT ON TABLE project IS 'PROYECTO ASIGNADO';

CREATE TABLE npd_leader (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_code integer      NOT NULL UNIQUE,
    full_name     varchar(150) NOT NULL,
    email         varchar(254),
    active        boolean      NOT NULL DEFAULT true,
    created_at    timestamptz  NOT NULL DEFAULT now(),
    updated_at    timestamptz  NOT NULL DEFAULT now()
);
COMMENT ON TABLE npd_leader IS 'LIDER NPD. A leader is usually also a resource (same employee_code), but not always';
COMMENT ON COLUMN npd_leader.employee_code IS 'COD LIDER';
COMMENT ON COLUMN npd_leader.full_name IS 'LIDER NPD';

CREATE TABLE job_title (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       varchar(150) NOT NULL,
    active     boolean      NOT NULL DEFAULT true,
    created_at timestamptz  NOT NULL DEFAULT now(),
    updated_at timestamptz  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX job_title_name_uk ON job_title (lower(name));
COMMENT ON TABLE job_title IS 'PUESTO: HR job title';

CREATE TABLE job_position (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       varchar(150) NOT NULL,
    active     boolean      NOT NULL DEFAULT true,
    created_at timestamptz  NOT NULL DEFAULT now(),
    updated_at timestamptz  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX job_position_name_uk ON job_position (lower(name));
COMMENT ON TABLE job_position IS 'POSICIÓN: position including seniority (JR./SR.)';

CREATE TABLE client_role (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       varchar(150) NOT NULL,
    active     boolean      NOT NULL DEFAULT true,
    created_at timestamptz  NOT NULL DEFAULT now(),
    updated_at timestamptz  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX client_role_name_uk ON client_role (lower(name));
COMMENT ON TABLE client_role IS 'ROL ACTUAL EN CLIENTE';

DO $$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['business_unit', 'gender', 'equipment_provider', 'work_modality',
                             'resource_status', 'client', 'project', 'npd_leader', 'job_title',
                             'job_position', 'client_role']
    LOOP
        EXECUTE format('CREATE TRIGGER %I BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION set_updated_at()',
                       t || '_set_updated_at', t);
    END LOOP;
END;
$$;
