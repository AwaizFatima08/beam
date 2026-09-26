import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/signals.dart';

/// Rebuilds with the pattern's on/off state every frame while [running].
/// Drives both the small preview lamp and the full-screen screen signal.
class PatternClock extends StatefulWidget {
  const PatternClock({
    super.key,
    required this.pattern,
    required this.running,
    required this.builder,
    this.repeat = true,
    this.onFinished,
  });

  final List<int> pattern;
  final bool running;
  final bool repeat;
  final Widget Function(BuildContext context, bool on) builder;
  final VoidCallback? onFinished;

  @override
  State<PatternClock> createState() => _PatternClockState();
}

class _PatternClockState extends State<PatternClock> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  bool _on = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _sync();
  }

  @override
  void didUpdateWidget(PatternClock old) {
    super.didUpdateWidget(old);
    // A new pattern or restart begins from its first flash.
    if (old.running != widget.running || !_sameList(old.pattern, widget.pattern)) {
      _ticker.stop();
      _sync();
    }
  }

  void _sync() {
    _finished = false;
    if (widget.running && widget.pattern.isNotEmpty) {
      _on = true;
      _ticker.start();
    } else {
      _on = false;
    }
  }

  void _tick(Duration elapsed) {
    final ms = elapsed.inMilliseconds;
    final on = patternIsOnAt(widget.pattern, ms, repeat: widget.repeat);
    if (on != _on) setState(() => _on = on);
    if (!widget.repeat && !_finished && ms >= patternLengthMs(widget.pattern)) {
      _finished = true;
      _ticker.stop();
      widget.onFinished?.call();
    }
  }

  static bool _sameList(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _on);
}
