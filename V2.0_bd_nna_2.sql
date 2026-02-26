-- SCHEMA: public
CREATE SCHEMA IF NOT EXISTS public
    AUTHORIZATION pg_database_owner;

COMMENT ON SCHEMA public
    IS 'standard public schema';

GRANT USAGE ON SCHEMA public TO PUBLIC;
GRANT ALL ON SCHEMA public TO pg_database_owner;

-- ==========================================
-- 0. ELIMINAR TABLAS EXISTENTES (orden correcto)
-- ==========================================
DROP TABLE IF EXISTS public.asignacionexpediente CASCADE;
DROP TABLE IF EXISTS public.equipoespecialista CASCADE;
DROP TABLE IF EXISTS public.equipo CASCADE;
DROP TABLE IF EXISTS public.valoracionmedica CASCADE;
DROP TABLE IF EXISTS public.situacionlegal CASCADE;
DROP TABLE IF EXISTS public.redfamiliar CASCADE;
DROP TABLE IF EXISTS public.seguimientobitacora CASCADE;
DROP TABLE IF EXISTS public.medidaproteccion CASCADE;
DROP TABLE IF EXISTS public.planrestitucion CASCADE;
DROP TABLE IF EXISTS public.diagnosticovulneracion CASCADE;
DROP TABLE IF EXISTS public.derechovulnerado CASCADE;
DROP TABLE IF EXISTS public.expediente CASCADE;
DROP TABLE IF EXISTS public.menordeedad CASCADE;
DROP TABLE IF EXISTS public.familiar CASCADE;
DROP TABLE IF EXISTS public.tutor CASCADE;
DROP TABLE IF EXISTS public.trabajadorsocial CASCADE;
DROP TABLE IF EXISTS public.psicologo CASCADE;
DROP TABLE IF EXISTS public.medico CASCADE;
DROP TABLE IF EXISTS public.abogado CASCADE;
DROP TABLE IF EXISTS public.coordinador CASCADE;
DROP TABLE IF EXISTS public.director CASCADE;
DROP TABLE IF EXISTS public.persona CASCADE;

-- ==========================================
-- 1. TABLA MAESTRA: DATOS PERSONALES
-- ==========================================
CREATE TABLE IF NOT EXISTS public.persona (
    "CURP" character varying(18) PRIMARY KEY NOT NULL,
    "RFC" character varying(13) UNIQUE,
    "p_nombre" character varying(50) NOT NULL,
    "s_nombre" character varying(50),
    "p_apellido" character varying(50) NOT NULL,
    "s_apellido" character varying(50) NOT NULL,
    "sexo" character varying(10) CHECK (sexo IN ('Masculino', 'Femenino', 'Otro')),
    "fecha_nacimiento" date NOT NULL,
    -- Dirección descompuesta
    "calle" character varying(100),
    "num_ext" character varying(10),
    "colonia" character varying(100),
    "cp" character(5),
    "municipio" character varying(100),
    "estado_rep" character varying(50),
    "telefono" character varying(15),
    "correo" character varying(100) UNIQUE CHECK ("correo" LIKE '%@%')
);

