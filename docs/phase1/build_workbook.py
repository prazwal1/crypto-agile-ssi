"""Build docs/phase1/Phase1-Workbook.xlsx from the repository (findings, decisions, results, evidence).
Usage: python3 docs/phase1/build_workbook.py [output.xlsx]
Formulas are written without cached values; Excel computes them on open (or run LibreOffice recalc).
"""
import csv, sys, re, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from workbook_data import *
import subprocess
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.comments import Comment

REPO_REL = '../../'   # workbook lives in docs/phase1/; links are relative to it
F = 'Arial'
HFILL = PatternFill('solid', fgColor='1F3864'); HFONT = Font(name=F, bold=True, color='FFFFFF', size=10)
BODY = Font(name=F, size=10); BOLD = Font(name=F, size=10, bold=True)
LINK = Font(name=F, size=10, color='0563C1', underline='single')
INPUT = PatternFill('solid', fgColor='FFFF00')
THIN = Side(style='thin', color='BFBFBF'); BORDER = Border(left=THIN, right=THIN, top=THIN, bottom=THIN)
WRAP = Alignment(wrap_text=True, vertical='top')

wb = Workbook(); wb.remove(wb.active)

def sheet(name, headers, widths, title=None, note=None):
    ws = wb.create_sheet(name); r = 1
    if title:
        ws.cell(1, 1, title).font = Font(name=F, size=13, bold=True); r = 2
        if note: ws.cell(2, 1, note).font = Font(name=F, size=9, italic=True, color='595959'); r = 3
        r += 1
    for i, h in enumerate(headers, 1):
        c = ws.cell(r, i, h); c.font = HFONT; c.fill = HFILL; c.alignment = Alignment(wrap_text=True, vertical='center'); c.border = BORDER
    for i, w in enumerate(widths, 1): ws.column_dimensions[get_column_letter(i)].width = w
    ws.freeze_panes = ws.cell(r + 1, 1)
    ws._hdr = r
    return ws

def put(ws, row, col, val, link=None, bold=False):
    c = ws.cell(row, col, val); c.font = LINK if link else (BOLD if bold else BODY); c.alignment = WRAP; c.border = BORDER
    if link: c.hyperlink = link
    return c

def coderef_text(ref):
    repo, path, a, b = ref
    s = f'{repo}: {path}'
    if a: s += f':{a}' + (f'-{b}' if b and b != a else '')
    return s

def finish(ws, last_col):
    ws.auto_filter.ref = f'A{ws._hdr}:{get_column_letter(last_col)}{ws.max_row}'

# ---------------- README
ws = wb.create_sheet('README')
ws.column_dimensions['A'].width = 28; ws.column_dimensions['B'].width = 110
rows = [
 ('Phase 1 Workbook: Cryptographic Dependency Analysis (RQ1)', None),
 ('Thesis', 'Crypto-agile architecture for W3C DID/VC systems, prototyped on MOSIP Inji (AIT Master\'s thesis, Prajwal Bhandary; supervisor Aj. George)'),
 ('Phase 1 question (RQ1)', 'Where, and how tightly, does the Inji stack bind to specific cryptographic algorithms, and what does that mean for a post-quantum migration?'),
 ('Status', 'Analysis complete (2026-10-13). Open: PB spot-check of 20 inventory rows (sheet Spot-Check); D-01 and D-02 (sheet Decisions); CBOM export.'),
 ('Source repository', 'F:\\thesis\\crypto-agile-ssi (git). This workbook: docs/phase1/Phase1-Workbook.xlsx. Links in column "Evidence" open files relative to this workbook, so keep the repository folder structure. Links in "Code" open the exact line on GitHub at the pinned commit.'),
 ('Generated', 'From the repository files by docs/phase1/build_workbook.py (findings.md, decisions.md, known-issues.md, results/*.csv, review/*.tsv, evidence/*). Edit the sources, then rebuild.'),
 ('', None),
 ('Sheet', 'What it contains'),
 ('RQ1 Answer', 'Short answers to the six Phase 1 sub-questions, each with supporting findings and the metric behind it'),
 ('Findings', 'F1 to F21: finding, how we concluded it (reasoning), why it matters, evidence type, confidence, code and evidence links'),
 ('Requirements', 'R-01 to R-12: design requirements derived from the findings, input to RQ2, with rationale, priority and how each will be checked in RQ4'),
 ('Traceability', 'Findings x requirements matrix (computed from the Requirements sheet)'),
 ('Algorithm Matrix', 'Which algorithm each component supports, accepts or advertises, with the code or evidence for each column'),
 ('Bindings', 'The 35 places in the stack that depend on an algorithm choice, with surface, coupling type, trust boundary and files'),
 ('Issuer Registries', 'The 12 places an issuer-side algorithm must be added to (F12), with code links'),
 ('Stats', 'Counts computed by formula from the Inventory sheet'),
 ('Inventory', 'All 919 scanner rows with status, binding and scores (filterable)'),
 ('Runtime Evidence', 'Timeline of the reference run and the failed first attempt, step by step, with log files'),
 ('Source Citations', 'Every cited source location (C1 to C24 signing trace, R1 to R16 inventory review) with GitHub permalink and local path'),
 ('Evidence Index', 'Evidence folders and artifacts: what, how produced, what they support'),
 ('Environment', 'Pinned repositories, running images, device and libraries'),
 ('Decisions', 'Open and closed scope and design decisions'),
 ('Known Issues', 'Environment problems met, causes and fixes'),
 ('Activity Log', 'Work sessions and every git commit, in order'),
 ('Method', 'Surfaces, coupling types, statuses, review passes, scanner rules and limits'),
 ('Spot-Check', 'Independent check of 20 sampled inventory rows: yellow cells are for the reviewer'),
 ('', None),
 ('Conventions', 'S1 key generation and storage; S2 verification method and DID encoding; S3 proof suites, formats, issuance and presentation proofs; S4 transport and key agreement. Coupling types after Rameshan and Messmer: creation, operation, provider. Yellow cells are inputs for the reviewer. No values are typed over formulas.'),
]
for i, (a, b) in enumerate(rows, 1):
    ca = ws.cell(i, 1, a); ca.font = Font(name=F, size=13 if i == 1 else 10, bold=(i == 1 or b is None and a != '' or a in ('Sheet',)))
    if b is not None:
        cb = ws.cell(i, 2, b); cb.font = BOLD if a == 'Sheet' else BODY; cb.alignment = WRAP
        if a in [s for s, _ in rows[8:26]] and a not in ('Sheet',):
            ca.hyperlink = f"#'{a}'!A1"; ca.font = LINK

