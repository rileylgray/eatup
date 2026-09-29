import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../map_gen.dart';
import '../maps.dart';

/// Records a map's ground (grass, roads, plazas, ponds...) once into a
/// [ui.Picture]; the game replays it every frame under the camera transform.
class GroundArt {
  const GroundArt._();

  static Color colorOf(GroundPaint p, GroundPalette g) => switch (p) {
    GroundPaint.grass => g.grass,
    GroundPaint.grassDark => g.grassDark,
    GroundPaint.road => g.road,
    GroundPaint.roadLine => g.roadLine,
    GroundPaint.sidewalk => g.sidewalk,
    GroundPaint.plaza => g.plaza,
    GroundPaint.water => g.water,
    GroundPaint.field => const Color(0xFFB98D5A),
    GroundPaint.fieldRow => const Color(0xFF86B84E),
    GroundPaint.asphalt => Color.lerp(g.road, const Color(0xFFFFFFFF), 0.12)!,
    GroundPaint.stripe => const Color(0xE6FFFFFF),
    GroundPaint.dirt => const Color(0xFFC9A57A),
    GroundPaint.pool => const Color(0xFF6FD6F0),
    GroundPaint.sea => g.water,
    GroundPaint.foam => const Color(0xDDFFFFFF),
  };

  static ui.Picture record(MapLayout layout) {
    final g = layout.map.ground;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final w = layout.width, h = layout.height;
    final full = layout.map.size;

    // Beyond the edge of town.
    c.drawRect(Rect.fromLTWH(-3000, -3000, w + 6000, full + 6000), Paint()..color = g.edge);
    final rng = Random(layout.map.id.hashCode);
    for (var i = 0; i < 260; i++) {
      final x = -600 + rng.nextDouble() * (w + 1200);
      final y = -600 + rng.nextDouble() * (full + 1200);
      if (x > -20 && x < w + 20 && y > -20 && y < full + 20) continue;
      c.drawCircle(
        Offset(x, y),
        18 + rng.nextDouble() * 26,
        Paint()..color = Color.lerp(g.edge, const Color(0xFF000000), 0.12)!,
      );
    }

    for (var i = 0; i < layout.ground.length; i++) {
      final s = layout.ground[i];
      final paint = Paint()..color = colorOf(s.paint, g);
      final rect = Rect.fromLTWH(s.x, s.y, s.w, s.h);
      if (s.paint == GroundPaint.sea) {
        c.drawRect(rect, paint);
        continue;
      }
      if (s.oval) {
        c.drawOval(rect.inflate(4), Paint()..color = Color.lerp(colorOf(s.paint, g), const Color(0xFFFFFFFF), 0.5)!);
        c.drawOval(rect, paint);
      } else if (s.round > 0) {
        c.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(s.round)), paint);
      } else {
        c.drawRect(rect, paint);
      }
      if (s.paint == GroundPaint.pool) {
        c.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(s.round)),
          Paint()
            ..color = const Color(0xFFFFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
      }
      // Texture on the base grass, under everything else.
      if (i == 0) _speckle(c, rect, g, rng, snow: layout.map.snow);
    }

    // A low hedge (or snowbank) marks the edge.
    final border = Paint()
      ..color = Color.lerp(g.edge, const Color(0xFF000000), 0.2)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-5, -5, w + 10, layout.map.sea ? h + 400 : h + 10),
        const Radius.circular(8),
      ),
      border,
    );
    return rec.endRecording();
  }

  static void _speckle(Canvas c, Rect r, GroundPalette g, Random rng, {required bool snow}) {
    final tuft = Paint()..color = Color.lerp(g.grass, snow ? const Color(0xFF9AB6D6) : const Color(0xFF2E6A2A), 0.18)!;
    final light = Paint()..color = Color.lerp(g.grass, const Color(0xFFFFFFFF), 0.25)!;
    final n = (r.width * r.height / 2600).round();
    for (var i = 0; i < n; i++) {
      final x = r.left + rng.nextDouble() * r.width;
      final y = r.top + rng.nextDouble() * r.height;
      if (rng.nextBool()) {
        c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 5, height: 2.6), tuft);
      } else {
        c.drawCircle(Offset(x, y), 1.4, light);
      }
    }
  }
}
