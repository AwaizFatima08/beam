import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the phone's flash can do. Strength control needs Android 13+ and a
/// flash driver that reports more than one level.
class TorchInfo {
  const TorchInfo({
    required this.hasFlash,
    required this.maxStrength,
    required this.defaultStrength,
    required this.sdkInt,
  });

  final bool hasFlash;
  final int maxStrength;
  final int defaultStrength;
  final int sdkInt;

  bool get supportsStrength => maxStrength > 1;

  static const none = TorchInfo(hasFlash: false, maxStrength: 0, defaultStrength: 0, sdkInt: 0);
}

/// Error codes sent by the native engine.
enum TorchError { cameraInUse, unavailable, noFlash }

/// The platform side, split out so tests can swap in a fake.
abstract class TorchPlatform {
  Future<TorchInfo> info();
  Stream<Map<Object?, Object?>> events();
  Future<void> setTorch(bool on, {int? strength});
  Future<void> setStrength(int strength);
  Future<void> playPattern(List<int> durations, {required bool repeat, int? strength});
  Future<void> stopPattern();
}

class MethodChannelTorch implements TorchPlatform {
  static const _methods = MethodChannel('beam/torch');
  static const _events = EventChannel('beam/torch_events');

  @override
  Future<TorchInfo> info() async {
    final m = await _methods.invokeMapMethod<String, Object?>('info') ?? const {};
    return TorchInfo(
      hasFlash: m['hasFlash'] == true,
      maxStrength: (m['maxStrength'] as int?) ?? 0,
      defaultStrength: (m['defaultStrength'] as int?) ?? 0,
      sdkInt: (m['sdkInt'] as int?) ?? 0,
    );
  }

  @override
  Stream<Map<Object?, Object?>> events() =>
      _events.receiveBroadcastStream().map((e) => (e as Map<Object?, Object?>?) ?? const {});

  @override
  Future<void> setTorch(bool on, {int? strength}) =>
      _methods.invokeMethod('setTorch', {'on': on, 'strength': strength});

  @override
  Future<void> setStrength(int strength) => _methods.invokeMethod('setStrength', {'strength': strength});

  @override
  Future<void> playPattern(List<int> durations, {required bool repeat, int? strength}) =>
      _methods.invokeMethod('playPattern', {'durations': durations, 'repeat': repeat, 'strength': strength});

  @override
  Future<void> stopPattern() => _methods.invokeMethod('stopPattern');
}

/// App-wide torch state. The native side is the source of truth: the UI
/// follows its events, so the system quick-settings toggle stays in sync.
class TorchController extends ChangeNotifier {
  TorchController(this._platform);

  final TorchPlatform _platform;
  StreamSubscription<Map<Object?, Object?>>? _sub;

  TorchInfo info = TorchInfo.none;
  bool ready = false;
  bool isOn = false;
  bool patternRunning = false;
  int strength = 1;
  TorchError? lastError;

  Future<void> init({int? savedStrength}) async {
    try {
      info = await _platform.info();
    } on PlatformException {
      info = TorchInfo.none;
    } on MissingPluginException {
      info = TorchInfo.none;
    }
    strength = (savedStrength ?? info.defaultStrength).clamp(1, info.maxStrength < 1 ? 1 : info.maxStrength);
    _sub = _platform.events().listen(_onEvent, onError: (_) {});
    ready = true;
    notifyListeners();
  }

  void _onEvent(Map<Object?, Object?> e) {
    isOn = e['on'] == true;
    patternRunning = e['patternRunning'] == true;
    // Keep the user's chosen level while the light is off (the driver may report 0/default).
    final s = e['strength'];
    if (isOn && s is int && s >= 1 && info.supportsStrength) strength = s;
    final err = e['error'];
    if (err is String) {
      lastError = TorchError.values.where((v) => v.name == err).firstOrNull;
    }
    notifyListeners();
  }

  /// Consumes the latest error so it is only shown once.
  TorchError? takeError() {
    final e = lastError;
    lastError = null;
    return e;
  }

  Future<void> toggle() => setOn(!isOn || patternRunning);

  Future<void> setOn(bool on) async {
    // Optimistic update so the button responds instantly; the event confirms it.
    isOn = on;
    patternRunning = false;
    notifyListeners();
    await _platform.setTorch(on, strength: info.supportsStrength ? strength : null);
  }

  /// Slider moves call this often; the native side coalesces on its thread.
  Future<void> setStrength(int level) async {
    if (!info.supportsStrength) return;
    strength = level.clamp(1, info.maxStrength);
    notifyListeners();
    if (isOn && !patternRunning) await _platform.setStrength(strength);
  }

  Future<void> play(List<int> durations, {bool repeat = true}) async {
    if (durations.isEmpty) return;
    patternRunning = true;
    notifyListeners();
    await _platform.playPattern(durations, repeat: repeat, strength: info.supportsStrength ? strength : null);
  }

  Future<void> stopPattern() async {
    patternRunning = false;
    isOn = false;
    notifyListeners();
    await _platform.stopPattern();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
