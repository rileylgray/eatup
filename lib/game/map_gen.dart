import 'dart:math';

import 'entities.dart';
import 'maps.dart';
import 'props.dart';

/// Paint for a piece of ground; the renderer resolves it against the map's
/// [GroundPalette] (and a few fixed colours).
enum GroundPaint {
  grass,
  grassDark,
  road,
  roadLine,
  sidewalk,
  plaza,
  water,
  field,
  fieldRow,
  asphalt,
  stripe,
  dirt,
  pool,
  sea,
  foam,
}

class GroundShape {
  const GroundShape(this.paint, this.x, this.y, this.w, this.h, {this.round = 0, this.oval = false});

  final GroundPaint paint;
  final double x, y, w, h;

  /// Corner radius (ignored for ovals).
  final double round;
  final bool oval;
}

/// A generated arena: the road grid, ground art and every prop.
class MapLayout {
  MapLayout({
    required this.map,
    required this.width,
    required this.height,
    required this.roadXs,
    required this.roadYs,
    required this.ground,
    required this.props,
  });

  final MapDef map;

  /// Walkable extent: x in [0, width], y in [0, height]. With a sea, [height]
  /// stops at the shoreline.
  final double width, height;

  /// Centre lines of the roads.
  final List<double> roadXs, roadYs;
  final List<GroundShape> ground;
  final List<Prop> props;

  static const double roadWidth = 64;
  static const double walk = 14;
}

/// Deterministic for a given map and seed, so a bug report's seed replays the
/// same town.
class MapGen {
  MapGen(this.map, int seed) : _rng = Random(seed);

  final MapDef map;
  final Random _rng;
  final List<GroundShape> _ground = [];
  final List<Prop> _props = [];

  double _r(double a, double b) => a + _rng.nextDouble() * (b - a);
  T _pick<T>(List<T> l) => l[_rng.nextInt(l.length)];

  static int variantsOf(PropKind k) => switch (k) {
    PropKind.car => 5,
    PropKind.house => 4,
    PropKind.umbrella => 3,
    PropKind.hut => 3,
    PropKind.shop => 3,
    PropKind.kiosk => 3,
    PropKind.flowers => 3,
    PropKind.tower => 2,
    PropKind.hotel => 2,
    PropKind.surfboard => 3,
    _ => 1,
  };

  PropKind _tree() => map.snow
      ? PropKind.pine
      : map.sea
      ? PropKind.palm
      : PropKind.tree;

  MapLayout generate() {
    final w = map.size;
    final h = map.sea ? map.size * 0.86 : map.size;
    final nx = max(3, (w / 380).round());
    final ny = max(3, (h / 380).round());
    final bx = w / nx, by = h / ny;
    final roadXs = [for (var i = 1; i < nx; i++) i * bx];
    final roadYs = [for (var i = 1; i < ny; i++) i * by];
    const rw = MapLayout.roadWidth;
    const sw = MapLayout.walk;

    // Base.
    _ground.add(GroundShape(GroundPaint.grass, 0, 0, w, h));
    if (map.sea) {
      _ground.add(GroundShape(GroundPaint.sea, -400, h, w + 800, map.size - h + 400));
      _ground.add(GroundShape(GroundPaint.foam, -400, h - 6, w + 800, 14, round: 7));
    }

    // Sidewalks, then roads over them, then lane lines.
    for (final x in roadXs) {
      _ground.add(GroundShape(GroundPaint.sidewalk, x - rw / 2 - sw, 0, rw + sw * 2, h));
    }
    for (final y in roadYs) {
      _ground.add(GroundShape(GroundPaint.sidewalk, 0, y - rw / 2 - sw, w, rw + sw * 2));
    }
    for (final x in roadXs) {
      _ground.add(GroundShape(GroundPaint.road, x - rw / 2, 0, rw, h));
    }
    for (final y in roadYs) {
      _ground.add(GroundShape(GroundPaint.road, 0, y - rw / 2, w, rw));
    }
    for (final x in roadXs) {
      for (var y = 0.0; y < h; y += 44) {
        if (roadYs.any((ry) => (y + 11 - ry).abs() < rw / 2 + 12)) continue;
        _ground.add(GroundShape(GroundPaint.roadLine, x - 2, y, 4, 22, round: 2));
      }
    }
    for (final y in roadYs) {
      for (var x = 0.0; x < w; x += 44) {
        if (roadXs.any((rx) => (x + 11 - rx).abs() < rw / 2 + 12)) continue;
        _ground.add(GroundShape(GroundPaint.roadLine, x, y - 2, 22, 4, round: 2));
      }
    }
    // Zebra crossings beside every intersection.
    for (final x in roadXs) {
      for (final y in roadYs) {
        for (var i = 0; i < 5; i++) {
          final o = -rw / 2 + 8 + i * 12;
          _ground.add(GroundShape(GroundPaint.stripe, x + o, y - rw / 2 - 16, 6, 12, round: 1));
          _ground.add(GroundShape(GroundPaint.stripe, x - rw / 2 - 16, y + o, 12, 6, round: 1));
        }
      }
    }

    // Blocks.
    final edgesX = [0.0, ...roadXs, w];
    final edgesY = [0.0, ...roadYs, h];
    final kinds = <BlockKind>[];
    map.blocks.forEach((k, n) => kinds.addAll(List.filled(n, k)));
    for (var j = 0; j < edgesY.length - 1; j++) {
      for (var i = 0; i < edgesX.length - 1; i++) {
        final x0 = edgesX[i] + (i == 0 ? 10 : rw / 2 + sw + 6);
        final x1 = edgesX[i + 1] - (i == edgesX.length - 2 ? 10 : rw / 2 + sw + 6);
        final y0 = edgesY[j] + (j == 0 ? 10 : rw / 2 + sw + 6);
        final y1 = edgesY[j + 1] - (j == edgesY.length - 2 ? 10 : rw / 2 + sw + 6);
        var kind = _pick(kinds);
        // The row by the sea is always beach.
        if (map.sea && j == edgesY.length - 2) kind = BlockKind.sand;
        _block(kind, x0, y0, x1, y1);
      }
    }

    _streetFurniture(roadXs, roadYs, w, h);

    return MapLayout(map: map, width: w, height: h, roadXs: roadXs, roadYs: roadYs, ground: _ground, props: _props);
  }

