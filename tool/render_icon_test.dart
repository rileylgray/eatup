// Renders the launcher icon PNGs from code:
//   flutter test tool/render_icon_test.dart
//   dart run flutter_launcher_icons
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:eatup/game/art/atlas.dart';
import 'package:eatup/game/art/monster_art.dart';
import 'package:eatup/game/maps.dart';
import 'package:eatup/game/skins.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const double s = 1024;

void _background(Canvas c) {
  c.drawRect(
    const Rect.fromLTWH(0, 0, s, s),
    Paint()
      ..shader = ui.Gradient.radial(
        const Offset(s * 0.5, s * 0.42),
        s * 0.75,
        const [Color(0xFFFFB0D0), Color(0xFFB57BFF), Color(0xFF4A2A9A)],
        const [0, 0.5, 1],
      ),
  );
  // Sunburst.
  for (var i = 0; i < 16; i++) {
    final a = i * pi / 8;
    final p = Path()
      ..moveTo(s / 2, s * 0.46)
      ..lineTo(s / 2 + cos(a - 0.09) * s, s * 0.46 + sin(a - 0.09) * s)
      ..lineTo(s / 2 + cos(a + 0.09) * s, s * 0.46 + sin(a + 0.09) * s)
      ..close();
    c.drawPath(p, Paint()..color = const Color(0x1AFFFFFF));
  }
}

void _foreground(Canvas c, {double scale = 1}) {
  c.save();
  c.translate(s / 2, s / 2);
  c.scale(scale);
  c.translate(-s / 2, -s / 2);
  // Two panicking townsfolk being pulled in.
  for (final (x, y, v, a) in [(0.2, 0.74, 0, -0.5), (0.8, 0.7, 3, 0.45)]) {
    c.save();
    c.translate(s * x, s * y);
    c.rotate(a);
    c.scale(s * 0.0105);
    PersonArt.draw(c, PeopleStyle.casual, v, 2);
    c.restore();
  }
  c.save();
  c.translate(s * 0.5, s * 0.5);
  MonsterArt.paint(c, skinById('blob'), s * 0.3, const MonsterPose(chomp: 0.85, fy: 0.4, wobble: 1.3), time: 1);
  c.restore();
  c.restore();
}

Future<void> _save(String path, void Function(Canvas) paint) async {
  final rec = ui.PictureRecorder();
  paint(Canvas(rec));
  final img = await rec.endRecording().toImage(s.toInt(), s.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('render icon', () async {
    await _save('assets/icon/icon.png', (c) {
      _background(c);
      _foreground(c);
    });
    await _save('assets/icon/icon_bg.png', _background);
    // Adaptive icons crop to a circle/squircle: keep the art in the middle.
    await _save('assets/icon/icon_fg.png', (c) => _foreground(c, scale: 0.72));
  });
}
