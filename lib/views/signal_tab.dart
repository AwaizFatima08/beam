import 'package:flutter/material.dart';

import '../ads/ads.dart';
import '../app.dart';
import '../core/signals.dart';
import '../widgets/pattern_lamp.dart';
import 'home.dart';
import 'screen_signal_page.dart';

enum SignalMode { strobe, sos, morse }

enum SignalOutput { flash, screen }

class SignalTab extends StatefulWidget {
  const SignalTab({super.key, required this.services});
  final AppServices services;

  @override
  State<SignalTab> createState() => _SignalTabState();
}

class _SignalTabState extends State<SignalTab> {
  SignalMode _mode = SignalMode.strobe;
  SignalOutput _output = SignalOutput.flash;
  bool _repeat = true;
  late double _hz = widget.services.settings.strobeHz;
  late int _wpm = widget.services.settings.morseWpm;
  late final TextEditingController _text = TextEditingController(text: widget.services.settings.morseText);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _hasFlash => widget.services.torch.info.hasFlash;
  SignalOutput get _effectiveOutput => _hasFlash ? _output : SignalOutput.screen;
  bool get _repeats => _mode == SignalMode.strobe || _repeat;

  List<int> get _pattern => switch (_mode) {
    SignalMode.strobe => strobePattern(_hz),
    SignalMode.sos => sosPattern(wpm: _wpm),
    SignalMode.morse => morsePattern(_text.text, wpm: _wpm),
  };

  bool get _flashRunning => widget.services.torch.patternRunning;

