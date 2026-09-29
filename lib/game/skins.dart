import 'dart:ui' show Color;

/// A decoration drawn on top of the monster's body (see `monster_art.dart`).
enum SkinFeature { none, ears, horns, spikes, antenna, crown, teeth, spots, stars, ghost, flames, bow, rainbow }

/// A monster look. Bought with coins once the player is [unlockLevel], or,
/// when [videos] > 0, unlocked by watching that many rewarded videos.
class SkinDef {
  const SkinDef({
    required this.id,
    required this.body,
    required this.shade,
    required this.belly,
    this.feature = SkinFeature.none,
    this.price = 0,
    this.unlockLevel = 1,
    this.videos = 0,
  });

  final String id;
  final Color body, shade, belly;
  final SkinFeature feature;
  final int price;
  final int unlockLevel;
  final int videos;

  bool get free => price == 0 && videos == 0;
}

const skins = <SkinDef>[
  SkinDef(id: 'blob', body: Color(0xFF6BD66B), shade: Color(0xFF3E9E4A), belly: Color(0xFFC8F2B0)),
  SkinDef(
    id: 'grape',
    body: Color(0xFFA774E8),
    shade: Color(0xFF6D43B0),
    belly: Color(0xFFE2CCFF),
    feature: SkinFeature.antenna,
    price: 300,
  ),
  SkinDef(
    id: 'fluffy',
    body: Color(0xFFFF8FC0),
    shade: Color(0xFFD65A92),
    belly: Color(0xFFFFD8E8),
    feature: SkinFeature.ears,
    price: 600,
    unlockLevel: 2,
  ),
  SkinDef(
    id: 'chomper',
    body: Color(0xFFFF9A3D),
    shade: Color(0xFFD0641A),
    belly: Color(0xFFFFE0B0),
    feature: SkinFeature.teeth,
    price: 900,
    unlockLevel: 3,
  ),
  SkinDef(
    id: 'rainbow',
    body: Color(0xFF7FD3FF),
    shade: Color(0xFF4A8FD8),
    belly: Color(0xFFFFFFFF),
    feature: SkinFeature.rainbow,
    videos: 5,
  ),
  SkinDef(
    id: 'frosty',
    body: Color(0xFF8FE3F5),
    shade: Color(0xFF4FA8CF),
    belly: Color(0xFFE6FAFF),
    feature: SkinFeature.spikes,
    price: 1500,
    unlockLevel: 5,
  ),
  SkinDef(
    id: 'devil',
    body: Color(0xFFF0524F),
    shade: Color(0xFFB02A35),
    belly: Color(0xFFFFC2B5),
    feature: SkinFeature.horns,
    price: 2500,
    unlockLevel: 7,
  ),
  SkinDef(
    id: 'ghost',
    body: Color(0xFFF4F1FF),
    shade: Color(0xFFB9B0E0),
    belly: Color(0xFFFFFFFF),
    feature: SkinFeature.ghost,
    price: 3500,
    unlockLevel: 9,
  ),
  SkinDef(
    id: 'robo',
    body: Color(0xFFB8C4D4),
    shade: Color(0xFF6F7F96),
    belly: Color(0xFFE4EAF2),
    feature: SkinFeature.antenna,
    price: 5000,
    unlockLevel: 11,
  ),
  SkinDef(
    id: 'toxic',
    body: Color(0xFFB6F03C),
    shade: Color(0xFF6FA81E),
    belly: Color(0xFFEFFFB8),
    feature: SkinFeature.spots,
    price: 6500,
    unlockLevel: 13,
  ),
  SkinDef(
    id: 'lava',
    body: Color(0xFF3A2A33),
    shade: Color(0xFF1E151B),
    belly: Color(0xFFFF8A3D),
    feature: SkinFeature.flames,
    price: 8000,
    unlockLevel: 16,
  ),
  SkinDef(
    id: 'galaxy',
    body: Color(0xFF3B3A8C),
    shade: Color(0xFF1F1E57),
    belly: Color(0xFF8C7BFF),
    feature: SkinFeature.stars,
    price: 10000,
    unlockLevel: 19,
  ),
  SkinDef(
    id: 'bowtie',
    body: Color(0xFFFFD35C),
    shade: Color(0xFFE09A1B),
    belly: Color(0xFFFFF3C4),
    feature: SkinFeature.bow,
    videos: 12,
    unlockLevel: 8,
  ),
  SkinDef(
    id: 'king',
    body: Color(0xFFFFC94A),
    shade: Color(0xFFC98A12),
    belly: Color(0xFFFFF0B8),
    feature: SkinFeature.crown,
    price: 18000,
    unlockLevel: 25,
  ),
];

SkinDef skinById(String id) => skins.firstWhere((s) => s.id == id, orElse: () => skins.first);

/// Looks the rival monsters wear (never the player's current skin).
const rivalSkinIds = ['grape', 'fluffy', 'chomper', 'frosty', 'devil', 'toxic', 'robo', 'ghost', 'galaxy', 'lava'];

/// Display names: they're names, so the same in every language.
const Map<String, String> skinNames = {
  'blob': 'Blobby',
  'grape': 'Grapey',
  'fluffy': 'Fluffy',
  'chomper': 'Chomper',
  'rainbow': 'Rainbow',
  'frosty': 'Frosty',
  'devil': 'Imp',
  'ghost': 'Boo',
  'robo': 'Robo',
  'toxic': 'Goo',
  'lava': 'Magma',
  'galaxy': 'Cosmo',
  'bowtie': 'Dapper',
  'king': 'King Chomp',
};
