import 'package:Prism/data/wallhaven/provider/wallhaven.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:optimized_cached_image/widgets.dart';
import 'package:provider/provider.dart';

class WallpaperScreen extends StatefulWidget {
  final List arguements;
  WallpaperScreen({@required this.arguements});
  @override
  _WallpaperScreenState createState() => _WallpaperScreenState();
}

class _WallpaperScreenState extends State<WallpaperScreen> {
  int index;

  @override
  void initState() {
    super.initState();
    index = widget.arguements[0];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OptimizedCacheImage(
        imageUrl: Provider.of<WallHavenProvider>(context).walls[index].path,
        imageBuilder: (context, imageProvider) => Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: imageProvider,
              fit: BoxFit.cover,
            ),
          ),
        ),
        placeholder: (context, url) => Container(
          color: HexColor(Provider.of<WallHavenProvider>(context, listen: false)
              .walls[index]
              .colors[Provider.of<WallHavenProvider>(context, listen: false)
                  .walls[index]
                  .colors
                  .length -
              2]),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(
                HexColor(Provider.of<WallHavenProvider>(context, listen: false)
                                .walls[index]
                                .colors[Provider.of<WallHavenProvider>(context,
                                        listen: false)
                                    .walls[index]
                                    .colors
                                    .length -
                                1])
                            .computeLuminance() >
                        0.5
                    ? Colors.black
                    : Colors.white,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: HexColor(Provider.of<WallHavenProvider>(context, listen: false)
              .walls[index]
              .colors[Provider.of<WallHavenProvider>(context, listen: false)
                  .walls[index]
                  .colors
                  .length -
              2]),
          child: Center(
            child: Icon(
              JamIcons.close_circle_f,
              color: HexColor(Provider.of<WallHavenProvider>(context,
                                  listen: false)
                              .walls[index]
                              .colors[Provider.of<WallHavenProvider>(context,
                                      listen: false)
                                  .walls[index]
                                  .colors
                                  .length -
                              1])
                          .computeLuminance() >
                      0.5
                  ? Colors.black
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class HexColor extends Color {
  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF" + hexColor;
    }
    return int.parse(hexColor, radix: 16);
  }

  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));
}
