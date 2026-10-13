#!/usr/bin/env python3
"""Score results/inventory.csv in two documented passes and write the reviewed inventory.

Pass 1 (scripted): every row is given a file_class from its path (rules below). Rows in
test, build, deployment-config and doc files get a status without being read.
Pass 2 (hand review): rows in source and app-config files take status, binding, coupling
type, surface, trust boundary, external party and notes from review/judgements.tsv, one
line per file written after reading the matched lines in the pinned clones.

The script fails if any source or app-config row has no judgement, so the review is
complete by construction.

Usage: python3 tools/score_inventory.py
Writes: results/inventory-scored.csv, results/bindings.csv, results/review-summary.txt
"""
import collections, csv, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEST = re.compile(r'(^|/)(api-test|ui-test|test|tests|__tests__|commonTest|androidTest|androidUnitTest|jvmTest|iosTest|testData|testdata|sample-application|e2e|mock[s]?)(/|$)|Test\.(kt|java|ts|tsx|swift)$|\.test\.(ts|tsx|js)$|\.spec\.(ts|js)$', re.I)
BUILD = re.compile(r'(^|/)(pom\.xml|build\.gradle(\.kts)?|settings\.gradle(\.kts)?|package\.json|package-lock\.json|Podfile(\.lock)?|Package\.resolved|[^/]*\.toml|jest\.config\.js|babel\.config\.js|metro\.config\.js)$|\.gradle$|\.kts$', re.I)
DEPLOY = re.compile(r'(^|/)(docker-compose|helm|deploy|db_scripts|db_upgrade_script[s]?|postman|config)(/|$)|\.sh$', re.I)
CODE_EXT = re.compile(r'\.(java|kt|ts|tsx|js|swift|m)$', re.I)
DOC = re.compile(r'\.(md|txt|adoc|rst)$|THIRD_PARTY', re.I)
PASS1_STATUS = {'test': 'excluded-test', 'build': 'build-dependency', 'deploy-config': 'upstream-deployment-config', 'doc': 'false-positive'}

def file_class(path):
    if TEST.search(path): return 'test'
    if DOC.search(path): return 'doc'
    if BUILD.search(path): return 'build'
    if DEPLOY.search(path) and not CODE_EXT.search(path): return 'deploy-config'
    if re.search(r'\.(properties|ya?ml|sql|json|hbs|xml)$', path, re.I): return 'app-config'
    return 'source'

def main():
    rows = list(csv.DictReader(open(os.path.join(ROOT, 'results/inventory.csv'))))
    judg = {}
    for line in open(os.path.join(ROOT, 'review/judgements.tsv')):
        if line.startswith('#') or not line.strip(): continue
        f = line.rstrip('\n').split('\t')
        if len(f) != 10: sys.exit(f'bad judgement line ({len(f)} fields): {line[:120]}')
        judg[(f[0], f[1])] = dict(zip(['status', 'binding', 'coupling_type', 'surface', 'crosses_trust_boundary', 'external_party', 'notes'], f[3:]))
    names = {}
    for line in open(os.path.join(ROOT, 'review/bindings.tsv')):
        if line.startswith('#') or not line.strip(): continue
        b, comp, name, desc = line.rstrip('\n').split('\t')
        names[b] = (comp, name, desc)
    missing, out = [], []
    for r in rows:
        cls = file_class(r['file']); r['file_class'] = cls
        if cls in PASS1_STATUS:
            r['status'] = PASS1_STATUS[cls]; r['notes'] = r['notes'] or f'pass 1: {cls} file, not read'
        else:
            j = judg.get((r['repo'], r['file']))
            if not j: missing.append((r['repo'], r['file'])); continue
            r.update({k: ('' if v == '-' else v) for k, v in j.items()})
            r['review_pass'] = '2'
        r.setdefault('review_pass', '1')
        out.append(r)
    if missing: sys.exit('no judgement for: ' + '; '.join(f'{a}:{b}' for a, b in sorted(set(missing))))
    unused = set(judg) - {(r['repo'], r['file']) for r in rows}
    if unused: sys.exit('judgements for files not in inventory: ' + '; '.join(f'{a}:{b}' for a, b in sorted(unused)))
    cols = list(rows[0].keys()) if 'file_class' in rows[0] else []
    cols = ['id', 'repo', 'file', 'lines', 'rule', 'algorithm', 'matched', 'file_class', 'review_pass', 'status', 'binding', 'surface', 'coupling_type', 'crosses_trust_boundary', 'external_party', 'evidence', 'notes']
    with open(os.path.join(ROOT, 'results/inventory-scored.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=cols, extrasaction='ignore'); w.writeheader(); w.writerows(out)
    # bindings
    agg = collections.OrderedDict()
    for r in out:
        b = r.get('binding') or ''
        if r['status'] not in ('verified', 'non-signature') or not b: continue
        a = agg.setdefault(b, {'files': set(), 'rows': 0, 'surface': set(), 'coupling': set(), 'trust': set(), 'party': set(), 'algs': set(), 'status': set()})
        a['files'].add(r['file']); a['rows'] += 1; a['surface'].add(r['surface']); a['coupling'].add(r['coupling_type'])
        a['trust'].add(r['crosses_trust_boundary']); a['party'].add(r['external_party']); a['status'].add(r['status'])
        if r['algorithm']: a['algs'].add(r['algorithm'])
    with open(os.path.join(ROOT, 'results/bindings.csv'), 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['binding', 'component', 'name', 'status', 'files', 'rows', 'surfaces', 'coupling_types', 'crosses_trust_boundary', 'external_parties', 'algorithms_matched', 'description'])
        for b in sorted(agg, key=lambda x: (names.get(x, ('', '', ''))[0], x)):
            a = agg[b]; comp, name, desc = names.get(b, ('?', '?', '?'))
            w.writerow([b, comp, name, '/'.join(sorted(a['status'])), len(a['files']), a['rows'], ' '.join(sorted(a['surface'])), ' '.join(sorted(a['coupling'])),
                        'yes' if 'yes' in a['trust'] else 'no', '; '.join(sorted(a['party'])), ' '.join(sorted(a['algs'])), desc])
    s = collections.Counter(r['status'] for r in out)
    fc = collections.Counter(r['file_class'] for r in out)
    with open(os.path.join(ROOT, 'results/review-summary.txt'), 'w') as f:
        f.write(f'rows: {len(out)}\n\nfile_class:\n' + ''.join(f'  {k}: {v}\n' for k, v in fc.most_common()))
        f.write('\nstatus:\n' + ''.join(f'  {k}: {v}\n' for k, v in s.most_common()))
        f.write(f'\nfiles hand-reviewed (pass 2): {len(judg)}\nbindings (verified or non-signature): {len(agg)}\n')
        v = [r for r in out if r['status'] == 'verified']
        f.write('\nverified rows by surface:\n' + ''.join(f'  {k}: {n}\n' for k, n in collections.Counter(r['surface'] for r in v).most_common()))
        f.write('verified rows by coupling type:\n' + ''.join(f'  {k}: {n}\n' for k, n in collections.Counter(r['coupling_type'] for r in v).most_common()))
        f.write('verified rows crossing a trust boundary:\n' + ''.join(f'  {k}: {n}\n' for k, n in collections.Counter(r['crosses_trust_boundary'] for r in v).most_common()))
        f.write('verified rows by repo:\n' + ''.join(f'  {k}: {n}\n' for k, n in collections.Counter(r['repo'] for r in v).most_common()))
    print(open(os.path.join(ROOT, 'results/review-summary.txt')).read())

if __name__ == '__main__': main()
