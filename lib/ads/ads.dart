import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/settings.dart';

/// Ads policy layer. No ad SDK type appears in this file: the network (AdMob,
/// placeholders, nothing) sits behind [AdNetwork], and everything the app is
/// allowed to do with it — caps, the ad-free pass, "never while a light is
/// on" — lives in [Ads]. Views only ever talk to [Ads]. See docs/ads.md.
enum AdPlacement {
  /// Banner above the bottom navigation, on the Signal and Screen tabs only
  /// (never on the Torch tab, never under a light or glow).
  homeBanner('home_banner'),

  /// Full-screen ad after leaving the full-screen colour glow.
  screenLightExit('screen_light_exit'),

  /// Full-screen ad after the user stops a strobe / SOS / Morse signal.
  signalStopped('signal_stopped'),

  /// Opt-in rewarded ad that grants 24 hours without ads.
  adFreeReward('ad_free_reward');

  const AdPlacement(this.id);

  /// Stable id used in logs and ad dashboards — never rename.
  final String id;
}

/// Standard banner height (320x50). The slot keeps this height reserved so a
/// loading banner never shifts the controls.
const double bannerHeight = 50;

/// How a rewarded view ended. Only [Rewarded] grants anything.
sealed class RewardOutcome {
  const RewardOutcome();
}

final class Rewarded extends RewardOutcome {
  const Rewarded();
}

/// The user closed the ad before earning the reward.
final class Dismissed extends RewardOutcome {
  const Dismissed();
}

/// There was no ad to show.
final class NoFill extends RewardOutcome {
  const NoFill();
}

/// The ad network behind the policy. Implementations do mechanics only:
/// load, show, report. They never decide *whether* an ad should appear.
abstract class AdNetwork {
  bool get enabled;

  /// Consent (EEA/UK) and SDK start-up. Safe to call more than once.
  Future<void> init();

  /// A self-loading banner widget for [placement].
  Widget banner(AdPlacement placement);

  /// Shows a preloaded interstitial if one is ready. Returns whether it showed.
  Future<bool> showInterstitial(BuildContext context, AdPlacement placement);

  /// True while a rewarded ad is loaded and could be shown right now.
  ValueListenable<bool> get rewardedReady;

  Future<RewardOutcome> showRewarded(BuildContext context, AdPlacement placement);

  /// Whether the consent rules require an in-app "privacy choices" entry.
  ValueListenable<bool> get privacyOptionsRequired;

  Future<void> showPrivacyOptions();
}

