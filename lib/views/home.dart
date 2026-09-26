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
          AdBannerSlot(ads: s.ads, placement: AdPlacement.homeBanner),
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
