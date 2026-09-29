import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ads/ad_manager.dart';
import '../core/analytics.dart';
import '../core/progress.dart';
import '../core/sound.dart';
import '../core/strings.dart';
import '../game/rewards.dart';
import 'store_panel.dart' show formatWait;
import 'theme.dart';
import 'widgets.dart';

Future<void> showWheel(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x99140C28),
    builder: (_) => const _WheelDialog(),
  );
}

class _WheelDialog extends StatefulWidget {
  const _WheelDialog();

  @override
  State<_WheelDialog> createState() => _WheelDialogState();
}

class _WheelDialogState extends State<_WheelDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  late Animation<double> _angle = const AlwaysStoppedAnimation(0);
  double _rest = 0;
  bool _spinning = false;
  int? _won;
  Timer? _tick;
  int _lastSlice = 0;

  static const _slice = 2 * pi / 8;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_spinning) setState(() {});
    });
    _spin.addListener(() {
      final slice = ((_angle.value) / _slice).floor();
      if (slice != _lastSlice) {
        _lastSlice = slice;
        Sound.instance.fx(Sfx.spin, volume: 0.6);
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _spin.dispose();
    super.dispose();
  }

  Future<void> _go(Progress p, {required bool ad}) async {
    if (_spinning) return;
    final s = Strings.of(context);
    if (ad) {
      setState(() => _spinning = true);
      final earned = await AdManager.instance.showRewarded('wheel');
      if (!mounted) return;
      if (!earned) {
        setState(() => _spinning = false);
        if (!AdManager.instance.rewardedReady.value) {
          showToast(context, s.videoUnavailable, icon: Icons.videocam_off_rounded);
        }
        return;
      }
    }
    final index = Wheel.spin(Random());
    // Land slice [index] under the pointer at the top, after a few turns.
    final target = -(index + 0.5) * _slice;
    final delta = ((target - _rest) % (2 * pi) + 2 * pi) % (2 * pi);
    final end = _rest + 5 * 2 * pi + delta;
    setState(() {
      _spinning = true;
      _won = null;
      _angle = Tween(begin: _rest, end: end).animate(CurvedAnimation(parent: _spin, curve: Curves.easeOutQuart));
    });
    await _spin.forward(from: 0);
    if (!mounted) return;
    _rest = end % (2 * pi);
    final prize = p.recordSpin(index, ad: ad);
    Sound.instance.fx(prize >= 500 ? Sfx.levelup : Sfx.coin);
    Analytics.instance.event('wheel_spin', {'prize': prize, 'ad': ad ? 1 : 0});
    setState(() {
      _spinning = false;
      _won = prize;
      _angle = AlwaysStoppedAnimation(_rest);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<Progress>();
    final s = Strings.of(context);
    final u = context.u;
    final freeReady = p.wheelFreeReady;
    final adLeft = p.wheelAdSpinsLeft;
    final wheelSize = min(300 * u, MediaQuery.sizeOf(context).width - 90 * u);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(20 * u),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420 * u),
        child: GlassCard(
          padding: EdgeInsets.all(18 * u),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.casino_rounded, color: AppColors.gold, size: 28 * u),
                  SizedBox(width: 10 * u),
                  Expanded(child: Text(s.luckyWheel, style: fredoka(24 * u, weight: 700))),
                  IconBubble(
                    icon: Icons.close_rounded,
                    size: 38,
                    onTap: _spinning ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 14 * u),
              SizedBox.square(
                dimension: wheelSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _spin,
                      builder: (_, _) => Transform.rotate(
                        angle: _angle.value,
                        child: CustomPaint(size: Size.square(wheelSize), painter: _WheelPainter()),
                      ),
                    ),
                    // Hub.
                    Container(
                      width: wheelSize * 0.2,
                      height: wheelSize * 0.2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(colors: [Color(0xFFFFF1B0), AppColors.gold, AppColors.goldDark]),
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8)],
                      ),
                      child: Icon(Icons.star_rounded, color: Colors.white, size: wheelSize * 0.1),
                    ),
                    // Pointer.
                    Positioned(
                      top: -2,
                      child: CustomPaint(size: Size(wheelSize * 0.12, wheelSize * 0.13), painter: _PointerPainter()),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14 * u),
              SizedBox(
                height: 44 * u,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
                    child: child,
                  ),
                  child: _won == null
                      ? const SizedBox.shrink()
                      : Row(
                          key: ValueKey(_won),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(s.youWon, style: fredoka(20 * u, weight: 600)),
                            SizedBox(width: 10 * u),
                            CoinIcon(size: 30 * u),
                            SizedBox(width: 6 * u),
                            Text('+$_won', style: fredoka(30 * u, weight: 700, color: AppColors.gold)),
                          ],
                        ),
                ),
              ),
              SizedBox(height: 10 * u),
              if (freeReady)
                Breathing(
                  child: GoldButton(
                    label: s.spin,
                    icon: Icons.refresh_rounded,
                    onTap: _spinning ? null : () => _go(p, ad: false),
                  ),
                )
              else ...[
                if (adLeft > 0)
                  RewardButton(
                    height: 54,
                    onTap: () => _go(p, ad: true),
                    label: Text('${s.spinAgain}  (${s.spinsLeft(adLeft)})', style: fredoka(17 * u, weight: 700)),
                  ),
                SizedBox(height: 10 * u),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.schedule_rounded, size: 16 * u, color: AppColors.textDim),
                    SizedBox(width: 6 * u),
                    Text(
                      s.freeSpinIn(formatWait(p.wheelFreeWait())),
                      style: fredoka(14 * u, weight: 500, color: AppColors.textDim),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  static const colors = [
    Color(0xFFFF5A8A),
    Color(0xFF7B4FD8),
    Color(0xFF4FC3F7),
    Color(0xFFFFB42A),
    Color(0xFF5BE07A),
    Color(0xFFFF7A3D),
    Color(0xFFFFD35C),
    Color(0xFF3F8EE8),
  ];

  @override
  void paint(Canvas c, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    const n = 8;
    const sweep = 2 * pi / n;
    c.drawCircle(center, r, Paint()..color = const Color(0xFF2B2240));
    final inner = r * 0.9;
    for (var i = 0; i < n; i++) {
      final start = -pi / 2 + i * sweep;
      c.drawArc(Rect.fromCircle(center: center, radius: inner), start, sweep, true, Paint()..color = colors[i]);
      c.drawArc(
        Rect.fromCircle(center: center, radius: inner),
        start,
        sweep,
        true,
        Paint()
          ..color = const Color(0x55FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      // Prize label, reading outward.
      final mid = start + sweep / 2;
      c.save();
      c.translate(center.dx + cos(mid) * inner * 0.62, center.dy + sin(mid) * inner * 0.62);
      c.rotate(mid + pi / 2);
      final jackpot = Wheel.prizes[i] >= 1000;
      final tp = TextPainter(
        text: TextSpan(
          text: '${Wheel.prizes[i]}',
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: r * (jackpot ? 0.15 : 0.13),
            fontWeight: FontWeight.w700,
            fontVariations: const [FontVariation('wght', 700)],
            color: Colors.white,
            shadows: const [Shadow(color: Color(0x88000000), offset: Offset(0, 1), blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
      c.restore();
    }
    // Rim lights.
    for (var i = 0; i < 16; i++) {
      final a = i * pi / 8;
      c.drawCircle(
        center + Offset(cos(a), sin(a)) * r * 0.95,
        r * 0.025,
        Paint()..color = i.isEven ? const Color(0xFFFFF1B0) : const Color(0xFFFFFFFF),
      );
    }
  }

  @override
  bool shouldRepaint(_WheelPainter old) => false;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    c.drawPath(path.shift(const Offset(0, 2)), Paint()..color = const Color(0x66000000));
    c.drawPath(path, Paint()..color = const Color(0xFFFF4A5A));
    c.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_PointerPainter old) => false;
}
