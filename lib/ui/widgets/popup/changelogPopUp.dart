import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';

void showChangelog(BuildContext context, Function func) {
  final controller = ScrollController();
  Dialog aboutPopUp = Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).primaryColor),
      width: MediaQuery.of(context).size.width * .78,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            height: 150,
            width: MediaQuery.of(context).size.width * .78,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20)),
                color: Theme.of(context).hintColor),
            child: FlareActor(
              "assets/animations/Changelog.flr",
              isPaused: false,
              alignment: Alignment.center,
              animation: "changelog",
            ),
          ),
          SizedBox(
            height: 400,
            child: Scrollbar(
              controller: controller,
              isAlwaysShown: true,
              child: SingleChildScrollView(
                controller: controller,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Row(
                  //   children: [
                  //     Padding(
                  //       padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
                  //       child: Text(
                  //         'v2.5.0',
                  //         style: TextStyle(
                  //             fontWeight: FontWeight.w700,
                  //             fontSize: 16,
                  //             color: Theme.of(context).accentColor),
                  //       ),
                  //     ),
                  //   ],
                  // ),
                  // SizedBox(
                  //   height: 20,
                  // ),
                  // Row(
                  //   crossAxisAlignment: CrossAxisAlignment.center,
                  //   mainAxisAlignment: MainAxisAlignment.start,
                  //   children: [
                  //     SizedBox(
                  //       width: 20,
                  //     ),
                  //     Icon(
                  //       JamIcons.picture,
                  //       size: 22,
                  //       color: Color(0xFFE57697),
                  //     ),
                  //     SizedBox(
                  //       width: 20,
                  //     ),
                  //     Container(
                  //       width: MediaQuery.of(context).size.width * 0.6,
                  //       child: Text(
                  //         "Added crop wallpaper support.",
                  //         style: Theme.of(context)
                  //             .textTheme
                  //             .headline6
                  //             .copyWith(color: Theme.of(context).accentColor),
                  //       ),
                  //     ),
                  //   ],
                  // ),
                  // SizedBox(
                  //   height: 25,
                  // ),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
                        child: Text(
                          'v2.4.2',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.bell,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Improved overall notifications.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.bug,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Minor bug fixes.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 25,
                  ),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
                        child: Text(
                          'v2.4.1',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.bug,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Minor bug fixes.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 25,
                  ),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
                        child: Text(
                          'v2.4.0',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.bug,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Major bug fixes and improvements.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.mountain,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Redesigned the wallpaper info sheet.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.home,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Added swipe to change categories.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.bar_chart,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Added Firebase analytics.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.bell,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Added notifications support.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 25,
                  ),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
                        child: Text(
                          'v2.3.5',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.bug,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Major bug fixes and improvements.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 25,
                  ),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
                        child: Text(
                          'v2.3.0',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.brush,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Changed app icon.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.history,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Added backwards compatibility.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.user,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Redesigned profile page UI.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.heart,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Fixed favourites and downloads.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 25,
                  ),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
                        child: Text(
                          'v2.2.0',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.clock,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Added clock overlay to test wallpapers.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.share_alt,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Added ability to share wallpapers.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.pie_chart_alt,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Added ability to clear app cache.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.bug,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Major bug fixes and tweaks.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 25,
                  ),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
                        child: Text(
                          'v2.0.0',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.phone,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Completely new redesigned UI.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.camera,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Added Pexels API support.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.search,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Added new color search.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.brush,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Added new themes.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.pictures,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Added 1M+ wallpapers.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.google,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Added non intrusive sign in support.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.settings_alt,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Added new quick wallpaper actions.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                      ),
                      Icon(
                        JamIcons.eyedropper,
                        size: 22,
                        color: Color(0xFFE57697),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          "Added new palette generator.",
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                      ),
                    ],
                  ),
                ]),
              ),
            ),
          ),
          SizedBox(
            height: 25,
          ),
          FlatButton(
            shape: StadiumBorder(),
            color: Color(0xFFE57697),
            onPressed: () {
              Navigator.of(context).pop();
              func();
            },
            child: Text(
              'CLOSE',
              style: TextStyle(
                fontSize: 16.0,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(
            height: 15,
          ),
        ],
      ),
    ),
  );
  showDialog(context: context, builder: (BuildContext context) => aboutPopUp);
}
