import 'package:flutter/material.dart';
import 'package:prism/model/wallhaven/wallhaven_wall_model.dart';
import 'package:prism/widgets/basic/wallpaper_card.dart';

class WallHavenWallCard extends WallpaperCard {
  const WallHavenWallCard({
    Key? key,
    required this.wallpaper,
  }) : super(key: key, wallpaper: wallpaper);

  final WallHavenWall wallpaper;
}
