import 'dart:math';

import 'package:eatup/game/arena.dart';
import 'package:eatup/game/entities.dart';
import 'package:eatup/game/growth.dart';
import 'package:eatup/game/map_gen.dart';
import 'package:eatup/game/maps.dart';
import 'package:eatup/game/props.dart';
import 'package:eatup/game/skins.dart';
import 'package:eatup/game/upgrades.dart';
import 'package:flutter_test/flutter_test.dart';

Arena _arena(MapDef map, {int seed = 1, bool tutorial = false}) => Arena(
  map: map,
  seed: seed,
  loadout: const Loadout(),
  playerSkin: skins.first,
  playerName: 'You',
  tutorial: tutorial,
);

/// Steers the player like a simple bot: to the nearest edible thing.
void _autopilot(Arena a) {
  final p = a.player;
  // A portrait phone's view, as the renderer would set it.
  final span = Growth.viewSpan(p.r);
  a.view = (x: p.x, y: p.y, hw: span / 2 + 150, hh: span * 1.1 + 150);
  Food? best;
  var bestD = double.infinity;
  for (final f in [...a.people, ...a.standingProps]) {
    if (!f.alive || !Growth.canSwallow(p.r, f.size)) continue;
    final d = pow(f.x - p.x, 2) + pow(f.y - p.y, 2);
    if (d < bestD) {
      bestD = d.toDouble();
      best = f;
    }
  }
  if (best == null) return;
  final dx = best.x - p.x, dy = best.y - p.y;
  final l = sqrt(dx * dx + dy * dy) + 1e-9;
  a.inputX = dx / l;
  a.inputY = dy / l;
}

