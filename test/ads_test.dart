import 'package:beam/ads/ads.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(AdPlacement.values.map((p) => p.id), ['home_banner', 'screen_light_exit', 'signal_stopped']);
  });

  test('no-ads service shows nothing', () {
    const ads = NoAdService();
    expect(ads.enabled, isFalse);
    expect(ads.banner(AdPlacement.homeBanner), isNull);
  });
}
