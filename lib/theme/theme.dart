import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _lightAppBarOverlayStyle = SystemUiOverlayStyle(
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
  systemStatusBarContrastEnforced: false,
);

const _darkAppBarOverlayStyle = SystemUiOverlayStyle(
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarContrastEnforced: false,
  systemStatusBarContrastEnforced: false,
);

const _lightMain = Color(0xFFFFFFFF);
const _lightSecond = Color(0xFFEDEDED);
const _lightAccent = Color(0xFF2F2F2F);
const _darkMain = Color(0xFF000000);
const _darkSecond = Color(0xFF2F2F2F);
const _darkAccent = Color(0xFFF0F0F0);
const _defaultPink = Color(0xFFE57697);

ThemeData _lightTheme({
  required Color primary,
  required Color hint,
  required Color accent,
  Color secondary = _lightAccent,
}) {
  return ThemeData(
    canvasColor: Colors.transparent,
    primaryColor: primary,
    brightness: Brightness.light,
    appBarTheme: const AppBarTheme(systemOverlayStyle: _lightAppBarOverlayStyle),
    focusColor: _lightMain,
    hintColor: hint,
    textTheme: TextTheme(
      labelLarge: const TextStyle(
        fontFamily: PrismFonts.proximaNova,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: _lightMain,
      ),
      headlineSmall: const TextStyle(fontSize: 16.0, color: _lightMain, fontFamily: PrismFonts.proximaNova),
      headlineMedium: const TextStyle(
        fontSize: 16,
        fontFamily: PrismFonts.proximaNova,
        fontWeight: FontWeight.w500,
        color: _lightAccent,
      ),
      displaySmall: const TextStyle(
        fontSize: 20,
        fontFamily: PrismFonts.proximaNova,
        fontWeight: FontWeight.w500,
        color: Colors.black,
      ),
      displayMedium: const TextStyle(
        fontSize: 24,
        fontFamily: PrismFonts.proximaNova,
        fontWeight: FontWeight.w500,
        color: Colors.black,
      ),
      displayLarge: const TextStyle(
        fontFamily: PrismFonts.proximaNova,
        color: _lightAccent,
        fontSize: 50,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: _lightSecond,
        fontFamily: PrismFonts.roboto,
      ),
      titleLarge: TextStyle(
        fontSize: 13.0,
        color: _lightMain.withValues(alpha: .85),
        fontFamily: PrismFonts.proximaNova,
      ),
      bodyMedium: TextStyle(
        fontFamily: PrismFonts.proximaNova,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _lightMain.withValues(alpha: .75),
      ),
      bodyLarge: const TextStyle(
        fontFamily: PrismFonts.proximaNova,
        fontSize: 24,
        fontWeight: FontWeight.w500,
        color: _lightMain,
      ),
      bodySmall: const TextStyle(
        fontFamily: PrismFonts.roboto,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: _lightAccent,
      ),
    ),
    colorScheme: ColorScheme.light(primary: accent).copyWith(secondary: secondary, error: accent),
  );
}

