import 'package:flutter/material.dart';
import 'package:wallpapers_app/feed.dart';

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
      ),
      home: Feed(),
    );
  }
}
