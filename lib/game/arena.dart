import 'dart:math';

import 'entities.dart';
import 'growth.dart';
import 'map_gen.dart';
import 'maps.dart';
import 'props.dart';
import 'rival_names.dart';
import 'skins.dart';
import 'spatial_grid.dart';
import 'upgrades.dart';

enum RoundPhase { countdown, playing, over }

/// How a round went, for the results card, coins, XP and missions.
class RoundResult {
  const RoundResult({
    required this.mapId,
    required this.rank,
    required this.players,
    required this.maxRadius,
    required this.people,
    required this.props,
    required this.vehicles,
    required this.buildings,
    required this.monsters,
    required this.eatenBy,
  });

  final String mapId;

  /// 1-based finishing place among [players] monsters.
  final int rank;
  final int players;
  final double maxRadius;
  final int people, props, vehicles, buildings, monsters;

  /// Who ate the player, if the round ended that way.
  final String? eatenBy;

  bool get won => rank == 1;
  int get totalEaten => people + props + monsters;
}

/// The whole round, as plain Dart: the map, everyone on it and the rules.
/// The Flame game ([EatGame]) only feeds it input and draws it, so rules and
/// balance are unit tested without a renderer.
class Arena {
  Arena({
    required this.map,
    required int seed,
    required Loadout loadout,
    required SkinDef playerSkin,
    required String playerName,
    this.demo = false,
    this.tutorial = false,
    double? roundSeconds,
  }) : _rng = Random(seed),
       duration = (roundSeconds ?? 100) + loadout.extraSeconds {
    layout = MapGen(map, seed).generate();
    _staticGrid = SpatialGrid<Prop>(max(layout.width, layout.height));
    _peopleGrid = SpatialGrid<Person>(max(layout.width, layout.height));
    for (final p in layout.props) {
      _staticGrid.insert(p);
    }
    _spawnCars();
    _spawnMonsters(loadout, playerSkin, playerName);
    while (people.length < map.population) {
      _spawnCrowd(awayFromPlayer: false);
    }
    timeLeft = duration;
    phase = demo ? RoundPhase.playing : RoundPhase.countdown;
  }

  final MapDef map;
  final Random _rng;
  final bool demo;

  /// The first-ever round: fewer, gentler rivals.
  final bool tutorial;
  late final MapLayout layout;
  late final SpatialGrid<Prop> _staticGrid;
  late final SpatialGrid<Person> _peopleGrid;

  final List<Person> people = [];
  final List<Prop> cars = [];
  final List<Monster> monsters = [];
  final List<PowerUp> powerUps = [];
  final List<Swallow> swallows = [];

  late Monster player;
  final double duration;
  late double timeLeft;
  late RoundPhase phase;
  double countdown = 2.4;
  double elapsed = 0;

  /// Paused (menu, eaten dialog): nothing moves.
  bool frozen = false;

  /// The player's movement input: a vector of length 0..1.
  double inputX = 0, inputY = 0;

  /// Player combo: things eaten in quick succession.
  int combo = 0;
  double _comboTimer = 0;

  double _crowdTimer = 0;
  double _powerTimer = 6;
  double _compactTimer = 0;
  String? eatenBy;
  final Set<PropTier> _tiersAnnounced = {};

  // Events for the game layer (sound, particles, popups, toasts).
  void Function(Monster m, Food f)? onEat;
  void Function(Monster eater, Monster victim)? onMonsterEaten;
  void Function(Monster m, PowerKind k)? onPowerUp;
  void Function(PropTier tier)? onTierReached;
  void Function(int combo)? onCombo;
  void Function()? onPlayerEaten;
  void Function()? onRoundOver;
  void Function()? onGo;

  double get width => layout.width;
  double get height => layout.height;
  double get progress => (elapsed / duration).clamp(0, 1);

  // Setup ---------------------------------------------------------------------

  double _startRadius(Loadout l) => demo ? Growth.startRadius : l.startRadius;

