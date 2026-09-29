import 'dart:math';

/// The numbers behind growing. Pure functions so balance changes are one
/// place and unit tested.
///
/// A monster's size is its *area* (radius squared); eating something adds
/// area, so growth slows naturally as a monster gets big.
class Growth {
  const Growth._();

  static const double startRadius = 20;

  /// A thing of eating radius `size` fits when `size <= radius * swallowRatio`.
  static const double swallowRatio = 0.7;

  /// A monster can eat another this many times smaller (by radius).
  static const double monsterEatRatio = 1.15;

  static const double personSize = 5;

  static double radius(double area) => sqrt(area);

  static double areaOf(double radius) => radius * radius;

  static bool canSwallow(double radius, double size) => size <= radius * swallowRatio;

  /// The radius at which something of [size] becomes edible.
  static double radiusToEat(double size) => size / swallowRatio;

  static bool canEatMonster(double eater, double victim) => eater >= victim * monsterEatRatio;

  /// Area gained from swallowing a thing of eating radius [size].
  static double gainFor(double size) => size * size * 0.25;

  /// Area gained from swallowing another monster.
  static double gainForMonster(double victimArea) => victimArea * 0.6;

  /// World units per second. Big monsters are slower, but not by much, so
  /// growing always feels like progress.
  static double speed(double radius) => 170 * pow(startRadius / radius, 0.2).toDouble();

  /// How much world fits across the screen's short side: the camera pulls
  /// back as the monster grows, but slower than it grows.
  static double viewSpan(double radius) => min(1500, 170 + radius * 7);

  /// Size as shown to the player, in metres (2.0 m at the start).
  static double metres(double radius) => radius / 10;
}
