import 'package:Prism/theme/config.dart' as config;
import 'package:flutter/material.dart';

ThemeData kLightTheme = ThemeData.from(
  textTheme: TextTheme(
    button: const TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: Color(0xFFFFFFFF),
    ),
    headline5: TextStyle(
      fontSize: 16.0,
      color: Colors.white.withOpacity(1),
      fontFamily: "Proxima Nova",
    ),
    headline4: TextStyle(
        fontSize: 16,
        fontFamily: "Proxima Nova",
        fontWeight: FontWeight.w500,
        color: config.Colors().accentColor(1)),
    headline3: const TextStyle(
        fontSize: 20,
        fontFamily: "Proxima Nova",
        fontWeight: FontWeight.w500,
        color: Colors.black),
    headline2: const TextStyle(
        fontSize: 24,
        fontFamily: "Proxima Nova",
        fontWeight: FontWeight.w500,
        color: Colors.black),
    headline1: TextStyle(
      fontFamily: 'Proxima Nova',
      color: config.Colors().accentColor(1),
      fontSize: 50,
      fontWeight: FontWeight.w600,
    ),
    subtitle1: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w900,
      color: config.Colors().secondColor(1),
      fontFamily: "Roboto",
    ),
    headline6: TextStyle(
      fontSize: 13.0,
      color: Colors.white.withOpacity(.85),
      fontFamily: "Proxima Nova",
    ),
    bodyText2: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Colors.white.withOpacity(.75),
    ),
    bodyText1: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 24,
      fontWeight: FontWeight.w500,
      color: Colors.white.withOpacity(1),
    ),
    caption: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: config.Colors().accentColor(1),
    ),
  ),
  colorScheme: ColorScheme(
    brightness: Brightness.light,
    primary: config.Colors().mainColor(1),
    primaryVariant: config.Colors().mainColor(1),
    secondary: config.Colors().accentColor(1),
    secondaryVariant: config.Colors().accentColor(1),
    background: config.Colors().mainColor(1),
    surface: config.Colors().mainColor(1),
    onBackground: Colors.black,
    onSurface: Colors.black,
    onError: Colors.white,
    onPrimary: const Color(0xFFE57697).computeLuminance() > 0.5
        ? Colors.black
        : Colors.white,
    onSecondary: const Color(0xFFE57697).computeLuminance() > 0.5
        ? Colors.black
        : Colors.white,
    error: Colors.red.shade400,
  ),
).copyWith(
  textSelectionTheme:
      const TextSelectionThemeData(cursorColor: Color(0xFFE57697)),
  highlightColor: const Color(0xFFE57697).withOpacity(0.2),
  scaffoldBackgroundColor: config.Colors().mainColor(1),
  toggleableActiveColor: const Color(0xFFE57697),
  disabledColor: Colors.grey,
);

