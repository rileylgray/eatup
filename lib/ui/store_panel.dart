import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ads/ad_manager.dart';
import '../core/analytics.dart';
import '../core/live_config.dart';
import '../core/progress.dart';
import '../core/purchases.dart';
import '../core/sound.dart';
import '../core/strings.dart';
import '../game/skins.dart';
import '../game/upgrades.dart';
import 'monster_view.dart';
import 'panel_scaffold.dart';
import 'theme.dart';
import 'widgets.dart';

enum StoreTab { skins, upgrades, coins }

class StorePanel extends StatefulWidget {
  const StorePanel({super.key, required this.onClose, this.initialTab = StoreTab.skins});

  final VoidCallback onClose;
  final StoreTab initialTab;

  @override
  State<StorePanel> createState() => _StorePanelState();
}

class _StorePanelState extends State<StorePanel> {
  late StoreTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<Progress>();
    final s = Strings.of(context);
    final u = context.u;
    return PanelScaffold(
      title: s.store,
      onClose: widget.onClose,
      trailing: CoinPill(coins: p.coins),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16 * u),
            child: Tabs(
              labels: [s.skins, s.upgradesTab, s.coinsTab],
              index: _tab.index,
              onChanged: (i) => setState(() => _tab = StoreTab.values[i]),
            ),
          ),
          SizedBox(height: 10 * u),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: switch (_tab) {
                StoreTab.skins => const _SkinGrid(key: ValueKey(0)),
                StoreTab.upgrades => const _UpgradeList(key: ValueKey(1)),
                StoreTab.coins => const _CoinsTab(key: ValueKey(2)),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A pill tab bar with a sliding gold marker.
class Tabs extends StatelessWidget {
  const Tabs({super.key, required this.labels, required this.index, required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return Container(
      height: 46 * u,
      padding: EdgeInsets.all(4 * u),
      decoration: BoxDecoration(color: AppColors.glassDark, borderRadius: BorderRadius.circular(23 * u)),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: w * index,
                width: w,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(19 * u)),
                ),
              ),
              Row(
                children: List.generate(labels.length, (i) {
                  return Expanded(
                    child: Pressable(
                      onTap: () => onChanged(i),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4 * u),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              labels[i],
                              style: fredoka(16 * u, weight: 700, color: i == index ? AppColors.ink : Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Skins -------------------------------------------------------------------------

class _SkinGrid extends StatelessWidget {
  const _SkinGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    final w = MediaQuery.sizeOf(context).width;
    final cols = w > 700 ? 4 : 3;
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16 * u, 2 * u, 16 * u, 24 * u),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 10 * u,
        crossAxisSpacing: 10 * u,
        childAspectRatio: 0.72,
      ),
      itemCount: skins.length,
      itemBuilder: (_, i) => _SkinCard(skin: skins[i]),
    );
  }
}

class _SkinCard extends StatefulWidget {
  const _SkinCard({required this.skin});
  final SkinDef skin;

  @override
  State<_SkinCard> createState() => _SkinCardState();
}

class _SkinCardState extends State<_SkinCard> {
  bool _watching = false;

  Future<void> _tap(Progress p) async {
    final s = Strings.of(context);
    final skin = widget.skin;
    if (p.ownedSkins.contains(skin.id)) {
      p.selectSkin(skin.id);
      Sound.instance.fx(Sfx.pop);
      return;
    }
    if (!p.skinLevelOk(skin)) {
      showToast(context, s.reachLevel(skin.unlockLevel), icon: Icons.lock_rounded);
      return;
    }
    if (skin.videos > 0) {
      if (_watching) return;
      setState(() => _watching = true);
      final earned = await AdManager.instance.showRewarded('skin_${skin.id}');
      if (!mounted) return;
      setState(() => _watching = false);
      if (earned) {
        if (p.addSkinVideo(skin)) {
          Sound.instance.fx(Sfx.levelup);
          Analytics.instance.event('skin_unlocked', {'id': skin.id, 'via': 'video'});
        } else {
          Sound.instance.fx(Sfx.star);
        }
      } else if (!AdManager.instance.rewardedReady.value) {
        showToast(context, s.videoUnavailable, icon: Icons.videocam_off_rounded);
      }
      return;
    }
    if (p.buySkin(skin)) {
      Sound.instance.fx(Sfx.levelup);
      Analytics.instance.event('skin_bought', {'id': skin.id, 'price': skin.price});
    } else {
      showToast(context, s.notEnoughCoins, icon: Icons.savings_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<Progress>();
    final s = Strings.of(context);
    final u = context.u;
    final skin = widget.skin;
    final owned = p.ownedSkins.contains(skin.id);
    final selected = p.skinId == skin.id;
    final levelOk = p.skinLevelOk(skin);

    final Widget action;
    if (selected) {
      action = _Tag(text: s.inUse, color: AppColors.mint, dark: true);
    } else if (owned) {
      action = _Tag(text: s.use, color: Colors.white24);
    } else if (!levelOk) {
      action = _Tag(text: s.reachLevel(skin.unlockLevel), color: Colors.white12, icon: Icons.lock_rounded);
    } else if (skin.videos > 0) {
      action = _Tag(
        text: '${p.videosFor(skin)}/${skin.videos}',
        color: const Color(0xFF2FAE63),
        icon: Icons.play_circle_fill_rounded,
      );
    } else {
      action = _Tag(
        text: '${skin.price}',
        color: p.coins >= skin.price ? AppColors.gold : Colors.white24,
        coin: true,
        dark: true,
      );
    }

    return Pressable(
      onTap: () => _tap(p),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(6 * u),
        decoration: BoxDecoration(
          color: selected ? const Color(0x33FFC94A) : AppColors.panel,
          borderRadius: BorderRadius.circular(18 * u),
          border: Border.all(color: selected ? AppColors.gold : const Color(0x2EFFFFFF), width: selected ? 2.5 : 1),
        ),
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (_, c) => MonsterView(
                  skin: skin,
                  size: c.biggest.shortestSide,
                  animate: selected,
                  locked: !owned && !levelOk,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(skinNames[skin.id] ?? skin.id, style: fredoka(14 * u, weight: 700)),
            ),
            SizedBox(height: 4 * u),
            action,
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color, this.icon, this.coin = false, this.dark = false});
  final String text;
  final Color color;
  final IconData? icon;
  final bool coin, dark;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    final fg = dark ? AppColors.ink : Colors.white;
    return Container(
      height: 28 * u,
      padding: EdgeInsets.symmetric(horizontal: 8 * u),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14 * u)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (coin) ...[CoinIcon(size: 16 * u), SizedBox(width: 4 * u)],
            if (icon != null) ...[Icon(icon, size: 16 * u, color: fg), SizedBox(width: 4 * u)],
            Text(text, style: fredoka(14 * u, weight: 700, color: fg)),
          ],
        ),
      ),
    );
  }
}

