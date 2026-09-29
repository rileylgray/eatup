import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ads/ad_manager.dart';
import '../core/analytics.dart';
import '../core/live_config.dart';
import '../core/progress.dart';
import '../core/review.dart';
import '../core/sound.dart';
import '../core/strings.dart';
import '../game/arena.dart';
import '../game/eat_game.dart';
import '../game/maps.dart';
import 'banner_slot.dart';
import 'eaten_panel.dart';
import 'home_panel.dart';
import 'hud.dart';
import 'maps_panel.dart';
import 'missions_panel.dart';
import 'pause_panel.dart';
import 'results_panel.dart';
import 'store_panel.dart';

enum Panel { home, play, store, maps, missions }

/// A toast the HUD shows over the game (hints, power-ups, rivals eaten).
class HudToast {
  HudToast(this.text, {this.icon, this.color}) : id = _next++;
  static int _next = 0;
  final int id;
  final String text;
  final IconData? icon;
  final Color? color;
}

/// The whole app lives on this one screen: the town is always running
/// underneath (rival monsters roam it behind the menus), and the menu, HUD,
/// results and store are panels over it. That keeps the single banner visible
/// everywhere and makes starting a round instant.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final Progress _progress = context.read<Progress>();
  final EatGame _game = EatGame();

  Panel _panel = Panel.home;
  StoreTab _storeTab = StoreTab.skins;
  RoundResult? _result;
  RoundRecord? _record;
  String? _eatenBy;
  bool _revived = false;
  bool _paused = false;
  bool _busy = false;
  final ValueNotifier<HudToast?> _toast = ValueNotifier(null);
  Timer? _hintTimer;
  Timer? _reviewTimer;

  @override
  void initState() {
    super.initState();
    _game
      ..onRoundEnd = _onRoundEnd
      ..onPlayerEaten = _onPlayerEaten
      ..onHint = _onHint
      ..onAteRival = _onAteRival;
    _game.showMenu(map: _progress.map, skin: _progress.skin);
    _progress.addListener(_syncMenu);
    // A first-time player goes straight into their first round.
    if (!_progress.tutorialDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _play());
    }
  }

  String _menuKey = '';

  /// The menu's town follows the chosen map.
  void _syncMenu() {
    final key = _progress.mapId;
    if (_panel == Panel.play || key == _menuKey) return;
    _menuKey = key;
    _game.showMenu(map: _progress.map, skin: _progress.skin);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = Strings.of(context);
    _game.labels = GameLabels(you: s.you, yum: s.yum, gulp: s.gulp, huge: s.huge, combo: s.combo);
  }

  @override
  void dispose() {
    _progress.removeListener(_syncMenu);
    _hintTimer?.cancel();
    _reviewTimer?.cancel();
    _toast.dispose();
    super.dispose();
  }

  void _play() {
    _toast.value = null;
    final tutorial = !_progress.tutorialDone;
    _game.startRound(
      map: tutorial ? maps.first : _progress.map,
      skin: _progress.skin,
      loadout: _progress.loadout,
      tutorial: tutorial,
      roundSeconds: LiveConfig.instance.roundSeconds,
    );
    _game.resumeEngine();
    Sound.instance.inRound = true;
    setState(() {
      _panel = Panel.play;
      _result = null;
      _record = null;
      _eatenBy = null;
      _revived = false;
      _paused = false;
    });
    Analytics.instance.event('round_start', {'map': _progress.mapId, 'level': _progress.level});
  }

  void _onRoundEnd(RoundResult r) {
    if (!mounted || _result != null) return;
    final record = _progress.recordRound(r);
    AdManager.instance.pacer.onRound();
    if (!_progress.tutorialDone) {
      _progress.completeTutorial();
      Analytics.instance.event('tutorial_complete');
    }
    Analytics.instance.event('round_end', {
      'map': r.mapId,
      'rank': r.rank,
      'size': r.maxRadius.round(),
      'people': r.people,
      'props': r.props,
      'monsters': r.monsters,
      'eaten': r.eatenBy == null ? 0 : 1,
      'revived': _revived ? 1 : 0,
    });
    if (record.levelledUp) {
      Analytics.instance.event('level_up', {'level': record.levelAfter});
    }
    for (final m in record.unlockedMaps) {
      Analytics.instance.event('map_unlocked', {'map': m.id});
    }
    Sound.instance.inRound = false;
    setState(() {
      _eatenBy = null;
      _result = r;
      _record = record;
    });
    if (r.won || record.newBest) {
      // After the card has had a moment on screen.
      _reviewTimer?.cancel();
      _reviewTimer = Timer(const Duration(milliseconds: 2200), () {
        if (mounted && _result == r) Review.instance.onHighPoint(totalRounds: _progress.rounds);
      });
    }
  }

  void _onPlayerEaten(String by) {
    if (!mounted) return;
    final canRevive = !_revived && LiveConfig.instance.reviveEnabled;
    if (!canRevive) {
      _game.giveUp();
      return;
    }
    setState(() => _eatenBy = by);
  }

  Future<void> _revive() async {
    final earned = await AdManager.instance.showRewarded('revive');
    if (!mounted) return;
    if (!earned) {
      if (!AdManager.instance.rewardedReady.value) {
        _toast.value = HudToast(Strings.of(context).videoUnavailable, icon: Icons.videocam_off_rounded);
      }
      return;
    }
    Analytics.instance.event('revive');
    setState(() {
      _eatenBy = null;
      _revived = true;
    });
    _game.revive();
  }

  void _declineRevive() {
    setState(() => _eatenBy = null);
    _game.giveUp();
  }

  void _onHint(Hint h) {
    if (!mounted) return;
    final s = Strings.of(context);
    final tutorial = !_progress.tutorialDone || _progress.rounds < 3;
    switch (h) {
      case Hint.move:
        if (tutorial) _toast.value = HudToast(s.hintMove, icon: Icons.pan_tool_alt_rounded);
        if (tutorial) {
          _hintTimer?.cancel();
          _hintTimer = Timer(const Duration(milliseconds: 3200), () {
            if (mounted && _panel == Panel.play && _result == null) {
              _toast.value = HudToast(s.hintEat, icon: Icons.restaurant_rounded);
            }
          });
        }
      case Hint.tierMedium:
        _toast.value = HudToast(s.hintMedium, icon: Icons.park_rounded);
      case Hint.tierLarge:
        _toast.value = HudToast(s.hintLarge, icon: Icons.directions_bus_rounded);
      case Hint.tierBuilding:
        _toast.value = HudToast(s.hintBuilding, icon: Icons.apartment_rounded);
      case Hint.avoid:
        if (tutorial) _toast.value = HudToast(s.hintAvoid, icon: Icons.warning_rounded, color: const Color(0xFFFF4A5A));
      case Hint.speed:
        _toast.value = HudToast(s.hintSpeed, icon: Icons.bolt_rounded, color: const Color(0xFFFFC93C));
      case Hint.magnet:
        _toast.value = HudToast(s.hintMagnet, icon: Icons.all_out_rounded, color: const Color(0xFFFF5A6A));
      case Hint.frenzy:
        _toast.value = HudToast(s.hintFrenzy, icon: Icons.auto_awesome_rounded, color: const Color(0xFFB06BFF));
    }
  }

  void _onAteRival(String name) {
    if (!mounted) return;
    _toast.value = HudToast(Strings.of(context).ateRival(name), icon: Icons.emoji_events_rounded);
  }

  Future<void> _afterResult(VoidCallback next) async {
    if (_busy) return;
    _busy = true;
    try {
      await AdManager.instance.maybeShowInterstitial(lifetimeRounds: _progress.rounds);
    } finally {
      _busy = false;
    }
    if (!mounted) return;
    next();
  }

  void _playAgain() => _afterResult(_play);

  void _home() => _afterResult(_goHome);

  void _goHome() {
    _toast.value = null;
    Sound.instance.inRound = false;
    _game.resumeEngine();
    _menuKey = _progress.mapId;
    _game.showMenu(map: _progress.map, skin: _progress.skin);
    setState(() {
      _result = null;
      _eatenBy = null;
      _paused = false;
      _panel = Panel.home;
    });
  }

  void _pause() {
    if (_result != null || _eatenBy != null) return;
    setState(() => _paused = true);
    _game.pointerUp();
    _game.pauseEngine();
  }

  void _resume() {
    setState(() => _paused = false);
    _game.resumeEngine();
  }

  void _leaveRound() {
    Analytics.instance.event('round_quit');
    _goHome();
  }

  void _openPanel(Panel p, {StoreTab? tab}) {
    if (p == Panel.missions) _progress.checkDay();
    setState(() {
      _panel = p;
      if (tab != null) _storeTab = tab;
    });
  }

  bool get _canPop => _panel == Panel.home;

  void _handleBack() {
    switch (_panel) {
      case Panel.store || Panel.maps || Panel.missions:
        _openPanel(Panel.home);
      case Panel.play:
        if (_result != null) {
          _home();
        } else if (_eatenBy != null) {
          _declineRevive();
        } else if (_paused) {
          _resume();
        } else {
          _pause();
        }
      case Panel.home:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inRound = _panel == Panel.play && _result == null && _eatenBy == null && !_paused;
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF2B1B4F),
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Listener(
              onPointerDown: (e) {
                if (inRound) _game.pointerDown(e.localPosition);
              },
              onPointerMove: (e) => _game.pointerMove(e.localPosition),
              onPointerUp: (_) => _game.pointerUp(),
              onPointerCancel: (_) => _game.pointerUp(),
              child: GameWidget(game: _game),
            ),
            Column(
              children: [
                SizedBox(height: MediaQuery.paddingOf(context).top),
                const BannerSlot(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(anim),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(key: ValueKey(_panel), child: _buildPanel()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel() {
    switch (_panel) {
      case Panel.home:
        return HomePanel(
          onPlay: _play,
          onStore: (tab) => _openPanel(Panel.store, tab: tab),
          onMaps: () => _openPanel(Panel.maps),
          onMissions: () => _openPanel(Panel.missions),
        );
      case Panel.store:
        return StorePanel(initialTab: _storeTab, onClose: () => _openPanel(Panel.home));
      case Panel.maps:
        return MapsPanel(onClose: () => _openPanel(Panel.home));
      case Panel.missions:
        return MissionsPanel(onClose: () => _openPanel(Panel.home));
      case Panel.play:
        final result = _result;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Touches pass through the HUD to the game, except its buttons.
            Hud(game: _game, toast: _toast, onPause: _pause, hidden: result != null),
            if (_eatenBy != null)
              EatenPanel(eaterName: _eatenBy!, skin: _progress.skin, onRevive: _revive, onDecline: _declineRevive),
            if (result != null)
              ResultsPanel(key: ValueKey(result), result: result, record: _record!, onAgain: _playAgain, onHome: _home),
            if (_paused) PausePanel(onResume: _resume, onLeave: _leaveRound),
          ],
        );
    }
  }
}
