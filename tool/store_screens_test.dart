// ignore_for_file: invalid_use_of_visible_for_testing_member
// Renders the real app UI in its key states for the Play screenshots.
//
//   flutter test tool/store_screens_test.dart && flutter test tool/make_graphics_test.dart
//
// Writes store-assets/raw/*.png (1080 px wide); make_graphics_test.dart then
// frames and captions them into store-assets/screenshots/.
// The torch shot uses a phone whose flash supports dimming (Android 13+).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:beam/ads/ads.dart';
import 'package:beam/app.dart';
import 'package:beam/services/screen.dart';
import 'package:beam/services/settings.dart';
import 'package:beam/services/torch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/fake_torch.dart';

const logical = Size(411, 890);
const ratio = 1080 / 411;
final boundary = GlobalKey();

Future<void> loadFonts() async {
  const dir = '/mnt/storage/projects/flutter/bin/cache/artifacts/material_fonts';
  ByteData read(String f) => ByteData.sublistView(File('$dir/$f').readAsBytesSync());
  final roboto = FontLoader('Roboto');
  for (final w in ['Regular', 'Medium', 'Bold', 'Black', 'Light']) {
    roboto.addFont(Future.value(read('Roboto-$w.ttf')));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(Future.value(read('MaterialIcons-Regular.otf')))).load();
}

Future<AppServices> pump(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  tester.view.physicalSize = logical * ratio;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'flashWarningAccepted': true, ...prefs});
  final torch = TorchController(FakeTorchPlatform());
  await torch.init();
  final services = AppServices(
    torch: torch,
    settings: await Settings.load(),
    ads: const NoAdService(),
    screen: const ScreenControl(),
  );
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: BeamApp(services: services),
    ),
  );
  await tester.pumpAndSettle();
  return services;
}

Future<void> shoot(WidgetTester tester, String name) async {
  final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final img = await ro.toImage(pixelRatio: ratio);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('store-assets/raw/$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(loadFonts);

  testWidgets('torch', (tester) async {
    final s = await pump(tester);
    await tester.tap(find.byKey(const Key('power')));
    await tester.pumpAndSettle();
    await s.torch.setStrength(4);
    await tester.pumpAndSettle();
    await shoot(tester, '01-torch');
  });

  testWidgets('strobe', (tester) async {
    await pump(tester, prefs: {'strobeHz': 8.0});
    await tester.tap(find.byKey(const Key('nav-signal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('signal-start')));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 45)); // lamp mid-flash
    await shoot(tester, '02-strobe');
    await tester.tap(find.byKey(const Key('signal-start')));
    await tester.pumpAndSettle();
  });

  testWidgets('morse', (tester) async {
    await pump(tester, prefs: {'morseText': 'HELP IS COMING'});
    await tester.tap(find.byKey(const Key('nav-signal')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morse'));
    await tester.pumpAndSettle();
    await shoot(tester, '03-sos');
  });

  testWidgets('screen', (tester) async {
    await pump(tester, prefs: {'screenColor': 0xFFFFD8A8, 'screenBrightness': 0.7});
    await tester.tap(find.byKey(const Key('nav-screen')));
    await tester.pumpAndSettle();
    await shoot(tester, '04-screen');
  });

  testWidgets('glow', (tester) async {
    await pump(tester, prefs: {'screenColor': 0xFFA64DFF});
    await tester.tap(find.byKey(const Key('nav-screen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('glow-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('glow')));
    await tester.pumpAndSettle();
    await shoot(tester, '05-glow');
    await tester.tap(find.byKey(const Key('glow-close')));
    await tester.pumpAndSettle();
  });
}
