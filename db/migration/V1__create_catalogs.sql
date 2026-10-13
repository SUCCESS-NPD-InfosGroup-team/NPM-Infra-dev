-- Catalogs (lookup tables) for the fields of the client's planner
-- (PLANIFICACION DE RECURSOS NPD, sheet PLANIFICADOR) that hold a closed or
-- repeated set of values. Names are unique case-insensitively so a load can't
-- create "QA Funcional" next to "QA FUNCIONAL".

CREATE FUNCTION set_updated_at() RETURNS trigger
    LANGUAGE plpgsql AS
$$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- Fixed catalogs: short code + display name, seeded below

CREATE TABLE resource_status (
    id         smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code       varchar(40)  NOT NULL UNIQUE,
    name       varchar(100) NOT NULL,
    active     boolean      NOT NULL DEFAULT true,
    created_at timestamptz  NOT NULL DEFAULT now(),
    updated_at timestamptz  NOT NULL DEFAULT now()
);
COMMENT ON TABLE resource_status IS 'ESTADO: employment status only (active, leave, departed). Whether the employee has a project is derived from assignment in resource_v';

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
COMMENT ON TABLE gender IS 'GENERO. Not seeded: source and categories pending with the client';

CREATE TABLE equipment_provider (
    id         smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code       varchar(20)  NOT NULL UNIQUE,
    name       varchar(100) NOT NULL,
    active     boolean      NOT NULL DEFAULT true,
    created_at timestamptz  NOT NULL DEFAULT now(),
    updated_at timestamptz  NOT NULL DEFAULT now()
);
COMMENT ON TABLE equipment_provider IS 'EQUIPO / LAPTOP: who provides the laptop';

CREATE TABLE work_modality (
    id         smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code       varchar(40)  NOT NULL UNIQUE,
    name       varchar(100) NOT NULL,
    active     boolean      NOT NULL DEFAULT true,
    created_at timestamptz  NOT NULL DEFAULT now(),
    updated_at timestamptz  NOT NULL DEFAULT now()
);
COMMENT ON TABLE work_modality IS 'MODALIDAD LABORAL DEL RECURSO';

-- Open catalogs: values grow as resources are registered

CREATE TABLE client (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        varchar(150) NOT NULL,
    is_internal boolean      NOT NULL DEFAULT false,
    active      boolean      NOT NULL DEFAULT true,
    created_at  timestamptz  NOT NULL DEFAULT now(),
    updated_at  timestamptz  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX client_name_uk ON client (lower(name));
COMMENT ON TABLE client IS 'CLIENTE';
COMMENT ON COLUMN client.is_internal IS 'Internal work such as NPD-ADMINISTRACION';

CREATE TABLE project (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id  bigint       NOT NULL REFERENCES client (id),
    name       varchar(150) NOT NULL,
    active     boolean      NOT NULL DEFAULT true,
    created_at timestamptz  NOT NULL DEFAULT now(),
    updated_at timestamptz  NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX project_client_name_uk ON project (client_id, lower(name));
COMMENT ON TABLE project IS 'PROYECTO ASIGNADO. "SIN PROYECTO" is not a project: it is an assignment without project_id';

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
    FOREACH t IN ARRAY ARRAY['resource_status', 'business_unit', 'gender', 'equipment_provider',
                             'work_modality', 'client', 'project', 'job_title', 'job_position',
                             'client_role']
    LOOP
        EXECUTE format('CREATE TRIGGER %I BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION set_updated_at()',
                       t || '_set_updated_at', t);
    END LOOP;
END;
$$;

-- Seed of the fixed catalogs the application needs to work. No client or
-- personal data from the planner is loaded here.

INSERT INTO resource_status (code, name) VALUES
    ('ACTIVO',   'Activo'),
    ('LICENCIA', 'Licencia'),
    ('BAJA',     'Baja');

INSERT INTO business_unit (code, name) VALUES
    ('AE',  'AE'),
    ('IFP', 'IFP');

INSERT INTO equipment_provider (code, name) VALUES
    ('INFOS',   'Infos'),
    ('CLIENTE', 'Cliente');

-- Data-validation list of the planner's MODALIDAD LABORAL column, with its
-- typos fixed ('Pesencial', 'Hibrido . 1 al mes')
INSERT INTO work_modality (code, name) VALUES
    ('PRESENCIAL_L_V',    'Presencial - L/V'),
    ('PRESENCIAL_4_DIAS', 'Presencial - 4 Dias'),
    ('PRESENCIAL_L_S',    'Presencial - L/S'),
    ('HIBRIDO_1_DIA',     'Hibrido - 1 Dia'),
    ('HIBRIDO_2_DIAS',    'Hibrido - 2 Dias'),
    ('HIBRIDO_3_DIAS',    'Hibrido - 3 Dias'),
    ('HIBRIDO_1_AL_MES',  'Hibrido - 1 al mes'),
    ('HIBRIDO_2_AL_MES',  'Hibrido - 2 al mes'),
    ('VIRTUAL',           'Virtual');
