import 'package:flutter/material.dart';

class AppColors {
  // Base colors
  static const black = Color(0xFF000000);
  static const darkGrey = Color(0xFF2A2A2A);
  static const grey = Color(0xFF2A2A2A);
  static const lightGrey = Color(0xFF3A3A3A);
  static const white = Color(0xFFF5F5F5);  // Light grey that appears white
  static const pureWhite = Color(0xFFFFFFFF);  // Pure white for contrast
  static const drawerBackground = Color(0xFF5D1A1A);  // Added this color



  // Theme colors
  static const darkRed = Color(0xFF3D0000);
  static const red = Color(0xFFFF4444);
  static const gameChangerOrange = Color(0xFFFFA726);
  
  // Button states
  static const pressedRed = Color(0xFF2D0000);
  static const splashRed = Color(0xFF550000);

  // Social media colors
  static const instagramPink = Color(0xFFE1306C);
  static const youtubeRed = Color(0xFFFF0000);
}

class AppUiColors extends ThemeExtension<AppUiColors> {
  final Color black;
  final Color darkGrey;
  final Color grey;
  final Color lightGrey;
  final Color white;
  final Color pureWhite;
  final Color drawerBackground;
  final Color darkRed;
  final Color red;
  final Color gameChangerOrange;
  final Color pressedRed;
  final Color splashRed;
  final Color instagramPink;
  final Color youtubeRed;
  final Color purple;
  final Color blue;
  final Color green;
  final Color orange;
  final Color white70;
  final Color white60;
  final Color white54;
  final Color white38;
  final Color white30;
  final Color white24;
  final Color white12;
  final Color white10;
  final Color black12;
  final Color black45;
  final Color black54;
  final Color black87;
  final Color greenAccent;
  final Color orangeAccent;

  final Color manaWhite;
  final Color manaBlue;
  final Color manaBlack;
  final Color manaRed;
  final Color manaGreen;
  final Color manaColorless;

  const AppUiColors({
    required this.black,
    required this.darkGrey,
    required this.grey,
    required this.lightGrey,
    required this.white,
    required this.pureWhite,
    required this.drawerBackground,
    required this.darkRed,
    required this.red,
    required this.gameChangerOrange,
    required this.pressedRed,
    required this.splashRed,
    required this.instagramPink,
    required this.youtubeRed,
    required this.purple,
    required this.blue,
    required this.green,
    required this.orange,
    required this.white70,
    required this.white60,
    required this.white54,
    required this.white38,
    required this.white30,
    required this.white24,
    required this.white12,
    required this.white10,
    required this.black12,
    required this.black45,
    required this.black54,
    required this.black87,
    required this.greenAccent,
    required this.orangeAccent,
    required this.manaWhite,
    required this.manaBlue,
    required this.manaBlack,
    required this.manaRed,
    required this.manaGreen,
    required this.manaColorless,
  });

