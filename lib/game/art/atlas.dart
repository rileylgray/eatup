import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../entities.dart';
import '../map_gen.dart';
import '../maps.dart';
import '../props.dart';

/// Where a sprite sits in the atlas. [cx], [cy] is the pixel that lands on
/// the entity's world position.
class SpriteRef {
  const SpriteRef(this.src, this.cx, this.cy);
  final Rect src;
  final double cx, cy;
}

/// Every person, prop and pickup, painted once from code into a single
/// texture at start-up. The game then draws hundreds of them per frame with
/// one `drawRawAtlas` call, which is what keeps big towns smooth on low-end
/// phones. No image assets, so the art is all tunable here.
class Atlas {
  Atlas._(this.image, this._props, this._people, this.shadow, this.powerUps);

  final ui.Image image;
  final Map<int, SpriteRef> _props;
  final Map<PeopleStyle, List<SpriteRef>> _people;
  final SpriteRef shadow;
  final Map<PowerKind, SpriteRef> powerUps;

  static int _key(PropKind k, int v) => k.index * 16 + v;

  SpriteRef prop(PropKind k, int variant) => _props[_key(k, variant)] ?? _props[_key(k, 0)]!;

  /// Frames: 0 and 1 walk, 2 panicking.
  SpriteRef person(PeopleStyle style, int variant, int frame) => _people[style]![variant * 3 + frame];

  static Future<Atlas> build() async {
    final jobs = <_Job>[];
    // Props.
    final propJobs = <int, _Job>{};
    for (final k in PropKind.values) {
      for (var v = 0; v < MapGen.variantsOf(k); v++) {
        final box = k.size * (k.vehicle ? 2.6 : 2.5);
        final j = _Job(box, box, (c) => PropArt.draw(c, k, v));
        propJobs[_key(k, v)] = j;
        jobs.add(j);
      }
    }
    // People.
    final peopleJobs = <PeopleStyle, List<_Job>>{};
    for (final style in PeopleStyle.values) {
      final list = <_Job>[];
      for (var v = 0; v < peopleVariants; v++) {
        for (var f = 0; f < 3; f++) {
          final j = _Job(16, 26, (c) {
            c.translate(0, 1.5);
            PersonArt.draw(c, style, v, f);
          });
          list.add(j);
          jobs.add(j);
        }
      }
      peopleJobs[style] = list;
    }
    final shadowJob = _Job(40, 40, (c) {
      c.drawCircle(
        Offset.zero,
        19,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            19,
            const [Color(0x55000000), Color(0x33000000), Color(0x00000000)],
            const [0, 0.6, 1],
          ),
      );
    });
    jobs.add(shadowJob);
    final powerJobs = {for (final k in PowerKind.values) k: _Job(26, 26, (c) => PowerArt.draw(c, k))};
    jobs.addAll(powerJobs.values);

    // Shelf-pack, tallest first.
    const width = 2048.0;
    const pad = 3.0;
    final order = [...jobs]..sort((a, b) => b.ph.compareTo(a.ph));
    var x = pad, y = pad, shelf = 0.0;
    for (final j in order) {
      if (x + j.pw + pad > width) {
        x = pad;
        y += shelf + pad;
        shelf = 0;
      }
      j.x = x;
      j.y = y;
      x += j.pw + pad;
      shelf = max(shelf, j.ph);
    }
    final height = (y + shelf + pad).ceilToDouble();

    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    for (final j in jobs) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(j.x, j.y, j.pw, j.ph));
      canvas.translate(j.x + j.pw / 2, j.y + j.ph / 2);
      canvas.scale(spriteScale);
      j.paint(canvas);
      canvas.restore();
    }
    final image = await rec.endRecording().toImage(width.toInt(), height.toInt());

    return Atlas._(
      image,
      propJobs.map((k, j) => MapEntry(k, j.ref)),
      peopleJobs.map((k, l) => MapEntry(k, [for (final j in l) j.ref])),
      shadowJob.ref,
      powerJobs.map((k, j) => MapEntry(k, j.ref)),
    );
  }
}

class _Job {
  _Job(double w, double h, this.paint) : pw = (w * spriteScale).ceilToDouble(), ph = (h * spriteScale).ceilToDouble();
  final double pw, ph;
  final void Function(Canvas) paint;
  double x = 0, y = 0;

  SpriteRef get ref => SpriteRef(Rect.fromLTWH(x, y, pw, ph), pw / 2, ph / 2);
}

// ---------------------------------------------------------------------------
// Shared painting helpers.

Paint fill(Color c) => Paint()..color = c;

Paint stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round;

const Color ink = Color(0xFF2B2240);

Color darken(Color c, double t) => Color.lerp(c, const Color(0xFF1A1030), t)!;
Color lighten(Color c, double t) => Color.lerp(c, const Color(0xFFFFFFFF), t)!;

void rrect(Canvas c, double x, double y, double w, double h, double r, Color color, {double outline = 0.9}) {
  final rr = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));
  c.drawRRect(rr, fill(color));
  if (outline > 0) c.drawRRect(rr, stroke(ink.withValues(alpha: 0.55), outline));
}

void circle(Canvas c, double x, double y, double r, Color color, {double outline = 0.9}) {
  c.drawCircle(Offset(x, y), r, fill(color));
  if (outline > 0) c.drawCircle(Offset(x, y), r, stroke(ink.withValues(alpha: 0.55), outline));
}

void oval(Canvas c, double x, double y, double w, double h, Color color, {double outline = 0.9}) {
  final rect = Rect.fromCenter(center: Offset(x, y), width: w, height: h);
  c.drawOval(rect, fill(color));
  if (outline > 0) c.drawOval(rect, stroke(ink.withValues(alpha: 0.55), outline));
}

/// A soft highlight blob, for that glossy toy look.
void shine(Canvas c, double x, double y, double w, double h, [double alpha = 0.45]) {
  c.drawOval(Rect.fromCenter(center: Offset(x, y), width: w, height: h), fill(Color.fromRGBO(255, 255, 255, alpha)));
}

// ---------------------------------------------------------------------------

class PersonArt {
  const PersonArt._();

