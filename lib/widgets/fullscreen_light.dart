import 'package:flutter/services.dart';

import '../services/screen.dart';

/// Enters and leaves "the screen is the lamp" mode: no system bars, screen
/// kept awake, brightness overridden for this window only.
class FullscreenLight {
  const FullscreenLight(this.screen);
  final ScreenControl screen;

  Future<void> enter(double brightness) async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await screen.keepOn(true);
    await screen.setBrightness(brightness);
  }

  Future<void> exit() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await screen.keepOn(false);
    await screen.setBrightness(null);
  }
}
