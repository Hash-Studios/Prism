import 'package:flutter/material.dart';
import 'package:wallpapers_app/feed.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // debugShowMaterialGrid: true,
      title: 'Prism',
      theme: ThemeData(
        primarySwatch: Colors.grey,
        textTheme: GoogleFonts.sourceSansProTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: Feed(),
    );
  }
}
