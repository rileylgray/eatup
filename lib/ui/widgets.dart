import 'package:flutter/material.dart';

import '../core/ads/ad_manager.dart';
import '../core/sound.dart';
import 'theme.dart';

/// Springs down when pressed and clicks. Every button in the app is one.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.sound = true});

  final Widget child;
  final VoidCallback? onTap;
  final bool sound;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapCancel: () => _set(false),
      onTapUp: enabled ? (_) => _set(false) : null,
      onTap: enabled
          ? () {
              if (widget.sound) Sound.instance.fx(Sfx.click, volume: 0.6);
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.93 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding, this.radius = 22, this.color});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? EdgeInsets.all(16 * context.u),
      decoration: BoxDecoration(
        color: color ?? AppColors.panel,
        borderRadius: BorderRadius.circular(radius * context.u),
        border: Border.all(color: const Color(0x2EFFFFFF)),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: child,
    );
  }
}

/// The main call-to-action: a chunky gold pill with a pressed-edge shadow.
class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.height = 58,
    this.fontSize = 22,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double height, fontSize;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    final enabled = onTap != null;
    return Pressable(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          height: height * u,
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: 24 * u),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height * u / 2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFDA70), AppColors.gold],
            ),
            boxShadow: [
              const BoxShadow(color: AppColors.goldDark, offset: Offset(0, 4)),
              BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, color: AppColors.ink, size: fontSize * 1.1 * u), SizedBox(width: 8 * u)],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, style: fredoka(fontSize * u, weight: 700, color: AppColors.ink)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GlassButton extends StatelessWidget {
  const GlassButton({super.key, required this.child, this.onTap, this.height = 52, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final double height;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: height * u,
        padding: padding ?? EdgeInsets.symmetric(horizontal: 18 * u),
        decoration: BoxDecoration(
          color: AppColors.glassDark,
          borderRadius: BorderRadius.circular(height * u / 2),
          border: Border.all(color: const Color(0x3DFFFFFF)),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class IconBubble extends StatelessWidget {
  const IconBubble({super.key, required this.icon, this.onTap, this.size = 46, this.badge = false, this.count = 0});

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool badge;

  /// A number badge (things waiting to be claimed); wins over [badge].
  final int count;

  @override
  Widget build(BuildContext context) {
    final s = size * context.u;
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: s,
        height: s,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.glassDark,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x3DFFFFFF)),
              ),
              child: Center(
                child: Icon(icon, color: Colors.white, size: s * 0.52),
              ),
            ),
            if (count > 0)
              Positioned(
                right: -3,
                top: -3,
                child: CountBadge(count: count, size: s * 0.4),
              )
            else if (badge)
              Positioned(right: 0, top: 0, child: _PulsingDot(size: s * 0.28)),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.size});
  final double size;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.85, end: 1.15).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: const Color(0xFFFF5A4E),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      ),
    );
  }
}

class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFF1B0), AppColors.gold, AppColors.goldDark],
          stops: [0, 0.55, 1],
        ),
        border: Border.all(color: const Color(0xFFB9780F), width: size * 0.06),
      ),
      child: Center(
        child: Container(
          width: size * 0.42,
          height: size * 0.42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x99B9780F), width: size * 0.07),
          ),
        ),
      ),
    );
  }
}

/// Coin balance that counts up/down smoothly when it changes.
class CoinPill extends StatelessWidget {
  const CoinPill({super.key, required this.coins, this.onTap});

  final int coins;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return Pressable(
      onTap: onTap,
      sound: onTap != null,
      child: Container(
        height: 40 * u,
        padding: EdgeInsets.only(left: 6 * u, right: 14 * u),
        decoration: BoxDecoration(
          color: AppColors.glassDark,
          borderRadius: BorderRadius.circular(20 * u),
          border: Border.all(color: const Color(0x3DFFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoinIcon(size: 28 * u),
            SizedBox(width: 8 * u),
            TweenAnimationBuilder<double>(
              tween: Tween(end: coins.toDouble()),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => Text('${v.round()}', style: fredoka(18 * u, weight: 700)),
            ),
            if (onTap != null) ...[SizedBox(width: 6 * u), Icon(Icons.add_circle, color: AppColors.gold, size: 18 * u)],
          ],
        ),
      ),
    );
  }
}

/// A "watch a video" button: shows a play badge and dims while no rewarded
/// ad is loaded (tapping then explains instead of doing nothing).
class RewardButton extends StatelessWidget {
  const RewardButton({super.key, required this.label, required this.onTap, this.height = 48});

  final Widget label;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return ValueListenableBuilder<bool>(
      valueListenable: AdManager.instance.rewardedReady,
      builder: (context, ready, _) => Pressable(
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: ready ? 1 : 0.55,
          duration: const Duration(milliseconds: 250),
          child: Container(
            height: height * u,
            padding: EdgeInsets.symmetric(horizontal: 14 * u),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height * u / 2),
              gradient: const LinearGradient(colors: [Color(0xFF5FD27A), Color(0xFF2FAE63)]),
              boxShadow: const [BoxShadow(color: Color(0xFF1E7F46), offset: Offset(0, 3))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24 * u,
                  height: 24 * u,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(Icons.play_arrow_rounded, size: 18 * u, color: const Color(0xFF2FAE63)),
                ),
                SizedBox(width: 8 * u),
                Flexible(
                  child: FittedBox(fit: BoxFit.scaleDown, child: label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showToast(BuildContext context, String text, {IconData? icon}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      duration: const Duration(milliseconds: 1800),
      content: Row(
        children: [
          if (icon != null) ...[Icon(icon, color: AppColors.gold), const SizedBox(width: 10)],
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}

/// A red count bubble for things waiting to be claimed.
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, required this.size});
  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      padding: EdgeInsets.symmetric(horizontal: size * 0.2),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4A5A),
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text('$count', style: fredoka(size * 0.62, weight: 700, height: 1)),
    );
  }
}

/// A pink secondary call-to-action, the same shape as [GoldButton].
class PinkButton extends StatelessWidget {
  const PinkButton({super.key, required this.label, this.onTap, this.icon, this.height = 52, this.fontSize = 19});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double height, fontSize;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return Pressable(
      onTap: onTap,
      child: Opacity(
        opacity: onTap != null ? 1 : 0.5,
        child: Container(
          height: height * u,
          padding: EdgeInsets.symmetric(horizontal: 20 * u),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height * u / 2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFF7FA6), AppColors.pink],
            ),
            boxShadow: const [BoxShadow(color: AppColors.pinkDark, offset: Offset(0, 4))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, color: Colors.white, size: fontSize * 1.1 * u), SizedBox(width: 8 * u)],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, style: fredoka(fontSize * u, weight: 700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A slow scale pulse that draws the eye to a button.
class Breathing extends StatefulWidget {
  const Breathing({super.key, required this.child, this.amount = 0.035});
  final Widget child;
  final double amount;

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1 + widget.amount).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

/// A thin rounded progress bar.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.height = 10, this.color = AppColors.gold});
  final double value;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final h = height * context.u;
    return Container(
      height: h,
      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(h / 2)),
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => FractionallySizedBox(
          widthFactor: v,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color.lerp(color, Colors.white, 0.3)!, color]),
              borderRadius: BorderRadius.circular(h / 2),
            ),
          ),
        ),
      ),
    );
  }
}
