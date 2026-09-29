import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../skins.dart';
import 'atlas.dart' show darken, lighten;

/// Pose of a monster for one frame. The game fills it from a [Monster]; the
/// menus use the defaults with a gentle idle animation.
class MonsterPose {
  const MonsterPose({
    this.wobble = 0,
    this.chomp = 0,
    this.fx = 0,
    this.fy = 1,
    this.blink = 1,
    this.squash = 0,
    this.shield = false,
    this.hungry = 0,
  });

  final double wobble;

  /// 0..1: how wide the mouth is open.
  final double chomp;

  /// Facing (unit vector), for the eyes.
  final double fx, fy;

  /// Negative while the eyes are shut.
  final double blink;
  final double squash;
  final bool shield;

  /// 0..1: mouth hangs open when food is near.
  final double hungry;
}

/// The monsters, drawn with vector paths so they stay crisp at any size, from
/// a 40 px store tile to half the screen.
class MonsterArt {
  const MonsterArt._();

  static const Color _ink = Color(0xFF2B2240);

  static void paint(Canvas c, SkinDef skin, double r, MonsterPose pose, {double time = 0}) {
    final sq = pose.squash;
    c.save();
    c.scale(1 + 0.1 * sq, 1 - 0.08 * sq);

    // Ground shadow.
    c.drawOval(
      Rect.fromCenter(center: Offset(r * 0.08, r * 0.62), width: r * 2.1, height: r * 0.9),
      Paint()..color = const Color(0x33000000),
    );

    _backFeatures(c, skin, r, time);

    final body = _bodyPath(skin, r, pose.wobble);
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);
    final Paint bodyPaint;
    if (skin.feature == SkinFeature.rainbow) {
      bodyPaint = Paint()
        ..shader = ui.Gradient.sweep(
          Offset.zero,
          const [
            Color(0xFFFF6A6A),
            Color(0xFFFFC94A),
            Color(0xFF7AE05A),
            Color(0xFF4FC3F7),
            Color(0xFFA774E8),
            Color(0xFFFF6A6A),
          ],
          const [0, 0.2, 0.4, 0.6, 0.8, 1],
          TileMode.repeated,
          time * 0.8,
          time * 0.8 + pi * 2,
        );
    } else {
      bodyPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(-r * 0.35, -r * 0.45),
          r * 1.6,
          [lighten(skin.body, 0.25), skin.body, skin.shade],
          const [0, 0.45, 1],
        );
    }
    if (skin.feature == SkinFeature.ghost) {
      c.saveLayer(rect.inflate(r * 0.3), Paint()..color = const Color(0xDDFFFFFF));
    }
    c.drawPath(body, bodyPaint);
    if (skin.feature == SkinFeature.rainbow) {
      c.drawPath(
        body,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(-r * 0.3, -r * 0.4),
            r * 1.4,
            const [Color(0x88FFFFFF), Color(0x00FFFFFF), Color(0x33000000)],
            const [0, 0.5, 1],
          ),
      );
    }

    // Belly.
    c.save();
    c.clipPath(body);
    c.drawOval(
      Rect.fromCenter(center: Offset(0, r * 0.45), width: r * 1.35, height: r * 1.1),
      Paint()..color = skin.belly.withValues(alpha: 0.75),
    );
    _bodyPattern(c, skin, r, time);
    c.restore();

    c.drawPath(
      body,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, r * 0.07)
        ..strokeJoin = StrokeJoin.round,
    );
    if (skin.feature == SkinFeature.ghost) c.restore();

    // Gloss.
    c.drawOval(
      Rect.fromCenter(center: Offset(-r * 0.42, -r * 0.5), width: r * 0.55, height: r * 0.3),
      Paint()..color = const Color(0x66FFFFFF),
    );

    _face(c, skin, r, pose);
    _frontFeatures(c, skin, r, time);
    c.restore();

    if (pose.shield) {
      c.drawCircle(
        Offset.zero,
        r * 1.25,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            r * 1.25,
            const [Color(0x00FFFFFF), Color(0x2280E0FF), Color(0x9980E0FF)],
            const [0, 0.8, 1],
          ),
      );
    }
  }

  static Path _bodyPath(SkinDef skin, double r, double wobble) {
    final path = Path();
    const n = 72;
    final ghost = skin.feature == SkinFeature.ghost;
    for (var i = 0; i <= n; i++) {
      final a = i / n * pi * 2;
      var rr = r * (1 + 0.035 * sin(a * 5 + wobble * 2.3) + 0.02 * sin(a * 3 - wobble * 1.7));
      // Ghosts have a wavy hem.
      if (ghost && sin(a) > 0.2) rr *= 1 + 0.08 * sin(a * 9 + wobble * 3);
      final x = cos(a) * rr;
      final y = sin(a) * rr * (ghost ? 1.08 : 1);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    return path..close();
  }

  static void _face(Canvas c, SkinDef skin, double r, MonsterPose pose) {
    final lookX = pose.fx * r * 0.1, lookY = pose.fy * r * 0.08;
    final eyeY = -r * 0.28 + lookY;
    final eyeR = r * 0.24;
    for (final side in [-1.0, 1.0]) {
      final ex = side * r * 0.33 + lookX;
      if (pose.blink < 0) {
        c.drawArc(
          Rect.fromCircle(center: Offset(ex, eyeY), radius: eyeR * 0.8),
          0.2,
          pi - 0.4,
          false,
          Paint()
            ..color = _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1, r * 0.06)
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }
      c.drawCircle(Offset(ex, eyeY), eyeR, Paint()..color = const Color(0xFFFFFFFF));
      c.drawCircle(
        Offset(ex, eyeY),
        eyeR,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1, r * 0.045),
      );
      final px = ex + pose.fx * eyeR * 0.35, py = eyeY + pose.fy * eyeR * 0.3;
      c.drawCircle(Offset(px, py), eyeR * 0.55, Paint()..color = _ink);
      c.drawCircle(Offset(px - eyeR * 0.2, py - eyeR * 0.22), eyeR * 0.2, Paint()..color = const Color(0xFFFFFFFF));
    }
    // Brows for the devil.
    if (skin.feature == SkinFeature.horns) {
      for (final side in [-1.0, 1.0]) {
        c.drawLine(
          Offset(side * r * 0.14 + lookX, eyeY - eyeR * 1.05),
          Offset(side * r * 0.52 + lookX, eyeY - eyeR * 1.45),
          Paint()
            ..color = _ink
            ..strokeWidth = r * 0.07
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    // Cheeks.
    for (final side in [-1.0, 1.0]) {
      c.drawOval(
        Rect.fromCenter(center: Offset(side * r * 0.55 + lookX, r * 0.02 + lookY), width: r * 0.22, height: r * 0.13),
        Paint()..color = const Color(0x55FF5A7A),
      );
    }

    // Mouth: a grin that opens into a big chomp.
    final open = max(pose.chomp, pose.hungry * 0.45);
    final my = r * 0.18 + lookY * 0.6;
    final mx = lookX * 0.6;
    final mw = r * (0.62 + open * 0.2);
    final mh = r * (0.1 + open * 0.55);
    final mouth = Path()
      ..moveTo(mx - mw / 2, my)
      ..quadraticBezierTo(mx, my - r * 0.06 * (1 - open), mx + mw / 2, my)
      ..quadraticBezierTo(mx, my + mh * 1.6, mx - mw / 2, my)
      ..close();
    c.drawPath(mouth, Paint()..color = const Color(0xFF5A1830));
    c.save();
    c.clipPath(mouth);
    c.drawOval(
      Rect.fromCenter(center: Offset(mx, my + mh * 0.95), width: mw * 0.6, height: mh * 0.8),
      Paint()..color = const Color(0xFFFF6A8A),
    );
    // Teeth.
    final tooth = r * 0.09;
    for (final side in [-1.0, 1.0]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(mx + side * mw * 0.18 - tooth / 2, my - 1, tooth, tooth * 1.1),
          Radius.circular(tooth * 0.3),
        ),
        Paint()..color = const Color(0xFFFFFFFF),
      );
    }
    c.restore();
    c.drawPath(
      mouth,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1, r * 0.05)
        ..strokeJoin = StrokeJoin.round,
    );
    if (skin.feature == SkinFeature.teeth) {
      for (final side in [-1.0, 1.0]) {
        final fang = Path()
          ..moveTo(mx + side * mw * 0.32, my + r * 0.01)
          ..lineTo(mx + side * mw * 0.2, my + r * 0.01)
          ..lineTo(mx + side * mw * 0.26, my + r * 0.16)
          ..close();
        c.drawPath(fang, Paint()..color = const Color(0xFFFFFFFF));
        c.drawPath(
          fang,
          Paint()
            ..color = _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(0.8, r * 0.025),
        );
      }
    }
  }

  static Paint _outline(double r) => Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(1, r * 0.05)
    ..strokeJoin = StrokeJoin.round;

  /// Things behind the body (ears, horns, spikes, flames).
  static void _backFeatures(Canvas c, SkinDef skin, double r, double time) {
    switch (skin.feature) {
      case SkinFeature.ears:
        for (final side in [-1.0, 1.0]) {
          final ear = Path()
            ..moveTo(side * r * 0.3, -r * 0.8)
            ..quadraticBezierTo(side * r * 0.75, -r * 1.55, side * r * 0.9, -r * 0.45)
            ..close();
          c.drawPath(ear, Paint()..color = skin.body);
          c.drawPath(ear, _outline(r));
          final inner = Path()
            ..moveTo(side * r * 0.42, -r * 0.78)
            ..quadraticBezierTo(side * r * 0.72, -r * 1.3, side * r * 0.8, -r * 0.6)
            ..close();
          c.drawPath(inner, Paint()..color = const Color(0xFFFFC2D8));
        }
      case SkinFeature.horns:
        for (final side in [-1.0, 1.0]) {
          final horn = Path()
            ..moveTo(side * r * 0.25, -r * 0.85)
            ..quadraticBezierTo(side * r * 0.55, -r * 1.55, side * r * 0.85, -r * 1.35)
            ..quadraticBezierTo(side * r * 0.62, -r * 1.15, side * r * 0.62, -r * 0.7)
            ..close();
          c.drawPath(horn, Paint()..color = const Color(0xFFFFF0D0));
          c.drawPath(horn, _outline(r));
        }
      case SkinFeature.spikes:
        for (var i = 0; i < 7; i++) {
          final a = -pi / 2 + (i - 3) * 0.36;
          final p = Path()
            ..moveTo(cos(a - 0.14) * r * 0.92, sin(a - 0.14) * r * 0.92)
            ..lineTo(cos(a) * r * 1.3, sin(a) * r * 1.3)
            ..lineTo(cos(a + 0.14) * r * 0.92, sin(a + 0.14) * r * 0.92)
            ..close();
          c.drawPath(p, Paint()..color = const Color(0xFFE6FAFF));
          c.drawPath(p, _outline(r));
        }
      case SkinFeature.flames:
        for (var i = 0; i < 9; i++) {
          final a = -pi / 2 + (i - 4) * 0.3;
          final h = 1.28 + 0.1 * sin(time * 9 + i * 1.7);
          final p = Path()
            ..moveTo(cos(a - 0.17) * r * 0.9, sin(a - 0.17) * r * 0.9)
            ..quadraticBezierTo(cos(a) * r * 1.1, sin(a) * r * 1.1, cos(a + 0.05) * r * h, sin(a + 0.05) * r * h)
            ..quadraticBezierTo(
              cos(a + 0.1) * r * 1.05,
              sin(a + 0.1) * r * 1.05,
              cos(a + 0.17) * r * 0.9,
              sin(a + 0.17) * r * 0.9,
            )
            ..close();
          c.drawPath(p, Paint()..color = i.isEven ? const Color(0xFFFF8A3D) : const Color(0xFFFFC94A));
        }
      default:
        break;
    }
  }

  static void _bodyPattern(Canvas c, SkinDef skin, double r, double time) {
    switch (skin.feature) {
      case SkinFeature.spots:
        final rng = Random(3);
        for (var i = 0; i < 7; i++) {
          final a = rng.nextDouble() * pi * 2, d = r * (0.35 + rng.nextDouble() * 0.5);
          c.drawCircle(
            Offset(cos(a) * d, sin(a) * d),
            r * (0.08 + rng.nextDouble() * 0.08),
            Paint()..color = darken(skin.body, 0.25).withValues(alpha: 0.7),
          );
        }
      case SkinFeature.stars:
        final rng = Random(8);
        for (var i = 0; i < 14; i++) {
          final a = rng.nextDouble() * pi * 2, d = r * rng.nextDouble() * 0.95;
          final tw = 0.5 + 0.5 * sin(time * 3 + i);
          c.drawCircle(
            Offset(cos(a) * d, sin(a) * d),
            r * (0.02 + rng.nextDouble() * 0.03),
            Paint()..color = Color.fromRGBO(255, 255, 255, 0.4 + 0.6 * tw),
          );
        }
      case SkinFeature.flames:
        final glow = Paint()
          ..color = Color.fromRGBO(255, 140, 60, 0.55 + 0.25 * sin(time * 4))
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.05
          ..strokeCap = StrokeCap.round;
        c.drawLine(Offset(-r * 0.7, r * 0.1), Offset(-r * 0.45, r * 0.35), glow);
        c.drawLine(Offset(-r * 0.45, r * 0.35), Offset(-r * 0.55, r * 0.6), glow);
        c.drawLine(Offset(r * 0.65, -r * 0.05), Offset(r * 0.5, r * 0.3), glow);
      case SkinFeature.antenna when skin.id == 'robo':
        final bolt = Paint()..color = darken(skin.body, 0.35);
        for (final p in [
          Offset(-r * 0.7, 0),
          Offset(r * 0.7, 0),
          Offset(-r * 0.5, r * 0.55),
          Offset(r * 0.5, r * 0.55),
        ]) {
          c.drawCircle(p, r * 0.05, bolt);
        }
      default:
        break;
    }
  }

  /// Things in front of the body (antenna, crown, bow).
  static void _frontFeatures(Canvas c, SkinDef skin, double r, double time) {
    switch (skin.feature) {
      case SkinFeature.antenna:
        final sway = sin(time * 3) * r * 0.08;
        c.drawLine(
          Offset(0, -r * 0.9),
          Offset(sway, -r * 1.4),
          Paint()
            ..color = const Color(0xFF2B2240)
            ..strokeWidth = max(1, r * 0.06)
            ..strokeCap = StrokeCap.round,
        );
        final tip = skin.id == 'robo' ? const Color(0xFFFF5A5A) : const Color(0xFFFFD35C);
        c.drawCircle(Offset(sway, -r * 1.45), r * 0.13, Paint()..color = tip);
        c.drawCircle(Offset(sway, -r * 1.45), r * 0.13, _outline(r));
      case SkinFeature.crown:
        final crown = Path()
          ..moveTo(-r * 0.45, -r * 0.82)
          ..lineTo(-r * 0.5, -r * 1.3)
          ..lineTo(-r * 0.22, -r * 1.08)
          ..lineTo(0, -r * 1.42)
          ..lineTo(r * 0.22, -r * 1.08)
          ..lineTo(r * 0.5, -r * 1.3)
          ..lineTo(r * 0.45, -r * 0.82)
          ..close();
        c.drawPath(crown, Paint()..color = const Color(0xFFFFD35C));
        c.drawPath(crown, _outline(r));
        for (final x in [-0.25, 0.0, 0.25]) {
          c.drawCircle(Offset(r * x, -r * 0.95), r * 0.06, Paint()..color = const Color(0xFFE8504A));
        }
      case SkinFeature.bow:
        final bow = Paint()..color = const Color(0xFFFF5A8A);
        for (final side in [-1.0, 1.0]) {
          final wing = Path()
            ..moveTo(0, -r * 0.92)
            ..lineTo(side * r * 0.45, -r * 1.22)
            ..lineTo(side * r * 0.45, -r * 0.7)
            ..close();
          c.drawPath(wing, bow);
          c.drawPath(wing, _outline(r));
        }
        c.drawCircle(Offset(0, -r * 0.94), r * 0.11, bow);
        c.drawCircle(Offset(0, -r * 0.94), r * 0.11, _outline(r));
      default:
        break;
    }
  }
}
