import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/arena.dart';
import '../game/maps.dart';
import '../game/rewards.dart';
import '../game/skins.dart';
import '../game/upgrades.dart';
import 'live_config.dart';
import 'missions.dart';

/// What a finished round changed, for the results card.
class RoundRecord {
  const RoundRecord({
    required this.coins,
    required this.xp,
    required this.levelBefore,
    required this.levelAfter,
    required this.levelCoins,
    required this.newBest,
    required this.missionsMoved,
    required this.unlockedMaps,
  });

  final int coins, xp;
  final int levelBefore, levelAfter;

  /// Coins granted for levelling up.
  final int levelCoins;
  final bool newBest;
  final int missionsMoved;
  final List<MapDef> unlockedMaps;

  bool get levelledUp => levelAfter > levelBefore;
}

/// Everything that survives a restart: coins, XP, skins, upgrades, records,
/// missions, timers and settings. One [ChangeNotifier] the UI watches.
///
/// Saved key by key in SharedPreferences; [schema] is bumped (with a migration
/// in [_migrate]) whenever a key changes meaning.
class Progress extends ChangeNotifier {
  Progress(this._prefs, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _migrate();
    _load();
  }

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  static const int schema = 1;

  static Future<Progress> load() async => Progress(await SharedPreferences.getInstance());

  int coins = 0;
  int xpTotal = 0;
  String skinId = 'blob';
  Set<String> ownedSkins = {'blob'};

  /// Skin id -> rewarded videos watched toward it.
  final Map<String, int> skinVideos = {};
  final Map<String, int> upgradeLevels = {};
  String mapId = 'town';
  final Map<String, double> bestRadius = {};
  final Map<String, int> wins = {};
  int rounds = 0;
  int totalEaten = 0;
  bool tutorialDone = false;
  bool noAds = false;

  bool sound = true;
  bool music = true;
  bool haptics = true;

  /// Null follows the device language.
  String? localeCode;

  String? _dailyClaimedOn;
  int dailyStreak = 0;
  DateTime? _freeCoinsAt;
  DateTime? _wheelFreeAt;
  String? _wheelAdDay;
  int _wheelAdSpins = 0;

  String _missionDay = '';
  List<Mission> missions = [];
  bool missionBonusClaimed = false;
  bool missionRerolled = false;

  void _migrate() {
    final v = _prefs.getInt('schema') ?? 0;
    if (v < schema) _prefs.setInt('schema', schema);
  }

  void _load() {
    final p = _prefs;
    coins = p.getInt('coins') ?? 0;
    xpTotal = p.getInt('xp') ?? 0;
    ownedSkins = (p.getStringList('skins_owned') ?? ['blob']).toSet()..add('blob');
    skinId = p.getString('skin') ?? 'blob';
    if (!ownedSkins.contains(skinId)) skinId = 'blob';
    for (final s in skins) {
      final v = p.getInt('skin_videos_${s.id}');
      if (v != null) skinVideos[s.id] = v;
    }
    for (final u in upgrades) {
      upgradeLevels[u.id] = p.getInt('upgrade_${u.id}') ?? 0;
    }
    mapId = p.getString('map') ?? 'town';
    if (!isMapUnlocked(mapById(mapId))) mapId = 'town';
    for (final m in maps) {
      bestRadius[m.id] = p.getDouble('best_${m.id}') ?? 0;
      wins[m.id] = p.getInt('wins_${m.id}') ?? 0;
    }
    rounds = p.getInt('rounds') ?? 0;
    totalEaten = p.getInt('eaten_total') ?? 0;
    tutorialDone = p.getBool('tutorial_done') ?? false;
    noAds = p.getBool('no_ads') ?? false;
    sound = p.getBool('sound') ?? true;
    music = p.getBool('music') ?? true;
    haptics = p.getBool('haptics') ?? true;
    localeCode = p.getString('locale');
    _dailyClaimedOn = p.getString('daily_on');
    dailyStreak = p.getInt('daily_streak') ?? 0;
    _freeCoinsAt = _time(p.getInt('free_coins_at'));
    _wheelFreeAt = _time(p.getInt('wheel_free_at'));
    _wheelAdDay = p.getString('wheel_ad_day');
    _wheelAdSpins = p.getInt('wheel_ad_spins') ?? 0;
    _loadMissions();
  }