# ---------------- Findings
ws = sheet('Findings', ['ID','Surface','Component','Finding','How we concluded (reasoning)','Why it matters','RQ','Evidence type','Confidence','Code (pinned commit)','Code 2','Code 3','Evidence in repo','Evidence 2','Requirements'], [6,9,16,60,45,45,10,14,10,38,38,38,36,36,14],
           'Phase 1 findings F1 to F21', 'Static = confirmed by reading source at the pinned commit; runtime = observed on the running stack; links open the exact lines.')
reqmap = {}
for rid, *_ , in REQS: pass
for rq in REQS:
    for fid in [x.strip() for x in rq[3].split(',')]: reqmap.setdefault(fid, []).append(rq[0])
r = ws._hdr + 1
for fid, surf, comp, text, reason, why, rq, etype, conf, codes, evs in FINDINGS:
    vals = [fid, surf, comp, text, reason, why, rq, etype, conf]
    for i, v in enumerate(vals, 1): put(ws, r, i, v, bold=(i == 1))
    for k in range(3):
        if k < len(codes): put(ws, r, 10 + k, coderef_text(codes[k]), link=gh(*codes[k]))
        else: put(ws, r, 10 + k, '')
    for k in range(2):
        if k < len(evs): put(ws, r, 13 + k, evs[k], link=REPO_REL + evs[k])
        else: put(ws, r, 13 + k, '')
    put(ws, r, 15, ', '.join(reqmap.get(fid, [])) or 'none (S4 key agreement, outside signature scope; in CBOM)')
    r += 1
finish(ws, 15)

# ---------------- Requirements
ws = sheet('Requirements', ['ID','Requirement','Statement','Derived from findings','Priority','How it will be checked (RQ4)','Rationale'], [7,26,60,18,9,45,50],
           'Design requirements derived from Phase 1 (input to RQ2)', 'Priority in MoSCoW terms. Baselines quoted in "How it will be checked" come from the findings.')
r = ws._hdr + 1
for row in REQS:
    for i, v in enumerate(row, 1): put(ws, r, i, v, bold=(i == 1))
    r += 1
finish(ws, 7)
req_first, req_last = ws._hdr + 1, r - 1

# ---------------- Traceability (formulas)
ws = sheet('Traceability', ['Finding'] + [q[0] for q in REQS] + ['Requirements linked'], [10] + [7]*len(REQS) + [12],
           'Findings x requirements', 'X = the requirement lists the finding in "Derived from findings" (computed from the Requirements sheet).')
