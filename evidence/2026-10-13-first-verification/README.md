# First verification, 2026-10-13 about 15:12 ICT

FarmerCredential issued at about 15:10 (Certify 0.14.0, `PreAuthDataProviderPlugin`), held in
Inji Wallet v0.22.1 on the Pixel 7, verified in Inji Verify 0.18.2 (UI at localhost:3000) by
uploading the wallet's QR code. Logs were not captured for this run.

| File | Content |
|---|---|
| `inji-verify-result.png` | Inji Verify result screen: "the given credential is valid" |

| Check | Observed |
|---|---|
| Verification result | Valid |
| Claims shown | All 14 CSV claims for id 2154189532: fullName, farmerID, gender, mobileNumber, dateOfBirth, landOwnershipType, villageOrTown, district, state, postalCode, landArea, primaryCropType, secondaryCropType, face (photo) |
| Signature suite (from issuer metadata) | `Ed25519Signature2020`, issuer `did:web:signing-regulated-grain-prior.trycloudflare.com` |

Unmodified issuer, wallet and verifier interoperate end to end. This is the classical
baseline for the later crypto-agility changes.
