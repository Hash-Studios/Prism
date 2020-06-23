import 'package:flutter/material.dart';
import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tabs/wallpapers.dart';

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
            autofocus: true,
            onSubmitted: (String query) {
              Navigator.push(context, MaterialPageRoute(builder: (context) {
                return Scaffold(
                    resizeToAvoidBottomInset: false,
                    appBar: AppBar(
                      elevation: 0,
                      centerTitle: true,
                      title: Text(
                        query.toLowerCase(),
                        style: GoogleFonts.pacifico(
                            fontWeight: FontWeight.w600,
                            fontSize: 30,
                            color: DynamicTheme.of(context)
                                .data
                                .secondaryHeaderColor),
                      ),
                    ),
                    body: Wallpapers(query));
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
        body: Container(
          height: double.infinity,
          width: double.infinity,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Image(
                  image: DynamicTheme.of(context).data.primaryColor ==
                          Color(0xFFFFFFFF)
                      ? AssetImage("assets/images/loadingsw.png")
                      : DynamicTheme.of(context).data.primaryColor ==
                              Color(0xFF272727)
                          ? AssetImage("assets/images/loadingdb.png")
                          : DynamicTheme.of(context).data.primaryColor ==
                                  Color(0xFF000000)
                              ? AssetImage("assets/images/loadingab.png")
                              : DynamicTheme.of(context).data.primaryColor ==
                                      Color(0xFF263238)
                                  ? AssetImage("assets/images/loadingcd.png")
                                  : AssetImage("assets/images/loadingmc.png"),
                  height: 600.h,
                  width: 600.w,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    "Search",
                    style: GoogleFonts.raleway(
                        fontSize: 30,
                        color:
                            DynamicTheme.of(context).data.secondaryHeaderColor),
                    textAlign: TextAlign.center,
                  ),
                ),
                Text(
                  "Type any keyword in the search\nbar to find your next\nfavourite wallpaper.",
                  style: GoogleFonts.raleway(
                      fontSize: 16,
                      color:
                          DynamicTheme.of(context).data.secondaryHeaderColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ));
  }
}