r = ws._hdr + 1
for f in FINDINGS:
    put(ws, r, 1, f[0], bold=True)
    for j, q in enumerate(REQS, 2):
        col = get_column_letter(j)
        ref = f"INDEX(Requirements!$D${req_first}:$D${req_last},MATCH({col}${ws._hdr},Requirements!$A${req_first}:$A${req_last},0))"
        c = ws.cell(r, j, f'=IF(ISNUMBER(SEARCH("|"&$A{r}&"|","|"&SUBSTITUTE({ref},", ","|")&"|")),"X","")')
        c.font = BODY; c.alignment = Alignment(horizontal='center'); c.border = BORDER
    lc = get_column_letter(len(REQS) + 1)
    c = ws.cell(r, len(REQS) + 2, f'=COUNTIF(B{r}:{lc}{r},"X")'); c.font = BODY; c.border = BORDER
    r += 1

RQ1CELLS = []
# ---------------- RQ1 Answer
ws = sheet('RQ1 Answer', ['#','Sub-question','Answer','Key number','Supporting findings','Evidence'], [5,34,80,12,22,40],
           'RQ1: where and how tightly does the stack bind to algorithms?')
r = ws._hdr + 1
for q, sq, ans, metric, fs, ev in RQ1:
    put(ws, r, 1, q, bold=True); put(ws, r, 2, sq, bold=True); put(ws, r, 3, ans)
    c = put(ws, r, 4, metric); RQ1CELLS.append((c, metric))
    put(ws, r, 5, fs)
    put(ws, r, 6, ev, link=(REPO_REL + ev) if ev != '-' else None)
    r += 1

# ---------------- Algorithm Matrix
ws = sheet('Algorithm Matrix', ['Algorithm'] + [m[0] for m in MATRIX], [20] + [22]*len(MATRIX),
           'Algorithm support by component', 'Row 5 links each column to its source. "No" = not supported, accepted or advertised. ML-DSA and SLH-DSA are supported nowhere in the deployed stack.')
put(ws, ws._hdr + 1, 1, 'Source', bold=True)
for j, m in enumerate(MATRIX, 2):
    src = m[1]
    if isinstance(src, tuple): put(ws, ws._hdr + 1, j, coderef_text(src).split(': ')[1].split('/')[-1], link=gh(*src))
    else: put(ws, ws._hdr + 1, j, src.split('/')[-1], link=REPO_REL + src)
for i, a in enumerate(ALGS):
    rr = ws._hdr + 2 + i; put(ws, rr, 1, a, bold=True)
    for j, m in enumerate(MATRIX, 2):
        v = m[2][i]; c = put(ws, rr, j, v)
        if v.startswith('No'): c.fill = PatternFill('solid', fgColor='F2F2F2')
nr = ws._hdr + 2 + len(ALGS) + 1
put(ws, nr, 1, 'Observations', bold=True)
obs = ['ES256: issuer can sign and accepts ES256 holder proofs, but vc-verifier\'s allow-list rejects ES256 JWS and its proof-type list lacks EcdsaSecp256r1Signature2019 (F18).',
       'ecdsa-rdfc-2019 / ecdsa-jcs-2019 map to ES256K in the deployed config but to ES256 in Certify\'s packaged default (F21).',
       'EdDSA is the only algorithm present in every column except hardware keystore and FarmerCredential holder proofs.',
       'No component supports ML-DSA or SLH-DSA; the only PQ code present is pre-standard Dilithium/SPHINCS+ in BouncyCastle 1.78.1 (F16).']
for k, o in enumerate(obs):
    ws.merge_cells(start_row=nr + 1 + k, start_column=1, end_row=nr + 1 + k, end_column=len(MATRIX) + 1)
    c = ws.cell(nr + 1 + k, 1, o); c.font = BODY; c.alignment = WRAP
    ws.row_dimensions[nr + 1 + k].height = 28

# ---------------- Bindings
judg = [l.rstrip('\n').split('\t') for l in open(os.path.join(ROOT, 'phase1-dependency-analysis/review/judgements.tsv')) if not l.startswith('#') and l.strip()]
files_by_b = {}
for j in judg:
    if j[4] not in ('-', ''): files_by_b.setdefault(j[4], []).append(j[1])
ws = sheet('Bindings', ['Binding','Component','Name','Status','Files','Rows','Surfaces','Coupling types','Crosses trust boundary','External parties','Algorithms matched','Description','Files (pinned)'], [8,14,28,13,7,7,9,20,11,24,26,50,70],
           'Algorithm bindings (35)', 'A binding is one place where the system depends on an algorithm choice; from results/bindings.csv. Rows are inventory rows; files lists every reviewed file in the binding.')
