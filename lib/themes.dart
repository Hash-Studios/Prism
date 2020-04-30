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
          'Dark Purple & Amber(Light)',
          'light-purple-amber',
          ThemeData(
            brightness: Brightness.light,
            primaryColor: Color(0xFFFFFFFF),
            secondaryHeaderColor: Color(0xFF000000),
            primarySwatch: Colors.grey,
            textTheme: GoogleFonts.sourceSansProTextTheme(),
          )),
      ThemeItem(
          2,
          'Indigo & Pink(Light)',
          'light-indigo-pink',
          ThemeData(
              brightness: Brightness.light,
              primaryColor: Colors.indigo,
              primarySwatch: Colors.pink,
              iconTheme: IconThemeData(color: Colors.pink),
              textTheme: TextTheme(
                  title: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black),
                  subtitle: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w300,
                      color: Colors.black54)))),
      ThemeItem(
          3,
          'Pink & BlueGrey(Dark)',
          'dark-pink-bluegrey',
          ThemeData(
              brightness: Brightness.dark,
              primarySwatch: Colors.blueGrey,
              primaryColor: Colors.pink,
              iconTheme: IconThemeData(color: Colors.blueGrey),
              textTheme: TextTheme(
                  title: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                  subtitle: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w300,
                      color: Colors.white70)))),
      ThemeItem(
          4,
          'Purple & Green(Dark)',
          'dark-purple-green',
          ThemeData(
              brightness: Brightness.dark,
              primaryColor: Colors.purple,
              primarySwatch: Colors.green,
              iconTheme: IconThemeData(color: Colors.green),
              textTheme: TextTheme(
                  title: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                  subtitle: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w300,
                      color: Colors.white70)))),
    ];
  }
}
