# Beam

Torch, strobe, SOS/Morse signals and a colour screen light for Android. No login, no permissions, works offline.
Built as a clean, small app to serve as a test bed for in-app ads (see [docs/ads.md](docs/ads.md)).

| | |
|---|---|
| Torch | One-tap flash; adjustable brightness on Android 13+ phones with a dimmable flash; follows the quick-settings toggle |
| Signal | Strobe 1–15 Hz, SOS, Morse code from any text; speed and repeat; output on the flash or the screen |
| Screen light | Full-screen colour lamp: presets, hue, saturation, brightness (slider or swipe), keeps the screen awake |

## Build and run
```bash
flutter pub get
flutter run                       # debug: ad placeholders visible
flutter build appbundle --release # Play upload (needs android/key.properties, see below)
```

## Tests
```bash
flutter test                                              # 26 host tests
flutter test integration_test/device_test.dart -d <id>    # 8 tests on a real phone
```
Report: [docs/testing.md](docs/testing.md).

## Graphics
```bash
flutter test tool/store_screens_test.dart && flutter test tool/make_graphics_test.dart
```
Regenerates launcher icons, the Play icon, the feature graphic and the store screenshots in `store-assets/`.

## Layout
- `android/app/src/main/kotlin/com/homilabs/beam/` — `TorchEngine.kt` (flash, strength, pattern player on its own thread), `MainActivity.kt` (channels, screen brightness, keep-awake, lifecycle)
- `lib/core/signals.dart` — Morse/SOS/strobe timing
- `lib/services/` — torch controller, screen control, settings
- `lib/ads/ads.dart` — ad placements, frequency cap, placeholder service
- `lib/views/`, `lib/widgets/` — UI
- `docs/` — Play listing kit, privacy policy, ads guide, test report

Release signing reads `android/key.properties` (gitignored) pointing at `.secrets/beam-upload.keystore` (gitignored; kept in the local and Drive backups only).
