# Beam: Torch, Strobe & SOS

Flutter, **Android only**, portrait. Package `com.homilabs.beam` — never change it after the first Play upload. Developer: HomiLabs.
Purpose: a simple free utility that doubles as a **test bed for in-app ads**.

## Locked decisions
- No login, no accounts, no network in v1 (release APK has **no permissions**). The flash is driven with `CameraManager.setTorchMode` / `turnOnTorchWithStrengthLevel`, which need no CAMERA permission.
- Torch code lives natively in `TorchEngine.kt` on a dedicated HandlerThread; patterns are played natively with absolute deadlines (no drift). Dart only sends duration lists.
- Strobes stop when the app goes to the background; a steady torch stays on (like the system toggle). Swiping the app away turns it off.
- Flashing-light warning before the first signal. Strobe capped at 15 Hz.
- Ads: every slot goes through `lib/ads/ads.dart` (`AdPlacement` ids are stable — ad dashboards use them). Debug/profile builds show placeholders; release shows nothing until a real `AdService` exists. Never show an interstitial while a light is running. See `docs/ads.md`.

## Status (2026-10-02)
Play app created in the Homilabs org account (app id 4975968279685186807); listing, content rating and all App content declarations done. versionCode 1 (1.0.0) was uploaded without the in-app privacy link and is burned; the production release uses **1.0.1 (versionCode 2)** from `releases/v1.0.1-2/` (adds the About sheet with Privacy/Terms links). Next versionCode must be ≥ 3.
Privacy policy and terms live on the shared tools site: https://tools.homilabs.org/privacy#beam and /terms#beam (source `/mnt/storage/projects/homilabs_tools/site/`, manual upload to Hostinger).
**Live on Google Play** since 2026-10-02: 1.0.1 (versionCode 2) in production — https://play.google.com/store/apps/details?id=com.homilabs.beam
Homi will review user feedback around **2026-11-02** and then decide on a revision/upgrade (likely candidates: AdMob per `docs/ads.md`, anything raised in reviews). Next versionCode must be ≥ 3.
Open item: the About sheet (1.0.1) has not been checked on the test phone yet (it was unplugged when 1.0.1 was built).

## Commands
- Tests: `flutter test` (28). Device: `flutter test integration_test/device_test.dart -d R58R61F3FDK` (8; uninstalls the app afterwards).
- Graphics: `flutter test tool/store_screens_test.dart && flutter test tool/make_graphics_test.dart`.
- Release: `flutter build appbundle --release` and `flutter build apk --release` (signs via `android/key.properties` → `.secrets/beam-upload.keystore`).
- Backup: `bash scripts/backup.sh` (commit first; the GitHub layer refuses untracked/uncommitted files).

## Locations
- Local backup: `/mnt/storage/project_backups/torch_backup/`
- Google Drive: folder `1CGrcE4hpvV7SibW6bdpwmdAclVwPM3ZM` (rclone remote `gdrive`)
- GitHub (**public**): `https://github.com/AwaizFatima08/beam`. `.secrets/`, `android/key.properties` and `releases/` are gitignored.

## Machine notes
- Test phone: Samsung Galaxy A12 SM-A125F, Android 12, id `R58R61F3FDK`. No flash strength API (maxStrength 1).
- Debug builds start slowly on this phone (~6 s); wait before sending taps. Release cold start ~0.75 s.
- Flash state for checks: `adb shell dumpsys media.camera | grep -A3 "torch events log"`; window brightness: `adb shell dumpsys power | grep BrightnessOverrideFromWindow`.
