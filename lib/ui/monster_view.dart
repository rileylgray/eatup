import 'dart:math';

import 'package:flutter/material.dart';

import '../game/art/monster_art.dart';
import '../game/skins.dart';

/// A monster in the menus: idles, blinks, looks around and bounces.
class MonsterView extends StatefulWidget {
  const MonsterView({super.key, required this.skin, required this.size, this.animate = true, this.locked = false});

  final SkinDef skin;

  /// Box side in logical px; the body fills about 60% of it.
  final double size;
  final bool animate;

  /// Drawn as a dark silhouette.
  final bool locked;

  @override
  State<MonsterView> createState() => _MonsterViewState();
}

class _MonsterViewState extends State<MonsterView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  final double _seed = Random().nextDouble() * 10;

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(MonsterView old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) _c.repeat();
    if (!widget.animate && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(painter: _MonsterPainter(widget.skin, _c.value * 6 + _seed, widget.animate)),
      ),
    );
    if (!widget.locked) return RepaintBoundary(child: child);
    return RepaintBoundary(
      child: ColorFiltered(
        colorFilter: const ColorFilter.mode(Color(0xFF1A1030), BlendMode.srcATop),
        child: Opacity(opacity: 0.8, child: child),
      ),
    );
  }
}

class _MonsterPainter extends CustomPainter {
  _MonsterPainter(this.skin, this.t, this.animate);
  final SkinDef skin;
  final double t;
  final bool animate;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide * 0.3;
    final bounce = animate ? (sin(t * 3).abs()) * r * 0.08 : 0.0;
    // Look around now and then.
    final look = animate ? sin(t * 0.9) : 0.0;
    final blinkPhase = (t * 0.7) % 1;
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.56 - bounce);
    MonsterArt.paint(
      canvas,
      skin,
      r,
      MonsterPose(
        wobble: t,
        fx: look * 0.8,
        fy: 0.6,
        blink: animate && blinkPhase > 0.96 ? -1 : 1,
        squash: animate ? max(0, 1 - (sin(t * 3).abs()) * 6) * 0.5 : 0,
        chomp: animate ? max(0, sin(t * 1.3) - 0.85) * 5 : 0,
      ),
      time: t,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MonsterPainter old) => old.t != t || old.skin != skin;
}