  void _spawnMonsters(Loadout loadout, SkinDef playerSkin, String playerName) {
    final names = RivalNames.pick(_rng, map.rivals);
    final count = tutorial ? 4 : map.rivals;
    final skill = tutorial ? 0.1 : map.rivalSkill;
    final looks = [...rivalSkinIds.where((id) => id != playerSkin.id)]..shuffle(_rng);

    // Spread everyone around a ring so nobody starts next to a rival.
    final cx = width / 2, cy = height / 2;
    final ring = min(width, height) * 0.32;
    final a0 = _rng.nextDouble() * pi * 2;
    player = Monster(
      id: 0,
      name: playerName,
      skin: playerSkin,
      x: cx + cos(a0) * ring * 0.2,
      y: cy + sin(a0) * ring * 0.2,
      radius: _startRadius(loadout),
      isPlayer: !demo,
      reach: loadout.reach,
      speedMult: loadout.speedMult,
    );
    monsters.add(player);
    for (var i = 0; i < count; i++) {
      final a = a0 + (i + 1) * pi * 2 / (count + 1);
      final ringR = ring * (0.8 + _rng.nextDouble() * 0.5);
      monsters.add(
        Monster(
          id: i + 1,
          name: names[i],
          skin: skinById(looks[i % looks.length]),
          x: (cx + cos(a) * ringR).clamp(60, width - 60),
          y: (cy + sin(a) * ringR).clamp(60, height - 60),
          radius: Growth.startRadius * (0.9 + _rng.nextDouble() * 0.15),
          speedMult: 0.84 + skill * 0.14,
        ),
      );
    }
  }

  /// Townsfolk come in little crowds: more fun to chomp.
  void _spawnCrowd({required bool awayFromPlayer}) {
    for (var attempt = 0; attempt < 8; attempt++) {
      final x = 30 + _rng.nextDouble() * (width - 60);
      final y = 30 + _rng.nextDouble() * (height - 60);
      if (awayFromPlayer) {
        final d = Growth.viewSpan(player.r) * 0.75;
        if ((x - player.x).abs() < d && (y - player.y).abs() < d * 1.8) continue;
      }
      final n = 3 + _rng.nextInt(5);
      for (var i = 0; i < n; i++) {
        final p = Person(
          (x + (_rng.nextDouble() - 0.5) * 60).clamp(10, width - 10),
          (y + (_rng.nextDouble() - 0.5) * 60).clamp(10, height - 10),
          variant: _rng.nextInt(peopleVariants),
          phase: _rng.nextDouble() * 10,
        );
        p
          ..tx = p.x
          ..ty = p.y
          ..idle = _rng.nextDouble() * 2;
        people.add(p);
      }
      return;
    }
  }

  void _spawnCars() {
    final kinds = map.id == 'farm'
        ? [PropKind.tractor, PropKind.car]
        : map.id == 'city'
        ? [PropKind.car, PropKind.taxi, PropKind.bus, PropKind.taxi]
        : [PropKind.car, PropKind.car, PropKind.bus];
    for (var i = 0; i < map.movingCars; i++) {
      final horizontal = _rng.nextBool();
      final lines = horizontal ? layout.roadYs : layout.roadXs;
      if (lines.isEmpty) continue;
      final line = lines[_rng.nextInt(lines.length)];
      final dir = horizontal ? (_rng.nextBool() ? 0 : 2) : (_rng.nextBool() ? 1 : 3);
      final along = 40 + _rng.nextDouble() * ((horizontal ? width : height) - 80);
      final kind = kinds[_rng.nextInt(kinds.length)];
      final car = Prop(0, 0, kind, variant: _rng.nextInt(MapGen.variantsOf(kind)))
        ..drive = Drive(dir, 55 + _rng.nextDouble() * 35);
      if (horizontal) {
        car
          ..x = along
          ..y = line + _laneOffset(dir);
      } else {
        car
          ..x = line + _laneOffset(dir)
          ..y = along;
      }
      car.angle = dir * pi / 2;
      cars.add(car);
    }
  }