/// Minimum spacing between full-screen ads, plus a grace period after launch
/// so the first thing a user sees is the torch, not an ad.
class FrequencyCap {
  FrequencyCap({
    this.minInterval = const Duration(seconds: 90),
    this.launchGrace = const Duration(seconds: 60),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _startedAt = (clock ?? DateTime.now)();

  final Duration minInterval;
  final Duration launchGrace;
  final DateTime Function() _clock;
  final DateTime _startedAt;
  DateTime? _lastShown;

  bool get canShow {
    final now = _clock();
    if (now.difference(_startedAt) < launchGrace) return false;
    final last = _lastShown;
    return last == null || now.difference(last) >= minInterval;
  }

  void recordShown() => _lastShown = _clock();
}

/// The single gate for every ad decision in the app.
class Ads extends ChangeNotifier {
  Ads({
    required this.network,
    required Settings settings,
    required bool Function() isLightOn,
    FrequencyCap? cap,
    DateTime Function()? clock,
  }) : _settings = settings,
       _isLightOn = isLightOn,
       _clock = clock ?? DateTime.now,
       cap = cap ?? FrequencyCap(clock: clock) {
    network.rewardedReady.addListener(notifyListeners);
    network.privacyOptionsRequired.addListener(notifyListeners);
  }

  /// How long one completed rewarded ad keeps Beam ad-free.
  static const adFreeDuration = Duration(hours: 24);

  final AdNetwork network;
  final FrequencyCap cap;
  final Settings _settings;
  final bool Function() _isLightOn;
  final DateTime Function() _clock;
  bool _initStarted = false;

  /// Every interstitial decision, for logs and tests.
  final List<String> log = [];

  bool get enabled => network.enabled;

  DateTime? get adFreeUntil {
    final until = _settings.adFreeUntil;
    return until != null && until.isAfter(_clock()) ? until : null;
  }

  bool get isAdFree => adFreeUntil != null;

  /// True when the "no ads for 24 hours" offer may be shown: ads are on, the
  /// user isn't already ad-free, and an ad is genuinely loaded (so the offer
  /// can never answer "no ads available").
  bool get canOfferAdFree => enabled && !isAdFree && network.rewardedReady.value;

  bool get privacyOptionsRequired => enabled && network.privacyOptionsRequired.value;

  Future<void> init() async {
    if (!enabled || _initStarted) return;
    _initStarted = true;
    await network.init();
  }

  /// A banner for [placement], or null when none may be shown.
  Widget? banner(AdPlacement placement) {
    if (!enabled || isAdFree) return null;
    return network.banner(placement);
  }

  /// Called at natural breaks only. Owns every rule: ad-free pass, light on,
  /// launch grace and spacing. Returns whether an ad actually showed.
  Future<bool> maybeShowInterstitial(BuildContext context, AdPlacement placement) async {
    final String reason;
    if (!enabled) {
      reason = 'off';
    } else if (isAdFree) {
      reason = 'ad-free';
    } else if (_isLightOn()) {
      reason = 'light-on';
    } else if (!cap.canShow) {
      reason = 'capped';
    } else if (!context.mounted) {
      reason = 'unmounted';
    } else {
      final shown = await network.showInterstitial(context, placement);
      if (shown) cap.recordShown();
      reason = shown ? 'shown' : 'not-ready';
    }
    log.add('${placement.id}:$reason');
    debugPrint('[ads] interstitial ${placement.id} $reason');
    return reason == 'shown';
  }

  /// Opt-in: plays a rewarded ad and grants [adFreeDuration] only when the ad
  /// was watched to the end. Dismissed / no fill leave everything unchanged.
  Future<RewardOutcome> watchForAdFree(BuildContext context) async {
    if (!canOfferAdFree) return const NoFill();
    final outcome = await network.showRewarded(context, AdPlacement.adFreeReward);
    switch (outcome) {
      case Rewarded():
        _settings.adFreeUntil = _clock().add(adFreeDuration);
      case Dismissed():
      case NoFill():
        break;
    }
    log.add('${AdPlacement.adFreeReward.id}:${outcome.runtimeType}');
    notifyListeners();
    return outcome;
  }

  Future<void> showPrivacyOptions() => network.showPrivacyOptions();

  @override
  void dispose() {
    network.rewardedReady.removeListener(notifyListeners);
    network.privacyOptionsRequired.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Ads switched off (`--dart-define=BEAM_ADS=off`).
class NoAdNetwork implements AdNetwork {
  NoAdNetwork();

  @override
  bool get enabled => false;

  @override
  Future<void> init() async {}

  @override
  Widget banner(AdPlacement placement) => const SizedBox.shrink();

  @override
  Future<bool> showInterstitial(BuildContext context, AdPlacement placement) async => false;

  @override
  final ValueListenable<bool> rewardedReady = ValueNotifier(false);

  @override
  Future<RewardOutcome> showRewarded(BuildContext context, AdPlacement placement) async => const NoFill();

  @override
  final ValueListenable<bool> privacyOptionsRequired = ValueNotifier(false);

  @override
  Future<void> showPrivacyOptions() async {}
}

/// Visible stand-ins (`--dart-define=BEAM_ADS=placeholder`, and in tests), so
/// placements and the rewarded flow can be checked without any network.
class PlaceholderAdNetwork implements AdNetwork {
  PlaceholderAdNetwork({bool rewardedLoaded = true}) : rewardedReady = ValueNotifier(rewardedLoaded);

  int initCount = 0;

  @override
  bool get enabled => true;

  @override
  Future<void> init() async => initCount++;

  @override
  Widget banner(AdPlacement placement) => _PlaceholderBanner(placement);

  @override
  Future<bool> showInterstitial(BuildContext context, AdPlacement placement) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('ad-interstitial'),
        title: const Text('Interstitial ad slot'),
        content: Text('Placement: ${placement.id}\n\nA full-screen ad would appear here.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
    return true;
  }

  @override
  final ValueNotifier<bool> rewardedReady;

  @override
  Future<RewardOutcome> showRewarded(BuildContext context, AdPlacement placement) async {
    final watched = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('ad-rewarded'),
        title: const Text('Rewarded ad slot'),
        content: Text('Placement: ${placement.id}'),
        actions: [
          TextButton(
            key: const Key('ad-rewarded-close'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Close early'),
          ),
          TextButton(
            key: const Key('ad-rewarded-finish'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Watch to the end'),
          ),
        ],
      ),
    );
    return watched == true ? const Rewarded() : const Dismissed();
  }

  @override
  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier(false);

  @override
  Future<void> showPrivacyOptions() async {}
}

class _PlaceholderBanner extends StatelessWidget {
  const _PlaceholderBanner(this.placement);
  final AdPlacement placement;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      key: Key('ad-banner-${placement.id}'),
      height: bannerHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border.all(color: c.outlineVariant),
      ),
      child: Text(
        'Ad slot · ${placement.id} · 320×50',
        style: TextStyle(color: c.onSurfaceVariant, fontSize: 12, letterSpacing: 0.3),
      ),
    );
  }
}

/// Reserves the banner area. Collapses to nothing when no banner may show.
class AdBannerSlot extends StatelessWidget {
  const AdBannerSlot({super.key, required this.ads, required this.placement});
  final Ads ads;
  final AdPlacement placement;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ads,
      builder: (context, _) {
        final b = ads.banner(placement);
        if (b == null) return const SizedBox.shrink();
        return SizedBox(height: bannerHeight, width: double.infinity, child: b);
      },
    );
  }
}
