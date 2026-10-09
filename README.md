# Crypto-Agile Architecture for W3C DID/VC Wallets

Research code and evidence for a Master's thesis (Computer Science, Asian Institute of Technology) on crypto-agility in W3C Decentralized Identifier and Verifiable Credential systems. The prototype platform is the MOSIP Inji stack (Inji Wallet, Mimoto, Inji Certify, Inji Verify).

Author: Prajwal Bhandary
Supervisor: Aj. George

## Research questions

| RQ | Focus | Where in this repo |
|---|---|---|
| RQ1 | Cryptographic dependency mapping in W3C DID/VC systems | `phase1-dependency-analysis/` |
| RQ2 | Design principles for crypto-agile architectures | `docs/decisions.md` (later phases) |
| RQ3 | Architecture artifact: Crypto Service Layer | later phases |
| RQ4 | Evaluation of the architecture | `evidence/` |

## Repository layout

| Path | Contents |
|---|---|
| `docs/architecture.md` | Local environment architecture and why public tunnels are needed |
| `docs/lab-notebook.md` | Dated record of every working session: what was done, observed and changed |
| `docs/decisions.md` | Open and closed design and scope decisions |
| `docs/known-issues.md` | Environment problems encountered and their fixes |
| `env/stack/` | Docker Compose environment: Certify, Mimoto, Verify, PostgreSQL, tunnels |
| `env/wallet/` | Scripts to set up, build and run the Inji Wallet working copy |
| `phase1-dependency-analysis/` | Pinned source baseline, static scanner, inventory, findings |
| `evidence/` | Dated, unedited captures (issuer metadata, run logs) cited in the thesis |

## Reproducing the environment

Requirements: Windows 10/11 with Docker Desktop (WSL2), Git, Node 20, JDK 17, Android Studio (SDK), Python 3 with PyYAML, ripgrep.

```powershell
cd env\stack
.\stack.ps1 start              # pull, start, publish tunnels, health check
.\stack.ps1 apply-patches      # apply configuration patches in sql\patches
.\stack.ps1 capture-baseline   # record issuer DID and metadata under evidence\
.\stack.ps1 issue-offer        # create a test credential offer (QR)

cd ..\wallet
.\setup-wallet.ps1             # clone pinned wallet, install dependencies
.\run-wallet.ps1               # build and launch on a USB phone

cd ..\..\phase1-dependency-analysis
.\tools\clone-baseline.ps1     # clone all pinned repositories
python -I tools\scan.py .      # regenerate results\
```

Every `stack.ps1` run writes its console output to `env\stack\logs\` (not versioned). Runs worth citing are copied into `evidence\`.

## Pinned versions

See `phase1-dependency-analysis/manifest.tsv` for exact commit hashes. Inji Wallet v0.22.1 is the anchor; native library versions come from its `android/app/build.gradle`. Server images: Certify 0.14.0, Mimoto 0.21.0, Verify 0.18.2, cloudflared 2026.9.3.

## Tool use

Parts of the environment tooling (setup scripts, the static scanner) were drafted with the help of an AI assistant (Claude, Anthropic) and then run, checked and adapted by the author. Research design, interpretation of results and the thesis text are the author's own.

## Licence

To be decided before the repository is made public. Configuration files derived from MOSIP repositories retain their original MPL-2.0 licence.