  /// Traffic keeps right.
  static double _laneOffset(int dir) => switch (dir) {
    0 => MapLayout.roadWidth / 4,
    1 => -MapLayout.roadWidth / 4,
    2 => -MapLayout.roadWidth / 4,
    _ => MapLayout.roadWidth / 4,
  };

  /// Props still standing (for the renderer), including cars on the move.
  Iterable<Prop> get standingProps sync* {
    for (final p in layout.props) {
      if (p.alive) yield p;
    }
    for (final c in cars) {
      if (c.alive) yield c;
    }
  }

  // Loop ----------------------------------------------------------------------

  void update(double dt) {
    if (frozen) return;
    dt = min(dt, 1 / 20);

    if (phase == RoundPhase.countdown) {
      countdown -= dt;
      if (countdown <= 0) {
        phase = RoundPhase.playing;
        onGo?.call();
      }
    } else if (phase == RoundPhase.playing) {
      elapsed += dt;
      if (!demo) {
        timeLeft -= dt;
        if (timeLeft <= 0) {
          timeLeft = 0;
          phase = RoundPhase.over;
          onRoundOver?.call();
        }
      }
    }

    final live = phase == RoundPhase.playing;
    _updatePeople(dt);
    _updateCars(dt);
    for (final m in monsters) {
      _animate(m, dt);
      if (!m.alive) {
        if (!m.isPlayer && live) {
          m.respawnIn -= dt;
          if (m.respawnIn <= 0) _respawn(m);
        }
        continue;
      }
      if (!live) continue;
      if (m.isPlayer) {
        _steer(m, inputX, inputY, dt);
      } else {
        _think(m, dt);
        final dx = m.tx - m.x, dy = m.ty - m.y;
        final d = sqrt(dx * dx + dy * dy);
        _steer(m, d > 1 ? dx / d : 0, d > 1 ? dy / d : 0, dt);
      }
      _eatFood(m, dt);
    }
    if (live) {
      _eatMonsters();
      _updatePowerUps(dt);
    }
    _updateSwallows(dt);

    if (_comboTimer > 0) {
      _comboTimer -= dt;
      if (_comboTimer <= 0) combo = 0;
    }

    // Keep the town busy.
    _crowdTimer -= dt;
    if (_crowdTimer <= 0 && people.length < map.population) {
      _crowdTimer = 0.25;
      // Faster when the town has been eaten bare.
      final crowds = people.length < map.population * 0.6 ? 3 : 1;
      for (var i = 0; i < crowds; i++) {
        _spawnCrowd(awayFromPlayer: true);
      }
    }
    _compactTimer -= dt;
    if (_compactTimer <= 0) {
      _compactTimer = 3;
      _staticGrid.compact();
    }
    if (!demo) _checkTiers();
  }

  void _animate(Monster m, double dt) {
    m.wobble += dt * (2 + sqrt(m.vx * m.vx + m.vy * m.vy) / 40);
    m.chomp = max(0, m.chomp - dt * 5);
    m.squash = max(0, m.squash - dt * 4);
    m.blink -= dt;
    if (m.blink < -0.12) m.blink = 2 + _rng.nextDouble() * 3;
    m.shield = max(0, m.shield - dt);
    m.speedT = max(0, m.speedT - dt);
    m.magnetT = max(0, m.magnetT - dt);
    m.frenzyT = max(0, m.frenzyT - dt);
  }

  void _steer(Monster m, double ix, double iy, double dt) {
    final top = Growth.speed(m.r) * m.speedMult * (m.speedT > 0 ? 1.45 : 1);
    final k = min(1.0, dt * 7);
    m.vx += (ix * top - m.vx) * k;
    m.vy += (iy * top - m.vy) * k;
    m.x += m.vx * dt;
    m.y += m.vy * dt;
    final pad = m.r * 0.5;
    m.x = m.x.clamp(pad, width - pad);
    m.y = m.y.clamp(pad, height - pad);
    final sp = sqrt(m.vx * m.vx + m.vy * m.vy);
    if (sp > 8) {
      m.fx += (m.vx / sp - m.fx) * min(1, dt * 8);
      m.fy += (m.vy / sp - m.fy) * min(1, dt * 8);
    }
  }

