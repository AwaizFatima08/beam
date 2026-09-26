import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything Beam remembers between launches. Stored on the device only;
/// there are no accounts and nothing leaves the phone.
class Settings extends ChangeNotifier {
  Settings(this._prefs);

  final SharedPreferences _prefs;

  static Future<Settings> load() async => Settings(await SharedPreferences.getInstance());

  int? get torchStrength => _prefs.getInt('torchStrength');
  set torchStrength(int? v) => v == null ? _prefs.remove('torchStrength') : _prefs.setInt('torchStrength', v);

  Color get screenColor => Color(_prefs.getInt('screenColor') ?? 0xFFFFFFFF);
  set screenColor(Color c) {
    _prefs.setInt('screenColor', c.toARGB32());
    notifyListeners();
  }

  double get screenBrightness => _prefs.getDouble('screenBrightness') ?? 1.0;
  set screenBrightness(double v) {
    _prefs.setDouble('screenBrightness', v);
    notifyListeners();
  }

  double get strobeHz => _prefs.getDouble('strobeHz') ?? 5;
  set strobeHz(double v) => _prefs.setDouble('strobeHz', v);

  int get morseWpm => _prefs.getInt('morseWpm') ?? 12;
  set morseWpm(int v) => _prefs.setInt('morseWpm', v);

  String get morseText => _prefs.getString('morseText') ?? 'HELLO';
  set morseText(String v) => _prefs.setString('morseText', v);

  /// Set once the user has acknowledged the flashing-light warning.
  bool get flashWarningAccepted => _prefs.getBool('flashWarningAccepted') ?? false;
  set flashWarningAccepted(bool v) => _prefs.setBool('flashWarningAccepted', v);
}
