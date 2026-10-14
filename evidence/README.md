# Evidence index

Every folder is named `<date>-<what>` and has a README stating how it was produced (commands,
scripts, who ran them), what each file contains, and what it supports. Files are kept
unedited. Large binaries live outside git in `F:\thesis\artifacts\` and are identified here by
SHA-256.

| Folder | What | Supports |
|---|---|---|
| `2026-10-09-issuer-baseline/` | First issuer DID and metadata capture (quick tunnel) | F9 |
| `2026-10-13-issuer-baseline/` | Issuer DID and metadata on the final stack (`did:web:ssi-issuer.arlabsnepal.com`) | F9, F15 |
| `2026-10-13-first-issuance/` | Failed issuance, both sides (`ERROR_FETCHING_IDENTITY_DATA`) | known-issues, C-06 follow-up |
| `2026-10-13-first-verification/` | First successful verification (quick tunnel DID) | F11 |
| `2026-10-13-reference-run/` | Phase 1 reference run: issuance and verification, logs both sides, image list | F3, F9, F10, F11 |
| `2026-10-13-issuer-signing-trace/` | Cited source excerpts for the Certify to keymanager trace | F12 to F16 |
| `2026-10-13-certify-image-libs/` | Libraries bundled in the deployed Certify jar | F16, D-04 |
| `2026-10-13-inventory-review/` | Two-pass scoring of the 919 inventory rows; excerpts for F17 to F20 | F17 to F20, `results/bindings.csv` |
| `2026-10-14-verifier-diagnosis/` | Layer test, verify-service and verify-ui logs, nginx config and env for the status 500 | known-issues 2026-10-14, SQL patch 002 |
| `2026-10-14-presentation-run/` | First presentation attempt; wallet face-matcher crash on the 28x5 placeholder face | known-issues 2026-10-14 |
| `2026-10-14-reissue-face/` | Reissue with a face photo; credential request rejected by nginx (header too large) | F22 |
| `2026-10-14-reissue-face-2/` | Second reissue; Certify Tomcat rejects the 11.9 KB token header | F22 |
| `2026-10-14-reissue-face-3/` | Successful reissue with face photo after both header limits raised (token 11,948 bytes, credential 200) | F22 |
| `2026-10-14-presentation-run-2/` | Two OpenID4VP presentations rejected for holder binding (Ed25519 VP key vs P-256 credential key) | F23 |
