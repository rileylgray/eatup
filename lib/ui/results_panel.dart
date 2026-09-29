import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ads/ad_manager.dart';
import '../core/progress.dart';
import '../core/sound.dart';
import '../core/strings.dart';
import '../game/arena.dart';
import '../game/growth.dart';
import 'monster_view.dart';
import 'theme.dart';
import 'widgets.dart';

class ResultsPanel extends StatefulWidget {
  const ResultsPanel({
    super.key,
    required this.result,
    required this.record,
    required this.onAgain,
    required this.onHome,
  });

  final RoundResult result;
  final RoundRecord record;
  final VoidCallback onAgain, onHome;

  @override
  State<ResultsPanel> createState() => _ResultsPanelState();
}

class _ResultsPanelState extends State<ResultsPanel> {
  bool _doubled = false;
  bool _watching = false;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    _timers.add(Timer(const Duration(milliseconds: 350), () => Sound.instance.fx(Sfx.coin)));
    if (widget.record.levelledUp) {
      _timers.add(Timer(const Duration(milliseconds: 1050), () => Sound.instance.fx(Sfx.levelup)));
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  Future<void> _double() async {
    if (_watching || _doubled) return;
    final s = Strings.of(context);
    setState(() => _watching = true);
    final earned = await AdManager.instance.showRewarded('double_coins');
    if (!mounted) return;
    setState(() => _watching = false);
    if (earned) {
      context.read<Progress>().addCoins(widget.record.coins);
      Sound.instance.fx(Sfx.coin);
      setState(() => _doubled = true);
    } else if (!AdManager.instance.rewardedReady.value) {
      showToast(context, s.videoUnavailable, icon: Icons.videocam_off_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<Progress>();
    final s = Strings.of(context);
    final u = context.u;
    final r = widget.result;
    final rec = widget.record;
    final won = r.won;
    final coins = rec.coins * (_doubled ? 2 : 1);

    final card = GlassCard(
      padding: EdgeInsets.fromLTRB(18 * u, 16 * u, 18 * u, 18 * u),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Pop(
            delay: 0,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                won ? s.winner : s.place(r.rank, r.players),
                style: fredoka(
                  won ? 40 * u : 34 * u,
                  weight: 700,
                  color: won ? AppColors.gold : Colors.white,
                  shadow: true,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 110 * u,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                MonsterView(skin: p.skin, size: 120 * u),
                if (won)
                  Positioned(
                    top: -2 * u,
                    child: Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 34 * u),
                  ),
              ],
            ),
          ),
          SizedBox(height: 6 * u),
          _Pop(
            delay: 150,
            child: Row(
              children: [
                _Stat(icon: Icons.person_rounded, label: s.people, value: '${r.people}'),
                _Stat(icon: Icons.local_florist_rounded, label: s.things, value: '${r.props}'),
                _Stat(icon: Icons.sentiment_very_satisfied_rounded, label: s.monsters, value: '${r.monsters}'),
                _Stat(
                  icon: Icons.straighten_rounded,
                  label: s.maxSize,
                  value: '${Growth.metres(r.maxRadius).toStringAsFixed(1)} m',
                  highlight: rec.newBest,
                ),
              ],
            ),
          ),
          if (rec.newBest) ...[
            SizedBox(height: 6 * u),
            _Pop(
              delay: 250,
              child: _Chip(text: s.newBest, color: AppColors.pink, icon: Icons.star_rounded),
            ),
          ],
          SizedBox(height: 14 * u),
          _Pop(
            delay: 300,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CoinIcon(size: 32 * u),
                SizedBox(width: 8 * u),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: coins.toDouble()),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) =>
                          Text('+${v.round()}', style: fredoka(32 * u, weight: 700, color: AppColors.gold)),
                    ),
                  ),
                ),
                if (!_doubled) ...[
                  SizedBox(width: 14 * u),
                  Flexible(
                    child: RewardButton(
                      height: 44,
                      onTap: _double,
                      label: Text(s.doubleCoins, style: fredoka(17 * u, weight: 700)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 14 * u),
          _Pop(
            delay: 420,
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10 * u, vertical: 4 * u),
                  decoration: BoxDecoration(color: AppColors.sky, borderRadius: BorderRadius.circular(12 * u)),
                  child: Text(s.level(p.level), style: fredoka(14 * u, weight: 700, color: AppColors.ink)),
                ),
                SizedBox(width: 10 * u),
                Expanded(
                  child: ProgressBar(value: p.xpInLevel / p.xpForNext, color: AppColors.sky, height: 12),
                ),
                SizedBox(width: 10 * u),
                Text('+${rec.xp} ${s.xp}', style: fredoka(14 * u, weight: 700, color: AppColors.sky)),
              ],
            ),
          ),
          if (rec.levelledUp) ...[
            SizedBox(height: 10 * u),
            _Pop(
              delay: 700,
              child: _Chip(
                text: '${s.levelUp(rec.levelAfter)}  +${rec.levelCoins}',
                color: AppColors.sky,
                icon: Icons.arrow_circle_up_rounded,
                coin: true,
              ),
            ),
          ],
          for (final m in rec.unlockedMaps) ...[
            SizedBox(height: 8 * u),
            _Pop(
              delay: 850,
              child: _Chip(
                text: '${s.newMapUnlocked} ${s.mapName(m.id)}',
                color: AppColors.mint,
                icon: Icons.map_rounded,
              ),
            ),
          ],
          if (rec.missionsMoved > 0 && p.missionsClaimable > 0) ...[
            SizedBox(height: 8 * u),
            _Pop(
              delay: 950,
              child: _Chip(text: s.missionProgress, color: AppColors.gold, icon: Icons.flag_rounded),
            ),
          ],
          SizedBox(height: 18 * u),
          Breathing(
            child: GoldButton(
              label: s.playAgain,
              icon: Icons.replay_rounded,
              onTap: widget.onAgain,
              height: 60,
              fontSize: 24,
            ),
          ),
          SizedBox(height: 10 * u),
          GlassButton(
            onTap: widget.onHome,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.home_rounded, color: Colors.white, size: 22 * u),
                SizedBox(width: 8 * u),
                Text(s.home, style: fredoka(18 * u, weight: 600)),
              ],
            ),
          ),
        ],
      ),
    );

    return ColoredBox(
      color: const Color(0x8C140C28),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (won) const IgnorePointer(child: _Confetti()),
          SafeArea(
            top: false,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16 * u),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 440 * u),
                  child: card,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value, this.highlight = false});
  final IconData icon;
  final String label, value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 3 * u),
        padding: EdgeInsets.symmetric(vertical: 8 * u, horizontal: 4 * u),
        decoration: BoxDecoration(
          color: highlight ? const Color(0x33FF5A8A) : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14 * u),
          border: Border.all(color: highlight ? AppColors.pink : Colors.transparent, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.gold, size: 20 * u),
            SizedBox(height: 2 * u),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: fredoka(18 * u, weight: 700)),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: fredoka(11 * u, weight: 500, color: AppColors.textDim)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color, required this.icon, this.coin = false});
  final String text;
  final Color color;
  final IconData icon;
  final bool coin;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * u, vertical: 6 * u),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16 * u),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20 * u),
          SizedBox(width: 6 * u),
          Flexible(
            child: Text(text, textAlign: TextAlign.center, style: fredoka(15 * u, weight: 700)),
          ),
          if (coin) ...[SizedBox(width: 4 * u), CoinIcon(size: 16 * u)],
        ],
      ),
    );
  }
}

