import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:prism/controllers/settings_controller.dart';
import 'package:prism/model/settings/wall_thumb_quality.dart';
import 'package:prism/model/wallhaven/wallhaven_wall_model.dart';
import 'package:prism/widgets/basic/wallpaper_immersive_card.dart';
import 'package:provider/provider.dart';

class WallHavenImmersiveWallCard extends WallpaperImmersiveCard {
  const WallHavenImmersiveWallCard({
    Key? key,
    required this.wallpaper,
  }) : super(key: key, wallpaper: wallpaper);

  final WallHavenWall wallpaper;

  // @override
  // Widget build(BuildContext context) {
  //   final wallpaperUrl = context.watch<SettingsController>().wallThumbQuality ==
  //           WallThumbQuality.high
  //       ? wallpaper?.path
  //       : wallpaper?.thumbs.original;
  //   return Stack(
  //     children: [
  //       Container(
  //         width: double.maxFinite,
  //         height: (wallpaper?.dimensionY ?? 0).toDouble() *
  //             MediaQuery.of(context).size.width /
  //             (wallpaper?.dimensionX ?? 0).toDouble(),
  //         color: Color(int.parse(
  //             'ff' +
  //                 (wallpaper?.colors[0].replaceFirst('#', '') ??
  //                     Theme.of(context)
  //                         .backgroundColor
  //                         .value
  //                         .toRadixString(16)),
  //             radix: 16)),
  //         child: CachedNetworkImage(
  //           imageUrl: wallpaperUrl ?? '',
  //           fit: BoxFit.cover,
  //         ),
  //       ),
  //       Positioned(
  //         bottom: 4,
  //         right: 12,
  //         child: GestureDetector(
  //           child: Container(
  //             color: Colors.transparent,
  //             child: Icon(
  //               Icons.more_horiz,
  //               color: Theme.of(context).colorScheme.secondary,
  //             ),
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }
}