  // Rivals --------------------------------------------------------------------

  /// A rival re-plans a few times a second: run from anything that can eat
  /// it, chase anything it can eat, otherwise head for the best snack nearby.
  void _think(Monster m, double dt) {
    m.think -= dt;
    final chase = m.chasing;
    if (chase != null && chase.alive && Growth.canEatMonster(m.r, chase.r)) {
      m.tx = chase.x + chase.vx * 0.3;
      m.ty = chase.y + chase.vy * 0.3;
    }
    if (m.think > 0) return;
    final skill = tutorial ? 0.1 : map.rivalSkill;
    m.think = 0.5 - skill * 0.3 + _rng.nextDouble() * 0.15;
    m.chasing = null;

    final r = m.r;
    // Threats.
    double fx = 0, fy = 0;
    var threatened = false;
    for (final o in monsters) {
      if (o == m || !o.alive) continue;
      final dx = m.x - o.x, dy = m.y - o.y;
      final d = sqrt(dx * dx + dy * dy) + 0.01;
      if (Growth.canEatMonster(o.r, r) && d < o.r + r * 4 + 120) {
        final w = 1 / d;
        fx += dx / d * w;
        fy += dy / d * w;
        threatened = true;
      }
    }
    if (threatened) {
      // Walls: lean back toward the middle so a cornered rival slides out.
      fx += (width / 2 - m.x) / width * 0.004;
      fy += (height / 2 - m.y) / height * 0.004;
      final l = sqrt(fx * fx + fy * fy) + 1e-9;
      m.tx = m.x + fx / l * 300;
      m.ty = m.y + fy / l * 300;
      return;
    }
    // Prey.
    if (_rng.nextDouble() < 0.25 + skill * 0.55) {
      Monster? best;
      var bestD = r * 5 + 200;
      for (final o in monsters) {
        if (o == m || !o.alive || o.shield > 0) continue;
        if (!Growth.canEatMonster(r, o.r)) continue;
        final d = sqrt(pow(o.x - m.x, 2) + pow(o.y - m.y, 2));
        if (d < bestD) {
          bestD = d;
          best = o;
        }
      }
      if (best != null) {
        m.chasing = best;
        m.tx = best.x;
        m.ty = best.y;
        return;
      }
    }
    // Food: best value per distance within sight.
    final sight = r * 5 + 180 + skill * 120;
    Food? target;
    var score = 0.0;
    void consider(Food f) {
      if (!Growth.canSwallow(r, f.size)) return;
      final d = sqrt(pow(f.x - m.x, 2) + pow(f.y - m.y, 2)) + 20;
      if (d > sight) return;
      final s = Growth.gainFor(f.size) / d;
      if (s > score) {
        score = s;
        target = f;
      }
    }

    _staticGrid.query(m.x, m.y, sight, consider);
    _peopleGrid.query(m.x, m.y, sight, consider);
    for (final c in cars) {
      if (c.alive) consider(c);
    }
    final t = target;
    if (t != null) {
      m.tx = t.x;
      m.ty = t.y;
    } else if ((m.tx - m.x).abs() + (m.ty - m.y).abs() < 40 || _rng.nextDouble() < 0.2) {
      m.tx = 80 + _rng.nextDouble() * (width - 160);
      m.ty = 80 + _rng.nextDouble() * (height - 160);
    }
  }

  void _respawn(Monster m) {
    for (var i = 0; i < 12; i++) {
      final x = 80 + _rng.nextDouble() * (width - 160);
      final y = 80 + _rng.nextDouble() * (height - 160);
      if (monsters.any((o) => o != m && o.alive && (o.x - x).abs() + (o.y - y).abs() < o.r * 4 + 300)) continue;
      m
        ..x = x
        ..y = y
        ..tx = x
        ..ty = y
        ..vx = 0
        ..vy = 0
        ..alive = true
        ..shield = 2.5
        ..area = m.startArea * (1 + progress * 1.6);
      return;
    }
    m.respawnIn = 0.5;
  }

