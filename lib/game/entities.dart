import 'dart:math';

import 'growth.dart';
import 'props.dart';
import 'skins.dart';

/// Anything a monster can swallow. [size] is its eating radius.
abstract class Food {
  Food(this.x, this.y, this.size);

  double x, y;
  final double size;
  bool alive = true;
}

class Person extends Food {
  Person(double x, double y, {required this.variant, required this.phase}) : super(x, y, Growth.personSize);

  /// Which outfit sprite (0..[peopleVariants]).
  final int variant;
  double vx = 0, vy = 0;
  double tx = 0, ty = 0;
  double idle = 0;

  /// Seconds left of running scared after the last threat.
  double panic = 0;

  /// Walk-cycle phase, advanced by distance walked.
  double phase;
}

const int peopleVariants = 6;

class Prop extends Food {
  Prop(double x, double y, this.kind, {this.variant = 0, this.angle = 0}) : super(x, y, kind.size);

  final PropKind kind;
  final int variant;
  double angle;

  /// Vehicles that drive the roads (see [Arena]); null for parked ones.
  Drive? drive;
}

/// A vehicle's route state: which way it is heading along the road grid.
class Drive {
  Drive(this.dir, this.speed);

  /// 0: +x, 1: +y, 2: -x, 3: -y.
  int dir;
  final double speed;

  /// The last intersection it decided at, so it decides once per crossing.
  int lastCross = -1;
}

enum PowerKind { speed, magnet, frenzy }

class PowerUp extends Food {
  PowerUp(double x, double y, this.kind) : super(x, y, 9);

  final PowerKind kind;
  double age = 0;
  static const double lifetime = 25;
}

/// Something on its way down a monster's throat (for the swallow animation).
class Swallow {
  Swallow(this.food, this.eater, this.dx, this.dy);

  final Food food;
  final Monster eater;

  /// Offset from the eater's centre when swallowed.
  final double dx, dy;
  double t = 0;
  static const double duration = 0.28;
}

class Monster {
  Monster({
    required this.id,
    required this.name,
    required this.skin,
    required this.x,
    required this.y,
    required double radius,
    this.isPlayer = false,
    this.reach = 1.25,
    this.speedMult = 1,
  }) : area = radius * radius,
       maxArea = radius * radius,
       startArea = radius * radius;

  final int id;
  final String name;
  final SkinDef skin;
  final bool isPlayer;
  double x, y;
  double vx = 0, vy = 0;

  /// Facing, for the eyes: a unit vector.
  double fx = 0, fy = 1;
  double area;
  double maxArea;
  final double startArea;
  double reach;
  double speedMult;

  bool alive = true;
  double respawnIn = 0;

  /// Seconds of spawn protection left (can't be eaten, drawn blinking).
  double shield = 0;

  // Power-ups: seconds left.
  double speedT = 0, magnetT = 0, frenzyT = 0;

  // Animation.
  double chomp = 0;
  double wobble = Random().nextDouble() * 10;
  double blink = 2 + Random().nextDouble() * 3;
  double squash = 0;

  // Stats for the round.
  int people = 0, props = 0, vehicles = 0, buildings = 0, monsters = 0;

  // AI.
  double think = 0;
  double tx = 0, ty = 0;
  Monster? chasing;

  /// Seconds spent pressed against something solid without getting anywhere.
  double blocked = 0;

  double get r => sqrt(area);

  double get effectiveReach => reach + (magnetT > 0 ? 1.2 : 0);

  void grow(double gain) {
    area += gain * (frenzyT > 0 ? 2 : 1);
    if (area > maxArea) maxArea = area;
    squash = 1;
  }
}