  static const skinTones = [
    Color(0xFFF6D2B5),
    Color(0xFFE8B48E),
    Color(0xFFC68A62),
    Color(0xFF8D5A3B),
    Color(0xFFF1C7A0),
    Color(0xFFA8704C),
  ];
  static const hairs = [
    Color(0xFF5A3A22),
    Color(0xFF1E1A1A),
    Color(0xFFE8C46A),
    Color(0xFFB5502A),
    Color(0xFF3A2A20),
    Color(0xFF8A8A8A),
  ];

  static List<Color> _tops(PeopleStyle s) => switch (s) {
    PeopleStyle.casual => const [
      Color(0xFFE8504A),
      Color(0xFF3F8EE8),
      Color(0xFFFFC93C),
      Color(0xFF4CC46B),
      Color(0xFFA062E0),
      Color(0xFFFF8A3D),
    ],
    PeopleStyle.beach => const [
      Color(0xFFFF5A8A),
      Color(0xFF28C8D8),
      Color(0xFFFFD23C),
      Color(0xFF7AE05A),
      Color(0xFFFF7A3D),
      Color(0xFF6A7CFF),
    ],
    PeopleStyle.farm => const [
      Color(0xFFD8463C),
      Color(0xFF3D7BD0),
      Color(0xFF6AA84F),
      Color(0xFFE8A33C),
      Color(0xFF9B5DE5),
      Color(0xFFD8463C),
    ],
    PeopleStyle.winter => const [
      Color(0xFFE23C4A),
      Color(0xFF1E9CB0),
      Color(0xFF2F4F9E),
      Color(0xFFF2A23C),
      Color(0xFF6BBF59),
      Color(0xFFB04AC8),
    ],
    PeopleStyle.business => const [
      Color(0xFF3A4252),
      Color(0xFF2B3C66),
      Color(0xFF5A5F6B),
      Color(0xFF232733),
      Color(0xFF6B4A3A),
      Color(0xFF2B3C66),
    ],
  };

  static void draw(Canvas c, PeopleStyle style, int v, int frame) {
    final skin = skinTones[v % skinTones.length];
    final hair = hairs[(v * 5 + style.index) % hairs.length];
    final top = _tops(style)[v];
    final panic = frame == 2;
    final pants = switch (style) {
      PeopleStyle.beach => skin,
      PeopleStyle.business => darken(top, 0.25),
      PeopleStyle.farm => const Color(0xFF3F5E9C),
      _ => const [Color(0xFF2E3F66), Color(0xFF4A6FA5), Color(0xFF444444), Color(0xFF6B4A2E)][v % 4],
    };

    // Legs.
    final step = frame == 0 ? 0.9 : (frame == 1 ? -0.9 : 0);
    final spread = panic ? 0.9 : 0;
    rrect(c, -2.9 - spread, 2.6 + step, 2.4, 5.2, 1.1, pants, outline: 0.5);
    rrect(c, 0.5 + spread, 2.6 - step, 2.4, 5.2, 1.1, pants, outline: 0.5);
    circle(c, -1.7 - spread, 7.8 + step, 1.4, const Color(0xFF2A2230), outline: 0);
    circle(c, 1.7 + spread, 7.8 - step, 1.4, const Color(0xFF2A2230), outline: 0);

    // Arms.
    final armColor = style == PeopleStyle.beach ? skin : top;
    if (panic) {
      rrect(c, -6.6, -8.6, 2.2, 6.2, 1.1, armColor, outline: 0.5);
      rrect(c, 4.4, -8.6, 2.2, 6.2, 1.1, armColor, outline: 0.5);
      circle(c, -5.5, -9.2, 1.3, skin, outline: 0.4);
      circle(c, 5.5, -9.2, 1.3, skin, outline: 0.4);
    } else {
      rrect(c, -5.9, -2.4 - step * 0.5, 2.2, 5.6, 1.1, armColor, outline: 0.5);
      rrect(c, 3.7, -2.4 + step * 0.5, 2.2, 5.6, 1.1, armColor, outline: 0.5);
    }

    // Body.
    if (style == PeopleStyle.beach) {
      rrect(c, -4.2, -3.6, 8.4, 7.6, 3.2, skin, outline: 0.7);
      rrect(c, -4.2, 1.2, 8.4, 3.2, 1.4, top, outline: 0.5);
      if (v.isEven) rrect(c, -3.6, -2.8, 7.2, 2.4, 1.2, top, outline: 0.5);
    } else {
      rrect(c, -4.2, -3.6, 8.4, 7.8, 3.2, top, outline: 0.7);
      c.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-4.2, 1.6, 8.4, 2.6), const Radius.circular(1.6)),
        fill(darken(top, 0.18)),
      );
    }
    switch (style) {
      case PeopleStyle.business:
        c.drawPath(
          Path()
            ..moveTo(-1.6, -3.6)
            ..lineTo(0, -1.2)
            ..lineTo(1.6, -3.6)
            ..close(),
          fill(const Color(0xFFF4F4F4)),
        );
        c.drawPath(
          Path()
            ..moveTo(-0.6, -2.6)
            ..lineTo(0.6, -2.6)
            ..lineTo(0.9, 1.2)
            ..lineTo(0, 2)
            ..lineTo(-0.9, 1.2)
            ..close(),
          fill(const [Color(0xFFE23C4A), Color(0xFF3F8EE8), Color(0xFFFFC93C)][v % 3]),
        );
      case PeopleStyle.farm:
        rrect(c, -3.2, -1.4, 6.4, 5.4, 1.2, const Color(0xFF3F5E9C), outline: 0.4);
        circle(c, -2.2, -1.2, 0.6, const Color(0xFFFFD35C), outline: 0);
        circle(c, 2.2, -1.2, 0.6, const Color(0xFFFFD35C), outline: 0);
      case PeopleStyle.winter:
        rrect(
          c,
          -4.4,
          -4.4,
          8.8,
          2.4,
          1.2,
          const [Color(0xFFFFFFFF), Color(0xFFFFD35C), Color(0xFF6BD0E8)][v % 3],
          outline: 0.5,
        );
      default:
        break;
    }

    // Head.
    const hy = -7.6;
    circle(c, 0, hy, 4.1, skin, outline: 0.7);
    shine(c, -1.4, hy - 1.6, 2.4, 1.4, 0.35);
    // Hair or hat.
    final hat = switch (style) {
      PeopleStyle.farm => v % 3 != 2,
      PeopleStyle.winter => true,
      PeopleStyle.beach => v % 3 == 0,
      _ => false,
    };
    if (!hat) {
      c.drawArc(Rect.fromCircle(center: const Offset(0, hy), radius: 4.1), pi * 1.02, pi * 0.96, true, fill(hair));
      if (v % 3 == 1) {
        // Long hair / bun.
        circle(c, 0, hy - 4.4, 1.8, hair, outline: 0.4);
      }
    } else {
      switch (style) {
        case PeopleStyle.farm || PeopleStyle.beach:
          final brim = style == PeopleStyle.farm ? const Color(0xFFE8C46A) : const Color(0xFFFFF0C8);
          oval(c, 0, hy - 2.6, 11, 3.2, brim, outline: 0.5);
          c.drawArc(Rect.fromCircle(center: Offset(0, hy - 2.4), radius: 3.2), pi, pi, true, fill(darken(brim, 0.08)));
          c.drawRect(Rect.fromLTWH(-3.2, hy - 3.2, 6.4, 0.9), fill(const Color(0xFFD8463C)));
        default:
          final beanie = top;
          c.drawArc(Rect.fromCircle(center: const Offset(0, hy - 0.4), radius: 4.3), pi, pi, true, fill(beanie));
          rrect(c, -4.4, hy - 1.4, 8.8, 1.8, 0.9, lighten(beanie, 0.5), outline: 0.4);
          circle(c, 0, hy - 4.8, 1.4, const Color(0xFFFFFFFF), outline: 0.4);
      }
    }
    // Face.
    if (panic) {
      circle(c, -1.5, hy + 0.2, 1.15, const Color(0xFFFFFFFF), outline: 0.35);
      circle(c, 1.5, hy + 0.2, 1.15, const Color(0xFFFFFFFF), outline: 0.35);
      circle(c, -1.5, hy + 0.4, 0.5, ink, outline: 0);
      circle(c, 1.5, hy + 0.4, 0.5, ink, outline: 0);
      oval(c, 0, hy + 2.3, 1.6, 2, const Color(0xFF6A1F2A), outline: 0);
    } else {
      circle(c, -1.4, hy + 0.3, 0.55, ink, outline: 0);
      circle(c, 1.4, hy + 0.3, 0.55, ink, outline: 0);
      c.drawArc(
        Rect.fromCenter(center: Offset(0, hy + 1.5), width: 2.2, height: 1.4),
        0.2,
        pi - 0.4,
        false,
        stroke(ink, 0.45),
      );
      circle(c, -2.6, hy + 1.4, 0.7, const Color(0x55FF6A6A), outline: 0);
      circle(c, 2.6, hy + 1.4, 0.7, const Color(0x55FF6A6A), outline: 0);
    }
  }
}

