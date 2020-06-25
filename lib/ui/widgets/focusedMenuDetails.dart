import 'dart:ui';
import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/data/pexels/provider/pexels.dart';
import 'package:Prism/data/wallhaven/provider/wallhaven.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/downloadButton.dart';
import 'package:Prism/ui/widgets/favWallpaperButton.dart';
import 'package:Prism/ui/widgets/setWallpaperButton.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FocusedMenuDetails extends StatelessWidget {
  final String provider;
  final Offset childOffset;
  final Size childSize;
  final int index;

  final Widget child;

  const FocusedMenuDetails({
    Key key,
    @required this.provider,
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
                      color: Provider.of<ThemeModel>(context, listen: false)
                                  .returnTheme() ==
                              ThemeType.Dark
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
              provider == "WallHaven"
                  ? Positioned(
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
                                  padding:
                                      const EdgeInsets.fromLTRB(15, 7, 15, 15),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      ActionChip(
                                          pressElevation: 5,
                                          padding: EdgeInsets.fromLTRB(
                                              14, 11, 14, 11),
                                          avatar: Icon(
                                            JamIcons.ordered_list,
                                            color: HexColor(Provider.of<
                                                                    WallHavenProvider>(
                                                                context,
                                                                listen: false)
                                                            .walls[index]
                                                            .colors[Provider.of<
                                                                        WallHavenProvider>(
                                                                    context,
                                                                    listen:
                                                                        false)
                                                                .walls[index]
                                                                .colors
                                                                .length -
                                                            1])
                                                        .computeLuminance() >
                                                    0.5
                                                ? Colors.black
                                                : Colors.white,
                                            size: 20,
                                          ),
                                          backgroundColor: HexColor(Provider.of<
                                                          WallHavenProvider>(
                                                      context,
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
                                            Provider.of<WallHavenProvider>(
                                                        context,
                                                        listen: false)
                                                    .walls[index]
                                                    .category
                                                    .toString()[0]
                                                    .toUpperCase() +
                                                Provider.of<WallHavenProvider>(
                                                        context,
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
                                                                      listen:
                                                                          false)
                                                                  .walls[index]
                                                                  .colors[Provider.of<
                                                                              WallHavenProvider>(
                                                                          context,
                                                                          listen:
                                                                              false)
                                                                      .walls[
                                                                          index]
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
                                        padding: const EdgeInsets.fromLTRB(
                                            0, 5, 0, 10),
                                        child: Text(
                                          Provider.of<WallHavenProvider>(
                                                  context,
                                                  listen: false)
                                              .walls[index]
                                              .id
                                              .toString()
                                              .toUpperCase(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .headline5,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            JamIcons.eye,
                                            size: 20,
                                            color: Colors.white70,
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            "Views: ${Provider.of<WallHavenProvider>(context, listen: false).walls[index].views.toString()}",
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyText2,
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            JamIcons.set_square,
                                            size: 20,
                                            color: Colors.white70,
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            "${Provider.of<WallHavenProvider>(context, listen: false).walls[index].resolution.toString()}",
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyText2,
                                          ),
                                        ],
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
                                              bottomRight:
                                                  Radius.circular(20))),
                                      padding: EdgeInsets.all(0),
                                      child: Padding(
                                        padding:
                                            EdgeInsets.fromLTRB(10, 5, 10, 5),
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
                    )
                  : provider == "Pexels"
                      ? Positioned(
                          top: childOffset.dy + childSize.height * 2 / 8,
                          left: childOffset.dx,
                          child: TweenAnimationBuilder(
                            duration: Duration(milliseconds: 200),
                            builder:
                                (BuildContext context, value, Widget child) {
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
                                borderRadius: const BorderRadius.all(
                                    Radius.circular(20.0)),
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.all(
                                    Radius.circular(20.0)),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: <Widget>[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          15, 7, 15, 15),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          ActionChip(
                                              pressElevation: 5,
                                              padding: EdgeInsets.fromLTRB(
                                                  14, 11, 14, 11),
                                              backgroundColor: Colors.black,
                                              avatar: Icon(JamIcons.camera,
                                                  color: Colors.white,
                                                  size: 20),
                                              label: Text(
                                                Provider.of<PexelsProvider>(
                                                        context,
                                                        listen: false)
                                                    .wallsP[index]
                                                    .photographer
                                                    .toString(),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headline4
                                                    .copyWith(
                                                      color: Colors.white,
                                                    ),
                                              ),
                                              onPressed: () {}),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                0, 5, 0, 10),
                                            child: Text(
                                              Provider.of<PexelsProvider>(context, listen: false)
                                                          .wallsP[index]
                                                          .url
                                                          .toString()
                                                          .replaceAll(
                                                              "https://www.pexels.com/photo/", "")
                                                          .replaceAll("-", " ")
                                                          .replaceAll("/", "")
                                                          .length >
                                                      8
                                                  ? Provider.of<PexelsProvider>(context, listen: false)
                                                          .wallsP[index]
                                                          .url
                                                          .toString()
                                                          .replaceAll(
                                                              "https://www.pexels.com/photo/", "")
                                                          .replaceAll("-", " ")
                                                          .replaceAll(
                                                              "/", "")[0]
                                                          .toUpperCase() +
                                                      Provider.of<PexelsProvider>(context, listen: false)
                                                          .wallsP[index]
                                                          .url
                                                          .toString()
                                                          .replaceAll(
                                                              "https://www.pexels.com/photo/", "")
                                                          .replaceAll("-", " ")
                                                          .replaceAll("/", "")
                                                          .substring(
                                                              1,
                                                              Provider.of<PexelsProvider>(context, listen: false)
                                                                      .wallsP[index]
                                                                      .url
                                                                      .toString()
                                                                      .replaceAll("https://www.pexels.com/photo/", "")
                                                                      .replaceAll("-", " ")
                                                                      .replaceAll("/", "")
                                                                      .length -
                                                                  7)
                                                  : Provider.of<PexelsProvider>(context, listen: false).wallsP[index].url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "")[0].toUpperCase() + Provider.of<PexelsProvider>(context, listen: false).wallsP[index].url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "").substring(1),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headline5,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Icon(
                                                JamIcons.set_square,
                                                color: Colors.white70,
                                                size: 20,
                                              ),
                                              SizedBox(width: 5),
                                              Text(
                                                "${Provider.of<PexelsProvider>(context, listen: false).wallsP[index].width.toString()}x${Provider.of<PexelsProvider>(context, listen: false).wallsP[index].height.toString()}",
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headline6,
                                              ),
                                            ],
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
                                                  bottomRight:
                                                      Radius.circular(20))),
                                          padding: EdgeInsets.all(0),
                                          child: Padding(
                                            padding: EdgeInsets.fromLTRB(
                                                10, 5, 10, 5),
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
                        )
                      : provider == "Liked"
                          ? Provider.of<FavouriteProvider>(context,
                                          listen: false)
                                      .liked[index]["provider"] ==
                                  "WallHaven"
                              ? Positioned(
                                  top:
                                      childOffset.dy + childSize.height * 2 / 8,
                                  left: childOffset.dx,
                                  child: TweenAnimationBuilder(
                                    duration: Duration(milliseconds: 200),
                                    builder: (BuildContext context, value,
                                        Widget child) {
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
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(20.0)),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(20.0)),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: <Widget>[
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      15, 7, 15, 15),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceEvenly,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  ActionChip(
                                                      pressElevation: 5,
                                                      padding:
                                                          EdgeInsets.fromLTRB(
                                                              14, 11, 14, 11),
                                                      avatar: Icon(
                                                        JamIcons.ordered_list,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                      backgroundColor:
                                                          Colors.black,
                                                      label: Text(
                                                        Provider.of<FavouriteProvider>(
                                                                    context,
                                                                    listen:
                                                                        false)
                                                                .liked[index]
                                                                    ["category"]
                                                                .toString()[0]
                                                                .toUpperCase() +
                                                            Provider.of<FavouriteProvider>(
                                                                    context,
                                                                    listen:
                                                                        false)
                                                                .liked[index]
                                                                    ["category"]
                                                                .toString()
                                                                .substring(1),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .headline4
                                                            .copyWith(
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                      ),
                                                      onPressed: () {}),
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .fromLTRB(0, 5, 0, 10),
                                                    child: Text(
                                                      Provider.of<FavouriteProvider>(
                                                              context,
                                                              listen: false)
                                                          .liked[index]["id"]
                                                          .toString()
                                                          .toUpperCase(),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .headline5,
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        JamIcons.eye,
                                                        size: 20,
                                                        color: Colors.white70,
                                                      ),
                                                      SizedBox(width: 10),
                                                      Text(
                                                        "Views: ${Provider.of<FavouriteProvider>(context, listen: false).liked[index]["views"].toString()}",
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyText2,
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        JamIcons.set_square,
                                                        size: 20,
                                                        color: Colors.white70,
                                                      ),
                                                      SizedBox(width: 10),
                                                      Text(
                                                        "${Provider.of<FavouriteProvider>(context, listen: false).liked[index]["resolution"].toString()}",
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyText2,
                                                      ),
                                                    ],
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
                                                      borderRadius:
                                                          BorderRadius.only(
                                                              topLeft: Radius
                                                                  .circular(20),
                                                              bottomRight:
                                                                  Radius
                                                                      .circular(
                                                                          20))),
                                                  padding: EdgeInsets.all(0),
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsets.fromLTRB(
                                                            10, 5, 10, 5),
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
                                )
                              : Provider.of<FavouriteProvider>(context,
                                              listen: false)
                                          .liked[index]["provider"] ==
                                      "Pexels"
                                  ? Positioned(
                                      top: childOffset.dy +
                                          childSize.height * 2 / 8,
                                      left: childOffset.dx,
                                      child: TweenAnimationBuilder(
                                        duration: Duration(milliseconds: 200),
                                        builder: (BuildContext context, value,
                                            Widget child) {
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
                                            borderRadius:
                                                const BorderRadius.all(
                                                    Radius.circular(20.0)),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                const BorderRadius.all(
                                                    Radius.circular(20.0)),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: <Widget>[
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          15, 7, 15, 15),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceEvenly,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: <Widget>[
                                                      ActionChip(
                                                          pressElevation: 5,
                                                          padding: EdgeInsets
                                                              .fromLTRB(14, 11,
                                                                  14, 11),
                                                          backgroundColor:
                                                              Colors.black,
                                                          avatar: Icon(
                                                              JamIcons.camera,
                                                              color:
                                                                  Colors.white,
                                                              size: 20),
                                                          label: Text(
                                                            Provider.of<FavouriteProvider>(
                                                                    context,
                                                                    listen:
                                                                        false)
                                                                .liked[index][
                                                                    "photographer"]
                                                                .toString(),
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .headline4
                                                                .copyWith(
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                          ),
                                                          onPressed: () {}),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                    .fromLTRB(
                                                                0, 5, 0, 10),
                                                        child: Text(
                                                          Provider.of<FavouriteProvider>(context, listen: false).liked[index]["url"].toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "").length > 8
                                                              ? Provider.of<FavouriteProvider>(context, listen: false).liked[index]["url"].toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "")[0].toUpperCase() +
                                                                  Provider.of<FavouriteProvider>(context, listen: false)
                                                                      .liked[index][
                                                                          "url"]
                                                                      .toString()
                                                                      .replaceAll(
                                                                          "https://www.pexels.com/photo/",
                                                                          "")
                                                                      .replaceAll(
                                                                          "-", " ")
                                                                      .replaceAll(
                                                                          "/", "")
                                                                      .substring(
                                                                          1,
                                                                          Provider.of<FavouriteProvider>(context, listen: false).liked[index]["url"].toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "").length -
                                                                              7)
                                                              : Provider.of<FavouriteProvider>(context, listen: false).liked[index]["url"].toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "")[0].toUpperCase() +
                                                                  Provider.of<PexelsProvider>(
                                                                          context,
                                                                          listen: false)
                                                                      .wallsP[index]
                                                                      .url
                                                                      .toString()
                                                                      .replaceAll("https://www.pexels.com/photo/", "")
                                                                      .replaceAll("-", " ")
                                                                      .replaceAll("/", "")
                                                                      .substring(1),
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .headline5,
                                                        ),
                                                      ),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            JamIcons.set_square,
                                                            color:
                                                                Colors.white70,
                                                            size: 20,
                                                          ),
                                                          SizedBox(width: 5),
                                                          Text(
                                                            Provider.of<FavouriteProvider>(
                                                                    context,
                                                                    listen:
                                                                        false)
                                                                .liked[index][
                                                                    "resolution"]
                                                                .toString(),
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .headline6,
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Align(
                                                  alignment:
                                                      Alignment.bottomRight,
                                                  child: GestureDetector(
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                          color:
                                                              Color(0xFF2F2F2F),
                                                          borderRadius:
                                                              BorderRadius.only(
                                                                  topLeft: Radius
                                                                      .circular(
                                                                          20),
                                                                  bottomRight: Radius
                                                                      .circular(
                                                                          20))),
                                                      padding:
                                                          EdgeInsets.all(0),
                                                      child: Padding(
                                                        padding:
                                                            EdgeInsets.fromLTRB(
                                                                10, 5, 10, 5),
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
                                    )
                                  : Positioned(
                                      top: childOffset.dy +
                                          childSize.height * 1 / 2,
                                      left: childOffset.dx,
                                      child: TweenAnimationBuilder(
                                        duration: Duration(milliseconds: 200),
                                        builder: (BuildContext context, value,
                                            Widget child) {
                                          return Transform.scale(
                                            scale: value,
                                            alignment: Alignment.bottomRight,
                                            child: child,
                                          );
                                        },
                                        tween: Tween(begin: 0.0, end: 1.0),
                                        child: Container(
                                          width: childSize.width,
                                          height: childSize.height * 1 / 2,
                                          decoration: BoxDecoration(
                                            color: Color(0xFF2F2F2F),
                                            borderRadius:
                                                const BorderRadius.all(
                                                    Radius.circular(20.0)),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                const BorderRadius.all(
                                                    Radius.circular(20.0)),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: <Widget>[
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          15, 7, 15, 15),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceEvenly,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: <Widget>[
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            JamIcons.heart_f,
                                                            color:
                                                                Colors.white70,
                                                            size: 20,
                                                          ),
                                                          SizedBox(width: 5),
                                                          Text(
                                                            "Likes: " +
                                                                Provider.of<FavouriteProvider>(
                                                                        context,
                                                                        listen:
                                                                            false)
                                                                    .liked[
                                                                        index][
                                                                        "fav"]
                                                                    .toString(),
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .headline6,
                                                          ),
                                                        ],
                                                      ),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            JamIcons.eye,
                                                            color:
                                                                Colors.white70,
                                                            size: 20,
                                                          ),
                                                          SizedBox(width: 5),
                                                          Text(
                                                            "Views: " +
                                                                Provider.of<FavouriteProvider>(
                                                                        context,
                                                                        listen:
                                                                            false)
                                                                    .liked[
                                                                        index][
                                                                        "views"]
                                                                    .toString(),
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .headline6,
                                                          ),
                                                        ],
                                                      ),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            JamIcons.set_square,
                                                            color:
                                                                Colors.white70,
                                                            size: 20,
                                                          ),
                                                          SizedBox(width: 5),
                                                          Text(
                                                            Provider.of<FavouriteProvider>(
                                                                    context,
                                                                    listen:
                                                                        false)
                                                                .liked[index][
                                                                    "resolution"]
                                                                .toString(),
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .headline6,
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Align(
                                                  alignment:
                                                      Alignment.bottomRight,
                                                  child: GestureDetector(
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                          color:
                                                              Color(0xFF2F2F2F),
                                                          borderRadius:
                                                              BorderRadius.only(
                                                                  topLeft: Radius
                                                                      .circular(
                                                                          20),
                                                                  bottomRight: Radius
                                                                      .circular(
                                                                          20))),
                                                      padding:
                                                          EdgeInsets.all(0),
                                                      child: Padding(
                                                        padding:
                                                            EdgeInsets.fromLTRB(
                                                                10, 5, 10, 5),
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
                                    )
                          : provider.length > 6 &&
                                  provider.substring(0, 6) == "Colors"
                              ? Positioned(
                                  top:
                                      childOffset.dy + childSize.height * 2 / 8,
                                  left: childOffset.dx,
                                  child: TweenAnimationBuilder(
                                    duration: Duration(milliseconds: 200),
                                    builder: (BuildContext context, value,
                                        Widget child) {
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
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(20.0)),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(20.0)),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: <Widget>[
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      15, 7, 15, 15),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceEvenly,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  ActionChip(
                                                      pressElevation: 5,
                                                      padding:
                                                          EdgeInsets.fromLTRB(
                                                              14, 11, 14, 11),
                                                      backgroundColor:
                                                          Colors.black,
                                                      avatar: Icon(
                                                          JamIcons.camera,
                                                          color: Colors.white,
                                                          size: 20),
                                                      label: Text(
                                                        Provider.of<PexelsProvider>(
                                                                context,
                                                                listen: false)
                                                            .wallsC[index]
                                                            .photographer
                                                            .toString(),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .headline4
                                                            .copyWith(
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                      ),
                                                      onPressed: () {}),
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .fromLTRB(0, 5, 0, 10),
                                                    child: Text(
                                                      Provider.of<PexelsProvider>(context, listen: false)
                                                                  .wallsC[index]
                                                                  .url
                                                                  .toString()
                                                                  .replaceAll(
                                                                      "https://www.pexels.com/photo/", "")
                                                                  .replaceAll(
                                                                      "-", " ")
                                                                  .replaceAll(
                                                                      "/", "")
                                                                  .length >
                                                              8
                                                          ? Provider.of<PexelsProvider>(context, listen: false)
                                                                  .wallsC[index]
                                                                  .url
                                                                  .toString()
                                                                  .replaceAll(
                                                                      "https://www.pexels.com/photo/", "")
                                                                  .replaceAll(
                                                                      "-", " ")
                                                                  .replaceAll(
                                                                      "/",
                                                                      "")[0]
                                                                  .toUpperCase() +
                                                              Provider.of<PexelsProvider>(
                                                                      context,
                                                                      listen: false)
                                                                  .wallsC[index]
                                                                  .url
                                                                  .toString()
                                                                  .replaceAll("https://www.pexels.com/photo/", "")
                                                                  .replaceAll("-", " ")
                                                                  .replaceAll("/", "")
                                                                  .substring(1, Provider.of<PexelsProvider>(context, listen: false).wallsC[index].url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "").length - 7)
                                                          : Provider.of<PexelsProvider>(context, listen: false).wallsC[index].url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "")[0].toUpperCase() + Provider.of<PexelsProvider>(context, listen: false).wallsC[index].url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "").substring(1),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .headline5,
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        JamIcons.set_square,
                                                        color: Colors.white70,
                                                        size: 20,
                                                      ),
                                                      SizedBox(width: 5),
                                                      Text(
                                                        "${Provider.of<PexelsProvider>(context, listen: false).wallsC[index].width.toString()}x${Provider.of<PexelsProvider>(context, listen: false).wallsC[index].height.toString()}",
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .headline6,
                                                      ),
                                                    ],
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
                                                      borderRadius:
                                                          BorderRadius.only(
                                                              topLeft: Radius
                                                                  .circular(20),
                                                              bottomRight:
                                                                  Radius
                                                                      .circular(
                                                                          20))),
                                                  padding: EdgeInsets.all(0),
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsets.fromLTRB(
                                                            10, 5, 10, 5),
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
                                )
                              : Positioned(
                                  top:
                                      childOffset.dy + childSize.height * 2 / 8,
                                  left: childOffset.dx,
                                  child: TweenAnimationBuilder(
                                    duration: Duration(milliseconds: 200),
                                    builder: (BuildContext context, value,
                                        Widget child) {
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
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(20.0)),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(20.0)),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: <Widget>[
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      15, 7, 15, 15),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceEvenly,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  ActionChip(
                                                      pressElevation: 5,
                                                      padding: EdgeInsets.fromLTRB(
                                                          14, 11, 14, 11),
                                                      avatar: Icon(
                                                          JamIcons.ordered_list,
                                                          color: HexColor(Provider.of<WallHavenProvider>(context, listen: false).walls[index].colors[Provider.of<WallHavenProvider>(context, listen: false).walls[index].colors.length - 1]).computeLuminance() > 0.5
                                                              ? Colors.black
                                                              : Colors.white,
                                                          size: 20),
                                                      backgroundColor: HexColor(
                                                          Provider.of<WallHavenProvider>(context,
                                                                  listen: false)
                                                              .wallsS[index]
                                                              .colors[Provider.of<WallHavenProvider>(context, listen: false)
                                                                  .wallsS[index]
                                                                  .colors
                                                                  .length -
                                                              1]),
                                                      label: Text(
                                                        Provider.of<WallHavenProvider>(
                                                                    context,
                                                                    listen:
                                                                        false)
                                                                .wallsS[index]
                                                                .category
                                                                .toString()[0]
                                                                .toUpperCase() +
                                                            Provider.of<WallHavenProvider>(
                                                                    context,
                                                                    listen:
                                                                        false)
                                                                .wallsS[index]
                                                                .category
                                                                .toString()
                                                                .substring(1),
                                                        style:
                                                            Theme.of(context)
                                                                .textTheme
                                                                .headline4
                                                                .copyWith(
                                                                  color: HexColor(Provider.of<WallHavenProvider>(context, listen: false).wallsS[index].colors[Provider.of<WallHavenProvider>(context, listen: false).wallsS[index].colors.length - 1])
                                                                              .computeLuminance() >
                                                                          0.5
                                                                      ? Colors
                                                                          .black
                                                                      : Colors
                                                                          .white,
                                                                ),
                                                      ),
                                                      onPressed: () {}),
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .fromLTRB(0, 5, 0, 10),
                                                    child: Text(
                                                      Provider.of<WallHavenProvider>(
                                                              context,
                                                              listen: false)
                                                          .wallsS[index]
                                                          .id
                                                          .toString()
                                                          .toUpperCase(),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .headline5,
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        JamIcons.eye,
                                                        size: 20,
                                                        color: Colors.white70,
                                                      ),
                                                      SizedBox(width: 10),
                                                      Text(
                                                        "Views: ${Provider.of<WallHavenProvider>(context, listen: false).wallsS[index].views.toString()}",
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyText2,
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        JamIcons.set_square,
                                                        size: 20,
                                                        color: Colors.white70,
                                                      ),
                                                      SizedBox(width: 10),
                                                      Text(
                                                        "${Provider.of<WallHavenProvider>(context, listen: false).wallsS[index].resolution.toString()}",
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyText2,
                                                      ),
                                                    ],
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
                                                      borderRadius:
                                                          BorderRadius.only(
                                                              topLeft: Radius
                                                                  .circular(20),
                                                              bottomRight:
                                                                  Radius
                                                                      .circular(
                                                                          20))),
                                                  padding: EdgeInsets.all(0),
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsets.fromLTRB(
                                                            10, 5, 10, 5),
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
                child: SetWallpaperButton(
                  url: provider == "WallHaven"
                      ? Provider.of<WallHavenProvider>(context, listen: false)
                          .walls[index]
                          .path
                          .toString()
                      : provider == "Pexels"
                          ? Provider.of<PexelsProvider>(context, listen: false)
                              .wallsP[index]
                              .url
                              .toString()
                          : provider == "Liked"
                              ? Provider.of<FavouriteProvider>(context,
                                      listen: false)
                                  .liked[index]["url"]
                                  .toString()
                              : provider.length > 6 &&
                                  provider.substring(0, 6) == "Colors"
                              ? Provider.of<PexelsProvider>(context,
                                      listen: false)
                                  .wallsC[index]
                                  .src["portrait"]
                                  .toString()
                              : Provider.of<WallHavenProvider>(context,
                                      listen: false)
                                  .wallsS[index]
                                  .path
                                  .toString(),
                ),
              ),
              Positioned(
                top: topOffset - fabHeartTopOffset,
                left: leftOffset - fabHeartLeftOffset,
                child: FavouriteWallpaperButton(),
              ),
              Positioned(
                top: topOffset + fabWallTopOffset,
                left: leftOffset + fabWallLeftOffset,
                child: DownloadButton(
                  link: provider == "WallHaven"
                      ? Provider.of<WallHavenProvider>(context, listen: false)
                          .walls[index]
                          .path
                          .toString()
                      : provider == "Pexels"
                          ? Provider.of<PexelsProvider>(context, listen: false)
                              .wallsP[index]
                              .url
                              .toString()
                          : provider == "Liked"
                              ? Provider.of<FavouriteProvider>(context,
                                      listen: false)
                                  .liked[index]["url"]
                                  .toString()
                              : provider.length > 6 &&
                                      provider.substring(0, 6) == "Colors"
                                  ? Provider.of<PexelsProvider>(context,
                                          listen: false)
                                      .wallsC[index]
                                  .src["portrait"]
                                      .toString()
                                  : Provider.of<WallHavenProvider>(context,
                                          listen: false)
                                      .wallsS[index]
                                      .path
                                      .toString(),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print(e.toString());
      Navigator.pop(context);
      return Container();
    }
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
