import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/progress.dart';
import '../core/sound.dart';
import '../core/strings.dart';
import '../game/growth.dart';
import '../game/maps.dart';
import 'panel_scaffold.dart';
import 'theme.dart';
import 'widgets.dart';

class MapsPanel extends StatelessWidget {
  const MapsPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final u = context.u;
    return PanelScaffold(
      title: s.maps,
      onClose: onClose,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(16 * u, 2 * u, 16 * u, 24 * u),
        itemCount: maps.length,
        separatorBuilder: (_, _) => SizedBox(height: 12 * u),
        itemBuilder: (_, i) => _MapCard(map: maps[i], onPicked: onClose),
      ),
    );
  }
}

IconData mapIcon(String id) => switch (id) {
  'beach' => Icons.beach_access_rounded,
  'farm' => Icons.agriculture_rounded,
  'snow' => Icons.ac_unit_rounded,
  'city' => Icons.location_city_rounded,
  _ => Icons.house_rounded,
};

class _MapCard extends StatelessWidget {
  const _MapCard({required this.map, required this.onPicked});
  final MapDef map;
  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<Progress>();
    final s = Strings.of(context);
    final u = context.u;
    final open = p.isMapUnlocked(map);
    final selected = p.mapId == map.id;
    final best = p.bestRadius[map.id] ?? 0;
    final wins = p.wins[map.id] ?? 0;
    final g = map.ground;

    return Pressable(
      onTap: () {
        if (!open) {
          showToast(context, s.reachLevel(map.unlockLevel), icon: Icons.lock_rounded);
          return;
        }
        p.selectMap(map.id);
        Sound.instance.fx(Sfx.pop);
        onPicked();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20 * u),
          border: Border.all(color: selected ? AppColors.gold : const Color(0x2EFFFFFF), width: selected ? 2.5 : 1),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // A tiny painted street as the card's backdrop.
            Positioned.fill(
              child: CustomPaint(painter: _MapThumb(g, sea: map.sea)),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xE6160E2C), const Color(0x66160E2C)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(14 * u),
              child: Row(
                children: [
                  Container(
                    width: 56 * u,
                    height: 56 * u,
                    decoration: BoxDecoration(
                      color: open ? g.grass : Colors.white12,
                      borderRadius: BorderRadius.circular(16 * u),
                      border: Border.all(color: Colors.white54, width: 2),
                    ),
                    child: Icon(
                      open ? mapIcon(map.id) : Icons.lock_rounded,
                      color: open ? AppColors.ink : Colors.white70,
                      size: 30 * u,
                    ),
                  ),
                  SizedBox(width: 12 * u),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.mapName(map.id), style: fredoka(20 * u, weight: 700)),
                        SizedBox(height: 4 * u),
                        Wrap(
                          spacing: 10 * u,
                          runSpacing: 4 * u,
                          children: [
                            _Info(
                              icon: Icons.monetization_on_rounded,
                              text: s.coinsX(map.coinMult),
                              color: AppColors.gold,
                            ),
                            _Info(icon: Icons.groups_rounded, text: s.rivals(map.rivals)),
                            if (open && best > 0)
                              _Info(
                                icon: Icons.straighten_rounded,
                                text: s.best(Growth.metres(best).toStringAsFixed(1)),
                              ),
                            if (open && wins > 0) _Info(icon: Icons.emoji_events_rounded, text: s.wins(wins)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!open)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10 * u, vertical: 6 * u),
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12 * u)),
                      child: Text(s.reachLevel(map.unlockLevel), style: fredoka(13 * u, weight: 700)),
                    )
                  else if (selected)
                    Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 30 * u),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text, this.color = AppColors.textDim});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15 * u, color: color),
        SizedBox(width: 3 * u),
        Text(text, style: fredoka(13 * u, weight: 600, color: color)),
      ],
    );
  }
}

class _MapThumb extends CustomPainter {
  _MapThumb(this.g, {required this.sea});
  final GroundPalette g;
  final bool sea;

  @override
  void paint(Canvas c, Size size) {
    c.drawRect(Offset.zero & size, Paint()..color = g.grass);
    final road = Paint()..color = g.road;
    final walk = Paint()..color = g.sidewalk;
    final w = size.width, h = size.height;
    c.drawRect(Rect.fromLTWH(w * 0.62 - 14, 0, 28, h), walk);
    c.drawRect(Rect.fromLTWH(0, h * 0.5 - 14, w, 28), walk);
    c.drawRect(Rect.fromLTWH(w * 0.62 - 10, 0, 20, h), road);
    c.drawRect(Rect.fromLTWH(0, h * 0.5 - 10, w, 20), road);
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.72, h * 0.08, w * 0.2, h * 0.3), const Radius.circular(8)),
      Paint()..color = g.plaza,
    );
    c.drawOval(Rect.fromLTWH(w * 0.78, h * 0.62, w * 0.12, h * 0.3), Paint()..color = g.water);
    if (sea) c.drawRect(Rect.fromLTWH(0, h * 0.82, w, h * 0.18), Paint()..color = g.water);
  }

  @override
  bool shouldRepaint(_MapThumb old) => old.g != g;
}
