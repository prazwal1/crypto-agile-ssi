# Lab Notebook

Dated record of working sessions. Each entry states what was done, what was observed and what changed. Newest entries first. Problems and their fixes are summarised in `known-issues.md`; open questions in `decisions.md`.

---

## 2026-10-14 (Wed)

### Preparing the OpenID4VP presentation trace
- Goal: one cross-device presentation of the FarmerCredential to Inji Verify, to observe at runtime the bindings F20 describes statically (VP signing, request-object verification, response handling).
- Found presentations disabled (`VP_SUBMISSION_SUPPORTED=false`) and the verifier identified by internal Docker names (`did:web:verify-service:v1:verify`), unreachable from the phone. Upstream 0.18.2 compose expects a public proxy host (`VERIFY_SERVICE_PROXY_FOR_LOCALHOST`).
- Changes: optional third tunnel hostname `VERIFY_HOSTNAME` (verify-ui:8000, which proxies `/v1/verify` and the DID to verify-service); verifier DID, response URI and redirect built from it; presentations enabled; FarmerCredential request added to `verify-config/config.json` (client_id_scheme did, ldp_vc, Ed25519Signature2020) and made the only essential entry.
- Found D-08: verifier source analysed at v0.17.0, images run 0.18.2.

### Verifier status 500 (10:47 to 11:05)
- Symptom: Generate QR Code (FarmerCredential) and Request Verifiable Credentials both fail with "Failed to fetch status". `POST vp-session-request` returns 201; `GET /v1/verify/vp-request/{id}/status` returns 500.
- Added `stack.ps1 diagnose-verifier`: same probe on verify-service (:8095), verify-ui nginx (:3000) and the tunnel. All three answer 404 `NO_AUTH_REQUEST` for a made-up id, and the verifier DID resolves on all three, so routing and the DID are fine (`evidence/2026-10-14-verifier-diagnosis/layer-test.txt`).
- Cause in `verify-service.log`: `PSQLException: column v1_0.response_code does not exist`. verify-service 0.18.2 maps `response_code`, `response_code_expiry_at`, `response_code_used` (same-device flow, added in 0.18.0). `sql/verify_init.sql` was copied from upstream `docker-compose/db-init/init.sql`, which upstream never updated; the authoritative DDL is `db_scripts/inji_verify/ddl/verify-vp_submission.sql`. The earlier check "schema matches db-init" compared against the stale file.
- Fix: SQL patch 002 (adds the columns, drops NOT NULL on `vp_token` and `presentation_submission`, adds the unique constraint and index, as in the 0.18.2 DDL); `apply-patches` now routes a patch by its `-- database:` header and restarts verify-service; `verify_init.sql` corrected for fresh installs. Other three tables match the DDL (`input_descriptors` is jsonb here, text upstream; no effect on reads).
- Lesson for the method: compare schemas against the release DDL, not the convenience compose file.

### Presentation attempt 1 and reissue with a face photo (11:42 to 19:18)
- Attempt 1 (`evidence/2026-10-14-presentation-run/`): wallet offered only "Share with selfie" and crashed after the selfie with "Input image width and height should be at least 32". The sample credential's `face` is a 28x5 placeholder PNG; `SendVPScreen.tsx:325-355` forces Share with selfie whenever a credential has a face. Added `issue-test-offer.ps1 -FaceFile` (photo kept in `F:\thesis\private\`, gitignored).
- Wallet stuck twice on "Loading from localhost:8081": wireless adb drops the Metro reverse forward. Added `env/wallet/connect-phone.ps1`; `capture-logs.ps1` sets the forward.
- Reissue (`evidence/2026-10-14-reissue-face/`): offer, metadata and token succeeded (token response 45,239 bytes); `POST /v1/certify/issuance/credential` was rejected by nginx with 400 "Request Header Or Cookie Too Large" before reaching Certify. Source: Certify writes all claims into the access token `sub` (F22). Fix: nginx header buffers 64k; face photos shrunk to 240 px. Checked the evidence for the photo and tokens before committing: none logged.
- Reissue 2 (`evidence/2026-10-14-reissue-face-2/`, 19:27): token 11,941 bytes passed nginx, then Certify's Tomcat rejected the header (`Request header is too large`). The wallet retried with the consumed offer (`invalid_grant`). Fix: `server.max-http-request-header-size=64KB`. Same 8 KB budget at a second layer, which strengthens F22.
- Reissue 3 (`evidence/2026-10-14-reissue-face-3/`, 19:42): token 11,948 bytes, `POST /issuance/credential` 200 (9,203 bytes), wallet then resolved the issuer DID and shows the card as valid.