r = ws._hdr + 1
for row in csv.DictReader(open(os.path.join(ROOT, 'phase1-dependency-analysis/results/bindings.csv'))):
    vals = [row['binding'], row['component'], row['name'], row['status'], int(row['files']), int(row['rows']), row['surfaces'], row['coupling_types'], row['crosses_trust_boundary'], row['external_parties'], row['algorithms_matched'], row['description'], '\n'.join(sorted(set(files_by_b.get(row['binding'], []))))]
    for i, v in enumerate(vals, 1): put(ws, r, i, v, bold=(i == 1))
    r += 1
bl = r - 1; bfirst = ws._hdr + 1
put(ws, r, 4, 'Total', bold=True); put(ws, r, 5, f'=SUM(E{ws._hdr+1}:E{bl})'); put(ws, r, 6, f'=SUM(F{ws._hdr+1}:F{bl})')
finish(ws, 13); ws.auto_filter.ref = f'A{ws._hdr}:M{bl}'

# ---------------- Issuer Registries
ws = sheet('Issuer Registries', ['#','Registry','Kind','Location','Link'], [5,48,26,44,60],
           'Where an issuer-side algorithm must be added (F12)', 'Certify 0.14.0 and keymanager 1.4.0. Kind = data, config, code or library.')
r = ws._hdr + 1
for n, name, kind, loc, ev, code in REGISTRIES:
    put(ws, r, 1, n); put(ws, r, 2, name); put(ws, r, 3, kind); put(ws, r, 4, loc)
    if code: put(ws, r, 5, coderef_text(code), link=gh(*code))
    else: put(ws, r, 5, ev, link=REPO_REL + ev)
    r += 1
put(ws, r, 2, 'Code registries', bold=True); put(ws, r, 3, f'=COUNTIF(C{ws._hdr+1}:C{r-1},"code*")')
put(ws, r + 1, 2, 'All registries', bold=True); put(ws, r + 1, 3, f'=COUNTA(A{ws._hdr+1}:A{r-1})')

# ---------------- Inventory
inv = list(csv.DictReader(open(os.path.join(ROOT, 'phase1-dependency-analysis/results/inventory-scored.csv'))))
cols = ['id','repo','file','lines','rule','algorithm','matched','file_class','review_pass','status','binding','surface','coupling_type','crosses_trust_boundary','external_party','evidence','notes']
ws = sheet('Inventory', cols + ['code link'], [7,14,50,14,13,11,18,11,7,16,8,7,11,9,20,40,45,10],
           'Scored inventory (919 rows)', 'results/inventory-scored.csv. Pass 1 = path rule, not read; pass 2 = file read by hand. Filter on status = verified for real dependencies.')
r = ws._hdr + 1
for x in inv:
    for i, k in enumerate(cols, 1):
        v = x[k]
        if k == 'review_pass': v = int(v)
        c = ws.cell(r, i, v); c.font = BODY; c.alignment = Alignment(vertical='top', wrap_text=False)
    first = re.match(r'\d+', x['lines'] or '')
    c = ws.cell(r, len(cols) + 1, 'open'); c.hyperlink = gh(x['repo'], x['file'], int(first.group()) if first else None); c.font = LINK
    r += 1
inv_last = r - 1; inv_first = ws._hdr + 1
ws.auto_filter.ref = f'A{ws._hdr}:{get_column_letter(len(cols)+1)}{inv_last}'

