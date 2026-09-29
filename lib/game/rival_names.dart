import 'dart:math';

/// Names for the rival monsters. Silly, short and the same in every language
/// (they read as names, not words).
class RivalNames {
  const RivalNames._();

  static const List<String> all = [
    'Chompy',
    'Gulpzilla',
    'Munchkin',
    'Nom Nom',
    'Blobby',
    'Snacky',
    'Burpo',
    'Gobbles',
    'Mr. Munch',
    'Crumbs',
    'Yumbo',
    'Slurp',
    'Big Tum',
    'Nibbles',
    'Grubby',
    'Mawzilla',
    'Snorf',
    'Jellybelly',
    'Fuzzball',
    'Gloop',
    'Mochi',
    'Tofu',
    'Pudding',
    'Wobbles',
    'Bubbles',
    'Dumpling',
    'Noodle',
    'Waffles',
    'Pickles',
    'Meatball',
    'Crunchy',
    'Glutton',
  ];

  static List<String> pick(Random rng, int n) => ([...all]..shuffle(rng)).take(n).toList();
}
