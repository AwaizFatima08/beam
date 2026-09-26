import 'package:flutter/material.dart';

import 'ads/ads.dart';
import 'services/screen.dart';
import 'services/settings.dart';
import 'services/torch.dart';
import 'views/home.dart';

/// The app's long-lived objects, created once in main() (or by a test).
class AppServices {
  AppServices({required this.torch, required this.settings, required this.ads, required this.screen});

  final TorchController torch;
  final Settings settings;
  final AdService ads;
  final ScreenControl screen;
}

const beamAmber = Color(0xFFFFC247);
const beamBackground = Color(0xFF0B0D10);

class BeamApp extends StatelessWidget {
  const BeamApp({super.key, required this.services});
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: beamAmber,
      brightness: Brightness.dark,
      surface: beamBackground,
    ).copyWith(primary: beamAmber, onPrimary: const Color(0xFF2A1C00));
    return MaterialApp(
      title: 'Beam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: beamBackground,
        useMaterial3: true,
        sliderTheme: const SliderThemeData(showValueIndicator: ShowValueIndicator.onDrag),
        cardTheme: CardThemeData(
          color: const Color(0xFF15181D),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: EdgeInsets.zero,
        ),
      ),
      home: HomeView(services: services),
    );
  }
}
