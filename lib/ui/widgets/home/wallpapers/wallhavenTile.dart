import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/home/wallpapers/wallhavenGrid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart'
    as wData;
import 'package:provider/provider.dart';

class WallhavenTile extends StatelessWidget {
  const WallhavenTile({
    Key key,
    @required this.widget,
    @required this.index,
  }) : super(key: key);

  final WallHavenGrid widget;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: wData.walls.isEmpty
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
                        wData.walls[index].thumbs["original"].toString(),
                      ),
                      fit: BoxFit.cover),
                ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              splashColor: Theme.of(context).accentColor.withOpacity(0.3),
              highlightColor: Theme.of(context).accentColor.withOpacity(0.1),
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
            ),
          ),
        ),
      ],
    );
  }
}
