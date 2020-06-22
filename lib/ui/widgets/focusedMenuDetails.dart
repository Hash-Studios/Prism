import 'dart:ui';
import 'package:Prism/data/wallhaven/provider/wallhaven.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FocusedMenuDetails extends StatelessWidget {
  final Offset childOffset;
  final Size childSize;
  final int index;

  final Widget child;

  const FocusedMenuDetails({
    Key key,
    @required this.childOffset,
    @required this.childSize,
    @required this.child,
    @required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    final maxMenuWidth = size.width * 0.63;
    final menuHeight = size.height * 0.14;
    final leftOffset = (childOffset.dx + maxMenuWidth) < size.width
        ? MediaQuery.of(context).orientation == Orientation.portrait
            ? childOffset.dx + childSize.width + size.width * 0.015
            : childOffset.dx + childSize.width + size.width * 0.01
        : MediaQuery.of(context).orientation == Orientation.portrait
            ? (childOffset.dx - maxMenuWidth + childSize.width)
            : (childOffset.dx -
                maxMenuWidth +
                childSize.width +
                size.width * 0.3);
    final topOffset =
        (childOffset.dy + menuHeight + childSize.height) < size.height
            ? MediaQuery.of(context).orientation == Orientation.portrait
                ? childOffset.dy + childSize.height + size.width * 0.015
                : childOffset.dy + childSize.height + size.width * 0.015
            : MediaQuery.of(context).orientation == Orientation.portrait
                ? childOffset.dy - menuHeight + size.width * 0.125
                : childOffset.dy - menuHeight;

    final fabHeartTopOffset =
        (childOffset.dy + menuHeight + childSize.height) < size.height
            ? MediaQuery.of(context).orientation == Orientation.portrait
                ? size.width * 0.175
                : size.width * 0.1
            : MediaQuery.of(context).orientation == Orientation.portrait
                ? -size.width * 0.175
                : -size.width * 0.1;
    final fabWallLeftOffset = (childOffset.dx + maxMenuWidth) < size.width
        ? MediaQuery.of(context).orientation == Orientation.portrait
            ? -size.width * 0.175
            : -size.width * 0.1
        : MediaQuery.of(context).orientation == Orientation.portrait
            ? size.width * 0.175
            : size.width * 0.1;

    final fabWallTopOffset =
        (childOffset.dy + menuHeight + childSize.height) < size.height
            ? MediaQuery.of(context).orientation == Orientation.portrait
                ? size.width * 0.05
                : size.width * 0.02
            : MediaQuery.of(context).orientation == Orientation.portrait
                ? -size.width * 0.05
                : -size.width * 0.02;
    final fabHeartLeftOffset = (childOffset.dx + maxMenuWidth) < size.width
        ? MediaQuery.of(context).orientation == Orientation.portrait
            ? -size.width * 0.05
            : -size.width * 0.02
        : MediaQuery.of(context).orientation == Orientation.portrait
            ? size.width * 0.05
            : size.width * 0.02;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                  child: Container(
                    color: ThemeModel().returnTheme() == ThemeType.Dark
                        ? Colors.black.withOpacity(0.75)
                        : Colors.white.withOpacity(0.75),
                  ),
                )),
            Positioned(
                top: childOffset.dy,
                left: childOffset.dx,
                child: AbsorbPointer(
                    absorbing: true,
                    child: Container(
                        width: childSize.width,
                        height: childSize.height,
                        child: child))),
            Positioned(
              top: childOffset.dy + childSize.height * 2 / 8,
              left: childOffset.dx,
              child: TweenAnimationBuilder(
                duration: Duration(milliseconds: 200),
                builder: (BuildContext context, value, Widget child) {
                  return Transform.scale(
                    scale: value,
                    alignment: Alignment.bottomRight,
                    child: child,
                  );
                },
                tween: Tween(begin: 0.0, end: 1.0),
                child: Container(
                  width: childSize.width,
                  height: childSize.height * 6 / 8,
                  decoration: BoxDecoration(
                    color: Color(0xFF2F2F2F),
                    borderRadius: const BorderRadius.all(Radius.circular(20.0)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(20.0)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(15, 7, 15, 15),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              ActionChip(
                                  pressElevation: 5,
                                  padding: EdgeInsets.fromLTRB(14, 11, 14, 11),
                                  backgroundColor: HexColor(
                                      Provider.of<WallHavenProvider>(context,
                                                  listen: false)
                                              .walls[index]
                                              .colors[
                                          Provider.of<WallHavenProvider>(
                                                      context,
                                                      listen: false)
                                                  .walls[index]
                                                  .colors
                                                  .length -
                                              1]),
                                  label: Text(
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .headline4
                                        .copyWith(
                                          color: HexColor(Provider.of<
                                                                  WallHavenProvider>(
                                                              context,
                                                              listen: false)
                                                          .walls[index]
                                                          .colors[Provider.of<
                                                                      WallHavenProvider>(
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
                                  onPressed: () {}),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0, 5, 0, 10),
                                child: Text(
                                  Provider.of<WallHavenProvider>(context,
                                          listen: false)
                                      .walls[index]
                                      .id
                                      .toString(),
                                  style: Theme.of(context).textTheme.headline5,
                                ),
                              ),
                              Text(
                                "${Provider.of<WallHavenProvider>(context, listen: false).walls[index].views.toString()} views",
                                style: Theme.of(context).textTheme.headline6,
                              ),
                              Text(
                                "${Provider.of<WallHavenProvider>(context, listen: false).walls[index].favorites.toString()} favs",
                                style: Theme.of(context).textTheme.headline6,
                              ),
                              Text(
                                Provider.of<WallHavenProvider>(context,
                                        listen: false)
                                    .walls[index]
                                    .short_url
                                    .toString()
                                    .replaceAll("https://", ""),
                                style: Theme.of(context).textTheme.headline6,
                              ),
                            ],
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: GestureDetector(
                            child: Container(
                              decoration: BoxDecoration(
                                  color: Color(0xFF2F2F2F),
                                  borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      bottomRight: Radius.circular(20))),
                              padding: EdgeInsets.all(0),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                                child: Icon(
                                  JamIcons.close,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                            },
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: topOffset,
              left: leftOffset,
              child: GestureDetector(
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
            ),
            Positioned(
              top: topOffset - fabHeartTopOffset,
              left: leftOffset - fabHeartLeftOffset,
              child: GestureDetector(
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
            ),
            Positioned(
              top: topOffset + fabWallTopOffset,
              left: leftOffset + fabWallLeftOffset,
              child: GestureDetector(
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
            ),
          ],
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
