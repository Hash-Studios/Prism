import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/home/wallpapers/trendingGrid.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as Data;
import 'package:provider/provider.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/main.dart' as main;

class TrendingTile extends StatelessWidget {
  const TrendingTile({
    Key key,
    @required this.widget,
    @required this.index,
  }) : super(key: key);

  final TrendingGrid widget;
  final int index;

  void showGooglePopUp(BuildContext context, Function func) {
    debugPrint(main.prefs.get("isLoggedin").toString());
    if (main.prefs.get("isLoggedin") == false) {
      googleSignInPopUp(context, func);
    } else {
      func();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: Data.subSortedData.isEmpty
              ? BoxDecoration(
                  color: Provider.of<ThemeModel>(context, listen: false)
                              .returnThemeType() ==
                          "Dark"
                      ? Colors.white10
                      : Colors.black.withOpacity(.1),
                  borderRadius: BorderRadius.circular(20),
                )
              : BoxDecoration(
                  color: Provider.of<ThemeModel>(context, listen: false)
                              .returnThemeType() ==
                          "Dark"
                      ? Colors.white10
                      : Colors.black.withOpacity(.1),
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(
                      Data.subSortedData[index]["wallpaper_thumb"].toString(),
                    ),
                    fit: BoxFit.cover,
                  )),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              splashColor: Theme.of(context).accentColor.withOpacity(0.3),
              highlightColor: Theme.of(context).accentColor.withOpacity(0.1),
              onTap: () {
                if (Data.subSortedData == []) {
                } else {
                  globals.isPremiumWall(
                                  globals.premiumCollections,
                                  Data.subSortedData[index]["collections"]
                                          as List ??
                                      []) ==
                              true &&
                          main.prefs.get('premium') != true
                      ? showGooglePopUp(context, () {
                          Navigator.pushNamed(
                            context,
                            premiumRoute,
                          );
                        })
                      : Navigator.pushNamed(
                          context,
                          wallpaperRoute,
                          arguments: [
                            widget.provider,
                            index,
                            Data.subSortedData[index]["wallpaper_thumb"],
                          ],
                        );
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
