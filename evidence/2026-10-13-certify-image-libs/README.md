# Libraries inside the running Certify image, 2026-10-13 21:15 ICT

Confirms which keymanager and crypto libraries the deployed issuer actually runs, rather than
what the source `pom.xml` declares.

## How it was produced

| Step | Command (run by PB on the laptop) | Output |
|---|---|---|
| 1 | `docker exec certify sh -c "find / -name '*.jar' -size +10M 2>/dev/null"` | `/home/inji/certify-service.jar`, `/home/inji/additional_jars/mock-certify-plugin.jar`, `/home/inji/additional_jars/mosip-identity-certify-plugin.jar` |
| 2 | `docker inspect certify --format "{{.Config.WorkingDir}} \| {{json .Config.Entrypoint}} \| {{json .Config.Cmd}}"` | `/home/inji \| ["./configure_start.sh"] \| ["java","-jar","-Dloader.path=${loader_path_env}",...,"certify-service.jar"]` |
| 3 | `docker cp certify:/home/inji/certify-service.jar F:\thesis\tmp\certify.jar` and the same for `mock-certify-plugin.jar` | Copies, archived in `F:\thesis\artifacts\2026-10-13-certify-0.14.0\` |
| 4 | `python3 phase1-dependency-analysis/tools/inspect-jar.py <certify.jar> <mock-certify-plugin.jar> --out evidence/2026-10-13-certify-image-libs` | The files below |

Image: `injistack/inji-certify-with-plugins:0.14.0`, image id `f6686f55f520`
(`../2026-10-13-reference-run/stack-images.txt`).

| File | Content |
|---|---|
| `sha256.txt` | SHA-256 of both jars; matches the archived copies |
| `bundled-libs.txt` | All 257 jars in `BOOT-INF/lib`, in `classpath.idx` order |
| `crypto-libs.txt` | Crypto-relevant subset |
| `bouncycastle-check.txt` | Post-quantum class check for each BouncyCastle copy; keymanager `pom.properties` |

## Results

| Check | Result |
|---|---|
| Keymanager | `kernel-keymanager-service-1.4.0-lib.jar`, `pom.properties` version 1.4.0: matches the traced source (`../2026-10-13-issuer-signing-trace/`) |
| BouncyCastle copies in the JVM | Three: `bcprov-jdk18on-1.78.1` (classpath position 174), `bcprov-jdk15on-1.70` (233), and an unversioned shaded copy in `mock-certify-plugin.jar` (4,686 classes, loaded through `loader.path`) |
| Final ML-DSA (FIPS 204) / SLH-DSA (FIPS 205) | Absent from all three |
| Pre-standard Dilithium and SPHINCS+ | Present only in 1.78.1 |
| Other signing libraries | nimbus-jose-jwt 10.0.2, jose4j 0.6.5, data-integrity-java 1.17.0, ld-signatures-java 1.0.0, titanium-rdfc 2.0.0, tink 1.13.0, eddsa 0.3.0, three CBOR libraries |

Not checked: `mosip-identity-certify-plugin.jar` (not used by the FarmerCredential flow).
