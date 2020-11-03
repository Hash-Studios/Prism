import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/ui/widgets/home/wallpapers/wallhavenGrid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart'
    as wData;

class WallhavenTile extends StatelessWidget {
  const WallhavenTile({
    Key key,
    @required this.widget,
    @required this.animation,
    @required this.index,
  }) : super(key: key);

  final WallHavenGrid widget;
  final Animation<Color> animation;
  final int index;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (wData.walls == []) {
        } else {
          Navigator.pushNamed(context, wallpaperRoute, arguments: [
            widget.provider,
            index,
            wData.walls[index].thumbs["small"].toString(),
          ]);
        }
      },
      child: Container(
        decoration: wData.walls.isEmpty
            ? BoxDecoration(
                color: animation.value,
                borderRadius: BorderRadius.circular(20),
              )
            : BoxDecoration(
                color: animation.value,
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(
                    image: CachedNetworkImageProvider(
                      wData.walls[index].thumbs["original"].toString(),
                    ),
                    fit: BoxFit.cover),
              ),
      ),
    );
  }
}