# ---------------- Stats (formulas over Inventory)
ws = sheet('Stats', ['Measure','Value','Formula basis'], [44,12,60], 'Inventory statistics (computed)', 'All values are formulas over the Inventory and Bindings sheets.')
I = lambda col: f"Inventory!${col}${inv_first}:${col}${inv_last}"
colL = {k: get_column_letter(i) for i, k in enumerate(cols, 1)}
st = [
 ('Inventory rows', f'=COUNTA({I(colL["id"])})', 'COUNTA(id)'),
 ('Verified', f'=COUNTIF({I(colL["status"])},"verified")', 'status = verified'),
 ('Non-signature (kept for CBOM)', f'=COUNTIF({I(colL["status"])},"non-signature")', ''),
 ('Format-only', f'=COUNTIF({I(colL["status"])},"format-only")', ''),
 ('False positive', f'=COUNTIF({I(colL["status"])},"false-positive")', ''),
 ('Dead code', f'=COUNTIF({I(colL["status"])},"dead-code")', ''),
 ('Excluded test', f'=COUNTIF({I(colL["status"])},"excluded-test")', ''),
 ('Excluded sample', f'=COUNTIF({I(colL["status"])},"excluded-sample")', ''),
 ('Upstream deployment config', f'=COUNTIF({I(colL["status"])},"upstream-deployment-config")', ''),
 ('Build dependency', f'=COUNTIF({I(colL["status"])},"build-dependency")', ''),
 ('Rows read by hand (pass 2)', f'=COUNTIF({I(colL["review_pass"])},2)', ''),
 ('Repositories with verified rows', '=9', 'count of distinct repos in Bindings (hard-coded: see Bindings sheet column Component)'),
 ('Bindings', f"=COUNTA(Bindings!$A${bfirst}:$A${bl})", 'rows in Bindings sheet'),
 ('Verified rows, surface S1', f'=COUNTIFS({I(colL["status"])},"verified",{I(colL["surface"])},"S1")', ''),
 ('Verified rows, surface S2', f'=COUNTIFS({I(colL["status"])},"verified",{I(colL["surface"])},"S2")', ''),
 ('Verified rows, surface S3', f'=COUNTIFS({I(colL["status"])},"verified",{I(colL["surface"])},"S3")', ''),
 ('Verified rows, surface S4', f'=COUNTIFS({I(colL["status"])},"verified",{I(colL["surface"])},"S4")', ''),
 ('Verified rows, coupling creation', f'=COUNTIFS({I(colL["status"])},"verified",{I(colL["coupling_type"])},"creation")', ''),
 ('Verified rows, coupling operation', f'=COUNTIFS({I(colL["status"])},"verified",{I(colL["coupling_type"])},"operation")', ''),
 ('Share of verified rows that are operation coupling', '=@{Verified rows, coupling operation}/@{Verified}', 'operation / verified'),
 ('Verified rows, coupling provider', f'=COUNTIFS({I(colL["status"])},"verified",{I(colL["coupling_type"])},"provider")', ''),
 ('Verified rows crossing a trust boundary', f'=COUNTIFS({I(colL["status"])},"verified",{I(colL["crosses_trust_boundary"])},"yes")', ''),
 ('Verified rows not crossing', f'=COUNTIFS({I(colL["status"])},"verified",{I(colL["crosses_trust_boundary"])},"no")', ''),
 ('Share of verified rows crossing a trust boundary', '=@{Verified rows crossing a trust boundary}/@{Verified}', 'crossing / verified'),
 ('Check: statuses sum to rows', '=SUM(@{Verified}:@{Build dependency})-@{Inventory rows}', 'should be 0'),
]
r = ws._hdr + 1
STATROW = {m: ws._hdr + 1 + i for i, (m, _, _) in enumerate(st)}
for m, f, basis in st:
    f = re.sub(r'@\{([^}]+)\}', lambda mm: f'B{STATROW[mm.group(1)]}', f)
    put(ws, r, 1, m); c = put(ws, r, 2, f); put(ws, r, 3, basis)
    if 'Share' in m: c.number_format = '0%'
    r += 1
ws[f"B{STATROW['Repositories with verified rows']}"].comment = Comment('Hard-coded: distinct components in the Bindings sheet (keymanager traced separately, not in the inventory).', 'build')

# ---------------- Runtime Evidence
ws = sheet('Runtime Evidence', ['Run','Time (ICT)','Step','Result','Evidence file'], [16,15,60,40,50],
           'Runtime timeline, 2026-10-13', 'Pixel 7 (Android 17), Inji Wallet v0.22.1, Certify 0.14.0, Mimoto 0.22.0, Inji Verify 0.18.2; issuer did:web:ssi-issuer.arlabsnepal.com for the reference run.')
r = ws._hdr + 1
for run, t, step, res, ev in RUNTIME:
    put(ws, r, 1, run, bold=True); put(ws, r, 2, t); put(ws, r, 3, step); put(ws, r, 4, res); put(ws, r, 5, ev, link=REPO_REL + ev); r += 1
finish(ws, 5)

# ---------------- Source Citations
ws = sheet('Source Citations', ['ID','Repo','Tag','Commit','Path','Lines','What it shows','GitHub (pinned)','Excerpt file'], [6,14,9,13,60,9,48,10,30],
           'Cited source locations', 'Every excerpt is reproduced verbatim in the excerpt file, generated by tools/cite.py from the pinned clones.')
