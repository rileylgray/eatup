import 'package:flutter/material.dart';

class AppColors {
  static const gold = Color(0xFFFFC94A);
  static const goldDark = Color(0xFFE09A1B);
  static const ink = Color(0xFF2B2240);
  static const pink = Color(0xFFFF5A8A);
  static const pinkDark = Color(0xFFC8356A);
  static const mint = Color(0xFF5BE07A);
  static const sky = Color(0xFF4FC3F7);
  static const glass = Color(0x33FFFFFF);
  static const glassDark = Color(0xA6201638);
  static const panel = Color(0xEB241A3E);
  static const text = Color(0xFFFFFFFF);
  static const textDim = Color(0xB3FFFFFF);
  static const star = Color(0xFFFFD45C);
  static const good = Color(0xFF7EE08B);
  static const danger = Color(0xFFFF4A5A);
}

/// UI scale: 1.0 on a 390pt-wide phone, smaller on compact phones, larger
/// (capped) on tablets. Every size in the UI goes through this.
extension UiScale on BuildContext {
  double get u => (MediaQuery.sizeOf(this).shortestSide / 390).clamp(0.82, 1.5);
}

/// Fredoka at a real weight (it's a variable font, so weight is an axis).
TextStyle fredoka(
  double size, {
  double weight = 600,
  Color color = AppColors.text,
  double height = 1.1,
  bool shadow = false,
}) => TextStyle(
  fontFamily: 'Fredoka',
  fontSize: size,
  height: height,
  color: color,
  fontVariations: [FontVariation('wght', weight)],
  fontWeight: weight >= 600 ? FontWeight.w600 : FontWeight.w400,
  shadows: shadow ? const [Shadow(color: Color(0x80000000), offset: Offset(0, 2), blurRadius: 8)] : null,
);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Fredoka',
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF7B4FD8),
      brightness: Brightness.dark,
      primary: AppColors.gold,
    ),
  );
  return base.copyWith(
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.panel,
      contentTextStyle: fredoka(15, weight: 500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.ink : Colors.white70,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.gold : Colors.white24,
      ),
    ),
  );
}
