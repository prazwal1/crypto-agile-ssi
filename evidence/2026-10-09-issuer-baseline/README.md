# Issuer baseline, 2026-10-09

Captured from the running local stack (Inji Certify 0.14.0) through the Certify tunnel
`https://should-waters-mens-incomplete.trycloudflare.com`, at 15:04 ICT. Files are unedited.

| File | Source endpoint |
|---|---|
| `did.json` | `/.well-known/did.json` |
| `issuer-meta.json` | `/v1/certify/.well-known/openid-credential-issuer` |
| `as-meta.json` | `/.well-known/oauth-authorization-server` |
| `jwks.json` | `/.well-known/jwks.json` |
| `run-check-health.log` | Health check run, 14:57 |
| `run-test-issuance.log` | Capture and offer attempt, 15:04 (offer failed: `unknown_claims`, fixed by SQL patch 001) |

Summary: one `Ed25519VerificationKey2020` verification method; FarmerCredential is `ldp_vc`
signed with EdDSA; holder binding `did:jwk`; holder proofs accepted: RS256, ES256;
JWKS holds RSA (2), Ed25519, secp256k1 and P-256 keys. See finding F9.
