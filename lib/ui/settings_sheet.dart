import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ads/ad_manager.dart';
import '../core/ads/consent_manager.dart';
import '../core/progress.dart';
import '../core/purchases.dart';
import '../core/review.dart';
import '../core/sound.dart';
import '../core/strings.dart';
import 'how_to_play.dart';
import 'store_panel.dart' show showRestore;
import 'theme.dart';
import 'widgets.dart';

/// Keep in step with `version:` in pubspec.yaml.
const String appVersion = '1.0.0';

Future<void> showSettings(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool _privacyRequired = false;

  @override
  void initState() {
    super.initState();
    ConsentManager().hasPrivacyOptions().then((v) {
      if (mounted) setState(() => _privacyRequired = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<Progress>();
    final s = Strings.of(context);
    final u = context.u;
    final maxH = MediaQuery.sizeOf(context).height * 0.85;

    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560 * u, maxHeight: maxH),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xF2241A3E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26 * u)),
            border: Border.all(color: const Color(0x2EFFFFFF)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20 * u, 10 * u, 20 * u, 16 * u),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44 * u,
                    height: 5 * u,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3)),
                  ),
                  SizedBox(height: 12 * u),
                  Text(s.settings, style: fredoka(26 * u, weight: 700)),
                  SizedBox(height: 12 * u),
                  _SwitchRow(
                    icon: Icons.volume_up_rounded,
                    label: s.sound,
                    value: p.sound,
                    onChanged: (v) {
                      p.setSound(v);
                      Sound.instance.sfxOn = v;
                    },
                  ),
                  _SwitchRow(
                    icon: Icons.music_note_rounded,
                    label: s.music,
                    value: p.music,
                    onChanged: (v) {
                      p.setMusic(v);
                      Sound.instance.musicOn = v;
                    },
                  ),
                  _SwitchRow(
                    icon: Icons.vibration_rounded,
                    label: s.haptics,
                    value: p.haptics,
                    onChanged: (v) {
                      p.setHaptics(v);
                      Sound.instance.hapticsOn = v;
                      if (v) Sound.instance.haptic(Sfx.gulp);
                    },
                  ),
                  _Row(
                    icon: Icons.language_rounded,
                    label: s.language,
                    trailing: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: p.localeCode,
                        dropdownColor: AppColors.panel,
                        borderRadius: BorderRadius.circular(14),
                        style: fredoka(16 * u, weight: 500),
                        items: [
                          DropdownMenuItem(value: null, child: Text(s.deviceLanguage)),
                          for (final code in Strings.languages)
                            DropdownMenuItem(value: code, child: Text(Strings.nativeNames[code]!)),
                        ],
                        onChanged: p.setLocale,
                      ),
                    ),
                  ),
                  _Row(icon: Icons.school_rounded, label: s.howToPlay, onTap: () => showHowToPlay(context)),
                  _Row(icon: Icons.star_rate_rounded, label: s.rateUs, onTap: Review.instance.openStore),
                  if (showRestore)
                    _Row(icon: Icons.restore_rounded, label: s.restorePurchases, onTap: Purchases.instance.restore),
                  if (_privacyRequired)
                    _Row(
                      icon: Icons.privacy_tip_rounded,
                      label: s.privacy,
                      onTap: () async {
                        await ConsentManager().showPrivacyOptions();
                        await AdManager.instance.startIfAllowed();
                      },
                    ),
                  SizedBox(height: 10 * u),
                  Text('${s.version} $appVersion', style: fredoka(13 * u, weight: 400, color: AppColors.textDim)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, this.trailing, this.onTap});
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final u = context.u;
    final row = Container(
      constraints: BoxConstraints(minHeight: 56 * u),
      margin: EdgeInsets.symmetric(vertical: 4 * u),
      padding: EdgeInsets.symmetric(horizontal: 14 * u),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16 * u),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 24 * u),
          SizedBox(width: 12 * u),
          Expanded(child: Text(label, style: fredoka(17 * u, weight: 500))),
          trailing ?? Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 24 * u),
        ],
      ),
    );
    return onTap == null ? row : Pressable(onTap: onTap, child: row);
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.icon, required this.label, required this.value, required this.onChanged});
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Row(
      icon: icon,
      label: label,
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}
