import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../core/sound.dart';
import 'arena.dart';
import 'art/atlas.dart';
import 'art/ground_art.dart';
import 'art/monster_art.dart';
import 'entities.dart';
import 'growth.dart';
import 'maps.dart';
import 'props.dart';
import 'skins.dart';
import 'upgrades.dart';

/// Moments the UI may want to explain with a toast.
enum Hint { move, tierMedium, tierLarge, tierBuilding, avoid, speed, magnet, frenzy }

/// Text the canvas draws itself, in the player's language.
class GameLabels {
  const GameLabels({
    this.you = 'You',
    this.yum = 'Yum!',
    this.gulp = 'Gulp!',
    this.huge = 'HUGE!',
    this.combo = 'Combo x{n}',
  });

  final String you, yum, gulp, huge, combo;
}

class Standing {
  const Standing(this.name, this.radius, this.color, {required this.isPlayer, required this.alive});
  final String name;
  final double radius;
  final Color color;
  final bool isPlayer, alive;
}

/// What the Flutter HUD shows, refreshed a few times a second.
class HudState {
  const HudState({
    this.timeLeft = 0,
    this.radius = Growth.startRadius,
    this.rank = 1,
    this.standings = const [],
    this.speedT = 0,
    this.magnetT = 0,
    this.frenzyT = 0,
    this.countdown = 0,
    this.phase = RoundPhase.countdown,
  });

  final double timeLeft, radius;
  final int rank;
  final List<Standing> standings;
  final double speedT, magnetT, frenzyT;
  final double countdown;
  final RoundPhase phase;
}

/// The town seen from above, following the player's monster. The rules live
/// in [Arena]; this class feeds it touch input and draws it.
///
/// Drawing is built to scale to big towns: the ground is a recorded picture,
/// and every prop, person and shadow on screen goes out in a few batched
/// `drawRawAtlas` calls from one texture ([Atlas]).
class EatGame extends FlameGame {
  EatGame();

  static Atlas? _atlas;
  static Future<Atlas>? _atlasLoading;

  Arena? arena;
  ui.Picture? _ground;
  GameLabels labels = const GameLabels();

  final ValueNotifier<HudState> hud = ValueNotifier(const HudState());

  void Function(RoundResult r)? onRoundEnd;
  void Function(String eaterName)? onPlayerEaten;
  void Function(Hint h)? onHint;
  void Function(String victimName)? onAteRival;

  // Camera.
  double _cx = 1000, _cy = 1000, _zoom = 1;
  double _shake = 0;
  bool _snapCamera = true;
  double _time = 0;
  double _hudTimer = 0;
  bool _warned = false;

  // Joystick (screen coordinates).
  Offset? _joyOrigin;
  Offset _joyPos = Offset.zero;
  static const double _joyRadius = 56;

  final List<_Particle> _particles = [];
  final List<_Popup> _popups = [];
  final _Batch _batch = _Batch();
  final Paint _atlasPaint = Paint()..filterQuality = FilterQuality.low;
  final Map<String, TextPainter> _tagCache = {};
  final Random _rng = Random();

