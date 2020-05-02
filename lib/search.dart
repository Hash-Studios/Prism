import 'package:flutter/material.dart';
import 'package:wallpapers_app/wallpapers.dart';
import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:cache_image/cache_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wallpapers_app/wallheaven.dart';
import 'package:wallpapers_app/display.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:firebase_database/firebase_database.dart';

class Search extends StatefulWidget {
  @override
  _SearchState createState() => _SearchState();
}

class _SearchState extends State<Search> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: Hero(
          tag: 'search',
          child: Card(
            elevation: 0,
            color: Colors.transparent,
            child: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context);
                }),
          ),
        ),
        title: TextField(
          onSubmitted: (String query) {
            Navigator.push(context, MaterialPageRoute(builder: (context) {
              return Wallpapers(query);
            }));
          },
          decoration: InputDecoration(
            hintText: "Search Wallpapers",
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: DynamicTheme.of(context).data.secondaryHeaderColor,
            ),
          ),
        ),
      ),
    );
  }
}
