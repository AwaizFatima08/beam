# Beam: work in progress (2026-09-27)
Done: Flutter project (com.homilabs.beam), native torch engine (android/.../TorchEngine.kt, MainActivity.kt:
steady torch, Android 13+ strength levels, background-thread pattern player, screen brightness/keep-on),
lib/core/signals.dart (Morse/SOS/strobe patterns), lib/services/{torch,screen,settings}.dart, lib/ads/ads.dart
(ad placements, placeholder banner/interstitial, frequency cap), lib/main.dart, lib/app.dart.
TODO: lib/views/home.dart (tabs Torch / Signal / Screen + banner slot), glow page, screen-signal page,
flash warning dialog, unit + widget tests, on-device tests on SM-A125F (Android 12: no strength API),
scripts/backup.sh (local + gdrive folder 1CGrcE4hpvV7SibW6bdpwmdAclVwPM3ZM + GitHub AwaizFatima08/beam, public).
App does NOT compile yet (views/home.dart missing).
