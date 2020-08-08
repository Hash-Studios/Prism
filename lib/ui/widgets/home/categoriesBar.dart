import 'package:Prism/data/categories/provider/categoriesProvider.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/popup/colorsPopUp.dart';
import 'package:Prism/ui/widgets/popup/tutorialCompletePopUp.dart';
import 'package:Prism/ui/widgets/popup/updatePopUp.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Prism/ui/pages/home/pageManager.dart' as PM;
import 'package:Prism/global/globals.dart' as globals;
import 'package:tutorial_coach_mark/animated_focus_light.dart';
import 'package:tutorial_coach_mark/content_target.dart';
import 'package:tutorial_coach_mark/target_focus.dart';
import 'package:tutorial_coach_mark/target_position.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:Prism/main.dart' as main;
import 'package:scroll_to_index/scroll_to_index.dart';

class CategoriesBar extends StatefulWidget {
  final width;
  final height;
  CategoriesBar({Key key, @required this.width, @required this.height})
      : super(key: key);

  @override
  _CategoriesBarState createState() => _CategoriesBarState();
}

class _CategoriesBarState extends State<CategoriesBar> {
  bool isNew;
  List<TargetFocus> targets = List();
  @override
  void initState() {
    isNew = true;
    super.initState();
    globals.height = widget.height;
    initTargets();
    if (isNew) {
      Future.delayed(Duration(seconds: 0)).then(
          (value) => WidgetsBinding.instance.addPostFrameCallback(afterLayout));
    }
  }

