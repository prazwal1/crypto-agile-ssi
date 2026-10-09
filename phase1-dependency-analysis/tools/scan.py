#!/usr/bin/env python3
"""Phase 1 first-pass crypto-binding scanner.

Runs every rule in rules.yaml over every repo in repos/ with ripgrep and writes:
  results/hits.csv       one row per match (raw evidence, machine generated)
  results/summary.csv    counts per repo x surface x algorithm
  results/inventory.csv  seeded inventory: one row per (repo, file, rule), with the
                     hand-scored columns left blank for Phase 1 review

Usage: python -I tools/scan.py [phase1_root]   (requires ripgrep on PATH and PyYAML)
"""
import csv, json, os, re, subprocess, sys
from collections import Counter, defaultdict
import yaml

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), ".."))
REPOS = os.path.join(ROOT, "repos")
OUT = os.path.join(ROOT, "results")
RULES = yaml.safe_load(open(os.path.join(ROOT, "tools", "rules.yaml")))["rules"]

GLOBS = ["!**/node_modules/**", "!**/*.lock", "!**/package-lock.json", "!**/yarn.lock",
         "!**/locales/**", "!**/*.md", "!**/*.svg", "!**/*.png", "!**/*.jpg", "!**/*.snap",
         "!**/build/**", "!**/dist/**", "!**/.git/**", "!**/docs/**", "!**/*.min.js",
         "!**/THIRD-PARTY-NOTICES.txt", "!**/licenses/**", "!**/*.html", "!**/sbom*", "!**/*.map", "!**/*.cdx.json"]

CONFIG_EXT = (".properties", ".yml", ".yaml", ".json", ".env", ".sql", ".xml", ".gradle", ".toml", ".plist", ".conf")
TEST_RE = re.compile(r"(/test/|/tests/|__tests__|__mocks__|\.test\.|\.spec\.|Test\.kt$|Test\.java$|/androidTest/|/mock)", re.I)

# Path-based surface overrides (first match wins). Tuned for the Inji repos.
PATH_SURFACE = [
    (re.compile(r"^tuvali/|/ble/|Tuvali", re.I), "S4"),
    (re.compile(r"secure-keystore|/keystore|KeyStore|keyManagement|/cryptoutil/", re.I), "S1"),
    (re.compile(r"/did|DidDocument|DIDDocument|verificationmethod|/resolver", re.I), "S2"),
    (re.compile(r"openid4vp|vci-client|/vci/|/openID4VP|/proof", re.I), "S3"),
    (re.compile(r"vc-verifier|/verifier/|signatureverifier|proofverifier", re.I), "S3"),
]
# Which outside party must understand a binding on each surface (for the boundary column).
SURFACE_PARTY = {"S1": "none (wallet internal)", "S2": "every verifier / DID resolver",
                 "S3": "issuer and verifier", "S4": "the two parties in the exchange"}


def surface_for(repo_rel, rule_surface):
    for rx, s in PATH_SURFACE:
        if rx.search(repo_rel):
            # an explicit rule surface for S2/S4 is stronger than a path guess
            return rule_surface if rule_surface in ("S2", "S4") else s
    return rule_surface or "?"


def run_rule(rule, repo):
    cmd = ["rg", "--json", "-n", "--no-messages", "-e", rule["regex"]]
    for g in GLOBS:
        cmd += ["-g", g]
    cmd.append(os.path.join(REPOS, repo))
    p = subprocess.run(cmd, capture_output=True, text=True)
    for line in p.stdout.splitlines():
        ev = json.loads(line)
        if ev.get("type") != "match":
            continue
        d = ev["data"]
        path = d["path"].get("text", "")
        text = d["lines"].get("text", "").strip()
        if len(text) > 400:  # minified / data blobs
            continue
        yield os.path.relpath(path, REPOS), d["line_number"], text, [s["match"]["text"] for s in d["submatches"]]


def main():
    os.makedirs(OUT, exist_ok=True)
    repos = sorted(d for d in os.listdir(REPOS) if os.path.isdir(os.path.join(REPOS, d)))
    hits = []
    for repo in repos:
        for rule in RULES:
            for rel, ln, text, matched in run_rule(rule, repo):
                path_in_repo = rel.split("/", 1)[1] if "/" in rel else rel
                surface = surface_for(rel, rule["surface"])
                hits.append({
                    "repo": repo, "file": path_in_repo, "line": ln, "rule": rule["id"], "kind": rule["kind"],
                    "algorithm": rule["algorithm"], "matched": "|".join(sorted(set(matched))),
                    "surface_guess": surface,
                    "binding_guess": "config" if path_in_repo.lower().endswith(CONFIG_EXT) else "code",
                    "is_test": "yes" if TEST_RE.search("/" + path_in_repo) else "no",
                    "snippet": text,
                })

    fields = list(hits[0].keys()) if hits else []
    with open(os.path.join(OUT, "hits.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields); w.writeheader(); w.writerows(hits)

    prod = [h for h in hits if h["is_test"] == "no"]
    cnt = Counter((h["repo"], h["surface_guess"], h["algorithm"] or h["rule"]) for h in prod)
    with open(os.path.join(OUT, "summary.csv"), "w", newline="") as f:
        w = csv.writer(f); w.writerow(["repo", "surface_guess", "algorithm_or_rule", "hits"])
        for k, v in sorted(cnt.items()):
            w.writerow([*k, v])

    # Seeded inventory: collapse to one row per (repo, file, rule), production code only.
    groups = defaultdict(list)
    for h in prod:
        groups[(h["repo"], h["file"], h["rule"])].append(h)
    inv_fields = ["id", "repo", "file", "lines", "rule", "algorithm", "matched", "surface", "binding",
                  "coupling_type", "crosses_trust_boundary", "external_party", "evidence", "status", "notes"]
    with open(os.path.join(OUT, "inventory.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=inv_fields); w.writeheader()
        for i, ((repo, file, rule), hs) in enumerate(sorted(groups.items()), 1):
            s = hs[0]["surface_guess"]
            w.writerow({
                "id": f"D{i:04d}", "repo": repo, "file": file,
                "lines": ",".join(str(h["line"]) for h in hs[:15]) + (" ..." if len(hs) > 15 else ""),
                "rule": rule, "algorithm": hs[0]["algorithm"],
                "matched": "|".join(sorted({m for h in hs for m in h["matched"].split("|")}))[:120],
                "surface": s, "binding": hs[0]["binding_guess"],
                "coupling_type": "",            # creation / operation / provider (hand-scored)
                "crosses_trust_boundary": "",   # yes / no (hand-scored)
                "external_party": SURFACE_PARTY.get(s, ""),
                "evidence": hs[0]["snippet"][:160],
                "status": "auto", "notes": "",
            })

    print(f"repos={len(repos)} rules={len(RULES)} hits={len(hits)} prod_hits={len(prod)} inventory_rows={len(groups)}")


if __name__ == "__main__":
    main()