  Future<bool> _confirmFlashWarning() async {
    final settings = widget.services.settings;
    if (settings.flashWarningAccepted) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('flash-warning'),
        icon: const Icon(Icons.warning_amber_rounded, color: beamAmber),
        title: const Text('Flashing lights'),
        content: const Text(
          'Signals flash light rapidly. Flashing light can trigger seizures in people with '
          'photosensitive epilepsy. Do not point the light at anyone\'s eyes, and stop '
          'straight away if you feel unwell.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('flash-warning-ok'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('I understand'),
          ),
        ],
      ),
    );
    if (ok == true) settings.flashWarningAccepted = true;
    return ok == true;
  }

  Future<void> _start() async {
    final pattern = _pattern;
    if (pattern.isEmpty) return;
    if (!await _confirmFlashWarning() || !mounted) return;
    FocusScope.of(context).unfocus();
    if (_effectiveOutput == SignalOutput.flash) {
      await widget.services.torch.play(pattern, repeat: _repeats);
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) =>
              ScreenSignalPage(services: widget.services, pattern: pattern, repeat: _repeats, title: _title),
        ),
      );
      if (mounted) await widget.services.ads.maybeShowInterstitial(context, AdPlacement.signalStopped);
    }
  }

  Future<void> _stop() async {
    await widget.services.torch.stopPattern();
    if (mounted) await widget.services.ads.maybeShowInterstitial(context, AdPlacement.signalStopped);
  }

  /// Applies a changed setting to a signal that is already flashing.
  void _restartIfRunning() {
    if (_flashRunning && _effectiveOutput == SignalOutput.flash) {
      widget.services.torch.play(_pattern, repeat: _repeats);
    }
  }

  String get _title => switch (_mode) {
    SignalMode.strobe => 'Strobe ${_hz.toStringAsFixed(1)} Hz',
    SignalMode.sos => 'SOS',
    SignalMode.morse => _text.text.trim().toUpperCase(),
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.services.torch,
      builder: (context, _) {
        final running = _flashRunning;
        final pattern = _pattern;
        final list = ListView(
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            TabHeader(
              title: 'Signal',
              subtitle: 'Strobe · SOS · Morse',
              trailing: StatusPill(
                key: const Key('signal-status'),
                label: running ? 'FLASHING' : 'IDLE',
                active: running,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<SignalMode>(
                key: const Key('signal-mode'),
                segments: const [
                  ButtonSegment(value: SignalMode.strobe, label: Text('Strobe'), icon: Icon(Icons.flash_on)),
                  ButtonSegment(value: SignalMode.sos, label: Text('SOS'), icon: Icon(Icons.sos)),
                  ButtonSegment(value: SignalMode.morse, label: Text('Morse'), icon: Icon(Icons.more_horiz)),
                ],
                selected: {_mode},
                onSelectionChanged: (s) {
                  setState(() => _mode = s.first);
                  _restartIfRunning();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: switch (_mode) {
                    SignalMode.strobe => _strobeControls(),
                    SignalMode.sos => _sosControls(),
                    SignalMode.morse => _morseControls(),
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Row(
                    children: [
                      const Text('Output', style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      SegmentedButton<SignalOutput>(
                        key: const Key('signal-output'),
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(value: SignalOutput.flash, label: const Text('Flash'), enabled: _hasFlash),
                          const ButtonSegment(value: SignalOutput.screen, label: Text('Screen')),
                        ],
                        selected: {_effectiveOutput},
                        onSelectionChanged: (s) {
                          // Switching output mid-signal stops the flash rather than leaving it running.
                          if (running) widget.services.torch.stopPattern();
                          setState(() => _output = s.first);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
        // The start button and lamp stay pinned so they are reachable
        // without scrolling on small or large-font screens.
        final bar = Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              PatternClock(
                pattern: pattern,
                running: running,
                repeat: _repeats,
                builder: (context, on) => AnimatedContainer(
                  key: const Key('signal-lamp'),
                  duration: const Duration(milliseconds: 40),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? beamAmber : const Color(0xFF22262C),
                    boxShadow: on
                        ? [BoxShadow(color: beamAmber.withValues(alpha: 0.6), blurRadius: 24, spreadRadius: 4)]
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    key: const Key('signal-start'),
                    style: FilledButton.styleFrom(
                      backgroundColor: running ? const Color(0xFFE5484D) : beamAmber,
                      foregroundColor: running ? Colors.white : const Color(0xFF2A1C00),
                      textStyle: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    onPressed: pattern.isEmpty ? null : (running ? _stop : _start),
                    icon: Icon(running ? Icons.stop_rounded : Icons.play_arrow_rounded),
                    label: Text(running ? 'Stop' : 'Start'),
                  ),
                ),
              ),
            ],
          ),
        );
        return Column(
          children: [
            Expanded(child: list),
            bar,
          ],
        );
      },
    );
  }

  Widget _strobeControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Text('Speed', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const Spacer(),
          Text('${_hz.toStringAsFixed(1)} flashes/s', key: const Key('strobe-hz')),
        ],
      ),
      Slider(
        key: const Key('strobe-slider'),
        value: _hz,
        min: minStrobeHz,
        max: maxStrobeHz,
        divisions: ((maxStrobeHz - minStrobeHz) * 2).round(),
        label: '${_hz.toStringAsFixed(1)} Hz',
        onChanged: (v) => setState(() => _hz = v),
        onChangeEnd: (v) {
          widget.services.settings.strobeHz = v;
          _restartIfRunning();
        },
      ),
      const Text(
        'Slow flashes are easier to see from far away; fast ones catch attention.',
        style: TextStyle(color: Colors.white54, fontSize: 13),
      ),
    ],
  );

  Widget _sosControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('International distress signal', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      const SizedBox(height: 10),
      Text(
        morseReadout('SOS').replaceAll('.', '•').replaceAll('-', '—'),
        key: const Key('sos-readout'),
        style: const TextStyle(fontSize: 22, letterSpacing: 4, color: beamAmber),
      ),
      const SizedBox(height: 6),
      _speedSlider(),
      _repeatSwitch(),
    ],
  );

  Widget _morseControls() {
    final bad = unsupportedMorseChars(_text.text);
    final readout = morseReadout(_text.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('morse-text'),
          controller: _text,
          maxLength: 60,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
          onChanged: (v) {
            widget.services.settings.morseText = v;
            setState(() {});
          },
          onSubmitted: (_) => _restartIfRunning(),
        ),
        if (readout.isNotEmpty)
          Text(
            readout.replaceAll('.', '·').replaceAll('-', '–'),
            key: const Key('morse-readout'),
            style: const TextStyle(color: beamAmber, fontSize: 16, letterSpacing: 1.5),
          ),
        if (bad.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Skipped (no Morse code): ${bad.join(' ')}',
              key: const Key('morse-unsupported'),
              style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 13),
            ),
          ),
        const SizedBox(height: 8),
        _speedSlider(),
        _repeatSwitch(),
      ],
    );
  }

  Widget _speedSlider() => Row(
    children: [
      const Text('Speed'),
      Expanded(
        child: Slider(
          key: const Key('morse-wpm'),
          value: _wpm.toDouble(),
          min: 5,
          max: 25,
          divisions: 20,
          label: '$_wpm wpm',
          onChanged: (v) => setState(() => _wpm = v.round()),
          onChangeEnd: (v) {
            widget.services.settings.morseWpm = v.round();
            _restartIfRunning();
          },
        ),
      ),
      Text('$_wpm wpm'),
    ],
  );

  Widget _repeatSwitch() => SwitchListTile(
    key: const Key('signal-repeat'),
    contentPadding: EdgeInsets.zero,
    title: const Text('Repeat until stopped'),
    value: _repeat,
    onChanged: (v) {
      setState(() => _repeat = v);
      _restartIfRunning();
    },
  );
}
