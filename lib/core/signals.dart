/// Light patterns as millisecond durations, alternating on/off and starting
/// with "on". This is exactly what the native torch engine plays, and the
/// screen light plays the same lists, so both outputs behave identically.
library;

const Map<String, String> morseTable = {
  'A': '.-',
  'B': '-...',
  'C': '-.-.',
  'D': '-..',
  'E': '.',
  'F': '..-.',
  'G': '--.',
  'H': '....',
  'I': '..',
  'J': '.---',
  'K': '-.-',
  'L': '.-..',
  'M': '--',
  'N': '-.',
  'O': '---',
  'P': '.--.',
  'Q': '--.-',
  'R': '.-.',
  'S': '...',
  'T': '-',
  'U': '..-',
  'V': '...-',
  'W': '.--',
  'X': '-..-',
  'Y': '-.--',
  'Z': '--..',
  '0': '-----',
  '1': '.----',
  '2': '..---',
  '3': '...--',
  '4': '....-',
  '5': '.....',
  '6': '-....',
  '7': '--...',
  '8': '---..',
  '9': '----.',
  '.': '.-.-.-',
  ',': '--..--',
  '?': '..--..',
  '!': '-.-.--',
  '/': '-..-.',
  '-': '-....-',
  '@': '.--.-.',
  '(': '-.--.',
  ')': '-.--.-',
  ':': '---...',
  '=': '-...-',
  '+': '.-.-.',
  "'": '.----.',
  '"': '.-..-.',
  '&': '.-...',
};

/// Strobe limits. Above ~15 Hz most flash drivers cannot switch cleanly.
const double minStrobeHz = 1;
const double maxStrobeHz = 15;

/// PARIS standard: one "unit" (a dot) lasts 1200 / wpm milliseconds.
int morseUnitMs(int wpm) => (1200 / wpm.clamp(3, 40)).round();

/// Characters Beam cannot send; the UI shows them so nothing is silently dropped.
Set<String> unsupportedMorseChars(String text) => {
  for (final ch in text.toUpperCase().split(''))
    if (ch.trim().isNotEmpty && !morseTable.containsKey(ch)) ch,
};

/// Morse code for [text] as dots/dashes, letters separated by spaces and
/// words by " / ". Used for the on-screen readout.
String morseReadout(String text) {
  final words = text.toUpperCase().trim().split(RegExp(r'\s+'));
  return words
      .map((w) => w.split('').map((c) => morseTable[c]).whereType<String>().join(' '))
      .where((w) => w.isNotEmpty)
      .join(' / ');
}

/// Timing for [text]: dot 1 unit, dash 3, gap inside a letter 1, between
/// letters 3, between words 7. The list ends with a 7-unit gap so a repeating
/// message is clearly separated from its next pass.
List<int> morsePattern(String text, {int wpm = 12}) {
  final unit = morseUnitMs(wpm);
  final b = _PatternBuilder();
  final words = text.toUpperCase().trim().split(RegExp(r'\s+'));
  var firstWord = true;
  for (final word in words) {
    final letters = word.split('').map((c) => morseTable[c]).whereType<String>().toList();
    if (letters.isEmpty) continue;
    if (!firstWord) b.off(7 * unit);
    firstWord = false;
    for (var li = 0; li < letters.length; li++) {
      if (li > 0) b.off(3 * unit);
      final code = letters[li];
      for (var si = 0; si < code.length; si++) {
        if (si > 0) b.off(unit);
        b.on(code[si] == '.' ? unit : 3 * unit);
      }
    }
  }
  if (b.isEmpty) return const [];
  b.off(7 * unit);
  return b.build();
}

/// ··· ——— ··· with normal letter gaps, then a word gap before it repeats.
List<int> sosPattern({int wpm = 12}) => morsePattern('SOS', wpm: wpm);

/// Square-wave strobe. [duty] is the fraction of each cycle the light is on.
List<int> strobePattern(double hz, {double duty = 0.5}) {
  final period = 1000 / hz.clamp(minStrobeHz, maxStrobeHz);
  final on = (period * duty.clamp(0.1, 0.9)).round();
  final off = (period - on).round();
  return [on, off];
}

/// Total length of one pass of [pattern], in milliseconds.
int patternLengthMs(List<int> pattern) => pattern.fold(0, (a, b) => a + b);

class _PatternBuilder {
  final List<int> _out = [];
  bool get isEmpty => _out.isEmpty;

  void on(int ms) => _add(true, ms);
  void off(int ms) => _add(false, ms);

  void _add(bool isOn, int ms) {
    if (ms <= 0) return;
    // Index parity encodes state: even = on, odd = off.
    final lastIsOn = _out.length.isOdd;
    if (_out.isEmpty) {
      if (!isOn) return; // patterns start with light
      _out.add(ms);
    } else if (lastIsOn == isOn) {
      _out[_out.length - 1] += ms;
    } else {
      _out.add(ms);
    }
  }

  List<int> build() => List.unmodifiable(_out);
}

/// Whether the light is on [elapsedMs] into [pattern]. With [repeat] the
/// pattern loops; otherwise it is off once finished.
bool patternIsOnAt(List<int> pattern, int elapsedMs, {bool repeat = true}) {
  final total = patternLengthMs(pattern);
  if (total <= 0 || elapsedMs < 0) return false;
  if (!repeat && elapsedMs >= total) return false;
  var t = elapsedMs % total;
  for (var i = 0; i < pattern.length; i++) {
    if (t < pattern[i]) return i.isEven;
    t -= pattern[i];
  }
  return false;
}
