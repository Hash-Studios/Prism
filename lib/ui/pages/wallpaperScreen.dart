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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int index;

  @override
  void initState() {
    super.initState();
    index = widget.arguements[0];
  }

  void _showBottomSheetCallback() {
    _scaffoldKey.currentState.showBottomSheet<void>(
      (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Color(0xFF2F2F2F),
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * .4,
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
                      Provider.of<WallHavenProvider>(context, listen: false)
                          .walls[index]
                          .colors
                          .length,
                      (color) {
                        return Container(
                          decoration: BoxDecoration(
                            color: HexColor(Provider.of<WallHavenProvider>(
                                    context,
                                    listen: false)
                                .walls[index]
                                .colors[color]),
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
                              child: Text(
                                Provider.of<WallHavenProvider>(context,
                                        listen: false)
                                    .walls[index]
                                    .id
                                    .toString(),
                                style: Theme.of(context).textTheme.bodyText1,
                              ),
                            ),
                            Text(
                              "${Provider.of<WallHavenProvider>(context, listen: false).walls[index].views.toString()} views",
                              style: Theme.of(context).textTheme.bodyText2,
                            ),
                            Text(
                              "${Provider.of<WallHavenProvider>(context, listen: false).walls[index].favorites.toString()} favs",
                              style: Theme.of(context).textTheme.bodyText2,
                            ),
                            Text(
                              Provider.of<WallHavenProvider>(context,
                                      listen: false)
                                  .walls[index]
                                  .short_url
                                  .toString()
                                  .replaceAll("https://", ""),
                              style: Theme.of(context).textTheme.bodyText2,
                            ),
                          ],
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 5, 0, 10),
                              child: Text(
                                Provider.of<WallHavenProvider>(context,
                                            listen: false)
                                        .walls[index]
                                        .category
                                        .toString()[0]
                                        .toUpperCase() +
                                    Provider.of<WallHavenProvider>(context,
                                            listen: false)
                                        .walls[index]
                                        .category
                                        .toString()
                                        .substring(1),
                                style: Theme.of(context).textTheme.bodyText1,
                              ),
                            ),
                            Text(
                              "${Provider.of<WallHavenProvider>(context, listen: false).walls[index].resolution.toString()}",
                              style: Theme.of(context).textTheme.bodyText2,
                            ),
                            Text(
                              "${double.parse(((double.parse(Provider.of<WallHavenProvider>(context, listen: false).walls[index].file_size.toString()) / 1000000).toString())).toStringAsFixed(2)} MB",
                              style: Theme.of(context).textTheme.bodyText2,
                            ),
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
              color: HexColor(
                  Provider.of<WallHavenProvider>(context, listen: false)
                          .walls[index]
                          .colors[
                      Provider.of<WallHavenProvider>(context, listen: false)
                              .walls[index]
                              .colors
                              .length -
                          2]),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(
                    HexColor(Provider.of<WallHavenProvider>(context,
                                        listen: false)
                                    .walls[index]
                                    .colors[Provider.of<WallHavenProvider>(
                                            context,
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
              color: HexColor(
                  Provider.of<WallHavenProvider>(context, listen: false)
                          .walls[index]
                          .colors[
                      Provider.of<WallHavenProvider>(context, listen: false)
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
                                  .colors[Provider.of<WallHavenProvider>(
                                          context,
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
              onTap: _showBottomSheetCallback,
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