  /// Places [kind] at a free spot in the rectangle; gives up quietly when
  /// the block is full.
  Prop? _place(
    PropKind kind,
    double x0,
    double y0,
    double x1,
    double y1, {
    double angle = 0,
    int? variant,
    int tries = 14,
  }) {
    final s = kind.size;
    if (x1 - x0 < s * 2 || y1 - y0 < s * 2) return null;
    for (var t = 0; t < tries; t++) {
      final x = _r(x0 + s, x1 - s);
      final y = _r(y0 + s, y1 - s);
      if (_free(x, y, s)) {
        final p = Prop(x, y, kind, variant: variant ?? _rng.nextInt(variantsOf(kind)), angle: angle);
        _props.add(p);
        return p;
      }
    }
    return null;
  }

  Prop? _at(PropKind kind, double x, double y, {double angle = 0, int? variant}) {
    if (!_free(x, y, kind.size)) return null;
    final p = Prop(x, y, kind, variant: variant ?? _rng.nextInt(variantsOf(kind)), angle: angle);
    _props.add(p);
    return p;
  }

  bool _free(double x, double y, double s) {
    for (final p in _props) {
      final d = s + p.size;
      final dx = p.x - x, dy = p.y - y;
      if (dx * dx + dy * dy < d * d * 0.72) return false;
    }
    return true;
  }

  void _scatter(PropKind kind, int n, double x0, double y0, double x1, double y1) {
    for (var i = 0; i < n; i++) {
      _place(kind, x0, y0, x1, y1, angle: kind.vehicle || kind == PropKind.cow ? _r(0, pi * 2) : 0);
    }
  }