  static DateTime? _time(int? ms) => ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);

  static String dayOf(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _today => dayOf(_clock());

  // Level ---------------------------------------------------------------------

  int get level => Levels.fromTotal(xpTotal).$1;
  int get xpInLevel => Levels.fromTotal(xpTotal).$2;
  int get xpForNext => Levels.xpToNext(level);

  // Coins ---------------------------------------------------------------------

  void addCoins(int n) {
    if (n <= 0) return;
    coins += n;
    _prefs.setInt('coins', coins);
    notifyListeners();
  }

  bool _spend(int n) {
    if (coins < n) return false;
    coins -= n;
    _prefs.setInt('coins', coins);
    return true;
  }

  // Skins ---------------------------------------------------------------------

  SkinDef get skin => skinById(skinId);

  bool skinLevelOk(SkinDef s) => level >= s.unlockLevel;

  bool buySkin(SkinDef s) {
    if (ownedSkins.contains(s.id) || s.videos > 0 || !skinLevelOk(s)) return false;
    if (!_spend(s.price)) return false;
    _own(s);
    return true;
  }

  void _own(SkinDef s) {
    ownedSkins.add(s.id);
    skinId = s.id;
    _prefs
      ..setStringList('skins_owned', ownedSkins.toList())
      ..setString('skin', s.id);
    notifyListeners();
  }

  int videosFor(SkinDef s) => skinVideos[s.id] ?? 0;

  /// Counts one rewarded video toward a video skin; true once it unlocks.
  bool addSkinVideo(SkinDef s) {
    if (ownedSkins.contains(s.id) || s.videos == 0) return false;
    final n = videosFor(s) + 1;
    skinVideos[s.id] = n;
    _prefs.setInt('skin_videos_${s.id}', n);
    if (n >= s.videos) {
      _own(s);
      return true;
    }
    notifyListeners();
    return false;
  }

  void selectSkin(String id) {
    if (!ownedSkins.contains(id) || id == skinId) return;
    skinId = id;
    _prefs.setString('skin', id);
    notifyListeners();
  }

  // Upgrades ------------------------------------------------------------------

  int levelOf(UpgradeDef u) => upgradeLevels[u.id] ?? 0;

  Loadout get loadout => Loadout.fromLevels(upgradeLevels);

  bool buyUpgrade(UpgradeDef u) {
    final lv = levelOf(u);
    if (lv >= UpgradeDef.maxLevel) return false;
    if (!_spend(u.costAt(lv))) return false;
    upgradeLevels[u.id] = lv + 1;
    _prefs.setInt('upgrade_${u.id}', lv + 1);
    notifyListeners();
    return true;
  }

  // Maps ----------------------------------------------------------------------

  MapDef get map => mapById(mapId);

  bool isMapUnlocked(MapDef m) => level >= m.unlockLevel;

  void selectMap(String id) {
    final m = mapById(id);
    if (!isMapUnlocked(m) || id == mapId) return;
    mapId = id;
    _prefs.setString('map', id);
    notifyListeners();
  }

  // Rounds --------------------------------------------------------------------

  RoundRecord recordRound(RoundResult r) {
    final map = mapById(r.mapId);
    final rewards = RoundRewards.of(r, map, loadout);
    final lockedBefore = maps.where((m) => !isMapUnlocked(m)).toSet();
    final levelBefore = level;

    xpTotal += rewards.xp;
    final levelAfter = level;
    var levelCoins = 0;
    for (var l = levelBefore + 1; l <= levelAfter; l++) {
      levelCoins += Levels.reward(l);
    }
    coins += rewards.coins + levelCoins;
    rounds++;
    totalEaten += r.totalEaten;
    final newBest = r.maxRadius > (bestRadius[r.mapId] ?? 0) + 0.5;
    if (newBest) bestRadius[r.mapId] = r.maxRadius;
    if (r.won) wins[r.mapId] = (wins[r.mapId] ?? 0) + 1;

    _refreshMissions();
    var moved = 0;
    for (final m in missions) {
      if (m.apply(r)) moved++;
    }

    _prefs
      ..setInt('xp', xpTotal)
      ..setInt('coins', coins)
      ..setInt('rounds', rounds)
      ..setInt('eaten_total', totalEaten)
      ..setDouble('best_${r.mapId}', bestRadius[r.mapId]!)
      ..setInt('wins_${r.mapId}', wins[r.mapId] ?? 0);
    _saveMissions();
    notifyListeners();

    return RoundRecord(
      coins: rewards.coins,
      xp: rewards.xp,
      levelBefore: levelBefore,
      levelAfter: levelAfter,
      levelCoins: levelCoins,
      newBest: newBest,
      missionsMoved: moved,
      unlockedMaps: lockedBefore.where(isMapUnlocked).toList(),
    );
  }

  void completeTutorial() {
    if (tutorialDone) return;
    tutorialDone = true;
    _prefs.setBool('tutorial_done', true);
  }

  // Missions ------------------------------------------------------------------

  void _loadMissions() {
    _missionDay = _prefs.getString('missions_day') ?? '';
    missionBonusClaimed = _prefs.getBool('missions_bonus') ?? false;
    missionRerolled = _prefs.getBool('missions_rerolled') ?? false;
    try {
      final raw = _prefs.getString('missions');
      if (raw != null) {
        missions = [for (final j in jsonDecode(raw) as List) ?Mission.fromJson(j as Map<String, dynamic>)];
      }
    } catch (e) {
      debugPrint('Missions unreadable, regenerating: $e');
      missions = [];
    }
    _refreshMissions();
  }

  /// A new day brings new missions.
  void _refreshMissions() {
    final today = _today;
    if (_missionDay == today && missions.length == MissionBoard.perDay) return;
    _missionDay = today;
    missions = MissionBoard.generate(today, level);
    missionBonusClaimed = false;
    missionRerolled = false;
    _saveMissions();
  }

  void _saveMissions() {
    _prefs
      ..setString('missions_day', _missionDay)
      ..setString('missions', jsonEncode([for (final m in missions) m.toJson()]))
      ..setBool('missions_bonus', missionBonusClaimed)
      ..setBool('missions_rerolled', missionRerolled);
  }

  /// Call when a screen showing missions opens (the day may have turned).
  void checkDay() {
    final before = _missionDay;
    _refreshMissions();
    if (before != _missionDay) notifyListeners();
  }

  int get missionsClaimable => missions.where((m) => m.claimable).length + (missionBonusReady ? 1 : 0);

  bool get missionBonusReady => !missionBonusClaimed && missions.every((m) => m.claimed);

  int claimMission(int i) {
    final m = missions[i];
    if (!m.claimable) return 0;
    m.claimed = true;
    coins += m.reward;
    _prefs.setInt('coins', coins);
    _saveMissions();
    notifyListeners();
    return m.reward;
  }

  int claimMissionBonus() {
    if (!missionBonusReady) return 0;
    missionBonusClaimed = true;
    coins += MissionBoard.allDoneBonus;
    _prefs.setInt('coins', coins);
    _saveMissions();
    notifyListeners();
    return MissionBoard.allDoneBonus;
  }

  /// Swaps one unfinished mission for another (once a day, after a video).
  void rerollMission(int i) {
    if (missionRerolled || missions[i].claimed) return;
    missions[i] = MissionBoard.reroll(missions, i, level, _clock().millisecondsSinceEpoch);
    missionRerolled = true;
    _saveMissions();
    notifyListeners();
  }

  // Settings ------------------------------------------------------------------

  void setSound(bool v) {
    sound = v;
    _prefs.setBool('sound', v);
    notifyListeners();
  }

  void setMusic(bool v) {
    music = v;
    _prefs.setBool('music', v);
    notifyListeners();
  }

  void setHaptics(bool v) {
    haptics = v;
    _prefs.setBool('haptics', v);
    notifyListeners();
  }

  void setLocale(String? code) {
    localeCode = code;
    if (code == null) {
      _prefs.remove('locale');
    } else {
      _prefs.setString('locale', code);
    }
    notifyListeners();
  }

  void setNoAds() {
    if (noAds) return;
    noAds = true;
    _prefs.setBool('no_ads', true);
    notifyListeners();
  }

  // Daily gift ----------------------------------------------------------------

  bool dailyAvailable() => _dailyClaimedOn != _today;

  /// The streak day (1..7) today's gift would count as.
  int dailyDay() {
    final yesterday = dayOf(_clock().subtract(const Duration(days: 1)));
    return _dailyClaimedOn == yesterday ? (dailyStreak % 7) + 1 : 1;
  }

  static int dailyReward(int day) => const [100, 150, 200, 250, 300, 400, 750][day - 1];

  int claimDaily({bool doubled = false}) {
    if (!dailyAvailable()) return 0;
    final day = dailyDay();
    final amount = dailyReward(day) * (doubled ? 2 : 1);
    dailyStreak = day;
    _dailyClaimedOn = _today;
    coins += amount;
    _prefs
      ..setString('daily_on', _dailyClaimedOn!)
      ..setInt('daily_streak', dailyStreak)
      ..setInt('coins', coins);
    notifyListeners();
    return amount;
  }

  // Free coins (rewarded video) -------------------------------------------------

  Duration freeCoinsWait() {
    final at = _freeCoinsAt;
    if (at == null) return Duration.zero;
    final left = at.add(LiveConfig.instance.freeCoinsCooldown).difference(_clock());
    return left.isNegative ? Duration.zero : left;
  }

  int claimFreeCoins() {
    _freeCoinsAt = _clock();
    _prefs.setInt('free_coins_at', _freeCoinsAt!.millisecondsSinceEpoch);
    final n = LiveConfig.instance.freeCoinsAmount;
    addCoins(n);
    return n;
  }

  // Lucky wheel ------------------------------------------------------------------

  Duration wheelFreeWait() {
    final at = _wheelFreeAt;
    if (at == null) return Duration.zero;
    final left = at.add(LiveConfig.instance.wheelFreeEvery).difference(_clock());
    return left.isNegative ? Duration.zero : left;
  }

  bool get wheelFreeReady => wheelFreeWait() == Duration.zero;

  int get wheelAdSpinsLeft => _wheelAdDay == _today
      ? max(0, LiveConfig.instance.wheelAdSpins - _wheelAdSpins)
      : LiveConfig.instance.wheelAdSpins;

  /// Records a spin and pays out slice [index]. [ad] spins count toward the
  /// daily video limit instead of the free timer.
  int recordSpin(int index, {required bool ad}) {
    if (ad) {
      if (_wheelAdDay != _today) {
        _wheelAdDay = _today;
        _wheelAdSpins = 0;
      }
      _wheelAdSpins++;
      _prefs
        ..setString('wheel_ad_day', _wheelAdDay!)
        ..setInt('wheel_ad_spins', _wheelAdSpins);
    } else {
      _wheelFreeAt = _clock();
      _prefs.setInt('wheel_free_at', _wheelFreeAt!.millisecondsSinceEpoch);
    }
    final prize = Wheel.prizes[index];
    addCoins(prize);
    return prize;
  }

  // Purchases -------------------------------------------------------------------

  /// Purchase ids already paid out, so a store that re-delivers a purchase
  /// (it happens) never pays twice.
  bool purchaseDelivered(String purchaseId) => (_prefs.getStringList('iap_done') ?? const []).contains(purchaseId);

  void markPurchaseDelivered(String purchaseId) {
    final list = [...?_prefs.getStringList('iap_done'), purchaseId];
    _prefs.setStringList('iap_done', list.length > 100 ? list.sublist(list.length - 100) : list);
  }
}
