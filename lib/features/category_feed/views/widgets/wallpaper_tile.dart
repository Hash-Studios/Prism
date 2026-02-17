import 'package:auto_route/auto_route.dart';
import 'dart:developer';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as Data;
import 'package:Prism/features/category_feed/views/widgets/wallpaper_grid.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
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
    final List<dynamic> walls = Data.subPrismWalls?.cast<dynamic>() ?? <dynamic>[];
    final bool hasWall = index >= 0 && index < walls.length;
    Map<String, dynamic>? wallData;
    if (hasWall) {
      final dynamic wall = walls[index];
      if (wall is Map<String, dynamic>) {
        wallData = wall;
      } else if (wall is Map) {
        wallData = wall.cast<String, dynamic>();
      }
    }

    return Stack(
      children: [
        Container(
          decoration: !hasWall || wallData == null
              ? BoxDecoration(
                  color: context.prismModeStyleForContext() == "Dark"
                      ? Colors.white10
                      : Colors.black.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(20),
                )
              : BoxDecoration(
                  color: context.prismModeStyleForContext() == "Dark"
                      ? Colors.white10
                      : Colors.black.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(
                      wallData["wallpaper_thumb"].toString(),
                    ),
                    fit: BoxFit.cover,
                  )),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              splashColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
              highlightColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
              onTap: () {
                if (!hasWall || wallData == null) {
                  return;
                }
                final List<dynamic> collections = wallData["collections"] as List? ?? <dynamic>[];
                log((globals.isPremiumWall(globals.premiumCollections, collections) == true).toString());
                log(globals.prismUser.premium.toString());
                globals.isPremiumWall(globals.premiumCollections, collections) == true &&
                        globals.prismUser.premium != true
                    ? showGooglePopUp(context, () {
                        context.router.push(const UpgradeRoute());
                      })
                    : context.router.push(WallpaperRoute(arguments: [
                          widget.provider,
                          index,
                          wallData["wallpaper_thumb"],
                        ]));
              },
            ),
          ),
        ),
      ],
    );
  }
}