### Presentation run 2 (19:44 to 19:46)
- `evidence/2026-10-14-presentation-run-2/`. Two presentations; both reached verify-service (VP 10,032 chars) and both failed the holder binding check: VP holder `did:jwk` OKP/Ed25519, VC subject `did:jwk` EC/P-256. Credential signature verification itself ran (LdpVerifier); no credentialStatus in the VC.
- Cause in the wallet source: issuance key from the issuer's allowed proof algorithms and the user's key order; presentation key fixed to Ed25519 (F23). Fix for the run: SQL patch 003 (FarmerCredential allows EdDSA proofs; wallet default order puts Ed25519 first), then reissue.
- Verifier screenshot not committed: it shows the holder's photo.

### Successful presentation (19:57 to 20:05)
- 19:57 `apply-patches` (001 to 003 OK; Certify and verify-service restarted).
- Reissue (`evidence/2026-10-14-reissue-eddsa/`, 20:02): wallet proof JWT header `alg: EdDSA`, `typ: openid4vci-proof+jwt`, `kid: did:jwk` (OKP, Ed25519), logcat line 6412. Credential 200 (9,072 bytes); wallet resolved the issuer DID twice (credential check).
- Presentation A (same folder, 20:03:10 to 20:03:39): wallet states `checkIfClientValidationIsRequired`, `getKeyPairFromKeystore`, `authenticateVerifier` (request object verified), `checkVerifierTrust`, consent, face match `FACE_VALID`, `sendVP` success. Verifier `req_2efce58b`: holder binding and proof-of-possession checks passed, no error.
- Presentation B (`evidence/2026-10-14-presentation-run-3/`, 20:04 to 20:05): `req_1d60e1d6`, VP 9,901 chars, same checks passed, result valid in the browser.
- Both: `LdpStatusChecker` warns "No credentialStatus field present in the VC" (no revocation check possible for this credential).
- The access token header in logcat is `{"b64":false,"crit":["b64"],"kid":...}` (detached-payload JWS form from keymanager); values in logcat are truncated, so the VP proof is taken from the verifier database (`stack.ps1 export-presentation`).
- 20:08 to 20:10 `export-presentation` (`evidence/2026-10-14-presentation-export/`). First run returned only large-object ids: `VPSubmission.vpToken` is `@JdbcTypeCode(SqlTypes.CLOB)`, stored by PostgreSQL as a large object; fixed with `lo_get`. Second run: 4 submissions, 4 face images redacted; the redaction regex also removed a JSON escape, repaired and the regex fixed. Trace summarised in `TRACE.md`: VP proof `JsonWebSignature2020` with detached EdDSA JWS; credential proof `Ed25519Signature2020`; failed runs P-256 subject vs Ed25519 holder, successful runs same Ed25519 key.
- Side observation: the wallet writes VP proof `created` in local time with a `Z` suffix (7 h off); not checked by the verifier.

