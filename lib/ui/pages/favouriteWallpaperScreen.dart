import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/clockOverlay.dart';
import 'package:Prism/ui/widgets/downloadButton.dart';
import 'package:Prism/ui/widgets/favWallpaperButton.dart';
import 'package:Prism/ui/widgets/setWallpaperButton.dart';
import 'package:Prism/ui/widgets/shareButton.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optimized_cached_image/widgets.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

class FavWallpaperViewScreen extends StatefulWidget {
  final List arguments;
  FavWallpaperViewScreen({this.arguments});

  @override
  _FavWallpaperViewScreenState createState() => _FavWallpaperViewScreenState();
}

class _FavWallpaperViewScreenState extends State<FavWallpaperViewScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int index;
  String thumb;
  bool isLoading = true;
  PaletteGenerator paletteGenerator;
  List<Color> colors;

  Future<void> _updatePaletteGenerator() async {
    setState(() {
      isLoading = true;
    });
    paletteGenerator = await PaletteGenerator.fromImageProvider(
      new NetworkImage(thumb),
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
    index = widget.arguments[0];
    thumb = widget.arguments[1];
    isLoading = true;
    _updatePaletteGenerator();
    super.initState();
  }

  void _showBottomSheetCallback() {
    _scaffoldKey.currentState.showBottomSheet<void>(
      (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * .42,
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            color: Color(0xFF2F2F2F),
          ),
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
                      return GestureDetector(
                          child: Container(
                            decoration: BoxDecoration(
                              color: colors[color],
                              borderRadius: BorderRadius.circular(500),
                            ),
                            height: MediaQuery.of(context).size.width / 8,
                            width: MediaQuery.of(context).size.width / 8,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            SystemChrome.setEnabledSystemUIOverlays(
                                [SystemUiOverlay.top, SystemUiOverlay.bottom]);
                            Navigator.pushNamed(
                              context,
                              ColorRoute,
                              arguments: [
                                colors[color]
                                    .toString()
                                    .replaceAll("Color(0xff", "")
                                    .replaceAll(")", ""),
                              ],
                            );
                          });
                    },
                  ),
                ),
              ),
              Provider.of<FavouriteProvider>(context, listen: false)
                          .liked[index]["provider"] ==
                      "WallHaven"
                  ? Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(35, 0, 35, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(0, 5, 0, 10),
                                  child: Text(
                                    Provider.of<FavouriteProvider>(context,
                                            listen: false)
                                        .liked[index]["id"]
                                        .toString()
                                        .toUpperCase(),
                                    style:
                                        Theme.of(context).textTheme.bodyText1,
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
                                      "${Provider.of<FavouriteProvider>(context, listen: false).liked[index]["views"].toString()}",
                                      style:
                                          Theme.of(context).textTheme.bodyText2,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 5),
                                Row(
                                  children: [
                                    Icon(
                                      JamIcons.heart_f,
                                      size: 20,
                                      color: Colors.white70,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      "${Provider.of<FavouriteProvider>(context, listen: false).liked[index]["fav"].toString()}",
                                      style:
                                          Theme.of(context).textTheme.bodyText2,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 5),
                                Row(
                                  children: [
                                    Icon(
                                      JamIcons.save,
                                      size: 20,
                                      color: Colors.white70,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      "${double.parse(((double.parse(Provider.of<FavouriteProvider>(context, listen: false).liked[index]["size"].toString()) / 1000000).toString())).toStringAsFixed(2)} MB",
                                      style:
                                          Theme.of(context).textTheme.bodyText2,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(0, 0, 0, 0),
                                  child: Row(
                                    children: [
                                      Text(
                                        Provider.of<FavouriteProvider>(context,
                                                    listen: false)
                                                .liked[index]["category"]
                                                .toString()[0]
                                                .toUpperCase() +
                                            Provider.of<FavouriteProvider>(
                                                    context,
                                                    listen: false)
                                                .liked[index]["category"]
                                                .toString()
                                                .substring(1),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyText2,
                                      ),
                                      SizedBox(width: 10),
                                      Icon(
                                        JamIcons.unordered_list,
                                        size: 20,
                                        color: Colors.white70,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 5),
                                Row(
                                  children: [
                                    Text(
                                      "${Provider.of<FavouriteProvider>(context, listen: false).liked[index]["resolution"].toString()}",
                                      style:
                                          Theme.of(context).textTheme.bodyText2,
                                    ),
                                    SizedBox(width: 10),
                                    Icon(
                                      JamIcons.set_square,
                                      size: 20,
                                      color: Colors.white70,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 5),
                                Row(
                                  children: [
                                    Text(
                                      Provider.of<FavouriteProvider>(context,
                                              listen: false)
                                          .liked[index]["provider"]
                                          .toString(),
                                      style:
                                          Theme.of(context).textTheme.bodyText2,
                                    ),
                                    SizedBox(width: 10),
                                    Icon(
                                      JamIcons.database,
                                      size: 20,
                                      color: Colors.white70,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  : Provider.of<FavouriteProvider>(context, listen: false)
                              .liked[index]["provider"] ==
                          "Pexels"
                      ? Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(35, 0, 35, 15),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Padding(
                                //   padding:
                                //       const EdgeInsets.fromLTRB(0, 5, 0, 10),
                                //   child: Container(
                                //     width:
                                //         MediaQuery.of(context).size.width * .8,
                                //     child: Text(
                                //       Provider.of<FavouriteProvider>(context,
                                //               listen: false)
                                //           .liked[index]["id"]
                                //           .toString()
                                //           .toUpperCase(),
                                //       style:
                                //           Theme.of(context).textTheme.bodyText1,
                                //       overflow: TextOverflow.ellipsis,
                                //       maxLines: 1,
                                //     ),
                                //   ),
                                // ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Row(
                                          children: [
                                            Icon(
                                              JamIcons.camera,
                                              size: 20,
                                              color: Colors.white70,
                                            ),
                                            SizedBox(width: 10),
                                            Container(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  .4,
                                              child: Text(
                                                Provider.of<FavouriteProvider>(
                                                        context,
                                                        listen: false)
                                                    .liked[index]
                                                        ["photographer"]
                                                    .toString(),
                                                textAlign: TextAlign.left,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyText2,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 5),
                                        Row(
                                          children: [
                                            Icon(
                                              JamIcons.set_square,
                                              size: 20,
                                              color: Colors.white70,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              Provider.of<FavouriteProvider>(
                                                      context,
                                                      listen: false)
                                                  .liked[index]["resolution"],
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyText2,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: <Widget>[
                                        Row(
                                          children: [
                                            Text(
                                              Provider.of<FavouriteProvider>(
                                                      context,
                                                      listen: false)
                                                  .liked[index]["id"]
                                                  .toString(),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyText2,
                                            ),
                                            SizedBox(width: 10),
                                            Icon(
                                              JamIcons.info,
                                              size: 20,
                                              color: Colors.white70,
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 5),
                                        Row(
                                          children: [
                                            Text(
                                              Provider.of<FavouriteProvider>(
                                                      context,
                                                      listen: false)
                                                  .liked[index]["provider"]
                                                  .toString(),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyText2,
                                            ),
                                            SizedBox(width: 10),
                                            Icon(
                                              JamIcons.database,
                                              size: 20,
                                              color: Colors.white70,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                      : Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(35, 0, 35, 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          0, 5, 0, 10),
                                      child: Text(
                                        Provider.of<FavouriteProvider>(context,
                                                listen: false)
                                            .liked[index]["id"]
                                            .toString()
                                            .toUpperCase(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyText1,
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
                                          "${Provider.of<FavouriteProvider>(context, listen: false).liked[index]["views"].toString()}",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText2,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Icon(
                                          JamIcons.heart_f,
                                          size: 20,
                                          color: Colors.white70,
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          "${Provider.of<FavouriteProvider>(context, listen: false).liked[index]["fav"].toString()}",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText2,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Text(
                                          "${Provider.of<FavouriteProvider>(context, listen: false).liked[index]["resolution"].toString()}",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText2,
                                        ),
                                        SizedBox(width: 10),
                                        Icon(
                                          JamIcons.set_square,
                                          size: 20,
                                          color: Colors.white70,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Text(
                                          "${double.parse(((double.parse(Provider.of<FavouriteProvider>(context, listen: false).liked[index]["size"].toString()) / 1000000).toString())).toStringAsFixed(2)} MB",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText2,
                                        ),
                                        SizedBox(width: 10),
                                        Icon(
                                          JamIcons.save,
                                          size: 20,
                                          color: Colors.white70,
                                        ),
                                      ],
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
                    DownloadButton(
                      link:
                          Provider.of<FavouriteProvider>(context, listen: false)
                              .liked[index]["url"],
                    ),
                    SetWallpaperButton(),
                    FavouriteWallpaperButton(
                      id: Provider.of<FavouriteProvider>(context, listen: false)
                          .liked[index]["id"]
                          .toString(),
                      provider:
                          Provider.of<FavouriteProvider>(context, listen: false)
                              .liked[index]["provider"]
                              .toString(),
                    ),
                    ShareButton(
                        id: Provider.of<FavouriteProvider>(context,
                                listen: false)
                            .liked[index]["id"],
                        provider: Provider.of<FavouriteProvider>(context,
                                listen: false)
                            .liked[index]["provider"],
                        url: Provider.of<FavouriteProvider>(context,
                                listen: false)
                            .liked[index]["url"],
                        thumbUrl: Provider.of<FavouriteProvider>(context,
                                listen: false)
                            .liked[index]["thumb"])
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    SystemChrome.setEnabledSystemUIOverlays(
        [SystemUiOverlay.top, SystemUiOverlay.bottom]);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIOverlays([]);
    // try {
    return Provider.of<FavouriteProvider>(context, listen: false).liked[index]
                    ["provider"] ==
                "WallHaven" ||
            Provider.of<FavouriteProvider>(context, listen: false).liked[index]
                    ["provider"] ==
                "Pexels"
        ? Scaffold(
            key: _scaffoldKey,
            backgroundColor:
                isLoading ? Theme.of(context).primaryColor : colors[0],
            body: Stack(
              children: <Widget>[
                OptimizedCacheImage(
                  imageUrl:
                      Provider.of<FavouriteProvider>(context, listen: false)
                          .liked[index]["url"],
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
                          isLoading
                              ? Theme.of(context).accentColor
                              : colors[0].computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    child: Center(
                      child: Icon(
                        JamIcons.close_circle_f,
                        color: isLoading
                            ? Theme.of(context).accentColor
                            : colors[0].computeLuminance() > 0.5
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
                    onTap: !isLoading
                        ? () {
                            return _showBottomSheetCallback();
                          }
                        : () {
                            toasts.info("Information is Loading, please wait!");
                          },
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
                      color: isLoading
                          ? Theme.of(context).accentColor
                          : colors[0].computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                      icon: Icon(
                        JamIcons.chevron_left,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconButton(
                      onPressed: () {
                        var link = Provider.of<FavouriteProvider>(context,
                                listen: false)
                            .liked[index]["url"];
                        Navigator.push(
                            context,
                            PageRouteBuilder(
                                transitionDuration: Duration(milliseconds: 300),
                                pageBuilder:
                                    (context, animation, secondaryAnimation) {
                                  animation = Tween(begin: 0.0, end: 1.0)
                                      .animate(animation);
                                  return FadeTransition(
                                      opacity: animation,
                                      child: ClockOverlay(
                                        link: link,
                                      ));
                                },
                                fullscreenDialog: true,
                                opaque: false));
                      },
                      color: isLoading
                          ? Theme.of(context).accentColor
                          : colors[0].computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                      icon: Icon(
                        JamIcons.clock,
                      ),
                    ),
                  ),
                )
              ],
            ),
          )
        :
        // Provider.of<FavouriteProvider>(context, listen: false).liked[index]
        //             ["provider"] ==
        //         "Pexels"
        //     ?
        Scaffold(
            key: _scaffoldKey,
            backgroundColor:
                isLoading ? Theme.of(context).primaryColor : colors[0],
            body: Stack(
              children: <Widget>[
                OptimizedCacheImage(
                  imageUrl:
                      "https://w.wallhaven.cc/full/${Provider.of<FavouriteProvider>(context, listen: false).liked[index]["id"].toString().substring(0, 2)}/wallhaven-${Provider.of<FavouriteProvider>(context, listen: false).liked[index]["id"]}.${Provider.of<FavouriteProvider>(context, listen: false).liked[index]["thumb"].toString().substring(Provider.of<FavouriteProvider>(context, listen: false).liked[index]["thumb"].toString().length - 3, Provider.of<FavouriteProvider>(context, listen: false).liked[index]["thumb"].toString().length)}",
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
                          isLoading
                              ? Theme.of(context).accentColor
                              : colors[0].computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    child: Center(
                      child: Icon(
                        JamIcons.close_circle_f,
                        color: isLoading
                            ? Theme.of(context).accentColor
                            : colors[0].computeLuminance() > 0.5
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
                    onTap: !isLoading
                        ? () {
                            return _showBottomSheetCallback();
                          }
                        : () {
                            toasts.info("Information is Loading, please wait!");
                          },
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
                      color: isLoading
                          ? Theme.of(context).accentColor
                          : colors[0].computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                      icon: Icon(
                        JamIcons.chevron_left,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconButton(
                      onPressed: () {
                        var link =
                            "https://w.wallhaven.cc/full/${Provider.of<FavouriteProvider>(context, listen: false).liked[index]["id"].toString().substring(0, 2)}/wallhaven-${Provider.of<FavouriteProvider>(context, listen: false).liked[index]["id"]}.${Provider.of<FavouriteProvider>(context, listen: false).liked[index]["thumb"].toString().substring(Provider.of<FavouriteProvider>(context, listen: false).liked[index]["thumb"].toString().length - 3, Provider.of<FavouriteProvider>(context, listen: false).liked[index]["thumb"].toString().length)}";
                        Navigator.push(
                            context,
                            PageRouteBuilder(
                                transitionDuration: Duration(milliseconds: 300),
                                pageBuilder:
                                    (context, animation, secondaryAnimation) {
                                  animation = Tween(begin: 0.0, end: 1.0)
                                      .animate(animation);
                                  return FadeTransition(
                                      opacity: animation,
                                      child: ClockOverlay(
                                        link: link,
                                      ));
                                },
                                fullscreenDialog: true,
                                opaque: false));
                      },
                      color: isLoading
                          ? Theme.of(context).accentColor
                          : colors[0].computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                      icon: Icon(
                        JamIcons.clock,
                      ),
                    ),
                  ),
                )
              ],
            ),
          );
  }
}
