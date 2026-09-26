// Renders Beam's launcher icons and Play Store graphics in code, so they can
// be regenerated at any time (no image tools or generators needed).
//
//   flutter test tool/make_graphics_test.dart
//
// Writes:
//   android/app/src/main/res/drawable-*/ic_launcher_{foreground,background,monochrome}.png  adaptive icon
//   android/app/src/main/res/mipmap-*/ic_launcher.png                                        legacy icon
//   store-assets/icon-512.png                     Play icon (512x512, Play applies the mask)
//   store-assets/feature-graphic-1024x500.png     Play feature graphic
//   store-assets/screenshots/*.png                1080x1920 captioned phone screenshots, built from
//                                                 the raw device captures in store-assets/raw/
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const res = 'android/app/src/main/res';
const amber = Color(0xFFFFC247);
const amberDeep = Color(0xFFE08A00);
const bgInner = Color(0xFF1C212B);
const bgOuter = Color(0xFF07080B);

Future<void> save(String path, int w, int h, void Function(Canvas c, Size s) draw) async {
  final rec = ui.PictureRecorder();
  draw(Canvas(rec), Size(w.toDouble(), h.toDouble()));
  final img = await rec.endRecording().toImage(w, h);
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void background(Canvas c, Rect r, {Offset? focus}) {
  c.drawRect(
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        focus ?? r.center,
        r.longestSide * 0.8,
        [bgInner, const Color(0xFF0E1116), bgOuter],
        [0, 0.5, 1],
      ),
  );
}

/// The Beam mark: a glowing lens throwing a cone of light upward, drawn in
/// the unit box [box]. With [mono] everything is flat white (themed icons).
void mark(Canvas c, Rect box, {bool mono = false}) {
  Offset p(double x, double y) => Offset(box.left + box.width * x, box.top + box.height * y);
  final w = box.width;
  final lens = p(0.5, 0.70);
  final lensR = w * 0.14;

  // Cone of light.
  final cone = Path()
    ..moveTo(p(0.40, 0.66).dx, p(0.40, 0.66).dy)
    ..lineTo(p(0.12, 0.14).dx, p(0.12, 0.14).dy)
    ..quadraticBezierTo(p(0.5, -0.02).dx, p(0.5, -0.02).dy, p(0.88, 0.14).dx, p(0.88, 0.14).dy)
    ..lineTo(p(0.60, 0.66).dx, p(0.60, 0.66).dy)
    ..close();
  c.drawPath(
    cone,
    Paint()
      ..shader = ui.Gradient.linear(
        p(0.5, 0.66),
        p(0.5, 0.04),
        mono
            ? [Colors.white, Colors.white.withValues(alpha: 0.35)]
            : [amber.withValues(alpha: 0.95), const Color(0xFFFFE6A6).withValues(alpha: 0.18)],
      ),
  );
  if (!mono) {
    // Bright core ray down the middle of the cone.
    final core = Path()
      ..moveTo(p(0.46, 0.66).dx, p(0.46, 0.66).dy)
      ..lineTo(p(0.36, 0.10).dx, p(0.36, 0.10).dy)
      ..quadraticBezierTo(p(0.5, 0.06).dx, p(0.5, 0.06).dy, p(0.64, 0.10).dx, p(0.64, 0.10).dy)
      ..lineTo(p(0.54, 0.66).dx, p(0.54, 0.66).dy)
      ..close();
    c.drawPath(
      core,
      Paint()
        ..shader = ui.Gradient.linear(p(0.5, 0.66), p(0.5, 0.08), [
          Colors.white.withValues(alpha: 0.75),
          Colors.white.withValues(alpha: 0.0),
        ]),
    );
    // Halo around the lens.
    c.drawCircle(
      lens,
      lensR * 1.9,
      Paint()
        ..shader = ui.Gradient.radial(lens, lensR * 1.9, [amber.withValues(alpha: 0.55), amber.withValues(alpha: 0)]),
    );
  }
  // Lens.
  c.drawCircle(
    lens,
    lensR,
    Paint()
      ..shader = mono
          ? null
          : ui.Gradient.radial(
              lens - Offset(lensR * 0.25, lensR * 0.25),
              lensR * 1.1,
              [Colors.white, const Color(0xFFFFEBB0), amber, amberDeep],
              [0, 0.35, 0.75, 1],
            )
      ..color = Colors.white,
  );
  // Housing ring.
  c.drawCircle(
    lens,
    lensR * 1.18,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lensR * 0.22
      ..color = mono ? Colors.white : const Color(0xFF3A3F4A),
  );
}

