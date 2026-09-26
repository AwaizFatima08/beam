import 'package:flutter/material.dart';

import '../app.dart';
import '../widgets/color_controls.dart';
import '../widgets/fullscreen_light.dart';

/// The screen itself is the lamp. Tap for controls, swipe vertically to
/// change brightness, back (or the close button) to leave.
class GlowPage extends StatefulWidget {
  const GlowPage({super.key, required this.services});
  final AppServices services;

  @override
  State<GlowPage> createState() => _GlowPageState();
}

class _GlowPageState extends State<GlowPage> {
  late final FullscreenLight _light = FullscreenLight(widget.services.screen);
  bool _controls = false;

  @override
  void initState() {
    super.initState();
    _light.enter(widget.services.settings.screenBrightness);
    widget.services.settings.addListener(_applyBrightness);
  }

  @override
  void dispose() {
    widget.services.settings.removeListener(_applyBrightness);
    _light.exit();
    super.dispose();
  }

  void _applyBrightness() => widget.services.screen.setBrightness(widget.services.settings.screenBrightness);

  void _drag(DragUpdateDetails d) {
    final h = MediaQuery.sizeOf(context).height;
    final s = widget.services.settings;
    s.screenBrightness = (s.screenBrightness - d.delta.dy / (h * 0.6)).clamp(0.05, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.services.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final color = settings.screenColor;
        final dark = color.computeLuminance() < 0.4;
        return Scaffold(
          backgroundColor: color,
          body: GestureDetector(
            key: const Key('glow'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _controls = !_controls),
            onVerticalDragUpdate: _drag,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: color)),
                if (_controls) ...[
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: IconButton.filled(
                          key: const Key('glow-close'),
                          style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close),
                          tooltip: 'Close',
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      child: Container(
                        key: const Key('glow-controls'),
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        decoration: BoxDecoration(
                          color: const Color(0xE6101216),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: ColorControls(settings: settings),
                      ),
                    ),
                  ),
                ] else
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Text(
                        'Tap for controls',
                        style: TextStyle(
                          color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.25),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
