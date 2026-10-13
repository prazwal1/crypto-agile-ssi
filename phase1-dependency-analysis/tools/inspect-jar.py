#!/usr/bin/env python3
"""Inventory the libraries bundled in a Spring Boot jar (and a plugin jar) and check
which post-quantum signature classes each BouncyCastle copy provides.

Usage: python3 inspect-jar.py <certify-service.jar> [plugin.jar ...] --out <dir>
Writes: sha256.txt, bundled-libs.txt, crypto-libs.txt, bouncycastle-check.txt
Read-only: the jars are opened, never modified.
"""
import argparse, hashlib, io, os, re, zipfile

CRYPTO = r'keymanager|kernel-core|bcprov|bcpkix|bcutil|danubetech|data-integrity|ld-signatures|nimbus|jose4j|titanium|cose|cbor|tink|eddsa|pixelpass|vc-?verifier'
PQ_MARKERS = {
    'ML-DSA (FIPS 204) JCA spec': 'org/bouncycastle/jcajce/spec/MLDSAParameterSpec.class',
    'ML-DSA (FIPS 204) signer':   'org/bouncycastle/pqc/crypto/mldsa/MLDSASigner.class',
    'SLH-DSA (FIPS 205) JCA spec':'org/bouncycastle/jcajce/spec/SLHDSAParameterSpec.class',
    'Dilithium (pre-standard) spec': 'org/bouncycastle/pqc/jcajce/spec/DilithiumParameterSpec.class',
    'SPHINCS+ (pre-standard) spec':  'org/bouncycastle/pqc/jcajce/spec/SPHINCSPlusParameterSpec.class',
}

def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''): h.update(chunk)
    return h.hexdigest()

def pq_check(names):
    return {k: (v in names) for k, v in PQ_MARKERS.items()}

def main():
    ap = argparse.ArgumentParser(); ap.add_argument('jars', nargs='+'); ap.add_argument('--out', required=True)
    a = ap.parse_args(); os.makedirs(a.out, exist_ok=True)
    with open(os.path.join(a.out, 'sha256.txt'), 'w') as f:
        for j in a.jars: f.write(f'{sha256(j)}  {os.path.basename(j)}\n')
    main_jar = zipfile.ZipFile(a.jars[0]); names = main_jar.namelist()
    libs = [n for n in names if n.startswith('BOOT-INF/lib/') and n.endswith('.jar')]
    idx = main_jar.read('BOOT-INF/classpath.idx').decode().splitlines() if 'BOOT-INF/classpath.idx' in names else []
    order = {l.strip().strip('- "'): i for i, l in enumerate(idx)}
    with open(os.path.join(a.out, 'bundled-libs.txt'), 'w') as f:
        f.write(f'# {os.path.basename(a.jars[0])}: {len(libs)} bundled jars (BOOT-INF/lib), classpath.idx order\n')
        for n in sorted(libs, key=lambda x: order.get(x, 9999)): f.write(f'{order.get(n, "-")}\t{n.split("/")[-1]}\n')
    with open(os.path.join(a.out, 'crypto-libs.txt'), 'w') as f:
        f.write('# crypto-relevant bundled jars, classpath.idx position\n')
        for n in sorted(libs, key=lambda x: order.get(x, 9999)):
            if re.search(CRYPTO, n, re.I): f.write(f'{order.get(n, "-")}\t{n.split("/")[-1]}\n')
    with open(os.path.join(a.out, 'bouncycastle-check.txt'), 'w') as f:
        for n in libs:
            if 'bcprov' not in n: continue
            inner = zipfile.ZipFile(io.BytesIO(main_jar.read(n))).namelist()
            f.write(f'{n.split("/")[-1]} (classpath.idx {order.get(n, "-")}): {len(inner)} entries\n')
            for k, v in pq_check(set(inner)).items(): f.write(f'  {k}: {"present" if v else "absent"}\n')
        for p in a.jars[1:]:
            pn = zipfile.ZipFile(p).namelist(); bc = [x for x in pn if x.startswith('org/bouncycastle/')]
            poms = [x for x in pn if 'org.bouncycastle' in x and x.endswith('pom.properties')]
            f.write(f'{os.path.basename(p)}: {len(bc)} shaded org/bouncycastle entries, version metadata {"present" if poms else "absent"}\n')
            for k, v in pq_check(set(pn)).items(): f.write(f'  {k}: {"present" if v else "absent"}\n')
        km = [n for n in libs if 'keymanager' in n]
        for n in km:
            inner = zipfile.ZipFile(io.BytesIO(main_jar.read(n)))
            for x in inner.namelist():
                if x.endswith('pom.properties'): f.write(f'{n.split("/")[-1]} pom.properties: ' + inner.read(x).decode().strip().replace('\n', '; ') + '\n')
    print('wrote', a.out)

if __name__ == '__main__': main()