Future<void> icons() async {
  const densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};
  for (final e in densities.entries) {
    final fg = (108 * e.value).round();
    // Adaptive layers: the mark sits in the 66dp safe zone of the 108dp canvas.
    Rect safe(Size s) => Rect.fromCenter(center: s.center(Offset.zero), width: s.width * 0.60, height: s.height * 0.60);
    await save('$res/drawable-${e.key}/ic_launcher_foreground.png', fg, fg, (c, s) => mark(c, safe(s)));
    await save('$res/drawable-${e.key}/ic_launcher_monochrome.png', fg, fg, (c, s) => mark(c, safe(s), mono: true));
    await save(
      '$res/drawable-${e.key}/ic_launcher_background.png',
      fg,
      fg,
      (c, s) => background(c, Offset.zero & s, focus: Offset(s.width / 2, s.height * 0.62)),
    );
    // Legacy square icon with rounded corners (pre-Android 8 launchers).
    final lg = (48 * e.value).round();
    await save('$res/mipmap-${e.key}/ic_launcher.png', lg, lg, (c, s) {
      final r = RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(s.width * 0.22));
      c.clipRRect(r);
      background(c, Offset.zero & s, focus: Offset(s.width / 2, s.height * 0.62));
      mark(c, (Offset.zero & s).deflate(s.width * 0.14));
    });
  }
  File('$res/mipmap-anydpi-v26/ic_launcher.xml')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />
