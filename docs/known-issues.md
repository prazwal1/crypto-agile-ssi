# Known Issues

Environment problems met so far, how they showed up, and the fix in place. Dates link to `lab-notebook.md`.

| First seen | Symptom | Cause | Fix |
|---|---|---|---|
| 2026-10-04 | Docker images, Maven and Android SDK downloads fail from a cloud sandbox | Network restrictions in that environment | Run the stack and builds on the laptop |
| 2026-10-04 | Reference compose fails at the eSignet step | External eSignet dependency unavailable | Certify configured as its own OAuth server (pre-authorized code flow) |
| 2026-10-04 | Wallet cannot reach local services over HTTP | Android blocks cleartext; `did:web` needs public HTTPS | Cloudflare quick tunnels (`refresh-tunnels`) |
| 2026-10-04 | Wallet build fails in deep folders | Windows 260-character path limit | Wallet cloned to `C:\dev\inji-wallet`; `core.longpaths` enabled |
| 2026-10-08 | All HTTPS checks fail from PowerShell scripts | Windows PowerShell 5.1 defaults to TLS 1.0 | Scripts force TLS 1.2 (`scripts/common.ps1`) |
| 2026-10-08 | Failed checks give no reason | Errors were swallowed in a `catch {}` | Scripts report the HTTP status or error for every failure |
| 2026-10-08 | Mimoto `/actuator/health` returns 503 while serving normally | Redis check (no Redis here) and key alias check | Redis check disabled; readiness checked with `/v1/mimoto/issuers` |
| 2026-10-08 | Certify exits at start with `KER-KMA-004 No such alias` | Keystore on a relative path lived inside the container and was lost on recreate; DB kept the aliases | Absolute keystore path on the bind mount; `stack.ps1 reset-keys` for recovery |
| 2026-10-09 | Tunnel hostnames stop resolving; containers still Running | Cloudflare deletes quick tunnels after sleep or network loss | `refresh-tunnels` detects dead tunnels and recreates them; long-term see D-06 |
| 2026-10-09 | Dead hostnames reported as alive | `Resolve-DnsName` returns the zone SOA record for a missing name | Check requires an A record |
| 2026-10-09 | `certify-nginx` returns 502 after Certify restarts | nginx caches the upstream container address | nginx restarted after every Certify restart (`Restart-Issuer`) |
| 2026-10-09 | Credential offer rejected with `unknown_claims` | Upstream seed declares 4 of the 14 CSV claims | SQL patch 001 |
| 2026-10-09 | Credential offer fails with `credentialOfferCache not available` | Cache list in the injistack-derived config predates Certify 0.14.0; offer and pre-auth caches not declared | Cache names, sizes and expiry aligned with Certify 0.14.0 defaults in `certify-default.properties` |
| 2026-10-10 | Wallet prerequisite check finds JDK 25 | Current Android Studio bundles JDK 25; Gradle 8.6 runs only on Java 17 to 21 | Separate Temurin 17 install; `env/wallet/find-jdk.ps1` selects a 17 to 21 JDK and the setup fails clearly otherwise |
| 2026-10-10 | Android SDK missing after installing Android Studio | The SDK is downloaded by the first-run wizard, not by the installer | Open Android Studio once and complete the Standard setup |
| 2026-10-10 | After a reboot only the tunnels, Certify and PostgreSQL were running; Mimoto and Verify absent (Mimoto tunnel 502) | Containers had no restart policy; `refresh-tunnels` started only the services it touched | `restart: unless-stopped` on every service; `refresh-tunnels` now brings the whole stack up first |
| 2026-10-09 | Certify logs `InsufficientAuthenticationException` shortly after each start | Not yet investigated; no functional impact seen | Open |
