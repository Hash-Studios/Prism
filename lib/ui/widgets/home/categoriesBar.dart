import 'package:Prism/data/categories/provider/categoriesProvider.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/popup/updatePopUp.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Prism/ui/pages/home/pageManager.dart' as PM;
import 'package:Prism/global/globals.dart' as globals;

class CategoriesBar extends StatefulWidget {
  CategoriesBar({Key key}) : super(key: key);

  @override
  _CategoriesBarState createState() => _CategoriesBarState();
}

class _CategoriesBarState extends State<CategoriesBar> {
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