  void _block(BlockKind kind, double x0, double y0, double x1, double y1) {
    final w = x1 - x0, h = y1 - y0;
    final cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
    final tree = _tree();
    switch (kind) {
      case BlockKind.houses:
        _ground.add(GroundShape(GroundPaint.grassDark, x0, y0, w, h, round: 18));
        // Up to four lots, a house in each, with a garden.
        for (final (fx, fy) in [(0.27, 0.27), (0.73, 0.27), (0.27, 0.73), (0.73, 0.73)]) {
          final hx = x0 + w * fx, hy = y0 + h * fy;
          _ground.add(GroundShape(GroundPaint.plaza, hx - 10, hy + 20, 20, h * 0.22, round: 4));
          _at(PropKind.house, hx, hy);
        }
        _scatter(tree, 3, x0, y0, x1, y1);
        _scatter(PropKind.bush, 5, x0, y0, x1, y1);
        _scatter(PropKind.flowers, 4, x0, y0, x1, y1);
        _scatter(PropKind.mailbox, 2, x0, y0, x1, y1);
      case BlockKind.park:
        _ground.add(GroundShape(GroundPaint.grassDark, x0, y0, w, h, round: 26));
        _ground.add(GroundShape(GroundPaint.plaza, cx - 9, y0, 18, h));
        _ground.add(GroundShape(GroundPaint.plaza, x0, cy - 9, w, 18));
        if (_rng.nextBool()) {
          _at(PropKind.fountain, cx, cy);
        } else {
          final pw = w * 0.34, ph = h * 0.26;
          final px = x0 + w * 0.08, py = y0 + h * 0.62;
          _ground.add(GroundShape(GroundPaint.water, px, py, pw, ph, oval: true));
          // Keep props out of the pond.
          _props.add(Prop(px + pw / 2, py + ph / 2, PropKind.fountain)..alive = false);
        }
        _scatter(tree, 8, x0, y0, x1, y1);
        _scatter(PropKind.bench, 4, x0, y0, x1, y1);
        _scatter(PropKind.bush, 5, x0, y0, x1, y1);
        _scatter(PropKind.flowers, 5, x0, y0, x1, y1);
        _scatter(PropKind.lamp, 3, x0, y0, x1, y1);
        _scatter(PropKind.trash, 2, x0, y0, x1, y1);
        if (map.snow) _scatter(PropKind.snowman, 3, x0, y0, x1, y1);
      case BlockKind.plaza:
        _ground.add(GroundShape(GroundPaint.plaza, x0, y0, w, h, round: 12));
        _at(PropKind.fountain, cx, cy);
        for (var i = 0; i < 6; i++) {
          final a = i * pi / 3;
          _at(PropKind.bench, cx + cos(a) * 62, cy + sin(a) * 62, angle: a + pi / 2);
        }
        for (final (fx, fy) in [(0.12, 0.12), (0.88, 0.12), (0.12, 0.88), (0.88, 0.88)]) {
          _at(tree, x0 + w * fx, y0 + h * fy);
        }
        _scatter(PropKind.kiosk, 1, x0, y0, x1, y1);
        _scatter(PropKind.lamp, 4, x0, y0, x1, y1);
        _scatter(PropKind.flowers, 4, x0, y0, x1, y1);
        _scatter(PropKind.trash, 2, x0, y0, x1, y1);
        if (map.snow) {
          _scatter(PropKind.snowman, 4, x0, y0, x1, y1);
          _scatter(PropKind.sled, 3, x0, y0, x1, y1);
        }
      case BlockKind.parking:
        _ground.add(GroundShape(GroundPaint.asphalt, x0, y0, w, h, round: 8));
        final rows = [y0 + h * 0.25, y0 + h * 0.75];
        for (final ry in rows) {
          for (var x = x0 + 26.0; x < x1 - 20; x += 40) {
            _ground.add(GroundShape(GroundPaint.stripe, x - 20, ry - 30, 3, 60));
            if (_rng.nextDouble() < 0.7) {
              _at(PropKind.car, x, ry, angle: pi / 2 + (_rng.nextBool() ? 0 : pi));
            }
          }
        }
        _scatter(PropKind.cone, 4, x0, y0, x1, y1);
        _scatter(PropKind.lamp, 2, x0, y0, x1, y1);
      case BlockKind.market:
        _ground.add(GroundShape(GroundPaint.plaza, x0, y0, w, h, round: 12));
        for (var i = 0; i < 6; i++) {
          _place(PropKind.kiosk, x0, y0, x1, y1);
        }
        _scatter(PropKind.umbrella, 4, x0, y0, x1, y1);
        _scatter(PropKind.crate, 8, x0, y0, x1, y1);
        _scatter(PropKind.trash, 2, x0, y0, x1, y1);
        _scatter(map.sea ? PropKind.surfboard : PropKind.flowers, 3, x0, y0, x1, y1);
      case BlockKind.sand:
        _ground.add(GroundShape(GroundPaint.plaza, x0, y0, w, h, round: 30));
        _scatter(PropKind.hut, 2, x0, y0, x1, y1);
        _scatter(PropKind.umbrella, 9, x0, y0, x1, y1);
        _scatter(PropKind.surfboard, 5, x0, y0, x1, y1);
        _scatter(PropKind.sandcastle, 4, x0, y0, x1, y1);
        _scatter(PropKind.palm, 4, x0, y0, x1, y1);
        _scatter(PropKind.rock, 3, x0, y0, x1, y1);
      case BlockKind.resort:
        _ground.add(GroundShape(GroundPaint.sidewalk, x0, y0, w, h, round: 14));
        _at(PropKind.hotel, x0 + w * 0.32, y0 + h * 0.32);
        final px = x0 + w * 0.52, py = y0 + h * 0.6;
        _ground.add(GroundShape(GroundPaint.pool, px, py, w * 0.38, h * 0.28, round: 18));
        _props.add(Prop(px + w * 0.19, py + h * 0.14, PropKind.hotel)..alive = false);
        _scatter(PropKind.palm, 5, x0, y0, x1, y1);
        _scatter(PropKind.umbrella, 5, x0, y0, x1, y1);
        _scatter(PropKind.flowers, 3, x0, y0, x1, y1);
      case BlockKind.field:
        _ground.add(GroundShape(GroundPaint.field, x0, y0, w, h, round: 6));
        for (var y = y0 + 10; y < y1 - 6; y += 22) {
          _ground.add(GroundShape(GroundPaint.fieldRow, x0 + 8, y, w - 16, 9, round: 4));
        }
        _scatter(PropKind.hay, 6, x0, y0, x1, y1);
        _scatter(PropKind.cow, 5, x0, y0, x1, y1);
        _scatter(PropKind.pumpkin, 10, x0, y0, x1, y1);
      case BlockKind.farmyard:
        _ground.add(GroundShape(GroundPaint.dirt, x0, y0, w, h, round: 16));
        _at(PropKind.barn, x0 + w * 0.34, y0 + h * 0.34);
        _at(PropKind.silo, x0 + w * 0.78, y0 + h * 0.25);
        _scatter(PropKind.tractor, 1, x0, y0, x1, y1);
        _scatter(PropKind.hay, 4, x0, y0, x1, y1);
        _scatter(PropKind.crate, 6, x0, y0, x1, y1);
        _scatter(PropKind.cow, 3, x0, y0, x1, y1);
        _scatter(PropKind.pumpkin, 5, x0, y0, x1, y1);
      case BlockKind.forest:
        _ground.add(GroundShape(GroundPaint.grassDark, x0, y0, w, h, round: 40));
        _scatter(tree, 14, x0, y0, x1, y1);
        _scatter(map.snow ? PropKind.pine : PropKind.tree, 4, x0, y0, x1, y1);
        _scatter(PropKind.rock, 5, x0, y0, x1, y1);
        _scatter(PropKind.bush, 6, x0, y0, x1, y1);
        if (map.snow) _scatter(PropKind.snowman, 2, x0, y0, x1, y1);
      case BlockKind.cabins:
        _ground.add(GroundShape(GroundPaint.grassDark, x0, y0, w, h, round: 20));
        for (final (fx, fy) in [(0.3, 0.3), (0.72, 0.36), (0.4, 0.74)]) {
          _at(PropKind.cabin, x0 + w * fx, y0 + h * fy);
        }
        _scatter(PropKind.pine, 6, x0, y0, x1, y1);
        _scatter(PropKind.snowman, 4, x0, y0, x1, y1);
        _scatter(PropKind.sled, 3, x0, y0, x1, y1);
        _scatter(PropKind.crate, 3, x0, y0, x1, y1);
      case BlockKind.downtown:
        _ground.add(GroundShape(GroundPaint.sidewalk, x0, y0, w, h, round: 6));
        if (_rng.nextDouble() < 0.55) {
          _at(PropKind.tower, cx, cy);
        } else {
          _at(PropKind.hotel, x0 + w * 0.3, y0 + h * 0.3);
          _at(PropKind.shop, x0 + w * 0.7, y0 + h * 0.72);
        }
        _scatter(PropKind.shop, 1, x0, y0, x1, y1);
        _scatter(PropKind.tree, 4, x0, y0, x1, y1);
        _scatter(PropKind.bench, 3, x0, y0, x1, y1);
        _scatter(PropKind.hydrant, 2, x0, y0, x1, y1);
        _scatter(PropKind.trash, 2, x0, y0, x1, y1);
        _scatter(PropKind.kiosk, 1, x0, y0, x1, y1);
    }
  }

