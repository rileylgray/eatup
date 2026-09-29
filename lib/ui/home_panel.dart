import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/progress.dart';
import '../core/strings.dart';
import '../game/growth.dart';
import '../game/maps.dart';
import 'daily_gift.dart';
import 'monster_view.dart';
import 'settings_sheet.dart';
import 'store_panel.dart';
import 'theme.dart';
import 'wheel_dialog.dart';
import 'widgets.dart';

class HomePanel extends StatefulWidget {
  const HomePanel({
    super.key,
    required this.onPlay,
    required this.onStore,
    required this.onMaps,
    required this.onMissions,
  });

  final VoidCallback onPlay, onMaps, onMissions;
  final ValueChanged<StoreTab> onStore;

  @override
  State<HomePanel> createState() => _HomePanelState();
}

class _HomePanelState extends State<HomePanel> with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 4))
    ..repeat();

  @override
  void initState() {
    super.initState();
    // Missions roll over at midnight even if the app stayed open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<Progress>().checkDay();
    });
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  void _cycleMap(Progress p, int dir) {
    final open = maps.where(p.isMapUnlocked).toList();
    final i = open.indexWhere((m) => m.id == p.mapId);
    p.selectMap(open[(i + dir) % open.length].id);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<Progress>();
    final s = Strings.of(context);
    final u = context.u;
    final map = p.map;
    final multipleMaps = maps.where(p.isMapUnlocked).length > 1;
    final best = p.bestRadius[map.id] ?? 0;

    return DecoratedBox(
      // Darken the top and bottom so the UI reads over the busy town.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x99160E2C), Color(0x00160E2C), Color(0x00160E2C), Color(0xB3160E2C)],
          stops: [0, 0.25, 0.55, 1],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 480 * u),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16 * u, 12 * u, 16 * u, 16 * u),
              child: Column(
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: CoinPill(coins: p.coins, onTap: () => widget.onStore(StoreTab.coins)),
                        ),
                      ),
                      SizedBox(width: 8 * u),
                      _LevelChip(p: p),
                      const Spacer(),
                      IconBubble(icon: Icons.casino_rounded, badge: p.wheelFreeReady, onTap: () => showWheel(context)),
                      SizedBox(width: 8 * u),
                      IconBubble(
                        icon: Icons.card_giftcard_rounded,
                        badge: p.dailyAvailable(),
                        onTap: () => showDailyGift(context),
                      ),
                      SizedBox(width: 8 * u),
                      IconBubble(icon: Icons.settings_rounded, onTap: () => showSettings(context)),
                    ],
                  ),
                  Expanded(
                    flex: 4,
                    child: AnimatedBuilder(
                      animation: _float,
                      builder: (_, child) =>
                          Transform.translate(offset: Offset(0, sin(_float.value * 2 * pi) * 5 * u), child: child),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Eat', style: fredoka(72 * u, weight: 700, shadow: true, height: 1)),
                                  Text(
                                    'Up!',
                                    style: fredoka(72 * u, weight: 700, shadow: true, height: 1, color: AppColors.gold),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6 * u),
                              Text(s.tagline, style: fredoka(17 * u, weight: 500, shadow: true)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Pressable(
                      onTap: () => widget.onStore(StoreTab.skins),
                      child: LayoutBuilder(
                        builder: (_, c) => Center(
                          child: MonsterView(skin: p.skin, size: min(c.maxHeight, 220 * u)),
                        ),
                      ),
                    ),
                  ),
                  GlassCard(
                    padding: EdgeInsets.symmetric(horizontal: 6 * u, vertical: 10 * u),
                    color: AppColors.glassDark,
                    child: Row(
                      children: [
                        _Arrow(icon: Icons.chevron_left_rounded, onTap: multipleMaps ? () => _cycleMap(p, -1) : null),
                        Expanded(
                          child: Pressable(
                            onTap: widget.onMaps,
                            child: Column(
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child: FittedBox(
                                    key: ValueKey(map.id),
                                    fit: BoxFit.scaleDown,
                                    child: Text(s.mapName(map.id), style: fredoka(22 * u, weight: 700)),
                                  ),
                                ),
                                SizedBox(height: 4 * u),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CoinIcon(size: 15 * u),
                                      SizedBox(width: 4 * u),
                                      Text(
                                        s.coinsX(map.coinMult),
                                        style: fredoka(14 * u, weight: 600, color: AppColors.gold),
                                      ),
                                      if (best > 0) ...[
                                        SizedBox(width: 10 * u),
                                        Text(
                                          s.best(Growth.metres(best).toStringAsFixed(1)),
                                          style: fredoka(14 * u, weight: 500, color: AppColors.textDim),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _Arrow(icon: Icons.chevron_right_rounded, onTap: multipleMaps ? () => _cycleMap(p, 1) : null),
                      ],
                    ),
                  ),
                  SizedBox(height: 14 * u),
                  Breathing(
                    child: GoldButton(
                      label: s.play,
                      icon: Icons.play_arrow_rounded,
                      onTap: widget.onPlay,
                      height: 68,
                      fontSize: 28,
                    ),
                  ),
                  SizedBox(height: 12 * u),
                  Row(
                    children: [
                      Expanded(
                        child: _MenuButton(
                          icon: Icons.pets_rounded,
                          label: s.skins,
                          onTap: () => widget.onStore(StoreTab.skins),
                        ),
                      ),
                      SizedBox(width: 10 * u),
                      Expanded(
                        child: _MenuButton(
                          icon: Icons.flag_rounded,
                          label: s.missions,
                          count: p.missionsClaimable,
                          onTap: widget.onMissions,
                        ),
                      ),
                      SizedBox(width: 10 * u),
                      Expanded(
                        child: _MenuButton(
                          icon: Icons.upgrade_rounded,
                          label: s.upgradesTab,
                          onTap: () => widget.onStore(StoreTab.upgrades),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The player's level in a ring that fills with XP.
class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.p});
  final Progress p;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    final d = 44 * u;
    return SizedBox.square(
      dimension: d,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.glassDark,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x3DFFFFFF)),
            ),
          ),
          SizedBox.square(
            dimension: d - 6 * u,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: p.xpInLevel / p.xpForNext),
              duration: const Duration(milliseconds: 600),
              builder: (_, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: 4 * u,
                color: AppColors.sky,
                backgroundColor: Colors.white12,
                strokeCap: StrokeCap.round,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('LV', style: fredoka(8 * u, weight: 700, color: AppColors.sky, height: 1)),
              Text('${p.level}', style: fredoka(16 * u, weight: 700, height: 1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.icon, required this.label, required this.onTap, this.count = 0});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int count;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GlassButton(
          onTap: onTap,
          height: 64,
          padding: EdgeInsets.symmetric(horizontal: 6 * u),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24 * u),
              SizedBox(height: 2 * u),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: fredoka(14 * u, weight: 600)),
              ),
            ],
          ),
        ),
        if (count > 0)
          Positioned(
            right: -2,
            top: -4,
            child: CountBadge(count: count, size: 20 * u),
          ),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(6 * context.u),
        child: Icon(icon, size: 34 * context.u, color: onTap == null ? Colors.white24 : Colors.white),
      ),
    );
  }
}
