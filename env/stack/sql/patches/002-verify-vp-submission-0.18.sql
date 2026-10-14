-- 002-verify-vp-submission-0.18.sql
-- database: inji_verify
-- Purpose: bring verify.vp_submission up to the verify-service 0.18.2 entity.
-- Reason:  sql/verify_init.sql was copied from inji-verify docker-compose/db-init/init.sql,
--          which upstream never updated after 0.18.0. verify-service 0.18.2 selects
--          response_code, response_code_expiry_at and response_code_used, so every
--          GET /v1/verify/vp-request/{id}/status failed with
--          "column v1_0.response_code does not exist" (HTTP 500, observed 2026-10-14,
--          evidence/2026-10-14-verifier-diagnosis/verify-service.log).
-- Source:  inji-verify v0.18.2 db_scripts/inji_verify/ddl/verify-vp_submission.sql
--          and db_upgrade_script/inji_verify/sql/0.17.0_to_0.18.0_upgrade.sql.
-- Safe to re-run.
SET search_path TO verify;
ALTER TABLE vp_submission
    ADD COLUMN IF NOT EXISTS response_code character varying(200) NULL,
    ADD COLUMN IF NOT EXISTS response_code_expiry_at TIMESTAMP WITH TIME ZONE NULL,
    ADD COLUMN IF NOT EXISTS response_code_used boolean DEFAULT false;
ALTER TABLE vp_submission ALTER COLUMN vp_token DROP NOT NULL;
ALTER TABLE vp_submission ALTER COLUMN presentation_submission DROP NOT NULL;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_vp_submission_response_code') THEN
    ALTER TABLE vp_submission ADD CONSTRAINT uq_vp_submission_response_code UNIQUE (response_code);
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_vp_submission_response_code ON vp_submission (response_code);
