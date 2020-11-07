import 'dart:ui';
import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as PData;
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as Data;
import 'package:Prism/data/profile/wallpaper/profileWallProvider.dart';
import 'package:Prism/data/profile/wallpaper/getUserProfile.dart' as UserData;
import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart'
    as WData;
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/menuButton/downloadButton.dart';
import 'package:Prism/ui/widgets/menuButton/favWallpaperButton.dart';
import 'package:Prism/ui/widgets/menuButton/setWallpaperButton.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/theme/config.dart' as config;

class FocusedMenuDetails extends StatefulWidget {
  final String provider;
  final Offset childOffset;
  final Size childSize;
  final int index;
  final Size size;
  final Orientation orientation;
  final Widget child;

  const FocusedMenuDetails({
    Key key,
    @required this.provider,
    @required this.childOffset,
    @required this.childSize,
    @required this.child,
    @required this.index,
    @required this.size,
    @required this.orientation,
  }) : super(key: key);

  @override
  _FocusedMenuDetailsState createState() => _FocusedMenuDetailsState();
}

class _FocusedMenuDetailsState extends State<FocusedMenuDetails> {
  num maxMenuWidth;
  num menuHeight;
  double leftOffset;
  double topOffset;
  num fabHeartTopOffset;
  num fabWallLeftOffset;
  num fabWallTopOffset;
  num fabHeartLeftOffset;
  @override
  void initState() {
    maxMenuWidth = widget.size.width * 0.63;
    menuHeight = widget.size.height * 0.14;
    leftOffset = (widget.childOffset.dx + maxMenuWidth) < widget.size.width
        ? widget.orientation == Orientation.portrait
            ? widget.childOffset.dx +
                widget.childSize.width +
                widget.size.width * 0.015
            : widget.childOffset.dx +
                widget.childSize.width +
                widget.size.width * 0.01
        : widget.orientation == Orientation.portrait
            ? (widget.childOffset.dx - maxMenuWidth + widget.childSize.width)
            : (widget.childOffset.dx -
                maxMenuWidth +
                widget.childSize.width +
                widget.size.width * 0.3);
    topOffset = (widget.childOffset.dy + menuHeight + widget.childSize.height) <
            widget.size.height
        ? widget.orientation == Orientation.portrait
            ? widget.childOffset.dy +
                widget.childSize.height +
                widget.size.width * 0.015
            : widget.childOffset.dy +
                widget.childSize.height +
                widget.size.width * 0.015
        : widget.orientation == Orientation.portrait
            ? widget.childOffset.dy - menuHeight + widget.size.width * 0.125
            : widget.childOffset.dy - menuHeight;

    fabHeartTopOffset =
        (widget.childOffset.dy + menuHeight + widget.childSize.height) <
                widget.size.height
            ? widget.orientation == Orientation.portrait
                ? widget.size.width * 0.175
                : widget.size.width * 0.1
            : widget.orientation == Orientation.portrait
                ? -widget.size.width * 0.175
                : -widget.size.width * 0.1;
    fabWallLeftOffset =
        (widget.childOffset.dx + maxMenuWidth) < widget.size.width
            ? widget.orientation == Orientation.portrait
                ? -widget.size.width * 0.175
                : -widget.size.width * 0.1
            : widget.orientation == Orientation.portrait
                ? widget.size.width * 0.175
                : widget.size.width * 0.1;

    fabWallTopOffset =
        (widget.childOffset.dy + menuHeight + widget.childSize.height) <
                widget.size.height
            ? widget.orientation == Orientation.portrait
                ? widget.size.width * 0.05
                : widget.size.width * 0.02
            : widget.orientation == Orientation.portrait
                ? -widget.size.width * 0.05
                : -widget.size.width * 0.02;
    fabHeartLeftOffset =
        (widget.childOffset.dx + maxMenuWidth) < widget.size.width
            ? widget.orientation == Orientation.portrait
                ? -widget.size.width * 0.05
                : -widget.size.width * 0.02
            : widget.orientation == Orientation.portrait
                ? widget.size.width * 0.05
                : widget.size.width * 0.02;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(widget.provider);
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
                top: widget.childOffset.dy,
                left: widget.childOffset.dx,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: AbsorbPointer(
                      child: Container(
                          width: widget.childSize.width,
                          height: widget.childSize.height,
                          child: widget.child)),
                )),
            widget.provider == "WallHaven"
                ? Positioned(
                    top: widget.childOffset.dy +
                        widget.childSize.height * 4 / 10,
                    left: widget.childOffset.dx,
                    child: TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 150),
                      builder:
                          (BuildContext context, double value, Widget child) {
                        return Transform.scale(
                          scale: value,
                          alignment: Alignment.bottomRight,
                          child: child,
                        );
                      },
                      tween: Tween(begin: 0.0, end: 1.0),
                      child: Container(
                        width: widget.childSize.width,
                        height: widget.childSize.height * 6 / 10,
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
                                padding:
                                    const EdgeInsets.fromLTRB(15, 7, 15, 15),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    ActionChip(
                                        pressElevation: 5,
                                        padding: const EdgeInsets.fromLTRB(
                                            14, 11, 14, 11),
                                        avatar: Icon(
                                          JamIcons.ordered_list,
                                          color: HexColor(WData
                                                          .walls[widget.index]
                                                          .colors[WData
                                                                  .walls[widget
                                                                      .index]
                                                                  .colors
                                                                  .length -
                                                              1]
                                                          .toString())
                                                      .computeLuminance() >
                                                  0.5
                                              ? Colors.black
                                              : Colors.white,
                                          size: 20,
                                        ),
                                        backgroundColor: HexColor(WData
                                            .walls[widget.index]
                                            .colors[WData.walls[widget.index]
                                                    .colors.length -
                                                1]
                                            .toString()),
                                        label: Text(
                                          WData.walls[widget.index].category
                                                  .toString()[0]
                                                  .toUpperCase() +
                                              WData.walls[widget.index].category
                                                  .toString()
                                                  .substring(1),
                                          style:
                                              Theme.of(context)
                                                  .textTheme
                                                  .headline4
                                                  .copyWith(
                                                    color: HexColor(WData
                                                                    .walls[widget
                                                                        .index]
                                                                    .colors[WData
                                                                            .walls[widget.index]
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
                                      padding: const EdgeInsets.fromLTRB(
                                          0, 5, 0, 10),
                                      child: Text(
                                        WData.walls[widget.index].id
                                            .toString()
                                            .toUpperCase(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .headline5
                                            .copyWith(
                                                color: Theme.of(context)
                                                    .accentColor),
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
                                          "Views: ${WData.walls[widget.index].views.toString()}",
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
                                          WData.walls[widget.index].resolution
                                              .toString(),
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
                                      padding: const EdgeInsets.fromLTRB(
                                          10, 5, 10, 5),
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
                : widget.provider == "Prism"
                    ? Positioned(
                        top: widget.childOffset.dy +
                            widget.childSize.height * 4 / 10,
                        left: widget.childOffset.dx,
                        child: TweenAnimationBuilder(
                          duration: const Duration(milliseconds: 150),
                          builder: (BuildContext context, double value,
                              Widget child) {
                            return Transform.scale(
                              scale: value,
                              alignment: Alignment.bottomRight,
                              child: child,
                            );
                          },
                          tween: Tween(begin: 0.0, end: 1.0),
                          child: Container(
                            width: widget.childSize.width,
                            height: widget.childSize.height * 6 / 10,
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
                                    padding: const EdgeInsets.fromLTRB(
                                        15, 7, 15, 15),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Stack(
                                            alignment: globals.verifiedUsers
                                                    .contains(Data
                                                        .subPrismWalls[widget
                                                            .index]["email"]
                                                        .toString())
                                                ? Alignment.topRight
                                                : Alignment.centerLeft,
                                            children: [
                                              ActionChip(
                                                  pressElevation: 5,
                                                  padding:
                                                      const EdgeInsets.all(5),
                                                  avatar: CircleAvatar(
                                                    backgroundImage:
                                                        CachedNetworkImageProvider(
                                                            Data
                                                                .subPrismWalls[
                                                                    widget
                                                                        .index][
                                                                    "userPhoto"]
                                                                .toString()),
                                                  ),
                                                  backgroundColor: Colors.black,
                                                  labelPadding:
                                                      const EdgeInsets.fromLTRB(
                                                          7, 3, 7, 3),
                                                  label: Text(
                                                    Data.subPrismWalls[widget
                                                                .index]["by"]
                                                            .toString()[0]
                                                            .toUpperCase() +
                                                        Data.subPrismWalls[
                                                                widget.index]
                                                                ["by"]
                                                            .toString()
                                                            .substring(1),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .headline4
                                                        .copyWith(
                                                          color: Colors.white,
                                                        ),
                                                  ),
                                                  onPressed: () {
                                                    Navigator.pushNamed(
                                                        context,
                                                        photographerProfileRoute,
                                                        arguments: [
                                                          Data.subPrismWalls[
                                                                  widget.index]
                                                              ["by"],
                                                          Data.subPrismWalls[
                                                                  widget.index]
                                                              ["email"],
                                                          Data.subPrismWalls[
                                                                  widget.index]
                                                              ["userPhoto"],
                                                          false,
                                                          Data.subPrismWalls[widget.index]
                                                                          [
                                                                          "twitter"] !=
                                                                      null &&
                                                                  Data.subPrismWalls[widget.index]
                                                                          [
                                                                          "twitter"] !=
                                                                      ""
                                                              ? Data
                                                                  .subPrismWalls[
                                                                      widget
                                                                          .index]
                                                                      [
                                                                      "twitter"]
                                                                  .toString()
                                                                  .split(
                                                                      "https://www.twitter.com/")[1]
                                                              : "",
                                                          Data.subPrismWalls[widget.index]
                                                                          [
                                                                          "instagram"] !=
                                                                      null &&
                                                                  Data.subPrismWalls[widget.index]
                                                                          [
                                                                          "instagram"] !=
                                                                      ""
                                                              ? Data
                                                                  .subPrismWalls[
                                                                      widget
                                                                          .index]
                                                                      [
                                                                      "instagram"]
                                                                  .toString()
                                                                  .split(
                                                                      "https://www.instagram.com/")[1]
                                                              : "",
                                                        ]);
                                                  }),
                                              globals.verifiedUsers.contains(
                                                      Data.subPrismWalls[widget
                                                              .index]["email"]
                                                          .toString())
                                                  ? Container(
                                                      width: 20,
                                                      height: 20,
                                                      child: SvgPicture.string(
                                                          verifiedIcon.replaceAll(
                                                              "E57697",
                                                              config.Colors().mainAccentColor(
                                                                          1) ==
                                                                      Colors
                                                                          .black
                                                                  ? "E57697"
                                                                  : main.prefs
                                                                      .get(
                                                                          "mainAccentColor")
                                                                      .toRadixString(
                                                                          16)
                                                                      .toString()
                                                                      .substring(
                                                                          2))),
                                                    )
                                                  : Container(),
                                            ]),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              0, 5, 0, 10),
                                          child: Text(
                                            Data.subPrismWalls[widget.index]
                                                    ["id"]
                                                .toString()
                                                .toUpperCase(),
                                            style: Theme.of(context)
                                                .textTheme
                                                .headline5
                                                .copyWith(
                                                    color: Theme.of(context)
                                                        .accentColor),
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Icon(
                                              JamIcons.save,
                                              size: 20,
                                              color:
                                                  Theme.of(context).accentColor,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              Data.subPrismWalls[widget.index]
                                                      ["size"]
                                                  .toString(),
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
                                              color:
                                                  Theme.of(context).accentColor,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              Data.subPrismWalls[widget.index]
                                                      ["resolution"]
                                                  .toString(),
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
                                            borderRadius:
                                                const BorderRadius.only(
                                                    topLeft:
                                                        Radius.circular(20),
                                                    bottomRight:
                                                        Radius.circular(20))),
                                        padding: const EdgeInsets.all(0),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              10, 5, 10, 5),
                                          child: Icon(
                                            JamIcons.close,
                                            color:
                                                Theme.of(context).accentColor,
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
                    : widget.provider == "ProfileWall"
                        ? Positioned(
                            top: widget.childOffset.dy +
                                widget.childSize.height * 4 / 10,
                            left: widget.childOffset.dx,
                            child: TweenAnimationBuilder(
                              duration: const Duration(milliseconds: 150),
                              builder: (BuildContext context, double value,
                                  Widget child) {
                                return Transform.scale(
                                  scale: value,
                                  alignment: Alignment.bottomRight,
                                  child: child,
                                );
                              },
                              tween: Tween(begin: 0.0, end: 1.0),
                              child: Container(
                                width: widget.childSize.width,
                                height: widget.childSize.height * 6 / 10,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).hintColor,
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
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                        14, 11, 14, 11),
                                                avatar: const Icon(
                                                  JamIcons.camera,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                                backgroundColor: Colors.black,
                                                label: Text(
                                                  Provider.of<ProfileWallProvider>(
                                                              context,
                                                              listen: false)
                                                          .profileWalls[widget
                                                              .index]["by"]
                                                          .toString()[0]
                                                          .toUpperCase() +
                                                      Provider.of<ProfileWallProvider>(
                                                              context,
                                                              listen: false)
                                                          .profileWalls[widget
                                                              .index]["by"]
                                                          .toString()
                                                          .substring(1),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headline4
                                                      .copyWith(
                                                        color: Colors.white,
                                                      ),
                                                ),
                                                onPressed: () {}),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      0, 5, 0, 10),
                                              child: Text(
                                                Provider.of<ProfileWallProvider>(
                                                        context,
                                                        listen: false)
                                                    .profileWalls[widget.index]
                                                        ["id"]
                                                    .toString()
                                                    .toUpperCase(),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headline5
                                                    .copyWith(
                                                        color: Theme.of(context)
                                                            .accentColor),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Icon(
                                                  JamIcons.save,
                                                  size: 20,
                                                  color: Theme.of(context)
                                                      .accentColor,
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  Provider.of<ProfileWallProvider>(
                                                          context,
                                                          listen: false)
                                                      .profileWalls[
                                                          widget.index]["size"]
                                                      .toString(),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyText2
                                                      .copyWith(
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Icon(
                                                  JamIcons.set_square,
                                                  size: 20,
                                                  color: Theme.of(context)
                                                      .accentColor,
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  Provider.of<ProfileWallProvider>(
                                                          context,
                                                          listen: false)
                                                      .profileWalls[widget
                                                          .index]["resolution"]
                                                      .toString(),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyText2
                                                      .copyWith(
                                                          color:
                                                              Theme.of(context)
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
                                                color:
                                                    Theme.of(context).hintColor,
                                                borderRadius:
                                                    const BorderRadius.only(
                                                        topLeft:
                                                            Radius.circular(20),
                                                        bottomRight:
                                                            Radius.circular(
                                                                20))),
                                            padding: const EdgeInsets.all(0),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      10, 5, 10, 5),
                                              child: Icon(
                                                JamIcons.close,
                                                color: Theme.of(context)
                                                    .accentColor,
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
                        : widget.provider == "UserProfileWall"
                            ? Positioned(
                                top: widget.childOffset.dy +
                                    widget.childSize.height * 4 / 10,
                                left: widget.childOffset.dx,
                                child: TweenAnimationBuilder(
                                  duration: const Duration(milliseconds: 150),
                                  builder: (BuildContext context, double value,
                                      Widget child) {
                                    return Transform.scale(
                                      scale: value,
                                      alignment: Alignment.bottomRight,
                                      child: child,
                                    );
                                  },
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  child: Container(
                                    width: widget.childSize.width,
                                    height: widget.childSize.height * 6 / 10,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).hintColor,
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
                                                    padding: const EdgeInsets
                                                            .fromLTRB(
                                                        14, 11, 14, 11),
                                                    avatar: const Icon(
                                                      JamIcons.camera,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                    backgroundColor:
                                                        Colors.black,
                                                    label: Text(
                                                      UserData.userProfileWalls[
                                                                  widget.index]
                                                                  ["by"]
                                                              .toString()[0]
                                                              .toUpperCase() +
                                                          UserData
                                                              .userProfileWalls[
                                                                  widget.index]
                                                                  ["by"]
                                                              .toString()
                                                              .substring(1),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .headline4
                                                          .copyWith(
                                                            color: Colors.white,
                                                          ),
                                                    ),
                                                    onPressed: () {}),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          0, 5, 0, 10),
                                                  child: Text(
                                                    UserData.userProfileWalls[
                                                            widget.index]["id"]
                                                        .toString()
                                                        .toUpperCase(),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .headline5
                                                        .copyWith(
                                                            color: Theme.of(
                                                                    context)
                                                                .accentColor),
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      JamIcons.save,
                                                      size: 20,
                                                      color: Theme.of(context)
                                                          .accentColor,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      UserData.userProfileWalls[
                                                              widget.index]
                                                              ["size"]
                                                          .toString(),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyText2
                                                          .copyWith(
                                                              color: Theme.of(
                                                                      context)
                                                                  .accentColor),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      JamIcons.set_square,
                                                      size: 20,
                                                      color: Theme.of(context)
                                                          .accentColor,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      UserData.userProfileWalls[
                                                              widget.index]
                                                              ["resolution"]
                                                          .toString(),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyText2
                                                          .copyWith(
                                                              color: Theme.of(
                                                                      context)
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
                                                    color: Theme.of(context)
                                                        .hintColor,
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                            topLeft:
                                                                Radius.circular(
                                                                    20),
                                                            bottomRight:
                                                                Radius.circular(
                                                                    20))),
                                                padding:
                                                    const EdgeInsets.all(0),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          10, 5, 10, 5),
                                                  child: Icon(
                                                    JamIcons.close,
                                                    color: Theme.of(context)
                                                        .accentColor,
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
                            : widget.provider == "Pexels"
                                ? Positioned(
                                    top: widget.childOffset.dy +
                                        widget.childSize.height * 4 / 10,
                                    left: widget.childOffset.dx,
                                    child: TweenAnimationBuilder(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      builder: (BuildContext context,
                                          double value, Widget child) {
                                        return Transform.scale(
                                          scale: value,
                                          alignment: Alignment.bottomRight,
                                          child: child,
                                        );
                                      },
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      child: Container(
                                        width: widget.childSize.width,
                                        height:
                                            widget.childSize.height * 6 / 10,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).hintColor,
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
                                                            const EdgeInsets
                                                                    .fromLTRB(
                                                                14, 11, 14, 11),
                                                        backgroundColor:
                                                            Colors.black,
                                                        avatar: const Icon(
                                                            JamIcons.camera,
                                                            color: Colors.white,
                                                            size: 20),
                                                        label: Text(
                                                          PData
                                                              .wallsP[
                                                                  widget.index]
                                                              .photographer
                                                              .toString(),
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .headline4
                                                                  .copyWith(
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                        ),
                                                        onPressed: () {
                                                          launch(PData
                                                              .wallsP[
                                                                  widget.index]
                                                              .url);
                                                        }),
                                                    Padding(
                                                      padding: const EdgeInsets
                                                              .fromLTRB(
                                                          0, 5, 0, 10),
                                                      child: Text(
                                                        PData.wallsP[widget.index].url
                                                                    .toString()
                                                                    .replaceAll(
                                                                        "https://www.pexels.com/photo/", "")
                                                                    .replaceAll(
                                                                        "-", " ")
                                                                    .replaceAll(
                                                                        "/", "")
                                                                    .length >
                                                                8
                                                            ? PData.wallsP[widget.index].url
                                                                    .toString()
                                                                    .replaceAll(
                                                                        "https://www.pexels.com/photo/", "")
                                                                    .replaceAll(
                                                                        "-", " ")
                                                                    .replaceAll(
                                                                        "/",
                                                                        "")[0]
                                                                    .toUpperCase() +
                                                                PData.wallsP[widget.index].url
                                                                    .toString()
                                                                    .replaceAll(
                                                                        "https://www.pexels.com/photo/", "")
                                                                    .replaceAll(
                                                                        "-", " ")
                                                                    .replaceAll("/", "")
                                                                    .substring(1, PData.wallsP[widget.index].url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "").length - 7)
                                                            : PData.wallsP[widget.index].url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "")[0].toUpperCase() + PData.wallsP[widget.index].url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "").substring(1),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .headline5
                                                            .copyWith(
                                                                color: Theme.of(
                                                                        context)
                                                                    .accentColor),
                                                      ),
                                                    ),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          JamIcons.set_square,
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor,
                                                          size: 20,
                                                        ),
                                                        const SizedBox(
                                                            width: 5),
                                                        Text(
                                                          "${PData.wallsP[widget.index].width.toString()}x${PData.wallsP[widget.index].height.toString()}",
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .headline6
                                                              .copyWith(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .accentColor),
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
                                                  onTap: () async {
                                                    Navigator.pop(context);
                                                  },
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .hintColor,
                                                        borderRadius:
                                                            const BorderRadius
                                                                    .only(
                                                                topLeft: Radius
                                                                    .circular(
                                                                        20),
                                                                bottomRight: Radius
                                                                    .circular(
                                                                        20))),
                                                    padding:
                                                        const EdgeInsets.all(0),
                                                    child: Padding(
                                                      padding: const EdgeInsets
                                                              .fromLTRB(
                                                          10, 5, 10, 5),
                                                      child: Icon(
                                                        JamIcons.close,
                                                        color: Theme.of(context)
                                                            .accentColor,
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
                                : widget.provider == "Liked"
                                    ? Provider.of<FavouriteProvider>(context,
                                                        listen: false)
                                                    .liked[widget.index]
                                                ["provider"] ==
                                            "WallHaven"
                                        ? Positioned(
                                            top: widget.childOffset.dy +
                                                widget.childSize.height * 2 / 8,
                                            left: widget.childOffset.dx,
                                            child: TweenAnimationBuilder(
                                              duration: const Duration(
                                                  milliseconds: 200),
                                              builder: (BuildContext context,
                                                  double value, Widget child) {
                                                return Transform.scale(
                                                  scale: value,
                                                  alignment:
                                                      Alignment.bottomRight,
                                                  child: child,
                                                );
                                              },
                                              tween:
                                                  Tween(begin: 0.0, end: 1.0),
                                              child: Container(
                                                width: widget.childSize.width,
                                                height:
                                                    widget.childSize.height *
                                                        6 /
                                                        8,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .hintColor,
                                                  borderRadius:
                                                      const BorderRadius.all(
                                                          Radius.circular(
                                                              20.0)),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      const BorderRadius.all(
                                                          Radius.circular(
                                                              20.0)),
                                                  child: Stack(
                                                    fit: StackFit.expand,
                                                    children: <Widget>[
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                    .fromLTRB(
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
                                                                pressElevation:
                                                                    5,
                                                                padding:
                                                                    const EdgeInsets
                                                                            .fromLTRB(
                                                                        14,
                                                                        11,
                                                                        14,
                                                                        11),
                                                                avatar:
                                                                    const Icon(
                                                                  JamIcons
                                                                      .ordered_list,
                                                                  color: Colors
                                                                      .white,
                                                                  size: 20,
                                                                ),
                                                                backgroundColor:
                                                                    Colors
                                                                        .black,
                                                                label: Text(
                                                                  Provider.of<FavouriteProvider>(
                                                                              context,
                                                                              listen:
                                                                                  false)
                                                                          .liked[widget.index]
                                                                              [
                                                                              "category"]
                                                                          .toString()[
                                                                              0]
                                                                          .toUpperCase() +
                                                                      Provider.of<FavouriteProvider>(
                                                                              context,
                                                                              listen:
                                                                                  false)
                                                                          .liked[
                                                                              widget.index]
                                                                              [
                                                                              "category"]
                                                                          .toString()
                                                                          .substring(
                                                                              1),
                                                                  style: Theme.of(
                                                                          context)
                                                                      .textTheme
                                                                      .headline4
                                                                      .copyWith(
                                                                        color: Colors
                                                                            .white,
                                                                      ),
                                                                ),
                                                                onPressed:
                                                                    () {}),
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                          .fromLTRB(
                                                                      0,
                                                                      5,
                                                                      0,
                                                                      10),
                                                              child: Text(
                                                                Provider.of<FavouriteProvider>(
                                                                        context,
                                                                        listen:
                                                                            false)
                                                                    .liked[
                                                                        widget
                                                                            .index]
                                                                        ["id"]
                                                                    .toString()
                                                                    .toUpperCase(),
                                                                style: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .headline5
                                                                    .copyWith(
                                                                        color: Theme.of(context)
                                                                            .accentColor),
                                                              ),
                                                            ),
                                                            Row(
                                                              children: [
                                                                const Icon(
                                                                  JamIcons.eye,
                                                                  size: 20,
                                                                  color: Colors
                                                                      .white70,
                                                                ),
                                                                const SizedBox(
                                                                    width: 10),
                                                                Text(
                                                                  "Views: ${Provider.of<FavouriteProvider>(context, listen: false).liked[widget.index]["views"].toString()}",
                                                                  style: Theme.of(
                                                                          context)
                                                                      .textTheme
                                                                      .bodyText2
                                                                      .copyWith(
                                                                          color:
                                                                              Theme.of(context).accentColor),
                                                                ),
                                                              ],
                                                            ),
                                                            Row(
                                                              children: [
                                                                const Icon(
                                                                  JamIcons
                                                                      .set_square,
                                                                  size: 20,
                                                                  color: Colors
                                                                      .white70,
                                                                ),
                                                                const SizedBox(
                                                                    width: 10),
                                                                Text(
                                                                  Provider.of<FavouriteProvider>(
                                                                          context,
                                                                          listen:
                                                                              false)
                                                                      .liked[
                                                                          widget
                                                                              .index]
                                                                          [
                                                                          "resolution"]
                                                                      .toString(),
                                                                  style: Theme.of(
                                                                          context)
                                                                      .textTheme
                                                                      .bodyText2
                                                                      .copyWith(
                                                                          color:
                                                                              Theme.of(context).accentColor),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Align(
                                                        alignment: Alignment
                                                            .bottomRight,
                                                        child: GestureDetector(
                                                          onTap: () async {
                                                            Navigator.pop(
                                                                context);
                                                          },
                                                          child: Container(
                                                            decoration: const BoxDecoration(
                                                                color: Color(
                                                                    0xFF2F2F2F),
                                                                borderRadius: BorderRadius.only(
                                                                    topLeft: Radius
                                                                        .circular(
                                                                            20),
                                                                    bottomRight:
                                                                        Radius.circular(
                                                                            20))),
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(0),
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                          .fromLTRB(
                                                                      10,
                                                                      5,
                                                                      10,
                                                                      5),
                                                              child: Icon(
                                                                JamIcons.close,
                                                                color: Theme.of(
                                                                        context)
                                                                    .accentColor,
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
                                        : Provider.of<FavouriteProvider>(
                                                            context,
                                                            listen: false)
                                                        .liked[widget.index]
                                                    ["provider"] ==
                                                "Prism"
                                            ? Positioned(
                                                top: widget.childOffset.dy +
                                                    widget.childSize.height *
                                                        2 /
                                                        8,
                                                left: widget.childOffset.dx,
                                                child: TweenAnimationBuilder(
                                                  duration: const Duration(
                                                      milliseconds: 200),
                                                  builder:
                                                      (BuildContext context,
                                                          double value,
                                                          Widget child) {
                                                    return Transform.scale(
                                                      scale: value,
                                                      alignment:
                                                          Alignment.bottomRight,
                                                      child: child,
                                                    );
                                                  },
                                                  tween: Tween(
                                                      begin: 0.0, end: 1.0),
                                                  child: Container(
                                                    width:
                                                        widget.childSize.width,
                                                    height: widget
                                                            .childSize.height *
                                                        6 /
                                                        8,
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context)
                                                          .hintColor,
                                                      borderRadius:
                                                          const BorderRadius
                                                                  .all(
                                                              Radius.circular(
                                                                  20.0)),
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          const BorderRadius
                                                                  .all(
                                                              Radius.circular(
                                                                  20.0)),
                                                      child: Stack(
                                                        fit: StackFit.expand,
                                                        children: <Widget>[
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                        .fromLTRB(
                                                                    15,
                                                                    7,
                                                                    15,
                                                                    15),
                                                            child: Column(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceEvenly,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: <
                                                                  Widget>[
                                                                ActionChip(
                                                                    pressElevation:
                                                                        5,
                                                                    padding:
                                                                        const EdgeInsets.fromLTRB(
                                                                            14,
                                                                            11,
                                                                            14,
                                                                            11),
                                                                    avatar:
                                                                        const Icon(
                                                                      JamIcons
                                                                          .camera,
                                                                      color: Colors
                                                                          .white,
                                                                      size: 20,
                                                                    ),
                                                                    backgroundColor:
                                                                        Colors
                                                                            .black,
                                                                    label: Text(
                                                                      Provider.of<FavouriteProvider>(context, listen: false)
                                                                              .liked[widget.index][
                                                                                  "photographer"]
                                                                              .toString()[
                                                                                  0]
                                                                              .toUpperCase() +
                                                                          Provider.of<FavouriteProvider>(context, listen: false)
                                                                              .liked[widget.index]["photographer"]
                                                                              .toString()
                                                                              .substring(1),
                                                                      style: Theme.of(
                                                                              context)
                                                                          .textTheme
                                                                          .headline4
                                                                          .copyWith(
                                                                            color:
                                                                                Colors.white,
                                                                          ),
                                                                    ),
                                                                    onPressed:
                                                                        () {}),
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                              .fromLTRB(
                                                                          0,
                                                                          5,
                                                                          0,
                                                                          10),
                                                                  child: Text(
                                                                    Provider.of<FavouriteProvider>(
                                                                            context,
                                                                            listen:
                                                                                false)
                                                                        .liked[
                                                                            widget.index]
                                                                            [
                                                                            "id"]
                                                                        .toString()
                                                                        .toUpperCase(),
                                                                    style: Theme.of(
                                                                            context)
                                                                        .textTheme
                                                                        .headline5
                                                                        .copyWith(
                                                                            color:
                                                                                Theme.of(context).accentColor),
                                                                  ),
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    const Icon(
                                                                      JamIcons
                                                                          .save,
                                                                      size: 20,
                                                                      color: Colors
                                                                          .white70,
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            10),
                                                                    Text(
                                                                      Provider.of<FavouriteProvider>(
                                                                              context,
                                                                              listen:
                                                                                  false)
                                                                          .liked[
                                                                              widget.index]
                                                                              [
                                                                              "size"]
                                                                          .toString(),
                                                                      style: Theme.of(
                                                                              context)
                                                                          .textTheme
                                                                          .bodyText2
                                                                          .copyWith(
                                                                              color: Theme.of(context).accentColor),
                                                                    ),
                                                                  ],
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    const Icon(
                                                                      JamIcons
                                                                          .set_square,
                                                                      size: 20,
                                                                      color: Colors
                                                                          .white70,
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            10),
                                                                    Text(
                                                                      Provider.of<FavouriteProvider>(
                                                                              context,
                                                                              listen:
                                                                                  false)
                                                                          .liked[
                                                                              widget.index]
                                                                              [
                                                                              "resolution"]
                                                                          .toString(),
                                                                      style: Theme.of(
                                                                              context)
                                                                          .textTheme
                                                                          .bodyText2
                                                                          .copyWith(
                                                                              color: Theme.of(context).accentColor),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          Align(
                                                            alignment: Alignment
                                                                .bottomRight,
                                                            child:
                                                                GestureDetector(
                                                              onTap: () async {
                                                                Navigator.pop(
                                                                    context);
                                                              },
                                                              child: Container(
                                                                decoration: const BoxDecoration(
                                                                    color: Color(
                                                                        0xFF2F2F2F),
                                                                    borderRadius: BorderRadius.only(
                                                                        topLeft:
                                                                            Radius.circular(
                                                                                20),
                                                                        bottomRight:
                                                                            Radius.circular(20))),
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(0),
                                                                child: Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                              .fromLTRB(
                                                                          10,
                                                                          5,
                                                                          10,
                                                                          5),
                                                                  child: Icon(
                                                                    JamIcons
                                                                        .close,
                                                                    color: Theme.of(
                                                                            context)
                                                                        .accentColor,
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
                                            : Provider.of<FavouriteProvider>(
                                                                context,
                                                                listen: false)
                                                            .liked[widget.index]
                                                        ["provider"] ==
                                                    "Pexels"
                                                ? Positioned(
                                                    top: widget.childOffset.dy +
                                                        widget.childSize
                                                                .height *
                                                            1 /
                                                            2,
                                                    left: widget.childOffset.dx,
                                                    child:
                                                        TweenAnimationBuilder(
                                                      duration: const Duration(
                                                          milliseconds: 200),
                                                      builder:
                                                          (BuildContext context,
                                                              double value,
                                                              Widget child) {
                                                        return Transform.scale(
                                                          scale: value,
                                                          alignment: Alignment
                                                              .bottomRight,
                                                          child: child,
                                                        );
                                                      },
                                                      tween: Tween(
                                                          begin: 0.0, end: 1.0),
                                                      child: Container(
                                                        width: widget
                                                            .childSize.width,
                                                        height: widget.childSize
                                                                .height *
                                                            1 /
                                                            2,
                                                        decoration:
                                                            const BoxDecoration(
                                                          color:
                                                              Color(0xFF2F2F2F),
                                                          borderRadius:
                                                              BorderRadius.all(
                                                                  Radius
                                                                      .circular(
                                                                          20.0)),
                                                        ),
                                                        child: ClipRRect(
                                                          borderRadius:
                                                              const BorderRadius
                                                                      .all(
                                                                  Radius
                                                                      .circular(
                                                                          20.0)),
                                                          child: Stack(
                                                            fit:
                                                                StackFit.expand,
                                                            children: <Widget>[
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                            .fromLTRB(
                                                                        15,
                                                                        7,
                                                                        15,
                                                                        15),
                                                                child: Column(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceEvenly,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: <
                                                                      Widget>[
                                                                    ActionChip(
                                                                        pressElevation:
                                                                            5,
                                                                        padding: const EdgeInsets.fromLTRB(
                                                                            14,
                                                                            11,
                                                                            14,
                                                                            11),
                                                                        backgroundColor:
                                                                            Colors
                                                                                .black,
                                                                        avatar: const Icon(
                                                                            JamIcons
                                                                                .camera,
                                                                            color: Colors
                                                                                .white,
                                                                            size:
                                                                                20),
                                                                        label:
                                                                            Text(
                                                                          Provider.of<FavouriteProvider>(context, listen: false)
                                                                              .liked[widget.index]["photographer"]
                                                                              .toString(),
                                                                          style: Theme.of(context)
                                                                              .textTheme
                                                                              .headline4
                                                                              .copyWith(
                                                                                color: Colors.white,
                                                                              ),
                                                                        ),
                                                                        onPressed:
                                                                            () {}),
                                                                    Row(
                                                                      children: [
                                                                        Icon(
                                                                          JamIcons
                                                                              .set_square,
                                                                          color:
                                                                              Theme.of(context).accentColor,
                                                                          size:
                                                                              20,
                                                                        ),
                                                                        const SizedBox(
                                                                            width:
                                                                                5),
                                                                        Text(
                                                                          Provider.of<FavouriteProvider>(context, listen: false)
                                                                              .liked[widget.index]["resolution"]
                                                                              .toString(),
                                                                          style: Theme.of(context)
                                                                              .textTheme
                                                                              .bodyText2
                                                                              .copyWith(color: Theme.of(context).accentColor),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              Align(
                                                                alignment: Alignment
                                                                    .bottomRight,
                                                                child:
                                                                    GestureDetector(
                                                                  onTap:
                                                                      () async {
                                                                    Navigator.pop(
                                                                        context);
                                                                  },
                                                                  child:
                                                                      Container(
                                                                    decoration: const BoxDecoration(
                                                                        color: Color(
                                                                            0xFF2F2F2F),
                                                                        borderRadius: BorderRadius.only(
                                                                            topLeft:
                                                                                Radius.circular(20),
                                                                            bottomRight: Radius.circular(20))),
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .all(0),
                                                                    child:
                                                                        Padding(
                                                                      padding:
                                                                          const EdgeInsets.fromLTRB(
                                                                              10,
                                                                              5,
                                                                              10,
                                                                              5),
                                                                      child:
                                                                          Icon(
                                                                        JamIcons
                                                                            .close,
                                                                        color: Theme.of(context)
                                                                            .accentColor,
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
                                                : Positioned(
                                                    top: widget.childOffset.dy +
                                                        widget.childSize
                                                                .height *
                                                            1 /
                                                            2,
                                                    left: widget.childOffset.dx,
                                                    child:
                                                        TweenAnimationBuilder(
                                                      duration: const Duration(
                                                          milliseconds: 200),
                                                      builder:
                                                          (BuildContext context,
                                                              double value,
                                                              Widget child) {
                                                        return Transform.scale(
                                                          scale: value,
                                                          alignment: Alignment
                                                              .bottomRight,
                                                          child: child,
                                                        );
                                                      },
                                                      tween: Tween(
                                                          begin: 0.0, end: 1.0),
                                                      child: Container(
                                                        width: widget
                                                            .childSize.width,
                                                        height: widget.childSize
                                                                .height *
                                                            1 /
                                                            2,
                                                        decoration:
                                                            const BoxDecoration(
                                                          color:
                                                              Color(0xFF2F2F2F),
                                                          borderRadius:
                                                              BorderRadius.all(
                                                                  Radius
                                                                      .circular(
                                                                          20.0)),
                                                        ),
                                                        child: ClipRRect(
                                                          borderRadius:
                                                              const BorderRadius
                                                                      .all(
                                                                  Radius
                                                                      .circular(
                                                                          20.0)),
                                                          child: Stack(
                                                            fit:
                                                                StackFit.expand,
                                                            children: <Widget>[
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                            .fromLTRB(
                                                                        15,
                                                                        7,
                                                                        15,
                                                                        15),
                                                                child: Column(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceEvenly,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: <
                                                                      Widget>[
                                                                    Row(
                                                                      children: [
                                                                        Icon(
                                                                          JamIcons
                                                                              .heart_f,
                                                                          color:
                                                                              Theme.of(context).accentColor,
                                                                          size:
                                                                              20,
                                                                        ),
                                                                        const SizedBox(
                                                                            width:
                                                                                5),
                                                                        Text(
                                                                          "Likes: ${Provider.of<FavouriteProvider>(context, listen: false).liked[widget.index]["fav"]}",
                                                                          style: Theme.of(context)
                                                                              .textTheme
                                                                              .headline6
                                                                              .copyWith(color: Theme.of(context).accentColor),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    Row(
                                                                      children: [
                                                                        Icon(
                                                                          JamIcons
                                                                              .eye,
                                                                          color:
                                                                              Theme.of(context).accentColor,
                                                                          size:
                                                                              20,
                                                                        ),
                                                                        const SizedBox(
                                                                            width:
                                                                                5),
                                                                        Text(
                                                                          "Views: ${Provider.of<FavouriteProvider>(context, listen: false).liked[widget.index]["views"]}",
                                                                          style: Theme.of(context)
                                                                              .textTheme
                                                                              .headline6
                                                                              .copyWith(color: Theme.of(context).accentColor),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    Row(
                                                                      children: [
                                                                        Icon(
                                                                          JamIcons
                                                                              .set_square,
                                                                          color:
                                                                              Theme.of(context).accentColor,
                                                                          size:
                                                                              20,
                                                                        ),
                                                                        const SizedBox(
                                                                            width:
                                                                                5),
                                                                        Text(
                                                                          Provider.of<FavouriteProvider>(context, listen: false)
                                                                              .liked[widget.index]["resolution"]
                                                                              .toString(),
                                                                          style: Theme.of(context)
                                                                              .textTheme
                                                                              .headline6
                                                                              .copyWith(color: Theme.of(context).accentColor),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              Align(
                                                                alignment: Alignment
                                                                    .bottomRight,
                                                                child:
                                                                    GestureDetector(
                                                                  onTap:
                                                                      () async {
                                                                    Navigator.pop(
                                                                        context);
                                                                  },
                                                                  child:
                                                                      Container(
                                                                    decoration: const BoxDecoration(
                                                                        color: Color(
                                                                            0xFF2F2F2F),
                                                                        borderRadius: BorderRadius.only(
                                                                            topLeft:
                                                                                Radius.circular(20),
                                                                            bottomRight: Radius.circular(20))),
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .all(0),
                                                                    child:
                                                                        Padding(
                                                                      padding:
                                                                          const EdgeInsets.fromLTRB(
                                                                              10,
                                                                              5,
                                                                              10,
                                                                              5),
                                                                      child:
                                                                          Icon(
                                                                        JamIcons
                                                                            .close,
                                                                        color: Theme.of(context)
                                                                            .accentColor,
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
                                    : Positioned(
                                        top: widget.childOffset.dy +
                                            widget.childSize.height * 2 / 8,
                                        left: widget.childOffset.dx,
                                        child: TweenAnimationBuilder(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          builder: (BuildContext context,
                                              double value, Widget child) {
                                            return Transform.scale(
                                              scale: value,
                                              alignment: Alignment.bottomRight,
                                              child: child,
                                            );
                                          },
                                          tween: Tween(begin: 0.0, end: 1.0),
                                          child: Container(
                                            width: widget.childSize.width,
                                            height:
                                                widget.childSize.height * 6 / 8,
                                            decoration: BoxDecoration(
                                              color:
                                                  Theme.of(context).hintColor,
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
                                                    padding: const EdgeInsets
                                                            .fromLTRB(
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
                                                            padding:
                                                                const EdgeInsets
                                                                        .fromLTRB(
                                                                    14,
                                                                    11,
                                                                    14,
                                                                    11),
                                                            backgroundColor:
                                                                Colors.black,
                                                            avatar: const Icon(
                                                                JamIcons.camera,
                                                                color: Colors
                                                                    .white,
                                                                size: 20),
                                                            label: Text(
                                                              PData
                                                                  .wallsC[widget
                                                                      .index]
                                                                  .photographer
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
                                                            PData.wallsC[widget.index].url
                                                                        .toString()
                                                                        .replaceAll(
                                                                            "https://www.pexels.com/photo/", "")
                                                                        .replaceAll(
                                                                            "-", " ")
                                                                        .replaceAll(
                                                                            "/", "")
                                                                        .length >
                                                                    8
                                                                ? PData.wallsC[widget.index].url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "")[0].toUpperCase() +
                                                                    PData.wallsC[widget.index].url
                                                                        .toString()
                                                                        .replaceAll(
                                                                            "https://www.pexels.com/photo/", "")
                                                                        .replaceAll(
                                                                            "-", " ")
                                                                        .replaceAll(
                                                                            "/", "")
                                                                        .substring(
                                                                            1,
                                                                            PData.wallsC[widget.index].url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "").length -
                                                                                7)
                                                                : PData.wallsC[widget.index].url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "")[0].toUpperCase() +
                                                                    PData
                                                                        .wallsC[widget.index]
                                                                        .url
                                                                        .toString()
                                                                        .replaceAll("https://www.pexels.com/photo/", "")
                                                                        .replaceAll("-", " ")
                                                                        .replaceAll("/", "")
                                                                        .substring(1),
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .headline5
                                                                .copyWith(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .accentColor),
                                                          ),
                                                        ),
                                                        Row(
                                                          children: [
                                                            const Icon(
                                                              JamIcons
                                                                  .set_square,
                                                              color: Colors
                                                                  .white70,
                                                              size: 20,
                                                            ),
                                                            const SizedBox(
                                                                width: 5),
                                                            Text(
                                                              "${PData.wallsC[widget.index].width.toString()}x${PData.wallsC[widget.index].height.toString()}",
                                                              style: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .headline6
                                                                  .copyWith(
                                                                      color: Theme.of(
                                                                              context)
                                                                          .accentColor),
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
                                                      onTap: () async {
                                                        Navigator.pop(context);
                                                      },
                                                      child: Container(
                                                        decoration: const BoxDecoration(
                                                            color: Color(
                                                                0xFF2F2F2F),
                                                            borderRadius: BorderRadius.only(
                                                                topLeft: Radius
                                                                    .circular(
                                                                        20),
                                                                bottomRight: Radius
                                                                    .circular(
                                                                        20))),
                                                        padding:
                                                            const EdgeInsets
                                                                .all(0),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                      .fromLTRB(
                                                                  10, 5, 10, 5),
                                                          child: Icon(
                                                            JamIcons.close,
                                                            color: Theme.of(
                                                                    context)
                                                                .accentColor,
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
                url: widget.provider == "WallHaven"
                    ? WData.walls[widget.index].path.toString()
                    : widget.provider == "Prism"
                        ? Data.subPrismWalls[widget.index]["wallpaper_url"]
                            .toString()
                        : widget.provider == "ProfileWall"
                            ? Provider.of<ProfileWallProvider>(context,
                                    listen: false)
                                .profileWalls[widget.index]["wallpaper_url"]
                                .toString()
                            : widget.provider == "UserProfileWall"
                                ? UserData.userProfileWalls[widget.index]
                                        ["wallpaper_url"]
                                    .toString()
                                : widget.provider == "Pexels"
                                    ? PData.wallsP[widget.index].src["original"]
                                        .toString()
                                    : widget.provider == "Liked"
                                        ? Provider.of<FavouriteProvider>(
                                                context,
                                                listen: false)
                                            .liked[widget.index]["url"]
                                            .toString()
                                        : PData.wallsC[widget.index]
                                            .src["original"]
                                            .toString(),
              ),
            ),
            Positioned(
              top: topOffset - fabHeartTopOffset,
              left: leftOffset - fabHeartLeftOffset,
              child: widget.provider == "WallHaven"
                  ? FavouriteWallpaperButton(
                      id: WData.walls[widget.index].id.toString(),
                      provider: "WallHaven",
                      wallhaven: WData.walls[widget.index],
                      trash: false,
                    )
                  : widget.provider == "Prism"
                      ? FavouriteWallpaperButton(
                          id: Data.subPrismWalls[widget.index]["id"].toString(),
                          provider: "Prism",
                          prism: Data.subPrismWalls[widget.index] as Map,
                          trash: false,
                        )
                      : widget.provider == "ProfileWall"
                          ? FavouriteWallpaperButton(
                              id: Provider.of<ProfileWallProvider>(context,
                                      listen: false)
                                  .profileWalls[widget.index]["id"]
                                  .toString(),
                              provider: "Prism",
                              prism: Provider.of<ProfileWallProvider>(context,
                                      listen: false)
                                  .profileWalls[widget.index] as Map,
                              trash: false,
                            )
                          : widget.provider == "UserProfileWall"
                              ? FavouriteWallpaperButton(
                                  id: UserData.userProfileWalls[widget.index]
                                          ["id"]
                                      .toString(),
                                  provider: "Prism",
                                  prism: UserData.userProfileWalls[widget.index]
                                      as Map,
                                  trash: false,
                                )
                              : widget.provider == "Pexels"
                                  ? FavouriteWallpaperButton(
                                      id: PData.wallsP[widget.index].id
                                          .toString(),
                                      provider: "Pexels",
                                      pexels: PData.wallsP[widget.index],
                                      trash: false,
                                    )
                                  : widget.provider == "Liked"
                                      ? FavouriteWallpaperButton(
                                          id: Provider.of<FavouriteProvider>(
                                                  context,
                                                  listen: false)
                                              .liked[widget.index]["id"]
                                              .toString(),
                                          provider:
                                              Provider.of<FavouriteProvider>(
                                                      context,
                                                      listen: false)
                                                  .liked[widget.index]
                                                      ["provider"]
                                                  .toString(),
                                          trash: true,
                                        )
                                      : FavouriteWallpaperButton(
                                          id: PData.wallsC[widget.index].id
                                              .toString(),
                                          provider: "Pexels",
                                          pexels: PData.wallsC[widget.index],
                                          trash: false,
                                        ),
            ),
            Positioned(
              top: topOffset + fabWallTopOffset,
              left: leftOffset + fabWallLeftOffset,
              child: DownloadButton(
                colorChanged: false,
                link: widget.provider == "WallHaven"
                    ? WData.walls[widget.index].path.toString()
                    : widget.provider == "Prism"
                        ? Data.subPrismWalls[widget.index]["wallpaper_url"]
                            .toString()
                        : widget.provider == "ProfileWall"
                            ? Provider.of<ProfileWallProvider>(context,
                                    listen: false)
                                .profileWalls[widget.index]["wallpaper_url"]
                                .toString()
                            : widget.provider == "UserProfileWall"
                                ? UserData.userProfileWalls[widget.index]
                                        ["wallpaper_url"]
                                    .toString()
                                : widget.provider == "Pexels"
                                    ? PData.wallsP[widget.index].src["original"]
                                        .toString()
                                    : widget.provider == "Liked"
                                        ? Provider.of<FavouriteProvider>(
                                                context,
                                                listen: false)
                                            .liked[widget.index]["url"]
                                            .toString()
                                        : PData.wallsC[widget.index]
                                            .src["original"]
                                            .toString(),
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
