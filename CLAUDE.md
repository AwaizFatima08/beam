# Beam: Torch, Strobe & SOS

Flutter, **Android only**, portrait. Package `com.homilabs.beam` — never change it after the first Play upload. Developer: HomiLabs.
Purpose: a simple free utility that doubles as a **test bed for in-app ads**.

## Locked decisions
- No login, no accounts. v1.0.x had no permissions; from 1.1.0 the AdMob SDK adds internet, network state and advertising ID (nothing else is requested). The flash is driven with `CameraManager.setTorchMode` / `turnOnTorchWithStrengthLevel`, which need no CAMERA permission.
- Torch code lives natively in `TorchEngine.kt` on a dedicated HandlerThread; patterns are played natively with absolute deadlines (no drift). Dart only sends duration lists.
- Strobes stop when the app goes to the background; a steady torch stays on (like the system toggle). Swiping the app away turns it off.
- Flashing-light warning before the first signal. Strobe capped at 15 Hz.
- Ads (from 1.1.0): Google AdMob behind `AdNetwork`; every rule lives in `Ads` (`lib/ads/ads.dart`); only `lib/ads/admob_network.dart` imports the SDK. `AdPlacement` ids are stable. No banner on the Torch tab or under a glow/dialog; interstitials only after glow exit / signal stop, 60 s launch grace, 90 s spacing, never while a light is on; opt-in rewarded = 24 h ad-free, granted only on `Rewarded`. Debug/profile always use Google sample ids; `scripts/check-release-ad-ids.sh` must PASS before a release build. See `docs/ads.md`.

## Status (2026-10-18)
Play app created in the Homilabs org account (app id 4975968279685186807); listing, content rating and all App content declarations done. versionCode 1 (1.0.0) was uploaded without the in-app privacy link and is burned; the production release uses **1.0.1 (versionCode 2)** from `releases/v1.0.1-2/` (adds the About sheet with Privacy/Terms links). Next versionCode must be ≥ 3.
Privacy policy and terms live on the shared tools site: https://tools.homilabs.org/privacy#beam and /terms#beam (source `/mnt/storage/projects/homilabs_tools/site/`, manual upload to Hostinger).
**Live on Google Play** since 2026-10-02: 1.0.1 (versionCode 2) in production — https://play.google.com/store/apps/details?id=com.homilabs.beam
Homi will review user feedback around **2026-11-02** and then decide on a revision/upgrade (likely candidates: AdMob per `docs/ads.md`, anything raised in reviews). Next versionCode must be ≥ 3.
**1.1.0 (versionCode 3) — AdMob:** Beam registered in the HomiLabs AdMob account (AdMob app 4314351695, app id `ca-app-pub-2087846699268567~4314351695`, under Google review from 2026-10-18), units: banner `…/1688188358`, interstitial `…/5807221758`, rewarded `…/9670620150`. Release check PASS; signed AAB/APK in `releases/v1.1.0-3/`. Verified on the `beam_api35` emulator with sample ids (2026-10-18): no banner on Torch tab, banner + offer on Signal/Screen, rewarded → 24 h ad-free, interstitial after glow exit. Done 2026-10-19: privacy policy (Beam section v1.1.0) and site card live on tools.homilabs.org; Play Console changes saved but **not submitted**: Ads = Yes, Advertising ID = used (Advertising, Analytics, Fraud prevention), Data safety = collects+shares approx. location, app interactions, crash logs, diagnostics, device IDs (required; encrypted in transit; no deletion request), new full description, AI asset declaration = don't label. Managed publishing is OFF. Still to do (Homi): upload `releases/v1.1.0-3/beam-1.1.0-3.aab` to a production release with the notes in `docs/play-listing.md`, then send everything for review together.
Open item: the About sheet has not been checked on a real phone yet.

## Commands
- Tests: `flutter test` (40). Device: `flutter test integration_test/device_test.dart -d R58R61F3FDK` (8; uninstalls the app afterwards).
- Graphics: `flutter test tool/store_screens_test.dart && flutter test tool/make_graphics_test.dart`.
- Release: `bash scripts/check-release-ad-ids.sh` (must PASS), then `flutter build appbundle --release` and `flutter build apk --release` (signs via `android/key.properties` → `.secrets/beam-upload.keystore`).
- Backup: `bash scripts/backup.sh` (commit first; the GitHub layer refuses untracked/uncommitted files).

## Locations
- Local backup: `/mnt/storage/project_backups/torch_backup/`
- Google Drive: folder `1CGrcE4hpvV7SibW6bdpwmdAclVwPM3ZM` (rclone remote `gdrive`)
- GitHub (**public**): `https://github.com/AwaizFatima08/beam`. `.secrets/`, `android/key.properties` and `releases/` are gitignored.

## Machine notes
- Test phone: Samsung Galaxy A12 SM-A125F, Android 12, id `R58R61F3FDK`. No flash strength API (maxStrength 1).
- Debug builds start slowly on this phone (~6 s); wait before sending taps. Release cold start ~0.75 s.
- Emulator: dedicated AVD `beam_api35` (`ANDROID_AVD_HOME=/mnt/storage/projects/android-avd`), port 5590. Follow `~/.claude/heavy-jobs.md` (one heavy job at a time, RAM check, GPU not usable for emulator GLES yet).
- Flash state for checks: `adb shell dumpsys media.camera | grep -A3 "torch events log"`; window brightness: `adb shell dumpsys power | grep BrightnessOverrideFromWindow`.
