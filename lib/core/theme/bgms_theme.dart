import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 색 토큰. 올리브 기운 숯색 바탕 위에 배그 골드 하나를 신호색으로 쓴다.
/// 데이터 색(치킨·탑10·킬·기절)은 의미가 있을 때만 쓴다.
class BgmsColors {
  const BgmsColors._();

  static const accent = Color(0xFFF2A900);
  static const onAccent = Color(0xFF14110A);
  static const bgBase = Color(0xFF0E100F);
  static const surface = Color(0xFF161917);
  static const elevated = Color(0xFF20241F);
  static const border = Color(0x1FFFFFFF);
  static const success = Color(0xFF57C785);
  static const danger = Color(0xFFE5484D);
  static const knock = Color(0xFFF08A24);
  static const top10 = Color(0xFF57C785);
  static const defeat = Color(0xFF8B958C);
  static const glassBg = Color(0xF2121513);
  static const glassBorder = border;
  static const textPrimary = Color(0xFFF4F3EE);
  static const textSecondary = Color(0xB3F4F3EE);
  static const textMuted = Color(0x80F4F3EE);

  /// PUBG 랭크 티어별 강조 색상. 웹 TIER_STYLE과 대응한다.
  static const tierColors = <String, Color>{
    'Master': Color(0xFFD8B4FE),
    'Survivor': Color(0xFFFDE68A),
    'Diamond': Color(0xFF67E8F9),
    'Crystal': Color(0xFF7DD3FC),
    'Platinum': Color(0xFF5EEAD4),
    'Gold': Color(0xFFFCD34D),
    'Silver': Color(0xFFCBD5E1),
    'Bronze': Color(0xFFFB923C),
  };

  static Color tierColor(String? tier) {
    if (tier == null || tier.isEmpty) return textMuted;
    for (final entry in tierColors.entries) {
      if (tier.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return textMuted;
  }
}

/// 화면 간 여백을 통일하기 위한 스페이싱 토큰.
class BgmsSpacing {
  const BgmsSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;

  static const EdgeInsets screen = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );
  static const EdgeInsets card = EdgeInsets.all(lg);
}

/// 모서리 반경 토큰. 둥근 모서리는 작은 요소(칩·스켈레톤)에만 남긴다.
class BgmsRadius {
  const BgmsRadius._();

  static const BorderRadius sm = BorderRadius.all(Radius.circular(3));
  static const BorderRadius md = BorderRadius.all(Radius.circular(4));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(6));
  static const BorderRadius xl = BorderRadius.all(Radius.circular(8));
}

/// 앱의 모양 언어: 둥글림 대신 사선으로 잘린 모서리.
class BgmsShape {
  const BgmsShape._();

  static const double cut = 6;
  static const double cutSmall = 4;

  static BeveledRectangleBorder panel({
    BorderSide side = const BorderSide(color: BgmsColors.border),
    double size = cut,
  }) => BeveledRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(size)),
    side: side,
  );
}

/// 큰 숫자·지표 전용 서체. 탭룰러 숫자로 자릿수를 정렬한다.
class BgmsText {
  const BgmsText._();

  static const numberFamily = 'BarlowCondensed';

  static TextStyle number(
    double size, {
    Color color = BgmsColors.textPrimary,
    FontWeight weight = FontWeight.w700,
  }) => TextStyle(
    fontFamily: numberFamily,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.0,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

class BgmsTheme {
  const BgmsTheme._();

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: BgmsColors.accent,
      brightness: Brightness.dark,
      primary: BgmsColors.accent,
      onPrimary: BgmsColors.onAccent,
      surface: BgmsColors.surface,
      onSurface: BgmsColors.textPrimary,
      surfaceContainerHighest: BgmsColors.elevated,
      outline: BgmsColors.border,
      error: BgmsColors.danger,
    );

    final buttonShape = BgmsShape.panel(side: BorderSide.none);
    const inputBorder = OutlineInputBorder(
      borderRadius: BgmsRadius.md,
      borderSide: BorderSide(color: BgmsColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: BgmsColors.bgBase,
      colorScheme: colorScheme,
      textTheme: Typography.material2021(platform: defaultTargetPlatform).white
          .apply(
            bodyColor: BgmsColors.textPrimary,
            displayColor: BgmsColors.textPrimary,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: BgmsColors.bgBase,
        surfaceTintColor: Colors.transparent,
        foregroundColor: BgmsColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: BgmsColors.border,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: BgmsColors.surface,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: BgmsShape.panel(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: BgmsColors.surface,
        selectedColor: BgmsColors.accent,
        disabledColor: BgmsColors.surface,
        checkmarkColor: BgmsColors.onAccent,
        labelStyle: const TextStyle(color: BgmsColors.textPrimary),
        secondaryLabelStyle: const TextStyle(color: BgmsColors.onAccent),
        side: const BorderSide(color: BgmsColors.border),
        shape: BgmsShape.panel(size: BgmsShape.cutSmall),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: BgmsColors.surface,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BgmsRadius.md,
          borderSide: BorderSide(color: BgmsColors.accent),
        ),
        labelStyle: TextStyle(color: BgmsColors.textSecondary),
        hintStyle: TextStyle(color: BgmsColors.textMuted),
        prefixIconColor: BgmsColors.textSecondary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BgmsColors.accent,
          foregroundColor: BgmsColors.onAccent,
          minimumSize: const Size(48, 48),
          shape: buttonShape,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BgmsColors.textPrimary,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: BgmsColors.border),
          shape: BgmsShape.panel(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BgmsColors.accent,
          minimumSize: const Size(44, 44),
        ),
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
              return BgmsColors.onAccent;
            }
            return BgmsColors.textPrimary;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: BgmsColors.border),
          ),
          shape: WidgetStateProperty.all(
            BgmsShape.panel(size: BgmsShape.cutSmall, side: BorderSide.none),
          ),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: BgmsColors.accent,
        unselectedLabelColor: BgmsColors.textSecondary,
        indicatorColor: BgmsColors.accent,
        dividerColor: BgmsColors.border,
        labelStyle: TextStyle(fontWeight: FontWeight.w800),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: BgmsColors.glassBg,
        indicatorColor: Colors.transparent,
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BgmsColors.elevated,
        contentTextStyle: const TextStyle(color: BgmsColors.textPrimary),
        actionTextColor: BgmsColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: BgmsShape.panel(),
      ),
    );
  }
}
