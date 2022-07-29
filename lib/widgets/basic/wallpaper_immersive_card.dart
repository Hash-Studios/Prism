import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:prism/controllers/settings_controller.dart';
import 'package:prism/model/settings/wall_thumb_quality.dart';
import 'package:prism/model/wallpaper/model.dart';
import 'package:provider/provider.dart';

class WallpaperImmersiveCard extends StatelessWidget {
  const WallpaperImmersiveCard({
    Key? key,
    required this.wallpaper,
  }) : super(key: key);

  final Wallpaper wallpaper;

  @override
  Widget build(BuildContext context) {
    final wallpaperUrl = context.watch<SettingsController>().wallThumbQuality ==
            WallThumbQuality.high
        ? wallpaper.wallpaper_url
        : wallpaper.wallpaper_thumb;
    return Stack(
      children: [
        SizedBox(
          width: double.maxFinite,
          height: double.parse(
                  wallpaper.resolution?.split("x")[1].toString() ?? "0") *
              MediaQuery.of(context).size.width /
              double.parse(
                  wallpaper.resolution?.split("x")[0].toString() ?? "0"),
          child: CachedNetworkImage(
            imageUrl: wallpaperUrl,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          bottom: 4,
          right: 12,
          child: GestureDetector(
            child: Container(
              color: Colors.transparent,
              child: Icon(
                Icons.more_horiz,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
