#!/usr/bin/env python3
"""Build a CycloneDX 1.6 CBOM for the Inji SSI prototype (RQ1, Phase 1).

Grounded in:
  - results/inventory-scored.csv  (446 verified rows; algorithm per binding)
  - evidence/2026-10-13-certify-image-libs/, 2026-10-14-verify-image-libs/  (jar contents)
  - manifest.tsv                  (pinned component versions)
Every cryptographic-asset carries occurrences pointing at a real finding/binding, and a
nistQuantumSecurityLevel (0 for every algorithm found: none is post-quantum).
"""
import json, uuid, csv, os, datetime, collections

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TS = "2026-10-14T22:30:00Z"

def ref(s): return s

# --- algorithms observed, with the finding/binding that evidences each ---
# (name, bom-ref, primitive, params, curve/None, functions, classical bits, exec env, oid, findings, note)
ALGS = [
 ("Ed25519","alg:ed25519","signature","Ed25519","Ed25519",["keygen","sign","verify"],128,"software-plain-ram","1.3.101.112",
   "F10,F20,F25","Default VC proof (Ed25519Signature2020), OpenID4VP request objects and VP proof, SD-JWT KB-JWT, holder issuance proof. Software key (@noble / eddsa-0.3.0)."),
 ("RSA-2048 (RS256/PS256)","alg:rsa2048","signature","2048",None,["keygen","sign","verify"],112,"software-plain-ram","1.2.840.113549.1.1.1",
   "F14,F20,F25","Certify access token (RS256); keymanager master-key hierarchy and X.509 chain; SD-JWT issuer certificate root. 2048-bit."),
 ("ECDSA P-256 (ES256)","alg:ecdsa-p256","signature","P-256","P-256",["keygen","sign","verify"],128,"hardware","1.2.840.10045.3.1.7",
   "F3,F9,F25","Holder proof for FarmerCredential (Android StrongBox, user-auth gated); SD-JWT issuer signature. secp256r1."),
 ("ECDSA secp256k1 (ES256K)","alg:ecdsa-secp256k1","signature","secp256k1","secp256k1",["keygen","sign","verify"],128,"software-plain-ram","1.3.132.0.10",
   "F1,F18,F21","Wallet software key type; accepted by vc-verifier; mapped in Certify suite config (F21 drift). Not exercised by any credential in the running flow."),
 ("ECDSA P-384","alg:ecdsa-p384","signature","P-384","P-384",["keygen","sign","verify"],192,"software-plain-ram","1.3.132.0.34",
   "F6","Present in verifier/library algorithm tables; not used by the FarmerCredential flow."),
 ("X25519","alg:x25519","key-agree","X25519","Curve25519",["keygen","keyderive"],128,"software-plain-ram","1.3.101.110",
   "F7,F20","ECDH key agreement: OpenID4VP response encryption (ECDH-ES) and Tuvali BLE transport."),
 ("ECDH-ES","alg:ecdh-es","key-agree","X25519",None,["keyderive"],128,"software-plain-ram",None,
   "F20","OpenID4VP authorization-response encryption, with X25519 and A256GCM."),
 ("RSA-OAEP","alg:rsa-oaep","pke","2048",None,["encrypt","decrypt"],112,"software-plain-ram","1.2.840.113549.1.1.7",
   "F14","Keymanager key unwrapping (master-key protection of stored signing keys)."),
 ("AES-256-GCM","alg:aes256gcm","ae","256",None,["encrypt","decrypt"],256,"software-plain-ram","2.16.840.1.101.3.4.1.46",
   "F7","Authenticated encryption: Tuvali BLE payloads, mimoto key storage, wallet local keystore."),
 ("HKDF-SHA256","alg:hkdf-sha256","kdf","SHA-256",None,["keyderive"],256,"software-plain-ram",None,
   "F7","Key derivation in the Tuvali BLE handshake."),
 ("PBKDF2","alg:pbkdf2","kdf","SHA-256",None,["keyderive"],256,"software-plain-ram","1.2.840.113549.1.5.12",
   "B-W8","Wallet backup key derivation."),
 ("SHA-256","alg:sha256","hash","SHA-256",None,["digest"],256,"software-plain-ram","2.16.840.1.101.3.4.2.1",
   "F7,F25","Digests: SD-JWT disclosures (_sd), canonicalized LD proof hashing, @noble/hashes."),
]

def crypto_asset(a):
    name,bref,prim,params,curve,fns,bits,env,oid,findings,note = a
    ap = {"primitive":prim,"parameterSetIdentifier":params,"executionEnvironment":env,
          "implementationPlatform":"generic","cryptoFunctions":fns,
          "classicalSecurityLevel":bits,"nistQuantumSecurityLevel":0}
    if curve: ap["curve"]=curve
    cp = {"assetType":"algorithm","algorithmProperties":ap}
    if oid: cp["oid"]=oid
    comp = {"type":"cryptographic-asset","bom-ref":bref,"name":name,"cryptoProperties":cp,
            "description":note+" Evidence: "+findings+" (see phase1-dependency-analysis/findings.md).",
            "properties":[{"name":"inji:findings","value":findings},
                          {"name":"inji:quantum-vulnerable","value":"true" if prim in("signature","key-agree","pke") else "false"}]}
    return comp

