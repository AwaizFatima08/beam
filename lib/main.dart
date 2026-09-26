import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  runApp(BeamApp(
    services: AppServices(torch: torch, settings: settings, ads: AdService.fromEnvironment(), screen: const ScreenControl()),
  ));
}
