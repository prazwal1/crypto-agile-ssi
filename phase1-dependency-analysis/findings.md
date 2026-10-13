# Phase 1 Findings: Cryptographic Dependency Analysis (RQ1)

Baseline: `manifest.tsv`. Static findings (F1 to F8) were confirmed by reading the source, not only by scanner matches. Runtime findings (F9 onward) cite files in `../evidence/`.

| # | Surface | Finding | Evidence | Why it matters |
|---|---|---|---|---|
| F1 | S1/S3 | Wallet key types are a closed enum of four: RS256, ES256, ES256K, Ed25519 | `inji-wallet/shared/cryptoutil/KeyTypes.ts` | Adding ML-DSA means extending this enum first |
| F2 | S1 | Key type selection is spread over 5 production files with 58 `KeyTypes.` references | `cryptoUtil.ts`, `constants.ts`, `openId4VCI/Utils.ts`, `openID4VP/OpenID4VPHelper.ts`, `machines/openID4VP/openID4VPModel.ts` | Baseline value for P1 and the "files touched" metric |
| F3 | S1 | Two key storage paths: RS256 and ES256 keys are generated in the Android hardware keystore (`RNSecureKeystoreModule`, `secp256r1`); ES256K and Ed25519 are generated in JS with `@noble` libraries, i.e. software keys Runtime: the ES256 proof key is non-exportable and bound to user authentication; every proof signature first fails with `KEY_USER_NOT_AUTHENTICATED` and succeeds after a biometric prompt | `cryptoUtil.ts` (`generateKeyPairRSA`, `generateKeyPairECR1` vs `generateKeyPairECK1`, `generateKeyPairED`); `secure-keystore/.../KeyGeneratorImpl.kt:103`; `../evidence/2026-10-13-reference-run/` (20:22:37) | Android Keystore has no ML-DSA, so a PQ key must take the software path. The architecture needs a provider split (hardware vs software), not just an algorithm switch. A software PQ key would also lose the hardware user-authentication binding seen at runtime |
| F4 | S3 | Mimoto already has a partial strategy pattern: `SigningAlgorithmHandler` + `SigningAlgorithmHandlerFactory` with one handler per algorithm, backed by a closed `SigningAlgorithm` enum | `mimoto/src/main/java/io/mosip/mimoto/util/factory/`, `constant/SigningAlgorithm.java` | Precedent inside the codebase; the CSL can extend it rather than replace it. Relevant to RQ2 and to honest baseline scoring |
| F5 | S3 | The Mimoto factory is bypassed in at least two places: `JWSAlgorithm.EdDSA` hard-coded for presentations, and RSA/RS256 hard-coded in `JoseUtil` | `WalletPresentationServiceImpl.java:320`, `JoseUtil.java:163-168` | Operation coupling that survives the existing abstraction; a concrete P1 target |
| F6 | S3 | vc-verifier has its own `SignatureFactory` and proof-type constants (Ed25519Signature2018/2020, JsonWebSignature2020, RS256, PS256, ES256, ES256K, EdDSA) | `vc-verifier/.../signature/SignatureFactory.kt`, `constants/CredentialVerifierConstants.kt` | A second, independent algorithm list. The wallet and its verifier library must agree, so a new algorithm has at least two registries to update |
| F7 | S4 | Tuvali (BLE offline transfer) uses X25519 key agreement, HKDF-SHA256 and AES-GCM via BouncyCastle lightweight API | `tuvali/kotlin/android/.../cryptography/CryptoBoxImpl.java`, `KeyGenerator.java`, `CipherBoxImpl.java` | X25519 is quantum-vulnerable; out of prototype scope (signatures only) but record it in the CBOM |
| F8 | n/a | BouncyCastle with PQC classes (Dilithium, Falcon, Kyber, composite Falcon+P-256) is already on Inji Verify's classpath, per its SBOM | `inji-verify/sbom-clean.json` | Not used by code, but shows a JVM ML-DSA provider is already a transitive dependency; useful for the Phase 4 provider choice |
| F9 | S1/S3 | The deployed FarmerCredential accepts holder proofs signed with RS256 or ES256 only, and binds the holder with `did:jwk`. These are exactly the two wallet key types held in the Android hardware keystore (F3); the Ed25519 and secp256k1 software keys cannot be used for this credential. The restriction is issuer configuration (`credential_config.proof_types_supported`), not code. Runtime: the wallet received `[RS256, ES256]` from the metadata and signed the proof with a P-256 key (ES256) | `../evidence/2026-10-09-issuer-baseline/issuer-meta.json`; `../evidence/2026-10-13-issuer-baseline/`; `../evidence/2026-10-13-reference-run/` (20:22:36); `env/stack/sql/certify_init.sql` | Algorithm choice is constrained by the counterparty's published metadata, not only by wallet code. A post-quantum holder key needs issuer-side configuration to be accepted (negotiation, RQ2) |
| F10 | S3 | Certify signs a second artefact at issuance: the Claim 169 QR payload, as a CWT, with its own per-credential-type algorithm (`credential_config.qr_signature_algo`, EdDSA in the seed), separate from the VC proof algorithm | `inji-certify/.../CertifyIssuanceServiceImpl.java:282` (`signQrEntries`); `db_scripts/inji_certify/ddl/certify-credential_config.sql:42`; `env/stack/sql/certify_init.sql:205`; `../evidence/2026-10-13-reference-run/certify.log` (13:22:40Z) | A credential carries two issuer signatures with independently configured algorithms. Migrating the VC proof alone leaves a classical signature inside the credential; both need covering in the CBOM and the CSL |
| F11 | S2/S3 | Two independent verifiers act on every credential in the default flow: the wallet verifies on receipt (vc-verifier, F6) and Inji Verify verifies on presentation; each resolves the issuer `did:web` document over HTTPS at verification time. Both accepted an `assertionMethod` that lists the DID rather than the verification method id (D-07) | `../evidence/2026-10-13-reference-run/` (did.json fetched 20:22:48 and 20:23:33; wallet `isVerified: true`); `inji-verify-result.png` | A new proof suite must be understood by both verifier implementations before the wallet will even store a credential; issuer key rotation is visible to both through the DID document |

## Open scope question

The wallet supports RS256 and ES256K as well as Ed25519 and ES256; the proposal baseline covers Ed25519 and P-256. Tracked as D-01 in `../docs/decisions.md`. F9 is relevant: the deployed credential accepts RS256.

## First-pass scan numbers (production code, tests excluded)

Scanner output after excluding SBOMs: 3,269 production hits, 919 seeded inventory rows across 10 repositories (`results/`).
These are locations to review, not dependencies. Expect a large share of VC-FORMAT, LIB and
DID-METHOD rows in Certify to be config or seed data that collapses into a few real bindings.

## Remaining Phase 1 work

- [x] Runtime trace of one issuance and one verification (`../evidence/2026-10-13-reference-run/`): the default flow uses ES256 (F3, F9)
- [x] Mimoto image matches the analysed source (C-07, closes D-05)
- [ ] Hand-score `results/inventory.csv` (coupling type, trust boundary, status)
- [ ] Confirm whether Inji supports SD-JWT VC end to end (D-02)
- [ ] Map Certify's signing path through MOSIP keymanager (not yet cloned)
- [ ] Decide the classical baseline algorithm set (D-01)
- [ ] Export verified rows to a CycloneDX CBOM
- [ ] Phase 1 summary answering RQ1
