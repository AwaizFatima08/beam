import 'dart:io';

import 'package:beam/ads/ads.dart';
import 'package:beam/app.dart';
import 'package:beam/services/screen.dart';
import 'package:beam/services/settings.dart';
import 'package:beam/services/torch.dart';
import 'package:beam/views/about_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_torch.dart';

Future<(FakeTorchPlatform, AppServices)> pumpBeam(
  WidgetTester tester, {
  TorchInfo info = const TorchInfo(hasFlash: true, maxStrength: 5, defaultStrength: 3, sdkInt: 34),
  AdNetwork? network,
  FrequencyCap? cap,
  DateTime Function()? clock,
  Map<String, Object> prefs = const {},
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues(prefs);
  final platform = FakeTorchPlatform(torchInfo: info);
  final torch = TorchController(platform);
  await torch.init();
  final settings = await Settings.load();
  final services = AppServices(
    torch: torch,
    settings: settings,
    ads: Ads(
      network: network ?? NoAdNetwork(),
      settings: settings,
      isLightOn: () => torch.isOn || torch.patternRunning,
      cap: cap,
      clock: clock,
    ),
    screen: const ScreenControl(),
  );
  await tester.pumpWidget(BeamApp(services: services));
  await tester.pumpAndSettle();
  return (platform, services);
}

void main() {
  testWidgets('power button toggles the torch', (tester) async {
    final (p, _) = await pumpBeam(tester);
    expect(find.text('OFF'), findsOneWidget);
    await tester.tap(find.byKey(const Key('power')));
    await tester.pumpAndSettle();
    expect(find.text('ON'), findsOneWidget);
    expect(p.on, isTrue);
    await tester.tap(find.byKey(const Key('power')));
    await tester.pumpAndSettle();
    expect(p.on, isFalse);
  });

  testWidgets('intensity slider sets strength on supported phones', (tester) async {
    final (p, s) = await pumpBeam(tester);
    await tester.tap(find.byKey(const Key('power')));
    await tester.pumpAndSettle();
    expect(find.text('60%'), findsOneWidget);
    final slider = find.byKey(const Key('intensity-slider'));
    await tester.drag(slider, const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    expect(p.strength, 5);
    expect(s.settings.torchStrength, 5);
  });

  testWidgets('unsupported intensity is explained, not hidden', (tester) async {
    await pumpBeam(tester, info: const TorchInfo(hasFlash: true, maxStrength: 1, defaultStrength: 1, sdkInt: 31));
    expect(find.byKey(const Key('intensity-unsupported')), findsOneWidget);
    expect(find.text('Fixed'), findsOneWidget);
  });

  testWidgets('no flash: power disabled, signals fall back to screen', (tester) async {
    final (p, _) = await pumpBeam(tester, info: TorchInfo.none);
    expect(find.text('NO FLASH'), findsOneWidget);
    await tester.tap(find.byKey(const Key('power')));
    await tester.pumpAndSettle();
    expect(p.calls, isEmpty);
    await tester.tap(find.byKey(const Key('nav-signal')));
    await tester.pumpAndSettle();
    final output = tester.widget<SegmentedButton<Object>>(find.byKey(const Key('signal-output')));
    expect(output.selected.single.toString(), 'SignalOutput.screen');
  });

  testWidgets('strobe: warning once, start, stop', (tester) async {
    final (p, s) = await pumpBeam(tester);
    await tester.tap(find.byKey(const Key('nav-signal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('signal-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flash-warning')), findsOneWidget);
    await tester.tap(find.byKey(const Key('flash-warning-ok')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(p.lastPattern, [100, 100]); // default 5 Hz
    expect(find.text('FLASHING'), findsOneWidget);
    expect(s.settings.flashWarningAccepted, isTrue);
    await tester.tap(find.byKey(const Key('signal-start')));
    await tester.pumpAndSettle();
    expect(p.pattern, isFalse);
    expect(find.text('IDLE'), findsOneWidget);
  });

  testWidgets('SOS and Morse build the right patterns', (tester) async {
    final (p, _) = await pumpBeam(tester, prefs: {'flashWarningAccepted': true});
    await tester.tap(find.byKey(const Key('nav-signal')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SOS'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sos-readout')), findsOneWidget);
    await tester.tap(find.byKey(const Key('signal-start')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(p.lastPattern!.length, 18);
    await tester.tap(find.byKey(const Key('signal-start')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Morse'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('morse-text')), 'E #');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('morse-unsupported')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('signal-start')));
    await tester.tap(find.byKey(const Key('signal-start')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(p.lastPattern, [100, 700]);
    expect(p.calls.last, 'playPattern(2,true,3)');
    await tester.tap(find.byKey(const Key('signal-start')));
    await tester.pumpAndSettle();
  });

  testWidgets('screen light: preset, glow page, controls, close', (tester) async {
    final (_, s) = await pumpBeam(tester);
    await tester.tap(find.byKey(const Key('nav-screen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('swatch-red')));
    await tester.pumpAndSettle();
    expect(s.settings.screenColor, const Color(0xFFFF2A2A));
    expect(find.text('#FF2A2A'), findsOneWidget);

    await tester.tap(find.byKey(const Key('glow-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('glow')), findsOneWidget);
    expect(
      tester
          .widget<Scaffold>(find.ancestor(of: find.byKey(const Key('glow')), matching: find.byType(Scaffold)).first)
          .backgroundColor,
      const Color(0xFFFF2A2A),
    );

    // Swipe up brightens, swipe down dims.
    s.settings.screenBrightness = 0.5;
    await tester.drag(find.byKey(const Key('glow')), const Offset(0, 200));
    expect(s.settings.screenBrightness, lessThan(0.5));

    await tester.tap(find.byKey(const Key('glow')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('glow-controls')), findsOneWidget);
    await tester.tap(find.byKey(const Key('swatch-blue')));
    await tester.pumpAndSettle();
    expect(s.settings.screenColor, const Color(0xFF3D6BFF));
    await tester.tap(find.byKey(const Key('glow-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('glow')), findsNothing);
  });

  testWidgets('screen signal output plays full screen and stops on tap', (tester) async {
    await pumpBeam(tester, prefs: {'flashWarningAccepted': true});
    await tester.tap(find.byKey(const Key('nav-signal')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(const Key('signal-output')), matching: find.text('Screen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('signal-start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('screen-signal-on')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100)); // 5 Hz: dark half
    expect(find.byKey(const Key('screen-signal-off')), findsOneWidget);
    await tester.tap(find.byKey(const Key('screen-signal')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('screen-signal')), findsNothing);
  });

  FrequencyCap noGrace() => FrequencyCap(launchGrace: Duration.zero);

  testWidgets('ads start once after the first frame', (tester) async {
    final net = PlaceholderAdNetwork();
    await pumpBeam(tester, network: net);
    expect(net.initCount, 1);
  });

  testWidgets('banner and offer never on the Torch tab; shown on Signal and Screen', (tester) async {
    await pumpBeam(tester, network: PlaceholderAdNetwork());
    expect(find.byKey(const Key('ad-banner-home_banner')), findsNothing);
    expect(find.byKey(const Key('ad-free-offer')), findsNothing);
    for (final tab in ['nav-signal', 'nav-screen']) {
      await tester.tap(find.byKey(Key(tab)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ad-banner-home_banner')), findsOneWidget, reason: tab);
      expect(find.byKey(const Key('ad-free-offer')), findsOneWidget, reason: tab);
    }
    await tester.tap(find.byKey(const Key('nav-torch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ad-banner-home_banner')), findsNothing);
  });

  testWidgets('banner is removed while the glow covers the screen', (tester) async {
    await pumpBeam(tester, network: PlaceholderAdNetwork(), cap: noGrace());
    await tester.tap(find.byKey(const Key('nav-screen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('glow-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ad-banner-home_banner')), findsNothing);
  });

  testWidgets('no offer while no rewarded ad is loaded', (tester) async {
    await pumpBeam(tester, network: PlaceholderAdNetwork(rewardedLoaded: false));
    await tester.tap(find.byKey(const Key('nav-signal')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ad-free-offer')), findsNothing);
    expect(find.byKey(const Key('ad-banner-home_banner')), findsOneWidget);
  });

  testWidgets('interstitial after the glow, then capped', (tester) async {
    final (_, s) = await pumpBeam(tester, network: PlaceholderAdNetwork(), cap: noGrace());
    await tester.tap(find.byKey(const Key('nav-screen')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const Key('glow-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('glow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('glow-close')));
      await tester.pumpAndSettle();
      if (i == 0) {
        expect(find.byKey(const Key('ad-interstitial')), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
      }
    }
    expect(s.ads.log, ['screen_light_exit:shown', 'screen_light_exit:capped']);
    expect(find.byKey(const Key('ad-interstitial')), findsNothing);
  });

  testWidgets('watching the rewarded ad to the end removes ads for 24 hours', (tester) async {
    final now = DateTime(2026, 10, 18, 9, 30);
    final (_, s) = await pumpBeam(tester, network: PlaceholderAdNetwork(), cap: noGrace(), clock: () => now);
    await tester.tap(find.byKey(const Key('nav-signal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ad-free-offer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ad-rewarded-finish')));
    await tester.pumpAndSettle();
    expect(s.settings.adFreeUntil, now.add(const Duration(hours: 24)));
    expect(find.textContaining('No ads until'), findsOneWidget);
    expect(find.byKey(const Key('ad-banner-home_banner')), findsNothing);
    expect(find.byKey(const Key('ad-free-offer')), findsNothing);
    // Interstitials are off too (wait for the snackbar to clear the button).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('signal-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flash-warning-ok')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('signal-start')));
    await tester.pumpAndSettle();
    expect(s.ads.log.last, 'signal_stopped:ad-free');
    expect(find.byKey(const Key('ad-interstitial')), findsNothing);
  });

  testWidgets('closing the rewarded ad early grants nothing', (tester) async {
    final (_, s) = await pumpBeam(tester, network: PlaceholderAdNetwork());
    await tester.tap(find.byKey(const Key('nav-screen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ad-free-offer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ad-rewarded-close')));
    await tester.pumpAndSettle();
    expect(s.settings.adFreeUntil, isNull);
    expect(find.textContaining('closed early'), findsOneWidget);
    expect(find.byKey(const Key('ad-banner-home_banner')), findsOneWidget);
  });

  testWidgets('about sheet: ads wording and ad-free status', (tester) async {
    final now = DateTime(2026, 10, 18, 9, 30);
    await pumpBeam(
      tester,
      network: PlaceholderAdNetwork(),
      clock: () => now,
      prefs: {'adFreeUntil': now.add(const Duration(hours: 5)).millisecondsSinceEpoch},
    );
    await tester.tap(find.byKey(const Key('about')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Google AdMob'), findsOneWidget);
    expect(find.byKey(const Key('about-ad-free')), findsOneWidget);
    expect(find.text('Until 14:30'), findsOneWidget);
  });

  testWidgets('about sheet shows version and privacy/terms links', (tester) async {
    await pumpBeam(tester);
    await tester.tap(find.byKey(const Key('about')));
    await tester.pumpAndSettle();
    expect(find.text('Version $appVersion · by HomiLabs'), findsOneWidget);
    expect(find.byKey(const Key('about-privacy')), findsOneWidget);
    expect(find.byKey(const Key('about-terms')), findsOneWidget);
    expect(find.byKey(const Key('about-community')), findsOneWidget);
  });

  test('appVersion matches pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final v = RegExp(r'^version: (\S+)\+', multiLine: true).firstMatch(pubspec)!.group(1);
    expect(appVersion, v);
    expect(privacyUrl, startsWith('https://tools.homilabs.org/'));
  });
}
