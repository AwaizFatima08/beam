import 'package:flutter/material.dart';

import '../ads/ads.dart';
import '../app.dart';
import '../widgets/color_controls.dart';
import 'glow_page.dart';
import 'home.dart';

class ScreenTab extends StatelessWidget {
  const ScreenTab({super.key, required this.services});
  final AppServices services;

  Future<void> _glow(BuildContext context) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, _, _) => GlowPage(services: services),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
    if (context.mounted) await services.ads.maybeShowInterstitial(context, AdPlacement.screenLightExit);
  }

  @override
  Widget build(BuildContext context) {
    final settings = services.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final color = settings.screenColor;
        final list = ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            const TabHeader(title: 'Screen light', subtitle: 'Use the screen as a coloured lamp'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: GestureDetector(
                key: const Key('screen-preview'),
                onTap: () => _glow(context),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 110,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: 2)],
                  ),
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                    key: const Key('screen-hex'),
                    style: TextStyle(
                      color: color.computeLuminance() > 0.5 ? Colors.black54 : Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: ColorControls(settings: settings),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: Text(
                'Tap the glowing screen for controls. Swipe up or down to change brightness.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          ],
        );
        return Column(
          children: [
            Expanded(child: list),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('glow-start'),
                  style: FilledButton.styleFrom(
                    textStyle: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => _glow(context),
                  icon: const Icon(Icons.light_mode_rounded),
                  label: const Text('Glow'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
