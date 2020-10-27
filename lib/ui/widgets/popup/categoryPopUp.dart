import 'package:Prism/global/categoryMenu.dart';
import 'package:Prism/global/categoryProvider.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Prism/ui/pages/home/core/pageManager.dart' as PM;
import 'package:Prism/theme/config.dart' as config;

void showCategories(BuildContext context, CategoryMenu initialValue) {
  final controller = ScrollController();
  final Dialog categoryPopUp = Dialog(
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
            height: 75,
            width: MediaQuery.of(context).size.width * .78,
            decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20)),
                color: Theme.of(context).primaryColor),
            child: Center(
              child: Text("Categories",
                  style: Theme.of(context).textTheme.headline2),
            ),
          ),
          SizedBox(
            height: 400,
            child: Scrollbar(
              controller: controller,
              isAlwaysShown: true,
              child: SingleChildScrollView(
                controller: controller,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: choices.map((choice) {
                      return Center(
                        child: Container(
                            margin: const EdgeInsets.all(10),
                            height: 100,
                            width: MediaQuery.of(context).size.width * .7,
                            decoration: BoxDecoration(
                              color: config.Colors().mainAccentColor(1),
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(
                                image: NetworkImage(choice.image as String),
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
                                      .changeSelectedChoice(
                                          choice as CategoryMenu);
                                  Provider.of<CategorySupplier>(context,
                                          listen: false)
                                      .changeWallpaperFuture(
                                          choice as CategoryMenu, "r");
                                  PM.pageController.animateToPage(0,
                                      duration:
                                          const Duration(milliseconds: 200),
                                      curve: Curves.easeInCubic);
                                },
                                child: Container(
                                  height: 100,
                                  width: MediaQuery.of(context).size.width * .7,
                                  decoration: BoxDecoration(
                                    color:
                                        initialValue == choice as CategoryMenu
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
                                        if (initialValue ==
                                            choice as CategoryMenu)
                                          Icon(JamIcons.check,
                                              color:
                                                  Theme.of(context).accentColor)
                                        else
                                          Container(),
                                        Text(
                                          choice.name.toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .headline4
                                              .copyWith(
                                                  color: Theme.of(context)
                                                      .accentColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )),
                      );
                    }).toList()),
              ),
            ),
          ),
          const SizedBox(
            height: 25,
          ),
          FlatButton(
            shape: const StadiumBorder(),
            color: config.Colors().mainAccentColor(1),
            onPressed: () {
              Navigator.of(context).pop();
              debugPrint('You have not chossed anything');
            },
            child: const Text(
              'CLOSE',
              style: TextStyle(
                fontSize: 16.0,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(
            height: 15,
          ),
        ],
      ),
    ),
  );
  showDialog(
      context: context,
      builder: (BuildContext context) => categoryPopUp,
      barrierDismissible: true);
}
