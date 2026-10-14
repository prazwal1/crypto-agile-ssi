# OpenID4VP presentation trace (2026-10-14)

Source: `vp_submission.json` (export of `verify.vp_submission` via `stack.ps1 export-presentation`;
the holder photo in `credentialSubject.face` is replaced with `<face image redacted>`).
Logs: `../2026-10-14-presentation-run-2/`, `../2026-10-14-reissue-eddsa/`, `../2026-10-14-presentation-run-3/`.

| request_id | Time (UTC) | Result | VC subject key | VP holder key |
|---|---|---|---|---|
| req_bb4e8a42 | 12:44 | invalid, ERR_HOLDER_BINDING_CHECK_FAILED | did:jwk EC P-256 | did:jwk OKP Ed25519 |
| req_db8e08ee | 12:45 | invalid, ERR_HOLDER_BINDING_CHECK_FAILED | did:jwk EC P-256 | did:jwk OKP Ed25519 |
| req_2efce58b | 13:03 | valid | did:jwk OKP Ed25519 | did:jwk OKP Ed25519 (same key) |
| req_1d60e1d6 | 13:05 | valid | did:jwk OKP Ed25519 | did:jwk OKP Ed25519 (same key) |

## Cryptographic operations in one successful presentation

| # | Operation | Who | Algorithm / suite | Key | Evidence |
|---|---|---|---|---|---|
| 1 | Holder proof at issuance | Wallet | JWT `alg: EdDSA`, `typ: openid4vci-proof+jwt` | Ed25519 software key, `did:jwk` | reissue-eddsa logcat:6412 |
| 2 | Credential signature | Certify (keymanager) | `Ed25519Signature2020`, proofPurpose assertionMethod, proofValue 89 chars (multibase) | `did:web:ssi-issuer.arlabsnepal.com#cvu2BxpFAd7kCDF` | vp_submission.json VC proof |
| 3 | Access token | Certify | detached-payload JWS header `{"b64":false,"crit":["b64"],"kid":...}` | Certify OAuth key (RS256 per signing trace C8) | reissue-eddsa logcat:5196 |
| 4 | Request object check | Wallet | Ed25519 (`client_id_scheme` did) | `did:web:ssi-verify.arlabsnepal.com:v1:verify#key-0` | logcat state `authenticateVerifier` 20:03:13 |
| 5 | Presentation signature | Wallet | `JsonWebSignature2020`, detached JWS header `{"alg":"EdDSA","crit":["b64"],"b64":false}`, 64-byte signature, proofPurpose authentication, challenge + domain set | Ed25519 software key (`did:jwk`) | vp_submission.json VP proof |
| 6 | Presentation verification | Inji Verify (vc-verifier) | holder binding, proof of possession, LDP credential signature; no status check (no `credentialStatus`) | issuer DID resolved over did:web | verify-service.log 13:03:41, 13:05:08 |

Observations
- Three signature formats in one flow: JWT (holder proof), Data Integrity `Ed25519Signature2020` (credential),
  detached JWS inside `JsonWebSignature2020` (presentation). Each is selected in a different component (F20, F23).
- The VP proof `created` values (19:44:27Z, 20:03:33Z) are local Bangkok time labelled `Z` (actual UTC 12:44, 13:03).
  The credential proof `created` (13:02:44Z) is correct UTC. The verifier did not check it.
