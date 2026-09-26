import 'package:flutter/material.dart';

import '../app.dart';
import '../widgets/fullscreen_light.dart';
import '../widgets/pattern_lamp.dart';

/// Plays a signal pattern on the whole screen, for phones without a flash
/// or when a coloured signal is wanted. Tap anywhere to stop.
class ScreenSignalPage extends StatefulWidget {
  const ScreenSignalPage({
    super.key,
    required this.services,
    required this.pattern,
    required this.repeat,
    required this.title,
  });
  final AppServices services;
  final List<int> pattern;
  final bool repeat;
  final String title;

  @override
  State<ScreenSignalPage> createState() => _ScreenSignalPageState();
}

class _ScreenSignalPageState extends State<ScreenSignalPage> {
  late final FullscreenLight _light = FullscreenLight(widget.services.screen);

  @override
  void initState() {
    super.initState();
    _light.enter(1.0);
  }

  @override
  void dispose() {
    _light.exit();
    super.dispose();
  }

  void _close() {
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.services.settings.screenColor;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        key: const Key('screen-signal'),
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: PatternClock(
          pattern: widget.pattern,
          running: true,
          repeat: widget.repeat,
          onFinished: _close,
          builder: (context, on) => Container(
            key: Key(on ? 'screen-signal-on' : 'screen-signal-off'),
            color: on ? color : Colors.black,
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.only(bottom: 48),
            child: Text(
              '${widget.title}  ·  tap to stop',
              style: TextStyle(color: on ? Colors.black38 : beamAmber.withValues(alpha: 0.5), fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}
