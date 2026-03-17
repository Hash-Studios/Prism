import 'package:Prism/theme/config.dart' as config;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _lightAppBarOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Color(0x00000000),
  systemNavigationBarDividerColor: Color(0x00000000),
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
  systemStatusBarContrastEnforced: false,
);

const _darkAppBarOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Color(0x00000000),
  systemNavigationBarDividerColor: Color(0x00000000),
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarContrastEnforced: false,
  systemStatusBarContrastEnforced: false,
);

ThemeData kLightTheme = ThemeData(
  canvasColor: Colors.transparent,
  primaryColor: Colors.white,
  brightness: Brightness.light,
  appBarTheme: const AppBarTheme(systemOverlayStyle: _lightAppBarOverlayStyle),
  focusColor: config.Colors().mainColor(1),
  hintColor: config.Colors().secondColor(1),
  textTheme: TextTheme(
    labelLarge: const TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: Color(0xFFFFFFFF),
    ),
    headlineSmall: TextStyle(fontSize: 16.0, color: Colors.white.withValues(alpha: 1), fontFamily: "Proxima Nova"),
    headlineMedium: TextStyle(
      fontSize: 16,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: config.Colors().accentColor(1),
    ),
    displaySmall: const TextStyle(
      fontSize: 20,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.black,
    ),
    displayMedium: const TextStyle(
      fontSize: 24,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.black,
    ),
    displayLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      color: config.Colors().accentColor(1),
      fontSize: 50,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w900,
      color: config.Colors().secondColor(1),
      fontFamily: "Roboto",
    ),
    titleLarge: TextStyle(fontSize: 13.0, color: Colors.white.withValues(alpha: .85), fontFamily: "Proxima Nova"),
    bodyMedium: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Colors.white.withValues(alpha: .75),
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 24,
      fontWeight: FontWeight.w500,
      color: Colors.white.withValues(alpha: 1),
    ),
    bodySmall: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: config.Colors().accentColor(1),
    ),
  ),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFFE57697),
  ).copyWith(secondary: config.Colors().accentColor(1)).copyWith(error: const Color(0xFFE57697)),
);

ThemeData kDarkTheme = ThemeData(
  canvasColor: Colors.transparent,
  primaryColor: config.Colors().mainDarkColor(1),
  brightness: Brightness.dark,
  appBarTheme: const AppBarTheme(systemOverlayStyle: _darkAppBarOverlayStyle),
  focusColor: config.Colors().mainDarkColor(1),
  hintColor: config.Colors().secondDarkColor(1),
  textTheme: TextTheme(
    labelLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: config.Colors().mainDarkColor(1),
    ),
    headlineSmall: TextStyle(fontSize: 16.0, color: config.Colors().accentDarkColor(1), fontFamily: "Proxima Nova"),
    headlineMedium: TextStyle(
      fontSize: 16,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(1),
    ),
    displaySmall: const TextStyle(
      fontSize: 20,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    displayMedium: const TextStyle(
      fontSize: 24,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    displayLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      color: config.Colors().accentDarkColor(1),
      fontSize: 50,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w900,
      color: config.Colors().secondDarkColor(1),
      fontFamily: "Roboto",
    ),
    titleLarge: TextStyle(fontSize: 14.0, color: config.Colors().accentDarkColor(.85), fontFamily: "Proxima Nova"),
    bodyMedium: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(.85),
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(1),
    ),
    bodySmall: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: config.Colors().accentDarkColor(1),
    ),
  ),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFFE57697),
  ).copyWith(secondary: config.Colors().accentDarkColor(1)).copyWith(error: const Color(0xFFE57697)),
);

ThemeData kLightTheme2 = ThemeData(
  canvasColor: Colors.transparent,
  primaryColor: const Color(0xFFF7F1E3),
  brightness: Brightness.light,
  appBarTheme: const AppBarTheme(systemOverlayStyle: _lightAppBarOverlayStyle),
  focusColor: config.Colors().mainColor(1),
  hintColor: const Color(0xFFF1E6D0),
  textTheme: TextTheme(
    labelLarge: const TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: Color(0xFFFFFFFF),
    ),
    headlineSmall: TextStyle(fontSize: 16.0, color: Colors.white.withValues(alpha: 1), fontFamily: "Proxima Nova"),
    headlineMedium: TextStyle(
      fontSize: 16,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: config.Colors().accentColor(1),
    ),
    displaySmall: const TextStyle(
      fontSize: 20,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.black,
    ),
    displayMedium: const TextStyle(
      fontSize: 24,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.black,
    ),
    displayLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      color: config.Colors().accentColor(1),
      fontSize: 50,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w900,
      color: config.Colors().secondColor(1),
      fontFamily: "Roboto",
    ),
    titleLarge: TextStyle(fontSize: 13.0, color: Colors.white.withValues(alpha: .85), fontFamily: "Proxima Nova"),
    bodyMedium: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Colors.white.withValues(alpha: .75),
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 24,
      fontWeight: FontWeight.w500,
      color: Colors.white.withValues(alpha: 1),
    ),
    bodySmall: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: config.Colors().accentColor(1),
    ),
  ),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFFC19439),
  ).copyWith(secondary: const Color(0xFF96732C)).copyWith(error: const Color(0xFFC19439)),
);

