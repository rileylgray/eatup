// Drives the real app through its main flows: menu, a whole round with an
// autopilot, results, store tabs, missions and the wheel. Fails on any
// exception or layout overflow.
//
// With `--dart-define=CAPTURE=true` it also saves a PNG of each screen to
// build/captures/ (for eyeballing visuals, and as raw store screenshots):
//   flutter test test/app_flow_test.dart --dart-define=CAPTURE=true
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:eatup/core/progress.dart';
import 'package:eatup/core/strings.dart';
import 'package:eatup/game/arena.dart';
import 'package:eatup/game/eat_game.dart';
import 'package:eatup/game/entities.dart';
import 'package:eatup/game/growth.dart';
import 'package:eatup/main.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool capture = bool.fromEnvironment('CAPTURE');

Future<void> _loadFonts() async {
  final fredoka = FontLoader('Fredoka')..addFont(rootBundle.load('assets/fonts/Fredoka.ttf'));
  await fredoka.load();
  // Material icons ship with the Flutter SDK, not the app bundle.
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  final icons = File('$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final bytes = icons.readAsBytesSync();
    final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

final _shotKey = GlobalKey();

Future<void> _shot(WidgetTester tester, String name) async {
  if (!capture) return;
  await tester.runAsync(() async {
    final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await boundary.toImage(pixelRatio: 3);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('build/captures/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _frames(WidgetTester tester, int n, {void Function()? each}) async {
  for (var i = 0; i < n; i++) {
    each?.call();
    await tester.pump(const Duration(milliseconds: 33));
  }
}

EatGame _game(WidgetTester tester) => tester.widget<GameWidget<EatGame>>(find.byType(GameWidget<EatGame>)).game!;

/// Steers toward the nearest edible thing, away from threats.
void _autopilot(EatGame g) {
  final a = g.arena;
  if (a == null || a.demo || !a.player.alive) return;
  final p = a.player;
  Food? best;
  var bestD = double.infinity;
  for (final f in [...a.people, ...a.standingProps]) {
    if (!f.alive || !Growth.canSwallow(p.r, f.size)) continue;
    final d = (f.x - p.x) * (f.x - p.x) + (f.y - p.y) * (f.y - p.y);
    if (d < bestD) {
      bestD = d;
      best = f;
    }
  }
  if (best == null) return;
  final dx = best.x - p.x, dy = best.y - p.y;
  final l = sqrt(dx * dx + dy * dy) + 1e-9;
  a.inputX = dx / l;
  a.inputY = dy / l;
}

Future<void> _pumpApp(WidgetTester tester, Map<String, Object> save) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(save);
  final progress = await tester.runAsync(Progress.load);
  await tester.runAsync(EatGame.loadAtlas);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _shotKey,
      child: ChangeNotifierProvider.value(value: progress!, child: const EatUpApp()),
    ),
  );
  await tester.pump();
  await _frames(tester, 30);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  const veteran = <String, Object>{
    'tutorial_done': true,
    'coins': 4820,
    'xp': 3200,
    'rounds': 20,
    'skins_owned': ['blob', 'grape', 'fluffy', 'chomper'],
    'skin': 'chomper',
    'upgrade_size': 3,
    'upgrade_speed': 2,
    'upgrade_time': 1,
    'best_town': 88.0,
    'wins_town': 4,
  };

  testWidgets('menu, a full round, results', (tester) async {
    await _pumpApp(tester, veteran);
    final s = Strings('en');
    expect(find.text(s.play), findsOneWidget);
    await _shot(tester, '1_home');

    await tester.tap(find.text(s.play));
    await _frames(tester, 3);
    final g = _game(tester);
    expect(g.inRound, isTrue);
    // Countdown, then about 25 s of play.
    await _frames(tester, 80, each: () => _autopilot(g));
    await _shot(tester, '2_play_early');
    await _frames(tester, 700, each: () => _autopilot(g));
    await _shot(tester, '3_play_late');

    // Time's up (revive if a rival got us).
    final a = g.arena!;
    if (a.frozen) a.revive();
    a.timeLeft = 0.05;
    await _frames(tester, 40);
    expect(a.phase, RoundPhase.over);
    expect(find.text(s.playAgain), findsOneWidget);
    await _shot(tester, '4_results');

    await tester.tap(find.text(s.home));
    await _frames(tester, 20);
    expect(find.text(s.play), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('being eaten offers a revive, declining ends the round', (tester) async {
    await _pumpApp(tester, veteran);
    final s = Strings('en');
    await tester.tap(find.text(s.play));
    await _frames(tester, 120);
    final a = _game(tester).arena!;
    expect(a.phase, RoundPhase.playing);
    a.monsters[1]
      ..area = 90 * 90
      ..shield = 0
      ..x = a.player.x
      ..y = a.player.y;
    await _frames(tester, 10);
    expect(find.text(s.revive), findsOneWidget);
    await _shot(tester, '5_eaten');
    await tester.tap(find.text(s.noThanks));
    await _frames(tester, 30);
    expect(find.text(s.playAgain), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('store, missions, maps and wheel', (tester) async {
    await _pumpApp(tester, veteran);
    final s = Strings('en');
    await tester.tap(find.text(s.skins).last);
    await _frames(tester, 20);
    await _shot(tester, '6_store_skins');
    await tester.tap(find.text(s.upgradesTab));
    await _frames(tester, 20);
    await _shot(tester, '7_store_upgrades');
    await tester.tap(find.text(s.coinsTab));
    await _frames(tester, 20);
    await _shot(tester, '8_store_coins');
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await _frames(tester, 20);

    await tester.tap(find.text(s.missions));
    await _frames(tester, 20);
    await _shot(tester, '9_missions');
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await _frames(tester, 20);

    await tester.tap(find.byIcon(Icons.casino_rounded));
    await _frames(tester, 20);
    await tester.tap(find.text(s.spin));
    await _frames(tester, 60);
    await _shot(tester, '10_wheel');
    await _frames(tester, 100);
    expect(find.text(s.youWon), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await _frames(tester, 20);

    await tester.tap(find.byIcon(Icons.card_giftcard_rounded));
    await _frames(tester, 20);
    await _shot(tester, '11_gift');
    await tester.tap(find.byIcon(Icons.close_rounded));
    await _frames(tester, 20);

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await _frames(tester, 20);
    await _shot(tester, '12_settings');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a first launch starts the tutorial round straight away', (tester) async {
    await _pumpApp(tester, {});
    final g = _game(tester);
    expect(g.inRound, isTrue);
    expect(g.arena!.tutorial, isTrue);
    await _frames(tester, 90);
    await _shot(tester, '13_tutorial');
    // Let the hint toasts time out.
    await _frames(tester, 160);
    expect(tester.takeException(), isNull);
  });
}
