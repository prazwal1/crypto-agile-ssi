# Issuer signing trace: source excerpts, 2026-10-13

Supports `../../phase1-dependency-analysis/issuer-signing-path.md` and findings F12 to F16.

## How it was produced

| Step | Action |
|---|---|
| 1 | Read inji-certify v0.14.0 and keymanager v1.4.0 at the commits in `manifest.tsv` (keymanager added to the manifest and cloned into `repos/` for this trace) |
| 2 | Recorded every cited location in `citations.tsv` (id, repo, path, line range, note) |
| 3 | `python3 phase1-dependency-analysis/tools/cite.py evidence/2026-10-13-issuer-signing-trace/citations.tsv evidence/2026-10-13-issuer-signing-trace/excerpts.md` |

| File | Content |
|---|---|
| `citations.tsv` | 24 cited source locations (C1 to C24) |
| `excerpts.md` | The exact lines at each location, with repo, tag and commit |

Runtime corroboration: `../2026-10-13-reference-run/certify.log` (EdDSA QR signing, key aliases
per application id); deployed library versions: `../2026-10-13-certify-image-libs/`.