  @override
  AppUiColors copyWith({
    Color? black,
    Color? darkGrey,
    Color? grey,
    Color? lightGrey,
    Color? white,
    Color? pureWhite,
    Color? drawerBackground,
    Color? darkRed,
    Color? red,
    Color? gameChangerOrange,
    Color? pressedRed,
    Color? splashRed,
    Color? instagramPink,
    Color? youtubeRed,
    Color? purple,
    Color? blue,
    Color? green,
    Color? orange,
    Color? white70,
    Color? white60,
    Color? white54,
    Color? white38,
    Color? white30,
    Color? white24,
    Color? white12,
    Color? white10,
    Color? black12,
    Color? black45,
    Color? black54,
    Color? black87,
    Color? greenAccent,
    Color? orangeAccent,
    Color? manaWhite,
    Color? manaBlue,
    Color? manaBlack,
    Color? manaRed,
    Color? manaGreen,
    Color? manaColorless,
  }) {
    return AppUiColors(
      black: black ?? this.black,
      darkGrey: darkGrey ?? this.darkGrey,
      grey: grey ?? this.grey,
      lightGrey: lightGrey ?? this.lightGrey,
      white: white ?? this.white,
      pureWhite: pureWhite ?? this.pureWhite,
      drawerBackground: drawerBackground ?? this.drawerBackground,
      darkRed: darkRed ?? this.darkRed,
      red: red ?? this.red,
      gameChangerOrange: gameChangerOrange ?? this.gameChangerOrange,
      pressedRed: pressedRed ?? this.pressedRed,
      splashRed: splashRed ?? this.splashRed,
      instagramPink: instagramPink ?? this.instagramPink,
      youtubeRed: youtubeRed ?? this.youtubeRed,
      purple: purple ?? this.purple,
      blue: blue ?? this.blue,
      green: green ?? this.green,
      orange: orange ?? this.orange,
      white70: white70 ?? this.white70,
      white60: white60 ?? this.white60,
      white54: white54 ?? this.white54,
      white38: white38 ?? this.white38,
      white30: white30 ?? this.white30,
      white24: white24 ?? this.white24,
      white12: white12 ?? this.white12,
      white10: white10 ?? this.white10,
      black12: black12 ?? this.black12,
      black45: black45 ?? this.black45,
      black54: black54 ?? this.black54,
      black87: black87 ?? this.black87,
      greenAccent: greenAccent ?? this.greenAccent,
      orangeAccent: orangeAccent ?? this.orangeAccent,
      manaWhite: manaWhite ?? this.manaWhite,
      manaBlue: manaBlue ?? this.manaBlue,
      manaBlack: manaBlack ?? this.manaBlack,
      manaRed: manaRed ?? this.manaRed,
      manaGreen: manaGreen ?? this.manaGreen,
      manaColorless: manaColorless ?? this.manaColorless,
    );
  }

  @override
  AppUiColors lerp(ThemeExtension<AppUiColors>? other, double t) {
    if (other is! AppUiColors) return this;

    return AppUiColors(
      black: Color.lerp(black, other.black, t) ?? black,
      darkGrey: Color.lerp(darkGrey, other.darkGrey, t) ?? darkGrey,
      grey: Color.lerp(grey, other.grey, t) ?? grey,
      lightGrey: Color.lerp(lightGrey, other.lightGrey, t) ?? lightGrey,
      white: Color.lerp(white, other.white, t) ?? white,
      pureWhite: Color.lerp(pureWhite, other.pureWhite, t) ?? pureWhite,
      drawerBackground:
          Color.lerp(drawerBackground, other.drawerBackground, t) ??
              drawerBackground,
      darkRed: Color.lerp(darkRed, other.darkRed, t) ?? darkRed,
      red: Color.lerp(red, other.red, t) ?? red,
      gameChangerOrange:
          Color.lerp(gameChangerOrange, other.gameChangerOrange, t) ??
              gameChangerOrange,
      pressedRed: Color.lerp(pressedRed, other.pressedRed, t) ?? pressedRed,
      splashRed: Color.lerp(splashRed, other.splashRed, t) ?? splashRed,
      instagramPink:
          Color.lerp(instagramPink, other.instagramPink, t) ?? instagramPink,
      youtubeRed: Color.lerp(youtubeRed, other.youtubeRed, t) ?? youtubeRed,
      purple: Color.lerp(purple, other.purple, t) ?? purple,
      blue: Color.lerp(blue, other.blue, t) ?? blue,
      green: Color.lerp(green, other.green, t) ?? green,
      orange: Color.lerp(orange, other.orange, t) ?? orange,
      white70: Color.lerp(white70, other.white70, t) ?? white70,
      white60: Color.lerp(white60, other.white60, t) ?? white60,
      white54: Color.lerp(white54, other.white54, t) ?? white54,
      white38: Color.lerp(white38, other.white38, t) ?? white38,
      white30: Color.lerp(white30, other.white30, t) ?? white30,
      white24: Color.lerp(white24, other.white24, t) ?? white24,
      white12: Color.lerp(white12, other.white12, t) ?? white12,
      white10: Color.lerp(white10, other.white10, t) ?? white10,
      black12: Color.lerp(black12, other.black12, t) ?? black12,
      black45: Color.lerp(black45, other.black45, t) ?? black45,
      black54: Color.lerp(black54, other.black54, t) ?? black54,
      black87: Color.lerp(black87, other.black87, t) ?? black87,
      greenAccent: Color.lerp(greenAccent, other.greenAccent, t) ?? greenAccent,
      orangeAccent:
          Color.lerp(orangeAccent, other.orangeAccent, t) ?? orangeAccent,
      manaWhite: Color.lerp(manaWhite, other.manaWhite, t) ?? manaWhite,
      manaBlue: Color.lerp(manaBlue, other.manaBlue, t) ?? manaBlue,
      manaBlack: Color.lerp(manaBlack, other.manaBlack, t) ?? manaBlack,
      manaRed: Color.lerp(manaRed, other.manaRed, t) ?? manaRed,
      manaGreen: Color.lerp(manaGreen, other.manaGreen, t) ?? manaGreen,
      manaColorless:
          Color.lerp(manaColorless, other.manaColorless, t) ?? manaColorless,
    );
  }
}

