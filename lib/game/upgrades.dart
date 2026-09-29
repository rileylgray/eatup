/// A permanent monster upgrade bought with coins, levelled 0..[maxLevel].
class UpgradeDef {
  const UpgradeDef(this.id, this.baseCost);

  final String id;
  final int baseCost;

  static const int maxLevel = 10;

  /// Cost of going from [level] to level + 1.
  int costAt(int level) {
    const curve = [1.0, 1.8, 2.9, 4.4, 6.3, 8.7, 11.6, 15.0, 19.0, 24.0];
    return (baseCost * curve[level] / 5).round() * 5;
  }
}

const List<UpgradeDef> upgrades = [
  UpgradeDef('size', 120),
  UpgradeDef('speed', 100),
  UpgradeDef('time', 110),
  UpgradeDef('reach', 90),
  UpgradeDef('coins', 130),
];

UpgradeDef upgradeById(String id) => upgrades.firstWhere((u) => u.id == id);

/// Everything a round needs to know about the player's monster once every
/// upgrade is stacked.
class Loadout {
  const Loadout({
    this.startRadius = 20,
    this.speedMult = 1,
    this.extraSeconds = 0,
    this.reach = 1.3,
    this.coinMult = 1,
  });

  final double startRadius;
  final double speedMult;
  final int extraSeconds;

  /// Things within `radius * reach` get sucked toward the mouth.
  final double reach;
  final double coinMult;

  factory Loadout.fromLevels(Map<String, int> levels) {
    int lv(String id) => levels[id] ?? 0;
    return Loadout(
      startRadius: 20 * (1 + lv('size') * 0.04),
      speedMult: 1 + lv('speed') * 0.03,
      extraSeconds: lv('time') * 5,
      reach: 1.3 + lv('reach') * 0.06,
      coinMult: 1 + lv('coins') * 0.1,
    );
  }
}