// Upgrades --------------------------------------------------------------------

IconData _upgradeIcon(String id) => switch (id) {
  'size' => Icons.open_in_full_rounded,
  'speed' => Icons.speed_rounded,
  'time' => Icons.timer_rounded,
  'reach' => Icons.all_out_rounded,
  _ => Icons.savings_rounded,
};

class _UpgradeList extends StatelessWidget {
  const _UpgradeList({super.key});

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16 * u, 2 * u, 16 * u, 24 * u),
      itemCount: upgrades.length,
      separatorBuilder: (_, _) => SizedBox(height: 10 * u),
      itemBuilder: (_, i) => _UpgradeRow(upgrade: upgrades[i]),
    );
  }
}

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow({required this.upgrade});
  final UpgradeDef upgrade;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<Progress>();
    final s = Strings.of(context);
    final u = context.u;
    final level = p.levelOf(upgrade);
    final maxed = level >= UpgradeDef.maxLevel;
    final cost = maxed ? 0 : upgrade.costAt(level);
    final affordable = !maxed && p.coins >= cost;

    return GlassCard(
      padding: EdgeInsets.all(12 * u),
      radius: 18,
      child: Row(
        children: [
          Container(
            width: 50 * u,
            height: 50 * u,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF9B6BF0), Color(0xFF6A3FC8)]),
              borderRadius: BorderRadius.circular(14 * u),
            ),
            child: Icon(_upgradeIcon(upgrade.id), color: Colors.white, size: 28 * u),
          ),
          SizedBox(width: 12 * u),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        s.upgradeName(upgrade.id),
                        overflow: TextOverflow.ellipsis,
                        style: fredoka(17 * u, weight: 700),
                      ),
                    ),
                    SizedBox(width: 6 * u),
                    Text(maxed ? s.max : s.level(level), style: fredoka(13 * u, weight: 600, color: AppColors.gold)),
                  ],
                ),
                SizedBox(height: 2 * u),
                Text(
                  s.upgradeDesc(upgrade.id),
                  maxLines: 2,
                  style: fredoka(13 * u, weight: 400, color: AppColors.textDim, height: 1.2),
                ),
                SizedBox(height: 6 * u),
                _Pips(level: level),
              ],
            ),
          ),
          SizedBox(width: 10 * u),
          maxed
              ? Icon(Icons.verified_rounded, color: AppColors.gold, size: 30 * u)
              : _PriceButton(
                  cost: cost,
                  enabled: affordable,
                  onTap: () {
                    if (p.buyUpgrade(upgrade)) {
                      Sound.instance.fx(Sfx.coin);
                      Analytics.instance.event('upgrade_bought', {'id': upgrade.id, 'level': level + 1});
                    } else {
                      showToast(context, s.notEnoughCoins, icon: Icons.savings_rounded);
                    }
                  },
                ),
        ],
      ),
    );
  }
}

