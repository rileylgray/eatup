import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets.dart';

/// Frame for full panels (lakes, store): dims the lake behind and gives a
/// back button, a title and an optional trailing widget.
class PanelScaffold extends StatelessWidget {
  const PanelScaffold({super.key, required this.title, required this.onClose, required this.child, this.trailing});

  final String title;
  final VoidCallback onClose;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xB3160E2C), Color(0xEB160E2C)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 620 * u),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(12 * u, 10 * u, 16 * u, 10 * u),
                  child: Row(
                    children: [
                      IconBubble(icon: Icons.arrow_back_rounded, onTap: onClose),
                      SizedBox(width: 12 * u),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(title, style: fredoka(28 * u, weight: 700)),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
