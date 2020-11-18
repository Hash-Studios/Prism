import 'package:Prism/global/categoryMenu.dart';
import 'package:Prism/global/categoryProvider.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:animations/animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Prism/ui/pages/home/core/pageManager.dart' as PM;
import 'package:Prism/theme/config.dart' as config;

void showCategories(BuildContext context, CategoryMenu initialValue) {
  final controller = ScrollController();
  final AlertDialog categoryPopUp = AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    content: Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).primaryColor),
      width: MediaQuery.of(context).size.width * .78,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            height: 75,
            decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10)),
                color: Theme.of(context).primaryColor),
            child: Center(
              child: Text("Categories",
                  style: Theme.of(context).textTheme.headline2),
            ),
          ),
          SizedBox(
            height: 400,
            child: Scrollbar(
              radius: const Radius.circular(500),
              thickness: 5,
              controller: controller,
              isAlwaysShown: true,
              child: ListView.builder(
                controller: controller,
                itemCount: choices.length,
                itemBuilder: (BuildContext context, int index) {
                  final choice = choices[index];
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.all(10),
                      height: 100,
                      width: MediaQuery.of(context).size.width * .7,
                      decoration: BoxDecoration(
                        color: config.Colors().mainAccentColor(1),
                        borderRadius: BorderRadius.circular(10),
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(
                              choice.image as String),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: MaterialButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            Navigator.pop(context);
                            Provider.of<CategorySupplier>(context,
                                    listen: false)
                                .changeSelectedChoice(choice as CategoryMenu);
                            Provider.of<CategorySupplier>(context,
                                    listen: false)
                                .changeWallpaperFuture(
                                    choice as CategoryMenu, "r");
                            PM.tabController.animateTo(0,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInCubic);
                          },
                          child: Container(
                            height: 100,
                            width: MediaQuery.of(context).size.width * .7,
                            decoration: BoxDecoration(
                              color: initialValue == choice as CategoryMenu
                                  ? Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.7)
                                  : Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (initialValue == choice as CategoryMenu)
                                    Icon(JamIcons.check,
                                        color: Theme.of(context).accentColor)
                                  else
                                    Container(),
                                  Text(
                                    choice.name.toString(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headline4
                                        .copyWith(
                                            color:
                                                Theme.of(context).accentColor),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      FlatButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        color: config.Colors().mainAccentColor(1),
        onPressed: () {
          Navigator.of(context).pop();
          debugPrint('You have not chossed anything');
        },
        child: const Text(
          'OK',
          style: TextStyle(
            fontSize: 16.0,
            color: Colors.white,
          ),
        ),
      ),
    ],
    contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
    backgroundColor: Theme.of(context).primaryColor,
    actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
  );
  showModal(
    context: context,
    configuration: const FadeScaleTransitionConfiguration(),
    builder: (BuildContext context) => categoryPopUp,
  );
}
