# CBOM (CycloneDX 1.6)

`cbom.json`: cryptographic bill of materials for the running prototype. Built by
`tools/build_cbom.py` from `results/inventory-scored.csv` (446 verified rows),
`manifest.tsv`, and the deployed-jar inspections in
`../../evidence/2026-10-13-certify-image-libs/` and `../../evidence/2026-10-14-verify-image-libs/`.
Validated against the CycloneDX 1.6 schema (26 components: 12 cryptographic-assets, 14 libraries).

Every cryptographic-asset has `nistQuantumSecurityLevel: 0`: the prototype contains **no**
post-quantum signature, KEM or key-agreement. Eight assets are quantum-vulnerable (all signatures,
plus X25519, ECDH-ES and RSA-OAEP): Ed25519, RSA-2048, ECDSA P-256, ECDSA secp256k1, ECDSA P-384,
X25519, ECDH-ES, RSA-OAEP. SHA-256, AES-256-GCM, HKDF and PBKDF2 are not quantum-broken (Grover
only halves their strength).

Each asset's `description` and `inji:findings` property point to the findings that evidence it, so
the CBOM and the finding register stay cross-referenced. Regenerate with
`python3 tools/build_cbom.py` after any inventory or image change.
