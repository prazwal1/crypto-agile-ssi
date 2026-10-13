# First issuance attempt, 2026-10-13 15:05 ICT

Failed attempt, captured on both sides with `env/wallet/capture-logs.ps1`. Files are unedited.

| File | Content |
|---|---|
| `logcat.txt` | Pixel 7 (Android 17), wallet JS and native warnings, 15:04:59 to 15:09 |
| `certify-nginx.log` | Requests from the phone through the Certify tunnel |
| `certify.log`, `mimoto-service.log` | Server logs for the same window |

| Time (UTC) | Request | Result |
|---|---|---|
| 08:05:36 | `GET /v1/certify/credential-offer-data/{id}` | 200 |
| 08:05:37 | `GET /.well-known/openid-credential-issuer` | 200 |
| 08:05:37 | `GET /.well-known/oauth-authorization-server` | 200 |
| 08:05:38 | `POST /v1/certify/oauth/token` (pre-authorized code) | 200 |
| (phone) | P-256 key from Android Keystore; first sign fails `KEY_USER_NOT_AUTHENTICATED`, biometric prompt, sign succeeds | |
| 08:05:40 | `POST /v1/certify/issuance/credential` | 400 `ERROR_FETCHING_IDENTITY_DATA` |

Cause: `MockCSVDataProviderPlugin` looks the holder up by token subject and ignores the
claims cached with the pre-authorized code. Fixed by `PreAuthDataProviderPlugin` (commit 9131aa6).
The successful issuance after the fix (about 15:10) was not captured.
