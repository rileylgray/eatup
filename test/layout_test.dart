import 'package:eatup/core/progress.dart';
import 'package:eatup/core/strings.dart';
import 'package:eatup/game/arena.dart';
import 'package:eatup/game/eat_game.dart';
import 'package:eatup/game/maps.dart';
import 'package:eatup/game/skins.dart';
import 'package:eatup/ui/eaten_panel.dart';
import 'package:eatup/ui/home_panel.dart';
import 'package:eatup/ui/hud.dart';
import 'package:eatup/ui/main_screen.dart';
import 'package:eatup/ui/maps_panel.dart';
import 'package:eatup/ui/missions_panel.dart';
import 'package:eatup/ui/pause_panel.dart';
import 'package:eatup/ui/results_panel.dart';
import 'package:eatup/ui/store_panel.dart';
import 'package:eatup/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every screen, at every size, in every language, must lay out without
/// overflow. Sizes: iPhone SE (1st gen), a tall Android, a large iPhone, an
/// iPad mini and a 12.9" iPad (all portrait, logical px).
const sizes = <String, Size>{
  'se': Size(320, 568),
  'tall': Size(360, 800),
  'pro max': Size(430, 932),
  'ipad mini': Size(744, 1133),
  'ipad pro': Size(1024, 1366),
};

Future<Progress> _progress({bool rich = false}) async {
  SharedPreferences.setMockInitialValues(
    rich
        ? {
            'coins': 1234567,
            'xp': 99999,
            'rounds': 500,
            'tutorial_done': true,
            'skins_owned': ['blob', 'grape', 'king'],
            'best_town': 188.0,
            'wins_town': 1234,
            'daily_on': '2000-01-01',
          }
        : {},
  );
  return Progress.load();
}

Widget _wrap(Progress p, String lang, Widget child) {
  return ChangeNotifierProvider.value(
    value: p,
    child: MaterialApp(
      theme: buildTheme(),
      locale: Locale(lang),
      supportedLocales: [for (final c in Strings.languages) Locale(c)],
      localizationsDelegates: const [
        Strings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(backgroundColor: const Color(0xFF3B6FB6), body: child),
    ),
  );
}

const _bigResult = RoundResult(
  mapId: 'town',
  rank: 9,
  players: 9,
  maxRadius: 1888,
  people: 88888,
  props: 88888,
  vehicles: 888,
  buildings: 888,
  monsters: 888,
  eatenBy: 'Jellybelly',
);

void main() {
  final panels = <String, Widget Function(Progress)>{
    'home': (_) => HomePanel(onPlay: () {}, onStore: (_) {}, onMaps: () {}, onMissions: () {}),
    'store skins': (_) => StorePanel(onClose: () {}),
    'store upgrades': (_) => StorePanel(onClose: () {}, initialTab: StoreTab.upgrades),
    'store coins': (_) => StorePanel(onClose: () {}, initialTab: StoreTab.coins),
    'maps': (_) => MapsPanel(onClose: () {}),
    'missions': (_) => MissionsPanel(onClose: () {}),
    'pause': (_) => PausePanel(onResume: () {}, onLeave: () {}),
    'eaten': (p) => EatenPanel(eaterName: 'Jellybelly', skin: p.skin, onRevive: () async {}, onDecline: () {}),
    'results': (p) => ResultsPanel(
      result: _bigResult,
      record: RoundRecord(
        coins: 123456,
        xp: 9999,
        levelBefore: 1,
        levelAfter: 99,
        levelCoins: 99999,
        newBest: true,
        missionsMoved: 3,
        unlockedMaps: maps.sublist(1),
      ),
      onAgain: () {},
      onHome: () {},
    ),
    'results won': (p) => ResultsPanel(
      result: const RoundResult(
        mapId: 'town',
        rank: 1,
        players: 9,
        maxRadius: 88,
        people: 12,
        props: 34,
        vehicles: 1,
        buildings: 0,
        monsters: 0,
        eatenBy: null,
      ),
      record: const RoundRecord(
        coins: 88,
        xp: 50,
        levelBefore: 3,
        levelAfter: 3,
        levelCoins: 0,
        newBest: false,
        missionsMoved: 0,
        unlockedMaps: [],
      ),
      onAgain: () {},
      onHome: () {},
    ),
    'hud': (p) {
      final game = EatGame();
      game.hud.value = HudState(
        timeLeft: 599,
        radius: 1888,
        rank: 9,
        speedT: 3,
        magnetT: 3,
        frenzyT: 3,
        phase: RoundPhase.playing,
        standings: [
          for (var i = 0; i < 9; i++)
            Standing(i == 8 ? 'You' : 'Jellybelly', 1888, skins[i].body, isPlayer: i == 8, alive: i.isEven),
        ],
      );
      return Hud(
        game: game,
        toast: ValueNotifier(HudToast(Strings('de').hintBuilding * 2, icon: Icons.apartment_rounded)),
        onPause: () {},
      );
    },
  };

  for (final lang in Strings.languages) {
    for (final size in sizes.entries) {
      for (final panel in panels.entries) {
        testWidgets('$lang ${size.key} ${panel.key}', (tester) async {
          tester.view.physicalSize = size.value * 3;
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          final p = await _progress(rich: panel.key != 'home' || lang == 'de');
          await tester.pumpWidget(_wrap(p, lang, panel.value(p)));
          // Localizations load async, so the panel builds on the first pump.
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));
          expect(tester.takeException(), isNull);
          // Let panels with timers (toasts, countdowns) wind down.
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 8));
        });
      }
    }
  }
}