// ---------------------------------------------------------------------------

class PowerArt {
  const PowerArt._();

  static Color colorOf(PowerKind k) => switch (k) {
    PowerKind.speed => const Color(0xFFFFC93C),
    PowerKind.magnet => const Color(0xFFFF5A6A),
    PowerKind.frenzy => const Color(0xFFB06BFF),
  };

  static void draw(Canvas c, PowerKind k) {
    final col = colorOf(k);
    c.drawCircle(
      Offset.zero,
      12.5,
      Paint()..shader = ui.Gradient.radial(Offset.zero, 12.5, [col.withValues(alpha: 0.55), col.withValues(alpha: 0)]),
    );
    circle(c, 0, 0, 8.5, const Color(0xFFFFFFFF), outline: 1.1);
    circle(c, 0, 0, 7, col, outline: 0);
    shine(c, -2.4, -3.4, 6, 3, 0.55);
    final white = fill(const Color(0xFFFFFFFF));
    switch (k) {
      case PowerKind.speed:
        c.drawPath(
          Path()
            ..moveTo(1.2, -5.2)
            ..lineTo(-3.4, 0.8)
            ..lineTo(-0.2, 0.8)
            ..lineTo(-1.4, 5.2)
            ..lineTo(3.4, -1)
            ..lineTo(0.2, -1)
            ..close(),
          white,
        );
      case PowerKind.magnet:
        final p = Path()
          ..addArc(Rect.fromCircle(center: const Offset(0, 0.6), radius: 3.4), 0, pi)
          ..moveTo(-3.4, 0.6)
          ..lineTo(-3.4, -3.6)
          ..moveTo(3.4, 0.6)
          ..lineTo(3.4, -3.6);
        c.drawPath(p, stroke(const Color(0xFFFFFFFF), 2.2)..strokeCap = StrokeCap.butt);
        c.drawRect(const Rect.fromLTWH(-4.5, -4.6, 2.2, 1.4), fill(const Color(0xFF3A3A4A)));
        c.drawRect(const Rect.fromLTWH(2.3, -4.6, 2.2, 1.4), fill(const Color(0xFF3A3A4A)));
      case PowerKind.frenzy:
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final a = -pi / 2 + i * pi / 5;
          final r = i.isEven ? 5.2 : 2.3;
          i == 0 ? star.moveTo(cos(a) * r, sin(a) * r) : star.lineTo(cos(a) * r, sin(a) * r);
        }
        c.drawPath(star..close(), white);
    }
  }
}

// ---------------------------------------------------------------------------

/// Painters for every prop, in world units around (0, 0). Top-down with a
/// hint of front face, lit from the top left, with a soft ink outline.
class PropArt {
  const PropArt._();

  static const carColors = [
    Color(0xFFE8504A),
    Color(0xFF3F8EE8),
    Color(0xFF4CC46B),
    Color(0xFFF4F4F4),
    Color(0xFFA062E0),
  ];
  static const roofColors = [Color(0xFFE0604F), Color(0xFF4F7FD8), Color(0xFF5BAE5B), Color(0xFF8A5AC8)];
  static const awnings = [Color(0xFFE8504A), Color(0xFF3FA0E8), Color(0xFF4CC46B)];