void main() {
  group('Growth', () {
    test('start size eats people and small props, not cars', () {
      expect(Growth.canSwallow(Growth.startRadius, Growth.personSize), isTrue);
      expect(Growth.canSwallow(Growth.startRadius, PropKind.bench.size), isTrue);
      expect(Growth.canSwallow(Growth.startRadius, PropKind.car.size), isFalse);
    });

    test('bigger things need a bigger monster, in tier order', () {
      final order = PropKind.values.toList()..sort((a, b) => a.size.compareTo(b.size));
      for (var i = 1; i < order.length; i++) {
        expect(order[i].tier.index, greaterThanOrEqualTo(order[i - 1].tier.index), reason: '${order[i]}');
      }
      expect(Growth.radiusToEat(PropKind.tower.size), lessThan(120));
    });

    test('monsters eat only clearly smaller monsters', () {
      expect(Growth.canEatMonster(30, 26), isTrue);
      expect(Growth.canEatMonster(30, 27), isFalse);
    });

    test('speed falls gently with size', () {
      expect(Growth.speed(100), lessThan(Growth.speed(20)));
      expect(Growth.speed(100), greaterThan(Growth.speed(20) * 0.6));
    });
  });

  group('MapGen', () {
    for (final map in maps) {
      test('${map.id} is deterministic and filled', () {
        final a = MapGen(map, 42).generate();
        final b = MapGen(map, 42).generate();
        expect(a.props.length, b.props.length);
        expect(a.props.length, greaterThan(150));
        for (final p in a.props) {
          expect(p.x, inInclusiveRange(0, a.width));
          expect(p.y, inInclusiveRange(0, a.height));
          expect(p.alive, isTrue);
        }
        // Something to grow into at every tier.
        final tiers = a.props.map((p) => p.kind.tier).toSet();
        expect(tiers, containsAll([PropTier.tiny, PropTier.small, PropTier.medium, PropTier.building]));
      });
    }
  });

  group('Arena', () {
    test('countdown, then play, then over when time runs out', () {
      final a = _arena(maps.first);
      var went = false, over = false;
      a
        ..onGo = (() => went = true)
        ..onRoundOver = (() => over = true);
      expect(a.phase, RoundPhase.countdown);
      for (var i = 0; i < 60 * 3; i++) {
        a.update(1 / 60);
      }
      expect(went, isTrue);
      expect(a.phase, RoundPhase.playing);
      a.frozen = false;
      var t = 0.0;
      while (a.phase != RoundPhase.over && t < 200) {
        a.frozen = false;
        a.update(1 / 20);
        t += 1 / 20;
        if (a.eatenBy != null) a.revive();
      }
      expect(over, isTrue);
    });

    for (final map in maps) {
      test('a player that chases food grows on ${map.id}', () {
        final a = _arena(map, seed: 7);
        final start = a.player.r;
        final sw = Stopwatch()..start();
        var frames = 0;
        while (a.phase != RoundPhase.over) {
          _autopilot(a);
          a.update(1 / 30);
          frames++;
          if (a.eatenBy != null) a.revive();
        }
        sw.stop();
        final res = a.result();
        // ignore: avoid_print
        print(
          '${map.id}: r=${a.player.r.round()} max=${res.maxRadius.round()} rank=${res.rank}/${res.players} '
          'people=${res.people} props=${res.props} bld=${res.buildings} mon=${res.monsters} '
          'rivals=${a.monsters.skip(1).map((m) => m.r.round()).join(',')} '
          'us/frame=${(sw.elapsedMicroseconds / frames).round()}',
        );
        expect(a.player.r, greaterThan(start * 1.5));
        expect(res.people + res.props, greaterThan(40));
        expect(res.rank, inInclusiveRange(1, a.monsters.length));
        // The simulation must stay cheap: well under a frame per update.
        expect(sw.elapsedMicroseconds / frames, lessThan(4000), reason: 'us per update');
        // Rivals play too.
        final rivals = a.monsters.where((m) => !m.isPlayer);
        expect(rivals.any((m) => m.maxArea > m.startArea * 2), isTrue);
      });
    }

    test('the town keeps its crowd topped up', () {
      final a = _arena(maps.first);
      for (final p in a.people) {
        p.alive = false;
      }
      for (var i = 0; i < 30 * 20; i++) {
        a.update(1 / 30);
      }
      expect(a.people.where((p) => p.alive).length, greaterThan(maps.first.population * 0.6));
    });

    test('revive brings the player back protected', () {
      final a = _arena(maps.first);
      a.player.alive = false;
      a.frozen = true;
      a.revive();
      expect(a.player.alive, isTrue);
      expect(a.player.shield, greaterThan(0));
      expect(a.frozen, isFalse);
    });

    test('things too big to eat are solid', () {
      final a = _arena(maps.first);
      for (var i = 0; i < 60 * 3; i++) {
        a.update(1 / 60);
      }
      final house = a.layout.props.firstWhere((p) => p.kind.building);
      expect(Growth.canSwallow(a.player.r, house.size), isFalse);
      a.player
        ..x = house.x - house.size - a.player.r - 10
        ..y = house.y;
      a.inputX = 1;
      a.inputY = 0;
      for (var i = 0; i < 60 * 2; i++) {
        a.frozen = false;
        a.update(1 / 60);
      }
      expect(house.alive, isTrue);
      final d = sqrt(pow(a.player.x - house.x, 2) + pow(a.player.y - house.y, 2));
      expect(d, greaterThan(house.size * 0.8));
    });

    test('people walk round things, not through them', () {
      final a = _arena(maps.first);
      final house = a.layout.props.firstWhere((p) => p.kind.building);
      a.people
        ..clear()
        ..add(
          Person(house.x - house.size - 10, house.y, variant: 0, phase: 0)
            ..tx = house.x + house.size + 10
            ..ty = house.y,
        );
      final p = a.people.single;
      for (var i = 0; i < 60 * 2; i++) {
        a.update(1 / 60);
        final d = sqrt(pow(p.x - house.x, 2) + pow(p.y - house.y, 2));
        expect(d, greaterThan(house.size * 0.8), reason: 'frame $i');
      }
    });

    test('a big rival eats a small player', () {
      final a = _arena(maps.first);
      for (var i = 0; i < 60 * 3; i++) {
        a.update(1 / 60);
      }
      final rival = a.monsters[1]
        ..area = 80 * 80
        ..x = a.player.x
        ..y = a.player.y;
      String? eater;
      a.onPlayerEaten = () => eater = a.eatenBy;
      a.update(1 / 60);
      expect(eater, rival.name);
      expect(a.frozen, isTrue);
      expect(a.result().eatenBy, rival.name);
    });
  });
}
