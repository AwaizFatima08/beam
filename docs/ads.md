# Adding ads to Beam (test bed guide)

Beam v1.0.0 ships with **no ad SDK**. Every place an ad can appear is already wired up in
`lib/ads/ads.dart`, so adding a network only means implementing one class.

## What is already in place
| Placement id | Kind | Where / when |
|---|---|---|
| `home_banner` | Banner 320×50 | Above the bottom navigation on every tab (`AdBannerSlot` in `lib/views/home.dart`). |
| `screen_light_exit` | Interstitial | After the user leaves the full-screen glow (`lib/views/screen_tab.dart`). |
| `signal_stopped` | Interstitial | After the user stops a flash signal, or leaves a screen signal (`lib/views/signal_tab.dart`). |

Rules built in (keep them; they protect ratings and Play policy):
- An interstitial is **never** requested while a light or signal is running, only at the natural break after it.
- `FrequencyCap`: nothing in the first 60 s after launch, then at most one interstitial per 90 s.
- The banner slot reserves its 50 dp, so the layout does not jump when an ad loads.

Build modes (`--dart-define=BEAM_ADS=...`):
- `placeholder` — grey boxes/dialogs labelled with the placement id. **Default for debug/profile builds.**
- `off` — nothing. **Default for release builds.**
Every interstitial request is logged as `[ads] interstitial <placement> shown|capped`.

## Adding Google AdMob (recommended first network)
1. Create the app in AdMob, then one ad unit per placement (Banner for `home_banner`, Interstitial for the other two). Until the app is approved, use Google's **test** unit ids:
   - Banner `ca-app-pub-3940256099942544/6300978111`
   - Interstitial `ca-app-pub-3940256099942544/1033173712`
   - Test app id `ca-app-pub-3940256099942544~3347511713`
2. `flutter pub add google_mobile_ads`
3. `android/app/src/main/AndroidManifest.xml`, inside `<application>`:
   ```xml
   <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="ca-app-pub-XXXXXXXX~YYYYYYYY"/>
   ```
   The plugin adds the `INTERNET` and `AD_ID` permissions itself.
4. Add `lib/ads/admob_ad_service.dart` implementing `AdService`:
   - `banner()` returns a widget holding a `BannerAd` (`AdSize.banner`) for the placement's unit id.
   - `maybeShowInterstitial()` checks `cap.canShow`, shows a preloaded `InterstitialAd`, calls `cap.recordShown()`, and preloads the next one.
   - `MobileAds.instance.initialize()` in `main()` before `runApp`.
5. Add an `admob` mode to `AdService.fromEnvironment()` and build with `--dart-define=BEAM_ADS=admob`.
6. Consent: users in the EEA/UK need a consent form. Use the UMP SDK that ships with `google_mobile_ads` (`ConsentInformation.instance.requestConsentInfoUpdate` → `ConsentForm.loadAndShowConsentFormIfRequired`) before loading ads, and add a "Privacy options" entry point (e.g. a small settings sheet).

## Before releasing a version with ads
- Play Console: set **Contains ads = Yes**; update **Data safety** (see `docs/play-listing.md`, items marked [ADS]); fill in the Advertising ID declaration.
- Update `docs/privacy-policy.html` (and the hosted copy) to name the ad provider and what it collects.
- Remove the "No tracking"-type claims from any listing text (the current listing already avoids them).
- Keep the target audience at 13+ unless you use a Families-certified ad network.
- Bump `version:` in `pubspec.yaml`.