r = ws._hdr + 1
for src, exf in [(os.path.join(ROOT, 'evidence/2026-10-13-issuer-signing-trace/citations.tsv'), 'evidence/2026-10-13-issuer-signing-trace/excerpts.md'),
                 (os.path.join(ROOT, 'evidence/2026-10-13-inventory-review/citations.tsv'), 'evidence/2026-10-13-inventory-review/excerpts.md')]:
    for row in csv.reader(open(src), delimiter='\t'):
        if not row or row[0].startswith('#'): continue
        cid, repo, path, a, b, note = row
        tag, sha = SHA[repo][0], SHA[repo][1]
        vals = [cid, repo, tag, sha[:12], path, f'{a}-{b}' if a != b else a, note]
        for i, v in enumerate(vals, 1): put(ws, r, i, v, bold=(i == 1))
        put(ws, r, 8, 'open', link=gh(repo, path, int(a), int(b))); put(ws, r, 9, exf.split('/')[1], link=REPO_REL + exf)
        r += 1
finish(ws, 9)

# ---------------- Evidence Index
ws = sheet('Evidence Index', ['Folder or artifact','Contents','How produced (who ran it)','Supports'], [46,60,40,22], 'Evidence index', 'Each folder has a README with exact commands. Large binaries live outside git and are identified by SHA-256.')
r = ws._hdr + 1
for p, what, how, sup in EVIDENCE:
    put(ws, r, 1, p, link=(REPO_REL + p + ('summary.txt' if p == 'evidence/2026-10-13-issuer-baseline/' else 'README.md')) if p.startswith('evidence') else None); put(ws, r, 2, what); put(ws, r, 3, how); put(ws, r, 4, sup); r += 1
finish(ws, 4)

# ---------------- Environment
ws = sheet('Environment', ['Item','Version / value','Commit or id','Role','Source'], [26,28,44,46,40], 'Environment and pinned versions')
r = ws._hdr + 1
for repo, (tag, sha, date, role, treat) in SHA.items():
    put(ws, r, 1, repo, bold=True); put(ws, r, 2, f'{tag} ({date})'); put(ws, r, 3, sha, link=f'https://github.com/mosip/{repo}/tree/{sha}'); put(ws, r, 4, f'{role}; {treat}'); put(ws, r, 5, 'phase1-dependency-analysis/manifest.tsv', link=REPO_REL + 'phase1-dependency-analysis/manifest.tsv'); r += 1
imgs = [l.split() for l in open(os.path.join(ROOT, 'evidence/2026-10-13-reference-run/stack-images.txt'), encoding='utf-8-sig').read().splitlines()[1:] if l.strip()]
for im in imgs:
    put(ws, r, 1, im[0], bold=True); put(ws, r, 2, f'{im[1]}:{im[2]}'); put(ws, r, 3, f'image id {im[4]}'); put(ws, r, 4, 'running container'); put(ws, r, 5, 'evidence/2026-10-13-reference-run/stack-images.txt', link=REPO_REL + 'evidence/2026-10-13-reference-run/stack-images.txt'); r += 1
for line in open(os.path.join(ROOT, 'evidence/2026-10-13-certify-image-libs/crypto-libs.txt')):
    if line.startswith('#') or not line.strip(): continue
    pos, jar = line.split()
    put(ws, r, 1, jar, bold=True); put(ws, r, 2, 'bundled in certify.jar'); put(ws, r, 3, f'classpath position {pos}'); put(ws, r, 4, 'issuer crypto library'); put(ws, r, 5, 'evidence/2026-10-13-certify-image-libs/crypto-libs.txt', link=REPO_REL + 'evidence/2026-10-13-certify-image-libs/crypto-libs.txt'); r += 1
for a, b, c_, d, e in [('Test device','Google Pixel 7, Android 17','security patch 2026-09-05','StrongBox keystore present','docs/lab-notebook.md'),
                       ('Issuer DID','did:web:ssi-issuer.arlabsnepal.com','Ed25519VerificationKey2020','named Cloudflare tunnel (C-08)','evidence/2026-10-13-issuer-baseline/did.json'),
                       ('Wallet backend','https://ssi-mimoto.arlabsnepal.com','-','Mimoto through named tunnel','env/stack/tunnel.env.example'),
                       ('Laptop','Windows, Docker Desktop with WSL2','F:\\thesis','stack and wallet build','docs/architecture.md')]:
    put(ws, r, 1, a, bold=True); put(ws, r, 2, b); put(ws, r, 3, c_); put(ws, r, 4, d); put(ws, r, 5, e, link=REPO_REL + e); r += 1

# ---------------- Decisions / Known issues from markdown tables
def md_tables(path):
    out, cur = [], None
    for line in open(path, encoding='utf-8'):
        if line.startswith('|'):
            cells = [c.strip() for c in line.strip().strip('|').split('|')]
            if set(''.join(cells)) <= set('-: '): continue
            if cur is None: cur = [cells]
            else: cur.append(cells)
        else:
            if cur: out.append(cur); cur = None
    if cur: out.append(cur)
    return out
