import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ads/ad_manager.dart';
import '../core/analytics.dart';
import '../core/missions.dart';
import '../core/progress.dart';
import '../core/sound.dart';
import '../core/strings.dart';
import 'panel_scaffold.dart';
import 'store_panel.dart' show formatWait;
import 'theme.dart';
import 'widgets.dart';

IconData missionIcon(MissionKind k) => switch (k) {
  MissionKind.eatPeople => Icons.person_rounded,
  MissionKind.eatProps => Icons.local_florist_rounded,
  MissionKind.eatVehicles => Icons.directions_car_rounded,
  MissionKind.eatBuildings => Icons.apartment_rounded,
  MissionKind.eatRivals => Icons.sentiment_very_satisfied_rounded,
  MissionKind.winRounds => Icons.emoji_events_rounded,
  MissionKind.top3 => Icons.military_tech_rounded,
  MissionKind.playRounds => Icons.replay_rounded,
  MissionKind.reachSize => Icons.straighten_rounded,
};

class MissionsPanel extends StatefulWidget {
  const MissionsPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<MissionsPanel> createState() => _MissionsPanelState();
}

class _MissionsPanelState extends State<MissionsPanel> {
  Timer? _tick;
  bool _watching = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      context.read<Progress>().checkDay();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _swap(Progress p, int i) async {
    if (_watching) return;
    final s = Strings.of(context);
    setState(() => _watching = true);
    final earned = await AdManager.instance.showRewarded('mission_swap');
    if (!mounted) return;
    setState(() => _watching = false);
    if (earned) {
      p.rerollMission(i);
      Sound.instance.fx(Sfx.whoosh);
    } else if (!AdManager.instance.rewardedReady.value) {
      showToast(context, s.videoUnavailable, icon: Icons.videocam_off_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<Progress>();
    final s = Strings.of(context);
    final u = context.u;
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final bonusReady = p.missionBonusReady;

    return PanelScaffold(
      title: s.dailyMissions,
      onClose: widget.onClose,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16 * u, 2 * u, 16 * u, 24 * u),
        children: [
          for (var i = 0; i < p.missions.length; i++) ...[
            _MissionCard(
              mission: p.missions[i],
              onClaim: () {
                final n = p.claimMission(i);
                if (n > 0) {
                  Sound.instance.fx(Sfx.coin);
                  Analytics.instance.event('mission_claim', {'kind': p.missions[i].kind.name});
                }
              },
              onSwap: !p.missionRerolled && !p.missions[i].done ? () => _swap(p, i) : null,
            ),
            SizedBox(height: 10 * u),
          ],
          GlassCard(
            padding: EdgeInsets.all(14 * u),
            color: bonusReady ? const Color(0xCC4A3510) : AppColors.panel,
            child: Row(
              children: [
                _ChestIcon(open: p.missionBonusClaimed, glow: bonusReady),
                SizedBox(width: 12 * u),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.allDoneBonus, style: fredoka(15 * u, weight: 600)),
                      SizedBox(height: 4 * u),
                      Row(
                        children: [
                          CoinIcon(size: 18 * u),
                          SizedBox(width: 4 * u),
                          Text(
                            '+${MissionBoard.allDoneBonus}',
                            style: fredoka(16 * u, weight: 700, color: AppColors.gold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (p.missionBonusClaimed)
                  Icon(Icons.check_circle_rounded, color: AppColors.mint, size: 30 * u)
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 110 * u),
                    child: GoldButton(
                      label: s.claim,
                      height: 42,
                      fontSize: 16,
                      expand: false,
                      onTap: bonusReady
                          ? () {
                              if (p.claimMissionBonus() > 0) {
                                Sound.instance.fx(Sfx.levelup);
                                Analytics.instance.event('mission_bonus');
                              }
                            }
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 14 * u),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_rounded, size: 16 * u, color: AppColors.textDim),
                SizedBox(width: 6 * u),
                Flexible(
                  child: Text(
                    s.newMissionsIn(formatWait(midnight.difference(now))),
                    style: fredoka(14 * u, weight: 500, color: AppColors.textDim),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission, required this.onClaim, this.onSwap});
  final Mission mission;
  final VoidCallback onClaim;
  final VoidCallback? onSwap;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final u = context.u;
    final m = mission;
    final isSize = m.kind == MissionKind.reachSize;
    final progressText = isSize
        ? '${(m.progress / 10).toStringAsFixed(1)} / ${(m.target / 10).toStringAsFixed(1)} m'
        : '${m.progress} / ${m.target}';
    return GlassCard(
      padding: EdgeInsets.all(12 * u),
      radius: 18,
      color: m.claimable ? const Color(0xCC1B3A2A) : null,
      child: Row(
        children: [
          Container(
            width: 48 * u,
            height: 48 * u,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: m.claimed
                    ? const [Color(0xFF5A5A6A), Color(0xFF3A3A4A)]
                    : const [Color(0xFFFF7FA6), AppColors.pink],
              ),
              borderRadius: BorderRadius.circular(14 * u),
            ),
            child: Icon(missionIcon(m.kind), color: Colors.white, size: 26 * u),
          ),
          SizedBox(width: 12 * u),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.mission(m.kind.name, m.target),
                  style: fredoka(16 * u, weight: 700, color: m.claimed ? AppColors.textDim : Colors.white),
                ),
                SizedBox(height: 6 * u),
                ProgressBar(value: m.fraction, color: m.done ? AppColors.mint : AppColors.gold, height: 9),
                SizedBox(height: 4 * u),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        progressText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: fredoka(12 * u, weight: 600, color: AppColors.textDim),
                      ),
                    ),
                    CoinIcon(size: 15 * u),
                    SizedBox(width: 3 * u),
                    Text('${m.reward}', style: fredoka(13 * u, weight: 700, color: AppColors.gold)),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 10 * u),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 104 * u),
            child: m.claimed
                ? Icon(Icons.check_circle_rounded, color: AppColors.mint, size: 30 * u)
                : m.done
                ? Breathing(
                    amount: 0.06,
                    child: GoldButton(label: s.claim, height: 42, fontSize: 16, expand: false, onTap: onClaim),
                  )
                : onSwap != null
                ? RewardButton(
                    height: 38,
                    onTap: onSwap!,
                    label: Text(s.swap, style: fredoka(14 * u, weight: 700)),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ChestIcon extends StatelessWidget {
  const _ChestIcon({required this.open, required this.glow});
  final bool open, glow;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    final icon = Container(
      width: 52 * u,
      height: 52 * u,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFDA70), AppColors.goldDark]),
        borderRadius: BorderRadius.circular(14 * u),
        boxShadow: glow ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.7), blurRadius: 18)] : null,
      ),
      child: Icon(open ? Icons.inventory_2_outlined : Icons.redeem_rounded, color: AppColors.ink, size: 30 * u),
    );
    return glow ? Breathing(amount: 0.08, child: icon) : icon;
  }
}
