import 'package:flutter/material.dart';

import '../core/strings.dart';
import 'theme.dart';
import 'widgets.dart';

class PausePanel extends StatelessWidget {
  const PausePanel({super.key, required this.onResume, required this.onLeave});

  final VoidCallback onResume, onLeave;

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
              constraints: BoxConstraints(maxWidth: 380 * u),
              child: GlassCard(
                padding: EdgeInsets.all(20 * u),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.paused, style: fredoka(30 * u, weight: 700)),
                    SizedBox(height: 18 * u),
                    GoldButton(label: s.resume, icon: Icons.play_arrow_rounded, onTap: onResume),
                    SizedBox(height: 12 * u),
                    GlassButton(
                      onTap: onLeave,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.logout_rounded, color: Colors.white, size: 20 * u),
                            SizedBox(width: 8 * u),
                            Text(s.leaveRound, style: fredoka(17 * u, weight: 600)),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 8 * u),
                    Text(
                      s.leaveWarning,
                      textAlign: TextAlign.center,
                      style: fredoka(13 * u, weight: 400, color: AppColors.textDim),
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