  // People and traffic ---------------------------------------------------------

  void _updatePeople(double dt) {
    _peopleGrid.clear();
    for (final p in people) {
      if (!p.alive) continue;
      // Scared of any monster close by.
      Monster? threat;
      var threatD = double.infinity;
      for (final m in monsters) {
        if (!m.alive) continue;
        final dx = p.x - m.x, dy = p.y - m.y;
        final d = dx * dx + dy * dy;
        final range = m.r * 2.6 + 50;
        if (d < range * range && d < threatD) {
          threatD = d;
          threat = m;
        }
      }
      double speed;
      if (threat != null) {
        p.panic = 1.2;
        final dx = p.x - threat.x, dy = p.y - threat.y;
        final d = sqrt(dx * dx + dy * dy) + 0.01;
        p.tx = p.x + dx / d * 80;
        p.ty = p.y + dy / d * 80;
        p.idle = 0;
        speed = 78;
      } else {
        p.panic = max(0, p.panic - dt);
        speed = p.panic > 0 ? 70 : 30;
        if (p.idle > 0) {
          p.idle -= dt;
          speed = 0;
        } else if ((p.tx - p.x).abs() + (p.ty - p.y).abs() < 4) {
          p.idle = 0.5 + _rng.nextDouble() * 2;
          p.tx = (p.x + (_rng.nextDouble() - 0.5) * 260).clamp(10, width - 10);
          p.ty = (p.y + (_rng.nextDouble() - 0.5) * 260).clamp(10, height - 10);
        }
      }
      if (speed > 0) {
        final dx = p.tx - p.x, dy = p.ty - p.y;
        final d = sqrt(dx * dx + dy * dy);
        if (d > 0.5) {
          p.vx = dx / d * speed;
          p.vy = dy / d * speed;
        }
      } else {
        p.vx = p.vy = 0;
      }
      p.x = (p.x + p.vx * dt).clamp(6, width - 6);
      p.y = (p.y + p.vy * dt).clamp(6, height - 6);
      p.phase += sqrt(p.vx * p.vx + p.vy * p.vy) * dt * 0.25;
      _peopleGrid.insert(p);
    }
    if (people.length > map.population * 2 || people.any((p) => !p.alive)) {
      people.removeWhere((p) => !p.alive);
    }
  }

  void _updateCars(double dt) {
    final xs = layout.roadXs, ys = layout.roadYs;
    for (final c in cars) {
      final drv = c.drive;
      if (!c.alive || drv == null) continue;
      // Brake for monsters in the way (they're scary).
      var speed = drv.speed;
      final ahead = 60.0;
      final hx = c.x + cos(drv.dir * pi / 2) * ahead, hy = c.y + sin(drv.dir * pi / 2) * ahead;
      for (final m in monsters) {
        if (m.alive && (m.x - hx).abs() < m.r + 20 && (m.y - hy).abs() < m.r + 20) {
          speed *= 0.35;
          break;
        }
      }
      final step = speed * dt;
      switch (drv.dir) {
        case 0:
          c.x += step;
        case 1:
          c.y += step;
        case 2:
          c.x -= step;
        default:
          c.y -= step;
      }
      final horizontal = drv.dir.isEven;
      final along = horizontal ? c.x : c.y;
      final crossings = horizontal ? xs : ys;
      // Turn at intersections now and then.
      for (var i = 0; i < crossings.length; i++) {
        if ((along - crossings[i]).abs() < step + 0.5 && drv.lastCross != i) {
          drv.lastCross = i;
          if (_rng.nextDouble() < 0.35) {
            final line = crossings[i];
            final newDir = horizontal ? (_rng.nextBool() ? 1 : 3) : (_rng.nextBool() ? 0 : 2);
            final crossLine = horizontal ? c.y - _laneOffset(drv.dir) : c.x - _laneOffset(drv.dir);
            drv.dir = newDir;
            drv.lastCross = _indexNear(horizontal ? ys : xs, crossLine);
            if (newDir.isEven) {
              c.y = crossLine + _laneOffset(newDir);
              c.x = line;
            } else {
              c.x = crossLine + _laneOffset(newDir);
              c.y = line;
            }
          }
          break;
        }
      }
      // U-turn at the edge of town.
      final limit = horizontal ? width : height;
      if (along < 10 || along > limit - 10) {
        final line = horizontal ? c.y - _laneOffset(drv.dir) : c.x - _laneOffset(drv.dir);
        drv.dir = (drv.dir + 2) % 4;
        drv.lastCross = -1;
        if (horizontal) {
          c
            ..x = c.x.clamp(11, limit - 11)
            ..y = line + _laneOffset(drv.dir);
        } else {
          c
            ..y = c.y.clamp(11, limit - 11)
            ..x = line + _laneOffset(drv.dir);
        }
      }
      // Ease the heading round rather than snapping.
      final target = drv.dir * pi / 2;
      var diff = (target - c.angle) % (pi * 2);
      if (diff > pi) diff -= pi * 2;
      c.angle += diff * min(1, dt * 10);
    }
  }