</adaptive-icon>
''');
  await save('store-assets/icon-512.png', 512, 512, (c, s) {
    background(c, Offset.zero & s, focus: Offset(s.width / 2, s.height * 0.62));
    mark(c, (Offset.zero & s).deflate(s.width * 0.14));
  });
}

void text(Canvas c, String t, Offset at, TextStyle style, {double maxWidth = 2000, TextAlign align = TextAlign.left}) {
  final tp = TextPainter(
    text: TextSpan(text: t, style: style),
    textDirection: TextDirection.ltr,
    textAlign: align,
  )..layout(maxWidth: maxWidth);
  final dx = switch (align) {
    TextAlign.center => at.dx - tp.width / 2,
    _ => at.dx,
  };
  tp.paint(c, Offset(dx, at.dy));
}

Future<void> featureGraphic() async {
  await save('store-assets/feature-graphic-1024x500.png', 1024, 500, (c, s) {
    final r = Offset.zero & s;
    background(c, r, focus: const Offset(250, 330));
    // Soft glow behind the title.
    c.drawCircle(
      const Offset(640, 230),
      380,
      Paint()
        ..shader = ui.Gradient.radial(const Offset(640, 230), 380, [
          amber.withValues(alpha: 0.10),
          amber.withValues(alpha: 0),
        ]),
    );
    mark(c, Rect.fromCenter(center: const Offset(230, 250), width: 330, height: 330));
    const title = TextStyle(
      fontFamily: 'Roboto',
      fontWeight: FontWeight.w900,
      fontSize: 132,
      color: Colors.white,
      letterSpacing: -2,
    );
    text(c, 'Beam', const Offset(450, 120), title);
    text(
      c,
      'Torch · Strobe · SOS · Screen light',
      const Offset(456, 290),
      const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w500, fontSize: 34, color: amber),
    );
    // Screen-light colour dots.
    const dots = [
      Colors.white,
      Color(0xFFFFD8A8),
      Color(0xFFFF2A2A),
      Color(0xFF2EE66B),
      Color(0xFF3D6BFF),
      Color(0xFFA64DFF),
    ];
    for (var i = 0; i < dots.length; i++) {
      c.drawCircle(Offset(474 + i * 52.0, 385), 17, Paint()..color = dots[i]);
    }
    text(
      c,
      'No login · Works offline',
      const Offset(776, 372),
      const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w400, fontSize: 20, color: Colors.white60),
    );
  });
}

Future<ui.Image> loadImage(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

/// 1080x1920 (9:16, within Play's 2:1 limit) with a caption above a framed
/// device capture.
Future<void> screenshots() async {
  const shots = [
    ('01-torch', 'One tap torch', 'Big switch, instant light'),
    ('02-strobe', 'Strobe & signals', 'Adjustable strobe up to 15 flashes a second'),
    ('03-sos', 'SOS & Morse code', 'Send SOS or any message in Morse'),
    ('04-screen', 'Screen light', 'Any colour, any brightness'),
    ('05-glow', 'Glow in any colour', 'Night-vision red, warm reading light and more'),
  ];
  for (final (name, head, sub) in shots) {
    final raw = 'store-assets/raw/$name.png';
    if (!File(raw).existsSync()) continue;
    final img = await loadImage(raw);
    await save('store-assets/screenshots/$name.png', 1080, 1920, (c, s) {
      final r = Offset.zero & s;
      background(c, r, focus: Offset(s.width / 2, s.height * 0.25));
      c.drawCircle(
        Offset(s.width / 2, 170),
        420,
        Paint()
          ..shader = ui.Gradient.radial(Offset(s.width / 2, 170), 420, [
            amber.withValues(alpha: 0.16),
            amber.withValues(alpha: 0),
          ]),
      );
      text(
        c,
        head,
        Offset(s.width / 2, 90),
        const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800, fontSize: 76, color: Colors.white),
        maxWidth: 1000,
        align: TextAlign.center,
      );
      text(
        c,
        sub,
        Offset(s.width / 2, 196),
        const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w400, fontSize: 38, color: amber),
        maxWidth: 1000,
        align: TextAlign.center,
      );
      // Phone frame.
      const top = 300.0;
      final h = s.height - top + 60; // runs off the bottom edge
      final w = h * img.width / img.height;
      final frame = Rect.fromLTWH((s.width - w) / 2, top, w, h);
      final outer = RRect.fromRectAndRadius(frame.inflate(18), const Radius.circular(64));
      c.drawRRect(
        outer.shift(const Offset(0, 16)),
        Paint()
          ..color = Colors.black54
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
      );
      c.drawRRect(outer, Paint()..color = const Color(0xFF23272F));
      c.save();
      c.clipRRect(RRect.fromRectAndRadius(frame, const Radius.circular(48)));
      c.drawImageRect(
        img,
        Offset.zero & Size(img.width.toDouble(), img.height.toDouble()),
        frame,
        Paint()..filterQuality = FilterQuality.high,
      );
      c.restore();
    });
  }
}

void main() {
  testWidgets('make graphics', (tester) async {
    await tester.runAsync(() async {
      const fonts = '/mnt/storage/projects/flutter/bin/cache/artifacts/material_fonts';
      final loader = FontLoader('Roboto');
      for (final f in ['Regular', 'Medium', 'Bold', 'Black']) {
        loader.addFont(Future.value(ByteData.sublistView(File('$fonts/Roboto-$f.ttf').readAsBytesSync())));
      }
      await loader.load();
      await icons();
      await featureGraphic();
      await screenshots();
    });
    expect(File('store-assets/icon-512.png').existsSync(), isTrue);
  });
}
