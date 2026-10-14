# D-01 draft: the classical baseline algorithm set

Status: draft for PB decision. Question (decisions.md D-01): include RS256 and ES256K in the
baseline, or justify excluding them. "Baseline" = the classical algorithms the Crypto Service
Layer (CSL) must already handle before any post-quantum algorithm is added, i.e. the "before" state
the migration starts from.

## What the running prototype actually exercises

| Algorithm | Where it runs (evidence) | Key storage |
|---|---|---|
| Ed25519 (EdDSA) | VC proof `Ed25519Signature2020` (F10, reference run); OpenID4VP request objects, VP proof, SD-JWT KB-JWT (F20, presentation trace); holder issuance proof in both ldp_vc and SD-JWT runs | wallet software (@noble); issuer software key |
| ES256 (P-256) | holder proof for FarmerCredential ldp_vc (F3, F9); SD-JWT issuer signature (D-02, F25) | wallet Android hardware keystore; issuer keymanager |
| RS256 (RSA-2048) | Certify access token (F20); keymanager master-key hierarchy and certificate chain (F14); SD-JWT issuer certificate root (F25) | issuer keystore / master keys |
| X25519 | OpenID4VP response encryption (ECDH-ES), Tuvali BLE (F7, F20) | software |

Ed25519, ES256 and RS256 each appear in at least one signed artefact of the running system.
ES256K does not.

## The case for each algorithm

**Ed25519** — not in question. It is the default VC suite, the only request-object algorithm the
wallet accepts, and the holder binding key in every run. Must be in the baseline.

**ES256 (P-256)** — in question only in name. It is the one hardware-backed signing key exercised
(StrongBox, user-auth gated, F3) and the SD-JWT issuer algorithm. Must be in the baseline.

**RS256** — argued include. It is not a VC proof suite here, but it signs the access token that
every issuance depends on (F20), and the whole issuer key hierarchy and certificate chain are RSA
(F14). A migration that ignores RS256 leaves a classical signature in the OAuth layer and classical
protection under every "migrated" key. The wallet also has RS256 as a hardware key type (F3).
Recommendation: include.

**ES256K (secp256k1)** — argued exclude from the demonstrated baseline, keep in the registry
inventory. For: it is a wallet key type (F1), it is in Mimoto's negotiation priority list (F19),
vc-verifier accepts it (F6, F18), and Certify config maps cryptosuites to it (F21). Against: it is
software-only (no hardware path, F3), no credential or transport in the running flow uses it, it is
a Koblitz/blockchain curve outside the W3C ECDSA cryptosuite definitions (F21 is exactly this
drift), and including it adds a migration target with no counterpart in the demonstrated system.
Recommendation: exclude from the end-to-end migration demonstration, but keep it in scope for the
coupling inventory and the CBOM (the agility mechanism must still enumerate and route it, because it
exists in the registries), and say so explicitly.

## Proposed baseline (for decision)

| Decision option | Baseline set | Trade-off |
|---|---|---|
| A (recommended) | Ed25519, ES256, RS256 | Covers every algorithm the running system signs with; ES256K documented as present-but-not-demonstrated |
| B | Ed25519, ES256, RS256, ES256K | Complete over the wallet's four key types; adds a migration target with no running counterpart and no hardware path |
| C | Ed25519, ES256 | Smallest; drops RS256, but RS256 still runs in the OAuth and key-protection layers, so the "before" state would be understated |

Option A keeps the baseline equal to what the prototype demonstrably does, which is the cleanest
story for RQ1 to RQ4: every baseline algorithm has a runtime trace, and ES256K is named as a known
registry entry the agility mechanism must handle without being a migration target.

PB decision: ______  (A / B / C / other). Once decided, this becomes a closed decision and the
baseline column feeds the RQ1 narrative and the Phase 4 migration scope.
