import 'package:flutter/material.dart';

class BgmsColors {
  const BgmsColors._();

  static const accent = Color(0xFFF2A900);
  static const bgBase = Color(0xFF0D0D0D);
  static const surface = Color(0xFF161616);
  static const elevated = Color(0xFF1F1F1F);
  static const border = Color(0x14FFFFFF);
  static const success = Color(0xFF34A853);
  static const danger = Color(0xFFEF4444);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x4DFFFFFF);
}

class BgmsTheme {
  const BgmsTheme._();

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: BgmsColors.accent,
      brightness: Brightness.dark,
      primary: BgmsColors.accent,
      onPrimary: Colors.black,
      surface: BgmsColors.surface,
      onSurface: BgmsColors.textPrimary,
      error: BgmsColors.danger,
    );

    const outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: BgmsColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: BgmsColors.bgBase,
      colorScheme: colorScheme,
      textTheme: Typography.whiteMountainView.apply(
        bodyColor: BgmsColors.textPrimary,
        displayColor: BgmsColors.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: BgmsColors.surface,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BgmsColors.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: BgmsColors.elevated,
        selectedColor: BgmsColors.accent,
        disabledColor: BgmsColors.surface,
        labelStyle: const TextStyle(color: BgmsColors.textPrimary),
        secondaryLabelStyle: const TextStyle(color: Colors.black),
        side: const BorderSide(color: BgmsColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: BgmsColors.surface,
        border: outlineBorder,
        enabledBorder: outlineBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: BgmsColors.accent),
        ),
        labelStyle: TextStyle(color: BgmsColors.textSecondary),
        hintStyle: TextStyle(color: BgmsColors.textMuted),
        prefixIconColor: BgmsColors.textSecondary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BgmsColors.accent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BgmsColors.textPrimary,
          side: const BorderSide(color: BgmsColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: BgmsColors.accent),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return BgmsColors.accent;
            }
            return BgmsColors.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.black;
            }
            return BgmsColors.textPrimary;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: BgmsColors.border),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: BgmsColors.surface,
        indicatorColor: BgmsColors.accent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: BgmsColors.textPrimary, fontSize: 12),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: BgmsColors.textPrimary),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: BgmsColors.textSecondary,
        textColor: BgmsColors.textPrimary,
        subtitleTextStyle: TextStyle(color: BgmsColors.textSecondary),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BgmsColors.accent,
        linearTrackColor: BgmsColors.elevated,
      ),
    );
  }
}