ThemeData kDarkTheme2 = ThemeData(
  canvasColor: Colors.transparent,
  primaryColor: Colors.black,
  brightness: Brightness.dark,
  appBarTheme: const AppBarTheme(systemOverlayStyle: _darkAppBarOverlayStyle),
  focusColor: Colors.black,
  hintColor: Colors.black,
  textTheme: TextTheme(
    labelLarge: const TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: Colors.black,
    ),
    headlineSmall: const TextStyle(fontSize: 16.0, color: Colors.white, fontFamily: "Proxima Nova"),
    headlineMedium: const TextStyle(
      fontSize: 16,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    displaySmall: const TextStyle(
      fontSize: 20,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    displayMedium: const TextStyle(
      fontSize: 24,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    displayLarge: const TextStyle(
      fontFamily: 'Proxima Nova',
      color: Colors.white,
      fontSize: 50,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black, fontFamily: "Roboto"),
    titleLarge: TextStyle(fontSize: 14.0, color: Colors.white.withValues(alpha: 0.85), fontFamily: "Proxima Nova"),
    bodyMedium: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Colors.white.withValues(alpha: .85),
    ),
    bodyLarge: const TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    bodySmall: const TextStyle(fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w400, color: Colors.white),
  ),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFFFFFFFF),
  ).copyWith(secondary: Colors.white).copyWith(error: Colors.black),
);

ThemeData kLightTheme3 = ThemeData(
  canvasColor: Colors.transparent,
  primaryColor: const Color(0xFFC5A79F),
  brightness: Brightness.light,
  appBarTheme: const AppBarTheme(systemOverlayStyle: _lightAppBarOverlayStyle),
  focusColor: config.Colors().mainColor(1),
  hintColor: const Color(0xFFBE9C93),
  textTheme: TextTheme(
    labelLarge: const TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: Color(0xFFFFFFFF),
    ),
    headlineSmall: TextStyle(fontSize: 16.0, color: Colors.white.withValues(alpha: 1), fontFamily: "Proxima Nova"),
    headlineMedium: TextStyle(
      fontSize: 16,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: config.Colors().accentColor(1),
    ),
    displaySmall: const TextStyle(
      fontSize: 20,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.black,
    ),
    displayMedium: const TextStyle(
      fontSize: 24,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.black,
    ),
    displayLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      color: config.Colors().accentColor(1),
      fontSize: 50,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w900,
      color: config.Colors().secondColor(1),
      fontFamily: "Roboto",
    ),
    titleLarge: TextStyle(fontSize: 13.0, color: Colors.white.withValues(alpha: .85), fontFamily: "Proxima Nova"),
    bodyMedium: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Colors.white.withValues(alpha: .75),
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 24,
      fontWeight: FontWeight.w500,
      color: Colors.white.withValues(alpha: 1),
    ),
    bodySmall: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: config.Colors().accentColor(1),
    ),
  ),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFFA7796D),
  ).copyWith(secondary: const Color(0xFF7D564B)).copyWith(error: const Color(0xFFA7796D)),
);

ThemeData kLightTheme4 = ThemeData(
  canvasColor: Colors.transparent,
  primaryColor: const Color(0xFF8399BE),
  brightness: Brightness.light,
  appBarTheme: const AppBarTheme(systemOverlayStyle: _lightAppBarOverlayStyle),
  focusColor: config.Colors().mainColor(1),
  hintColor: const Color(0xFF788CAF),
  textTheme: TextTheme(
    labelLarge: const TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: Color(0xFFFFFFFF),
    ),
    headlineSmall: TextStyle(fontSize: 16.0, color: Colors.white.withValues(alpha: 1), fontFamily: "Proxima Nova"),
    headlineMedium: TextStyle(
      fontSize: 16,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: config.Colors().accentColor(1),
    ),
    displaySmall: const TextStyle(
      fontSize: 20,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.black,
    ),
    displayMedium: const TextStyle(
      fontSize: 24,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.black,
    ),
    displayLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      color: config.Colors().accentColor(1),
      fontSize: 50,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w900,
      color: config.Colors().secondColor(1),
      fontFamily: "Roboto",
    ),
    titleLarge: TextStyle(fontSize: 13.0, color: Colors.white.withValues(alpha: .85), fontFamily: "Proxima Nova"),
    bodyMedium: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Colors.white.withValues(alpha: .75),
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 24,
      fontWeight: FontWeight.w500,
      color: Colors.white.withValues(alpha: 1),
    ),
    bodySmall: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: config.Colors().accentColor(1),
    ),
  ),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF596F95),
  ).copyWith(secondary: const Color(0xFF36435A)).copyWith(error: const Color(0xFF596F95)),
);