ThemeData kDarkTheme = ThemeData.from(
  textTheme: TextTheme(
    button: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: config.Colors().mainDarkColor(1),
    ),
    headline5: TextStyle(
      fontSize: 16.0,
      color: config.Colors().accentDarkColor(1),
      fontFamily: "Proxima Nova",
    ),
    headline4: TextStyle(
        fontSize: 16,
        fontFamily: "Proxima Nova",
        fontWeight: FontWeight.w500,
        color: config.Colors().accentDarkColor(1)),
    headline3: const TextStyle(
      fontSize: 20,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    headline2: const TextStyle(
      fontSize: 24,
      fontFamily: "Proxima Nova",
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    headline1: TextStyle(
      fontFamily: 'Proxima Nova',
      color: config.Colors().accentDarkColor(1),
      fontSize: 50,
      fontWeight: FontWeight.w600,
    ),
    subtitle1: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w900,
      color: config.Colors().secondDarkColor(1),
      fontFamily: "Roboto",
    ),
    headline6: TextStyle(
      fontSize: 14.0,
      color: config.Colors().accentDarkColor(.85),
      fontFamily: "Proxima Nova",
    ),
    bodyText2: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(.85),
    ),
    bodyText1: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(1),
    ),
    caption: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: config.Colors().accentDarkColor(1),
    ),
  ),
  colorScheme: ColorScheme(
    brightness: Brightness.dark,
    primary: const Color(0xFFE57697),
    primaryVariant: const Color(0xFFE57697),
    secondary: Colors.white,
    secondaryVariant: Colors.white,
    background: config.Colors().mainDarkColor(1),
    surface: config.Colors().mainDarkColor(1),
    onBackground: Colors.white,
    onSurface: Colors.white,
    onError: Colors.white,
    onPrimary: const Color(0xFFE57697).computeLuminance() > 0.5
        ? Colors.black
        : Colors.white,
    onSecondary: const Color(0xFFE57697).computeLuminance() > 0.5
        ? Colors.black
        : Colors.white,
    error: Colors.red.shade400,
  ),
).copyWith(
  textSelectionTheme:
      const TextSelectionThemeData(cursorColor: Color(0xFFE57697)),
  highlightColor: const Color(0xFFE57697).withOpacity(0.2),
  scaffoldBackgroundColor: config.Colors().mainDarkColor(1),
  toggleableActiveColor: const Color(0xFFE57697),
  disabledColor: Colors.grey,
);

// ThemeData kLightTheme2 = ThemeData(
//   canvasColor: Colors.transparent,
//   primaryColor: const Color(0xFFF7F1E3),
//   brightness: Brightness.light,
//   errorColor: const Color(0xFFC19439),
//   focusColor: config.Colors().mainColor(1),
//   hintColor: const Color(0xFFF1E6D0),
//   textTheme: TextTheme(
//     button: const TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 16,
//       fontWeight: FontWeight.w800,
//       color: Color(0xFFFFFFFF),
//     ),
//     headline5: TextStyle(
//       fontSize: 16.0,
//       color: Colors.white.withOpacity(1),
//       fontFamily: "Proxima Nova",
//     ),
//     headline4: TextStyle(
//         fontSize: 16,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: config.Colors().accentColor(1)),
//     headline3: const TextStyle(
//         fontSize: 20,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: Colors.black),
//     headline2: const TextStyle(
//         fontSize: 24,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: Colors.black),
//     headline1: TextStyle(
//       fontFamily: 'Proxima Nova',
//       color: config.Colors().accentColor(1),
//       fontSize: 50,
//       fontWeight: FontWeight.w600,
//     ),
//     subtitle1: TextStyle(
//       fontSize: 20,
//       fontWeight: FontWeight.w900,
//       color: config.Colors().secondColor(1),
//       fontFamily: "Roboto",
//     ),
//     headline6: TextStyle(
//       fontSize: 13.0,
//       color: Colors.white.withOpacity(.85),
//       fontFamily: "Proxima Nova",
//     ),
//     bodyText2: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 14,
//       fontWeight: FontWeight.w500,
//       color: Colors.white.withOpacity(.75),
//     ),
//     bodyText1: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 24,
//       fontWeight: FontWeight.w500,
//       color: Colors.white.withOpacity(1),
//     ),
//     caption: TextStyle(
//       fontFamily: 'Roboto',
//       fontSize: 16,
//       fontWeight: FontWeight.w400,
//       color: config.Colors().accentColor(1),
//     ),
//   ),
//   colorScheme: const ColorScheme.light(primary: Color(0xFFC19439))
//       .copyWith(secondary: const Color(0xFF96732C)),
// );