class _Pips extends StatelessWidget {
  const _Pips({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return Row(
      children: List.generate(UpgradeDef.maxLevel, (i) {
        final on = i < level;
        return Expanded(
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200 + i * 20),
            height: 6 * u,
            margin: EdgeInsets.only(right: 3 * u),
            decoration: BoxDecoration(
              color: on ? AppColors.gold : Colors.white24,
              borderRadius: BorderRadius.circular(3 * u),
            ),
          ),
        );
      }),
    );
  }
}

class _PriceButton extends StatelessWidget {
  const _PriceButton({required this.cost, required this.enabled, required this.onTap});
  final int cost;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return Pressable(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.5,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 42 * u,
          constraints: BoxConstraints(minWidth: 84 * u),
          padding: EdgeInsets.symmetric(horizontal: 12 * u),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21 * u),
            gradient: const LinearGradient(colors: [Color(0xFFFFDA70), AppColors.gold]),
            boxShadow: const [BoxShadow(color: AppColors.goldDark, offset: Offset(0, 3))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CoinIcon(size: 20 * u),
              SizedBox(width: 6 * u),
              Text('$cost', style: fredoka(17 * u, weight: 700, color: AppColors.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

// Coins --------------------------------------------------------------------------

class _CoinsTab extends StatefulWidget {
  const _CoinsTab({super.key});

  @override
  State<_CoinsTab> createState() => _CoinsTabState();
}

class _CoinsTabState extends State<_CoinsTab> {
  @override
  void initState() {
    super.initState();
    Purchases.instance.lastResult.addListener(_purchaseResult);
  }

  @override
  void dispose() {
    Purchases.instance.lastResult.removeListener(_purchaseResult);
    super.dispose();
  }

  void _purchaseResult() {
    final r = Purchases.instance.lastResult.value;
    if (r == null || !mounted) return;
    final s = Strings.of(context);
    if (r) {
      Sound.instance.fx(Sfx.levelup);
      showToast(context, s.purchaseThanks, icon: Icons.favorite_rounded);
    } else {
      showToast(context, s.purchaseFailed, icon: Icons.error_outline_rounded);
    }
    Purchases.instance.lastResult.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    final s = Strings.of(context);
    final p = context.watch<Progress>();
    return ListenableBuilder(
      listenable: Purchases.instance,
      builder: (context, _) {
        final iap = Purchases.instance;
        final products = iap.products;
        return ListView(
          padding: EdgeInsets.fromLTRB(16 * u, 2 * u, 16 * u, 24 * u),
          children: [
            const _FreeCoinsCard(),
            SizedBox(height: 12 * u),
            if (!p.noAds && products.containsKey(Purchases.removeAds)) ...[
              _RemoveAdsCard(price: products[Purchases.removeAds]!.price, busy: iap.busy),
              SizedBox(height: 12 * u),
            ],
            if (p.noAds) ...[
              GlassCard(
                padding: EdgeInsets.all(14 * u),
                child: Row(
                  children: [
                    Icon(Icons.block_rounded, color: AppColors.mint, size: 28 * u),
                    SizedBox(width: 12 * u),
                    Text(s.adsRemoved, style: fredoka(17 * u, weight: 700)),
                  ],
                ),
              ),
              SizedBox(height: 12 * u),
            ],
            Padding(
              padding: EdgeInsets.only(left: 4 * u, bottom: 8 * u),
              child: Text(s.coinPacks, style: fredoka(18 * u, weight: 700)),
            ),
            if (products.keys.any(Purchases.coinPacks.containsKey))
              for (final e in Purchases.coinPacks.entries)
                if (products[e.key] != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 10 * u),
                    child: _PackRow(
                      coins: e.value,
                      price: products[e.key]!.price,
                      best: e.key == 'eatup_coins_large',
                      onTap: iap.busy ? null : () => iap.buy(e.key),
                    ),
                  )
                else
                  const SizedBox.shrink()
            else
              GlassCard(
                padding: EdgeInsets.all(16 * u),
                child: Text(
                  s.storeUnavailable,
                  textAlign: TextAlign.center,
                  style: fredoka(15 * u, weight: 500, color: AppColors.textDim),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RemoveAdsCard extends StatelessWidget {
  const _RemoveAdsCard({required this.price, required this.busy});
  final String price;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    final s = Strings.of(context);
    return GlassCard(
      padding: EdgeInsets.all(14 * u),
      color: const Color(0xCC3A1F5E),
      child: Row(
        children: [
          Container(
            width: 50 * u,
            height: 50 * u,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF7FA6), AppColors.pink]),
              borderRadius: BorderRadius.circular(14 * u),
            ),
            child: Icon(Icons.block_rounded, color: Colors.white, size: 28 * u),
          ),
          SizedBox(width: 12 * u),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.removeAds, style: fredoka(18 * u, weight: 700)),
                Text(s.removeAdsDesc, style: fredoka(13 * u, weight: 400, color: AppColors.textDim, height: 1.2)),
              ],
            ),
          ),
          SizedBox(width: 10 * u),
          PinkButton(
            label: price,
            height: 44,
            fontSize: 16,
            onTap: busy ? null : () => Purchases.instance.buy(Purchases.removeAds),
          ),
        ],
      ),
    );
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({required this.coins, required this.price, required this.best, required this.onTap});
  final int coins;
  final String price;
  final bool best;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    final s = Strings.of(context);
    return GlassCard(
      padding: EdgeInsets.all(12 * u),
      radius: 18,
      color: best ? const Color(0xCC4A3510) : null,
      child: Row(
        children: [
          SizedBox(
            width: 54 * u,
            height: 44 * u,
            child: Stack(
              children: [
                for (
                  var i = 0;
                  i <
                      (coins >= 20000
                          ? 3
                          : coins >= 6000
                          ? 2
                          : 1);
                  i++
                )
                  Positioned(
                    left: i * 9 * u,
                    top: (2 - i) * 4 * u,
                    child: CoinIcon(size: 34 * u),
                  ),
              ],
            ),
          ),
          SizedBox(width: 10 * u),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$coins', style: fredoka(20 * u, weight: 700, color: AppColors.gold)),
                if (best) Text(s.bestValue, style: fredoka(13 * u, weight: 600, color: AppColors.pink)),
              ],
            ),
          ),
          GoldButton(label: price, onTap: onTap, height: 44, fontSize: 17, expand: false),
        ],
      ),
    );
  }
}

