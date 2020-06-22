import 'package:flutter/material.dart';
import 'package:Prism/theme/config.dart' as config;

var kLightTheme = ThemeData(
  primaryColor: Colors.white,
  brightness: Brightness.light,
  accentColor: config.Colors().accentColor(1),
  focusColor: config.Colors().mainColor(1),
  hintColor: config.Colors().secondColor(1),
  accentTextTheme: TextTheme(headline6: TextStyle(fontFamily: "Proxima Nova")),
  textTheme: TextTheme(
    button: TextStyle(
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
    headline3: TextStyle(
        fontSize: 20,
        fontFamily: "Proxima Nova",
        fontWeight: FontWeight.w500,
        color: Colors.black),
    headline2: TextStyle(
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
      fontSize: 20,
      fontWeight: FontWeight.w500,
      color: config.Colors().accentColor(.85),
    ),
    bodyText1: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 24,
      fontWeight: FontWeight.w500,
      color: config.Colors().accentColor(1),
    ),
    caption: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: config.Colors().accentColor(1),
    ),
  ),
);

var kDarkTheme = ThemeData(
  primaryColor: Color(0xFF181818),
  brightness: Brightness.dark,
  accentColor: config.Colors().accentDarkColor(1),
  focusColor: config.Colors().mainDarkColor(1),
  hintColor: config.Colors().secondDarkColor(1),
  accentTextTheme: TextTheme(headline6: TextStyle(fontFamily: "Proxima Nova")),
  textTheme: TextTheme(
    button: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: Color(0xFF181818),
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
    headline3: TextStyle(
        fontSize: 20,
        fontFamily: "Proxima Nova",
        fontWeight: FontWeight.w500,
        color: Colors.white),
    headline2: TextStyle(
        fontSize: 24,
        fontFamily: "Proxima Nova",
        fontWeight: FontWeight.w500,
        color: Colors.white),
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
      fontSize: 20,
      fontWeight: FontWeight.w500,
      color: config.Colors().accentDarkColor(.85),
    ),
    bodyText1: TextStyle(
      fontFamily: 'Proxima Nova',
      fontSize: 24,
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
);
