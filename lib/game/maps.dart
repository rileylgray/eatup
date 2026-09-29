import 'dart:ui' show Color;

/// What fills one city block. The generator (see `map_gen.dart`) turns each
/// kind into ground paint and a set of props.
enum BlockKind { houses, park, plaza, parking, market, sand, resort, field, farmyard, forest, cabins, downtown }

/// How the townsfolk dress on a map (see the people sprites in `atlas.dart`).
enum PeopleStyle { casual, beach, farm, winter, business }

class GroundPalette {
  const GroundPalette({
    required this.grass,
    required this.grassDark,
    required this.road,
    required this.roadLine,
    required this.sidewalk,
    required this.plaza,
    required this.water,
    required this.edge,
  });

  final Color grass, grassDark, road, roadLine, sidewalk, plaza, water, edge;
}

class MapDef {
  const MapDef({
    required this.id,
    required this.unlockLevel,
    required this.size,
    required this.rivals,
    required this.coinMult,
    required this.rivalSkill,
    required this.blocks,
    required this.ground,
    required this.people,
    this.sea = false,
    this.snow = false,
    this.movingCars = 14,
  });

  final String id;
  final int unlockLevel;

  /// The arena is a [size] x [size] square of world units.
  final double size;
  final int rivals;
  final double coinMult;

  /// 0..1: how quickly and cleverly the rival monsters play.
  final double rivalSkill;
  final Map<BlockKind, int> blocks;
  final GroundPalette ground;
  final PeopleStyle people;

  /// A strip of sea along the bottom edge (no monster can enter it).
  final bool sea;
  final bool snow;
  final int movingCars;

  /// Townsfolk kept on the map at once, scaled to its area.
  int get population => (size * size / 15000).round();
}

const maps = <MapDef>[
  MapDef(
    id: 'town',
    unlockLevel: 1,
    size: 2000,
    rivals: 6,
    coinMult: 1.0,
    rivalSkill: 0.25,
    people: PeopleStyle.casual,
    blocks: {BlockKind.houses: 5, BlockKind.park: 3, BlockKind.plaza: 1, BlockKind.parking: 1, BlockKind.market: 1},
    ground: GroundPalette(
      grass: Color(0xFF8FD16A),
      grassDark: Color(0xFF79BF57),
      road: Color(0xFF5E6474),
      roadLine: Color(0xFFF4E9B8),
      sidewalk: Color(0xFFD9D4CB),
      plaza: Color(0xFFE8DCC6),
      water: Color(0xFF5CC6E8),
      edge: Color(0xFF4F9A43),
    ),
  ),
  MapDef(
    id: 'beach',
    unlockLevel: 3,
    size: 2200,
    rivals: 7,
    coinMult: 1.25,
    rivalSkill: 0.4,
    people: PeopleStyle.beach,
    sea: true,
    blocks: {BlockKind.sand: 5, BlockKind.resort: 2, BlockKind.market: 2, BlockKind.park: 1, BlockKind.parking: 1},
    ground: GroundPalette(
      grass: Color(0xFFF3DDA2),
      grassDark: Color(0xFFE9CD88),
      road: Color(0xFF6A6F7E),
      roadLine: Color(0xFFFFFFFF),
      sidewalk: Color(0xFFF7EBD0),
      plaza: Color(0xFFF0C9A0),
      water: Color(0xFF3FC1E0),
      edge: Color(0xFF2A9CC8),
    ),
  ),
  MapDef(
    id: 'farm',
    unlockLevel: 6,
    size: 2400,
    rivals: 7,
    coinMult: 1.5,
    rivalSkill: 0.5,
    people: PeopleStyle.farm,
    movingCars: 10,
    blocks: {BlockKind.field: 4, BlockKind.farmyard: 3, BlockKind.forest: 2, BlockKind.houses: 1},
    ground: GroundPalette(
      grass: Color(0xFFA4D46B),
      grassDark: Color(0xFF8CC158),
      road: Color(0xFFC49A6C),
      roadLine: Color(0xFFD8B288),
      sidewalk: Color(0xFFB58B5E),
      plaza: Color(0xFFD7B98E),
      water: Color(0xFF6BC4E0),
      edge: Color(0xFF6E9E3F),
    ),
  ),
  MapDef(
    id: 'snow',
    unlockLevel: 10,
    size: 2400,
    rivals: 8,
    coinMult: 1.8,
    rivalSkill: 0.6,
    people: PeopleStyle.winter,
    snow: true,
    blocks: {BlockKind.cabins: 4, BlockKind.forest: 3, BlockKind.plaza: 2, BlockKind.parking: 1},
    ground: GroundPalette(
      grass: Color(0xFFF2F7FC),
      grassDark: Color(0xFFDCE8F4),
      road: Color(0xFF7D8595),
      roadLine: Color(0xFFE9EEF5),
      sidewalk: Color(0xFFC9D5E3),
      plaza: Color(0xFFE3EBF5),
      water: Color(0xFFA8DDF0),
      edge: Color(0xFFB4C8DC),
    ),
  ),
  MapDef(
    id: 'city',
    unlockLevel: 15,
    size: 2800,
    rivals: 8,
    coinMult: 2.2,
    rivalSkill: 0.75,
    people: PeopleStyle.business,
    movingCars: 22,
    blocks: {BlockKind.downtown: 5, BlockKind.plaza: 2, BlockKind.parking: 2, BlockKind.park: 2, BlockKind.market: 1},
    ground: GroundPalette(
      grass: Color(0xFF84C766),
      grassDark: Color(0xFF6FB454),
      road: Color(0xFF4B505E),
      roadLine: Color(0xFFFFD35C),
      sidewalk: Color(0xFFBFC3CB),
      plaza: Color(0xFFD5D0C8),
      water: Color(0xFF4FB6E0),
      edge: Color(0xFF3B404C),
    ),
  ),
];

MapDef mapById(String id) => maps.firstWhere((m) => m.id == id, orElse: () => maps.first);
