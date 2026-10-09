-- 001-farmer-credential-subject.sql
-- Purpose: align FarmerCredential's declared credential subject with the claims the
--          CSV data provider actually supplies (config/farmer_identity_data.csv).
-- Reason:  the upstream injistack seed declares only fullName, phone, dateOfBirth and
--          gender, so Certify rejects pre-authorized offers carrying the remaining
--          CSV columns with "unknown_claims" (observed 2026-10-09).
-- Scope:   configuration data only; no Certify code is changed.
UPDATE certify.credential_config
SET credential_subject = '{"fullName": {"display": [{"name": "Full Name", "locale": "en"}]}, "mobileNumber": {"display": [{"name": "Mobile Number", "locale": "en"}]}, "dateOfBirth": {"display": [{"name": "Date of Birth", "locale": "en"}]}, "gender": {"display": [{"name": "Gender", "locale": "en"}]}, "state": {"display": [{"name": "State", "locale": "en"}]}, "district": {"display": [{"name": "District", "locale": "en"}]}, "villageOrTown": {"display": [{"name": "Village or Town", "locale": "en"}]}, "postalCode": {"display": [{"name": "Postal Code", "locale": "en"}]}, "landArea": {"display": [{"name": "Land Area", "locale": "en"}]}, "landOwnershipType": {"display": [{"name": "Land Ownership Type", "locale": "en"}]}, "primaryCropType": {"display": [{"name": "Primary Crop Type", "locale": "en"}]}, "secondaryCropType": {"display": [{"name": "Secondary Crop Type", "locale": "en"}]}, "face": {"display": [{"name": "Face", "locale": "en"}]}, "farmerID": {"display": [{"name": "Farmer ID", "locale": "en"}]}}'::JSONB
WHERE credential_config_key_id = 'FarmerCredential';