  static void draw(Canvas c, PropKind k, int v) {
    switch (k) {
      case PropKind.cone:
        circle(c, 0, 0, 4.2, const Color(0xFFFF7A2A));
        c.drawCircle(Offset.zero, 2.6, stroke(const Color(0xFFFFFFFF), 1.1));
        circle(c, 0, 0, 1.2, const Color(0xFFFF9A55), outline: 0);
      case PropKind.hydrant:
        circle(c, 0, 0, 4.6, const Color(0xFFD8343C));
        rrect(c, -6, -1.3, 12, 2.6, 1.2, const Color(0xFFB0222C), outline: 0.6);
        circle(c, 0, 0, 2.6, const Color(0xFFF0484F), outline: 0.5);
        shine(c, -1.2, -1.4, 2.4, 1.4);
      case PropKind.trash:
        circle(c, 0, 0, 5, const Color(0xFF4F9A5A));
        circle(c, 0, 0, 3.8, const Color(0xFF3E7F49), outline: 0);
        rrect(c, -1.8, -0.8, 3.6, 1.6, 0.8, const Color(0xFF2C5E36), outline: 0);
        shine(c, -1.8, -2.4, 3, 1.4);
      case PropKind.mailbox:
        rrect(c, -0.8, -1, 1.6, 6, 0.6, const Color(0xFF5A4A3A), outline: 0.5);
        rrect(c, -4.6, -5.4, 9.2, 6.2, 3, const Color(0xFF3F6FD8));
        rrect(c, 3.6, -7.4, 1.2, 4, 0.4, const Color(0xFFE8504A), outline: 0.4);
        shine(c, -1.6, -3.8, 4, 1.4);
      case PropKind.pumpkin:
        oval(c, 0, 0.5, 10.6, 8.6, const Color(0xFFFF8A2A));
        oval(c, -2.4, 0.5, 3.6, 8, const Color(0xFFF07A1E), outline: 0.4);
        oval(c, 2.4, 0.5, 3.6, 8, const Color(0xFFF07A1E), outline: 0.4);
        rrect(c, -0.8, -5, 1.6, 2.8, 0.6, const Color(0xFF4F7A2A), outline: 0.4);
        shine(c, -2.6, -1.6, 3, 1.6);
      case PropKind.flowers:
        final petal = [const Color(0xFFFF6A9A), const Color(0xFFFFD35C), const Color(0xFFB06BFF)][v];
        oval(c, 0, 0, 14, 11, const Color(0xFF4FA84A));
        final rng = Random(v + 3);
        for (var i = 0; i < 7; i++) {
          final x = (rng.nextDouble() - 0.5) * 9, y = (rng.nextDouble() - 0.5) * 6;
          for (var p = 0; p < 5; p++) {
            final a = p * pi * 2 / 5;
            circle(c, x + cos(a) * 1.1, y + sin(a) * 1.1, 0.9, petal, outline: 0);
          }
          circle(c, x, y, 0.6, const Color(0xFFFFF2A0), outline: 0);
        }
      case PropKind.crate:
        rrect(c, -6, -6, 12, 12, 1.2, const Color(0xFFC98B4A));
        c.drawRect(const Rect.fromLTWH(-5, -5, 10, 10), stroke(const Color(0xFF9A6230), 0.8));
        c.drawLine(const Offset(-5, -5), const Offset(5, 5), stroke(const Color(0xFF9A6230), 1.2));
        c.drawLine(const Offset(5, -5), const Offset(-5, 5), stroke(const Color(0xFF9A6230), 1.2));
      case PropKind.lamp:
        c.drawCircle(
          Offset.zero,
          7,
          Paint()..shader = ui.Gradient.radial(Offset.zero, 7, const [Color(0x88FFF1A8), Color(0x00FFF1A8)]),
        );
        circle(c, 0, 0, 3.4, const Color(0xFF4A4F5E));
        circle(c, 0, 0, 2.1, const Color(0xFFFFF1A8), outline: 0);
      case PropKind.bench:
        rrect(c, -10, -4.6, 20, 9.2, 1.6, const Color(0xFF6A4A2E));
        for (var i = 0; i < 3; i++) {
          rrect(c, -9.2, -3.8 + i * 2.8, 18.4, 2.1, 0.8, const Color(0xFFC98B4A), outline: 0.35);
        }
      case PropKind.bush:
        _blobs(c, const Color(0xFF3F9A48), const Color(0xFF5BC062), 9, 5, v + 11);
      case PropKind.rock:
        final p = Path()
          ..moveTo(-8.5, 2)
          ..lineTo(-6, -5.5)
          ..lineTo(1, -8)
          ..lineTo(8, -3)
          ..lineTo(8.5, 4)
          ..lineTo(2, 7.5)
          ..lineTo(-5.5, 6.5)
          ..close();
        c.drawPath(p, fill(const Color(0xFF9AA0AE)));
        c.drawPath(p, stroke(ink.withValues(alpha: 0.55), 0.9));
        c.drawPath(
          Path()
            ..moveTo(-6, -5.5)
            ..lineTo(1, -8)
            ..lineTo(3, -2)
            ..lineTo(-4, 0)
            ..close(),
          fill(const Color(0xFFC0C6D2)),
        );
      case PropKind.snowman:
        circle(c, 0, 3, 7.4, const Color(0xFFFFFFFF));
        circle(c, 0, -4, 5, const Color(0xFFF6FAFF));
        rrect(c, -4.4, -9.6, 8.8, 2, 1, const Color(0xFF2B2B3A), outline: 0.4);
        rrect(c, -2.8, -13, 5.6, 4, 0.8, const Color(0xFF2B2B3A), outline: 0.4);
        circle(c, -1.5, -4.4, 0.7, ink, outline: 0);
        circle(c, 1.5, -4.4, 0.7, ink, outline: 0);
        c.drawPath(
          Path()
            ..moveTo(0, -3.4)
            ..lineTo(4, -2.6)
            ..lineTo(0, -2.2)
            ..close(),
          fill(const Color(0xFFFF8A2A)),
        );
        rrect(c, -5, -0.8, 10, 2.2, 1.1, const Color(0xFFE23C4A), outline: 0.4);
      case PropKind.surfboard:
        final col = [const Color(0xFFFF6A5A), const Color(0xFF28C8D8), const Color(0xFFFFD23C)][v];
        c.save();
        c.rotate(0.6);
        oval(c, 0, 0, 7, 22, col);
        c.drawLine(const Offset(0, -10), const Offset(0, 10), stroke(const Color(0xFFFFFFFF), 1.2));
        shine(c, -1.2, -5, 2, 6);
        c.restore();
      case PropKind.sled:
        rrect(c, -9, -4.6, 18, 9.2, 3, const Color(0xFFE23C4A));
        c.drawLine(const Offset(-8, -5.6), const Offset(9, -5.6), stroke(const Color(0xFF9AA0AE), 1.2));
        c.drawLine(const Offset(-8, 5.6), const Offset(9, 5.6), stroke(const Color(0xFF9AA0AE), 1.2));
        shine(c, -2, -2, 8, 2);
      case PropKind.hay:
        circle(c, 0, 0, 10.4, const Color(0xFFE8C45A));
        for (var r = 2.5; r < 10; r += 2.6) {
          c.drawCircle(Offset.zero, r, stroke(const Color(0xFFC9A03A), 0.9));
        }
        shine(c, -3, -4, 6, 3, 0.3);
      case PropKind.umbrella:
        final col = [const Color(0xFFE8504A), const Color(0xFF3F8EE8), const Color(0xFFFFC93C)][v];
        for (var i = 0; i < 8; i++) {
          final a0 = i * pi / 4;
          c.drawPath(
            Path()
              ..moveTo(0, 0)
              ..arcTo(Rect.fromCircle(center: Offset.zero, radius: 13), a0, pi / 4, false)
              ..close(),
            fill(i.isEven ? col : const Color(0xFFFFFFFF)),
          );
        }
        c.drawCircle(Offset.zero, 13, stroke(ink.withValues(alpha: 0.55), 0.9));
        circle(c, 0, 0, 1.6, darken(col, 0.3), outline: 0);
        shine(c, -4, -5, 8, 4, 0.3);
      case PropKind.sandcastle:
        rrect(c, -9, -5, 18, 12, 1.2, const Color(0xFFE6C27A));
        for (final x in [-9.0, 5.0]) {
          rrect(c, x, -9, 4.6, 16, 1, const Color(0xFFD8B066));
          for (var i = 0; i < 2; i++) {
            c.drawRect(Rect.fromLTWH(x + i * 2.6, -10.2, 1.8, 1.4), fill(const Color(0xFFD8B066)));
          }
        }
        rrect(c, -2, 1, 4, 6, 2, const Color(0xFF9A7A48), outline: 0.4);
        c.drawLine(const Offset(0, -5), const Offset(0, -12), stroke(ink, 0.6));
        c.drawPath(
          Path()
            ..moveTo(0, -12)
            ..lineTo(4, -10.8)
            ..lineTo(0, -9.6)
            ..close(),
          fill(const Color(0xFFE8504A)),
        );
      case PropKind.cow:
        rrect(c, -9, -5, 16, 10, 5, const Color(0xFFFFFFFF));
        circle(c, -4, -1, 2.6, const Color(0xFF2B2B35), outline: 0);
        circle(c, 2.5, 2, 2.2, const Color(0xFF2B2B35), outline: 0);
        circle(c, 3.5, -2.8, 1.4, const Color(0xFF2B2B35), outline: 0);
        rrect(c, 6, -4, 7, 8, 3.4, const Color(0xFFFFFFFF));
        rrect(c, 10.2, -2.6, 3, 5.2, 1.6, const Color(0xFFFFB0B8), outline: 0.4);
        circle(c, 8, -1.6, 0.6, ink, outline: 0);
        circle(c, 8, 1.6, 0.6, ink, outline: 0);
        oval(c, 6.6, -4.8, 2.2, 1.4, const Color(0xFFD9D0C0), outline: 0.3);
        oval(c, 6.6, 4.8, 2.2, 1.4, const Color(0xFFD9D0C0), outline: 0.3);
      case PropKind.tree:
        _trunk(c, 14);
        _blobs(c, const Color(0xFF3E9A45), const Color(0xFF63C35A), 15.5, 6, v + 1, highlight: true);
      case PropKind.pine:
        _trunk(c, 13);
        for (var layer = 0; layer < 3; layer++) {
          final r = 15.5 - layer * 4.6;
          final path = Path();
          for (var i = 0; i < 16; i++) {
            final a = -pi / 2 + i * pi / 8 + layer * 0.2;
            final rr = i.isEven ? r : r * 0.72;
            i == 0 ? path.moveTo(cos(a) * rr, sin(a) * rr) : path.lineTo(cos(a) * rr, sin(a) * rr);
          }
          path.close();
          final col = Color.lerp(const Color(0xFF2E7A4A), const Color(0xFF55B070), layer / 2)!;
          c.drawPath(path, fill(col));
          c.drawPath(path, stroke(ink.withValues(alpha: 0.4), 0.8));
        }
        circle(c, 0, 0, 2.6, const Color(0xFFF6FAFF), outline: 0);
      case PropKind.palm:
        circle(c, 0, 0, 3, const Color(0xFF9A6A3A));
        for (var i = 0; i < 7; i++) {
          final a = i * pi * 2 / 7 + 0.3;
          c.save();
          c.rotate(a);
          final leaf = Path()
            ..moveTo(0, 0)
            ..quadraticBezierTo(8, -4.5, 16.5, 0)
            ..quadraticBezierTo(8, 4.5, 0, 0)
            ..close();
          c.drawPath(leaf, fill(i.isEven ? const Color(0xFF3FA84A) : const Color(0xFF5BC062)));
          c.drawPath(leaf, stroke(ink.withValues(alpha: 0.45), 0.7));
          c.drawLine(Offset.zero, const Offset(15, 0), stroke(const Color(0xFF2E7A3A), 0.5));
          c.restore();
        }
        circle(c, 1.8, 1.2, 1.6, const Color(0xFF7A4A22), outline: 0.4);
        circle(c, -1.4, 1.8, 1.6, const Color(0xFF7A4A22), outline: 0.4);
      case PropKind.car:
        _car(c, carColors[v]);
      case PropKind.taxi:
        _car(c, const Color(0xFFFFC93C));
        rrect(c, -2.5, -2.4, 5, 4.8, 1, const Color(0xFFFFFFFF), outline: 0.5);
        c.drawRect(const Rect.fromLTWH(-9, -6.6, 18, 1), fill(const Color(0xFF2B2B35)));
      case PropKind.kiosk:
        final col = awnings[v];
        rrect(c, -18, -12, 36, 22, 2, const Color(0xFFF2E6D0));
        for (var i = 0; i < 6; i++) {
          c.drawRect(Rect.fromLTWH(-18 + i * 6, -16, 6, 12), fill(i.isEven ? col : const Color(0xFFFFFFFF)));
        }
        c.drawRect(const Rect.fromLTWH(-18, -16, 36, 12), stroke(ink.withValues(alpha: 0.55), 0.9));
        for (var i = 0; i < 6; i++) {
          c.drawArc(Rect.fromLTWH(-18 + i * 6, -7, 6, 4), 0, pi, true, fill(i.isEven ? col : const Color(0xFFFFFFFF)));
        }
        rrect(c, -14, 2, 28, 6, 1, const Color(0xFFC98B4A), outline: 0.6);
        for (var i = 0; i < 5; i++) {
          circle(
            c,
            -11 + i * 5.5,
            5,
            1.6,
            [const Color(0xFFFF6A5A), const Color(0xFFFFD23C), const Color(0xFF7AE05A)][i % 3],
            outline: 0.3,
          );
        }
      case PropKind.tractor:
        rrect(c, -14, -11, 9, 5, 1.2, const Color(0xFF2B2B35));
        rrect(c, -14, 6, 9, 5, 1.2, const Color(0xFF2B2B35));
        rrect(c, 6, -9, 6, 3.4, 1, const Color(0xFF2B2B35));
        rrect(c, 6, 5.6, 6, 3.4, 1, const Color(0xFF2B2B35));
        rrect(c, -12, -7, 26, 14, 3, const Color(0xFF4CAF50));
        rrect(c, -12, -6, 11, 12, 2, const Color(0xFF3A3F4A));
        shine(c, 4, -3, 12, 3);
        circle(c, 11, -4.5, 1.2, const Color(0xFFFFF2A0), outline: 0);
        circle(c, 11, 4.5, 1.2, const Color(0xFFFFF2A0), outline: 0);
      case PropKind.bus:
        rrect(c, -31, -12, 62, 24, 4, const Color(0xFFFFB42A));
        rrect(c, -28, -10, 56, 20, 3, const Color(0xFFFFC94A), outline: 0);
        for (var i = 0; i < 6; i++) {
          rrect(c, -24 + i * 8.5, -10.2, 6, 2.4, 0.8, const Color(0xFF3A4A66), outline: 0);
          rrect(c, -24 + i * 8.5, 7.8, 6, 2.4, 0.8, const Color(0xFF3A4A66), outline: 0);
        }
        rrect(c, 26, -9, 4, 18, 1.2, const Color(0xFF3A4A66), outline: 0);
        circle(c, 30, -8.5, 1.4, const Color(0xFFFFF2A0), outline: 0);
        circle(c, 30, 8.5, 1.4, const Color(0xFFFFF2A0), outline: 0);
        rrect(c, -18, -4, 20, 8, 1.2, const Color(0xFFE09A1B), outline: 0);
      case PropKind.fountain:
        circle(c, 0, 0, 29, const Color(0xFFD9D4CB));
        circle(c, 0, 0, 24, const Color(0xFF5CC6E8), outline: 0.6);
        for (var r = 8.0; r < 22; r += 6) {
          c.drawCircle(Offset.zero, r, stroke(const Color(0x66FFFFFF), 1));
        }
        circle(c, 0, 0, 7, const Color(0xFFC9C3B8));
        circle(c, 0, 0, 4, const Color(0xFF8FE3F5), outline: 0);
        shine(c, -8, -10, 12, 5, 0.4);
      case PropKind.hut:
        final col = [const Color(0xFFFF6A5A), const Color(0xFF3FA0E8), const Color(0xFF4CC46B)][v];
        _building(c, 44, 30, 12, const Color(0xFFFFF2DA), (c, w, h) {
          for (var i = 0; i < 6; i++) {
            c.drawRect(
              Rect.fromLTWH(-w / 2 + i * w / 6, -h / 2, w / 6, h),
              fill(i.isEven ? col : const Color(0xFFFFFFFF)),
            );
          }
          c.drawLine(Offset(-w / 2, 0), Offset(w / 2, 0), stroke(darken(col, 0.3), 1.2));
        });
      case PropKind.silo:
        rrect(c, -18, 6, 36, 16, 3, const Color(0xFFB9C0CC));
        for (var x = -14.0; x < 16; x += 7) {
          c.drawLine(Offset(x, 7), Offset(x, 21), stroke(const Color(0xFF8A92A0), 0.8));
        }
        circle(c, 0, 0, 18, const Color(0xFFC9D0DA));
        for (var r = 5.0; r < 18; r += 5) {
          c.drawCircle(Offset.zero, r, stroke(const Color(0xFF9AA2B0), 0.8));
        }
        circle(c, 0, 0, 3, const Color(0xFFE8504A));
        shine(c, -6, -7, 10, 5, 0.4);
      case PropKind.house:
        final roof = roofColors[v];
        _building(c, 64, 46, 20, const Color(0xFFFFF2DA), (c, w, h) {
          c.drawRect(Rect.fromLTWH(-w / 2, -h / 2, w, h / 2), fill(lighten(roof, 0.12)));
          c.drawRect(Rect.fromLTWH(-w / 2, 0, w, h / 2), fill(darken(roof, 0.12)));
          for (var y = -h / 2 + 5; y < h / 2; y += 5) {
            c.drawLine(Offset(-w / 2, y), Offset(w / 2, y), stroke(darken(roof, 0.25).withValues(alpha: 0.35), 0.6));
          }
          c.drawLine(Offset(-w / 2, 0), Offset(w / 2, 0), stroke(darken(roof, 0.35), 1.6));
          rrect(c, w * 0.18, -h * 0.42, 7, 9, 1, const Color(0xFFB5503A), outline: 0.6);
        }, door: true);
      case PropKind.cabin:
        _building(
          c,
          64,
          46,
          20,
          const Color(0xFFA0683A),
          (c, w, h) {
            c.drawRect(Rect.fromLTWH(-w / 2, -h / 2, w, h), fill(const Color(0xFF7A4A2A)));
            c.drawRect(Rect.fromLTWH(-w / 2 + 2, -h / 2 + 2, w - 4, h * 0.5), fill(const Color(0xFFF6FAFF)));
            c.drawRect(Rect.fromLTWH(-w / 2 + 2, 0, w - 4, h * 0.34), fill(const Color(0xFFE4EEF8)));
            c.drawLine(Offset(-w / 2, 0), Offset(w / 2, 0), stroke(const Color(0xFFB9C8DA), 1.4));
            rrect(c, -w * 0.3, -h * 0.4, 7, 9, 1, const Color(0xFF8A5A3A), outline: 0.6);
          },
          door: true,
          logs: true,
        );
      case PropKind.shop:
        final col = awnings[v];
        _building(c, 76, 52, 24, const Color(0xFFF2E6D0), (c, w, h) {
          c.drawRect(Rect.fromLTWH(-w / 2, -h / 2, w, h), fill(const Color(0xFFB9C0CC)));
          c.drawRect(Rect.fromLTWH(-w / 2 + 3, -h / 2 + 3, w - 6, h - 6), fill(const Color(0xFFCFD5DE)));
          rrect(c, -w * 0.3, -h * 0.28, 12, 9, 1.2, const Color(0xFF8A92A0), outline: 0.6);
          rrect(c, w * 0.08, -h * 0.1, 16, 10, 1.2, const Color(0xFF8A92A0), outline: 0.6);
          circle(c, w * 0.08 + 8, -h * 0.1 + 5, 3.2, const Color(0xFF6A7280), outline: 0.5);
        }, awning: col);
      case PropKind.barn:
        _building(c, 92, 62, 26, const Color(0xFFC8423A), (c, w, h) {
          c.drawRect(Rect.fromLTWH(-w / 2, -h / 2, w, h / 2), fill(const Color(0xFF9A3A34)));
          c.drawRect(Rect.fromLTWH(-w / 2, 0, w, h / 2), fill(const Color(0xFF7E2E2A)));
          c.drawLine(Offset(-w / 2, 0), Offset(w / 2, 0), stroke(const Color(0xFF5A1E1C), 1.8));
          for (var x = -w / 2 + 8; x < w / 2; x += 8) {
            c.drawLine(Offset(x, -h / 2), Offset(x, h / 2), stroke(const Color(0x33000000), 0.7));
          }
        }, barnDoor: true);
      case PropKind.hotel:
        final col = v == 0 ? const Color(0xFFFFB0A0) : const Color(0xFF9AD8E8);
        _building(c, 104, 70, 42, col, (c, w, h) {
          c.drawRect(Rect.fromLTWH(-w / 2, -h / 2, w, h), fill(const Color(0xFFE8E4DC)));
          c.drawRect(Rect.fromLTWH(-w / 2 + 3, -h / 2 + 3, w - 6, h - 6), fill(const Color(0xFFF4F0E8)));
          circle(c, -w * 0.22, 0, 12, const Color(0xFF6FD6F0));
          rrect(c, w * 0.08, -h * 0.3, 26, 12, 2, const Color(0xFF9AA2B0), outline: 0.6);
          for (var i = 0; i < 3; i++) {
            circle(c, w * 0.12 + i * 8, h * 0.22, 3, const Color(0xFFFF8A6A), outline: 0.4);
          }
        }, windows: true);
      case PropKind.tower:
        final col = v == 0 ? const Color(0xFF7FB6E8) : const Color(0xFFB0A0E0);
        _building(c, 116, 96, 50, col, (c, w, h) {
          c.drawRect(Rect.fromLTWH(-w / 2, -h / 2, w, h), fill(const Color(0xFF6A7282)));
          c.drawRect(Rect.fromLTWH(-w / 2 + 4, -h / 2 + 4, w - 8, h - 8), fill(const Color(0xFF8A92A2)));
          c.drawCircle(Offset(-w * 0.18, 0), 16, fill(const Color(0xFF5A6272)));
          c.drawCircle(Offset(-w * 0.18, 0), 16, stroke(const Color(0xFFFFD35C), 1.4));
          final tp = TextPainter(
            text: const TextSpan(
              text: 'H',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFFFFFFF)),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(c, Offset(-w * 0.18 - tp.width / 2, -tp.height / 2));
          for (var i = 0; i < 3; i++) {
            rrect(c, w * 0.12, -h * 0.32 + i * 13, 22, 9, 1.2, const Color(0xFFB9C0CC), outline: 0.6);
          }
        }, windows: true);
    }
  }

