import 'dart:developer';

import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as Data;
import 'package:Prism/features/category_feed/views/widgets/wallpaper_grid.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class WallpaperTile extends StatelessWidget {
  const WallpaperTile({
    super.key,
    required this.widget,
    required this.index,
  });

  final WallpaperGrid widget;
  final int index;

  void showGooglePopUp(BuildContext context, Function func) {
    logger.d(globals.prismUser.loggedIn.toString());
    if (globals.prismUser.loggedIn == false) {
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
          decoration: Data.subPrismWalls!.isEmpty
              ? BoxDecoration(
                  color: context.prismModeStyleForContext() == "Dark" ? Colors.white10 : Colors.black.withOpacity(.1),
                  borderRadius: BorderRadius.circular(20),
                )
              : BoxDecoration(
                  color: context.prismModeStyleForContext() == "Dark" ? Colors.white10 : Colors.black.withOpacity(.1),
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(
                      Data.subPrismWalls![index]["wallpaper_thumb"].toString(),
                    ),
                    fit: BoxFit.cover,
                  )),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              splashColor: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
              highlightColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              onTap: () {
                if (Data.subPrismWalls == []) {
                } else {
                  log((globals.isPremiumWall(
                              globals.premiumCollections, Data.subPrismWalls![index]["collections"] as List? ?? []) ==
                          true)
                      .toString());
                  log(globals.prismUser.premium.toString());
                  globals.isPremiumWall(globals.premiumCollections,
                                  Data.subPrismWalls![index]["collections"] as List? ?? []) ==
                              true &&
                          globals.prismUser.premium != true
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
                            Data.subPrismWalls![index]["wallpaper_thumb"],
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
