# Lab Notebook

Dated record of working sessions. Each entry states what was done, what was observed and what changed. Newest entries first. Problems and their fixes are summarised in `known-issues.md`; open questions in `decisions.md`.

---

## 2026-10-10 (Sat)

### Wallet toolchain
- Installed Node 22.23.2 and Android Studio (winget). Setup check: Git and Node OK; Android SDK not yet present (first-run wizard not completed); Android Studio's bundled JDK is 25.
- JDK 25 is outside what Gradle 8.6 (wallet build) supports. Added `env/wallet/find-jdk.ps1` to select a JDK 17 to 21 explicitly; the setup now fails with an actionable message instead of a warning. Temurin 17 to be installed.

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
