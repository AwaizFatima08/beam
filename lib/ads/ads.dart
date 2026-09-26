import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Ad scaffolding. Beam ships with no ad SDK; this file is the single seam
/// where one plugs in (see docs/ads.md). Every place the app could show an ad
/// is a named [AdPlacement], so a real network only needs to implement
/// [AdService] and be returned from [AdService.fromEnvironment].
enum AdPlacement {
  /// Banner pinned above the bottom navigation on every tab.
  homeBanner('home_banner'),

  /// Full-screen ad after leaving the full-screen colour glow.
  screenLightExit('screen_light_exit'),

  /// Full-screen ad after the user stops a strobe / SOS / Morse signal.
  signalStopped('signal_stopped');

  const AdPlacement(this.id);
  final String id;
}

/// Standard banner height (AdMob/most networks: 320x50). The slot keeps this
/// height reserved so turning ads on never shifts the controls.
const double bannerHeight = 50;

abstract class AdService {
  /// Chooses the implementation from `--dart-define=BEAM_ADS=off|placeholder`.
  /// Default: placeholders in debug/profile builds, nothing in release.
  factory AdService.fromEnvironment() {
    const mode = String.fromEnvironment('BEAM_ADS');
    final placeholder = mode == 'placeholder' || (mode.isEmpty && !kReleaseMode);
    return placeholder ? PlaceholderAdService() : const NoAdService();
  }

  bool get enabled;

  /// A banner for [placement], or null when there is nothing to show.
  Widget? banner(AdPlacement placement);

  /// Called at natural breaks. Implementations decide (with [FrequencyCap])
  /// whether to actually show something. Never called while a light is on.
  Future<void> maybeShowInterstitial(BuildContext context, AdPlacement placement);
}

class NoAdService implements AdService {
  const NoAdService();

  @override
  bool get enabled => false;

  @override
  Widget? banner(AdPlacement placement) => null;

  @override
  Future<void> maybeShowInterstitial(BuildContext context, AdPlacement placement) async {}
}

/// Minimum spacing between full-screen ads, plus a grace period after launch
/// so the first thing a user sees is the torch, not an ad.
class FrequencyCap {
  FrequencyCap({
    this.minInterval = const Duration(seconds: 90),
    this.launchGrace = const Duration(seconds: 60),
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
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

/// Visible stand-ins used while developing, so placements and layout can be
/// checked on a device before any ad network is added.
class PlaceholderAdService implements AdService {
  PlaceholderAdService({FrequencyCap? cap}) : cap = cap ?? FrequencyCap();

  final FrequencyCap cap;

  /// Every interstitial request, for logs and tests.
  final List<String> log = [];

  @override
  bool get enabled => true;

  @override
  Widget? banner(AdPlacement placement) => _PlaceholderBanner(placement);

  @override
  Future<void> maybeShowInterstitial(BuildContext context, AdPlacement placement) async {
    final allowed = cap.canShow;
    log.add('${placement.id}:${allowed ? 'shown' : 'capped'}');
    debugPrint('[ads] interstitial ${placement.id} ${allowed ? 'shown' : 'capped'}');
    if (!allowed || !context.mounted) return;
    cap.recordShown();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('ad-interstitial'),
        title: const Text('Interstitial ad slot'),
        content: Text('Placement: ${placement.id}\n\nA full-screen ad would appear here.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }
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
      child: Text('Ad slot · ${placement.id} · 320×50',
          style: TextStyle(color: c.onSurfaceVariant, fontSize: 12, letterSpacing: 0.3)),
    );
  }
}

/// Reserves the banner area. Collapses to nothing when ads are off.
class AdBannerSlot extends StatelessWidget {
  const AdBannerSlot({super.key, required this.ads, required this.placement});
  final AdService ads;
  final AdPlacement placement;

  @override
  Widget build(BuildContext context) {
    final b = ads.banner(placement);
    if (b == null) return const SizedBox.shrink();
    return SizedBox(height: bannerHeight, width: double.infinity, child: b);
  }
}
