# Decisions

Scope and design decisions, with the reasoning at the time. Open items first.

## Open

| ID | Question | Why it matters | Notes |
|---|---|---|---|
| D-01 | Include RS256 and ES256K in the baseline, or justify excluding them | Wallet supports four key types (F1); the proposal baseline covers Ed25519 and P-256 | F9 shows the FarmerCredential accepts only RS256 and ES256 holder proofs, which argues for including RS256 |
| D-02 | Is SD-JWT VC supported end to end in Inji? | Decides whether the commitment-based credential family is in scope | Certify validates `vc+sd-jwt` claims separately from `ldp_vc`; wallet support not yet checked |
| D-03 | Which unmodified external verifier for P3 | Needed for the interoperability evaluation | Decide by M2 rather than M5 |
| D-04 | ML-DSA library for Android/JVM | Phase 4 provider choice | BouncyCastle PQC classes are already a transitive dependency of Inji Verify (F8). Certify image: BouncyCastle 1.78.1, 1.70 and a shaded copy, none with final ML-DSA (F16) |
| D-07 | `assertionMethod` in the issuer DID document lists the DID, not the verification method id | May affect strict verifiers | Check against DID Core and the chosen external verifier. Root cause: hard-coded in `DIDDocumentUtil.java:62-63` (F15). Accepted by both Inji verifiers (F11) |

## Closed

| ID | Decision | Date | Reasoning |
|---|---|---|---|
| C-01 | Prototype on MOSIP Inji rather than walt.id | 2026-08 | AIT hosts and uses MOSIP; realistic integration path |
| C-02 | Physical Android phone, not emulator: Google Pixel 7, Android 17, StrongBox present | 2026-10-01, device fixed 2026-10-11 | Hardware keystore behaviour (F3) is part of the findings; StrongBox allows comparing TEE and StrongBox storage |
| C-03 | Certify as its own OAuth server (pre-authorized code), no eSignet | 2026-10-04 | eSignet dependency in the reference compose was broken; pre-authorized flow is sufficient for crypto experiments |
| C-04 | Certify and Verify run unmodified; Wallet and Mimoto are the modified side | 2026-10-04 | Unmodified counterparties are needed to demonstrate interoperability |
| C-05 | Wallet v0.22.1 is the version anchor for all pinned repositories | 2026-10-08 | Its `build.gradle` fixes native library versions exactly |
| C-06 | Declare all 14 CSV claims in FarmerCredential's `credential_subject` (patch 001) | 2026-10-09 | Upstream seed declares 4; offers with the CSV claims were rejected. Configuration only |
| C-07 | Run Mimoto 0.22.0 to match the analysed source v0.22.0 (closes D-05) | 2026-10-13 | F4/F5 cite v0.22.0 paths and lines; Mimoto is a modified component and should sit on the wallet v0.22.x release line. `injistack/mimoto:0.22.0` is published (2026-04-27, same day as the tag); its default config differs from ours only by `spring.session.store-type=caffeine` |
| C-08 | Named Cloudflare tunnel on `arlabsnepal.com` (`ssi-issuer`, `ssi-mimoto`) instead of quick tunnels (closes D-06) | 2026-10-13 | Fixed issuer DID `did:web:ssi-issuer.arlabsnepal.com`, so issued credentials stay verifiable across runs and evidence refers to one DID. One-level subdomains for Universal SSL. Quick-tunnel mode kept as fallback (no `tunnel.env`) |
| C-09 | Offer creation (`/v1/certify/pre-authorized-data`) and actuator blocked on the public hostname | 2026-10-13 | The endpoint is unauthenticated in Certify; on a permanent public host anyone could mint credentials under the issuer DID. Offers are created on localhost:8090 |
| C-10 | Keep inji-verify v0.17.0 (`3b6f90f`) as the analysed static baseline; runtime evidence comes from the 0.18.2 images (closes D-08) | 2026-10-14 | `git diff v0.17.0 v0.18.2`: of the 18 inventory files, 10 changed but no algorithm, key or suite changed (lists only shifted); F20 citations unchanged. New in 0.18: VP challenge/domain checks. The deployed jar (sha256 `4c049791...`) bundles vcverifier 1.8.1 (pom), not 1.7.0-SNAPSHOT (stale SBOM); vc-verifier 1.6.0 to 1.8.1 diffed and recorded in F8, F18, F23. Re-pinning would move inventory line numbers without changing any finding. Evidence: `evidence/2026-10-14-verify-version-diff/`, `-verify-image-libs/` |