ThemeData _darkTheme({
  required Color primary,
  required Color hint,
  required Color accent,
  required Color secondary,
  Color text = _darkAccent,
  Color titleMedium = _darkSecond,
  Color? error,
}) {
  return ThemeData(
    canvasColor: Colors.transparent,
    primaryColor: primary,
    brightness: Brightness.dark,
    appBarTheme: const AppBarTheme(systemOverlayStyle: _darkAppBarOverlayStyle),
    focusColor: _darkMain,
    hintColor: hint,
    textTheme: TextTheme(
      labelLarge: const TextStyle(
        fontFamily: PrismFonts.proximaNova,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: _darkMain,
      ),
      headlineSmall: TextStyle(fontSize: 16.0, color: text, fontFamily: PrismFonts.proximaNova),
      headlineMedium: TextStyle(
        fontSize: 16,
        fontFamily: PrismFonts.proximaNova,
        fontWeight: FontWeight.w500,
        color: text,
      ),
      displaySmall: const TextStyle(
        fontSize: 20,
        fontFamily: PrismFonts.proximaNova,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      displayMedium: const TextStyle(
        fontSize: 24,
        fontFamily: PrismFonts.proximaNova,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      displayLarge: TextStyle(
        fontFamily: PrismFonts.proximaNova,
        color: text,
        fontSize: 50,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: titleMedium,
        fontFamily: PrismFonts.roboto,
      ),
      titleLarge: TextStyle(fontSize: 14.0, color: text.withValues(alpha: .85), fontFamily: PrismFonts.proximaNova),
      bodyMedium: TextStyle(
        fontFamily: PrismFonts.proximaNova,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: text.withValues(alpha: .85),
      ),
      bodyLarge: TextStyle(fontFamily: PrismFonts.proximaNova, fontSize: 22, fontWeight: FontWeight.w500, color: text),
      bodySmall: TextStyle(fontFamily: PrismFonts.roboto, fontSize: 16, fontWeight: FontWeight.w400, color: text),
    ),
    colorScheme: ColorScheme.dark(primary: accent).copyWith(secondary: secondary, error: error ?? accent),
  );
}

ThemeData kLightTheme = _lightTheme(primary: _lightMain, hint: _lightSecond, accent: _defaultPink);

ThemeData kLightTheme2 = _lightTheme(
  primary: const Color(0xFFF7F1E3),
  hint: const Color(0xFFF1E6D0),
  accent: const Color(0xFFC19439),
  secondary: const Color(0xFF96732C),
);

ThemeData kLightTheme3 = _lightTheme(
  primary: const Color(0xFFC5A79F),
  hint: const Color(0xFFBE9C93),
  accent: const Color(0xFFA7796D),
  secondary: const Color(0xFF7D564B),
);

ThemeData kLightTheme4 = _lightTheme(
  primary: const Color(0xFF8399BE),
  hint: const Color(0xFF788CAF),
  accent: const Color(0xFF596F95),
  secondary: const Color(0xFF36435A),
);

ThemeData kDarkTheme = _darkTheme(primary: _darkMain, hint: _darkSecond, accent: _defaultPink, secondary: _darkAccent);

ThemeData kDarkTheme2 = _darkTheme(
  primary: Colors.black,
  hint: Colors.black,
  accent: Colors.white,
  secondary: Colors.white,
  text: Colors.white,
  titleMedium: Colors.black,
  error: Colors.black,
);

ThemeData kDarkTheme3 = _darkTheme(
  primary: const Color(0xFF202113),
  hint: const Color(0xFF35371F),
  accent: const Color(0xFF767B45),
  secondary: const Color(0xFFE3E4D0),
);

ThemeData kDarkTheme4 = _darkTheme(
  primary: const Color(0xFF041B29),
  hint: const Color(0xFF152836),
  accent: const Color(0xFF427DA8),
  secondary: const Color(0xFFB0CCE0),
);

ThemeData kDarkTheme5 = _darkTheme(
  primary: const Color(0xFF12210E),
  hint: const Color(0xFF1D2B1A),
  accent: const Color(0xFF4C7044),
  secondary: const Color(0xFFD9E6D6),
);

ThemeData kDarkTheme6 = _darkTheme(
  primary: const Color(0xFF290D02),
  hint: const Color(0xFF361B12),
  accent: const Color(0xFF703826),
  secondary: const Color(0xFFDFB0A0),
);

ThemeData kDarkTheme7 = _darkTheme(
  primary: const Color(0xFF142431),
  hint: const Color(0xFF193543),
  accent: const Color(0xFF2D6079),
  secondary: const Color(0xFFA9CDDF),
);

ThemeData kDarkTheme8 = _darkTheme(
  primary: const Color(0xFF393D46),
  hint: const Color(0xFF33363F),
  accent: const Color(0xFF686E80),
  secondary: const Color(0xFFEEEFF2),
);
