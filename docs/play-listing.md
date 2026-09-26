# Beam: Google Play listing kit (v1.0.0)

Copy-paste values for Play Console. Everything here matches v1.0.0 (versionCode 1), which ships **without ads**.
When the ad SDK is added, update the items marked **[ADS]** before that release goes out.

## App details
| Field | Value |
|---|---|
| App name (≤30) | `Beam: Torch, Strobe & SOS` |
| Package | `com.homilabs.beam` (locked after first upload) |
| Default language | English (United Kingdom) — or English (US) if you prefer |
| App or game | App |
| Free or paid | Free |
| Category | Tools |
| Tags (suggested) | Flashlight, Tools, Utilities |
| Contact email | `homilabs.smc@gmail.com` (**confirm**: copied from your EchoSteps listing) |
| Privacy policy URL | `https://tools.homilabs.org/privacy#beam` |
| Website (optional) | `https://tools.homilabs.org/#beam` |

## Short description (≤80)
```
Bright torch, strobe, SOS & Morse signals, plus a colour screen light. No login.
```

## Full description (≤4000)
```
Beam turns your phone into a simple, powerful light. No account, no sign-in, nothing to set up. Open it and tap.

TORCH
• One big switch for instant light
• Adjustable brightness on phones that support it (Android 13 and newer with a compatible flash)
• Stays in sync with the torch in your quick settings

SIGNALS
• Strobe from 1 to 15 flashes a second
• SOS distress signal in proper Morse timing
• Morse code: type any message and Beam flashes it, with a live dot-dash readout
• Adjustable speed, repeat or play once
• Send signals with the flash or with the whole screen

SCREEN LIGHT
• Turn the whole screen into a soft lamp
• Any colour: warm white for reading, red to keep your night vision, or any shade you like
• Adjust brightness with a slider or by swiping up and down
• Keeps the screen awake while it glows

SMALL AND PRIVATE
• No login and no account
• Works fully offline
• Needs no permissions — not even camera access
• Settings stay on your phone

Safety: signals flash rapidly. Flashing light can trigger seizures in people with photosensitive epilepsy. Never shine the light into anyone's eyes.
```
**[ADS]** Add a line such as "Beam is free and supported by ads." when ads ship.

## Graphics (in `store-assets/`)
| Asset | File | Spec |
|---|---|---|
| App icon | `icon-512.png` | 512×512 PNG, Play applies the round mask |
| Feature graphic | `feature-graphic-1024x500.png` | 1024×500 PNG |
| Phone screenshots | `screenshots/01-torch.png` … `05-glow.png` | 1080×1920 (9:16), 5 images |

Tablet screenshots are optional; Beam is a phone app (portrait only).

## Store settings answers
- **Ads**: *Does your app contain ads?* → **No** for v1.0.0. **[ADS]** switch to **Yes** in the same release that adds the SDK.
- **App access**: All functionality is available without special access.
- **Content rating** (IARC questionnaire): category *Utility, Productivity, Communication, or Other*. Answer **No** to violence, sexuality, language, controlled substances, gambling, user interaction/sharing, location sharing, digital purchases. Expected rating: Everyone / PEGI 3.
- **Target audience**: 13–15, 16–17, 18+ (do **not** include under-13s: that pulls Beam into the Families policy, which restricts which ad networks you can use later).
- **News app**: No. **Government app**: No. **Financial features**: none. **Health**: none.
- **Data safety** (v1.0.0): *Does your app collect or share any of the required user data types?* → **No**. Encryption in transit: not applicable (no network). Deletion request: not applicable (no data collected).
  **[ADS]** With AdMob this changes to **Yes**: Device or other IDs (advertising ID) and App activity / App interactions, plus Diagnostics (crash logs, performance) — collected and **shared** for Advertising or marketing, Analytics and Fraud prevention. Also declare the `AD_ID` permission in the Advertising ID declaration.
- **Photosensitivity**: not a Play form, but the in-app warning and the description line above cover it.

## Release
- Upload `releases/v1.0.0-1/beam-1.0.0-1.aab` to a testing track first (Internal testing is instant), then Production.
- Play App Signing: accept Google-managed signing. The upload key is `.secrets/beam-upload.keystore` (password in `.secrets/README.txt`; both in the local and Drive backups, never in Git).
- Release name: `1.0.0 (1)`. Release notes:
```
First release: torch, adjustable strobe, SOS and Morse signals, and a colour screen light.
```
- If your developer account is a *personal* account created after Nov 2023, Play requires a closed test with 12 testers for 14 days before Production access.

## Privacy policy and terms
Hosted on the HomiLabs tools site (source: `/mnt/storage/projects/homilabs_tools/site/`, uploaded to Hostinger):
- Privacy: `https://tools.homilabs.org/privacy#beam`
- Terms: `https://tools.homilabs.org/terms#beam`

**[ADS]** Update Beam's sections in `site/privacy.html` (and the Play Data safety form) before a version with ads is released.
