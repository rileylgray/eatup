import 'dart:math';

import 'package:eatup/core/ads/ad_manager.dart';
import 'package:eatup/core/missions.dart';
import 'package:eatup/core/progress.dart';
import 'package:eatup/core/strings.dart';
import 'package:eatup/game/arena.dart';
import 'package:eatup/game/maps.dart';
import 'package:eatup/game/rewards.dart';
import 'package:eatup/game/skins.dart';
import 'package:eatup/game/upgrades.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

RoundResult _round({int rank = 3, int people = 50, int props = 40, double radius = 50, int monsters = 0}) =>
    RoundResult(
      mapId: 'town',
      rank: rank,
      players: 7,
      maxRadius: radius,
      people: people,
      props: props,
      vehicles: 3,
      buildings: 1,
      monsters: monsters,
      eatenBy: null,
    );

void main() {
  late DateTime now;
  Future<Progress> load([Map<String, Object> save = const {}]) async {
    SharedPreferences.setMockInitialValues(save);
    return Progress(await SharedPreferences.getInstance(), clock: () => now);
  }

  setUp(() => now = DateTime(2026, 9, 29, 12));

  group('Progress', () {
    test('a fresh save starts with the free skin on the first map', () async {
      final p = await load();
      expect(p.coins, 0);
      expect(p.level, 1);
      expect(p.skinId, 'blob');
      expect(p.mapId, 'town');
      expect(p.missions, hasLength(MissionBoard.perDay));
    });

    test('rounds pay coins and XP, and level ups pay and unlock maps', () async {
      final p = await load();
      final beach = mapById('beach');
      expect(p.isMapUnlocked(beach), isFalse);
      var unlocked = false;
      for (var i = 0; i < 30 && !unlocked; i++) {
        final r = p.recordRound(_round(rank: 1, people: 120, props: 90));
        expect(r.coins, greaterThan(0));
        unlocked = r.unlockedMaps.contains(beach);
      }
      expect(unlocked, isTrue);
      expect(p.level, greaterThanOrEqualTo(beach.unlockLevel));
      expect(p.wins['town'], greaterThan(0));
    });

    test('bests only go up', () async {
      final p = await load();
      expect(p.recordRound(_round(radius: 60)).newBest, isTrue);
      expect(p.recordRound(_round(radius: 40)).newBest, isFalse);
      expect(p.bestRadius['town'], 60);
    });

    test('skins cost coins and need the level', () async {
      final p = await load({'coins': 100000});
      final king = skinById('king');
      expect(p.buySkin(king), isFalse, reason: 'level too low');
      final grape = skinById('grape');
      expect(p.buySkin(grape), isTrue);
      expect(p.skinId, 'grape');
      expect(p.coins, 100000 - grape.price);
      expect(p.buySkin(grape), isFalse, reason: 'already owned');
    });

    test('video skins unlock after enough videos', () async {
      final p = await load();
      final rainbow = skinById('rainbow');
      for (var i = 0; i < rainbow.videos - 1; i++) {
        expect(p.addSkinVideo(rainbow), isFalse);
      }
      expect(p.addSkinVideo(rainbow), isTrue);
      expect(p.ownedSkins, contains('rainbow'));
    });

    test('upgrades cost more each level and stop at max', () async {
      final p = await load({'coins': 10000000});
      final u = upgradeById('speed');
      var last = 0;
      for (var i = 0; i < UpgradeDef.maxLevel; i++) {
        expect(u.costAt(i), greaterThan(last));
        last = u.costAt(i);
        expect(p.buyUpgrade(u), isTrue);
      }
      expect(p.buyUpgrade(u), isFalse);
      expect(p.loadout.speedMult, greaterThan(1.2));
    });

    test('the daily gift streak continues day to day and resets after a gap', () async {
      final p = await load();
      expect(p.claimDaily(), Progress.dailyReward(1));
      expect(p.dailyAvailable(), isFalse);
      now = now.add(const Duration(days: 1));
      expect(p.dailyDay(), 2);
      expect(p.claimDaily(doubled: true), Progress.dailyReward(2) * 2);
      now = now.add(const Duration(days: 3));
      expect(p.dailyDay(), 1);
    });

    test('the wheel has a free spin on a timer and a few video spins a day', () async {
      final p = await load();
      expect(p.wheelFreeReady, isTrue);
      p.recordSpin(0, ad: false);
      expect(p.wheelFreeReady, isFalse);
      now = now.add(const Duration(hours: 7));
      expect(p.wheelFreeReady, isTrue);
      final left = p.wheelAdSpinsLeft;
      p.recordSpin(1, ad: true);
      expect(p.wheelAdSpinsLeft, left - 1);
      now = now.add(const Duration(days: 1));
      expect(p.wheelAdSpinsLeft, left);
    });

    test('missions progress over rounds, pay once, then the bonus', () async {
      final p = await load();
      // Force a board we know.
      p.missions
        ..clear()
        ..addAll([
          Mission(MissionKind.playRounds, 2, 100),
          Mission(MissionKind.eatPeople, 60, 100),
          Mission(MissionKind.reachSize, 45, 100),
        ]);
      p.recordRound(_round(people: 30, radius: 30));
      expect(p.missions[0].progress, 1);
      expect(p.missions[2].progress, 30, reason: 'best in one round, not a sum');
      p.recordRound(_round(people: 30, radius: 50));
      expect(p.missions.every((m) => m.done), isTrue);
      final before = p.coins;
      for (var i = 0; i < 3; i++) {
        expect(p.claimMission(i), 100);
        expect(p.claimMission(i), 0);
      }
      expect(p.missionBonusReady, isTrue);
      expect(p.claimMissionBonus(), MissionBoard.allDoneBonus);
      expect(p.coins, before + 300 + MissionBoard.allDoneBonus);
    });

    test('missions survive a restart and roll over at midnight', () async {
      final p = await load();
      final kinds = p.missions.map((m) => m.kind).toList();
      final prefs = await SharedPreferences.getInstance();
      final again = Progress(prefs, clock: () => now);
      expect(again.missions.map((m) => m.kind), kinds);
      now = now.add(const Duration(days: 1));
      again.checkDay();
      expect(again.missions, hasLength(MissionBoard.perDay));
    });

    test('a re-delivered purchase is recognised', () async {
      final p = await load();
      expect(p.purchaseDelivered('GPA.1'), isFalse);
      p.markPurchaseDelivered('GPA.1');
      expect(p.purchaseDelivered('GPA.1'), isTrue);
    });
  });

  group('Rewards', () {
    test('a better rank pays more', () {
      final l = const Loadout();
      final map = maps.first;
      expect(
        RoundRewards.of(_round(rank: 1), map, l).coins,
        greaterThan(RoundRewards.of(_round(rank: 5), map, l).coins),
      );
      expect(
        RoundRewards.of(_round(rank: 1), maps.last, l).coins,
        greaterThan(RoundRewards.of(_round(rank: 1), map, l).coins),
      );
    });

    test('levels need more XP as they go', () {
      expect(Levels.xpToNext(10), greaterThan(Levels.xpToNext(1)));
      expect(Levels.fromTotal(0), (1, 0));
      expect(Levels.fromTotal(Levels.xpToNext(1)), (2, 0));
    });

    test('the wheel pays every slice and the jackpot is rare', () {
      final rng = Random(1);
      final hits = List.filled(Wheel.prizes.length, 0);
      for (var i = 0; i < 20000; i++) {
        hits[Wheel.spin(rng)]++;
      }
      expect(hits.every((h) => h > 0), isTrue);
      final jackpot = Wheel.prizes.indexOf(1000);
      expect(hits[jackpot] / 20000, lessThan(0.02));
    });
  });

  group('Missions', () {
    test('boards are stable for a day and sized to the level', () {
      final a = MissionBoard.generate('2026-09-29', 5);
      final b = MissionBoard.generate('2026-09-29', 5);
      expect(a.map((m) => m.kind), b.map((m) => m.kind));
      expect(a.map((m) => m.kind).toSet(), hasLength(3));
      final low = MissionBoard.make(MissionKind.eatPeople, 1, Random(1));
      final high = MissionBoard.make(MissionKind.eatPeople, 30, Random(1));
      expect(high.target, greaterThan(low.target));
    });

    test('new players never get missions they cannot do yet', () {
      for (var d = 1; d <= 28; d++) {
        final board = MissionBoard.generate('2026-02-${d.toString().padLeft(2, '0')}', 1);
        expect(board.map((m) => m.kind), isNot(contains(MissionKind.eatRivals)));
        expect(board.map((m) => m.kind), isNot(contains(MissionKind.eatBuildings)));
      }
    });

    test('a swap gives a different kind', () {
      final board = MissionBoard.generate('2026-09-29', 5);
      final swapped = MissionBoard.reroll(board, 0, 5, 42);
      expect(board.map((m) => m.kind), isNot(contains(swapped.kind)));
    });
  });

  group('InterstitialPacer', () {
    test('never in the grace rounds or the session warm-up, then spaced out', () {
      var t = DateTime(2026);
      final pacer = InterstitialPacer(clock: () => t);
      pacer.onRound();
      expect(pacer.shouldShow(lifetimeRounds: 1), isFalse, reason: 'grace');
      expect(pacer.shouldShow(lifetimeRounds: 10), isFalse, reason: 'warm-up');
      t = t.add(const Duration(seconds: 61));
      expect(pacer.shouldShow(lifetimeRounds: 10), isTrue);
      pacer.onFullScreenShown();
      pacer.onRound();
      t = t.add(const Duration(seconds: 30));
      expect(pacer.shouldShow(lifetimeRounds: 11), isFalse, reason: 'min gap');
      t = t.add(const Duration(seconds: 61));
      expect(pacer.shouldShow(lifetimeRounds: 11), isTrue);
    });
  });

  group('Strings', () {
    test('every row has every language', () {
      Strings.table.forEach((key, row) {
        expect(row, hasLength(Strings.languages.length), reason: key);
        for (final v in row) {
          expect(v.trim(), isNotEmpty, reason: key);
        }
      });
    });

    test('every content id has a name', () {
      for (final lang in Strings.languages) {
        final s = Strings(lang);
        for (final m in maps) {
          expect(s.mapName(m.id), isNot(startsWith('map_')));
        }
        for (final u in upgrades) {
          expect(s.upgradeName(u.id), isNot(startsWith('up_')));
          expect(s.upgradeDesc(u.id), isNot(startsWith('updesc_')));
        }
        for (final k in MissionKind.values) {
          expect(s.mission(k.name, 10), contains(k == MissionKind.reachSize ? '1.0' : '10'));
        }
      }
      for (final sk in skins) {
        expect(skinNames[sk.id], isNotNull, reason: sk.id);
      }
    });

    test('placeholders survive translation', () {
      for (final lang in Strings.languages) {
        final s = Strings(lang);
        expect(s.eatenBy('Zed'), contains('Zed'));
        expect(s.place(3, 9), allOf(contains('3'), contains('9')));
        expect(s.freeSpinIn('1:00'), contains('1:00'));
        expect(s.levelUp(7), contains('7'));
      }
    });
  });
}