### D-08: Inji Verify v0.17.0 vs v0.18.2 (20:42 to 21:20)
- Cloned inji-verify and vc-verifier; `git diff` of the 18 inji-verify inventory files: 8 unchanged, 10 changed, no algorithm or suite list changed. Service adds VP challenge = nonce and domain = client_id checks (`VerifiablePresentationSubmissionServiceImpl.java:166-177`).
- Root pom: vcverifier-jar 1.7.0 -> 1.8.1, nimbus 9.37.2 -> 9.37.4, BouncyCastle 1.78 unchanged. The v0.18.2 `sbom.json` equals the v0.17.0 `sbom-clean.json` except a trailing newline.
- vc-verifier 1.6.0 (wallet) vs 1.8.1 (Inji Verify): ES256 fixed (was mapped to the secp256k1 verifier), EcdsaSecp256r1Signature2019 added, proofValue suite chosen by proof type, holder binding and proof-of-possession added (Ed25519 and P-256 holder keys).
- PB copied `/home/inji/verify-service.jar` out of the running container (image `inji-verify-service:0.18.2`, sha256 `2ed468e7...`) to `F:\thesis\artifacts\2026-10-14-verify-0.18.2\` (jar sha256 `4c049791...`). `inspect-jar.py`: vcverifier-jar 1.8.1, nimbus 9.37.4, BouncyCastle 1.69, 1.70 and 1.78 (1.69 first on the classpath); only 1.78 has pre-standard Dilithium/SPHINCS+.
- Decision C-10 (closes D-08); F8, F18, F23 updated.

### D-02: SD-JWT VC end to end (21:21 to 22:00)
- Upstream SD-JWT setup read from Certify v0.14.0 (`docs/SD-JWT-Support.md`, api-test configs, `SDJWT.java`, `VelocityTemplatingEngineImpl.java:249-253` adds vct, cnf, iss). Registered `FarmerCredentialSdJwt` through Certify's own API (`stack.ps1 add-credential-config`): ES256 with the P-256 keymanager key, 12 selectively disclosable claims, farmerID plain.
- While reading the config: `credential-configurations`, `credentials/status`, `system-info`, `ledger-search` are in `ignore-auth-urls` and were reachable through the public hostname (F24). Blocked in nginx (C-12).
- Correction to the D-08 note on F18: vc-verifier 1.6.0's ES256K class verifies with the key's own curve (`SHA256withECDSA`), so P-256 signatures verify; the issue is the mislabelled registry and no alg-to-curve check, not a wrong-curve verification.
- Issuance 1 (with face) succeeded; presentation 1 failed `FACE_INVALID` three times. Cause: wallet forces selfie from `getFaceAttribute` (reads SD-JWT) but takes the reference face from `credential.credentialSubject.face` only (`openID4VPSelectors.ts:81`). Face removed from the SD-JWT template.
- Issuance 2 (21:5x): token 1,681 B, credential 5,436 B, holder proof `alg: Ed25519`. Presentation 2 (21:56): plain Share, 3 of 12 disclosures, KB-JWT EdDSA with aud = verifier DID, nonce, sd_hash (recomputed, matches); verify-service no error, status check skipped for SD-JWT. Issuer cert chain: P-256 leaf under a self-signed RSA example root; `iss` is the https URL. Trace in `TRACE-SDJWT.md`. C-11 closes D-02; F24, F25.

### Closing items on Claude's side (22:08 onward)
- InsufficientAuthenticationException (open since 2026-10-09): mechanism confirmed from `SecurityConfig` (`.anyRequest().authenticated()` + oauth2 resource server). Any request to `certify:8090` on a non-ignored path without a bearer token is rejected (401) and logged at ERROR by `ExceptionHandlerAdvice`. No functional impact. Added `stack.ps1 diagnose-certify-auth` to pin the exact caller; left as cosmetic.
- D-07: issuer DID `assertionMethod`/`authentication` list the bare DID, not the verification-method id (`DIDDocumentUtil.java:62-63` vs the id at `:132`). Non-conformant with DID Core / Controlled Identifiers; MOSIP verifiers do not enforce it (`vc-verifier LdpVerifier.kt:43-55`) so runs passed. Deferred to the D-03 external-verifier test (C-13); covered by R-10. Evidence `evidence/2026-10-14-did-conformance/`.

---

## 2026-10-13 (Tue, evening)

### Final Phase 1 stack
- Mimoto image set to 0.22.0 to match the analysed source (C-07). Named Cloudflare tunnel on `arlabsnepal.com` (C-08): issuer DID now fixed at `did:web:ssi-issuer.arlabsnepal.com`, Mimoto at `https://ssi-mimoto.arlabsnepal.com`. Offer creation and actuator blocked on the public host (C-09).
- `start` (20:13): named tunnel registered; all local and public endpoints 200. Wallet rebuilt against the new Mimoto host.

### Workbook review columns (23:24 to 23:35)
- Added reviewer columns (PB verdict and comment, Supervisor verdict and comment; verdict drop-down Agree / Partly / Disagree) to every sheet that makes a claim: RQ1 Answer, Findings, Requirements, Algorithm Matrix, Bindings, Issuer Registries, Runtime Evidence, Source Citations, Decisions, Spot-Check (181 items).
- New Review Status sheet counts reviewed items and agreement per sheet by formula.
- `build_workbook.py` now reads existing verdicts and comments before rebuilding and writes them back, keyed by each row's id; tested by entering sample reviews, rebuilding over them and checking they survived. 423 formulas recalculate with no errors.

