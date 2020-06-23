import 'package:Prism/data/pexels/provider/pexels.dart';
import 'package:Prism/data/wallhaven/provider/wallhaven.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:optimized_cached_image/widgets.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';

class WallpaperScreenP extends StatefulWidget {
  final List arguements;
  WallpaperScreenP({@required this.arguements});
  @override
  _WallpaperScreenPState createState() => _WallpaperScreenPState();
}

class _WallpaperScreenPState extends State<WallpaperScreenP> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int index;
  String link;

  bool isLoading = true;
  PaletteGenerator paletteGenerator;
  List<Color> colors;

  Future<void> _updatePaletteGenerator() async {
    setState(() {
      isLoading = true;
    });
    paletteGenerator = await PaletteGenerator.fromImageProvider(
      new NetworkImage(link),
      maximumColorCount: 20,
    );
    setState(() {
      isLoading = false;
    });
    colors = paletteGenerator.colors.toList();
    if (paletteGenerator.colors.length > 5) {
      colors = colors.sublist(0, 5);
    }
  }

  @override
  void initState() {
    super.initState();
    index = widget.arguements[0];
    link = widget.arguements[1];
    isLoading = true;
    _updatePaletteGenerator();
  }

  void _showBottomSheetCallback() {
    _scaffoldKey.currentState.showBottomSheet<void>(
      (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Color(0xFF2F2F2F),
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * .42,
            width: MediaQuery.of(context).size.width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Icon(
                        JamIcons.chevron_down,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      colors.length,
                      (color) {
                        return Container(
                          decoration: BoxDecoration(
                            color: colors[color],
                            borderRadius: BorderRadius.circular(500),
                          ),
                          height: MediaQuery.of(context).size.width / 8,
                          width: MediaQuery.of(context).size.width / 8,
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(35, 0, 35, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 5, 0, 10),
                              child: Container(
                                width: MediaQuery.of(context).size.width * .4,
                                child: Text(
                                  Provider.of<PexelsProvider>(context,
                                              listen: false)
                                          .wallsP[index]
                                          .url
                                          .toString()
                                          .replaceAll(
                                              "https://www.pexels.com/photo/",
                                              "")
                                          .replaceAll("-", " ")
                                          .replaceAll("/", "")[0]
                                          .toUpperCase() +
                                      Provider.of<PexelsProvider>(context,
                                              listen: false)
                                          .wallsP[index]
                                          .url
                                          .toString()
                                          .replaceAll(
                                              "https://www.pexels.com/photo/",
                                              "")
                                          .replaceAll("-", " ")
                                          .replaceAll("/", "")
                                          .substring(
                                              1,
                                              Provider.of<PexelsProvider>(
                                                          context,
                                                          listen: false)
                                                      .wallsP[index]
                                                      .url
                                                      .toString()
                                                      .replaceAll(
                                                          "https://www.pexels.com/photo/",
                                                          "")
                                                      .replaceAll("-", " ")
                                                      .replaceAll("/", "")
                                                      .length -
                                                  8),
                                  style: Theme.of(context).textTheme.bodyText1,
                                ),
                              ),
                            ),
                            Text(
                              "${Provider.of<PexelsProvider>(context, listen: false).wallsP[index].width.toString()}x${Provider.of<PexelsProvider>(context, listen: false).wallsP[index].height.toString()}",
                              style: Theme.of(context).textTheme.bodyText2,
                            ),
                          ],
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Container(
                              width: MediaQuery.of(context).size.width * .4,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(0, 5, 0, 10),
                                child: Text(
                                  Provider.of<PexelsProvider>(context,
                                          listen: false)
                                      .wallsP[index]
                                      .photographer
                                      .toString(),
                                  textAlign: TextAlign.end,
                                  style: Theme.of(context).textTheme.bodyText1,
                                ),
                              ),
                            ),
                            Text(
                              Provider.of<PexelsProvider>(context,
                                      listen: false)
                                  .wallsP[index]
                                  .id
                                  .toString(),
                              style: Theme.of(context).textTheme.bodyText2,
                            ),
                            // Text(
                            //   "${double.parse(((double.parse(Provider.of<PexelsProvider>(context, listen: false).walls[index].file_size.toString()) / 1000000).toString())).toStringAsFixed(2)} MB",
                            //   style: Theme.of(context).textTheme.bodyText2,
                            // ),
                            Text(
                              "All Rights Reserved",
                              style: Theme.of(context).textTheme.bodyText2,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      GestureDetector(
                        onTap: () {
                          print("Download");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(.25),
                                  blurRadius: 4,
                                  offset: Offset(0, 4))
                            ],
                            borderRadius: BorderRadius.circular(500),
                          ),
                          padding: EdgeInsets.all(17),
                          child: Icon(
                            JamIcons.download,
                            color: Theme.of(context).accentColor,
                            size: 30,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          print("Wallpaper");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(.25),
                                  blurRadius: 4,
                                  offset: Offset(0, 4))
                            ],
                            borderRadius: BorderRadius.circular(500),
                          ),
                          padding: EdgeInsets.all(17),
                          child: Icon(
                            JamIcons.layers,
                            color: Theme.of(context).accentColor,
                            size: 30,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          print("Fav");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(.25),
                                  blurRadius: 4,
                                  offset: Offset(0, 4))
                            ],
                            borderRadius: BorderRadius.circular(500),
                          ),
                          padding: EdgeInsets.all(17),
                          child: Icon(
                            JamIcons.heart,
                            color: Theme.of(context).accentColor,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Stack(
        children: <Widget>[
          OptimizedCacheImage(
            imageUrl: Provider.of<PexelsProvider>(context)
                .wallsP[index]
                .src["portrait"],
            imageBuilder: (context, imageProvider) => Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            placeholder: (context, url) => Container(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(
                    Colors.white,
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              child: Center(
                child: Icon(
                  JamIcons.close_circle_f,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              child: Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    color: Color(0xFF2F2F2F)),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height / 20,
                  child: Center(
                    child: Icon(
                      JamIcons.chevron_up,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              onTap: !isLoading ? _showBottomSheetCallback : () {},
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                color: Colors.white,
                icon: Icon(
                  JamIcons.chevron_left,
                ),
              ),
            ),
          )
        ],
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