  /// Lamps, hydrants and bins along the pavements, and cars parked by the kerb.
  void _streetFurniture(List<double> roadXs, List<double> roadYs, double w, double h) {
    const rw = MapLayout.roadWidth;
    const sw = MapLayout.walk;
    final small = [PropKind.lamp, PropKind.lamp, PropKind.hydrant, PropKind.trash, PropKind.cone];
    final parked = map.id == 'city' ? [PropKind.car, PropKind.taxi, PropKind.car] : [PropKind.car];
    for (final x in roadXs) {
      for (var y = 30.0; y < h - 30; y += _r(70, 120)) {
        if (roadYs.any((ry) => (y - ry).abs() < rw)) continue;
        final side = _rng.nextBool() ? 1 : -1;
        _at(_pick(small), x + side * (rw / 2 + sw / 2), y);
        if (_rng.nextDouble() < 0.18) {
          _at(_pick(parked), x + side * (rw / 2 - 12), y + 30, angle: side > 0 ? pi / 2 : -pi / 2);
        }
      }
    }
    for (final y in roadYs) {
      for (var x = 30.0; x < w - 30; x += _r(70, 120)) {
        if (roadXs.any((rx) => (x - rx).abs() < rw)) continue;
        final side = _rng.nextBool() ? 1 : -1;
        _at(_pick(small), x, y + side * (rw / 2 + sw / 2));
        if (_rng.nextDouble() < 0.18) {
          _at(_pick(parked), x + 30, y + side * (rw / 2 - 12), angle: side > 0 ? 0 : pi);
        }
      }
    }
    // Placeholder props that only reserved space (ponds, pools) go now.
    _props.removeWhere((p) => !p.alive);
  }
}