// ThemeData kDarkTheme2 = ThemeData(
//   canvasColor: Colors.transparent,
//   primaryColor: Colors.black,
//   brightness: Brightness.dark,
//   errorColor: Colors.black,
//   focusColor: Colors.black,
//   hintColor: Colors.black,
//   textTheme: TextTheme(
//     button: const TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 16,
//       fontWeight: FontWeight.w800,
//       color: Colors.black,
//     ),
//     headline5: const TextStyle(
//       fontSize: 16.0,
//       color: Colors.white,
//       fontFamily: "Proxima Nova",
//     ),
//     headline4: const TextStyle(
//         fontSize: 16,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: Colors.white),
//     headline3: const TextStyle(
//         fontSize: 20,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: Colors.white),
//     headline2: const TextStyle(
//         fontSize: 24,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: Colors.white),
//     headline1: const TextStyle(
//       fontFamily: 'Proxima Nova',
//       color: Colors.white,
//       fontSize: 50,
//       fontWeight: FontWeight.w600,
//     ),
//     subtitle1: const TextStyle(
//       fontSize: 20,
//       fontWeight: FontWeight.w900,
//       color: Colors.black,
//       fontFamily: "Roboto",
//     ),
//     headline6: TextStyle(
//       fontSize: 14.0,
//       color: Colors.white.withOpacity(0.85),
//       fontFamily: "Proxima Nova",
//     ),
//     bodyText2: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 14,
//       fontWeight: FontWeight.w500,
//       color: Colors.white.withOpacity(.85),
//     ),
//     bodyText1: const TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 22,
//       fontWeight: FontWeight.w500,
//       color: Colors.white,
//     ),
//     caption: const TextStyle(
//       fontFamily: 'Roboto',
//       fontSize: 16,
//       fontWeight: FontWeight.w400,
//       color: Colors.white,
//     ),
//   ),
//   colorScheme: const ColorScheme.dark(primary: Color(0xFFFFFFFF))
//       .copyWith(secondary: Colors.white),
// );

// ThemeData kLightTheme3 = ThemeData(
//   canvasColor: Colors.transparent,
//   primaryColor: const Color(0xFFC5A79F),
//   brightness: Brightness.light,
//   errorColor: const Color(0xFFA7796D),
//   focusColor: config.Colors().mainColor(1),
//   hintColor: const Color(0xFFBE9C93),
//   textTheme: TextTheme(
//     button: const TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 16,
//       fontWeight: FontWeight.w800,
//       color: Color(0xFFFFFFFF),
//     ),
//     headline5: TextStyle(
//       fontSize: 16.0,
//       color: Colors.white.withOpacity(1),
//       fontFamily: "Proxima Nova",
//     ),
//     headline4: TextStyle(
//         fontSize: 16,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: config.Colors().accentColor(1)),
//     headline3: const TextStyle(
//         fontSize: 20,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: Colors.black),
//     headline2: const TextStyle(
//         fontSize: 24,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: Colors.black),
//     headline1: TextStyle(
//       fontFamily: 'Proxima Nova',
//       color: config.Colors().accentColor(1),
//       fontSize: 50,
//       fontWeight: FontWeight.w600,
//     ),
//     subtitle1: TextStyle(
//       fontSize: 20,
//       fontWeight: FontWeight.w900,
//       color: config.Colors().secondColor(1),
//       fontFamily: "Roboto",
//     ),
//     headline6: TextStyle(
//       fontSize: 13.0,
//       color: Colors.white.withOpacity(.85),
//       fontFamily: "Proxima Nova",
//     ),
//     bodyText2: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 14,
//       fontWeight: FontWeight.w500,
//       color: Colors.white.withOpacity(.75),
//     ),
//     bodyText1: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 24,
//       fontWeight: FontWeight.w500,
//       color: Colors.white.withOpacity(1),
//     ),
//     caption: TextStyle(
//       fontFamily: 'Roboto',
//       fontSize: 16,
//       fontWeight: FontWeight.w400,
//       color: config.Colors().accentColor(1),
//     ),
//   ),
//   colorScheme: const ColorScheme.light(primary: Color(0xFFA7796D))
//       .copyWith(secondary: const Color(0xFF7D564B)),
// );

