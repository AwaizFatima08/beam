import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ads/admob_network.dart';
import 'ads/ads.dart';
import 'app.dart';
import 'services/screen.dart';
import 'services/settings.dart';
import 'services/torch.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final settings = await Settings.load();
  final torch = TorchController(MethodChannelTorch());
  await torch.init(savedStrength: settings.torchStrength);
  final ads = Ads(network: _adNetwork(), settings: settings, isLightOn: () => torch.isOn || torch.patternRunning);
  runApp(
    BeamApp(
      services: AppServices(torch: torch, settings: settings, ads: ads, screen: const ScreenControl()),
    ),
  );
}

/// `--dart-define=BEAM_ADS=admob|placeholder|off` (default: admob). Debug and
/// profile builds use Google's sample units; see lib/ads/ad_ids.dart.
AdNetwork _adNetwork() => switch (const String.fromEnvironment('BEAM_ADS')) {
  'off' => NoAdNetwork(),
  'placeholder' => PlaceholderAdNetwork(),
  _ => AdMobNetwork(),
};
