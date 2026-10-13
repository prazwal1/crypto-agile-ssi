# Inventory review, 2026-10-13 21:31 to 21:40 ICT

Scoring of all 919 rows of `phase1-dependency-analysis/results/inventory.csv`
(SHA-256 `c83896cb0492107f5db5bfa9dae0e507ae7a0c631b8e8e3fe53e4ccfb05da841`, scan of 2026-10-08)
against the pinned clones in `manifest.tsv`. Reviewer: Claude, for PB to spot-check.

## How it was produced

| Step | Action | Output |
|---|---|---|
| 1 | Profiled the inventory by repo, rule, file type and top-level folder | Noise classes: test rigs, samples, build files, upstream deployment config |
| 2 | Pass 1, scripted: `file_class` from the path (rules in `tools/score_inventory.py`) | 341 rows in test, build, deployment-config and doc files get a status without being read |
| 3 | Pass 2, by hand: for each of the 245 remaining files, read the matched lines (and surrounding code where needed) in the pinned clone and wrote one judgement line | `phase1-dependency-analysis/review/judgements.tsv` |
| 4 | Grouped verified files into bindings: one binding = one place where the system depends on an algorithm choice | `review/bindings.tsv` (35 bindings) |
| 5 | `python3 tools/score_inventory.py` (fails if any source or config row lacks a judgement) | `results/inventory-scored.csv`, `results/bindings.csv`, `results/review-summary.txt` |
| 6 | Extracted the code behind new findings F17 to F20 and other key judgements | `citations.tsv`, `excerpts.md` here (`tools/cite.py`) |
| 7 | Drew a seeded stratified sample of 20 rows for PB to check | `review/spot-check.csv` |
| 8 | Re-ran steps 5 and 6 on the laptop: outputs identical | |

One correction during the review: the first deployment-config rule matched any path with a
`config/` folder and so caught four production Java files (`AppConfig`, `SecurityConfig`,
`KeyManagerConfig`); the rule now excludes code files and those files were reviewed by hand.

## Results

| Status | Rows | Meaning |
|---|---|---|
| verified | 446 | Real algorithm dependency, confirmed in code |
| excluded-test | 249 | Test rigs and test data (pass 1) |
| upstream-deployment-config | 58 | Upstream docker-compose, helm, SQL seeds (deployed values are in `env/stack`) |
| excluded-sample | 50 | Example and sample apps |
| format-only | 39 | Credential format dispatch, no algorithm |
| false-positive | 29 | Names, comments, Hex encoders, Gson from Nimbus's shaded copy |
| build-dependency | 26 | Library declarations (input to the CBOM) |
| non-signature | 13 | Hashing, AES, HMAC, PBKDF2 (kept for the CBOM) |
| dead-code | 9 | Not imported by production code |

446 verified rows collapse into 35 bindings across 9 repositories. Verified rows by surface:
S3 248, S1 110, S2 68, S4 20; by coupling type: operation 243, creation 170, provider 33;
241 cross a trust boundary.

## Limits

- Judgements are per file: every row of a file takes the file's verdict. Mixed files are
  noted in the judgement (e.g. `CertifyIssuanceServiceImpl.java`, whose rows are format
  dispatch while its signing calls are covered by the issuer signing trace).
- Coupling type follows Rameshan and Messmer's three types; where a file both selects and
  invokes an algorithm, the dominant role is recorded.
- iOS files are reviewed but the prototype is Android only.
- Keymanager is not in the scanner inventory; it is covered by `../2026-10-13-issuer-signing-trace/`.
