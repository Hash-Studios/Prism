import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/home/wallpapers/wallpaperGrid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as Data;
import 'package:provider/provider.dart';

class WallpaperTile extends StatelessWidget {
  const WallpaperTile({
    Key key,
    @required this.widget,
    @required this.index,
  }) : super(key: key);

  final WallpaperGrid widget;
  final int index;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (Data.subPrismWalls == []) {
        } else {
          Navigator.pushNamed(
            context,
            wallpaperRoute,
            arguments: [
              widget.provider,
              index,
              Data.subPrismWalls[index]["wallpaper_thumb"],
            ],
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Container(
          decoration: Data.subPrismWalls.isEmpty
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
                      Data.subPrismWalls[index]["wallpaper_thumb"].toString(),
                    ),
                    fit: BoxFit.cover,
                  )),
        ),
      ),
    );
  }
}
