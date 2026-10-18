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

  /// Beam's real units. Replace with the ids from AdMob before releasing.
  static const release = AdUnitIds(
    banner: 'ca-app-pub-3940256099942544/6300978111',
    interstitial: 'ca-app-pub-3940256099942544/1033173712',
    rewarded: 'ca-app-pub-3940256099942544/5224354917',
  );

  /// Debug and profile builds always use the sample units, so testing on a
  /// device can never produce invalid traffic on Beam's real account.
  static AdUnitIds get current => kReleaseMode ? release : sample;
}