  static int _indexNear(List<double> lines, double v) {
    for (var i = 0; i < lines.length; i++) {
      if ((lines[i] - v).abs() < 1) return i;
    }
    return -1;
  }

  // Eating --------------------------------------------------------------------

  void _eatFood(Monster m, double dt) {
    final r = m.r;
    final reach = r * m.effectiveReach;
    final maxSize = PropKind.tower.size;

    void tryEat(Food f) {
      if (!f.alive || !Growth.canSwallow(r, f.size)) return;
      final dx = m.x - f.x, dy = m.y - f.y;
      final d = sqrt(dx * dx + dy * dy);
      if (d < r - f.size * 0.4) {
        _swallow(m, f);
      } else if (d < reach + f.size * 0.5 && d > 0) {
        // Suction: lighter things slide in faster.
        final pull = (160 + r * 2) * (1 - f.size / (r * Growth.swallowRatio) * 0.6) * dt;
        final step = min(pull, d);
        f.x += dx / d * step;
        f.y += dy / d * step;
      }
    }

    _staticGrid.query(m.x, m.y, reach + maxSize, tryEat);
    _peopleGrid.query(m.x, m.y, reach + 10, tryEat);
    for (final c in cars) {
      if (c.alive && (c.x - m.x).abs() < reach + c.size && (c.y - m.y).abs() < reach + c.size) tryEat(c);
    }
    for (final p in powerUps) {
      if (!p.alive) continue;
      final d = sqrt(pow(p.x - m.x, 2) + pow(p.y - m.y, 2));
      if (d < r + p.size) {
        p.alive = false;
        switch (p.kind) {
          case PowerKind.speed:
            m.speedT = 6;
          case PowerKind.magnet:
            m.magnetT = 8;
          case PowerKind.frenzy:
            m.frenzyT = 8;
        }
        m.chomp = 1;
        onPowerUp?.call(m, p.kind);
      }
    }
  }

  void _swallow(Monster m, Food f) {
    f.alive = false;
    swallows.add(Swallow(f, m, f.x - m.x, f.y - m.y));
    m.grow(Growth.gainFor(f.size));
    m.chomp = 1;
    if (f is Person) {
      m.people++;
    } else if (f is Prop) {
      m.props++;
      if (f.kind.vehicle) m.vehicles++;
      if (f.kind.building) m.buildings++;
    }
    if (m.isPlayer) {
      combo++;
      _comboTimer = 0.9;
      if (combo == 5 || combo == 10 || combo == 20 || combo == 35 || (combo >= 50 && combo % 25 == 0)) {
        onCombo?.call(combo);
      }
    }
    onEat?.call(m, f);
  }

