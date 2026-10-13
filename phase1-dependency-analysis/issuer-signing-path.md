# Issuer signing path: Inji Certify 0.14.0 through MOSIP keymanager 1.4.0

Traced 2026-10-13 by reading source at the pinned commits (`manifest.tsv`): inji-certify v0.14.0
(`e54539a`) and keymanager v1.4.0 (`7c53fc9`, the `kernel.keymanager.version` declared in
Certify's `pom.xml:105`). Runtime cross-check: `../evidence/2026-10-13-reference-run/certify.log`.
Paths below are relative to `certify-service/src/main/java/io/mosip/certify/` (Certify) and
`kernel/kernel-keymanager-service/src/main/java/io/mosip/kernel/` (keymanager).

## Call chain for one `ldp_vc` credential (FarmerCredential)

| Step | Where | What decides the algorithm |
|---|---|---|
| 1 | `credential_config` row (DB) | `signature_crypto_suite` = Ed25519Signature2020, `signature_algo` = EdDSA, `key_manager_app_id` = CERTIFY_VC_SIGN_ED25519, `key_manager_ref_id` = ED25519_SIGN, `qr_signature_algo` = EdDSA |
| 2 | Certify properties | `credential-signing-alg-values-supported` (suite to JWS alg) and `signature-algo.key-alias-mapper` (JWS alg to appId/refId); validated in `services/CredentialConfigurationServiceImpl.java:160-195` |
| 3 | `services/CertifyIssuanceServiceImpl.java:302` | Calls `addProof(..., proofAlgorithm, appID, refID, didUrl, cryptoSuite)` |
| 4 | `credential/W3CJsonLD.java:114-117` | Two branches: if the suite is a Data Integrity cryptosuite known to danubetech `data-integrity-java` for that JWS alg (`findCryptosuitesForJwsAlgorithm`), use `DataIntegrityProof`; otherwise look up a legacy `ProofGenerator` by suite name |
| 5 | `proofgenerators/Ed25519Signature2020ProofGenerator.java:47` | Suite class hard-codes `JWSAlgorithm.EdDSA` and calls keymanager `SignatureServicev2.signv2` |
| 6 | keymanager `signature/service/impl/SignatureServiceImpl.java:640-698` | Loads the key by appId/refId, picks a `SignatureProvider` from `SignatureProviderEnum` by alg; missing alg defaults to PS256 (`:667`); an unknown appId silently switches to the default signing appId/refId (`:282`, `:381`, `:571`) |
| 7 | keymanager `signature/constant/SignatureProviderEnum.java:12` | Closed enum: PS256, RS256, ES256, ES256K (shared EC provider), EdDSA |
| 8 | JCA provider | BouncyCastle `bcprov-jdk18on` 1.78.1 (keymanager `pom.xml:51`); PKCS12 keystore provider `keymanager/hsm/impl/pkcs/PKCS12KeyStoreImpl.java:214` |
| 9 | `utils/DIDDocumentUtil.java:62-63, 109-125` | DID document: `authentication` and `assertionMethod` set to the DID itself; verification-method type chosen by a switch over 4 algs (ES256K, EdDSA, RS256, ES256) |

The QR (Claim 169) signature takes a parallel path: `CertifyIssuanceServiceImpl.java:345-370` maps
`qr_signature_algo` through the same `key-alias-mapper`, then `credential/Credential.java:125`
calls keymanager COSE signing, whose `CoseSignatureServiceImpl.java:404-421` maps JWS names to COSE
algorithm ids with a switch that defaults to PS256 on unknown input.

OAuth access tokens issued by Certify are signed RS256 by a hard-coded value
(`utils/AccessTokenJwtUtil.java:128`, appId CERTIFY_SERVICE).

## How keymanager decides the key type

The key type is encoded in the **reference id string**, not in a parameter:

| refId | Key generated | Where |
|---|---|---|
| (blank) | RSA-2048 (`mosip.kernel.keygenerator.asymmetric-algorithm-name=RSA`, `asymmetric-key-length=2048`) | default branch, `KeymanagerServiceImpl.java:251` |
| `EC_SECP256R1_SIGN` | P-256 | `keymanagerservice/constant/KeyReferenceIdConsts.java`, `ECCurves.java`, map at `KeymanagerServiceImpl.java:169-171` |
| `EC_SECP256K1_SIGN` | secp256k1 | same |
| `ED25519_SIGN` | Ed25519 | special branch `KeymanagerServiceImpl.java:244`, `:372`, `:1368` |

`SignatureAlgorithmIdentifyEnum.java:10` and `SignatureUtil.getSignAlgorithm` (`:217`) map refId back to
an algorithm; both default to RS256/PS256 for anything they do not recognise.

## Key hierarchy

| Layer | Algorithm | Stored |
|---|---|---|
| Root and per-application master keys (e.g. CERTIFY_SERVICE, CERTIFY_VC_SIGN_ED25519) | RSA-2048, certificates `SHA256withRSA` (`mosip.kernel.certificate.sign.algorithm`) | PKCS12 keystore (`local.p12`), on HSM in production |
| Ed25519 signing key (default, `mosip.kernel.keymanager.ed25519.hsm.support.enabled=false`) | Generated in software with BouncyCastle; private key encrypted with the application's RSA master public key (`KeymanagerServiceImpl.java:393`, `:1381`) | Database table `key_store` (`:415`) |
| EC signing keys (P-256, secp256k1) and RSA VC key | Generated in the keystore | PKCS12 keystore |

## Registries that a new signature algorithm must be added to (issuer side)

| # | Registry | Kind | Location |
|---|---|---|---|
| 1 | `credential_config` row | data | Certify DB |
| 2 | `credential-signing-alg-values-supported` | config | Certify properties |
| 3 | `signature-algo.key-alias-mapper` | config | Certify properties |
| 4 | Proof generator class, or a cryptosuite in danubetech `DataIntegritySuites` | code (Certify or external library) | `proofgenerators/`, `W3CJsonLD.java:114` |
| 5 | Verification-method switch | code | `DIDDocumentUtil.java:109` |
| 6 | Reference id constant and curve name | code | `KeyReferenceIdConsts`, `ECCurves`, `KeymanagerServiceImpl.java:169` |
| 7 | Key generation branches (three if-chains on refId) | code | `KeymanagerServiceImpl.java:239-244`, `:709-717`, `:819-820` |
| 8 | `SignatureProviderEnum` and a provider class | code | keymanager `signature/constant`, `service/impl` |
| 9 | `AlgorithmInstanceEnum` | code | keymanager |
| 10 | `SignatureAlgorithmIdentifyEnum`, `SignatureUtil.getSignAlgorithm` | code | keymanager |
| 11 | COSE algorithm switch (QR path) | code | `CoseSignatureServiceImpl.java:404` |
| 12 | JCA provider support | library | BouncyCastle 1.78.1 |

Nine of the twelve are code in two repositories (Certify and keymanager), and keymanager is a
library Certify consumes as a Maven artifact, so an issuer-side algorithm addition means a
keymanager release first.

## Limits

- Read from source at the pinned tags; that the `inji-certify-with-plugins:0.14.0` image bundles
  keymanager 1.4.0 is taken from the pom, not yet confirmed inside the image.
- Production deployments may use PKCS11 HSMs; this trace covers the PKCS12 keystore used here.
