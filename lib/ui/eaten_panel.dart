import 'dart:async';

import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../game/skins.dart';
import 'monster_view.dart';
import 'theme.dart';
import 'widgets.dart';

/// Shown when a rival swallows the player: one revive per round for a video,
/// on a short countdown so declining is never a chore.
class EatenPanel extends StatefulWidget {
  const EatenPanel({
    super.key,
    required this.eaterName,
    required this.skin,
    required this.onRevive,
    required this.onDecline,
  });

  final String eaterName;
  final SkinDef skin;
  final Future<void> Function() onRevive;
  final VoidCallback onDecline;

  static const Duration offer = Duration(seconds: 6);

  @override
  State<EatenPanel> createState() => _EatenPanelState();
}

class _EatenPanelState extends State<EatenPanel> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this, duration: EatenPanel.offer)
    ..forward()
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && !_watching) widget.onDecline();
    });
  bool _watching = false;

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  Future<void> _revive() async {
    if (_watching) return;
    setState(() => _watching = true);
    _clock.stop();
    await widget.onRevive();
    if (!mounted) return;
    // Still here: no video. The clock carries on.
    setState(() => _watching = false);
    unawaited(_clock.forward());
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final u = context.u;
    return ColoredBox(
      color: const Color(0x99140C28),
      child: SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24 * u),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 400 * u),
              child: GlassCard(
                padding: EdgeInsets.all(20 * u),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.eatenBy(widget.eaterName), textAlign: TextAlign.center, style: fredoka(26 * u, weight: 700)),
                    SizedBox(height: 8 * u),
                    SizedBox.square(
                      dimension: 150 * u,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _clock,
                            builder: (_, _) => SizedBox.square(
                              dimension: 140 * u,
                              child: CircularProgressIndicator(
                                value: 1 - _clock.value,
                                strokeWidth: 7 * u,
                                color: AppColors.gold,
                                backgroundColor: Colors.white12,
                              ),
                            ),
                          ),
                          Opacity(
                            opacity: 0.85,
                            child: MonsterView(skin: widget.skin, size: 130 * u),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14 * u),
                    RewardButton(
                      height: 58,
                      onTap: _revive,
                      label: Text(s.revive, style: fredoka(22 * u, weight: 700)),
                    ),
                    SizedBox(height: 12 * u),
                    Pressable(
                      onTap: _watching ? null : widget.onDecline,
                      child: Padding(
                        padding: EdgeInsets.all(8 * u),
                        child: Text(s.noThanks, style: fredoka(16 * u, weight: 500, color: AppColors.textDim)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