### Phase 1 workbook (22:08 to 22:25)
- Built `docs/phase1/Phase1-Workbook.xlsx` from the repository with `docs/phase1/build_workbook.py` (content in `workbook_data.py`): RQ1 answers, findings F1 to F21 with reasoning, design requirements R-01 to R-12, findings-to-requirements traceability, algorithm support matrix, bindings, issuer registries, scored inventory, runtime timeline, source citations with GitHub permalinks at the pinned commits, evidence index, environment, decisions, known issues, activity log, method and the spot-check sheet.
- Checks: 308 formulas recalculated with no errors; all 1,195 GitHub links point to existing files and lines in the pinned clones; all 28 relative links resolve in the repository; the build re-run on the laptop gives identical cell content.
- Corrections found while building: F12 said 9 code registries, the table has 8 (plus 3 data/config and 1 library); fixed in findings and the signing-path write-up. New F21: the ECDSA cryptosuites map to ES256 in Certify's packaged default but to ES256K in the injistack compose config we deploy.

### Inventory review (21:31 to 21:40)
- Scored all 919 scanner rows. Pass 1 by path rule: 341 rows in tests, build files, upstream deployment config, samples and docs. Pass 2 by hand: read the matched code in 245 production files at the pinned commits, one judgement per file (`phase1-dependency-analysis/review/judgements.tsv`).
- Result: 446 verified rows collapse into 35 bindings across 9 repositories (`results/bindings.csv`). New `tools/score_inventory.py` refuses to run if any production row lacks a judgement; outputs reproduced identically on the laptop.
- Mistake caught: the deployment-config path rule also matched four production Java classes in `config/` packages; fixed and reviewed by hand.
- New findings: F17 iOS wallet treats unverifiable suites as valid; F18 issuer and vc-verifier allow-lists disagree (ES256 and Data Integrity issuable but rejected); F19 Mimoto negotiates the proof algorithm with a fail-open Ed25519 fallback; F20 single-algorithm choices in OpenID4VP request signing, response encryption and OAuth tokens.
- Pending: PB spot-check of 20 sampled rows (`review/spot-check.csv`).

