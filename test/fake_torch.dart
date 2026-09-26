import 'dart:async';

import 'package:beam/services/torch.dart';

/// In-memory stand-in for the native torch, recording every call.
class FakeTorchPlatform implements TorchPlatform {
  FakeTorchPlatform({this.torchInfo = const TorchInfo(hasFlash: true, maxStrength: 5, defaultStrength: 3, sdkInt: 34)});

  final TorchInfo torchInfo;
  final calls = <String>[];
  final _events = StreamController<Map<Object?, Object?>>.broadcast();
  bool on = false;
  bool pattern = false;
  int strength = 1;
  List<int>? lastPattern;

  void _emit([Map<Object?, Object?> extra = const {}]) =>
      _events.add({'on': on, 'strength': strength, 'patternRunning': pattern, ...extra});

  void emitError(String code) => _emit({'error': code});

  @override
  Future<TorchInfo> info() async => torchInfo;

  @override
  Stream<Map<Object?, Object?>> events() => _events.stream;

  @override
  Future<void> setTorch(bool on, {int? strength}) async {
    calls.add('setTorch($on,$strength)');
    this.on = on;
    pattern = false;
    if (strength != null) this.strength = strength;
    _emit();
  }

  @override
  Future<void> setStrength(int strength) async {
    calls.add('setStrength($strength)');
    this.strength = strength;
    on = true;
    _emit();
  }

  @override
  Future<void> playPattern(List<int> durations, {required bool repeat, int? strength}) async {
    calls.add('playPattern(${durations.length},$repeat,$strength)');
    lastPattern = durations;
    pattern = true;
    _emit();
  }

  @override
  Future<void> stopPattern() async {
    calls.add('stopPattern');
    pattern = false;
    on = false;
    _emit();
  }
}
