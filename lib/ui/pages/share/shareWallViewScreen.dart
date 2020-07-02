import 'package:Prism/data/pexels/model/wallpaperp.dart';
import 'package:Prism/data/pexels/provider/pexels.dart';
import 'package:Prism/data/wallhaven/model/wallpaper.dart';
import 'package:Prism/data/wallhaven/provider/wallhaven.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/clockOverlay.dart';
import 'package:Prism/ui/widgets/menuButton/downloadButton.dart';
import 'package:Prism/ui/widgets/menuButton/favWallpaperButton.dart';
import 'package:Prism/ui/widgets/menuButton/setWallpaperButton.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optimized_cached_image/widgets.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class ShareWallpaperViewScreen extends StatefulWidget {
  final List arguments;
  ShareWallpaperViewScreen({this.arguments});

  @override
  _ShareWallpaperViewScreenState createState() =>
      _ShareWallpaperViewScreenState();
}

class _ShareWallpaperViewScreenState extends State<ShareWallpaperViewScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String id;
  String provider;
  String url;
  String thumb;
  bool isLoading = true;
  PaletteGenerator paletteGenerator;
  List<Color> colors;
  Future future;
  PanelController panelController = PanelController();
  var image;
  Future<void> _updatePaletteGenerator() async {
    setState(() {
      isLoading = true;
    });
    try {
      image = new OptimizedCacheImageProvider(thumb, errorListener: () {
        colors = [
          Color(0xFFFFFFFF),
          Color(0xFFc7c7c7),
          Color(0xFF848484),
          Color(0xFF3d3d3d),
          Color(0xFF000000)
        ];
      });
    } catch (e) {
      // toasts.error(e.toString());
    }
    paletteGenerator = await PaletteGenerator.fromImageProvider(image,
        maximumColorCount: 20, timeout: Duration(seconds: 120));
    setState(() {
      isLoading = false;
    });
    colors = paletteGenerator.colors.toList();
    print(colors.toString());
    if (paletteGenerator.colors.length > 5) {
      colors = colors.sublist(0, 5);
    }
  }

  @override
  void initState() {
    id = widget.arguments[0];
    provider = widget.arguments[1];
    url = widget.arguments[2];
    thumb = widget.arguments[3];
    isLoading = true;
    if (provider == "WallHaven") {
      future = Provider.of<WallHavenProvider>(context, listen: false)
          .getWallbyID(id);
    } else if (provider == "Pexels") {
      future =
          Provider.of<PexelsProvider>(context, listen: false).getWallbyIDP(id);
    }
    _updatePaletteGenerator();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    SystemChrome.setEnabledSystemUIOverlays(
        [SystemUiOverlay.top, SystemUiOverlay.bottom]);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIOverlays([SystemUiOverlay.bottom]);

    return provider == "WallHaven"
        ? Scaffold(
            key: _scaffoldKey,
            backgroundColor:
                isLoading ? Theme.of(context).primaryColor : colors[0],
            body: SlidingUpPanel(
              backdropEnabled: true,
              backdropTapClosesPanel: true,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [],
              collapsed: Container(
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
                  )),
                ),
              ),
              minHeight: MediaQuery.of(context).size.height / 20,
              parallaxEnabled: true,
              parallaxOffset: 0.54,
              color: Color(0xFF2F2F2F),
              maxHeight: MediaQuery.of(context).size.height * .46,
              controller: panelController,
              panel: Container(
                height: MediaQuery.of(context).size.height * .42,
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  color: Color(0xFF2F2F2F),
                ),
                child: FutureBuilder<WallPaper>(
                    future: future,
                    builder: (context, AsyncSnapshot<WallPaper> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting ||
                          snapshot.connectionState == ConnectionState.none) {
                        print("snapshot none, waiting in share route");
                        return CircularProgressIndicator();
                      } else {
                        print("done");
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Center(
                                child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Icon(
                                JamIcons.chevron_down,
                                color: Colors.white,
                              ),
                            )),
                            Expanded(
                              flex: 2,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: List.generate(
                                  colors == null ? 5 : colors.length,
                                  (color) {
                                    return GestureDetector(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: colors == null
                                                ? Color(0xFF000000)
                                                : colors[color],
                                            borderRadius:
                                                BorderRadius.circular(500),
                                          ),
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .width /
                                              8,
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width /
                                              8,
                                        ),
                                        onTap: () {
                                          // String route = currentRoute;
                                          // currentRoute = previousRoute;
                                          // previousRoute = route;
                                          // print(currentRoute);
                                          SystemChrome
                                              .setEnabledSystemUIOverlays([
                                            SystemUiOverlay.top,
                                            SystemUiOverlay.bottom
                                          ]);
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
                            Expanded(
                              flex: 4,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(35, 0, 35, 10),
                                child: Row(
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
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              0, 5, 0, 10),
                                          child: Text(
                                            id.toString().toUpperCase(),
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
                                              "${Provider.of<WallHavenProvider>(context).wall == null ? 0 : Provider.of<WallHavenProvider>(context).wall.views.toString()}",
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
                                              "${Provider.of<WallHavenProvider>(context).wall == null ? 0 : Provider.of<WallHavenProvider>(context).wall.favourites.toString()}",
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
                                              JamIcons.save,
                                              size: 20,
                                              color: Colors.white70,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              "${Provider.of<WallHavenProvider>(context).wall == null ? 0 : (double.parse(((double.parse(Provider.of<WallHavenProvider>(context).wall.file_size.toString()) / 1000000).toString())).toStringAsFixed(2))} MB",
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
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              0, 0, 0, 0),
                                          child: Row(
                                            children: [
                                              Text(
                                                Provider.of<WallHavenProvider>(
                                                                context)
                                                            .wall ==
                                                        null
                                                    ? "General"
                                                    : (Provider.of<WallHavenProvider>(
                                                                context)
                                                            .wall
                                                            .category
                                                            .toString()[0]
                                                            .toUpperCase() +
                                                        Provider.of<WallHavenProvider>(
                                                                context)
                                                            .wall
                                                            .category
                                                            .toString()
                                                            .substring(1)),
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
                                              "${Provider.of<WallHavenProvider>(context).wall == null ? 0x0 : Provider.of<WallHavenProvider>(context).wall.resolution.toString()}",
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
                                              provider.toString(),
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
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: <Widget>[
                                  DownloadButton(
                                      link: Provider.of<WallHavenProvider>(
                                                      context)
                                                  .wall ==
                                              null
                                          ? ""
                                          : Provider.of<WallHavenProvider>(
                                                  context)
                                              .wall
                                              .path
                                              .toString()),
                                  SetWallpaperButton(
                                    url: Provider.of<WallHavenProvider>(context)
                                                .wall ==
                                            null
                                        ? ""
                                        : Provider.of<WallHavenProvider>(
                                                context)
                                            .wall
                                            .path
                                            .toString(),
                                  ),
                                  FavouriteWallpaperButton(
                                    id: Provider.of<WallHavenProvider>(context)
                                                .wall ==
                                            null
                                        ? ""
                                        : Provider.of<WallHavenProvider>(
                                                context)
                                            .wall
                                            .id
                                            .toString(),
                                    provider: "WallHaven",
                                    wallhaven:
                                        Provider.of<WallHavenProvider>(context)
                                                    .wall ==
                                                null
                                            ? WallPaper()
                                            : Provider.of<WallHavenProvider>(
                                                    context)
                                                .wall,
                                    trash: false,
                                  )
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                    }),
              ),
              body: Stack(
                children: <Widget>[
                  GestureDetector(
                      child: OptimizedCacheImage(
                        imageUrl: url,
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
                      onPanUpdate: (details) {
                        if (details.delta.dy < -10) {
                          print(details.delta.dy);
                          panelController.open();
                        }
                      }),
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IconButton(
                        onPressed: () {
                          String route = currentRoute;
                          currentRoute = previousRoute;
                          previousRoute = route;
                          print(currentRoute);
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
                          var link = url;
                          Navigator.push(
                              context,
                              PageRouteBuilder(
                                  transitionDuration:
                                      Duration(milliseconds: 300),
                                  pageBuilder:
                                      (context, animation, secondaryAnimation) {
                                    animation = Tween(begin: 0.0, end: 1.0)
                                        .animate(animation);
                                    return FadeTransition(
                                        opacity: animation,
                                        child: ClockOverlay(
                                          link: link,
                                          file: false,
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
            ),
          )
        : provider == "Pexels"
            ? Scaffold(
                key: _scaffoldKey,
                backgroundColor:
                    isLoading ? Theme.of(context).primaryColor : colors[0],
                body: SlidingUpPanel(
                  backdropEnabled: true,
                  backdropTapClosesPanel: true,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [],
                  collapsed: Container(
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
                      )),
                    ),
                  ),
                  minHeight: MediaQuery.of(context).size.height / 20,
                  parallaxEnabled: true,
                  parallaxOffset: 0.54,
                  color: Color(0xFF2F2F2F),
                  maxHeight: MediaQuery.of(context).size.height * .46,
                  controller: panelController,
                  panel: Container(
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
                            child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Icon(
                            JamIcons.chevron_down,
                            color: Colors.white,
                          ),
                        )),
                        Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              colors == null ? 5 : colors.length,
                              (color) {
                                return GestureDetector(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: colors == null
                                            ? Color(0xFF000000)
                                            : colors[color],
                                        borderRadius:
                                            BorderRadius.circular(500),
                                      ),
                                      height:
                                          MediaQuery.of(context).size.width / 8,
                                      width:
                                          MediaQuery.of(context).size.width / 8,
                                    ),
                                    onTap: () {
                                      // String route = currentRoute;
                                      // currentRoute = previousRoute;
                                      // previousRoute = route;
                                      // print(currentRoute);
                                      SystemChrome.setEnabledSystemUIOverlays([
                                        SystemUiOverlay.top,
                                        SystemUiOverlay.bottom
                                      ]);
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
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(35, 0, 35, 15),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(0, 5, 0, 10),
                                  child: Container(
                                    width:
                                        MediaQuery.of(context).size.width * .8,
                                    child: Text(
                                      Provider.of<PexelsProvider>(context).wall ==
                                              null
                                          ? "Wallpaper"
                                          : (Provider.of<PexelsProvider>(context).wall.url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "").length > 8
                                              ? Provider.of<PexelsProvider>(context)
                                                      .wall
                                                      .url
                                                      .toString()
                                                      .replaceAll(
                                                          "https://www.pexels.com/photo/", "")
                                                      .replaceAll("-", " ")
                                                      .replaceAll("/", "")[0]
                                                      .toUpperCase() +
                                                  Provider.of<PexelsProvider>(context)
                                                      .wall
                                                      .url
                                                      .toString()
                                                      .replaceAll(
                                                          "https://www.pexels.com/photo/", "")
                                                      .replaceAll("-", " ")
                                                      .replaceAll("/", "")
                                                      .substring(
                                                          1,
                                                          Provider.of<PexelsProvider>(context).wall.url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "").length -
                                                              7)
                                              : Provider.of<PexelsProvider>(context)
                                                      .wall
                                                      .url
                                                      .toString()
                                                      .replaceAll(
                                                          "https://www.pexels.com/photo/", "")
                                                      .replaceAll("-", " ")
                                                      .replaceAll("/", "")[0]
                                                      .toUpperCase() +
                                                  Provider.of<PexelsProvider>(context)
                                                      .wall
                                                      .url
                                                      .toString()
                                                      .replaceAll(
                                                          "https://www.pexels.com/photo/", "")
                                                      .replaceAll("-", " ")
                                                      .replaceAll("/", "")
                                                      .substring(1)),
                                      style:
                                          Theme.of(context).textTheme.bodyText1,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
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
                                                Provider.of<PexelsProvider>(
                                                                context)
                                                            .wall ==
                                                        null
                                                    ? "Photographer"
                                                    : Provider.of<
                                                                PexelsProvider>(
                                                            context)
                                                        .wall
                                                        .photographer
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
                                              "${Provider.of<PexelsProvider>(context).wall == null ? 0 : Provider.of<PexelsProvider>(context).wall.width.toString()}x${Provider.of<PexelsProvider>(context).wall == null ? 0 : Provider.of<PexelsProvider>(context).wall.height.toString()}",
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
                                              id.toString(),
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
                                              provider.toString(),
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
                        ),
                        Expanded(
                          flex: 3,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: <Widget>[
                              DownloadButton(
                                link: url.toString(),
                              ),
                              SetWallpaperButton(
                                url: url.toString(),
                              ),
                              FavouriteWallpaperButton(
                                id: Provider.of<PexelsProvider>(context,
                                                listen: false)
                                            .wall ==
                                        null
                                    ? ""
                                    : Provider.of<PexelsProvider>(context,
                                            listen: false)
                                        .wall
                                        .id
                                        .toString(),
                                provider: "Pexels",
                                pexels:
                                    Provider.of<PexelsProvider>(context).wall ==
                                            null
                                        ? WallPaperP()
                                        : Provider.of<PexelsProvider>(context,
                                                listen: false)
                                            .wall,
                                trash: false,
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  body: Stack(
                    children: <Widget>[
                      GestureDetector(
                          child: OptimizedCacheImage(
                            imageUrl: url,
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
                          onPanUpdate: (details) {
                            if (details.delta.dy < -10) {
                              print(details.delta.dy);
                              panelController.open();
                            }
                          }),
                      Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: IconButton(
                            onPressed: () {
                              String route = currentRoute;
                              currentRoute = previousRoute;
                              previousRoute = route;
                              print(currentRoute);
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
                              var link = url;
                              Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                      transitionDuration:
                                          Duration(milliseconds: 300),
                                      pageBuilder: (context, animation,
                                          secondaryAnimation) {
                                        animation = Tween(begin: 0.0, end: 1.0)
                                            .animate(animation);
                                        return FadeTransition(
                                            opacity: animation,
                                            child: ClockOverlay(
                                              link: link,
                                              file: false,
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
                ),
              )
            : Container();
  }
}
