import 'package:beam/services/torch.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_torch.dart';

void main() {
  test('toggle, strength and patterns reach the platform', () async {
    final p = FakeTorchPlatform();
    final t = TorchController(p);
    await t.init();
    expect(t.strength, 3); // device default
    await t.toggle();
    await pumpEventQueue();
    expect(t.isOn, isTrue);
    expect(p.calls.last, 'setTorch(true,3)');

    await t.setStrength(9); // clamped to max
    expect(t.strength, 5);
    expect(p.calls.last, 'setStrength(5)');

    await t.play([100, 100]);
    await pumpEventQueue();
    expect(t.patternRunning, isTrue);
    // Tapping the power button during a signal gives a steady light.
    await t.toggle();
    await pumpEventQueue();
    expect(t.patternRunning, isFalse);
    expect(t.isOn, isTrue);

    await t.toggle();
    await pumpEventQueue();
    expect(t.isOn, isFalse);
  });

  test('without strength support no level is sent and slider is inert', () async {
    final p = FakeTorchPlatform(
      torchInfo: const TorchInfo(hasFlash: true, maxStrength: 1, defaultStrength: 1, sdkInt: 31),
    );
    final t = TorchController(p);
    await t.init(savedStrength: 4);
    expect(t.strength, 1);
    await t.setOn(true);
    expect(p.calls.last, 'setTorch(true,null)');
    await t.setStrength(3);
    expect(p.calls.where((c) => c.startsWith('setStrength')), isEmpty);
  });

  test('system toggles and errors are reflected', () async {
    final p = FakeTorchPlatform();
    final t = TorchController(p);
    await t.init();
    p.on = true;
    p.emitError('cameraInUse');
    await pumpEventQueue();
    expect(t.isOn, isTrue);
    expect(t.takeError(), TorchError.cameraInUse);
    expect(t.takeError(), isNull);
  });
}