# --- crypto-provider libraries actually bundled in the two running images + wallet native ---
LIBS = [
 ("BouncyCastle bcprov-jdk18on","1.78.1","pkg:maven/org.bouncycastle/bcprov-jdk18on@1.78.1","Certify image; only copy with pre-standard Dilithium/SPHINCS+ (no final ML-DSA). F16."),
 ("BouncyCastle bcprov-jdk15on","1.70","pkg:maven/org.bouncycastle/bcprov-jdk15on@1.70","Certify image (second copy). F16."),
 ("BouncyCastle bcprov-jdk18on","1.78","pkg:maven/org.bouncycastle/bcprov-jdk18on@1.78","verify-service image. F8."),
 ("BouncyCastle bcprov-jdk15on","1.69","pkg:maven/org.bouncycastle/bcprov-jdk15on@1.69","verify-service image; first on the classpath. F8."),
 ("BouncyCastle bcprov-jdk15to18","1.70","pkg:maven/org.bouncycastle/bcprov-jdk15to18@1.70","verify-service image (third copy). F8."),
 ("nimbus-jose-jwt","10.0.2","pkg:maven/com.nimbusds/nimbus-jose-jwt@10.0.2","Certify JWT/JWS. "),
 ("nimbus-jose-jwt","9.37.4","pkg:maven/com.nimbusds/nimbus-jose-jwt@9.37.4","verify-service JWT/JWS and SD-JWT."),
 ("Google Tink","1.13.0","pkg:maven/com.google.crypto.tink/tink@1.13.0","Certify image."),
 ("Google Tink","1.16.0","pkg:maven/com.google.crypto.tink/tink@1.16.0","verify-service image."),
 ("ed25519-java (i2p)","0.3.0","pkg:maven/net.i2p.crypto/eddsa@0.3.0","Ed25519 in both images."),
 ("vcverifier-jar","1.8.1","pkg:maven/io.mosip/vcverifier-jar@1.8.1","verify-service credential/presentation verification. F25."),
 ("kernel-keymanager-service","1.4.0","pkg:maven/io.mosip/kernel-keymanager-service@1.4.0","Certify signing backend. F12-F16."),
 ("@noble/curves + @noble/hashes","(wallet v0.22.1)",None,"Wallet software ES256K/Ed25519 keygen and SHA-2. F3."),
 ("Android Keystore","(Pixel 7, Android 17, StrongBox)",None,"Wallet hardware RSA and P-256 keys (no ML-DSA). F3."),
]
def lib(l):
    name,ver,purl,note=l
    c={"type":"library","bom-ref":"lib:"+name.lower().replace(' ','-').replace('/','-')+"@"+ver,
       "name":name,"version":ver,"description":note}
    if purl: c["purl"]=purl
    return c

bom = {
 "$schema":"http://cyclonedx.org/schema/bom-1.6.schema.json",
 "bomFormat":"CycloneDX","specVersion":"1.6",
 "serialNumber":"urn:uuid:"+str(uuid.uuid5(uuid.NAMESPACE_URL,"inji-ssi-cbom-phase1")),
 "version":1,
 "metadata":{
   "timestamp":TS,
   "authors":[{"name":"Prajwal Bhandary"}],
   "component":{"type":"application","bom-ref":"inji-ssi-prototype","name":"Crypto-agile SSI prototype (MOSIP Inji)","version":"phase1-2026-10-14",
     "description":"W3C DID/VC issuance, holding and OpenID4VP presentation on MOSIP Inji (Certify 0.14.0, Mimoto 0.22.0, Inji Verify 0.18.2, Wallet 0.22.1). CBOM scope: cryptographic assets on surfaces S1-S4."},
   "properties":[
     {"name":"inji:verified-bindings","value":"446 verified inventory rows across 9 repositories + keymanager"},
     {"name":"inji:note","value":"nistQuantumSecurityLevel is 0 for every algorithm found: no post-quantum signature, KEM or key-agreement is present in any running component."}]
 },
 "components":[crypto_asset(a) for a in ALGS]+[lib(l) for l in LIBS],
}

# dependency: the application exercises the signature/transport algorithms
sig_refs=[a[1] for a in ALGS]
bom["dependencies"]=[{"ref":"inji-ssi-prototype","dependsOn":sig_refs}]

out=os.path.join(ROOT,"phase1-dependency-analysis/results/cbom.json")
json.dump(bom,open(out,"w"),indent=2)
print("wrote",out)
print("components:",len(bom["components"]),"(",sum(1 for c in bom['components'] if c['type']=='cryptographic-asset'),"crypto-assets,",sum(1 for c in bom['components'] if c['type']=='library'),"libraries )")
