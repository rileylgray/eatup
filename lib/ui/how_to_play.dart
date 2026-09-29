import 'package:flutter/material.dart';

import '../core/strings.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showHowToPlay(BuildContext context) {
  return showDialog<void>(context: context, barrierColor: const Color(0x99140C28), builder: (_) => const _HowToPlay());
}

class _HowToPlay extends StatelessWidget {
  const _HowToPlay();

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final u = context.u;
    final tips = [
      (Icons.pan_tool_alt_rounded, s.hintMove, AppColors.sky),
      (Icons.restaurant_rounded, s.hintEat, AppColors.mint),
      (Icons.apartment_rounded, s.hintBuilding, AppColors.gold),
      (Icons.warning_rounded, s.hintAvoid, AppColors.danger),
      (Icons.bolt_rounded, '${s.hintSpeed}  ${s.hintMagnet}  ${s.hintFrenzy}', const Color(0xFFB06BFF)),
    ];
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
                  Icon(Icons.school_rounded, color: AppColors.gold, size: 28 * u),
                  SizedBox(width: 10 * u),
                  Expanded(child: Text(s.howToPlay, style: fredoka(24 * u, weight: 700))),
                  IconBubble(icon: Icons.close_rounded, size: 38, onTap: () => Navigator.pop(context)),
                ],
              ),
              SizedBox(height: 12 * u),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final (icon, text, color) in tips)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 5 * u),
                          child: Row(
                            children: [
                              Container(
                                width: 44 * u,
                                height: 44 * u,
                                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(13 * u)),
                                child: Icon(icon, color: Colors.white, size: 24 * u),
                              ),
                              SizedBox(width: 12 * u),
                              Expanded(child: Text(text, style: fredoka(16 * u, weight: 500, height: 1.25))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