def clean(s): return s.replace('`', '')
dec = md_tables(os.path.join(ROOT, 'docs/decisions.md'))
ws = sheet('Decisions', ['ID','State','Question or decision','Date','Why it matters / reasoning','Notes'], [7,8,50,14,55,55], 'Decisions (docs/decisions.md)')
r = ws._hdr + 1
for row in dec[0][1:]:
    put(ws, r, 1, row[0], bold=True); put(ws, r, 2, 'Open'); put(ws, r, 3, clean(row[1])); put(ws, r, 4, ''); put(ws, r, 5, clean(row[2])); put(ws, r, 6, clean(row[3])); r += 1
for row in dec[1][1:]:
    put(ws, r, 1, row[0], bold=True); put(ws, r, 2, 'Closed'); put(ws, r, 3, clean(row[1])); put(ws, r, 4, row[2]); put(ws, r, 5, clean(row[3])); put(ws, r, 6, ''); r += 1
finish(ws, 6)
ki = md_tables(os.path.join(ROOT, 'docs/known-issues.md'))
ws = sheet('Known Issues', ['First seen','Symptom','Cause','Fix'], [12,55,55,55], 'Known environment issues (docs/known-issues.md)')
r = ws._hdr + 1
for row in ki[0][1:]:
    for i, v in enumerate(row, 1): put(ws, r, i, clean(v))
    r += 1
finish(ws, 4)

# ---------------- Activity Log
ws = sheet('Activity Log', ['When','Session or commit','What was done','Evidence or reference'], [20,30,80,40], 'Activity log', 'Sessions from docs/lab-notebook.md (ICT), then every git commit in order (commit times in UTC).')
r = ws._hdr + 1
for a, b, c_, d in SESSIONS:
    put(ws, r, 1, a, bold=True); put(ws, r, 2, b); put(ws, r, 3, c_); put(ws, r, 4, d); r += 1
r += 1; put(ws, r, 1, 'Git commits', bold=True); r += 1
GITLOG = subprocess.run(['git', '-C', ROOT, 'log', '--reverse', '--format=%h%x09%ad%x09%s', '--date=format:%Y-%m-%d %H:%M'], capture_output=True, text=True, check=True).stdout.splitlines()
for line in GITLOG:
    h, t, msg = line.rstrip('\n').split('\t', 2)
    put(ws, r, 1, t + ' UTC'); put(ws, r, 2, h); put(ws, r, 3, msg); put(ws, r, 4, 'git show ' + h); r += 1

# ---------------- Method
ws = sheet('Method', ['Topic','Item','Definition or rule'], [20,30,100], 'Method')
r = ws._hdr + 1
meth = [
 ('Surfaces','S1','Key generation and storage'),('Surfaces','S2','Verification method and DID document encoding'),('Surfaces','S3','Proof suites, credential formats, issuance and presentation proofs'),('Surfaces','S4','Transport and key agreement (BLE, response encryption)'),
 ('Coupling type','creation','Where an algorithm or key type is chosen or a key is created (enums, maps, keygen, configuration)'),
 ('Coupling type','operation','Where a cryptographic operation is performed with the algorithm fixed or derived locally (sign, verify, encode, decode)'),
 ('Coupling type','provider','Where a library or provider is bound (imports, provider registration, delegation to a library)'),
 ('Status','verified','Real algorithm dependency confirmed by reading code'),('Status','non-signature','Hashing, symmetric encryption, HMAC, KDF: kept for the CBOM, outside the signature scope'),
 ('Status','format-only','Credential format dispatch without an algorithm'),('Status','false-positive','Matched text that is not a crypto dependency (names, comments, encoders, shaded Gson)'),
 ('Status','dead-code','Not imported by production code'),('Status','excluded-test / excluded-sample','Test rigs, test data, example and sample apps'),
 ('Status','upstream-deployment-config','Upstream compose, helm, SQL seeds; the deployed values are in env/stack and covered by F9, F21'),('Status','build-dependency','Library declarations; input to the CBOM'),
 ('Review','Pass 1 (scripted)','file_class from path: test, build, deploy-config (non-code files only), doc, app-config, source. Rules in tools/score_inventory.py'),
 ('Review','Pass 2 (hand)','For every source and app-config file: read the matched lines and surrounding code at the pinned commit; one judgement per file in review/judgements.tsv; script refuses to run if any is missing'),
 ('Review','Correction','Deploy rule first matched production Java classes under config/ packages; rule changed to non-code files and the four classes reviewed by hand'),
 ('Review','Independent check','Seeded stratified sample of 20 rows (sheet Spot-Check), to be checked by PB'),
 ('Runtime','capture-logs.ps1','Clears logcat, records wallet JS and native warnings, then saves Certify, nginx and Mimoto logs for the same window'),
 ('Runtime','capture-baseline','Saves issuer DID, issuer metadata, OAuth metadata and JWKS from the public hostname'),
 ('Citations','tools/cite.py','Extracts every cited file:line range from the pinned clones into an excerpt file with repo, tag and commit'),
 ('Limits','Granularity','Judgements are per file; mixed files are explained in the judgement notes'),
 ('Limits','Static vs runtime','F18 is a static inference (not executed); runtime findings cover one credential type (FarmerCredential, ldp_vc)'),
 ('Limits','Platform','Prototype is Android only; iOS files reviewed but out of scope'),
 ('Limits','Keymanager','Not in the scanner inventory; traced by hand (issuer-signing-path.md)'),
]
for t, i_, d in meth:
    put(ws, r, 1, t, bold=True); put(ws, r, 2, i_); put(ws, r, 3, d); r += 1