class AppTheme {
  static const _primaryPurple = Color(0xFF9C27B0);

  static const AppUiColors ui = AppUiColors(
    black: AppColors.black,
    darkGrey: AppColors.darkGrey,
    grey: AppColors.grey,
    lightGrey: AppColors.lightGrey,
    white: AppColors.white,
    pureWhite: AppColors.pureWhite,
    drawerBackground: AppColors.drawerBackground,
    darkRed: AppColors.darkRed,
    red: AppColors.red,
    gameChangerOrange: AppColors.gameChangerOrange,
    pressedRed: AppColors.pressedRed,
    splashRed: AppColors.splashRed,
    instagramPink: AppColors.instagramPink,
    youtubeRed: AppColors.youtubeRed,
    purple: _primaryPurple,
    blue: Colors.blue,
    green: Colors.green,
    orange: Colors.orange,
    white70: Colors.white70,
    white60: Colors.white60,
    white54: Colors.white54,
    white38: Colors.white38,
    white30: Colors.white30,
    white24: Colors.white24,
    white12: Colors.white12,
    white10: Colors.white10,
    black12: Colors.black12,
    black45: Colors.black45,
    black54: Colors.black54,
    black87: Colors.black87,
    greenAccent: Colors.greenAccent,
    orangeAccent: Colors.orangeAccent,
    manaWhite: Color(0xFFF9FAF4),
    manaBlue: Color(0xFF0E68AB),
    manaBlack: Color(0xFF21130D),
    manaRed: Color(0xFFD3202A),
    manaGreen: Color(0xFF00733E),
    manaColorless: Color(0xFF9FA4A9),
  );

  static ThemeData theme() {
    final colorScheme = const ColorScheme(
      brightness: Brightness.dark,
      primary: _primaryPurple,
      onPrimary: Colors.white,
      secondary: AppColors.gameChangerOrange,
      onSecondary: Colors.black,
      error: AppColors.red,
      onError: Colors.white,
      surface: AppColors.darkGrey,
      onSurface: AppColors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.black,
      canvasColor: AppColors.darkGrey,
      cardColor: AppColors.darkGrey,
      dividerColor: AppColors.lightGrey,
      extensions: const <ThemeExtension<dynamic>>[ui],
      chipTheme: const ChipThemeData(showCheckmark: false),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return AppColors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withAlpha((0.45 * 255).round());
          }
          return AppColors.lightGrey;
        }),
      ),
    );
  }
}

extension AppThemeContextExtension on BuildContext {
  AppUiColors get uiColors =>
      Theme.of(this).extension<AppUiColors>() ?? AppTheme.ui;
}