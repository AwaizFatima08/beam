import 'package:flutter/material.dart';

import '../app.dart';

/// The big round torch switch. Its glow scales with [glow] (0..1) so the
/// intensity slider has visible feedback on the button too.
class PowerButton extends StatelessWidget {
  const PowerButton({
    super.key,
    required this.on,
    required this.onPressed,
    this.enabled = true,
    this.glow = 1,
    this.size = 200,
  });

  final bool on;
  final bool enabled;
  final double glow;
  final double size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final g = glow.clamp(0.15, 1.0);
    return Semantics(
      button: true,
      toggled: on,
      label: 'Torch',
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: on
                  ? [const Color(0xFFFFF1C9), beamAmber, const Color(0xFFE08A00)]
                  : [const Color(0xFF2A2F37), const Color(0xFF1A1D22), const Color(0xFF121418)],
              stops: const [0.0, 0.55, 1.0],
            ),
            boxShadow: on
                ? [
                    BoxShadow(
                      color: beamAmber.withValues(alpha: 0.55 * g),
                      blurRadius: 80 * g,
                      spreadRadius: 18 * g,
                    ),
                    BoxShadow(
                      color: beamAmber.withValues(alpha: 0.25 * g),
                      blurRadius: 160 * g,
                      spreadRadius: 40 * g,
                    ),
                  ]
                : const [BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 10))],
            border: Border.all(color: on ? const Color(0xFFFFE08A) : Colors.white12, width: 2),
          ),
          child: Icon(
            Icons.power_settings_new_rounded,
            size: size * 0.38,
            color: !enabled
                ? Colors.white24
                : on
                ? const Color(0xFF3A2500)
                : Colors.white70,
          ),
        ),
      ),
    );
  }
}