ThemeData kDarkTheme3 = ThemeData(
  canvasColor: Colors.transparent,
  primaryColor: const Color(0xFF202113),
  brightness: Brightness.dark,
  appBarTheme: const AppBarTheme(systemOverlayStyle: _darkAppBarOverlayStyle),
  focusColor: config.Colors().mainDarkColor(1),
  hintColor: const Color(0xFF35371F),
  textTheme: TextTheme(
    labelLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: config.Colors().mainDarkColor(1),
    ),
    headlineSmall: TextStyle(fontSize: 16.0, color: config.Colors().accentDarkColor(1), fontFamily: "Proxima Nova"),
    headlineMedium: TextStyle(
      fontSize: 16,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(1),
    ),
    displaySmall: const TextStyle(
      fontSize: 20,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    displayMedium: const TextStyle(
      fontSize: 24,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    displayLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      color: config.Colors().accentDarkColor(1),
      fontSize: 50,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w900,
      color: config.Colors().secondDarkColor(1),
      fontFamily: "Roboto",
    ),
    titleLarge: TextStyle(fontSize: 14.0, color: config.Colors().accentDarkColor(.85), fontFamily: "Proxima Nova"),
    bodyMedium: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(.85),
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(1),
    ),
    bodySmall: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: config.Colors().accentDarkColor(1),
    ),
  ),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF767B45),
  ).copyWith(secondary: const Color(0xFFE3E4D0)).copyWith(error: const Color(0xFF767B45)),
);

ThemeData kDarkTheme4 = ThemeData(
  canvasColor: Colors.transparent,
  primaryColor: const Color(0xFF041B29),
  brightness: Brightness.dark,
  appBarTheme: const AppBarTheme(systemOverlayStyle: _darkAppBarOverlayStyle),
  focusColor: config.Colors().mainDarkColor(1),
  hintColor: const Color(0xFF152836),
  textTheme: TextTheme(
    labelLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: config.Colors().mainDarkColor(1),
    ),
    headlineSmall: TextStyle(fontSize: 16.0, color: config.Colors().accentDarkColor(1), fontFamily: "Proxima Nova"),
    headlineMedium: TextStyle(
      fontSize: 16,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(1),
    ),
    displaySmall: const TextStyle(
      fontSize: 20,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    displayMedium: const TextStyle(
      fontSize: 24,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    displayLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      color: config.Colors().accentDarkColor(1),
      fontSize: 50,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w900,
      color: config.Colors().secondDarkColor(1),
      fontFamily: "Roboto",
    ),
    titleLarge: TextStyle(fontSize: 14.0, color: config.Colors().accentDarkColor(.85), fontFamily: "Proxima Nova"),
    bodyMedium: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(.85),
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(1),
    ),
    bodySmall: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: config.Colors().accentDarkColor(1),
    ),
  ),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF427DA8),
  ).copyWith(secondary: const Color(0xFFB0CCE0)).copyWith(error: const Color(0xFF427DA8)),
);

ThemeData kDarkTheme5 = ThemeData(
  canvasColor: Colors.transparent,
  primaryColor: const Color(0xFF12210E),
  brightness: Brightness.dark,
  appBarTheme: const AppBarTheme(systemOverlayStyle: _darkAppBarOverlayStyle),
  focusColor: config.Colors().mainDarkColor(1),
  hintColor: const Color(0xFF1D2B1A),
  textTheme: TextTheme(
    labelLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: config.Colors().mainDarkColor(1),
    ),
    headlineSmall: TextStyle(fontSize: 16.0, color: config.Colors().accentDarkColor(1), fontFamily: "Proxima Nova"),
    headlineMedium: TextStyle(
      fontSize: 16,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(1),
    ),
    displaySmall: const TextStyle(
      fontSize: 20,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    displayMedium: const TextStyle(
      fontSize: 24,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    displayLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      color: config.Colors().accentDarkColor(1),
      fontSize: 50,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w900,
      color: config.Colors().secondDarkColor(1),
      fontFamily: "Roboto",
    ),
    titleLarge: TextStyle(fontSize: 14.0, color: config.Colors().accentDarkColor(.85), fontFamily: "Proxima Nova"),
    bodyMedium: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(.85),
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(1),
    ),
    bodySmall: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: config.Colors().accentDarkColor(1),
    ),
  ),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF4C7044),
  ).copyWith(secondary: const Color(0xFFD9E6D6)).copyWith(error: const Color(0xFF4C7044)),
);

