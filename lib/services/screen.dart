import 'package:flutter/services.dart';

/// Window brightness and keep-awake for the screen light. Brightness is a
/// per-window override, so leaving Beam restores the user's own setting.
class ScreenControl {
  const ScreenControl();

  static const _channel = MethodChannel('beam/screen');

  /// [value] 0..1 overrides brightness; null hands it back to the system.
  Future<void> setBrightness(double? value) => _safe('setBrightness', {'value': value ?? -1.0});

  Future<void> keepOn(bool on) => _safe('keepOn', {'on': on});

  Future<void> _safe(String method, Map<String, Object?> args) async {
    try {
      await _channel.invokeMethod(method, args);
    } on MissingPluginException {
      // Widget tests have no platform side.
    }
  }
}
