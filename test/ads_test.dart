import 'dart:io';

import 'package:beam/ads/ad_ids.dart';
import 'package:beam/ads/ads.dart';
import 'package:beam/services/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('frequency cap: launch grace, then minimum interval', () {
    var now = DateTime(2026, 1, 1, 12);
    final cap = FrequencyCap(
      minInterval: const Duration(seconds: 90),
      launchGrace: const Duration(seconds: 60),
      clock: () => now,
    );
    expect(cap.canShow, isFalse);
    now = now.add(const Duration(seconds: 61));
    expect(cap.canShow, isTrue);
    cap.recordShown();
    now = now.add(const Duration(seconds: 89));
    expect(cap.canShow, isFalse);
    now = now.add(const Duration(seconds: 1));
    expect(cap.canShow, isTrue);
  });

  test('placement ids are stable (ad network dashboards use them)', () {
    expect(AdPlacement.values.map((p) => p.id), [
      'home_banner',
      'screen_light_exit',
      'signal_stopped',
      'ad_free_reward',
    ]);
  });

  group('Ads policy', () {
    late Settings settings;
    var now = DateTime(2026, 10, 18, 12);
    var lightOn = false;

    Ads make(AdNetwork net) => Ads(
      network: net,
      settings: settings,
      isLightOn: () => lightOn,
      cap: FrequencyCap(launchGrace: Duration.zero, clock: () => now),
      clock: () => now,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = await Settings.load();
      now = DateTime(2026, 10, 18, 12);
      lightOn = false;
    });

    test('ads switched off: no banner, no offer, no init', () async {
      final ads = make(NoAdNetwork());
      expect(ads.banner(AdPlacement.homeBanner), isNull);
      expect(ads.canOfferAdFree, isFalse);
      await ads.init();
    });

    test('init reaches the network only once', () async {
      final net = PlaceholderAdNetwork();
      final ads = make(net);
      await ads.init();
      await ads.init();
      expect(net.initCount, 1);
    });

    testWidgets('no interstitial while a light is on', (tester) async {
      final ads = make(PlaceholderAdNetwork());
      lightOn = true;
      final ctx = await pumpContext(tester);
      expect(await ads.maybeShowInterstitial(ctx, AdPlacement.signalStopped), isFalse);
      expect(ads.log, ['signal_stopped:light-on']);
    });

    test('the ad-free pass expires after 24 hours', () {
      final ads = make(PlaceholderAdNetwork());
      settings.adFreeUntil = now.add(Ads.adFreeDuration);
      expect(ads.isAdFree, isTrue);
      expect(ads.banner(AdPlacement.homeBanner), isNull);
      expect(ads.canOfferAdFree, isFalse);
      now = now.add(const Duration(hours: 24, seconds: 1));
      expect(ads.isAdFree, isFalse);
      expect(ads.banner(AdPlacement.homeBanner), isNotNull);
      expect(ads.canOfferAdFree, isTrue);
    });

    testWidgets('no rewarded ad loaded: offer hidden and watching grants nothing', (tester) async {
      final ads = make(PlaceholderAdNetwork(rewardedLoaded: false));
      final ctx = await pumpContext(tester);
      expect(ads.canOfferAdFree, isFalse);
      expect(await ads.watchForAdFree(ctx), isA<NoFill>());
      expect(settings.adFreeUntil, isNull);
    });
  });

  test('release ad ids are checked by the release script', () {
    expect(AdUnitIds.sample.banner, startsWith('ca-app-pub-3940256099942544/'));
    expect(File('scripts/check-release-ad-ids.sh').existsSync(), isTrue);
  });
}

/// Pumps an empty app and returns a live BuildContext from inside it.
Future<BuildContext> pumpContext(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (c) {
          ctx = c;
          return const SizedBox();
        },
      ),
    ),
  );
  return ctx;
}