  static void _trunk(Canvas c, double y) {
    rrect(c, -2.6, 2, 5.2, y - 2, 1.5, const Color(0xFF8A5A32));
  }

  /// A bushy canopy: a ring of overlapping circles.
  static void _blobs(Canvas c, Color dark, Color light, double r, int n, int seed, {bool highlight = false}) {
    final rng = Random(seed);
    final parts = <(double, double, double)>[];
    for (var i = 0; i < n; i++) {
      final a = i * pi * 2 / n + rng.nextDouble() * 0.4;
      final d = r * 0.42;
      parts.add((cos(a) * d, sin(a) * d, r * (0.5 + rng.nextDouble() * 0.12)));
    }
    parts.add((0, 0, r * 0.62));
    final outline = Path();
    for (final (x, y, rr) in parts) {
      outline.addOval(Rect.fromCircle(center: Offset(x, y), radius: rr));
    }
    c.drawPath(outline, stroke(ink.withValues(alpha: 0.6), 1.8));
    for (final (x, y, rr) in parts) {
      c.drawCircle(Offset(x, y), rr, fill(dark));
    }
    for (final (x, y, rr) in parts) {
      c.drawCircle(Offset(x - rr * 0.2, y - rr * 0.25), rr * 0.72, fill(light));
    }
    if (highlight) shine(c, -r * 0.35, -r * 0.45, r * 0.6, r * 0.3, 0.35);
  }