  void _eatMonsters() {
    for (final a in monsters) {
      if (!a.alive) continue;
      for (final b in monsters) {
        if (a == b || !b.alive || b.shield > 0) continue;
        if (!Growth.canEatMonster(a.r, b.r)) continue;
        final dx = a.x - b.x, dy = a.y - b.y;
        final reach = a.r - b.r * 0.35;
        if (dx * dx + dy * dy < reach * reach) {
          b.alive = false;
          b.respawnIn = 3;
          a.grow(Growth.gainForMonster(b.area));
          a.monsters++;
          a.chomp = 1;
          onMonsterEaten?.call(a, b);
          if (b == player && !demo) {
            eatenBy = a.name;
            frozen = true;
            onPlayerEaten?.call();
            return;
          }
        }
      }
    }
  }

  /// Brings the player back after a rewarded video: same size, somewhere
  /// safe, with a moment of protection.
  void revive() {
    final m = player;
    var best = (m.x, m.y);
    var bestD = -1.0;
    for (var i = 0; i < 20; i++) {
      final x = 80 + _rng.nextDouble() * (width - 160);
      final y = 80 + _rng.nextDouble() * (height - 160);
      var nearest = double.infinity;
      for (final o in monsters) {
        if (o == m || !o.alive) continue;
        nearest = min(nearest, sqrt(pow(o.x - x, 2) + pow(o.y - y, 2)) - o.r);
      }
      if (nearest > bestD) {
        bestD = nearest;
        best = (x, y);
      }
    }
    m
      ..x = best.$1
      ..y = best.$2
      ..vx = 0
      ..vy = 0
      ..alive = true
      ..shield = 3;
    eatenBy = null;
    frozen = false;
  }

  /// The player declined a revive: the round ends where it stands.
  void giveUp() {
    phase = RoundPhase.over;
    frozen = false;
  }

  void _updateSwallows(double dt) {
    for (final s in swallows) {
      s.t += dt / Swallow.duration;
    }
    swallows.removeWhere((s) => s.t >= 1);
  }

  void _updatePowerUps(double dt) {
    for (final p in powerUps) {
      p.age += dt;
      if (p.age > PowerUp.lifetime) p.alive = false;
    }
    powerUps.removeWhere((p) => !p.alive);
    _powerTimer -= dt;
    if (_powerTimer <= 0 && powerUps.length < 3) {
      _powerTimer = 9 + _rng.nextDouble() * 6;
      final kind = PowerKind.values[_rng.nextInt(PowerKind.values.length)];
      // Somewhere the player can see it coming, but not on top of them.
      final a = _rng.nextDouble() * pi * 2;
      final d = Growth.viewSpan(player.r) * (0.35 + _rng.nextDouble() * 0.3);
      powerUps.add(
        PowerUp((player.x + cos(a) * d).clamp(40, width - 40), (player.y + sin(a) * d).clamp(40, height - 40), kind),
      );
    }
  }

  void _checkTiers() {
    if (!player.alive) return;
    // The sizes the hints name: cars, buses, houses.
    const thresholds = {PropTier.medium: 19.0, PropTier.large: 30.0, PropTier.building: 42.0};
    thresholds.forEach((tier, size) {
      if (!_tiersAnnounced.contains(tier) && Growth.canSwallow(player.r, size)) {
        _tiersAnnounced.add(tier);
        onTierReached?.call(tier);
      }
    });
  }

  // Results -------------------------------------------------------------------

  /// Everyone, biggest first.
  List<Monster> standings() => [...monsters]..sort((a, b) => b.area.compareTo(a.area));

  int get playerRank => standings().indexOf(player) + 1;

  RoundResult result() => RoundResult(
    mapId: map.id,
    rank: playerRank,
    players: monsters.length,
    maxRadius: sqrt(player.maxArea),
    people: player.people,
    props: player.props,
    vehicles: player.vehicles,
    buildings: player.buildings,
    monsters: player.monsters,
    eatenBy: eatenBy,
  );

  /// Test hook: the people grid, as the rules see it.
  SpatialGrid<Person> get peopleGrid => _peopleGrid;
}