ThemeData kDarkTheme6 = ThemeData(
  canvasColor: Colors.transparent,
  primaryColor: const Color(0xFF290D02),
  brightness: Brightness.dark,
  appBarTheme: const AppBarTheme(systemOverlayStyle: _darkAppBarOverlayStyle),
  focusColor: config.Colors().mainDarkColor(1),
  hintColor: const Color(0xFF361B12),
  textTheme: TextTheme(
    labelLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: config.Colors().mainDarkColor(1),
    ),
    headlineSmall: TextStyle(fontSize: 16.0, color: config.Colors().accentDarkColor(1), fontFamily: "Proxima Nova"),
    headlineMedium: TextStyle(
      fontSize: 16,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(1),
    ),
    displaySmall: const TextStyle(
      fontSize: 20,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    displayMedium: const TextStyle(
      fontSize: 24,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    displayLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      color: config.Colors().accentDarkColor(1),
      fontSize: 50,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w900,
      color: config.Colors().secondDarkColor(1),
      fontFamily: "Roboto",
    ),
    titleLarge: TextStyle(fontSize: 14.0, color: config.Colors().accentDarkColor(.85), fontFamily: "Proxima Nova"),
    bodyMedium: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(.85),
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(1),
    ),
    bodySmall: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: config.Colors().accentDarkColor(1),
    ),
  ),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF703826),
  ).copyWith(secondary: const Color(0xFFDFB0A0)).copyWith(error: const Color(0xFF703826)),
);

ThemeData kDarkTheme7 = ThemeData(
  canvasColor: Colors.transparent,
  primaryColor: const Color(0xFF142431),
  brightness: Brightness.dark,
  appBarTheme: const AppBarTheme(systemOverlayStyle: _darkAppBarOverlayStyle),
  focusColor: config.Colors().mainDarkColor(1),
  hintColor: const Color(0xFF193543),
  textTheme: TextTheme(
    labelLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: config.Colors().mainDarkColor(1),
    ),
    headlineSmall: TextStyle(fontSize: 16.0, color: config.Colors().accentDarkColor(1), fontFamily: "Proxima Nova"),
    headlineMedium: TextStyle(
      fontSize: 16,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(1),
    ),
    displaySmall: const TextStyle(
      fontSize: 20,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    displayMedium: const TextStyle(
      fontSize: 24,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    displayLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      color: config.Colors().accentDarkColor(1),
      fontSize: 50,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w900,
      color: config.Colors().secondDarkColor(1),
      fontFamily: "Roboto",
    ),
    titleLarge: TextStyle(fontSize: 14.0, color: config.Colors().accentDarkColor(.85), fontFamily: "Proxima Nova"),
    bodyMedium: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(.85),
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(1),
    ),
    bodySmall: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: config.Colors().accentDarkColor(1),
    ),
  ),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF2D6079),
  ).copyWith(secondary: const Color(0xFFA9CDDF)).copyWith(error: const Color(0xFF2D6079)),
);

ThemeData kDarkTheme8 = ThemeData(
  canvasColor: Colors.transparent,
  primaryColor: const Color(0xFF393D46),
  brightness: Brightness.dark,
  appBarTheme: const AppBarTheme(systemOverlayStyle: _darkAppBarOverlayStyle),
  focusColor: config.Colors().mainDarkColor(1),
  hintColor: const Color(0xFF33363F),
  textTheme: TextTheme(
    labelLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: config.Colors().mainDarkColor(1),
    ),
    headlineSmall: TextStyle(fontSize: 16.0, color: config.Colors().accentDarkColor(1), fontFamily: "Proxima Nova"),
    headlineMedium: TextStyle(
      fontSize: 16,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(1),
    ),
    displaySmall: const TextStyle(
      fontSize: 20,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    displayMedium: const TextStyle(
      fontSize: 24,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    displayLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      color: config.Colors().accentDarkColor(1),
      fontSize: 50,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w900,
      color: config.Colors().secondDarkColor(1),
      fontFamily: "Roboto",
    ),
    titleLarge: TextStyle(fontSize: 14.0, color: config.Colors().accentDarkColor(.85), fontFamily: "Proxima Nova"),
    bodyMedium: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(.85),
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(1),
    ),
    bodySmall: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: config.Colors().accentDarkColor(1),
    ),
  ),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF686E80),
  ).copyWith(secondary: const Color(0xFFEEEFF2)).copyWith(error: const Color(0xFF686E80)),
);