  static void _car(Canvas c, Color col) {
    // Facing +x.
    rrect(c, -18, -9.5, 36, 19, 6, col);
    circle(c, -11, -9.6, 2.6, const Color(0xFF2B2B35), outline: 0);
    circle(c, 11, -9.6, 2.6, const Color(0xFF2B2B35), outline: 0);
    circle(c, -11, 9.6, 2.6, const Color(0xFF2B2B35), outline: 0);
    circle(c, 11, 9.6, 2.6, const Color(0xFF2B2B35), outline: 0);
    rrect(c, -18, -9.5, 36, 19, 6, col, outline: 0.9);
    rrect(c, -8, -7.6, 18, 15.2, 4, darken(col, 0.12), outline: 0);
    rrect(c, 5, -7, 6, 14, 2, const Color(0xFF3A4A66), outline: 0);
    rrect(c, -10.5, -6.6, 4, 13.2, 1.6, const Color(0xFF3A4A66), outline: 0);
    rrect(c, -5.5, -6.6, 10, 13.2, 3, lighten(col, 0.12), outline: 0);
    circle(c, 17, -6.2, 1.5, const Color(0xFFFFF6C0), outline: 0);
    circle(c, 17, 6.2, 1.5, const Color(0xFFFFF6C0), outline: 0);
    circle(c, -17.4, -6.4, 1.2, const Color(0xFFE8504A), outline: 0);
    circle(c, -17.4, 6.4, 1.2, const Color(0xFFE8504A), outline: 0);
    shine(c, -4, -4.6, 12, 2.6);
  }

