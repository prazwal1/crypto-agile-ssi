# Phase 1 Findings: Cryptographic Dependency Analysis (RQ1)

Baseline: `manifest.tsv`. Static findings (F1 to F8) were confirmed by reading the source, not only by scanner matches. Runtime findings (F9 onward) cite files in `../evidence/`.

| # | Surface | Finding | Evidence | Why it matters |
|---|---|---|---|---|
| F1 | S1/S3 | Wallet key types are a closed enum of four: RS256, ES256, ES256K, Ed25519 | `inji-wallet/shared/cryptoutil/KeyTypes.ts` | Adding ML-DSA means extending this enum first |
| F2 | S1 | Key type selection is spread over 5 production files with 58 `KeyTypes.` references | `cryptoUtil.ts`, `constants.ts`, `openId4VCI/Utils.ts`, `openID4VP/OpenID4VPHelper.ts`, `machines/openID4VP/openID4VPModel.ts` | Baseline value for P1 and the "files touched" metric |
| F3 | S1 | Two key storage paths: RS256 and ES256 keys are generated in the Android hardware keystore (`RNSecureKeystoreModule`, `secp256r1`); ES256K and Ed25519 are generated in JS with `@noble` libraries, i.e. software keys | `cryptoUtil.ts` (`generateKeyPairRSA`, `generateKeyPairECR1` vs `generateKeyPairECK1`, `generateKeyPairED`); `secure-keystore/.../KeyGeneratorImpl.kt:103` | Android Keystore has no ML-DSA, so a PQ key must take the software path. The architecture needs a provider split (hardware vs software), not just an algorithm switch |
| F4 | S3 | Mimoto already has a partial strategy pattern: `SigningAlgorithmHandler` + `SigningAlgorithmHandlerFactory` with one handler per algorithm, backed by a closed `SigningAlgorithm` enum | `mimoto/src/main/java/io/mosip/mimoto/util/factory/`, `constant/SigningAlgorithm.java` | Precedent inside the codebase; the CSL can extend it rather than replace it. Relevant to RQ2 and to honest baseline scoring |
| F5 | S3 | The Mimoto factory is bypassed in at least two places: `JWSAlgorithm.EdDSA` hard-coded for presentations, and RSA/RS256 hard-coded in `JoseUtil` | `WalletPresentationServiceImpl.java:320`, `JoseUtil.java:163-168` | Operation coupling that survives the existing abstraction; a concrete P1 target |
| F6 | S3 | vc-verifier has its own `SignatureFactory` and proof-type constants (Ed25519Signature2018/2020, JsonWebSignature2020, RS256, PS256, ES256, ES256K, EdDSA) | `vc-verifier/.../signature/SignatureFactory.kt`, `constants/CredentialVerifierConstants.kt` | A second, independent algorithm list. The wallet and its verifier library must agree, so a new algorithm has at least two registries to update |
| F7 | S4 | Tuvali (BLE offline transfer) uses X25519 key agreement, HKDF-SHA256 and AES-GCM via BouncyCastle lightweight API | `tuvali/kotlin/android/.../cryptography/CryptoBoxImpl.java`, `KeyGenerator.java`, `CipherBoxImpl.java` | X25519 is quantum-vulnerable; out of prototype scope (signatures only) but record it in the CBOM |
| F8 | n/a | BouncyCastle with PQC classes (Dilithium, Falcon, Kyber, composite Falcon+P-256) is already on Inji Verify's classpath, per its SBOM | `inji-verify/sbom-clean.json` | Not used by code, but shows a JVM ML-DSA provider is already a transitive dependency; useful for the Phase 4 provider choice |
| F9 | S1/S3 | The deployed FarmerCredential accepts holder proofs signed with RS256 or ES256 only, and binds the holder with `did:jwk`. These are exactly the two wallet key types held in the Android hardware keystore (F3); the Ed25519 and secp256k1 software keys cannot be used for this credential. The restriction is issuer configuration (`credential_config.proof_types_supported`), not code | `../evidence/2026-10-09-issuer-baseline/issuer-meta.json`; `env/stack/sql/certify_init.sql` | Algorithm choice is constrained by the counterparty's published metadata, not only by wallet code. A post-quantum holder key needs issuer-side configuration to be accepted (negotiation, RQ2) |

## Open scope question

The wallet supports RS256 and ES256K as well as Ed25519 and ES256; the proposal baseline covers Ed25519 and P-256. Tracked as D-01 in `../docs/decisions.md`. F9 is relevant: the deployed credential accepts RS256.

## First-pass scan numbers (production code, tests excluded)

Scanner output after excluding SBOMs: 3,269 production hits, 919 seeded inventory rows across 10 repositories (`results/`).
These are locations to review, not dependencies. Expect a large share of VC-FORMAT, LIB and
DID-METHOD rows in Certify to be config or seed data that collapses into a few real bindings.

## Remaining Phase 1 work

- Hand-score `results/inventory.csv` (coupling type, trust boundary, status)
- Runtime trace of one issuance and one presentation on the laptop stack, to confirm which of the
  four wallet key types the default flow actually uses
- Confirm whether Inji supports SD-JWT VC end to end (D-02)
- Map Certify's signing path through MOSIP keymanager (not yet cloned)
- Resolve the Mimoto image/source version mismatch (D-05) before runtime tracing
- Export verified rows to a CycloneDX CBOM