/// Watch a video for coins, on a short cooldown.
class _FreeCoinsCard extends StatefulWidget {
  const _FreeCoinsCard();

  @override
  State<_FreeCoinsCard> createState() => _FreeCoinsCardState();
}

class _FreeCoinsCardState extends State<_FreeCoinsCard> {
  Timer? _tick;
  bool _watching = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _watch(Progress p) async {
    if (_watching) return;
    final s = Strings.of(context);
    setState(() => _watching = true);
    final earned = await AdManager.instance.showRewarded('free_coins');
    if (!mounted) return;
    setState(() => _watching = false);
    if (earned) {
      p.claimFreeCoins();
      Sound.instance.fx(Sfx.coin);
    } else if (!AdManager.instance.rewardedReady.value) {
      showToast(context, s.videoUnavailable, icon: Icons.videocam_off_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<Progress>();
    final s = Strings.of(context);
    final u = context.u;
    final wait = p.freeCoinsWait();
    final ready = wait == Duration.zero;
    final amount = LiveConfig.instance.freeCoinsAmount;

    return GlassCard(
      padding: EdgeInsets.symmetric(horizontal: 14 * u, vertical: 12 * u),
      color: const Color(0xCC1B3A2A),
      child: Row(
        children: [
          CoinIcon(size: 40 * u),
          SizedBox(width: 12 * u),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.freeCoins, style: fredoka(18 * u, weight: 700)),
                Text('+$amount', style: fredoka(15 * u, weight: 600, color: AppColors.gold)),
              ],
            ),
          ),
          if (ready)
            RewardButton(
              height: 44,
              onTap: () => _watch(p),
              label: Text('+$amount', style: fredoka(17 * u, weight: 700)),
            )
          else
            _Countdown(wait: wait),
        ],
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.wait});
  final Duration wait;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return Container(
      height: 44 * u,
      padding: EdgeInsets.symmetric(horizontal: 14 * u),
      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(22 * u)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 18 * u, color: Colors.white70),
          SizedBox(width: 6 * u),
          Text(formatWait(wait), style: fredoka(16 * u, weight: 600, color: Colors.white70)),
        ],
      ),
    );
  }
}

/// "4:05" or "2:14:09".
String formatWait(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// Settings -> Restore purchases is only a thing on iOS (Android restores
/// on its own when the purchase stream opens).
bool get showRestore => !kIsWeb && Platform.isIOS;
