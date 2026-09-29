import 'dart:math';

import 'arena.dart';
import 'maps.dart';
import 'upgrades.dart';

/// Coins and XP for a finished round.
class RoundRewards {
  const RoundRewards(this.coins, this.xp);

  final int coins;
  final int xp;

  static const _rankCoins = [60, 45, 35, 25, 20, 15, 12, 10, 8];

  static RoundRewards of(RoundResult r, MapDef map, Loadout loadout) {
    final base =
        _rankCoins[min(r.rank, _rankCoins.length) - 1] +
        r.people * 0.5 +
        r.props * 0.5 +
        r.vehicles * 2 +
        r.buildings * 8 +
        r.monsters * 12;
    final coins = (base * map.coinMult * loadout.coinMult).round();
    final xp =
        20 +
        (r.people + r.props) ~/ 5 +
        r.monsters * 5 +
        switch (r.rank) {
          1 => 30,
          2 => 20,
          3 => 10,
          _ => 0,
        };
    return RoundRewards(coins, xp);
  }
}

/// Player levels: XP needed to go from [level] to the next.
class Levels {
  const Levels._();

  static const int max = 99;

  static int xpToNext(int level) => 60 + level * 40;

  /// Coins for reaching [level].
  static int reward(int level) => 100 + level * 25;

  /// (level, xp into that level) for a lifetime XP total.
  static (int, int) fromTotal(int total) {
    var level = 1;
    var left = total;
    while (level < max && left >= xpToNext(level)) {
      left -= xpToNext(level);
      level++;
    }
    return (level, left);
  }
}

/// The lucky wheel's slices, clockwise from the top.
class Wheel {
  const Wheel._();

  static const List<int> prizes = [100, 50, 250, 75, 500, 150, 1000, 60];

  /// Relative odds of each slice; the jackpot is rare.
  static const List<int> weights = [18, 22, 9, 20, 4, 14, 1, 20];

  static int spin(Random rng) {
    final total = weights.reduce((a, b) => a + b);
    var roll = rng.nextInt(total);
    for (var i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) return i;
    }
    return 0;
  }
}