r += 1; put(ws, r, 1, 'Scanner rules', bold=True); put(ws, r, 2, 'tools/rules.yaml', link=REPO_REL + 'phase1-dependency-analysis/tools/rules.yaml'); r += 1
for line in open(os.path.join(ROOT, 'phase1-dependency-analysis/tools/rules.yaml')):
    m = re.match(r"\s*- \{id: ([\w-]+),\s*kind: (\w+),\s*algorithm: ([^,]*),\s*surface: ([^,]*),\s*regex: '(.*)'\}", line)
    if m:
        put(ws, r, 1, m.group(1)); put(ws, r, 2, f'kind {m.group(2)}; algorithm {m.group(3).strip(chr(34)) or "-"}; surface {m.group(4).strip(chr(34)) or "by path"}'); put(ws, r, 3, m.group(5)); r += 1

# ---------------- Spot-Check
ws = sheet('Spot-Check', ['ID','Repo','File','Lines','Rule','Matched','Status given','Binding','Coupling','Surface','Trust boundary','Notes','Code','Reviewer agrees (yes/no)','Reviewer comment'], [7,13,45,12,12,16,14,8,10,8,9,40,8,14,40],
           'Spot-check of the inventory review', 'For each row, open the code link, read the lines, and fill in the yellow cells. Example: yes / "Proof suite constant, correctly operation coupling".')
r = ws._hdr + 1
dv = DataValidation(type='list', formula1='"yes,no"', allow_blank=True); ws.add_data_validation(dv)
for x in csv.DictReader(open(os.path.join(ROOT, 'phase1-dependency-analysis/review/spot-check.csv'))):
    vals = [x['id'], x['repo'], x['file'], x['lines'], x['rule'], x['matched'], x['status'], x['binding'], x['coupling_type'], x['surface'], x['crosses_trust_boundary'], x['notes']]
    for i, v in enumerate(vals, 1): put(ws, r, i, v)
    first = re.match(r'\d+', x['lines'] or ''); put(ws, r, 13, 'open', link=gh(x['repo'], x['file'], int(first.group()) if first else None))
    for col in (14, 15):
        c = put(ws, r, col, ''); c.fill = INPUT
    dv.add(f'N{r}')
    r += 1
put(ws, r + 1, 13, 'Agreed', bold=True); put(ws, r + 1, 14, f'=COUNTIF(N{ws._hdr+1}:N{r-1},"yes")')
put(ws, r + 2, 13, 'Checked', bold=True); put(ws, r + 2, 14, f'=COUNTA(N{ws._hdr+1}:N{r-1})')
put(ws, r + 3, 13, 'Agreement', bold=True); c = put(ws, r + 3, 14, f'=IF(N{r+2}=0,"-",N{r+1}/N{r+2})'); c.number_format = '0%'

for c, metric in RQ1CELLS:
    if metric != '-':
        c.value = f"=Stats!B{STATROW[metric]}"
        if 'Share' in metric: c.number_format = '0%'
order = ['README','RQ1 Answer','Findings','Requirements','Traceability','Algorithm Matrix','Bindings','Issuer Registries','Stats','Inventory','Runtime Evidence','Source Citations','Evidence Index','Environment','Decisions','Known Issues','Activity Log','Method','Spot-Check']
wb._sheets = [wb[n] for n in order]
for wsx in wb.worksheets: wsx.sheet_view.zoomScale = 100
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'docs/phase1/Phase1-Workbook.xlsx')
wb.save(out); print('saved', out)