// ThemeData kLightTheme4 = ThemeData(
//   canvasColor: Colors.transparent,
//   primaryColor: const Color(0xFF8399BE),
//   brightness: Brightness.light,
//   errorColor: const Color(0xFF596F95),
//   focusColor: config.Colors().mainColor(1),
//   hintColor: const Color(0xFF788CAF),
//   textTheme: TextTheme(
//     button: const TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 16,
//       fontWeight: FontWeight.w800,
//       color: Color(0xFFFFFFFF),
//     ),
//     headline5: TextStyle(
//       fontSize: 16.0,
//       color: Colors.white.withOpacity(1),
//       fontFamily: "Proxima Nova",
//     ),
//     headline4: TextStyle(
//         fontSize: 16,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: config.Colors().accentColor(1)),
//     headline3: const TextStyle(
//         fontSize: 20,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: Colors.black),
//     headline2: const TextStyle(
//         fontSize: 24,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: Colors.black),
//     headline1: TextStyle(
//       fontFamily: 'Proxima Nova',
//       color: config.Colors().accentColor(1),
//       fontSize: 50,
//       fontWeight: FontWeight.w600,
//     ),
//     subtitle1: TextStyle(
//       fontSize: 20,
//       fontWeight: FontWeight.w900,
//       color: config.Colors().secondColor(1),
//       fontFamily: "Roboto",
//     ),
//     headline6: TextStyle(
//       fontSize: 13.0,
//       color: Colors.white.withOpacity(.85),
//       fontFamily: "Proxima Nova",
//     ),
//     bodyText2: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 14,
//       fontWeight: FontWeight.w500,
//       color: Colors.white.withOpacity(.75),
//     ),
//     bodyText1: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 24,
//       fontWeight: FontWeight.w500,
//       color: Colors.white.withOpacity(1),
//     ),
//     caption: TextStyle(
//       fontFamily: 'Roboto',
//       fontSize: 16,
//       fontWeight: FontWeight.w400,
//       color: config.Colors().accentColor(1),
//     ),
//   ),
//   colorScheme: const ColorScheme.light(primary: Color(0xFF596F95))
//       .copyWith(secondary: const Color(0xFF36435A)),
// );

// ThemeData kDarkTheme3 = ThemeData(
//   canvasColor: Colors.transparent,
//   primaryColor: const Color(0xFF202113),
//   brightness: Brightness.dark,
//   errorColor: const Color(0xFF767B45),
//   focusColor: config.Colors().mainDarkColor(1),
//   hintColor: const Color(0xFF35371F),
//   textTheme: TextTheme(
//     button: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 16,
//       fontWeight: FontWeight.w800,
//       color: config.Colors().mainDarkColor(1),
//     ),
//     headline5: TextStyle(
//       fontSize: 16.0,
//       color: config.Colors().accentDarkColor(1),
//       fontFamily: "Proxima Nova",
//     ),
//     headline4: TextStyle(
//         fontSize: 16,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: config.Colors().accentDarkColor(1)),
//     headline3: const TextStyle(
//         fontSize: 20,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: Colors.white),
//     headline2: const TextStyle(
//         fontSize: 24,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: Colors.white),
//     headline1: TextStyle(
//       fontFamily: 'Proxima Nova',
//       color: config.Colors().accentDarkColor(1),
//       fontSize: 50,
//       fontWeight: FontWeight.w600,
//     ),
//     subtitle1: TextStyle(
//       fontSize: 20,
//       fontWeight: FontWeight.w900,
//       color: config.Colors().secondDarkColor(1),
//       fontFamily: "Roboto",
//     ),
//     headline6: TextStyle(
//       fontSize: 14.0,
//       color: config.Colors().accentDarkColor(.85),
//       fontFamily: "Proxima Nova",
//     ),
//     bodyText2: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 14,
//       fontWeight: FontWeight.w500,
//       color: config.Colors().accentDarkColor(.85),
//     ),
//     bodyText1: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 22,
//       fontWeight: FontWeight.w500,
//       color: config.Colors().accentDarkColor(1),
//     ),
//     caption: TextStyle(
//       fontFamily: 'Roboto',
//       fontSize: 16,
//       fontWeight: FontWeight.w400,
//       color: config.Colors().accentDarkColor(1),
//     ),
//   ),
//   colorScheme: const ColorScheme.dark(primary: Color(0xFF767B45))
//       .copyWith(secondary: const Color(0xFFE3E4D0)),
// );

