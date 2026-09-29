import 'dart:math';

import '../game/arena.dart';

enum MissionKind { eatPeople, eatProps, eatVehicles, eatBuildings, eatRivals, winRounds, top3, playRounds, reachSize }

/// One daily mission. Progress adds up over every round played that day,
/// except [MissionKind.reachSize], which is a best-in-one-round.
class Mission {
  Mission(this.kind, this.target, this.reward, {this.progress = 0, this.claimed = false});

  final MissionKind kind;
  final int target;
  final int reward;
  int progress;
  bool claimed;

  bool get done => progress >= target;
  bool get claimable => done && !claimed;
  double get fraction => (progress / target).clamp(0, 1);

  /// Folds a finished round into this mission. Returns true if it moved.
  bool apply(RoundResult r) {
    if (claimed || done) return false;
    final before = progress;
    switch (kind) {
      case MissionKind.eatPeople:
        progress += r.people;
      case MissionKind.eatProps:
        progress += r.props;
      case MissionKind.eatVehicles:
        progress += r.vehicles;
      case MissionKind.eatBuildings:
        progress += r.buildings;
      case MissionKind.eatRivals:
        progress += r.monsters;
      case MissionKind.winRounds:
        if (r.won) progress++;
      case MissionKind.top3:
        if (r.rank <= 3) progress++;
      case MissionKind.playRounds:
        progress++;
      case MissionKind.reachSize:
        progress = max(progress, r.maxRadius.floor());
    }
    progress = min(progress, target);
    return progress != before;
  }

  Map<String, Object> toJson() => {'k': kind.name, 't': target, 'r': reward, 'p': progress, 'c': claimed};

  static Mission? fromJson(Map<String, dynamic> j) {
    final kind = MissionKind.values.where((k) => k.name == j['k']).firstOrNull;
    if (kind == null) return null;
    return Mission(
      kind,
      j['t'] as int,
      j['r'] as int,
      progress: j['p'] as int? ?? 0,
      claimed: j['c'] as bool? ?? false,
    );
  }
}

/// Three missions a day, the same for everyone on the same day and level
/// band (seeded by date), sized to the player's level.
class MissionBoard {
  const MissionBoard._();

  static const int perDay = 3;
  static const int allDoneBonus = 300;

  static Mission make(MissionKind kind, int level, Random rng) {
    final l = level.clamp(1, 60);
    int t;
    switch (kind) {
      case MissionKind.eatPeople:
        t = 150 + l * 15;
      case MissionKind.eatProps:
        t = 120 + l * 12;
      case MissionKind.eatVehicles:
        t = 8 + l;
      case MissionKind.eatBuildings:
        t = 3 + l ~/ 3;
      case MissionKind.eatRivals:
        t = 2 + l ~/ 5;
      case MissionKind.winRounds:
        t = 1 + l ~/ 12;
      case MissionKind.top3:
        t = 2 + l ~/ 10;
      case MissionKind.playRounds:
        t = 4 + rng.nextInt(3);
      case MissionKind.reachSize:
        t = min(130, 45 + l * 3);
    }
    // Round counts stay readable.
    if (t > 50) t = (t / 10).round() * 10;
    final reward = ((80 + l * 12) * (0.9 + rng.nextDouble() * 0.4) / 10).round() * 10;
    return Mission(kind, t, reward);
  }

  static List<Mission> generate(String day, int level) {
    final rng = Random(day.hashCode ^ (level ~/ 3));
    final kinds = [...MissionKind.values];
    // Rival and building missions only once the player can realistically do
    // them.
    if (level < 3) kinds.removeWhere((k) => k == MissionKind.eatBuildings || k == MissionKind.eatRivals);
    kinds.shuffle(rng);
    return [for (final k in kinds.take(perDay)) make(k, level, rng)];
  }

  /// A different mission of a kind not already on the board.
  static Mission reroll(List<Mission> board, int index, int level, int salt) {
    final rng = Random(salt);
    final used = board.map((m) => m.kind).toSet();
    final kinds = MissionKind.values.where((k) => !used.contains(k)).toList()..shuffle(rng);
    return make(kinds.first, level, rng);
  }
}
