# SD-JWT VC end-to-end trace (D-02, 2026-10-14)

Credential type `FarmerCredentialSdJwt` (`env/stack/config/credential-configs/FarmerCredentialSdJwt.json`),
registered with `stack.ps1 add-credential-config` (logs `env/stack/logs/20261014-212858-*`, `-215353-*`).
Run logs: `../2026-10-14-sdjwt-issuance/`, `-sdjwt-presentation/` (face-match failure), `-sdjwt-issuance-2/`, `-sdjwt-presentation-2/`.
Stored presentation: `vp_submission.json`, request `req_67368f5d`.

## Result

| Step | Outcome | Evidence |
|---|---|---|
| Issuer metadata | `vc+sd-jwt`, vct `FarmerCredentialSdJwt`, signing ES256, holder proofs RS256, PS256, ES256, Ed25519 | add-credential-config logs |
| Issuance (attempt 1, with face) | token 200 (11,936 B), credential 200 (15,986 B) | sdjwt-issuance/certify-nginx.log |
| Presentation (attempt 1) | wallet `FACE_INVALID` three times, never sent (wallet bug, known-issues) | sdjwt-presentation/logcat.txt:780, 998 |
| Issuance (attempt 2, no face) | token 200 (1,681 B), credential 200 (5,436 B); wallet `isRevoked FALSE`, no verification error; no DID fetch | sdjwt-issuance-2 |
| Presentation (attempt 2) | plain Share; VP 5,127 chars; verify-service processed with no error; status check skipped ("not supported for this credential format") | sdjwt-presentation-2/verify-service.log 14:56:30 |

## Cryptographic operations

| # | Operation | Algorithm | Key / trust | Evidence |
|---|---|---|---|---|
| 1 | Holder proof at issuance | JWT `alg: Ed25519` (fully-specified name), `typ: openid4vci-proof+jwt` | wallet Ed25519 software key, `did:jwk` | sdjwt-issuance-2/logcat.txt:1452 |
| 2 | Issuer signature on the SD-JWT | `alg: ES256`, `typ: vc+sd-jwt`, 64-byte signature | keymanager `CERTIFY_VC_SIGN_EC_R1 / EC_SECP256R1_SIGN` (P-256); header carries `x5c` (2 certs), `x5t#S256`, `kid` | vp_submission.json |
| 3 | Issuer certificate chain | leaf P-256, signed `sha256WithRSAEncryption` by a self-signed RSA "ROOT" (`CN=www.example.com`, `O=IIITB`), valid 2026-10-13 to 2029-10-12 | default keymanager certificates, not a real CA | openssl on x5c[0] |
| 4 | Issuer identity | `iss: https://ssi-issuer.arlabsnepal.com` (URL, not the issuer DID) | vc-verifier takes the key from `x5c[0]` (`SdJwtVerifier.kt:17-27`), no anchor check found | source + payload |
| 5 | Selective disclosure | 12 `_sd` digests (`_sd_alg` absent, default sha-256); `farmerID`, `vct`, `iss`, `id` plain | 3 of 12 disclosures presented (fullName, primaryCropType, secondaryCropType) | vp_submission.json |
| 6 | Key binding | `cnf.kid` = holder `did:jwk` (OKP Ed25519); KB-JWT `alg: EdDSA`, `typ: kb+jwt`, `aud` = verifier DID, `nonce`, `sd_hash` (recomputed: matches) | same Ed25519 key as step 1 | vp_submission.json |
| 7 | Request object | Ed25519 (`authenticateVerifier`) | verifier did:web | sdjwt-presentation-2/logcat.txt:336 |

## Observations

- SD-JWT VC works end to end in this stack: issuance, wallet storage, OpenID4VP with selective disclosure and key binding, verification.
- The SD-JWT issuer key is trusted through an embedded certificate, not through the issuer DID document used for `ldp_vc`: a second, independent key-publication path (S2) with its own algorithm (RSA root, P-256 leaf).
- One holder key, two algorithm names in one flow: `Ed25519` in the issuance proof, `EdDSA` in the KB-JWT. The wallet picks the name to match the issuer's list (`resolveEd25519Alg`).
- No revocation check is possible for SD-JWT in Inji Verify 0.18.2.
- Credentials with a face claim cannot be presented as SD-JWT (wallet reads the reference face only from the ldp_vc layout).