// ThemeData kDarkTheme4 = ThemeData(
//   canvasColor: Colors.transparent,
//   primaryColor: const Color(0xFF041B29),
//   brightness: Brightness.dark,
//   errorColor: const Color(0xFF427DA8),
//   focusColor: config.Colors().mainDarkColor(1),
//   hintColor: const Color(0xFF152836),
//   textTheme: TextTheme(
//     button: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 16,
//       fontWeight: FontWeight.w800,
//       color: config.Colors().mainDarkColor(1),
//     ),
//     headline5: TextStyle(
//       fontSize: 16.0,
//       color: config.Colors().accentDarkColor(1),
//       fontFamily: "Proxima Nova",
//     ),
//     headline4: TextStyle(
//         fontSize: 16,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: config.Colors().accentDarkColor(1)),
//     headline3: const TextStyle(
//         fontSize: 20,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: Colors.white),
//     headline2: const TextStyle(
//         fontSize: 24,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: Colors.white),
//     headline1: TextStyle(
//       fontFamily: 'Proxima Nova',
//       color: config.Colors().accentDarkColor(1),
//       fontSize: 50,
//       fontWeight: FontWeight.w600,
//     ),
//     subtitle1: TextStyle(
//       fontSize: 20,
//       fontWeight: FontWeight.w900,
//       color: config.Colors().secondDarkColor(1),
//       fontFamily: "Roboto",
//     ),
//     headline6: TextStyle(
//       fontSize: 14.0,
//       color: config.Colors().accentDarkColor(.85),
//       fontFamily: "Proxima Nova",
//     ),
//     bodyText2: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 14,
//       fontWeight: FontWeight.w500,
//       color: config.Colors().accentDarkColor(.85),
//     ),
//     bodyText1: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 22,
//       fontWeight: FontWeight.w500,
//       color: config.Colors().accentDarkColor(1),
//     ),
//     caption: TextStyle(
//       fontFamily: 'Roboto',
//       fontSize: 16,
//       fontWeight: FontWeight.w400,
//       color: config.Colors().accentDarkColor(1),
//     ),
//   ),
//   colorScheme: const ColorScheme.dark(primary: Color(0xFF427DA8))
//       .copyWith(secondary: const Color(0xFFB0CCE0)),
// );

// ThemeData kDarkTheme5 = ThemeData(
//   canvasColor: Colors.transparent,
//   primaryColor: const Color(0xFF12210E),
//   brightness: Brightness.dark,
//   errorColor: const Color(0xFF4C7044),
//   focusColor: config.Colors().mainDarkColor(1),
//   hintColor: const Color(0xFF1D2B1A),
//   textTheme: TextTheme(
//     button: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 16,
//       fontWeight: FontWeight.w800,
//       color: config.Colors().mainDarkColor(1),
//     ),
//     headline5: TextStyle(
//       fontSize: 16.0,
//       color: config.Colors().accentDarkColor(1),
//       fontFamily: "Proxima Nova",
//     ),
//     headline4: TextStyle(
//         fontSize: 16,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: config.Colors().accentDarkColor(1)),
//     headline3: const TextStyle(
//         fontSize: 20,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: Colors.white),
//     headline2: const TextStyle(
//         fontSize: 24,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: Colors.white),
//     headline1: TextStyle(
//       fontFamily: 'Proxima Nova',
//       color: config.Colors().accentDarkColor(1),
//       fontSize: 50,
//       fontWeight: FontWeight.w600,
//     ),
//     subtitle1: TextStyle(
//       fontSize: 20,
//       fontWeight: FontWeight.w900,
//       color: config.Colors().secondDarkColor(1),
//       fontFamily: "Roboto",
//     ),
//     headline6: TextStyle(
//       fontSize: 14.0,
//       color: config.Colors().accentDarkColor(.85),
//       fontFamily: "Proxima Nova",
//     ),
//     bodyText2: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 14,
//       fontWeight: FontWeight.w500,
//       color: config.Colors().accentDarkColor(.85),
//     ),
//     bodyText1: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 22,
//       fontWeight: FontWeight.w500,
//       color: config.Colors().accentDarkColor(1),
//     ),
//     caption: TextStyle(
//       fontFamily: 'Roboto',
//       fontSize: 16,
//       fontWeight: FontWeight.w400,
//       color: config.Colors().accentDarkColor(1),
//     ),
//   ),
//   colorScheme: const ColorScheme.dark(primary: Color(0xFF4C7044))
//       .copyWith(secondary: const Color(0xFFD9E6D6)),
// );

