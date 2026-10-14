-- 003-farmer-credential-eddsa-proof.sql
-- Purpose: let the wallet bind FarmerCredential to the same key it later presents with.
-- Reason:  the upstream seed allows only RS256 and ES256 holder proofs for FarmerCredential, so
--          Inji Wallet binds the credential to its hardware P-256 key (did:jwk, EC). Its
--          OpenID4VP flow signs every ldp_vc presentation with its Ed25519 key instead
--          (openID4VPModel.ts:80 keyType ED25519; openID4VPServices.ts:106-107 holder did:jwk).
--          Inji Verify 0.18.2 then fails ERR_HOLDER_BINDING_CHECK_FAILED (observed 2026-10-14,
--          evidence/2026-10-14-presentation-run-2/verify-service.log). See F23.
--          The wallet's default key order puts Ed25519 first, so offering EdDSA here makes
--          issuance pick Ed25519. JwtProofValidator.java:198 matches the header alg name, and the
--          wallet sends "EdDSA".
-- Scope:   configuration data only. Credentials issued before this patch stay bound to P-256.
UPDATE certify.credential_config
SET proof_types_supported = '{"jwt": {"proof_signing_alg_values_supported": ["EdDSA", "ES256", "RS256"]}}'::JSONB
WHERE credential_config_key_id = 'FarmerCredential';