  void initTargets() {
    targets.add(TargetFocus(
      identify: "Target 0",
      targetPosition: TargetPosition(Size(0, 0), Offset(0, 0)),
      contents: [
        ContentTarget(
            align: AlignContent.bottom,
            child: SizedBox(
              height: widget.height,
              child: Container(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      "Hey! Welcome to Prism.",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 20.0),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: RichText(
                        text: TextSpan(
                          text:
                              "➡ Let's start your beautiful journey with a quick intro.\n\n➡ Tap anywhere on the screen to continue.",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ))
      ],
      shape: ShapeLightFocus.Circle,
    ));
    targets.add(TargetFocus(
      identify: "Target 1",
      targetPosition: TargetPosition(Size(widget.width, 60), Offset(0, 20)),
      contents: [
        ContentTarget(
            align: AlignContent.bottom,
            child: Container(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "This is the Categories Bar.",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: RichText(
                      text: TextSpan(
                          text: "➡ Find all wallpaper categories like ",
                          style: TextStyle(color: Colors.white),
                          children: [
                            TextSpan(
                              text:
                                  "Curated, 4k, Abstract, Nature, Art, Minimal ",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: "etc, here.\n\n"),
                            TextSpan(text: "➡ It also has a "),
                            TextSpan(
                              text: "Colors ",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                                text:
                                    "button, which lets you find wallpapers by a specific color.\n\n"),
                          ]),
                    ),
                  )
                ],
              ),
            ))
      ],
      shape: ShapeLightFocus.RRect,
    ));
    targets.add(TargetFocus(
      identify: "Target 2",
      targetPosition: TargetPosition(
          Size(widget.width, widget.height - 400), Offset(0, 70)),
      contents: [
        ContentTarget(
            align: AlignContent.bottom,
            child: Container(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "This is the Wallpapers Feed.",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: RichText(
                      text: TextSpan(
                          text: "➡ Swipe ",
                          style: TextStyle(color: Colors.white),
                          children: [
                            TextSpan(
                              text: "vertically ",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                                text:
                                    "to see all the wallpapers in a category.\n\n"),
                            TextSpan(text: "➡ Swipe "),
                            TextSpan(
                              text: "horizontally ",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                                text:
                                    "to switch between different categories.\n\n"),
                          ]),
                    ),
                  )
                ],
              ),
            ))
      ],
      shape: ShapeLightFocus.RRect,
    ));
    targets.add(TargetFocus(
      targetPosition: TargetPosition(
          Size(widget.width * 0.5, widget.width * 0.5 / 0.6625), Offset(0, 70)),
      identify: "Target 3",
      contents: [
        ContentTarget(
            align: AlignContent.bottom,
            child: Container(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Tap on a wallpaper to view it.",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: RichText(
                      text: TextSpan(
                          text: "➡ You can also ",
                          style: TextStyle(color: Colors.white),
                          children: [
                            TextSpan(
                              text: "apply, favorite,",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: " and"),
                            TextSpan(
                              text: " download",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                                text: " it directly from the 3-dots menu.\n\n"),
                            TextSpan(text: "➡ You can also "),
                            TextSpan(
                              text: "tap and hold ",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                                text:
                                    "any wallpaper to quickly copy its sharing link.\n\n"),
                          ]),
                    ),
                  )
                ],
              ),
            ))
      ],
      shape: ShapeLightFocus.RRect,
    ));
    targets.add(TargetFocus(
      targetPosition: TargetPosition(Size(widget.width * 0.7, 100),
          Offset(widget.width * 0.15, widget.height - 100)),
      identify: "Target 4",
      contents: [
        ContentTarget(
            align: AlignContent.top,
            child: Container(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "This is the navigation bar.",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: RichText(
                      text: TextSpan(
                          text: "➡ Here you can access your ",
                          style: TextStyle(color: Colors.white),
                          children: [
                            TextSpan(
                              text: "favorites, downloads,",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: " and"),
                            TextSpan(
                              text: " search",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: " for more wallpapers.\n\n"),
                            TextSpan(text: "➡ You can also upload your own "),
                            TextSpan(
                              text: "wallpapers ",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: "from here.\n\n"),
                            TextSpan(text: "➡ You can also access your "),
                            TextSpan(
                              text: "profile ",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: "from here.\n\n"),
                          ]),
                    ),
                  )
                ],
              ),
            ))
      ],
      shape: ShapeLightFocus.RRect,
    ));
    // targets.add(TargetFocus(
    //   identify: "Target 5",
    //   targetPosition: TargetPosition(
    //       Size(40, 40), Offset(widget.width / 2 - 45, widget.height - 65)),
    //   contents: [
    //     ContentTarget(
    //         align: AlignContent.top,
    //         child: Container(
    //           child: Column(
    //             mainAxisSize: MainAxisSize.min,
    //             crossAxisAlignment: CrossAxisAlignment.start,
    //             children: <Widget>[
    //               Text(
    //                 "This is the Search Page.",
    //                 style: TextStyle(
    //                     fontWeight: FontWeight.bold,
    //                     color: Colors.white,
    //                     fontSize: 20.0),
    //               ),
    //               Padding(
    //                 padding: const EdgeInsets.only(top: 10.0),
    //                 child: Text(
    //                   "Head over here to search Wallpapers, and apply them.",
    //                   style: TextStyle(color: Colors.white),
    //                 ),
    //               )
    //             ],
    //           ),
    //         ))
    //   ],
    //   shape: ShapeLightFocus.Circle,
    // ));
    // targets.add(TargetFocus(
    //   identify: "Target 6",
    //   targetPosition: TargetPosition(
    //       Size(40, 40), Offset(widget.width / 2 + 5, widget.height - 65)),
    //   contents: [
    //     ContentTarget(
    //         align: AlignContent.top,
    //         child: Container(
    //           child: Column(
    //             mainAxisSize: MainAxisSize.min,
    //             crossAxisAlignment: CrossAxisAlignment.start,
    //             children: <Widget>[
    //               Text(
    //                 "This is the Favorites Page.",
    //                 style: TextStyle(
    //                     fontWeight: FontWeight.bold,
    //                     color: Colors.white,
    //                     fontSize: 20.0),
    //               ),
    //               Padding(
    //                 padding: const EdgeInsets.only(top: 10.0),
    //                 child: Text(
    //                   "All your saved favorites are visible here, and you can apply them straight away from here.",
    //                   style: TextStyle(color: Colors.white),
    //                 ),
    //               )
    //             ],
    //           ),
    //         ))
    //   ],
    //   shape: ShapeLightFocus.Circle,
    // ));
    // targets.add(TargetFocus(
    //   identify: "Target 7",
    //   targetPosition: TargetPosition(
    //       Size(40, 40), Offset(widget.width / 2 + 55, widget.height - 65)),
    //   contents: [
    //     ContentTarget(
    //         align: AlignContent.top,
    //         child: Container(
    //           child: Column(
    //             mainAxisSize: MainAxisSize.min,
    //             crossAxisAlignment: CrossAxisAlignment.start,
    //             children: <Widget>[
    //               Text(
    //                 "This is the Profile Page.",
    //                 style: TextStyle(
    //                     fontWeight: FontWeight.bold,
    //                     color: Colors.white,
    //                     fontSize: 20.0),
    //               ),
    //               Padding(
    //                 padding: const EdgeInsets.only(top: 10.0),
    //                 child: Text(
    //                   "It lets you view your downloads, set wallpapers from downloaded ones, sign in or log out, change themes, clear your downloads and cache, and more experimental features. Clearly this is the next best thing in this app after wallpapers, so make sure to check it out.",
    //                   style: TextStyle(color: Colors.white),
    //                 ),
    //               )
    //             ],
    //           ),
    //         ))
    //   ],
    //   shape: ShapeLightFocus.Circle,
    // ));
    // targets.add(TargetFocus(
    //   identify: "Target 7",
    //   targetPosition: TargetPosition(Size(0, 0), Offset(300 * 0.6625, 370)),
    //   contents: [
    //     ContentTarget(
    //         align: AlignContent.bottom,
    //         child: Container(
    //           child: Column(
    //             mainAxisSize: MainAxisSize.min,
    //             crossAxisAlignment: CrossAxisAlignment.start,
    //             children: <Widget>[
    //               Text(
    //                 "Congratulations.",
    //                 style: TextStyle(
    //                     fontWeight: FontWeight.bold,
    //                     color: Colors.white,
    //                     fontSize: 20.0),
    //               ),
    //               Padding(
    //                 padding: const EdgeInsets.only(top: 10.0),
    //                 child: Text(
    //                   "You have successfully completed the tutorial and are ready to revamp your home screen.\n\nThank you for your awesomeness.",
    //                   style: TextStyle(color: Colors.white),
    //                 ),
    //               )
    //             ],
    //           ),
    //         ))
    //   ],
    //   shape: ShapeLightFocus.Circle,
    // ));
  }

  void showTutorial() {
    TutorialCoachMark(context,
        targets: targets,
        colorShadow: Color(0xFFE57697),
        textSkip: "SKIP",
        paddingFocus: 1,
        opacityShadow: 0.9, finish: () {
      print("finish");
    }, clickTarget: (target) {
      print(target.identify);
      if (target.identify == "Target 4") {
        Future.delayed(Duration(milliseconds: 500))
            .then((value) => showTutorialComplete(context));
      }
    }, clickSkip: () {
      print("skip");
    })
      ..show();
  }

  void afterLayout(_) {
    var newApp = main.prefs.get("newApp");
    if (newApp == null || newApp == true) {
      Future.delayed(Duration(milliseconds: 100), showTutorial);
      main.prefs.put("newApp", false);
    } else {
      main.prefs.put("newApp", false);
    }
  }

  Widget _wrapScrollTag({int index, Widget child}) => AutoScrollTag(
        key: ValueKey(index),
        controller: globals.categoryController,
        index: index,
        child: child,
        highlightColor: Colors.black.withOpacity(0.1),
      );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      excludeHeaderSemantics: false,
      automaticallyImplyLeading: false,
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          globals.updateAvailable
              ? SizedBox(
                  width: MediaQuery.of(context).size.width * 0.1,
                  height: 100,
                  child: IconButton(
                    icon: globals.noNewNotification
                        ? Icon(JamIcons.bell)
                        : Stack(children: <Widget>[
                            Icon(JamIcons.bell_f),
                            Positioned(
                              top: 0.0,
                              right: 0.0,
                              child: Icon(
                                Icons.brightness_1,
                                size: 9.0,
                                color: Color(0xFFE57697),
                              ),
                            )
                          ]),
                    onPressed: () {
                      setState(() {
                        globals.noNewNotification = true;
                      });
                      showUpdate(context);
                    },
                  ),
                )
              : Container(),
          SizedBox(
            // key: globals.keyCategoriesBar,
            width: globals.updateAvailable
                ? MediaQuery.of(context).size.width * 0.7
                : MediaQuery.of(context).size.width * 0.8,
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              controller: globals.categoryController,
              itemCount:
                  Provider.of<CategoryProvider>(context).categories.length,
              itemBuilder: (context, index) {
                return _wrapScrollTag(
                  index: index,
                  child: Align(
                    alignment: Alignment.center,
                    child: Stack(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.all(5),
                          child: AnimatedCrossFade(
                            duration: Duration(milliseconds: 300),
                            firstCurve: Curves.easeIn,
                            secondCurve: Curves.easeIn,
                            secondChild: ActionChip(
                                backgroundColor: Theme.of(context).hintColor,
                                pressElevation: 5,
                                padding: EdgeInsets.fromLTRB(14, 11, 14, 11),
                                label: Text(
                                    Provider.of<CategoryProvider>(context)
                                        .categories[index],
                                    style:
                                        Theme.of(context).textTheme.headline4),
                                onPressed: () {
                                  switch (Provider.of<CategoryProvider>(context,
                                          listen: false)
                                      .categories[index]) {
                                    case "Wallpapers":
                                      PM.pageController.jumpToPage(0);
                                      break;
                                    case "Collections":
                                      PM.pageController.jumpToPage(1);
                                      break;
                                    default:
                                      break;
                                  }
                                }),
                            crossFadeState:
                                Provider.of<CategoryProvider>(context)
                                            .categories[index] ==
                                        Provider.of<CategoryProvider>(context)
                                            .selectedCategory
                                    ? CrossFadeState.showFirst
                                    : CrossFadeState.showSecond,
                            firstChild: ActionChip(
                                pressElevation: 5,
                                padding: EdgeInsets.fromLTRB(14, 11, 14, 11),
                                backgroundColor: Theme.of(context).accentColor,
                                label: Text(
                                    Provider.of<CategoryProvider>(context)
                                        .categories[index],
                                    style: Theme.of(context)
                                        .textTheme
                                        .headline4
                                        .copyWith(
                                            color: Theme.of(context)
                                                .primaryColor)),
                                onPressed: () {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.1,
            height: 100,
            child: IconButton(
              icon: Icon(JamIcons.brush),
              onPressed: () {
                showColors(context);
              },
            ),
          ),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.1,
            height: 100,
            child: IconButton(
              icon: Icon(JamIcons.more_vertical),
              onPressed: () {},
            ),
          )
        ],
      ),
    );
  }
}
