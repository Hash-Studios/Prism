import 'package:Prism/data/categories/provider/categoriesProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/popup/colorsPopUp.dart';
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

class CategoriesBar extends StatefulWidget {
  CategoriesBar({Key key}) : super(key: key);

  @override
  _CategoriesBarState createState() => _CategoriesBarState();
}

class _CategoriesBarState extends State<CategoriesBar> {
  List<TargetFocus> targets = List();
  @override
  void initState() {
    initTargets();
    WidgetsBinding.instance.addPostFrameCallback(_afterLayout);
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
    targets.add(TargetFocus(
      identify: "Target 3",
      keyTarget: globals.keyBottomBar,
      contents: [
        ContentTarget(
            align: AlignContent.top,
            child: Container(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "This is the Navigation Bar.",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "It lets you quickly switch between Home, Search, Favorites and Profile.",
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                ],
              ),
            ))
      ],
      shape: ShapeLightFocus.RRect,
    ));
  }

  void showTutorial() {
    TutorialCoachMark(context,
        targets: targets,
        colorShadow: Color(0xFFE57697),
        textSkip: "SKIP",
        paddingFocus: 1,
        opacityShadow: 0.8, finish: () {
      print("finish");
    }, clickTarget: (target) {
      print(target);
    }, clickSkip: () {
      print("skip");
    })
      ..show();
  }

  void _afterLayout(_) {
    Future.delayed(Duration(milliseconds: 100), () {
      showTutorial();
    });
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
                                if (Provider.of<CategoryProvider>(context,
                                            listen: false)
                                        .selectedCategory ==
                                    "Home") {
                                  if (Provider.of<CategoryProvider>(context,
                                              listen: false)
                                          .categories[index] ==
                                      "Home") {
                                  } else if (Provider.of<CategoryProvider>(
                                              context,
                                              listen: false)
                                          .categories[index] ==
                                      "Curated") {
                                    PM.pageController.jumpToPage(1);
                                  } else if (Provider.of<CategoryProvider>(
                                              context,
                                              listen: false)
                                          .categories[index] ==
                                      "Abstract") {
                                    PM.pageController.jumpToPage(2);
                                  } else if (Provider.of<CategoryProvider>(
                                              context,
                                              listen: false)
                                          .categories[index] ==
                                      "Nature") {
                                    PM.pageController.jumpToPage(3);
                                  } else if (Provider.of<CategoryProvider>(
                                              context,
                                              listen: false)
                                          .categories[index] ==
                                      "Colors") {
                                    showColors(context);
                                  }
                                } else if (Provider.of<CategoryProvider>(
                                            context,
                                            listen: false)
                                        .selectedCategory ==
                                    "Curated") {
                                  if (Provider.of<CategoryProvider>(context,
                                              listen: false)
                                          .categories[index] ==
                                      "Home") {
                                    print(navStack);
                                    PM.pageController.jumpToPage(0);
                                  } else if (Provider.of<CategoryProvider>(
                                              context,
                                              listen: false)
                                          .categories[index] ==
                                      "Curated") {
                                  } else if (Provider.of<CategoryProvider>(
                                              context,
                                              listen: false)
                                          .categories[index] ==
                                      "Abstract") {
                                    PM.pageController.jumpToPage(2);
                                  } else if (Provider.of<CategoryProvider>(
                                              context,
                                              listen: false)
                                          .categories[index] ==
                                      "Nature") {
                                    PM.pageController.jumpToPage(3);
                                  } else if (Provider.of<CategoryProvider>(
                                              context,
                                              listen: false)
                                          .categories[index] ==
                                      "Colors") {
                                    showColors(context);
                                  }
                                } else if (Provider.of<CategoryProvider>(
                                            context,
                                            listen: false)
                                        .selectedCategory ==
                                    "Abstract") {
                                  if (Provider.of<CategoryProvider>(context,
                                              listen: false)
                                          .categories[index] ==
                                      "Home") {
                                    print(navStack);
                                    PM.pageController.jumpToPage(0);
                                  } else if (Provider.of<CategoryProvider>(
                                              context,
                                              listen: false)
                                          .categories[index] ==
                                      "Curated") {
                                    PM.pageController.jumpToPage(1);
                                  } else if (Provider.of<CategoryProvider>(
                                              context,
                                              listen: false)
                                          .categories[index] ==
                                      "Abstract") {
                                  } else if (Provider.of<CategoryProvider>(
                                              context,
                                              listen: false)
                                          .categories[index] ==
                                      "Nature") {
                                    PM.pageController.jumpToPage(3);
                                  } else if (Provider.of<CategoryProvider>(
                                              context,
                                              listen: false)
                                          .categories[index] ==
                                      "Colors") {
                                    showColors(context);
                                  }
                                } else if (Provider.of<CategoryProvider>(
                                            context,
                                            listen: false)
                                        .selectedCategory ==
                                    "Nature") {
                                  if (Provider.of<CategoryProvider>(context,
                                              listen: false)
                                          .categories[index] ==
                                      "Home") {
                                    print(navStack);
                                    PM.pageController.jumpToPage(0);
                                  } else if (Provider.of<CategoryProvider>(
                                              context,
                                              listen: false)
                                          .categories[index] ==
                                      "Curated") {
                                    PM.pageController.jumpToPage(1);
                                  } else if (Provider.of<CategoryProvider>(
                                              context,
                                              listen: false)
                                          .categories[index] ==
                                      "Abstract") {
                                    PM.pageController.jumpToPage(2);
                                  } else if (Provider.of<CategoryProvider>(
                                              context,
                                              listen: false)
                                          .categories[index] ==
                                      "Nature") {
                                  } else if (Provider.of<CategoryProvider>(
                                              context,
                                              listen: false)
                                          .categories[index] ==
                                      "Colors") {
                                    showColors(context);
                                  }
                                } else if (Provider.of<CategoryProvider>(
                                            context,
                                            listen: false)
                                        .selectedCategory ==
                                    "Colors") {
                                  if (Provider.of<CategoryProvider>(context,
                                              listen: false)
                                          .categories[index] ==
                                      "Home") {
                                    print(navStack);
                                    PM.pageController.jumpToPage(0);
                                  } else if (Provider.of<CategoryProvider>(
                                              context,
                                              listen: false)
                                          .categories[index] ==
                                      "Curated") {
                                    PM.pageController.jumpToPage(1);
                                  } else if (Provider.of<CategoryProvider>(
                                              context,
                                              listen: false)
                                          .categories[index] ==
                                      "Abstract") {
                                    PM.pageController.jumpToPage(2);
                                  } else if (Provider.of<CategoryProvider>(
                                              context,
                                              listen: false)
                                          .categories[index] ==
                                      "Nature") {
                                    PM.pageController.jumpToPage(3);
                                  } else if (Provider.of<CategoryProvider>(
                                              context,
                                              listen: false)
                                          .categories[index] ==
                                      "Colors") {
                                    showColors(context);
                                  }
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