  /// A building with a visible front wall (3/4 view): roof on top, the wall
  /// below it. [roof] paints the roof in a box of `w` x `h` centred at (0,0),
  /// which is shifted up by half the wall height.
  static void _building(
    Canvas c,
    double w,
    double h,
    double wallH,
    Color wall,
    void Function(Canvas c, double w, double h) roof, {
    bool door = false,
    bool logs = false,
    bool barnDoor = false,
    bool windows = false,
    Color? awning,
  }) {
    final top = -(h + wallH) / 2;
    // Wall.
    final wallRect = Rect.fromLTWH(-w / 2 + 2, top + h - 4, w - 4, wallH + 4);
    c.drawRRect(RRect.fromRectAndRadius(wallRect, const Radius.circular(2)), fill(wall));
    if (logs) {
      for (var y = wallRect.top + 3; y < wallRect.bottom; y += 3.2) {
        c.drawLine(Offset(wallRect.left, y), Offset(wallRect.right, y), stroke(const Color(0x33000000), 0.7));
      }
    }
    c.drawRect(Rect.fromLTWH(wallRect.left, wallRect.bottom - 3, wallRect.width, 3), fill(const Color(0x22000000)));
    if (windows) {
      final rows = (wallH / 8).floor();
      final cols = (w / 10).floor();
      for (var j = 0; j < rows; j++) {
        for (var i = 0; i < cols; i++) {
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                wallRect.left + 3 + i * (wallRect.width - 6) / cols,
                wallRect.top + 6 + j * 8,
                (wallRect.width - 6) / cols - 3,
                5,
              ),
              const Radius.circular(1),
            ),
            fill(const Color(0xFF3A5A86)),
          );
        }
      }
    } else {
      // Two windows.
      for (final fx in [-0.3, 0.3]) {
        final r = Rect.fromCenter(center: Offset(w * fx, wallRect.center.dy + 1), width: 9, height: wallH * 0.45);
        c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(1.5)), fill(const Color(0xFF6FB6E8)));
        c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(1.5)), stroke(const Color(0xFFFFFFFF), 1));
      }
    }
    if (door) {
      rrect(c, -4.5, wallRect.bottom - wallH * 0.7, 9, wallH * 0.7, 1.5, const Color(0xFF8A4A2A), outline: 0.6);
    }
    if (barnDoor) {
      final d = Rect.fromLTWH(-12, wallRect.bottom - wallH * 0.85, 24, wallH * 0.85);
      c.drawRect(d, fill(const Color(0xFFFFF2DA)));
      c.drawRect(d.deflate(2), fill(const Color(0xFFB0342E)));
      c.drawLine(d.deflate(2).topLeft, d.deflate(2).bottomRight, stroke(const Color(0xFFFFF2DA), 1.6));
      c.drawLine(d.deflate(2).topRight, d.deflate(2).bottomLeft, stroke(const Color(0xFFFFF2DA), 1.6));
    }
    if (awning != null) {
      final n = 8;
      for (var i = 0; i < n; i++) {
        c.drawRect(
          Rect.fromLTWH(wallRect.left + i * wallRect.width / n, wallRect.top + 3, wallRect.width / n, 6),
          fill(i.isEven ? awning : const Color(0xFFFFFFFF)),
        );
      }
      final r = Rect.fromLTWH(wallRect.left + 6, wallRect.top + 11, wallRect.width - 12, wallH - 14);
      c.drawRect(r, fill(const Color(0xFF8FD0F0)));
      c.drawRect(r, stroke(const Color(0xFFFFFFFF), 1));
    }
    c.drawRRect(RRect.fromRectAndRadius(wallRect, const Radius.circular(2)), stroke(ink.withValues(alpha: 0.55), 0.9));

    // Roof.
    c.save();
    c.translate(0, top + h / 2);
    final rr = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      const Radius.circular(3),
    );
    c.save();
    c.clipRRect(rr);
    roof(c, w, h);
    c.restore();
    c.drawRRect(rr, stroke(ink.withValues(alpha: 0.6), 1.1));
    c.restore();
  }
}