  bool get inRound => arena != null && !arena!.demo;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (_atlas == null) await loadAtlas();
  }

  /// Paints the sprite atlas once per app run.
  static Future<Atlas> loadAtlas() => _atlasLoading ??= Atlas.build().then((a) => _atlas = a);

  // Rounds ---------------------------------------------------------------------

  /// The attract mode behind the menus: rival monsters roaming the town.
  void showMenu({required MapDef map, required SkinDef skin}) {
    _setArena(
      Arena(
        map: map,
        seed: _rng.nextInt(1 << 30),
        loadout: const Loadout(),
        playerSkin: skin,
        playerName: '',
        demo: true,
      ),
    );
  }

  void startRound({
    required MapDef map,
    required SkinDef skin,
    required Loadout loadout,
    required bool tutorial,
    double? roundSeconds,
  }) {
    final a = Arena(
      map: map,
      seed: _rng.nextInt(1 << 30),
      loadout: loadout,
      playerSkin: skin,
      playerName: labels.you,
      tutorial: tutorial,
      roundSeconds: roundSeconds,
    );
    a
      ..onEat = _onEat
      ..onMonsterEaten = _onMonsterEaten
      ..onPowerUp = _onPowerUp
      ..onCombo = _onCombo
      ..onTierReached = (t) {
        onHint?.call(switch (t) {
          PropTier.medium => Hint.tierMedium,
          PropTier.large => Hint.tierLarge,
          _ => Hint.tierBuilding,
        });
      }
      ..onPlayerEaten = () {
        Sound.instance.fx(Sfx.eaten);
        _shake = 14;
        _joyOrigin = null;
        onPlayerEaten?.call(a.eatenBy ?? '');
      }
      ..onGo = () {
        Sound.instance.fx(Sfx.go);
        onHint?.call(Hint.move);
      }
      ..onRoundOver = () {
        Sound.instance.fx(Sfx.win);
        _joyOrigin = null;
        onRoundEnd?.call(a.result());
      };
    _warned = false;
    _setArena(a);
    _publishHud();
  }

  void _setArena(Arena a) {
    arena = a;
    _ground = GroundArt.record(a.layout);
    _particles.clear();
    _popups.clear();
    _joyOrigin = null;
    _snapCamera = true;
  }

  void revive() {
    arena?.revive();
    _publishHud();
  }

  /// The player declined a revive; the round ends where it stands.
  void giveUp() {
    final a = arena;
    if (a == null) return;
    a.giveUp();
    onRoundEnd?.call(a.result());
  }

  // Input ------------------------------------------------------------------------

  void pointerDown(Offset p) {
    if (!inRound) return;
    _joyOrigin = p;
    _joyPos = p;
    _applyJoy();
  }

  void pointerMove(Offset p) {
    if (_joyOrigin == null) return;
    // The base stays where the finger first landed; dragging past the rim
    // just holds full speed in that direction.
    _joyPos = p;
    _applyJoy();
  }

  void pointerUp() {
    _joyOrigin = null;
    _applyJoy();
  }

  void _applyJoy() {
    final a = arena;
    if (a == null) return;
    final o = _joyOrigin;
    if (o == null) {
      a.inputX = a.inputY = 0;
      return;
    }
    final d = _joyPos - o;
    final len = d.distance;
    if (len < 4) {
      a.inputX = a.inputY = 0;
      return;
    }
    final m = min(1.0, len / _joyRadius);
    a.inputX = d.dx / len * m;
    a.inputY = d.dy / len * m;
  }

  // Events -------------------------------------------------------------------------

  bool _onScreen(double x, double y, [double margin = 60]) {
    final hw = size.x / _zoom / 2 + margin, hh = size.y / _zoom / 2 + margin;
    return (x - _cx).abs() < hw && (y - _cy).abs() < hh;
  }

  void _onEat(Monster m, Food f) {
    final visible = _onScreen(f.x, f.y);
    if (visible) _burst(f.x, f.y, f.size, f is Person ? 5 : 8);
    if (!m.isPlayer) return;
    if (f is Prop) {
      switch (f.kind.tier) {
        case PropTier.tiny:
        case PropTier.small:
          Sound.instance.fx(Sfx.chomp, volume: 0.8);
        case PropTier.medium:
          Sound.instance.fx(Sfx.gulp);
          _popup(f.x, f.y, labels.yum, const Color(0xFFFFFFFF), 18);
        case PropTier.large:
          Sound.instance.fx(Sfx.big);
          _shake = max(_shake, 6);
          _popup(f.x, f.y, labels.gulp, const Color(0xFFFFE27A), 22);
        case PropTier.building:
          Sound.instance.fx(Sfx.big);
          _shake = max(_shake, 12);
          _popup(f.x, f.y, labels.huge, const Color(0xFFFF8A5A), 30);
          _burst(f.x, f.y, f.size, 22);
      }
    } else if (f is Person) {
      Sound.instance.fx(Sfx.chomp, volume: 0.65);
    }
  }

  void _onMonsterEaten(Monster eater, Monster victim) {
    if (_onScreen(victim.x, victim.y)) {
      _burst(victim.x, victim.y, victim.r, 26, color: victim.skin.body);
    }
    if (eater.isPlayer) {
      Sound.instance.fx(Sfx.big);
      _shake = max(_shake, 10);
      _popup(victim.x, victim.y, victim.name, victim.skin.body, 24);
      onAteRival?.call(victim.name);
    }
  }

  void _onPowerUp(Monster m, PowerKind k) {
    if (!m.isPlayer) return;
    Sound.instance.fx(Sfx.powerup);
    _burst(m.x, m.y, m.r, 16, color: PowerArt.colorOf(k));
    onHint?.call(switch (k) {
      PowerKind.speed => Hint.speed,
      PowerKind.magnet => Hint.magnet,
      PowerKind.frenzy => Hint.frenzy,
    });
  }

  void _onCombo(int n) {
    final a = arena!;
    Sound.instance.fx(Sfx.combo);
    _popup(a.player.x, a.player.y - a.player.r, labels.combo.replaceAll('{n}', '$n'), const Color(0xFFFFD35C), 24);
  }

  void _burst(double x, double y, double size, int n, {Color? color}) {
    const palette = [Color(0xFFFFD35C), Color(0xFFFF6A8A), Color(0xFF7AE05A), Color(0xFF4FC3F7), Color(0xFFFFFFFF)];
    for (var i = 0; i < n && _particles.length < 400; i++) {
      final a = _rng.nextDouble() * pi * 2;
      final s = (40 + _rng.nextDouble() * 90) * (0.6 + size / 30);
      _particles.add(
        _Particle(
          x,
          y,
          cos(a) * s,
          sin(a) * s,
          0.35 + _rng.nextDouble() * 0.35,
          color ?? palette[_rng.nextInt(palette.length)],
          (1.5 + _rng.nextDouble() * 2.5) * (0.7 + size / 25),
        ),
      );
    }
  }

  void _popup(double x, double y, String text, Color color, double fontSize) {
    if (_popups.length > 8) _popups.removeAt(0);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          fontVariations: const [FontVariation('wght', 700)],
          color: color,
          shadows: const [Shadow(color: Color(0xAA000000), offset: Offset(0, 2), blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _popups.add(_Popup(x, y, tp));
  }

  // Loop -----------------------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);
    final a = arena;
    if (a == null) return;
    _time += dt;
    a.update(dt);

    // Camera.
    final target = a.player;
    final short = min(size.x, size.y);
    if (short <= 0) return;
    final span = Growth.viewSpan(target.r) * (a.demo ? 1.35 : 1);
    final z = short / span;
    // Follow the monster, but don't show much beyond the edge of town.
    var tx = target.x, ty = target.y;
    final hw = size.x / z / 2 - 60, hh = size.y / z / 2 - 60;
    final bottom = a.map.sea ? a.height + 250 : a.height;
    tx = a.width > hw * 2 ? tx.clamp(hw, a.width - hw) : a.width / 2;
    ty = bottom > hh * 2 ? ty.clamp(hh, bottom - hh) : bottom / 2;
    if (_snapCamera) {
      _cx = tx;
      _cy = ty;
      _zoom = z;
      _snapCamera = false;
    } else {
      final k = min(1.0, dt * 5);
      _cx += (tx - _cx) * k;
      _cy += (ty - _cy) * k;
      _zoom += (z - _zoom) * min(1.0, dt * 2);
    }
    _shake = max(0, _shake - dt * 30);
    // People just off screen collide too, so nobody pops out of a wall as
    // the camera moves.
    a.view = (x: _cx, y: _cy, hw: size.x / _zoom / 2 + 150, hh: size.y / _zoom / 2 + 150);

    for (final p in _particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vx *= 1 - dt * 3;
      p.vy *= 1 - dt * 3;
      p.life -= dt;
    }
    _particles.removeWhere((p) => p.life <= 0);
    for (final p in _popups) {
      p.t += dt;
    }
    _popups.removeWhere((p) => p.t > 1.1);

    if (!a.demo) {
      // A friendly warning the first time something big comes close.
      if (!_warned && a.player.alive && a.phase == RoundPhase.playing) {
        for (final m in a.monsters) {
          if (m == a.player || !m.alive) continue;
          if (Growth.canEatMonster(m.r, a.player.r) &&
              (m.x - a.player.x).abs() + (m.y - a.player.y).abs() < m.r * 3 + 200) {
            _warned = true;
            onHint?.call(Hint.avoid);
            break;
          }
        }
      }
      _hudTimer -= dt;
      if (_hudTimer <= 0) {
        _hudTimer = 0.12;
        _publishHud();
      }
    }
  }

  void _publishHud() {
    final a = arena;
    if (a == null) return;
    final st = a.standings();
    hud.value = HudState(
      timeLeft: a.timeLeft,
      radius: a.player.r,
      rank: st.indexOf(a.player) + 1,
      standings: [for (final m in st) Standing(m.name, m.r, m.skin.body, isPlayer: m == a.player, alive: m.alive)],
      speedT: a.player.speedT,
      magnetT: a.player.magnetT,
      frenzyT: a.player.frenzyT,
      countdown: a.countdown,
      phase: a.phase,
    );
  }

  // Drawing ----------------------------------------------------------------------------

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final a = arena;
    final atlas = _atlas;
    final ground = _ground;
    final w = size.x, h = size.y;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = a?.map.ground.edge ?? const Color(0xFF2B1B4F));
    if (a == null || atlas == null || ground == null) return;

    final sx = _shake > 0 ? (_rng.nextDouble() - 0.5) * _shake : 0.0;
    final sy = _shake > 0 ? (_rng.nextDouble() - 0.5) * _shake : 0.0;
    final z = _zoom;
    canvas.save();
    canvas.translate(w / 2 + sx, h / 2 + sy);
    canvas.scale(z);
    canvas.translate(-_cx, -_cy);

    canvas.drawPicture(ground);
    if (a.map.sea) _drawSea(canvas, a);

    final view = Rect.fromCenter(center: Offset(_cx, _cy), width: w / z + 240, height: h / z + 240);
    final img = atlas.image;
    final style = a.map.people;

    // Visible things, gathered once.
    final props0 = <Prop>[], props1 = <Prop>[];
    for (final p in a.standingProps) {
      if (!view.inflate(p.size).contains(Offset(p.x, p.y))) continue;
      (p.kind.layer == 0 ? props0 : props1).add(p);
    }
    final people = <Person>[];
    for (final p in a.people) {
      if (p.alive && view.contains(Offset(p.x, p.y))) people.add(p);
    }
    people.sort((p, q) => p.y.compareTo(q.y));

    // Shadows.
    for (final p in props0) {
      _batch.add(atlas.shadow, p.x + p.size * 0.18, p.y + p.size * 0.28, scale: p.size * 1.15 / 19);
    }
    for (final p in props1) {
      _batch.add(atlas.shadow, p.x + p.size * 0.25, p.y + p.size * 0.35, scale: p.size * 1.1 / 19);
    }
    for (final p in people) {
      _batch.add(atlas.shadow, p.x, p.y + 8, scale: 0.3);
    }
    _batch.flush(canvas, img, _atlasPaint);

    for (final p in props0) {
      _batch.add(atlas.prop(p.kind, p.variant), p.x, p.y, angle: p.angle);
    }
    for (final p in people) {
      final moving = p.vx != 0 || p.vy != 0;
      final frame = p.panic > 0 && moving ? 2 : (moving ? p.phase.floor() % 2 : 0);
      // A little hop while running scared.
      final hop = frame == 2 ? -((p.phase * 2) % 1) * 2 : 0.0;
      _batch.add(atlas.person(style, p.variant, frame), p.x, p.y + hop);
    }
    for (final p in props1) {
      _batch.add(atlas.prop(p.kind, p.variant), p.x, p.y, angle: p.angle);
    }
    // Power-ups bob and pulse.
    for (final p in a.powerUps) {
      if (!view.contains(Offset(p.x, p.y))) continue;
      final blink = p.age > PowerUp.lifetime - 4 && (p.age * 6).floor().isEven;
      if (blink) continue;
      _batch.add(atlas.powerUps[p.kind]!, p.x, p.y + sin(_time * 4 + p.x) * 3, scale: 1 + 0.08 * sin(_time * 6));
    }
    // Things on their way down.
    for (final s in a.swallows) {
      final t = Curves.easeInCubic.transform(s.t.clamp(0, 1));
      final x = s.eater.x + s.dx * (1 - t), y = s.eater.y + s.dy * (1 - t);
      if (!view.contains(Offset(x, y))) continue;
      final f = s.food;
      final scale = 1 - t * 0.9;
      final spin = t * 3;
      if (f is Person) {
        _batch.add(atlas.person(style, f.variant, 2), x, y, scale: scale, angle: spin);
      } else if (f is Prop) {
        _batch.add(atlas.prop(f.kind, f.variant), x, y, scale: scale, angle: f.angle + spin * 0.5);
      }
    }
    _batch.flush(canvas, img, _atlasPaint);

    // Monsters, smallest first so the big ones loom over.
    final ms = [...a.monsters.where((m) => m.alive)]..sort((p, q) => p.area.compareTo(q.area));
    for (final m in ms) {
      final r = m.r;
      if (!view.inflate(r * 1.6).contains(Offset(m.x, m.y))) continue;
      if (m.shield > 0 && (m.shield * 8).floor().isOdd) continue;
      canvas.save();
      canvas.translate(m.x, m.y);
      if (m.frenzyT > 0 || m.speedT > 0 || m.magnetT > 0) _aura(canvas, m);
      MonsterArt.paint(
        canvas,
        m.skin,
        r,
        MonsterPose(
          wobble: m.wobble,
          chomp: m.chomp,
          fx: m.fx,
          fy: m.fy,
          blink: m.blink,
          squash: m.squash,
          shield: m.shield > 0,
          hungry: m.isPlayer && (m.vx.abs() + m.vy.abs()) > 20 ? 0.5 : 0.2,
        ),
        time: _time,
      );
      canvas.restore();
    }

    for (final p in _particles) {
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.size * (p.life / p.max).clamp(0.2, 1),
        Paint()..color = p.color.withValues(alpha: (p.life / p.max).clamp(0, 1)),
      );
    }
    canvas.restore();

    // Screen space: name tags, arrows, popups, joystick.
    Offset toScreen(double x, double y) => Offset((x - _cx) * z + w / 2 + sx, (y - _cy) * z + h / 2 + sy);
    final leader = ms.isEmpty ? null : ms.last;
    for (final m in ms) {
      final r = m.r;
      final s = toScreen(m.x, m.y - r * 1.25);
      if (s.dx < -80 || s.dx > w + 80 || s.dy < -40 || s.dy > h + 80) continue;
      if (a.demo) continue;
      _nameTag(canvas, s, m.name, isPlayer: m.isPlayer, leader: m == leader && ms.length > 1);
    }
    if (!a.demo && a.player.alive) _edgeArrows(canvas, a, toScreen, w, h);
    for (final p in _popups) {
      final s = toScreen(p.x, p.y);
      final t = p.t / 1.1;
      final scale = t < 0.15 ? Curves.easeOutBack.transform(t / 0.15) : 1.0;
      canvas.save();
      canvas.translate(s.dx, s.dy - 30 - t * 50);
      canvas.scale(scale);
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(255, 255, 255, t > 0.7 ? (1 - t) / 0.3 : 1));
      p.tp.paint(canvas, Offset(-p.tp.width / 2, -p.tp.height / 2));
      canvas.restore();
      canvas.restore();
    }
    final o = _joyOrigin;
    if (o != null) {
      canvas.drawCircle(o, _joyRadius, Paint()..color = const Color(0x33FFFFFF));
      canvas.drawCircle(
        o,
        _joyRadius,
        Paint()
          ..color = const Color(0x66FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      var d = _joyPos - o;
      if (d.distance > _joyRadius) d = d / d.distance * _joyRadius;
      canvas.drawCircle(o + d, 26, Paint()..color = const Color(0xAAFFFFFF));
      canvas.drawCircle(o + d, 20, Paint()..color = const Color(0xDDFFFFFF));
    }
  }

  void _aura(Canvas c, Monster m) {
    final r = m.r;
    final color = m.frenzyT > 0
        ? PowerArt.colorOf(PowerKind.frenzy)
        : m.magnetT > 0
        ? PowerArt.colorOf(PowerKind.magnet)
        : PowerArt.colorOf(PowerKind.speed);
    final pulse = 1.25 + 0.08 * sin(_time * 8);
    c.drawCircle(
      Offset.zero,
      r * pulse,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          r * pulse,
          [color.withValues(alpha: 0), color.withValues(alpha: 0.45)],
          const [0.6, 1],
        ),
    );
    if (m.magnetT > 0) {
      final reach = r * m.effectiveReach;
      c.drawCircle(
        Offset.zero,
        reach * (1 - (_time * 0.8) % 1 * 0.3),
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 / _zoom,
      );
    }
  }

  void _nameTag(Canvas c, Offset s, String name, {required bool isPlayer, required bool leader}) {
    final key = '$name$isPlayer';
    final tp = _tagCache[key] ??= TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontVariations: const [FontVariation('wght', 600)],
          color: isPlayer ? const Color(0xFF2B2240) : const Color(0xFFFFFFFF),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromCenter(center: s, width: tp.width + 14, height: tp.height + 4);
    c.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()..color = isPlayer ? const Color(0xFFFFD35C) : const Color(0x99201830),
    );
    tp.paint(c, Offset(rect.left + 7, rect.top + 2));
    if (leader) {
      final cx = rect.left - 10, cy = rect.center.dy;
      final crown = Path()
        ..moveTo(cx - 8, cy + 5)
        ..lineTo(cx - 9, cy - 5)
        ..lineTo(cx - 4, cy - 1)
        ..lineTo(cx, cy - 7)
        ..lineTo(cx + 4, cy - 1)
        ..lineTo(cx + 9, cy - 5)
        ..lineTo(cx + 8, cy + 5)
        ..close();
      c.drawPath(crown, Paint()..color = const Color(0xFFFFD35C));
      c.drawPath(
        crown,
        Paint()
          ..color = const Color(0xFF8A5A10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  /// Arrows at the screen edge for nearby monsters out of view: red for ones
  /// that could eat you, green for ones you could eat.
  void _edgeArrows(Canvas c, Arena a, Offset Function(double, double) toScreen, double w, double h) {
    final p = a.player;
    final range = Growth.viewSpan(p.r) * 1.6;
    for (final m in a.monsters) {
      if (m == p || !m.alive) continue;
      final dx = m.x - p.x, dy = m.y - p.y;
      final d = sqrt(dx * dx + dy * dy);
      if (d > range) continue;
      final s = toScreen(m.x, m.y);
      if (s.dx > 0 && s.dx < w && s.dy > 0 && s.dy < h) continue;
      final Color col;
      if (Growth.canEatMonster(m.r, p.r)) {
        col = const Color(0xFFFF4A5A);
      } else if (Growth.canEatMonster(p.r, m.r)) {
        col = const Color(0xFF5BE07A);
      } else {
        continue;
      }
      final ang = atan2(dy, dx);
      const pad = 26.0;
      final cx = w / 2, cy = h / 2;
      final t = min((cx - pad) / max(cos(ang).abs(), 1e-6), (cy - pad) / max(sin(ang).abs(), 1e-6));
      final pos = Offset(cx + cos(ang) * t, cy + sin(ang) * t);
      c.save();
      c.translate(pos.dx, pos.dy);
      c.rotate(ang);
      final arrow = Path()
        ..moveTo(12, 0)
        ..lineTo(-8, -10)
        ..lineTo(-4, 0)
        ..lineTo(-8, 10)
        ..close();
      final alpha = 0.55 + 0.45 * (1 - d / range);
      c.drawPath(arrow, Paint()..color = col.withValues(alpha: alpha));
      c.drawPath(
        arrow,
        Paint()
          ..color = const Color(0xCCFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      c.restore();
    }
  }

  void _drawSea(Canvas c, Arena a) {
    final y0 = a.height;
    final wave = Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var row = 0; row < 4; row++) {
      final y = y0 + 40 + row * 70 + sin(_time * 1.2 + row) * 6;
      final path = Path();
      for (var x = _cx - 900; x < _cx + 900; x += 60) {
        final xx = (x / 60).floor() * 60.0 + (row.isEven ? 0 : 30);
        path.moveTo(xx, y);
        path.quadraticBezierTo(xx + 15, y - 8, xx + 30, y);
      }
      c.drawPath(path, wave);
    }
    // Lapping foam.
    final foam = y0 + 4 + sin(_time * 1.6) * 5;
    c.drawRect(Rect.fromLTWH(-400, foam, a.width + 800, 6), Paint()..color = const Color(0x88FFFFFF));
  }
}

class _Batch {
  Float32List _xf = Float32List(1024), _rc = Float32List(1024);
  int _n = 0;

  void add(SpriteRef s, double x, double y, {double scale = 1, double angle = 0}) {
    if ((_n + 1) * 4 > _xf.length) {
      _xf = Float32List(_xf.length * 2)..setAll(0, _xf);
      _rc = Float32List(_rc.length * 2)..setAll(0, _rc);
    }
    final k = scale / spriteScale;
    final sc = k * cos(angle), ss = k * sin(angle);
    final i = _n * 4;
    _xf[i] = sc;
    _xf[i + 1] = ss;
    _xf[i + 2] = x - (sc * s.cx - ss * s.cy);
    _xf[i + 3] = y - (ss * s.cx + sc * s.cy);
    _rc[i] = s.src.left;
    _rc[i + 1] = s.src.top;
    _rc[i + 2] = s.src.right;
    _rc[i + 3] = s.src.bottom;
    _n++;
  }

  void flush(Canvas c, ui.Image img, Paint paint) {
    if (_n == 0) return;
    c.drawRawAtlas(
      img,
      Float32List.sublistView(_xf, 0, _n * 4),
      Float32List.sublistView(_rc, 0, _n * 4),
      null,
      null,
      null,
      paint,
    );
    _n = 0;
  }
}

class _Particle {
  _Particle(this.x, this.y, this.vx, this.vy, this.life, this.color, this.size) : max = life;
  double x, y, vx, vy, life;
  final double max;
  final Color color;
  final double size;
}

class _Popup {
  _Popup(this.x, this.y, this.tp);
  final double x, y;
  final TextPainter tp;
  double t = 0;
}
