# D-08: Inji Verify v0.17.0 (analysed) vs v0.18.2 (running)

Date 2026-10-14. Sources: `git clone https://github.com/mosip/inji-verify` and `https://github.com/mosip/vc-verifier`, tags compared with `git diff`.

| Repo | Analysed | Running | Notes |
|---|---|---|---|
| inji-verify | v0.17.0 `3b6f90f` (2026-03-04) | v0.18.2 `f3f7c75` (2026-07-10) | images `injistack/inji-verify-service:0.18.2`, `-ui:0.18.2` |
| vc-verifier (in verify-service) | v1.6.0 `f3634ba` (wallet's version, `manifest.tsv`) | 1.8.1 per v0.18.2 root `pom.xml` (v0.17.0 used 1.7.0) | wallet still bundles `vcverifier-aar:1.6.0` (`android/app/build.gradle:294`) |
| BouncyCastle (verify-service) | 1.78 | 1.78 | unchanged in pom |
| nimbus-jose-jwt | 9.37.2 | 9.37.4 | patch release |

Files: `inji-verify-summary.txt` (per-file change status of the 18 inventory files), `inji-verify-service-main.diff`, `inji-verify-sdk-config.diff`, `sbom-v0.17.0-vs-v0.18.2.diff`, `vc-verifier-1.6.0-vs-1.8.1-main.diff`, `vc-verifier-1.6.0-vs-1.8.1-stat.txt`.

## Inji Verify: crypto-relevant files

| File (binding) | Change | Effect on findings |
|---|---|---|
| `P12KeyExtractor.java` (B-V2) | unchanged | F20 citation `:55-64` still valid |
| `DIDDocumentUtil.java`, `P12FileKeyManagementServiceImpl.java` (B-V2) | unchanged | none |
| `VCVerificationServiceImpl.java`, `VCVerificationController.java`, `SecurityUtils.java` (B-V1) | unchanged | none |
| `shared/Constants.java` (B-V3) | +1 line (`COOKIE_NAME`) | algorithm lists identical (SD-JWT RS256/ES256/ES256K/EdDSA; ldp suites Ed25519 2018/2020, RSA 2018); line numbers shift by 1 |
| SDK `OpenID4VPVerification.tsx` (B-V3) | +150 -64 | `vp_formats` lists identical; moved from lines 57-66 to 68-77 |
| `VerifiablePresentationRequestServiceImpl.java` (B-V2) | +3 -2 | adds `responseCodeValidationRequired`; no algorithm change |
| `application*.properties` (B-V2) | cookie and response-code settings | no algorithm change |
| `VerifiablePresentationSubmissionServiceImpl.java` (not in inventory) | +304 lines | new: VP `proof.challenge` must equal request nonce and `proof.domain` must equal client_id (`:166-177`) unless unsigned VPs are accepted; split results into `holderProofCheck` and `schemaAndSignatureCheck` |
| `sbom.json` | content identical to v0.17.0 `sbom-clean.json` (only a trailing newline differs) | still lists `vcverifier-jar 1.7.0-SNAPSHOT`, nimbus 9.37.2: the published v0.18.2 SBOM does not describe the v0.18.2 build. F8 rests on it |

## vc-verifier 1.6.0 -> 1.8.1 (algorithm-relevant)

| Area | 1.6.0 | 1.8.1 |
|---|---|---|
| `SignatureFactory.get` | ES256 mapped to `ES256KSignatureVerifierImpl` (secp256k1 verifier for a P-256 alg, `:22`) | ES256 mapped to new `ES256SignatureVerifierImpl` (`:23`) |
| LDP proofValue proofs (`LdpVerifier`) | any `proofValue` verified as Ed25519 (`:57-61`) | algorithm from proof type via `getJwsAlgorithmFromProofType` (`keyResolver/Utils.kt:72-80`); unknown suite throws |
| Accepted proof types | RsaSignature2018, Ed25519Signature2018/2020, EcdsaSecp256k1Signature2019 | + EcdsaSecp256r1Signature2019 |
| Accepted JWS algs (`ALGORITHMS_SUPPORTED`) | PS256, RS256, EdDSA, ES256K | unchanged (ES256 still absent from the JWS allow-list) |
| Presentation verification | VP proof only (Ed25519 2018/2020, JsonWebSignature2020) | adds holder binding (VP holder vs VC subject) and holder proof-of-possession (`PresentationVerifier.kt:176`, `:298-330`); holder keys parsed for Ed25519 and P-256 only (TODO `:332-333`); JsonWebSignature2020 accepts EdDSA, ES256K, ES256 (`:512+`) |
| New formats | ldp_vc, sd-jwt, mso_mdoc | + `cwt_vc`, `jwt_vc_json` verifiers, JWKS key resolver |

## Consequences

1. Inji Verify-side static findings hold at v0.18.2: F20 (Ed25519-only request-signing key) and B-V3 lists are unchanged.
2. F8 cannot rest on the shipped SBOM; the deployed jar is the reference. Inspected in `../2026-10-14-verify-image-libs/`: vcverifier-jar 1.8.1, nimbus 9.37.4, BouncyCastle 1.69, 1.70, 1.78.
3. Two vc-verifier versions are in play: wallet 1.6.0, Inji Verify 1.8.1. F6 and F18 describe 1.6.0 (wallet); for Inji Verify, 1.8.1 fixes the proofValue-as-Ed25519 inference and adds EcdsaSecp256r1Signature2019, so issuer and the two verifiers now disagree differently.
4. 1.6.0 maps ES256 to the secp256k1 verifier: a P-256 JWS would be checked against the wrong curve in the wallet. New detail for F18.
5. The holder-binding check that exposed F23 exists only from vc-verifier 1.8.x; it accepts JsonWebSignature2020 with ES256, so the verifier would accept a P-256 presentation. F23 is a wallet-side limitation.
