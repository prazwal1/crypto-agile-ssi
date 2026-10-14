# D-07: issuer DID document conformance (2026-10-14)

Document under test: `issuer-did.json` (copy of `evidence/2026-10-13-issuer-baseline/did.json`),
served at `https://ssi-issuer.arlabsnepal.com/.well-known/did.json`.

## The mismatch

| Field | Value |
|---|---|
| `verificationMethod[0].id` | `did:web:ssi-issuer.arlabsnepal.com#cvu2BxpFAd7kCDFHfOGYgYMLl_2-BlTR9V09m9re8Tc` |
| `verificationMethod[0].type` | `Ed25519VerificationKey2020` |
| `assertionMethod[0]` | `did:web:ssi-issuer.arlabsnepal.com` (the bare DID) |
| `authentication[0]` | `did:web:ssi-issuer.arlabsnepal.com` (the bare DID) |

Credentials are signed with `verificationMethod` = `did:web:ssi-issuer.arlabsnepal.com#cvu2...`
(seen in every VC proof, `evidence/2026-10-14-presentation-export/`).

## Why it is non-conformant

DID Core 1.0 and Controlled Identifiers v1.0: an entry in a verification relationship
(`assertionMethod`, `authentication`) is either an embedded verification method map or a DID-URL
string that **references a verification method** in the document. Dereferencing the bare DID
`did:web:ssi-issuer.arlabsnepal.com` yields the DID document, not a verification method, so neither
relationship names the key that actually signs. A verifier that enforces "the proof's
`verificationMethod` must be authorized for assertion by `assertionMethod`" finds `#cvu2...` in
`verificationMethod` but not in `assertionMethod`, and rejects the credential.

Root cause: `inji-certify` `DIDDocumentUtil.java:62-63` hard-codes both relationships to `didUrl`,
while each verification method is built with id `didUrl + "#" + kid` (`:132`). The two never match.
This is F15.

## Why our runs still passed

MOSIP's own verifiers do not perform the check. `vc-verifier` (1.6.0 and 1.8.1) `LdpVerifier.verify`
resolves the key straight from `ldProof.verificationMethod` via `PublicKeyResolverFactory` and
verifies the signature; nothing compares that method against `assertionMethod` or checks a proof
purpose (`LdpVerifier.kt:43-55`). So both the wallet's verifier and Inji Verify accept the
credential. The gap only bites against a verifier that enforces the verification relationship.

## Decision

The thesis targets interoperability with unmodified external verifiers (C-04), so conformance
matters, but the finished judgement needs the external verifier that D-03 will choose. Recorded as
C-13: keep the deferral, re-test against the D-03 verifier, and treat a conformant DID document as
part of R-10 (standards-conformant key publication). A one-line fix in a fork
(`assertionMethod`/`authentication` referencing the verification-method id) is available if D-03
shows a real rejection.
