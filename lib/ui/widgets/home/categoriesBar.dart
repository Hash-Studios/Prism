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

class CategoriesBar extends StatefulWidget {
  CategoriesBar({Key key}) : super(key: key);

  @override
  _CategoriesBarState createState() => _CategoriesBarState();
}

class _CategoriesBarState extends State<CategoriesBar> {
  bool isNew;
  List<TargetFocus> targets = List();
  @override
  void initState() {
    isNew = true;
    initTargets();
    if (isNew) {
      Future.delayed(Duration(seconds: 0)).then(
          (value) => WidgetsBinding.instance.addPostFrameCallback(afterLayout));
    }
    super.initState();
  }

  void initTargets() {
    targets.add(TargetFocus(
      identify: "Target 1",
      keyTarget: globals.keyCategoriesBar,
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
                    child: Text(
                      "Find all wallpaper categories like Curated, Abstract and Nature, here. At last, it also has a Colors button, which lets you select the color of the wallpapers you want.",
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                ],
              ),
            ))
      ],
      shape: ShapeLightFocus.RRect,
    ));
    targets.add(TargetFocus(
      targetPosition: TargetPosition(Size(300 * 0.6625, 300), Offset(0, 70)),
      identify: "Target 2",
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
                    child: Text(
                      "You can also apply, favorite, and download it directly from the 3-dots menu.",
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                ],
              ),
            ))
      ],
      shape: ShapeLightFocus.RRect,
    ));
    // targets.add(TargetFocus(
    //   identify: "Target 3",
    //   keyTarget: globals.keyBottomBar,
    //   contents: [
    //     ContentTarget(
    //         align: AlignContent.top,
    //         child: Container(
    //           child: Column(
    //             mainAxisSize: MainAxisSize.min,
    //             crossAxisAlignment: CrossAxisAlignment.start,
    //             children: <Widget>[
    //               Text(
    //                 "This is the Navigation Bar.",
    //                 style: TextStyle(
    //                     fontWeight: FontWeight.bold,
    //                     color: Colors.white,
    //                     fontSize: 20.0),
    //               ),
    //               Padding(
    //                 padding: const EdgeInsets.only(top: 10.0),
    //                 child: Text(
    //                   "It lets you quickly switch between Home, Search, Favorites and Profile.",
    //                   style: TextStyle(color: Colors.white),
    //                 ),
    //               )
    //             ],
    //           ),
    //         ))
    //   ],
    //   shape: ShapeLightFocus.RRect,
    // ));
    targets.add(TargetFocus(
      identify: "Target 4",
      keyTarget: globals.keySearchButton,
      contents: [
        ContentTarget(
            align: AlignContent.top,
            child: Container(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "This is the Search Page.",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Head over here to search Wallpapers, and apply them.",
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                ],
              ),
            ))
      ],
      shape: ShapeLightFocus.Circle,
    ));
    targets.add(TargetFocus(
      identify: "Target 5",
      keyTarget: globals.keyFavButton,
      contents: [
        ContentTarget(
            align: AlignContent.top,
            child: Container(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "This is the Favorites Page.",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "All your saved favorites are visible here, and you can apply them straight away from here.",
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                ],
              ),
            ))
      ],
      shape: ShapeLightFocus.Circle,
    ));
    targets.add(TargetFocus(
      identify: "Target 6",
      keyTarget: globals.keyProfileButton,
      contents: [
        ContentTarget(
            align: AlignContent.top,
            child: Container(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "This is the Profile Page.",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "It lets you view your downloads, set wallpapers from downloaded ones, sign in or log out, change themes, clear your downloads and cache, and more experimental features. Clearly this is the next best thing in this app after wallpapers, so make sure to check it out.",
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                ],
              ),
            ))
      ],
      shape: ShapeLightFocus.Circle,
    ));
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
      showTutorialComplete(context);
    }, clickTarget: (target) {
      print(target);
    }, clickSkip: () {
      print("skip");
    })
      ..show();
  }

  void afterLayout(_) {
    var newApp = main.prefs.getBool("newApp");
    if (newApp == null) {
      Future.delayed(Duration(milliseconds: 100), () {
        showTutorial();
      });
      main.prefs.setBool("newApp", false);
    } else {
      main.prefs.setBool("newApp", false);
    }
  }

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
            key: globals.keyCategoriesBar,
            width: globals.updateAvailable
                ? MediaQuery.of(context).size.width * 0.9
                : MediaQuery.of(context).size.width,
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount:
                  Provider.of<CategoryProvider>(context).categories.length,
              itemBuilder: (context, index) {
                return Align(
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
                                  style: Theme.of(context).textTheme.headline4),
                              onPressed: () {
                                switch (Provider.of<CategoryProvider>(context,
                                        listen: false)
                                    .categories[index]) {
                                  case "Home":
                                    PM.pageController.jumpToPage(0);
                                    break;
                                  case "Curated":
                                    PM.pageController.jumpToPage(1);
                                    break;
                                  case "Abstract":
                                    PM.pageController.jumpToPage(2);
                                    break;
                                  case "Nature":
                                    PM.pageController.jumpToPage(3);
                                    break;
                                  case "Art":
                                    PM.pageController.jumpToPage(4);
                                    break;
                                  case "Minimal":
                                    PM.pageController.jumpToPage(5);
                                    break;
                                  case "Textures":
                                    PM.pageController.jumpToPage(6);
                                    break;
                                  case "Monochrome":
                                    PM.pageController.jumpToPage(7);
                                    break;
                                  case "Space":
                                    PM.pageController.jumpToPage(8);
                                    break;
                                  case "Animals":
                                    PM.pageController.jumpToPage(9);
                                    break;
                                  case "Neon":
                                    PM.pageController.jumpToPage(10);
                                    break;
                                  case "Sports":
                                    PM.pageController.jumpToPage(11);
                                    break;
                                  case "Music":
                                    PM.pageController.jumpToPage(12);
                                    break;
                                  case "Colors":
                                    showColors(context);
                                    break;
                                  default:
                                    break;
                                }
                              }),
                          crossFadeState: Provider.of<CategoryProvider>(context)
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
                                          color:
                                              Theme.of(context).primaryColor)),
                              onPressed: () {}),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
