import 'package:flutter/material.dart';

import '../app.dart';
import '../services/settings.dart';

/// Lamp colours people actually reach for: plain and warm white for reading,
/// red to keep night vision, and a few moods.
const presetColors = <String, Color>{
  'White': Color(0xFFFFFFFF),
  'Warm': Color(0xFFFFD8A8),
  'Candle': Color(0xFFFFA64D),
  'Red': Color(0xFFFF2A2A),
  'Green': Color(0xFF2EE66B),
  'Cyan': Color(0xFF2FE0F0),
  'Blue': Color(0xFF3D6BFF),
  'Purple': Color(0xFFA64DFF),
  'Pink': Color(0xFFFF5FB4),
};

/// Presets, hue, saturation and brightness. Used on the Screen tab and in
/// the glow overlay, so both always show the same state.
class ColorControls extends StatelessWidget {
  const ColorControls({super.key, required this.settings});
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final color = settings.screenColor;
        final hsv = HSVColor.fromColor(color);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final e in presetColors.entries)
                  _Swatch(
                    name: e.key,
                    color: e.value,
                    selected: e.value.toARGB32() == color.toARGB32(),
                    onTap: () => settings.screenColor = e.value,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _label('Colour'),
            _GradientSlider(
              key: const Key('hue-slider'),
              value: hsv.hue / 360,
              colors: [for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor()],
              onChanged: (v) => settings.screenColor = HSVColor.fromAHSV(
                1,
                (v * 360).clamp(0, 359.9),
                hsv.saturation < 0.05 ? 1 : hsv.saturation,
                1,
              ).toColor(),
            ),
            _label('Saturation'),
            _GradientSlider(
              key: const Key('saturation-slider'),
              value: hsv.saturation,
              colors: [Colors.white, HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor()],
              onChanged: (v) => settings.screenColor = HSVColor.fromAHSV(1, hsv.hue, v, 1).toColor(),
            ),
            _label('Brightness ${(settings.screenBrightness * 100).round()}%', key: const Key('brightness-label')),
            Slider(
              key: const Key('brightness-slider'),
              value: settings.screenBrightness,
              min: 0.05,
              max: 1,
              onChanged: (v) => settings.screenBrightness = v,
            ),
          ],
        );
      },
    );
  }

  Widget _label(String text, {Key? key}) => Padding(
    padding: const EdgeInsets.only(left: 4, top: 4),
    child: Text(
      text,
      key: key,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white70),
    ),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.color, required this.selected, required this.onTap});
  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$name light',
      child: GestureDetector(
        key: Key('swatch-${name.toLowerCase()}'),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? beamAmber : Colors.white24, width: selected ? 3 : 1),
          ),
          child: selected
              ? Icon(Icons.check, size: 20, color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white)
              : null,
        ),
      ),
    );
  }
}

/// A slider whose track is a colour gradient.
class _GradientSlider extends StatelessWidget {
  const _GradientSlider({super.key, required this.value, required this.colors, required this.onChanged});
  final double value;
  final List<Color> colors;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(colors: colors),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 12,
            activeTrackColor: Colors.transparent,
            inactiveTrackColor: Colors.transparent,
            thumbColor: Colors.white,
            overlayColor: Colors.white24,
          ),
          child: Slider(value: value.clamp(0, 1), onChanged: onChanged),
        ),
      ],
    );
  }
}