// ThemeData kDarkTheme6 = ThemeData(
//   canvasColor: Colors.transparent,
//   primaryColor: const Color(0xFF290D02),
//   brightness: Brightness.dark,
//   errorColor: const Color(0xFF703826),
//   focusColor: config.Colors().mainDarkColor(1),
//   hintColor: const Color(0xFF361B12),
//   textTheme: TextTheme(
//     button: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 16,
//       fontWeight: FontWeight.w800,
//       color: config.Colors().mainDarkColor(1),
//     ),
//     headline5: TextStyle(
//       fontSize: 16.0,
//       color: config.Colors().accentDarkColor(1),
//       fontFamily: "Proxima Nova",
//     ),
//     headline4: TextStyle(
//         fontSize: 16,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: config.Colors().accentDarkColor(1)),
//     headline3: const TextStyle(
//         fontSize: 20,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: Colors.white),
//     headline2: const TextStyle(
//         fontSize: 24,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: Colors.white),
//     headline1: TextStyle(
//       fontFamily: 'Proxima Nova',
//       color: config.Colors().accentDarkColor(1),
//       fontSize: 50,
//       fontWeight: FontWeight.w600,
//     ),
//     subtitle1: TextStyle(
//       fontSize: 20,
//       fontWeight: FontWeight.w900,
//       color: config.Colors().secondDarkColor(1),
//       fontFamily: "Roboto",
//     ),
//     headline6: TextStyle(
//       fontSize: 14.0,
//       color: config.Colors().accentDarkColor(.85),
//       fontFamily: "Proxima Nova",
//     ),
//     bodyText2: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 14,
//       fontWeight: FontWeight.w500,
//       color: config.Colors().accentDarkColor(.85),
//     ),
//     bodyText1: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 22,
//       fontWeight: FontWeight.w500,
//       color: config.Colors().accentDarkColor(1),
//     ),
//     caption: TextStyle(
//       fontFamily: 'Roboto',
//       fontSize: 16,
//       fontWeight: FontWeight.w400,
//       color: config.Colors().accentDarkColor(1),
//     ),
//   ),
//   colorScheme: const ColorScheme.dark(primary: Color(0xFF703826))
//       .copyWith(secondary: const Color(0xFFDFB0A0)),
// );

