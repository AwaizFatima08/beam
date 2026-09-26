import 'package:beam/core/signals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('morse', () {
    test('unit length follows PARIS timing', () {
      expect(morseUnitMs(12), 100);
      expect(morseUnitMs(20), 60);
      expect(morseUnitMs(1), 400); // clamped to 3 wpm
    });

    test('SOS timing: dots, dashes, letter gaps and trailing word gap', () {
      // S = . . .   O = - - -   S = . . .
      expect(sosPattern(wpm: 12), [
        100, 100, 100, 100, 100, 300, // S + letter gap
        300, 100, 300, 100, 300, 300, // O + letter gap
        100, 100, 100, 100, 100, 700, // S + word gap before repeat
      ]);
    });

    test('word gap is seven units and letters merge correctly', () {
      // E E = . (word gap) .
      expect(morsePattern('E E', wpm: 12), [100, 700, 100, 700]);
    });

    test('unknown characters are skipped and reported', () {
      expect(morsePattern('E#', wpm: 12), morsePattern('E', wpm: 12));
      expect(unsupportedMorseChars('hi #1 ~'), {'#', '~'});
      expect(morsePattern('###'), isEmpty);
      expect(morsePattern('   '), isEmpty);
    });

    test('readout', () {
      expect(morseReadout('sos'), '... --- ...');
      expect(morseReadout('hi there'), '.... .. / - .... . .-. .');
    });

    test('patterns always alternate starting with light, all positive', () {
      for (final text in ['A', 'HELLO WORLD', 'SOS 123?', 'Q']) {
        final p = morsePattern(text);
        expect(p.length.isEven, isTrue, reason: text);
        expect(p.every((d) => d > 0), isTrue, reason: text);
      }
    });
  });

  group('strobe', () {
    test('period and duty', () {
      expect(strobePattern(5), [100, 100]);
      expect(strobePattern(10, duty: 0.3), [30, 70]);
      expect(patternLengthMs(strobePattern(2)), 500);
    });

    test('frequency is clamped', () {
      expect(patternLengthMs(strobePattern(100)), closeTo(1000 / maxStrobeHz, 1));
      expect(patternLengthMs(strobePattern(0)), 1000);
    });
  });

  group('patternIsOnAt', () {
    final p = [100, 200];
    test('within first cycle', () {
      expect(patternIsOnAt(p, 0), isTrue);
      expect(patternIsOnAt(p, 99), isTrue);
      expect(patternIsOnAt(p, 100), isFalse);
      expect(patternIsOnAt(p, 299), isFalse);
    });
    test('repeats', () {
      expect(patternIsOnAt(p, 300), isTrue);
      expect(patternIsOnAt(p, 750), isFalse);
    });
    test('one-shot ends dark', () {
      expect(patternIsOnAt(p, 300, repeat: false), isFalse);
      expect(patternIsOnAt(const [], 10), isFalse);
    });
  });
}
