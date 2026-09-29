import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/sound.dart';
import '../core/strings.dart';
import '../game/arena.dart';
import '../game/art/atlas.dart' show PowerArt;
import '../game/eat_game.dart';
import '../game/entities.dart';
import '../game/growth.dart';
import 'main_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// The in-round overlay: timer, size, live leaderboard, power-ups, the
/// countdown and toasts. Everything but the pause button ignores touches so
/// a drag can start anywhere.
class Hud extends StatelessWidget {
  const Hud({super.key, required this.game, required this.toast, required this.onPause, this.hidden = false});

  final EatGame game;
  final ValueNotifier<HudToast?> toast;
  final VoidCallback onPause;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return AnimatedOpacity(
      opacity: hidden ? 0 : 1,
      duration: const Duration(milliseconds: 250),
      child: SafeArea(
        top: false,
        child: ValueListenableBuilder<HudState>(
          valueListenable: game.hud,
          builder: (context, h, _) => Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: 12 * u,
                right: 12 * u,
                top: 10 * u,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IgnorePointer(child: _TimerPill(seconds: h.timeLeft)),
                    SizedBox(width: 8 * u),
                    Expanded(
                      child: IgnorePointer(
                        child: Center(
                          child: _SizePill(radius: h.radius, rank: h.rank),
                        ),
                      ),
                    ),
                    SizedBox(width: 8 * u),
                    if (!hidden) IconBubble(icon: Icons.pause_rounded, onTap: onPause, size: 42),
                  ],
                ),
              ),
              Positioned(
                right: 10 * u,
                top: 62 * u,
                child: IgnorePointer(child: _Leaderboard(standings: h.standings)),
              ),
              Positioned(
                left: 12 * u,
                top: 62 * u,
                child: IgnorePointer(child: _PowerChips(h: h)),
              ),
              Positioned(
                left: 0,
                right: 0,
                // Below the live leaderboard (up to 6 rows).
                top: 240 * u,
                child: IgnorePointer(child: _ToastView(toast: toast)),
              ),
              IgnorePointer(
                child: _Countdown(phase: h.phase, countdown: h.countdown),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerPill extends StatelessWidget {
  const _TimerPill({required this.seconds});
  final double seconds;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    final s = seconds.ceil();
    final low = s <= 10;
    final text = '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 42 * u,
      padding: EdgeInsets.symmetric(horizontal: 12 * u),
      decoration: BoxDecoration(
        color: low ? const Color(0xE6D8343C) : AppColors.glassDark,
        borderRadius: BorderRadius.circular(21 * u),
        border: Border.all(color: const Color(0x3DFFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_rounded, color: low ? Colors.white : AppColors.gold, size: 20 * u),
          SizedBox(width: 6 * u),
          Text(text, style: fredoka(19 * u, weight: 700).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

class _SizePill extends StatelessWidget {
  const _SizePill({required this.radius, required this.rank});
  final double radius;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    final s = Strings.of(context);
    return Container(
      height: 42 * u,
      padding: EdgeInsets.only(left: 6 * u, right: 14 * u),
      decoration: BoxDecoration(
        color: AppColors.glassDark,
        borderRadius: BorderRadius.circular(21 * u),
        border: Border.all(color: const Color(0x3DFFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32 * u,
            height: 32 * u,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: rank == 1 ? AppColors.gold : Colors.white24),
            child: Text('#$rank', style: fredoka(13 * u, weight: 700, color: rank == 1 ? AppColors.ink : Colors.white)),
          ),
          SizedBox(width: 8 * u),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${s.size} ${Growth.metres(radius).toStringAsFixed(1)} m',
                style: fredoka(17 * u, weight: 700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Leaderboard extends StatelessWidget {
  const _Leaderboard({required this.standings});
  final List<Standing> standings;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    if (standings.isEmpty) return const SizedBox.shrink();
    final me = standings.indexWhere((e) => e.isPlayer);
    final rows = <(int, Standing)>[for (var i = 0; i < min(5, standings.length); i++) (i, standings[i])];
    if (me >= 5) rows.add((me, standings[me]));
    return Container(
      width: 138 * u,
      padding: EdgeInsets.symmetric(horizontal: 8 * u, vertical: 6 * u),
      decoration: BoxDecoration(color: const Color(0x80201638), borderRadius: BorderRadius.circular(14 * u)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, e) in rows)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 1.5 * u),
              child: Row(
                children: [
                  SizedBox(
                    width: 18 * u,
                    child: Text(
                      '${i + 1}',
                      style: fredoka(12 * u, weight: 700, color: i == 0 ? AppColors.gold : AppColors.textDim),
                    ),
                  ),
                  Container(
                    width: 10 * u,
                    height: 10 * u,
                    decoration: BoxDecoration(
                      color: e.alive ? e.color : Colors.white24,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white54, width: 1),
                    ),
                  ),
                  SizedBox(width: 5 * u),
                  Expanded(
                    child: Text(
                      e.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: fredoka(
                        12 * u,
                        weight: e.isPlayer ? 700 : 500,
                        color: e.isPlayer ? AppColors.gold : Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    Growth.metres(e.radius).toStringAsFixed(1),
                    style: fredoka(11.5 * u, weight: 600, color: e.isPlayer ? AppColors.gold : AppColors.textDim),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PowerChips extends StatelessWidget {
  const _PowerChips({required this.h});
  final HudState h;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    final chips = [
      if (h.speedT > 0) (PowerKind.speed, Icons.bolt_rounded, h.speedT / 6),
      if (h.magnetT > 0) (PowerKind.magnet, Icons.all_out_rounded, h.magnetT / 8),
      if (h.frenzyT > 0) (PowerKind.frenzy, Icons.auto_awesome_rounded, h.frenzyT / 8),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (kind, icon, left) in chips)
          Padding(
            padding: EdgeInsets.only(bottom: 6 * u),
            child: SizedBox.square(
              dimension: 42 * u,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(color: PowerArt.colorOf(kind), shape: BoxShape.circle),
                  ),
                  CircularProgressIndicator(
                    value: left.clamp(0, 1),
                    strokeWidth: 3.5 * u,
                    color: Colors.white,
                    backgroundColor: Colors.black26,
                  ),
                  Icon(icon, color: Colors.white, size: 22 * u),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({required this.toast});
  final ValueNotifier<HudToast?> toast;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> {
  HudToast? _shown;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    widget.toast.addListener(_changed);
    _changed();
  }

  @override
  void dispose() {
    widget.toast.removeListener(_changed);
    _hide?.cancel();
    super.dispose();
  }

  void _changed() {
    final t = widget.toast.value;
    if (t == null || t.id == _shown?.id) {
      if (t == null && mounted) setState(() => _shown = null);
      return;
    }
    setState(() => _shown = t);
    _hide?.cancel();
    _hide = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _shown = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    final t = _shown;
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: t == null
            ? const SizedBox.shrink()
            : Container(
                key: ValueKey(t.id),
                constraints: BoxConstraints(maxWidth: 340 * u),
                padding: EdgeInsets.symmetric(horizontal: 16 * u, vertical: 10 * u),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(20 * u),
                  border: Border.all(color: (t.color ?? AppColors.gold).withValues(alpha: 0.8), width: 2),
                  boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 16, offset: Offset(0, 6))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (t.icon != null) ...[
                      Icon(t.icon, color: t.color ?? AppColors.gold, size: 22 * u),
                      SizedBox(width: 8 * u),
                    ],
                    Flexible(
                      child: Text(t.text, textAlign: TextAlign.center, style: fredoka(16 * u, weight: 600)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// "Ready?" during the countdown, then a big "EAT!" as the round starts.
class _Countdown extends StatefulWidget {
  const _Countdown({required this.phase, required this.countdown});
  final RoundPhase phase;
  final double countdown;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  bool _go = false;
  int _lastTick = -1;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(_Countdown old) {
    super.didUpdateWidget(old);
    if (old.phase == RoundPhase.countdown && widget.phase == RoundPhase.playing) {
      setState(() => _go = true);
      _hide?.cancel();
      _hide = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _go = false);
      });
    }
    if (widget.phase == RoundPhase.countdown) {
      final tick = widget.countdown.ceil();
      if (tick != _lastTick && tick > 0 && tick <= 2) Sound.instance.fx(Sfx.tick);
      _lastTick = tick;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final u = context.u;
    final String? text = widget.phase == RoundPhase.countdown ? s.ready : (_go ? s.go : null);
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut, reverseCurve: Curves.easeIn),
          child: child,
        ),
        child: text == null
            ? const SizedBox.shrink()
            : FittedBox(
                key: ValueKey(text),
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24 * u),
                  child: Text(
                    text,
                    style: fredoka(
                      text == s.go ? 76 * u : 48 * u,
                      weight: 700,
                      color: text == s.go ? AppColors.gold : Colors.white,
                      shadow: true,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
