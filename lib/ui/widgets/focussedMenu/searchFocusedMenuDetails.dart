import 'dart:ui';
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as pdata;
import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart'
    as wdata;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/menuButton/downloadButton.dart';
import 'package:Prism/ui/widgets/menuButton/favWallpaperButton.dart';
import 'package:Prism/ui/widgets/menuButton/setWallpaperButton.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SearchFocusedMenuDetails extends StatelessWidget {
  final String selectedProvider;
  final String query;
  final Offset childOffset;
  final Size childSize;
  final int index;

  final Widget child;

  const SearchFocusedMenuDetails({
    Key key,
    @required this.selectedProvider,
    @required this.query,
    @required this.childOffset,
    @required this.childSize,
    @required this.child,
    @required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

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
    try {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  color: Provider.of<ThemeModel>(context, listen: false)
                              .returnThemeType() ==
                          "Dark"
                      ? Colors.black.withOpacity(0.75)
                      : Colors.white.withOpacity(0.75),
                )),
            Positioned(
                top: childOffset.dy,
                left: childOffset.dx,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: AbsorbPointer(
                      child: Container(
                          width: childSize.width,
                          height: childSize.height,
                          child: child)),
                )),
            if (selectedProvider == "WallHaven")
              Positioned(
                top: childOffset.dy + childSize.height * 2 / 8,
                left: childOffset.dx,
                child: TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 200),
                  builder: (BuildContext context, double value, Widget child) {
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
                      color: Theme.of(context).hintColor,
                      borderRadius:
                          const BorderRadius.all(Radius.circular(20.0)),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.all(Radius.circular(20.0)),
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
                                    padding: const EdgeInsets.fromLTRB(
                                        14, 11, 14, 11),
                                    avatar: Icon(JamIcons.ordered_list,
                                        color: HexColor(wdata
                                                        .wallsS[index]
                                                        .colors[wdata
                                                                .wallsS[index]
                                                                .colors
                                                                .length -
                                                            1]
                                                        .toString())
                                                    .computeLuminance() >
                                                0.5
                                            ? Colors.black
                                            : Colors.white,
                                        size: 20),
                                    backgroundColor: HexColor(wdata
                                        .wallsS[index]
                                        .colors[wdata.wallsS[index].colors.length - 1]
                                        .toString()),
                                    label: Text(
                                      wdata.wallsS[index].category
                                              .toString()[0]
                                              .toUpperCase() +
                                          wdata.wallsS[index].category
                                              .toString()
                                              .substring(1),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headline4
                                          .copyWith(
                                            color: HexColor(wdata
                                                            .wallsS[index]
                                                            .colors[wdata
                                                                    .wallsS[
                                                                        index]
                                                                    .colors
                                                                    .length -
                                                                1]
                                                            .toString())
                                                        .computeLuminance() >
                                                    0.5
                                                ? Colors.black
                                                : Colors.white,
                                          ),
                                    ),
                                    onPressed: () {}),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(0, 5, 0, 10),
                                  child: Text(
                                    wdata.wallsS[index].id
                                        .toString()
                                        .toUpperCase(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headline5
                                        .copyWith(
                                            color:
                                                Theme.of(context).accentColor),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      JamIcons.eye,
                                      size: 20,
                                      color: Theme.of(context).accentColor,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      "Views: ${wdata.wallsS[index].views.toString()}",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyText2
                                          .copyWith(
                                              color: Theme.of(context)
                                                  .accentColor),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      JamIcons.set_square,
                                      size: 20,
                                      color: Theme.of(context).accentColor,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      wdata.wallsS[index].resolution,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyText2
                                          .copyWith(
                                              color: Theme.of(context)
                                                  .accentColor),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: GestureDetector(
                              onTap: () async {
                                Navigator.pop(context);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                    color: Theme.of(context).hintColor,
                                    borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(20),
                                        bottomRight: Radius.circular(20))),
                                padding: const EdgeInsets.all(0),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(10, 5, 10, 5),
                                  child: Icon(
                                    JamIcons.close,
                                    color: Theme.of(context).accentColor,
                                  ),
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              Positioned(
                top: childOffset.dy + childSize.height * 4 / 10,
                left: childOffset.dx,
                child: TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 200),
                  builder: (BuildContext context, double value, Widget child) {
                    return Transform.scale(
                      scale: value,
                      alignment: Alignment.bottomRight,
                      child: child,
                    );
                  },
                  tween: Tween(begin: 0.0, end: 1.0),
                  child: Container(
                    width: childSize.width,
                    height: childSize.height * 6 / 10,
                    decoration: BoxDecoration(
                      color: Theme.of(context).hintColor,
                      borderRadius:
                          const BorderRadius.all(Radius.circular(20.0)),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.all(Radius.circular(20.0)),
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
                                    padding: const EdgeInsets.fromLTRB(
                                        14, 11, 14, 11),
                                    backgroundColor: Colors.black,
                                    avatar: const Icon(JamIcons.camera,
                                        color: Colors.white, size: 20),
                                    label: Text(
                                      pdata.wallsPS[index].photographer
                                          .toString(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headline4
                                          .copyWith(
                                            color: Colors.white,
                                          ),
                                    ),
                                    onPressed: () {
                                      launch(pdata.wallsPS[index].url);
                                    }),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(0, 5, 0, 10),
                                  child: Text(
                                    pdata.wallsPS[index].url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "").length > 8
                                        ? pdata.wallsPS[index].url
                                                .toString()
                                                .replaceAll(
                                                    "https://www.pexels.com/photo/", "")
                                                .replaceAll("-", " ")
                                                .replaceAll("/", "")[0]
                                                .toUpperCase() +
                                            pdata.wallsPS[index].url
                                                .toString()
                                                .replaceAll(
                                                    "https://www.pexels.com/photo/", "")
                                                .replaceAll("-", " ")
                                                .replaceAll("/", "")
                                                .substring(
                                                    1,
                                                    pdata.wallsPS[index].url
                                                            .toString()
                                                            .replaceAll(
                                                                "https://www.pexels.com/photo/", "")
                                                            .replaceAll(
                                                                "-", " ")
                                                            .replaceAll("/", "")
                                                            .length -
                                                        7)
                                        : pdata.wallsPS[index].url
                                                .toString()
                                                .replaceAll(
                                                    "https://www.pexels.com/photo/", "")
                                                .replaceAll("-", " ")
                                                .replaceAll("/", "")[0]
                                                .toUpperCase() +
                                            pdata.wallsPS[index].url
                                                .toString()
                                                .replaceAll(
                                                    "https://www.pexels.com/photo/",
                                                    "")
                                                .replaceAll("-", " ")
                                                .replaceAll("/", "")
                                                .substring(1),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headline5
                                        .copyWith(
                                            color:
                                                Theme.of(context).accentColor),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      JamIcons.set_square,
                                      color: Theme.of(context).accentColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      "${pdata.wallsPS[index].width.toString()}x${pdata.wallsPS[index].height.toString()}",
                                      style: Theme.of(context)
                                          .textTheme
                                          .headline6
                                          .copyWith(
                                              color: Theme.of(context)
                                                  .accentColor),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: GestureDetector(
                              onTap: () async {
                                Navigator.pop(context);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                    color: Theme.of(context).hintColor,
                                    borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(20),
                                        bottomRight: Radius.circular(20))),
                                padding: const EdgeInsets.all(0),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(10, 5, 10, 5),
                                  child: Icon(
                                    JamIcons.close,
                                    color: Theme.of(context).accentColor,
                                  ),
                                ),
                              ),
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
              child: SetWallpaperButton(
                colorChanged: false,
                url: selectedProvider == "WallHaven"
                    ? wdata.wallsS[index].path.toString()
                    : pdata.wallsPS[index].src["original"].toString(),
              ),
            ),
            Positioned(
              top: topOffset - fabHeartTopOffset,
              left: leftOffset - fabHeartLeftOffset,
              child: selectedProvider == "WallHaven"
                  ? FavouriteWallpaperButton(
                      id: wdata.wallsS[index].id.toString(),
                      provider: "WallHaven",
                      wallhaven: wdata.wallsS[index],
                      trash: false,
                    )
                  : FavouriteWallpaperButton(
                      id: pdata.wallsPS[index].id.toString(),
                      provider: "Pexels",
                      pexels: pdata.wallsPS[index],
                      trash: false,
                    ),
            ),
            Positioned(
              top: topOffset + fabWallTopOffset,
              left: leftOffset + fabWallLeftOffset,
              child: DownloadButton(
                colorChanged: false,
                link: selectedProvider == "WallHaven"
                    ? wdata.wallsS[index].path.toString()
                    : pdata.wallsPS[index].src["original"].toString(),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint(e.toString());
      Navigator.pop(context);
      return Container();
    }
  }
}

class HexColor extends Color {
  static int _getColorFromHex(String hexColor) {
    final String heColor = hexColor.toUpperCase().replaceAll("#", "");
    String hColor;
    if (heColor.length == 6) {
      hColor = "FF$heColor";
    }
    return int.parse(hColor, radix: 16);
  }

  HexColor(final String hColor) : super(_getColorFromHex(hColor));
}
