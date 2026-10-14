-- Inji Verify database. Schema from inji-verify v0.18.2 db_scripts/inji_verify/ddl.
-- Note: upstream docker-compose/db-init/init.sql is stale (no response_code columns); see sql/patches/002.
CREATE DATABASE inji_verify ENCODING = 'UTF8' TEMPLATE = template0 OWNER = postgres;
\c inji_verify postgres
CREATE SCHEMA IF NOT EXISTS verify;

CREATE TABLE IF NOT EXISTS verify.authorization_request_details (
    request_id character varying(40) NOT NULL,
    transaction_id character varying(40) NOT NULL,
    authorization_details text NOT NULL,
    expires_at bigint NOT NULL
);

CREATE TABLE IF NOT EXISTS verify.presentation_definition(
    id character varying(36) NOT NULL,
    input_descriptors jsonb NOT NULL,
    name character varying(500),
    purpose character varying(500),
    vp_format text,
    submission_requirements text
);

CREATE TABLE IF NOT EXISTS verify.vc_submission(
    transaction_id character varying(40) NOT NULL,
    vc text NOT NULL
);

CREATE TABLE IF NOT EXISTS verify.vp_submission(
    request_id character varying(40) NOT NULL,
    vp_token VARCHAR NULL,
    presentation_submission text NULL,
    error character varying(100) NULL,
    error_description character varying(200) NULL,
    response_code character varying(200) NULL,
    response_code_expiry_at TIMESTAMP WITH TIME ZONE NULL,
    response_code_used boolean DEFAULT false,
    CONSTRAINT uq_vp_submission_response_code UNIQUE (response_code)
);
CREATE INDEX IF NOT EXISTS idx_vp_submission_response_code ON verify.vp_submission (response_code);
ALTER DATABASE inji_verify SET search_path TO verify,pg_catalog,public;
