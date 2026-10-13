# Phase 1: Cryptographic Dependency Analysis

Answers RQ1: where, and how tightly, the Inji stack binds to specific cryptographic algorithms.

| Path | Contents |
|---|---|
| `manifest.tsv` | Pinned repositories: name, tag, commit, date, role, treatment |
| `tools/clone-baseline.ps1`, `.sh` | Clone every repository at its tag into `repos/` and verify the commit |
| `tools/rules.yaml` | Scanner rule catalog: algorithm identifiers, proof suites, verification-method encodings, crypto API call sites, libraries |
| `tools/scan.py` | Runs the rules with ripgrep and writes `results/` |
| `results/hits.csv` | Every match, including tests (raw, generated) |
| `results/summary.csv` | Production matches per repository, surface and algorithm |
| `results/inventory.csv` | Seeded inventory, one row per repository, file and rule; hand-scored columns blank |
| `issuer-signing-path.md` | Certify to keymanager signing trace: call chain, key types, key hierarchy, registries |
| `findings.md` | Findings confirmed by reading source or captured at runtime |
| `repos/` | Pinned clones (not versioned; recreate with `clone-baseline`) |

## Surfaces

| Surface | Meaning |
|---|---|
| S1 | Key generation and storage |
| S2 | Verification method and DID document encoding |
| S3 | Proof suites, credential formats, issuance and presentation proofs |
| S4 | Transport and key agreement (offline BLE transfer) |

## Inventory columns

| Column | Filled by | Values |
|---|---|---|
| `id`, `repo`, `file`, `lines`, `rule`, `algorithm`, `matched`, `evidence` | scanner | |
| `surface`, `binding` | scanner guess, confirmed by hand | S1 to S4; code or config |
| `coupling_type` | hand | creation, operation or provider (Rameshan and Messmer) |
| `crosses_trust_boundary` | hand | yes or no |
| `external_party` | scanner default per surface, confirmed by hand | who must understand the algorithm |
| `status` | hand | auto, verified, false-positive |
| `notes` | hand | |

Only `verified` rows are cited in the thesis or exported to the CBOM.

## Limits

- Regex matching locates candidate bindings; it does not follow data flow. Each cited finding is confirmed by reading the code.
- Surface assignment is a path-based guess; 364 of 919 rows have no guess and are assigned during review.
- iOS paths are scanned, but the prototype is Android only.
- Certify signs through MOSIP keymanager (Maven dependency, v1.4.0 per Certify's pom). Pinned in `manifest.tsv` and traced by hand in `issuer-signing-path.md`; the scanner inventory predates it and does not include keymanager.
