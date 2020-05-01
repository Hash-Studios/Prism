import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeItem {
  int id;
  String name, slug;
  ThemeData themeData;

  ThemeItem(this.id, this.name, this.slug, this.themeData);

  static List<ThemeItem> getThemeItems() {
    return <ThemeItem>[
      ThemeItem(
          1,
          'Serene White',
          'light-white-black',
          ThemeData(
            brightness: Brightness.light,
            primaryColor: Color(0xFFFFFFFF),
            secondaryHeaderColor: Color(0xFF000000),
            primarySwatch: Colors.grey,
            textTheme: GoogleFonts.sourceSansProTextTheme(TextTheme(
                title: TextStyle(color: Colors.black),
                subtitle: TextStyle(color: Colors.black))),
          )),
      ThemeItem(
          2,
          'Divine Black',
          'dark-black-white',
          ThemeData(
            brightness: Brightness.dark,
            primaryColor: Color(0xFF272727),
            secondaryHeaderColor: Color(0xFFFFFFFF),
            primarySwatch: Colors.grey,
            textTheme: GoogleFonts.sourceSansProTextTheme(TextTheme(
                title: TextStyle(color: Colors.white),
                subtitle: TextStyle(color: Colors.white))),
          )),
      ThemeItem(
          3,
          'Amoled Blue',
          'dark-black-blue',
          ThemeData(
            brightness: Brightness.dark,
            primaryColor: Color(0xFF000000),
            secondaryHeaderColor: Color(0xFF025EFD),
            primarySwatch: Colors.blue,
            textTheme: GoogleFonts.sourceSansProTextTheme(TextTheme(
                title: TextStyle(color: Colors.white),
                subtitle: TextStyle(color: Colors.white))),
          )),
      ThemeItem(
          4,
          'Classic Dark',
          'dark-black-darkblue',
          ThemeData(
            brightness: Brightness.dark,
            primaryColor: Color(0xFF263238),
            secondaryHeaderColor: Color(0xFFEEEEEE),
            primarySwatch: Colors.blue,
            textTheme: GoogleFonts.sourceSansProTextTheme(TextTheme(
                title: TextStyle(color: Colors.white),
                subtitle: TextStyle(color: Colors.white))),
          )),
      ThemeItem(
          5,
          'Monochrome Cyan',
          'light-cyan-black',
          ThemeData(
            brightness: Brightness.light,
            primaryColor: Colors.cyan[100],
            secondaryHeaderColor: Color(0xFF000000),
            primarySwatch: Colors.cyan,
            textTheme: GoogleFonts.sourceSansProTextTheme(TextTheme(
                title: TextStyle(color: Colors.black),
                subtitle: TextStyle(color: Colors.black))),
          )),
    ];
  }
}