-- ==========================================
-- 2. JERARQUÍA DE PERSONAL
-- ==========================================
CREATE TABLE IF NOT EXISTS public.director (
    "id_director" serial PRIMARY KEY,
    "CURP" character varying(18) UNIQUE NOT NULL,
    "fecha_ingreso" date NOT NULL,
    "contrasena" varchar(255) NOT NULL,
    "estado" character varying(20) DEFAULT 'Activo' CHECK (estado IN ('Activo', 'Inactivo')),
    CONSTRAINT fk_dir_persona FOREIGN KEY ("CURP") REFERENCES public.persona("CURP") ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.coordinador (
    "id_coordinador" serial PRIMARY KEY,
    "CURP" character varying(18) UNIQUE NOT NULL,
    "contrasena" varchar(255) NOT NULL,
    "estado" character varying(20) DEFAULT 'Activo' CHECK (estado IN ('Activo', 'Inactivo')),
    "id_director" integer NOT NULL,
    CONSTRAINT fk_coord_persona FOREIGN KEY ("CURP") REFERENCES public.persona("CURP") ON DELETE CASCADE,
    CONSTRAINT fk_coord_director FOREIGN KEY ("id_director") REFERENCES public.director("id_director")
);

-- ==========================================
-- 3. ESPECIALISTAS
-- ==========================================
CREATE TABLE IF NOT EXISTS public.abogado (
    "cedula" character varying(20) PRIMARY KEY NOT NULL,
    "CURP" character varying(18) UNIQUE NOT NULL,
    "especialidad" character varying(50),
    "contrasena" varchar(255) NOT NULL,
    "estado" character varying(20) DEFAULT 'Activo' CHECK (estado IN ('Activo', 'Inactivo')),
    CONSTRAINT fk_abogado_persona FOREIGN KEY ("CURP") REFERENCES public.persona("CURP") ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.medico (
    "cedula" character varying(20) PRIMARY KEY NOT NULL,
    "CURP" character varying(18) UNIQUE NOT NULL,
    "especialidad" character varying(50),
    "contrasena" varchar(255) NOT NULL,
    "estado" character varying(20) DEFAULT 'Activo' CHECK (estado IN ('Activo', 'Inactivo')),
    CONSTRAINT fk_medico_persona FOREIGN KEY ("CURP") REFERENCES public.persona("CURP") ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.psicologo (
    "cedula" character varying(20) PRIMARY KEY NOT NULL,
    "CURP" character varying(18) UNIQUE NOT NULL,
    "enfoque_terapeutico" character varying(100),
    "contrasena" varchar(255) NOT NULL,
    "estado" character varying(20) DEFAULT 'Activo' CHECK (estado IN ('Activo', 'Inactivo')),
    CONSTRAINT fk_psicologo_persona FOREIGN KEY ("CURP") REFERENCES public.persona("CURP") ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.trabajadorsocial (
    "cedula" character varying(20) PRIMARY KEY NOT NULL,
    "CURP" character varying(18) UNIQUE NOT NULL,
    "contrasena" varchar(255) NOT NULL,
    "estado" character varying(20) DEFAULT 'Activo' CHECK (estado IN ('Activo', 'Inactivo')),
    CONSTRAINT fk_tsocial_persona FOREIGN KEY ("CURP") REFERENCES public.persona("CURP") ON DELETE CASCADE
);

-- ==========================================
-- 4. ENTIDADES DE APOYO Y MENORES
-- ==========================================
CREATE TABLE IF NOT EXISTS public.tutor (
    "CURP" character varying(18) PRIMARY KEY NOT NULL,
    "parentesco" character varying(30) NOT NULL,
    "ocupacion" character varying(100),
    CONSTRAINT fk_tutor_persona FOREIGN KEY ("CURP") REFERENCES public.persona("CURP") ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.familiar (
    "CURP" character varying(18) PRIMARY KEY NOT NULL,
    CONSTRAINT fk_familiar_persona FOREIGN KEY ("CURP") REFERENCES public.persona("CURP") ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.menordeedad (
    "idME" serial PRIMARY KEY,
    "CURP" character varying(18) UNIQUE NOT NULL,
    "escolaridad" character varying(50),
    "discapacidad" character varying(100),
    "curpTutor" character varying(18),
    CONSTRAINT fk_me_persona FOREIGN KEY ("CURP") REFERENCES public.persona("CURP") ON DELETE CASCADE,
    CONSTRAINT fk_me_tutor FOREIGN KEY ("curpTutor") REFERENCES public.tutor("CURP") ON DELETE SET NULL
);

-- ==========================================
-- 5. GESTIÓN DE EXPEDIENTES
-- ==========================================
CREATE TABLE IF NOT EXISTS public.expediente (
    "numExpediente" character varying(20) PRIMARY KEY NOT NULL,
    "fechaApertura" date NOT NULL,
    "estado" character varying(15) NOT NULL,
    "canalizacion" character varying(30) NOT NULL,
    "idME" integer NOT NULL,
    CONSTRAINT fk_exp_me FOREIGN KEY ("idME") REFERENCES public.menordeedad ("idME") ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.derechovulnerado (
    "idDerecho" serial PRIMARY KEY,
    "derecho" character varying(50) NOT NULL,
    "descripcion" text
);

CREATE TABLE IF NOT EXISTS public.diagnosticovulneracion (
    "idDiagnostico" serial PRIMARY KEY,
    "numExpediente" character varying(20) NOT NULL,
    "idDerecho" integer NOT NULL,
    "fechaDiagnostico" date NOT NULL,
    "gravedad" character varying(10) NOT NULL,
    "observaciones" text,
    CONSTRAINT fk_diag_exp FOREIGN KEY ("numExpediente") REFERENCES public.expediente ("numExpediente") ON DELETE CASCADE,
    CONSTRAINT fk_diag_der FOREIGN KEY ("idDerecho") REFERENCES public.derechovulnerado ("idDerecho")
);

-- ==========================================
-- 6. VALORACIONES Y PLANES
-- ==========================================
CREATE TABLE IF NOT EXISTS public.planrestitucion (
    "idPlan" serial PRIMARY KEY,
    "numExpediente" character varying(20) UNIQUE NOT NULL,
    "fechaInicio" date NOT NULL,
    "fechaFinPrevista" date NOT NULL,
    "objetivoGeneral" text NOT NULL,
    CONSTRAINT fk_plan_exp FOREIGN KEY ("numExpediente") REFERENCES public.expediente ("numExpediente") ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.medidaproteccion (
    "idMedida" serial PRIMARY KEY,
    "idPlan" integer NOT NULL,
    "descripcion" text NOT NULL,
    "inst_responsable" character varying(150),
    "estado_medida" character varying(10) NOT NULL,
    CONSTRAINT fk_med_plan FOREIGN KEY ("idPlan") REFERENCES public.planrestitucion ("idPlan") ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.seguimientobitacora (
    "idSeguimiento" serial PRIMARY KEY,
    "idMedida" integer NOT NULL,
    "fechaSeguimiento" date NOT NULL,
    "avance" text NOT NULL,
    CONSTRAINT fk_seg_medida FOREIGN KEY ("idMedida") REFERENCES public.medidaproteccion ("idMedida") ON DELETE CASCADE
);

-- ==========================================
-- 7. RELACIONES N:M EXISTENTES
-- ==========================================
CREATE TABLE IF NOT EXISTS public.redfamiliar (
    "idME" integer NOT NULL,
    "curpFamiliar" character varying(18) NOT NULL,
    "parentesco" character varying(50) NOT NULL,
    "esContactoEmergencia" boolean DEFAULT false,
    PRIMARY KEY ("idME", "curpFamiliar"),
    CONSTRAINT fk_red_me FOREIGN KEY ("idME") REFERENCES public.menordeedad ("idME") ON DELETE CASCADE,
    CONSTRAINT fk_red_fam FOREIGN KEY ("curpFamiliar") REFERENCES public.familiar ("CURP") ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.situacionlegal (
    "idSLegal" serial PRIMARY KEY,
    "numExpediente" character varying(20) NOT NULL,
    "cedulaAbogado" character varying(20) NOT NULL,
    "fechaActualizacion" date NOT NULL,
    "estatusJuridico" text,
    CONSTRAINT fk_sl_exp FOREIGN KEY ("numExpediente") REFERENCES public.expediente ("numExpediente") ON DELETE CASCADE,
    CONSTRAINT fk_sl_abogado FOREIGN KEY ("cedulaAbogado") REFERENCES public.abogado ("cedula")
);

CREATE TABLE IF NOT EXISTS public.valoracionmedica (
    "idVMedica" serial PRIMARY KEY,
    "numExpediente" character varying(20) NOT NULL,
    "cedulaMedico" character varying(20) NOT NULL,
    "fechaRevision" date NOT NULL,
    "peso" numeric(5, 2),
    "altura" numeric(4, 2),
    CONSTRAINT fk_vm_exp FOREIGN KEY ("numExpediente") REFERENCES public.expediente ("numExpediente") ON DELETE CASCADE,
    CONSTRAINT fk_vm_medico FOREIGN KEY ("cedulaMedico") REFERENCES public.medico ("cedula")
);

-- ==========================================
-- 8. NUEVAS TABLAS PARA GESTIÓN DE EQUIPOS
-- ==========================================

-- Tabla de equipos (cada coordinador puede tener varios equipos)
CREATE TABLE IF NOT EXISTS public.equipo (
    "idEquipo" serial PRIMARY KEY,
    "nombre" character varying(100) NOT NULL,
    "descripcion" text,
    "id_coordinador" integer NOT NULL,
    "fechaCreacion" date NOT NULL DEFAULT CURRENT_DATE,
    "estado" character varying(20) DEFAULT 'Activo' CHECK (estado IN ('Activo', 'Inactivo')),
    CONSTRAINT fk_equipo_coordinador FOREIGN KEY ("id_coordinador") REFERENCES public.coordinador ("id_coordinador") ON DELETE CASCADE,
    CONSTRAINT unique_nombre_por_coordinador UNIQUE ("nombre", "id_coordinador")
);

-- Relación N:M entre equipos y especialistas
CREATE TABLE IF NOT EXISTS public.equipoespecialista (
    "idEquipo" integer NOT NULL,
    "tipo_especialista" character varying(20) NOT NULL,
    "cedula" character varying(20) NOT NULL,
    "fechaAsignacion" date NOT NULL DEFAULT CURRENT_DATE,
    "rol_en_equipo" character varying(50),
    PRIMARY KEY ("idEquipo", "tipo_especialista", "cedula"),
    CONSTRAINT fk_ee_equipo FOREIGN KEY ("idEquipo") REFERENCES public.equipo ("idEquipo") ON DELETE CASCADE,
    CONSTRAINT check_tipo_especialista CHECK (tipo_especialista IN ('abogado', 'medico', 'psicologo', 'trabajador_social'))
);

-- Asignación de expedientes a equipos
CREATE TABLE IF NOT EXISTS public.asignacionexpediente (
    "idAsignacion" serial PRIMARY KEY,
    "numExpediente" character varying(20) NOT NULL,
    "idEquipo" integer NOT NULL,
    "id_coordinador" integer NOT NULL,
    "fechaAsignacion" date NOT NULL DEFAULT CURRENT_DATE,
    "motivo" text,
    "estado_asignacion" character varying(20) DEFAULT 'Activa' CHECK (estado_asignacion IN ('Activa', 'Completada', 'Reasignada')),
    CONSTRAINT fk_asign_exp FOREIGN KEY ("numExpediente") REFERENCES public.expediente ("numExpediente") ON DELETE CASCADE,
    CONSTRAINT fk_asign_equipo FOREIGN KEY ("idEquipo") REFERENCES public.equipo ("idEquipo") ON DELETE CASCADE,
    CONSTRAINT fk_asign_coordinador FOREIGN KEY ("id_coordinador") REFERENCES public.coordinador ("id_coordinador") ON DELETE CASCADE,
    CONSTRAINT unique_expediente_activo UNIQUE ("numExpediente", "estado_asignacion")
);

-- Índice único parcial para garantizar que un expediente activo solo esté en un equipo
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_expediente_activo 
    ON public.asignacionexpediente ("numExpediente") 
    WHERE estado_asignacion = 'Activa';

-- ==========================================
-- 9. ÍNDICES ADICIONALES PARA RENDIMIENTO
-- ==========================================
CREATE INDEX IF NOT EXISTS idx_persona_curp ON public.persona("CURP");
CREATE INDEX IF NOT EXISTS idx_expediente_idme ON public.expediente("idME");
CREATE INDEX IF NOT EXISTS idx_expediente_estado ON public.expediente("estado");
CREATE INDEX IF NOT EXISTS idx_equipo_coordinador ON public.equipo("id_coordinador");
CREATE INDEX IF NOT EXISTS idx_asignacion_equipo ON public.asignacionexpediente("idEquipo");
CREATE INDEX IF NOT EXISTS idx_asignacion_coordinador ON public.asignacionexpediente("id_coordinador");
CREATE INDEX IF NOT EXISTS idx_asignacion_estado ON public.asignacionexpediente("estado_asignacion");