### Deployed Certify libraries and citation evidence (21:15)
- Located the Certify application in the running container (`/home/inji/certify-service.jar`, plugins in `/home/inji/additional_jars/`) and copied it and the mock plugin out. Archived outside git in `F:\thesis\artifacts\2026-10-13-certify-0.14.0\` with SHA-256 recorded.
- New `tools/inspect-jar.py`: keymanager 1.4.0 confirmed inside the image; three BouncyCastle copies in the issuer JVM, none with final ML-DSA or SLH-DSA (F16). Evidence: `evidence/2026-10-13-certify-image-libs/`.
- New `tools/cite.py`: all 24 file:line citations of the signing trace extracted from the pinned clones into `evidence/2026-10-13-issuer-signing-trace/excerpts.md`, so each claim is checkable.
- Added `evidence/README.md` (index and convention) and `F:\thesis\artifacts\README.md`.

### Issuer signing path (20:40)
- Traced Certify 0.14.0 signing through MOSIP keymanager 1.4.0 (version from Certify's pom). Added keymanager to `manifest.tsv` and `repos/`. Write-up: `phase1-dependency-analysis/issuer-signing-path.md`.
- New findings F12 to F15: 12 issuer-side registries per algorithm, key type encoded in reference-id strings with silent PS256/RS256 fallbacks, an RSA-2048 key hierarchy beneath the Ed25519 VC key, and the DID document's hard-coded `assertionMethod` (root cause of D-07).
- To confirm: that the Certify image actually bundles keymanager 1.4.0.

### Reference run (20:22)
Evidence: `evidence/2026-10-13-reference-run/`, issuer baseline re-captured in `evidence/2026-10-13-issuer-baseline/`
- Issuance and verification succeeded end to end; Inji Verify reports the credential valid with all 14 claims.
- Wallet selected ES256 from `[RS256, ES256]`; the P-256 key needs user authentication for every signature (F3, F9 updated).
- New: Certify signs the Claim 169 QR payload as a CWT with a separately configured algorithm (F10). Two verifiers act on each credential, the wallet on receipt and Inji Verify on presentation (F11).

---

## 2026-10-13 (Tue)

### Move to a second laptop
- The first laptop could not sustain the wallet build: Gradle ran CPU and RAM at 100% and the USB port was unreliable for the phone connection. Moved the environment to a second Windows laptop.
- Copied this repository to `F:\thesis\crypto-agile-ssi`. The ten pinned analysis clones came across at their manifest commits.
- Removed runtime state from the first laptop: `env/stack/logs/*`, `offer.html`, `.env`, `wallet.env` (all regenerated by `refresh-tunnels` or `issue-offer`) and the Certify keystore `data/CERTIFY_PKCS12/local.p12`. The keystore would not match the new, empty PostgreSQL volume; Certify generates new keys on first start. The issuer DID changes anyway with new tunnels.
- The wallet working copy now defaults to `<thesis root>\inji-wallet` (`F:\thesis\inji-wallet`) instead of `C:\dev\inji-wallet`; still short enough for the 260-character limit.
- Added `env/wallet/build-env.ps1`: Gradle and npm caches under the thesis root, and a user-level `gradle.properties` that caps the daemon heap and worker count and builds only `arm64-v8a`. The wallet source is not modified.

### Stack and wallet on the second laptop
- `start` (11:29): all local endpoints 200 (Certify, nginx, Mimoto, Verify UI, Inji Web); both tunnels registered; public DID, issuer metadata, OAuth metadata and Mimoto 200. New issuer DID `did:web:signing-regulated-grain-prior.trycloudflare.com`; Mimoto `https://overview-library-assumptions-presenting.trycloudflare.com`. Certify generated a fresh keystore.
- `apply-patches` (11:33): patch 001 applied, Certify back up. The `InsufficientAuthenticationException` seen on the first laptop appears here too right after start, so it is not machine specific.
- Wallet toolchain: Temurin 17 not found at first (finder rewritten to search registry, vendor folders and PATH); SDK packages installed after the `sdkmanager` to `android` CLI change was handled.
- First build failed moving Gradle's `dependencies-accessors` workspace (two concurrent Gradle processes, rename blocked). After closing Android Studio, adding Defender exclusions and stopping daemons, `run-wallet.ps1` built and installed the debug build (14:24).
- Next: first issuance into the wallet from a pre-authorized offer, then the wallet-side baseline.

### First issuance attempt (15:05)
Evidence: `evidence/2026-10-13-first-issuance/logcat.txt` (server logs for this window were not saved)

| Step | Observed |
|---|---|
| Offer scan, metadata, issuer trust prompt | OK; issuer `https://signing-regulated-grain-prior.trycloudflare.com` |
| Token request (pre-authorized code) | OK, Bearer token issued |
| Key selection | `proofSigningAlgosSupported` from metadata; wallet picked a P-256 key (ES256) from the Android Keystore; private key not exportable |
| First signature | `KeyStoreException: Key user not authenticated` (keystore code -26): the key requires user authentication; the keystore library then ran the biometric prompt and signing succeeded |
| Credential request | Rejected by Certify: `ERROR_FETCHING_IDENTITY_DATA` |

- Cause: Certify was configured with `MockCSVDataProviderPlugin`, which ignores the claims attached to the pre-authorized offer and looks the holder up in the CSV by token subject. Certify core ships `PreAuthDataProviderPlugin`, which returns the cached offer claims. Switched to it (configuration only).
- Observation for F3/F9: the holder proof key is a hardware-backed P-256 key bound to user authentication; every proof needs a biometric or device credential. Algorithm choice is driven by the issuer's `proof_signing_alg_values_supported` (RS256, ES256).
- Server side of the failed attempt captured as well (nginx shows offer, metadata and token 200, credential request 400); see the evidence README.
- After `restart-issuer` with `PreAuthDataProviderPlugin` (about 15:10): FarmerCredential downloaded and shown in the wallet. First end-to-end issuance on this stack. Not captured; capture on the next run.

### First verification (about 15:12)
Evidence: `evidence/2026-10-13-first-verification/`
- Wallet QR uploaded to Inji Verify: "the given credential is valid". All 14 claims shown, so patch 001 holds end to end.
- Unmodified Certify, wallet and Verify interoperate with Ed25519Signature2020 over `did:web`. Phase 1 runtime baseline complete. D-07 (`assertionMethod` lists the DID) did not stop Inji Verify; still to test against an external verifier (D-03).

---

## 2026-10-11 (Sun)

### Full stack green
- `start` (21:29) with the restart policy in place: all 8 local endpoints 200 (Certify, nginx, Mimoto, Verify UI, Inji Web); both tunnels registered; all public endpoints 200.
- Issuer DID: `did:web:operator-breakfast-painting-favors.trycloudflare.com`. Mimoto: `https://unlimited-rebecca-display-though.trycloudflare.com`.
### Test device
| Property | Value |
|---|---|
| Model | Google Pixel 7 (serial 33010DLH2000KY) |
| Android | 17 |
| Security patch | 2026-09-05 |
| StrongBox keystore | yes (`android.hardware.strongbox_keystore` = true) |
| Connection | USB, ADB authorised |

- The wallet targets API 35 (Android 15) and runs here under Android 17; platform behaviour changes between 15 and 17 are a possible confound for keystore observations and are noted for the analysis.
- Inji Wallet v0.22.1 debug build (`residentappDebug`) installed and running on the Pixel 7 (21:54), JavaScript served by Metro over USB.
- Next: first issuance from the pre-authorized offer.

---

## 2026-10-10 (Sat)

### Wallet toolchain
- Installed Node 22.23.2 and Android Studio (winget). Setup check: Git and Node OK; Android SDK not yet present (first-run wizard not completed); Android Studio's bundled JDK is 25.
- JDK 25 is outside what Gradle 8.6 (wallet build) supports. Added `env/wallet/find-jdk.ps1` to select a JDK 17 to 21 explicitly; the setup now fails with an actionable message instead of a warning. Temurin 17 to be installed.
- Installed Temurin 17.0.20 and, through the Android Studio SDK Manager, SDK platform 35, build-tools 35.0.0, NDK 21.4.7075529, command-line tools and platform-tools.
- `setup-wallet.ps1` completed (20:50): Inji Wallet v0.22.1 cloned to `C:\dev\inji-wallet`, branch `thesis/crypto-agility` and tag `thesis-baseline` created on the release commit, `.env` pointed at the local Mimoto tunnel, npm dependencies installed.
- First `run-wallet.ps1` started.
- After a laptop restart, `refresh-tunnels` (20:53) produced new tunnels (issuer DID `did:web:boot-obligation-pope-acrobat.trycloudflare.com`); Certify endpoints OK, Mimoto tunnel 502. `check` (21:09) showed Mimoto, Inji Web and Verify not running: no restart policy. Added `restart: unless-stopped` to all services and made `refresh-tunnels` start the full stack.

---

## 2026-10-09 (Fri)

### Stack moved to the repository
- Stopped the previous stack and started it from `env/stack` (15:18). New tunnels; issuer DID now `did:web:cardiac-poor-which-springs.trycloudflare.com`. All public endpoints OK; database and issuer keys carried over.
- Applied SQL patch 001 (15:21). The next offer attempt no longer failed on claims but on `credentialOfferCache not available`: the cache list in the configuration inherited from the injistack compose predates Certify 0.14.0. Aligned the cache configuration with the 0.14.0 defaults.
- After `restart-issuer`, `issue-offer` succeeded: Certify returned a pre-authorized FarmerCredential offer (OpenID4VCI `credential_offer_uri`), rendered as a QR code. Server-side issuance path confirmed; the wallet is the next component.

### Repository restructure
- Consolidated the environment (`env/`), Phase 1 analysis and evidence into this single repository under version control.
- Replaced ad hoc scripts with one entry point, `env/stack/stack.ps1 <command>`, which logs every run to `env/stack/logs/`.
- Pinned `cloudflared` to 2026.9.3 (was `latest`).
- Moved environment fixes from inline comments into `known-issues.md`.

### Issuer baseline captured
Evidence: `evidence/2026-10-09-issuer-baseline/`

| Item | Observed |
|---|---|
| Issuer DID | `did:web:should-waters-mens-incomplete.trycloudflare.com`, one `Ed25519VerificationKey2020` method (`publicKeyMultibase`) |
| `assertionMethod` | Lists the DID itself rather than the verification method id. To check against DID Core and against what verifiers expect |
| FarmerCredential | `ldp_vc`, signed with `EdDSA` (`Ed25519Signature2020`) |
| Holder binding | `did:jwk` |
| Accepted holder proof algorithms | `jwt`: `RS256`, `ES256` only |
| Issuer JWKS | 5 keys: RSA x2, Ed25519, secp256k1, P-256 |
| OAuth AS | Certify itself; grants `authorization_code` and `pre-authorized_code`; PKCE S256 |

Observation: the proof algorithm list (RS256, ES256) matches exactly the two wallet key types generated in the Android hardware keystore. The wallet's Ed25519 and secp256k1 software keys cannot be used for this credential. The restriction is set in issuer configuration (`credential_config.proof_types_supported`), not in code. Recorded as Phase 1 finding F9.

### Test credential offer
- `issue-offer` failed with `unknown_claims`. Certify validates offer claims against `credential_config.credential_subject`, which in the upstream seed declares only `fullName`, `phone`, `dateOfBirth`, `gender`, while the CSV data provider supplies 14 claims.
- Added `env/stack/sql/patches/001-farmer-credential-subject.sql` to declare all 14 claims. Configuration only; no Certify code changed. Also applied to the seed in `certify_init.sql` for fresh databases.

### Tunnels and issuer reachability
- Quick tunnels created on 8 Oct had been deleted by Cloudflare after the host slept (`Unauthorized: Tunnel not found`); containers still reported Running. Tunnel refresh now detects this and recreates them.
- After Certify was recreated, `certify-nginx` returned 502 for the DID and metadata: nginx had cached the previous container address. Scripts now restart nginx after any Certify restart.
- Final state (14:57): all local endpoints 200; issuer metadata, OAuth metadata, issuer DID and Mimoto reachable through the tunnels.

### Issuer keys
- Certify failed to start (`KER-KMA-004 No such alias`): the database held key aliases from 2 Oct but the PKCS#12 keystore was gone. Its path was relative, so it had been written inside the container and lost when the container was recreated.
- Keystore path made absolute (`/home/mosip/CERTIFY_PKCS12/local.p12`, on the bind mount); key tables cleared; Certify regenerated keys. Keystore now persists on the host.

---

## 2026-10-08 (Thu)

### Phase 1 static baseline
- Pinned ten repositories and recorded commit hashes in `phase1-dependency-analysis/manifest.tsv`. Wallet v0.22.1 is the anchor; native library versions taken from its `build.gradle`; Certify and Verify versions match the official injistack compose file.
- Note: version numbers are not monotonic in time. `mimoto` v1.2.0 dates from 2022; v0.22.0 from 2026.
- Built a regex-based scanner (`tools/rules.yaml`, `tools/scan.py`). First pass: 3,269 production hits, 919 seeded inventory rows. Two rule corrections during the pass: trailing word boundaries missed `Ed25519Signature2020` and similar identifiers; SBOM files produced false post-quantum hits and are now excluded.
- Read the main bindings in source and recorded findings F1 to F8 (`phase1-dependency-analysis/findings.md`).

### Stack bring-up
- `docker compose up` succeeded but Certify was not serving and Mimoto reported health DOWN. Layered checks (containers, local ports, tunnels) isolated the cause to the services, not the tunnels.
- Mimoto health DOWN came from a Redis check (no Redis in this stack) and a key alias check; neither affects serving. Readiness is now checked with `/v1/mimoto/issuers`.
- Wallet setup script confirmed to clone v0.22.1 and place the `thesis-baseline` tag on that commit.

---

## 2026-10-04 (Sun)

### Environment design
- Confirmed the laptop runs Docker Desktop with WSL2 and virtualization enabled.
- Built the server environment from Certify's injistack compose; added Inji Verify; replaced the eSignet dependency with Certify's own pre-authorized code flow.
- Added Cloudflare quick tunnels: Android blocks cleartext HTTP and `did:web` needs a public HTTPS host.
- Prepared wallet setup scripts targeting `C:\dev\inji-wallet` (short path for Windows path limits).
- Observed: Certify has no admin UI; credential types are rows in `credential_config`; signing algorithm is set per credential type.
- Observed: `shared/cryptoutil/KeyTypes.ts` in the wallet is a closed enum of four algorithms.

---

## 2026-10-01 (Wed)

### Planning
- Mapped Inji's cryptographic surfaces: secure-keystore (S1), VCI client and OpenID4VP (S3), vc-verifier (S3), Tuvali BLE transfer with X25519 (S4).
- Decided to use a physical Android phone rather than an emulator, since hardware keystore behaviour is itself a finding.
