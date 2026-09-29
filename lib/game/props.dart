/// Everything edible that isn't a person: street furniture, trees, cars and
/// buildings. Kept free of Flutter so the simulation can be unit tested.
///
/// [size] is the prop's eating radius in world units: a monster whose radius
/// is at least [size] / [Growth.swallowRatio] can swallow it. The sprite is
/// drawn in a box of [size] * 2 * [spriteScale].
enum PropKind {
  // Tiny: anything can eat these from the start.
  cone(4.5, PropTier.tiny),
  hydrant(5, PropTier.tiny),
  trash(5.5, PropTier.tiny),
  mailbox(5.5, PropTier.tiny),
  pumpkin(5.5, PropTier.tiny),
  flowers(7, PropTier.tiny),
  crate(7, PropTier.tiny),
  lamp(6, PropTier.tiny, layer: 1),
  // Small.
  bench(10, PropTier.small),
  bush(10, PropTier.small),
  rock(10, PropTier.small),
  snowman(10, PropTier.small),
  surfboard(10, PropTier.small),
  sled(10, PropTier.small),
  hay(11, PropTier.small),
  umbrella(13, PropTier.small, layer: 1),
  sandcastle(12, PropTier.small),
  cow(13, PropTier.small),
  // Medium.
  tree(17, PropTier.medium, layer: 1),
  pine(16, PropTier.medium, layer: 1),
  palm(17, PropTier.medium, layer: 1),
  car(19, PropTier.medium, vehicle: true),
  taxi(19, PropTier.medium, vehicle: true),
  kiosk(22, PropTier.medium),
  tractor(22, PropTier.medium, vehicle: true),
  // Large.
  bus(30, PropTier.large, vehicle: true),
  fountain(30, PropTier.large),
  hut(28, PropTier.large),
  silo(28, PropTier.large),
  // Buildings.
  house(42, PropTier.building),
  cabin(42, PropTier.building),
  shop(48, PropTier.building),
  barn(55, PropTier.building),
  hotel(62, PropTier.building),
  tower(72, PropTier.building);

  const PropKind(this.size, this.tier, {this.layer = 0, this.vehicle = false});

  final double size;
  final PropTier tier;

  /// 0 draws under people, 1 (canopies, lamps, umbrellas) over them.
  final int layer;

  /// Counts toward the "eat vehicles" missions.
  final bool vehicle;

  bool get building => tier == PropTier.building;
}

enum PropTier { tiny, small, medium, large, building }

/// Pixels per world unit in the sprite atlas. Sprites are drawn once at this
/// scale and then batched, so this trades memory for crispness when zoomed in.
const double spriteScale = 2.5;
