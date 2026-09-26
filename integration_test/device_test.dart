// On-device tests against the real flash. Run on a phone:
//   flutter test integration_test/device_test.dart -d <device-id>
// The torch really turns on; each test leaves it off.
import 'package:beam/ads/ads.dart';
import 'package:beam/app.dart';
import 'package:beam/core/signals.dart';
import 'package:beam/services/screen.dart';
import 'package:beam/services/settings.dart';
import 'package:beam/services/torch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

late TorchController torch;

Future<AppServices> launch(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'flashWarningAccepted': true});
  torch = TorchController(MethodChannelTorch());
  await torch.init();
  final services = AppServices(
    torch: torch,
    settings: await Settings.load(),
    ads: PlaceholderAdService(cap: FrequencyCap(launchGrace: const Duration(hours: 1))),
    screen: const ScreenControl(),
  );
  await tester.pumpWidget(BeamApp(services: services));
  await tester.pumpAndSettle();
  return services;
}

/// Waits (real time) until [cond] holds, pumping frames meanwhile.
Future<void> waitFor(WidgetTester tester, bool Function() cond, {Duration timeout = const Duration(seconds: 8)}) async {
  final end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('timed out waiting for condition');
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await torch.setOn(false);
  });

  testWidgets('device reports a flash', (tester) async {
    await launch(tester);
    debugPrint(
      'torch info: hasFlash=${torch.info.hasFlash} maxStrength=${torch.info.maxStrength} sdk=${torch.info.sdkInt}',
    );
    expect(torch.info.hasFlash, isTrue);
    expect(torch.info.sdkInt, greaterThan(20));
  });

  testWidgets('power button turns the real torch on and off', (tester) async {
    await launch(tester);
    await tester.tap(find.byKey(const Key('power')));
    // Wait for the native TorchCallback to confirm, not just the optimistic update.
    await tester.pump(const Duration(milliseconds: 600));
    await waitFor(tester, () => torch.isOn);
    expect(find.text('ON'), findsOneWidget);
    await tester.tap(find.byKey(const Key('power')));
    await tester.pump(const Duration(milliseconds: 600));
    await waitFor(tester, () => !torch.isOn);
    expect(find.text('OFF'), findsOneWidget);
  });

  testWidgets('strobe runs until stopped, then the flash is off', (tester) async {
    await launch(tester);
    await tester.tap(find.byKey(const Key('nav-signal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('signal-start')));
    await tester.pump(const Duration(seconds: 2));
    expect(torch.patternRunning, isTrue);
    expect(find.text('FLASHING'), findsOneWidget);
    await tester.tap(find.byKey(const Key('signal-start')));
    await tester.pump(const Duration(milliseconds: 500));
    await waitFor(tester, () => !torch.patternRunning && !torch.isOn);
    expect(find.text('IDLE'), findsOneWidget);
  });

  testWidgets('maximum strobe speed keeps up', (tester) async {
    await launch(tester);
    await torch.play(strobePattern(maxStrobeHz));
    await tester.pump(const Duration(seconds: 3));
    expect(torch.patternRunning, isTrue);
    await torch.stopPattern();
    await tester.pump(const Duration(milliseconds: 300));
    await waitFor(tester, () => !torch.isOn);
  });

  testWidgets('one-shot SOS finishes on its own', (tester) async {
    await launch(tester);
    final sos = sosPattern(wpm: 20);
    final sw = Stopwatch()..start();
    await torch.play(sos, repeat: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(torch.patternRunning, isTrue);
    await waitFor(tester, () => !torch.patternRunning);
    debugPrint('SOS expected ${patternLengthMs(sos)} ms, took ${sw.elapsedMilliseconds} ms');
    expect(sw.elapsedMilliseconds, inInclusiveRange(patternLengthMs(sos) - 100, patternLengthMs(sos) + 800));
    expect(torch.isOn, isFalse);
  });

  testWidgets('power button during a signal switches to a steady light', (tester) async {
    await launch(tester);
    await torch.play(strobePattern(4));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('power')));
    await tester.pump(const Duration(milliseconds: 800));
    await waitFor(tester, () => torch.isOn && !torch.patternRunning);
    // Still steady a second later (no stray pattern step turned it off).
    await tester.pump(const Duration(seconds: 1));
    expect(torch.isOn, isTrue);
  });

  testWidgets('Morse message plays on the flash', (tester) async {
    await launch(tester);
    await tester.tap(find.byKey(const Key('nav-signal')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morse'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('morse-text')), 'HI');
    await tester.pumpAndSettle();
    expect(find.text('···· ··'), findsOneWidget);
    await tester.tap(find.byKey(const Key('signal-start')));
    await tester.pump(const Duration(seconds: 1));
    expect(torch.patternRunning, isTrue);
    await tester.tap(find.byKey(const Key('signal-start')));
    await tester.pump(const Duration(milliseconds: 500));
    await waitFor(tester, () => !torch.patternRunning);
  });

  testWidgets('screen glow and screen signal work on the device', (tester) async {
    final s = await launch(tester);
    await tester.tap(find.byKey(const Key('nav-screen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('swatch-green')));
    await tester.tap(find.byKey(const Key('glow-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('glow')), findsOneWidget);
    await tester.drag(find.byKey(const Key('glow')), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(s.settings.screenBrightness, lessThan(1));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('glow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('glow-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('glow')), findsNothing);

    await tester.tap(find.byKey(const Key('nav-signal')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(const Key('signal-output')), matching: find.text('Screen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('signal-start')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('screen-signal')), findsOneWidget);
    expect(torch.isOn, isFalse); // screen output never touches the flash
    await tester.tap(find.byKey(const Key('screen-signal')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('screen-signal')), findsNothing);
  });
}
