# Decisions

Scope and design decisions, with the reasoning at the time. Open items first.

## Open

| ID | Question | Why it matters | Notes |
|---|---|---|---|
| D-01 | Include RS256 and ES256K in the baseline, or justify excluding them | Wallet supports four key types (F1); the proposal baseline covers Ed25519 and P-256 | F9 shows the FarmerCredential accepts only RS256 and ES256 holder proofs, which argues for including RS256 |
| D-02 | Is SD-JWT VC supported end to end in Inji? | Decides whether the commitment-based credential family is in scope | Certify validates `vc+sd-jwt` claims separately from `ldp_vc`; wallet support not yet checked |
| D-03 | Which unmodified external verifier for P3 | Needed for the interoperability evaluation | Decide by M2 rather than M5 |
| D-04 | ML-DSA library for Android/JVM | Phase 4 provider choice | BouncyCastle PQC classes are already a transitive dependency of Inji Verify (F8) |
| D-05 | Mimoto version mismatch: running image 0.21.0, analysed source v0.22.0 | Runtime and static findings must refer to the same code | Either pin the image to 0.22.0 or re-pin the source to v0.21.0 |
| D-06 | Replace quick tunnels with a named Cloudflare tunnel on an owned domain | Quick-tunnel hostnames change, which changes the issuer DID and invalidates issued credentials | Required before collecting Phase 3/4 evidence |
| D-07 | `assertionMethod` in the issuer DID document lists the DID, not the verification method id | May affect strict verifiers | Check against DID Core and the chosen external verifier |

## Closed

| ID | Decision | Date | Reasoning |
|---|---|---|---|
| C-01 | Prototype on MOSIP Inji rather than walt.id | 2026-08 | AIT hosts and uses MOSIP; realistic integration path |
| C-02 | Physical Android phone, not emulator | 2026-10-01 | Hardware keystore behaviour (F3) is part of the findings |
| C-03 | Certify as its own OAuth server (pre-authorized code), no eSignet | 2026-10-04 | eSignet dependency in the reference compose was broken; pre-authorized flow is sufficient for crypto experiments |
| C-04 | Certify and Verify run unmodified; Wallet and Mimoto are the modified side | 2026-10-04 | Unmodified counterparties are needed to demonstrate interoperability |
| C-05 | Wallet v0.22.1 is the version anchor for all pinned repositories | 2026-10-08 | Its `build.gradle` fixes native library versions exactly |
| C-06 | Declare all 14 CSV claims in FarmerCredential's `credential_subject` (patch 001) | 2026-10-09 | Upstream seed declares 4; offers with the CSV claims were rejected. Configuration only |
