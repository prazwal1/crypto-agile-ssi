# Phase 1 reference run, 2026-10-13 20:22 ICT

Classical baseline on the final Phase 1 stack: named tunnel, fixed issuer DID
`did:web:ssi-issuer.arlabsnepal.com`, Mimoto 0.22.0. Issuance into Inji Wallet v0.22.1 on a
Pixel 7 (Android 17), then verification in the wallet and in Inji Verify. Files are unedited.
Issuer metadata and DID for this run: `../2026-10-13-issuer-baseline/` (captured 20:20).

| File | Content |
|---|---|
| `stack-images.txt` | Running images and tags (`docker compose images`) |
| `logcat.txt` | Wallet JS and native warnings, 20:20 to 20:24 |
| `certify-nginx.log`, `certify.log`, `mimoto-service.log` | Server side for the same window |
| `inji-verify-result.png` | Inji Verify: "the given credential is valid", 14 claims |

## Sequence

| Time (ICT) | Step | Result |
|---|---|---|
| 20:22:20 | Wallet fetches offer `/v1/certify/credential-offer-data/{id}` | 200 |
| 20:22:22 | Issuer metadata, then OAuth AS metadata | 200, 200 |
| 20:22:23 to :33 | Trust-issuer consent; issuer added to wallet's trusted issuers | |
| 20:22:35 | Token, pre-authorized code grant | 200 |
| 20:22:36 | Wallet receives `proofSigningAlgosSupported: [RS256, ES256]`, selects a P-256 key (SPKI prefix `MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE`, id-ecPublicKey prime256v1) | |
| 20:22:37 to :39 | Proof signing: Android Keystore returns `KEY_USER_NOT_AUTHENTICATED`; biometric prompt; signature produced. Private key not exported (`privateKey: ""`) | |
| 20:22:40 | Certify: `ldp_vc` request; claims from `PreAuthDataProviderPlugin`; Claim 169 QR payload signed as CWT with `EdDSA` (`qr_signature_algo`); credential stored in ledger | |
| 20:22:43 | `/v1/certify/issuance/credential` | 200 |
| 20:22:45 to :50 | Wallet verifies the credential on receipt (fetches `/.well-known/did.json` at :48): `isVerified: true`, `isRevoked: FALSE` | |
| 20:23:33 | Inji Verify fetches `/.well-known/did.json` and reports the credential valid | |

The first 20:20 attempt in the log failed to load issuers: that wallet build still pointed at
the old quick-tunnel Mimoto. The rebuilt app (new process at 20:22) used `ssi-mimoto.arlabsnepal.com`.

Not captured: the full credential JSON (the wallet truncates it in logs).