/// Springs a child in after [delay] ms.
class _Pop extends StatelessWidget {
  const _Pop({required this.delay, required this.child});
  final int delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + delay),
      curve: Interval(delay / (450 + delay), 1, curve: Curves.easeOutBack),
      builder: (_, v, child) => Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.scale(scale: 0.7 + 0.3 * v, child: child),
      ),
      child: child,
    );
  }
}

class _Confetti extends StatefulWidget {
  const _Confetti();

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(painter: _ConfettiPainter(_c.value)),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);
  final double t;

  static const colors = [Color(0xFFFFD35C), Color(0xFFFF5A8A), Color(0xFF5BE07A), Color(0xFF4FC3F7), Color(0xFFB06BFF)];

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(5);
    for (var i = 0; i < 90; i++) {
      final x0 = rng.nextDouble() * size.width;
      final speed = 0.5 + rng.nextDouble() * 0.7;
      final start = rng.nextDouble() * 0.4;
      final k = ((t - start) / (1 - start)).clamp(0.0, 1.0);
      if (k <= 0 || k >= 1) continue;
      final y = -20 + k * speed * (size.height + 60) * 1.4;
      final x = x0 + sin(k * 12 + i) * 24;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(k * 10 + i);
      canvas.drawRect(
        const Rect.fromLTWH(-4, -2.5, 8, 5),
        Paint()..color = colors[i % colors.length].withValues(alpha: 1 - k * 0.6),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
