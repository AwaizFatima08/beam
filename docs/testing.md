# Beam: testing

## Automated
| Suite | Command | Count |
|---|---|---|
| Unit + widget (host) | `flutter test` | 26 |
| On-device (real flash) | `flutter test integration_test/device_test.dart -d <device-id>` | 8 |
| Store screen renders | `flutter test tool/store_screens_test.dart` | 5 |

The on-device suite toggles the real flash through the native engine and waits for the Android
`TorchCallback` to confirm each change. Note: it installs a debug build and uninstalls it afterwards.

## Device test report: Samsung Galaxy A12 (SM-A125F), Android 12, 720×1600 — 2026-09-27
All results below were observed on the physical phone (release and debug builds).

| Check | Result |
|---|---|
| Launch, cold start (release, warm install) | ~0.75 s (`am start -W`) |
| Torch on/off from the power button | Pass: camera service log shows on/off for `com.homilabs.beam` |
| Quick-settings torch toggled off while Beam showed ON | Pass: Beam switched to OFF by itself |
| Intensity | This phone reports `maxStrength=1` (Android 12), so the slider is hidden and the "fixed brightness" note is shown. The strength path is covered by widget tests with a fake flash; it still needs a real Android 13+ device with a dimmable flash. |
| Strobe 5 Hz | Exactly 10 cycles every 2.000 s (native log), no drift; each flash switch takes ~17–25 ms on this driver |
| Strobe 15 Hz (max) | 10 cycles every 0.670 s = 15.0 Hz; switch lag ≤ 23 ms |
| SOS one-shot | Finished by itself and ended with the flash off (2.04 s pattern, ~2.4 s including round trips) |
| Morse | "HI" played; readout rendered correctly |
| Power button during a signal | Switches to a steady light |
| App sent to background while strobing | Strobe stopped immediately, flash left off |
| Photosensitivity warning | Shown once before the first signal |
| Screen glow | Window brightness override 1.0 → 0.83 after a downward swipe; `FLAG_KEEP_SCREEN_ON` set; both released (override `NaN`) on exit; colour fills the notch area |
| Screen-output signal | Full-screen SOS flashes at brightness 1.0; tap stops it; flash untouched |
| Permissions | Release APK requests none (no CAMERA, no INTERNET) |

Device captures are in `docs/device-test-captures/`.

### Issues found on the device and fixed
- Start button fell below the fold at this screen size / font scale → action buttons pinned to the bottom of each tab.
- Screen-light preview pushed the saturation and brightness controls off-screen → smaller preview.
- Black bar beside the camera notch during the glow → `LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES`.
- Output selector hid the active output while a signal ran → kept enabled (switching output stops the flash).
- Fixed-brightness card showed a disabled slider plus a paragraph → one short note.

### Still worth checking by hand
- A phone on Android 13+ with a dimmable flash (Pixel 7 or newer, recent Samsung S-series): the intensity slider should change the real brightness.
- A phone without a flash (some tablets): Torch shows "No flash", signals default to Screen.