// ThemeData kDarkTheme7 = ThemeData(
//   canvasColor: Colors.transparent,
//   primaryColor: const Color(0xFF142431),
//   brightness: Brightness.dark,
//   errorColor: const Color(0xFF2D6079),
//   focusColor: config.Colors().mainDarkColor(1),
//   hintColor: const Color(0xFF193543),
//   textTheme: TextTheme(
//     button: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 16,
//       fontWeight: FontWeight.w800,
//       color: config.Colors().mainDarkColor(1),
//     ),
//     headline5: TextStyle(
//       fontSize: 16.0,
//       color: config.Colors().accentDarkColor(1),
//       fontFamily: "Proxima Nova",
//     ),
//     headline4: TextStyle(
//         fontSize: 16,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: config.Colors().accentDarkColor(1)),
//     headline3: const TextStyle(
//         fontSize: 20,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: Colors.white),
//     headline2: const TextStyle(
//         fontSize: 24,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: Colors.white),
//     headline1: TextStyle(
//       fontFamily: 'Proxima Nova',
//       color: config.Colors().accentDarkColor(1),
//       fontSize: 50,
//       fontWeight: FontWeight.w600,
//     ),
//     subtitle1: TextStyle(
//       fontSize: 20,
//       fontWeight: FontWeight.w900,
//       color: config.Colors().secondDarkColor(1),
//       fontFamily: "Roboto",
//     ),
//     headline6: TextStyle(
//       fontSize: 14.0,
//       color: config.Colors().accentDarkColor(.85),
//       fontFamily: "Proxima Nova",
//     ),
//     bodyText2: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 14,
//       fontWeight: FontWeight.w500,
//       color: config.Colors().accentDarkColor(.85),
//     ),
//     bodyText1: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 22,
//       fontWeight: FontWeight.w500,
//       color: config.Colors().accentDarkColor(1),
//     ),
//     caption: TextStyle(
//       fontFamily: 'Roboto',
//       fontSize: 16,
//       fontWeight: FontWeight.w400,
//       color: config.Colors().accentDarkColor(1),
//     ),
//   ),
//   colorScheme: const ColorScheme.dark(primary: Color(0xFF2D6079))
//       .copyWith(secondary: const Color(0xFFA9CDDF)),
// );

// ThemeData kDarkTheme8 = ThemeData(
//   canvasColor: Colors.transparent,
//   primaryColor: const Color(0xFF393D46),
//   brightness: Brightness.dark,
//   errorColor: const Color(0xFF686E80),
//   focusColor: config.Colors().mainDarkColor(1),
//   hintColor: const Color(0xFF33363F),
//   textTheme: TextTheme(
//     button: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 16,
//       fontWeight: FontWeight.w800,
//       color: config.Colors().mainDarkColor(1),
//     ),
//     headline5: TextStyle(
//       fontSize: 16.0,
//       color: config.Colors().accentDarkColor(1),
//       fontFamily: "Proxima Nova",
//     ),
//     headline4: TextStyle(
//         fontSize: 16,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: config.Colors().accentDarkColor(1)),
//     headline3: const TextStyle(
//         fontSize: 20,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: Colors.white),
//     headline2: const TextStyle(
//         fontSize: 24,
//         fontFamily: "Proxima Nova",
//         fontWeight: FontWeight.w500,
//         color: Colors.white),
//     headline1: TextStyle(
//       fontFamily: 'Proxima Nova',
//       color: config.Colors().accentDarkColor(1),
//       fontSize: 50,
//       fontWeight: FontWeight.w600,
//     ),
//     subtitle1: TextStyle(
//       fontSize: 20,
//       fontWeight: FontWeight.w900,
//       color: config.Colors().secondDarkColor(1),
//       fontFamily: "Roboto",
//     ),
//     headline6: TextStyle(
//       fontSize: 14.0,
//       color: config.Colors().accentDarkColor(.85),
//       fontFamily: "Proxima Nova",
//     ),
//     bodyText2: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 14,
//       fontWeight: FontWeight.w500,
//       color: config.Colors().accentDarkColor(.85),
//     ),
//     bodyText1: TextStyle(
//       fontFamily: 'Proxima Nova',
//       fontSize: 22,
//       fontWeight: FontWeight.w500,
//       color: config.Colors().accentDarkColor(1),
//     ),
//     caption: TextStyle(
//       fontFamily: 'Roboto',
//       fontSize: 16,
//       fontWeight: FontWeight.w400,
//       color: config.Colors().accentDarkColor(1),
//     ),
//   ),
//   colorScheme: const ColorScheme.dark(primary: Color(0xFF686E80))
//       .copyWith(secondary: const Color(0xFFEEEFF2)),
// );
