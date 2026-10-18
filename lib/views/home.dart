import 'package:flutter/material.dart';

import '../ads/ads.dart';
import '../app.dart';
import '../services/torch.dart';
import 'screen_tab.dart';
import 'signal_tab.dart';
import 'torch_tab.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key, required this.services});
  final AppServices services;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _tab = 0;

  TorchController get _torch => widget.services.torch;

  @override
  void initState() {
    super.initState();
    _torch.addListener(_onTorch);
    // Consent and ad loading start after the first frame, so the torch is
    // usable immediately and the consent form (EEA/UK) has an activity.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.services.ads.init());
  }

  @override
  void dispose() {
    _torch.removeListener(_onTorch);
    super.dispose();
  }

  void _onTorch() {
    final err = _torch.takeError();
    if (err == null || !mounted) return;
    final msg = switch (err) {
      TorchError.cameraInUse => 'The flash is busy. Close the camera or other torch apps and try again.',
      TorchError.unavailable => 'The flash is being used by another app.',
      TorchError.noFlash => 'This phone has no usable flash. Try the screen light instead.',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _goTo(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final s = widget.services;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            TorchTab(services: s, onOpenScreenLight: () => _goTo(2)),
            SignalTab(services: s),
            ScreenTab(services: s),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // No ads on the Torch tab, and none while a glow, signal or dialog
          // covers this screen (the banner is disposed, so it never refreshes
          // unseen).
          if (_tab != 0 && (ModalRoute.of(context)?.isCurrent ?? true)) ...[
            AdFreeOffer(ads: s.ads),
            AdBannerSlot(ads: s.ads, placement: AdPlacement.homeBanner),
          ],
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: _goTo,
            backgroundColor: const Color(0xFF111418),
            destinations: const [
              NavigationDestination(
                key: Key('nav-torch'),
                icon: Icon(Icons.flashlight_on_outlined),
                selectedIcon: Icon(Icons.flashlight_on),
                label: 'Torch',
              ),
              NavigationDestination(
                key: Key('nav-signal'),
                icon: Icon(Icons.flare_outlined),
                selectedIcon: Icon(Icons.flare),
                label: 'Signal',
              ),
              NavigationDestination(
                key: Key('nav-screen'),
                icon: Icon(Icons.palette_outlined),
                selectedIcon: Icon(Icons.palette),
                label: 'Screen',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shared page header used by every tab.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, required this.subtitle, this.trailing});
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: t.bodyMedium?.copyWith(color: Colors.white60)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Status pill: amber when something is lit.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.active});
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? beamAmber.withValues(alpha: 0.18) : Colors.white10,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? beamAmber : Colors.white60,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// "No ads for 24 hours" — shown only while a rewarded ad is actually loaded
/// and the user isn't already ad-free, so it can never dead-end.
class AdFreeOffer extends StatelessWidget {
  const AdFreeOffer({super.key, required this.ads});
  final Ads ads;

  Future<void> _watch(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ads.watchForAdFree(context);
    final msg = switch (outcome) {
      Rewarded() => 'Thanks! No ads until ${formatAdFreeUntil(ads.adFreeUntil)}.',
      Dismissed() => 'The ad was closed early, so no reward this time.',
      NoFill() => 'No ad is available right now. Please try again later.',
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ads,
      builder: (context, _) {
        if (!ads.canOfferAdFree) return const SizedBox.shrink();
        return Material(
          color: const Color(0xFF15181D),
          child: InkWell(
            key: const Key('ad-free-offer'),
            onTap: () => _watch(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.block, size: 18, color: beamAmber),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('No ads for 24 hours', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text(
                    'Watch a short ad',
                    style: TextStyle(color: beamAmber, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "14:05" today, "tomorrow 14:05" otherwise.
String formatAdFreeUntil(DateTime? until, {DateTime? now}) {
  if (until == null) return '';
  final n = now ?? DateTime.now();
  final hm = '${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}';
  final sameDay = until.year == n.year && until.month == n.month && until.day == n.day;
  return sameDay ? hm : 'tomorrow $hm';
}
