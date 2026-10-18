# Ads in Beam (AdMob)

From **1.1.0 (versionCode 3)** Beam is free and supported by Google AdMob. This is the HomiLabs ads test bed,
so the rules below are deliberately conservative.

## Formats and placements
| Placement id (stable) | Format | When it can appear |
|---|---|---|
| `home_banner` | Banner 320×50 | Above the bottom menu on the **Signal** and **Screen** tabs only. Never on the Torch tab, never while a glow, screen signal or dialog covers the screen (the banner is disposed, so it never refreshes unseen). |
| `screen_light_exit` | Interstitial | After the user closes the full-screen glow. |
| `signal_stopped` | Interstitial | After the user stops a flash signal, or leaves a screen signal. |
| `ad_free_reward` | Rewarded (opt-in) | "No ads for 24 hours — Watch a short ad" row above the banner. Shown **only while a rewarded ad is loaded** and the user isn't already ad-free. |

Rules, all enforced in one place (`Ads` in `lib/ads/ads.dart`):
- Interstitials: none in the first 60 s after launch, then at most one per 90 s, never while the torch or a signal is on.
- Rewarded: grants 24 h without banners and interstitials **only** when the ad is watched to the end (`Rewarded`);
  closing early (`Dismissed`) or no ad (`NoFill`) grants nothing. The pass is stored on the phone (`adFreeUntil`).
- Consent: Google's UMP form runs before the SDK starts (shown only where required, e.g. EEA/UK/CH). When the rules
  require it, About shows **Ad privacy choices**.

## Code map
- `lib/ads/ads.dart` — policy (`Ads`), the `AdNetwork` seam, `FrequencyCap`, `RewardOutcome`, placeholder and no-op networks.
- `lib/ads/admob_network.dart` — the only file that imports `google_mobile_ads`.
- `lib/ads/ad_ids.dart` — unit ids. Debug/profile always use Google's sample units; release uses `AdUnitIds.release`.
- `android/app/build.gradle.kts` — `admobAppId` manifest placeholder (sample for debug, Beam's id for release).
- Build switch: `--dart-define=BEAM_ADS=admob|placeholder|off` (default `admob`).

## Before every release with ads
1. `bash scripts/check-release-ad-ids.sh` must print PASS (it refuses Google's sample ids).
2. AdMob: Beam registered as an app (linked to the Play listing), 3 ad units (banner, interstitial, rewarded),
   **app-ads.txt**: already live at https://tools.homilabs.org/app-ads.txt (publisher `pub-2087846699268567`), which is Beam's Play website — nothing to add,
   and a GDPR + US-states consent message published in *Privacy & messaging*.
3. Privacy policy: Beam's section on tools.homilabs.org describes AdMob (source updated 2026-10-18; upload it
   **before** 1.1.0 goes live).
4. Play Console: Ads = **Yes**; Data safety and Advertising ID updated (see `docs/play-listing.md`, [ADS] items);
   store description no longer claims "no permissions" / "fully offline".
5. Test on a device with the sample ids (debug build) — never tap real ads on your own device.
