import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ads/ad_manager.dart';
import '../core/analytics.dart';
import '../core/progress.dart';
import '../core/sound.dart';
import '../core/strings.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showDailyGift(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x99140C28),
    builder: (_) => const _DailyGiftDialog(),
  );
}

class _DailyGiftDialog extends StatefulWidget {
  const _DailyGiftDialog();

  @override
  State<_DailyGiftDialog> createState() => _DailyGiftDialogState();
}

class _DailyGiftDialogState extends State<_DailyGiftDialog> {
  bool _watching = false;
  int? _claimed;

  Future<void> _claim(Progress p, {required bool doubled}) async {
    if (_watching) return;
    final s = Strings.of(context);
    if (doubled) {
      setState(() => _watching = true);
      final earned = await AdManager.instance.showRewarded('daily_double');
      if (!mounted) return;
      setState(() => _watching = false);
      if (!earned) {
        if (!AdManager.instance.rewardedReady.value) {
          showToast(context, s.videoUnavailable, icon: Icons.videocam_off_rounded);
        }
        return;
      }
    }
    final amount = p.claimDaily(doubled: doubled);
    if (amount > 0) {
      Sound.instance.fx(Sfx.star);
      Analytics.instance.event('daily_claim', {'day': p.dailyStreak, 'doubled': doubled ? 1 : 0});
      setState(() => _claimed = amount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<Progress>();
    final s = Strings.of(context);
    final u = context.u;
    final available = p.dailyAvailable();
    final today = available ? p.dailyDay() : p.dailyStreak;

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
                  Icon(Icons.card_giftcard_rounded, color: AppColors.gold, size: 28 * u),
                  SizedBox(width: 10 * u),
                  Expanded(child: Text(s.dailyGift, style: fredoka(24 * u, weight: 700))),
                  IconBubble(icon: Icons.close_rounded, size: 38, onTap: () => Navigator.pop(context)),
                ],
              ),
              SizedBox(height: 16 * u),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8 * u,
                runSpacing: 8 * u,
                children: List.generate(7, (i) {
                  final day = i + 1;
                  final past = available ? day < today : day <= today;
                  final current = available && day == today;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 70 * u,
                    padding: EdgeInsets.symmetric(vertical: 8 * u),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14 * u),
                      color: current
                          ? const Color(0x44FFC94A)
                          : past
                          ? const Color(0x3339B36B)
                          : Colors.white.withValues(alpha: 0.06),
                      border: Border.all(color: current ? AppColors.gold : Colors.white12, width: current ? 2 : 1),
                    ),
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(s.day(day), style: fredoka(12 * u, weight: 600, color: AppColors.textDim)),
                        ),
                        SizedBox(height: 4 * u),
                        past
                            ? Icon(Icons.check_circle_rounded, color: AppColors.good, size: 24 * u)
                            : CoinIcon(size: 24 * u),
                        SizedBox(height: 4 * u),
                        Text('${Progress.dailyReward(day)}', style: fredoka(14 * u, weight: 700)),
                      ],
                    ),
                  );
                }),
              ),
              SizedBox(height: 18 * u),
              if (_claimed != null)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CoinIcon(size: 34 * u),
                      SizedBox(width: 8 * u),
                      Text('+$_claimed', style: fredoka(32 * u, weight: 700, color: AppColors.gold)),
                    ],
                  ),
                )
              else if (available) ...[
                RewardButton(
                  height: 54,
                  onTap: () => _claim(p, doubled: true),
                  label: Text(
                    '${s.claimDouble}  (${Progress.dailyReward(today) * 2})',
                    style: fredoka(18 * u, weight: 700),
                  ),
                ),
                SizedBox(height: 10 * u),
                GlassButton(
                  onTap: () => _claim(p, doubled: false),
                  child: Text('${s.claim}  (${Progress.dailyReward(today)})', style: fredoka(17 * u, weight: 600)),
                ),
              ] else
                Text(
                  s.comeBackTomorrow,
                  textAlign: TextAlign.center,
                  style: fredoka(16 * u, weight: 500, color: AppColors.textDim),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
