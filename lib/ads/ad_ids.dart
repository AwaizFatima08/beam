import 'package:flutter/foundation.dart';

/// AdMob unit ids. These are configuration, not secrets (they are visible in
/// any decompiled app), so they live here as constants.
///
/// Release builds must use Beam's own units from the HomiLabs AdMob account.
/// `scripts/check-release-ad-ids.sh` fails a release while any of them is
/// still Google's sample id — sample ids serve "Test Ad" creatives and earn
/// nothing. The AdMob *app* id lives in android/app/build.gradle.kts.
class AdUnitIds {
  const AdUnitIds({required this.banner, required this.interstitial, required this.rewarded});

  final String banner;
  final String interstitial;
  final String rewarded;

  /// Google's published Android sample units (always fill, never pay).
  static const sample = AdUnitIds(
    banner: 'ca-app-pub-3940256099942544/6300978111',
    interstitial: 'ca-app-pub-3940256099942544/1033173712',
    rewarded: 'ca-app-pub-3940256099942544/5224354917',
  );

  /// Beam's own units in the HomiLabs AdMob account (app 4314351695),
  /// created 2026-10-18. Names in AdMob match the placement ids.
  static const release = AdUnitIds(
    banner: 'ca-app-pub-2087846699268567/1688188358', // Beam home_banner
    interstitial: 'ca-app-pub-2087846699268567/5807221758', // Beam interstitial (glow exit, signal stop)
    rewarded: 'ca-app-pub-2087846699268567/9670620150', // Beam ad_free_reward (24 h ad-free)
  );

  /// Debug and profile builds always use the sample units, so testing on a
  /// device can never produce invalid traffic on Beam's real account.
  static AdUnitIds get current => kReleaseMode ? release : sample;
}
