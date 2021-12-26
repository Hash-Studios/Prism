import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/data/informatics/dataManager.dart';
import 'package:Prism/data/profile/wallpaper/getUserProfile.dart' as user_data;
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/home/core/collapsedPanel.dart';
import 'package:Prism/ui/widgets/home/core/colorBar.dart';
import 'package:Prism/ui/widgets/home/wallpapers/clockOverlay.dart';
import 'package:Prism/ui/widgets/menuButton/downloadButton.dart';
import 'package:Prism/ui/widgets/menuButton/editButton.dart';
import 'package:Prism/ui/widgets/menuButton/favWallpaperButton.dart';
import 'package:Prism/ui/widgets/menuButton/setWallpaperButton.dart';
import 'package:Prism/ui/widgets/menuButton/shareButton.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:sliding_up_panel/sliding_up_panel.dart';

class UserProfileWallViewScreen extends StatefulWidget {
  final List? arguments;
  const UserProfileWallViewScreen({this.arguments});

  @override
  _UserProfileWallViewScreenState createState() =>
      _UserProfileWallViewScreenState();
}

class _UserProfileWallViewScreenState extends State<UserProfileWallViewScreen>
    with SingleTickerProviderStateMixin {
  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    logger.d(navStack.toString());
    return true;
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey genKey = GlobalKey();
  late int index;
  late String thumb;
  String? path;
  int progress = 0;
  bool downloading = false;
  bool applying = false;
  bool downloaded = false;
  final ReceivePort _port = ReceivePort();
  bool isLoading = true;
  late PaletteGenerator paletteGenerator;
  List<Color?>? colors;
  Color? accent;
  bool colorChanged = false;
  String? downloadLinkBackwards;
  late File _imageFile;
  bool screenshotTaken = false;
  PanelController panelController = PanelController();
  late AnimationController shakeController;
  bool panelClosed = true;
  bool panelCollapsed = true;
  Future<String>? _futureView;

  Future<void> _updatePaletteGenerator() async {
    setState(() {
      isLoading = true;
    });
    await Future.delayed(const Duration(milliseconds: 500)).then((value) async {
      paletteGenerator = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(thumb),
        maximumColorCount: 20,
      );
    });
    setState(() {
      isLoading = false;
    });
    colors = paletteGenerator.colors.toList();
    if (paletteGenerator.colors.length > 5) {
      colors = colors!.sublist(0, 5);
    }
    setState(() {
      accent = colors![0];
    });
    if (accent!.computeLuminance() > 0.5) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark
          .copyWith(statusBarIconBrightness: Brightness.dark));
    } else {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark
          .copyWith(statusBarIconBrightness: Brightness.light));
    }
  }

  void updateAccent() {
    if (colors!.contains(accent)) {
      final index = colors!.indexOf(accent);
      setState(() {
        accent = colors![(index + 1) % 5];
      });
      setState(() {
        colorChanged = true;
      });
      if (accent!.computeLuminance() > 0.5) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark
            .copyWith(statusBarIconBrightness: Brightness.dark));
      } else {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark
            .copyWith(statusBarIconBrightness: Brightness.light));
      }
    }
  }

  Future<File> _capturePng() async {
    final RenderRepaintBoundary boundary =
        genKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 3);
    final directory = (await getTemporaryDirectory()).path;
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List pngBytes = byteData!.buffer.asUint8List();
    final r = Random();
    String rNum = "";
    for (var i = 0; i < 6; i++) {
      rNum = "$rNum${r.nextInt(9)}";
    }
    final File imgFile = File('$directory/photo_$rNum.png');
    await imgFile.writeAsBytes(pngBytes);
    logger.d(imgFile.path);
    return imgFile;
  }

  void setupDownloader() {
    initPlatformState();
    ui.IsolateNameServer.registerPortWithName(
        _port.sendPort, 'downloader_send_port');
    _port.listen((dynamic data) {
      // String id = data[0];
      final DownloadTaskStatus status = data[1] as DownloadTaskStatus;
      if (status == const DownloadTaskStatus(3)) {
        setState(() {
          downloaded = true;
        });
        toasts.codeSend("Wall Downloaded in Downloads!");
      }
      setState(() {
        if (status == const DownloadTaskStatus(2)) {
          downloading = true;
          progress = data[2] as int;
        } else {
          downloading = false;
          progress = 0;
        }
      });
    });
    FlutterDownloader.registerCallback(callback);
  }

  void _setPath() async {
    path = (await _findLocalPath())!;
    final savedDir = Directory(path ?? "");
    final bool hasExisted = await savedDir.exists();
    if (!hasExisted) {
      savedDir.create();
    }
  }

  @override
  void initState() {
    super.initState();
    shakeController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    setupDownloader();
    index = widget.arguments![0] as int;
    thumb = widget.arguments![1].toString();
    isLoading = true;
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      updateViews(
          Provider.of<user_data.UserProfileProvider>(context, listen: false)
              .userProfileWalls![index]
              .data()["id"]
              .toString()
              .toUpperCase());
      _futureView = getViews(
          Provider.of<user_data.UserProfileProvider>(context, listen: false)
              .userProfileWalls![index]
              .data()["id"]
              .toString()
              .toUpperCase());
    });
    _updatePaletteGenerator();
  }

  Future<void> initPlatformState() async {
    _setPath();
    if (!mounted) return;
  }

  Future<String?> _findLocalPath() async {
    String? externalStorageDirPath;
    if (Platform.isAndroid) {
      try {
        externalStorageDirPath = "/storage/emulated/0/Download";
      } catch (e) {
        final directory = await getExternalStorageDirectory();
        externalStorageDirPath = directory?.path;
      }
    } else if (Platform.isIOS) {
      externalStorageDirPath =
          (await getApplicationDocumentsDirectory()).absolute.path;
    }
    return externalStorageDirPath;
  }

  static void callback(String id, DownloadTaskStatus status, int progress) {
    final SendPort? send =
        ui.IsolateNameServer.lookupPortByName('downloader_send_port');
    send?.send([id, status, progress]);
  }

  @override
  void dispose() {
    shakeController.dispose();
    ui.IsolateNameServer.removePortNameMapping('downloader_send_port');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> offsetAnimation = Tween(begin: 0.0, end: 48.0)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(shakeController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          shakeController.reverse();
        }
      });
    return WillPopScope(
        onWillPop: onWillPop,
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: isLoading ? Theme.of(context).primaryColor : accent,
          body: SlidingUpPanel(
            onPanelOpened: () {
              setState(() {
                panelCollapsed = false;
              });
              if (panelClosed) {
                logger.d('Screenshot Starting');
              }
            },
            onPanelClosed: () {
              setState(() {
                panelCollapsed = true;
              });
              setState(() {
                panelClosed = true;
              });
            },
            backdropEnabled: true,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: const [],
            collapsed: CollapsedPanel(
              panelCollapsed: panelCollapsed,
              panelController: panelController,
            ),
            minHeight: MediaQuery.of(context).size.height / 20,
            parallaxEnabled: true,
            parallaxOffset: 0.00,
            color: Colors.transparent,
            maxHeight: MediaQuery.of(context).size.height * .43,
            controller: panelController,
            panel: Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              height: MediaQuery.of(context).size.height * .43,
              width: MediaQuery.of(context).size.width,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 750),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: panelCollapsed
                          ? Theme.of(context).primaryColor.withOpacity(1)
                          : Theme.of(context).primaryColor.withOpacity(.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Center(
                            child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: AnimatedOpacity(
                            duration: const Duration(),
                            opacity: panelCollapsed ? 0.0 : 1.0,
                            child: GestureDetector(
                              onTap: () {
                                panelController.close();
                              },
                              child: Icon(
                                JamIcons.chevron_down,
                                color: Theme.of(context).accentColor,
                              ),
                            ),
                          ),
                        )),
                        ColorBar(colors: colors),
                        Expanded(
                          flex: 8,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(35, 0, 35, 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                          0.36,
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            0, 5, 0, 10),
                                        child: Row(
                                          children: [
                                            Text(
                                              Provider.of<
                                                          user_data
                                                              .UserProfileProvider>(
                                                      context)
                                                  .userProfileWalls![index]
                                                  .data()["id"]
                                                  .toString()
                                                  .toUpperCase(),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyText1!
                                                  .copyWith(
                                                      color: Theme.of(context)
                                                          .accentColor),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6.0),
                                              child: Container(
                                                height: 20,
                                                color: Theme.of(context)
                                                    .accentColor,
                                                width: 2,
                                              ),
                                            ),
                                            FutureBuilder(
                                              future: _futureView,
                                              builder: (context, snapshot) {
                                                switch (
                                                    snapshot.connectionState) {
                                                  case ConnectionState.waiting:
                                                    return Text(
                                                      "",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyText1!
                                                          .copyWith(
                                                              color: Theme.of(
                                                                      context)
                                                                  .accentColor,
                                                              fontSize: 16),
                                                    );
                                                  case ConnectionState.none:
                                                    return Text(
                                                      "",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyText1!
                                                          .copyWith(
                                                              color: Theme.of(
                                                                      context)
                                                                  .accentColor,
                                                              fontSize: 16),
                                                    );
                                                  default:
                                                    if (snapshot.hasError) {
                                                      return Text(
                                                        "",
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyText1!
                                                            .copyWith(
                                                                color: Theme.of(
                                                                        context)
                                                                    .accentColor,
                                                                fontSize: 16),
                                                      );
                                                    } else {
                                                      return Text(
                                                        "${snapshot.data} views",
                                                        overflow:
                                                            TextOverflow.fade,
                                                        softWrap: false,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyText1!
                                                            .copyWith(
                                                                color: Theme.of(
                                                                        context)
                                                                    .accentColor,
                                                                fontSize: 16),
                                                      );
                                                    }
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          JamIcons.upload,
                                          size: 20,
                                          color: Theme.of(context)
                                              .accentColor
                                              .withOpacity(.7),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          Provider.of<
                                                      user_data
                                                          .UserProfileProvider>(
                                                  context)
                                              .userProfileWalls![index]
                                              .data()["by"]
                                              .toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText2!
                                              .copyWith(
                                                  color: Theme.of(context)
                                                      .accentColor),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Icon(
                                          JamIcons.arrow_circle_right,
                                          size: 20,
                                          color: Theme.of(context)
                                              .accentColor
                                              .withOpacity(.7),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          Provider.of<
                                                      user_data
                                                          .UserProfileProvider>(
                                                  context)
                                              .userProfileWalls![index]
                                              .data()["desc"]
                                              .toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText2!
                                              .copyWith(
                                                  color: Theme.of(context)
                                                      .accentColor),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Icon(
                                          JamIcons.save,
                                          size: 20,
                                          color: Theme.of(context)
                                              .accentColor
                                              .withOpacity(.7),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          Provider.of<
                                                      user_data
                                                          .UserProfileProvider>(
                                                  context)
                                              .userProfileWalls![index]
                                              .data()["size"]
                                              .toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText2!
                                              .copyWith(
                                                  color: Theme.of(context)
                                                      .accentColor),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    Row(
                                      children: [
                                        Text(
                                          Provider.of<
                                                      user_data
                                                          .UserProfileProvider>(
                                                  context)
                                              .userProfileWalls![index]
                                              .data()["resolution"]
                                              .toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText2!
                                              .copyWith(
                                                  color: Theme.of(context)
                                                      .accentColor),
                                        ),
                                        const SizedBox(width: 10),
                                        Icon(
                                          JamIcons.set_square,
                                          size: 20,
                                          color: Theme.of(context)
                                              .accentColor
                                              .withOpacity(.7),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Text(
                                          Provider.of<
                                                      user_data
                                                          .UserProfileProvider>(
                                                  context)
                                              .userProfileWalls![index]
                                              .data()["wallpaper_provider"]
                                              .toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText2!
                                              .copyWith(
                                                  color: Theme.of(context)
                                                      .accentColor),
                                        ),
                                        const SizedBox(width: 10),
                                        Icon(
                                          JamIcons.database,
                                          size: 20,
                                          color: Theme.of(context)
                                              .accentColor
                                              .withOpacity(.7),
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
                          flex: 5,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: <Widget>[
                              DownloadButtonNew(
                                colorChanged: colorChanged,
                                screenshotCallback: () async {
                                  final File file = await _capturePng();
                                  return file;
                                },
                                loading: downloading,
                                path: path ?? "",
                                progress:
                                    (progress / 100.0).clamp(0, 100).toInt(),
                                link:
                                    Provider.of<user_data.UserProfileProvider>(
                                            context)
                                        .userProfileWalls![index]
                                        .data()["wallpaper_url"]
                                        .toString(),
                              ),
                              SetWallpaperButton(
                                colorChanged: colorChanged,
                                screenshotCallback: () async {
                                  final File file = await _capturePng();
                                  return file;
                                },
                                url: Provider.of<user_data.UserProfileProvider>(
                                        context)
                                    .userProfileWalls![index]
                                    .data()["wallpaper_url"]
                                    .toString(),
                              ),
                              FavouriteWallpaperButton(
                                id: Provider.of<user_data.UserProfileProvider>(
                                        context)
                                    .userProfileWalls![index]
                                    .data()["id"]
                                    .toString(),
                                provider:
                                    Provider.of<user_data.UserProfileProvider>(
                                            context)
                                        .userProfileWalls![index]
                                        .data()["wallpaper_provider"]
                                        .toString(),
                                prism:
                                    Provider.of<user_data.UserProfileProvider>(
                                            context)
                                        .userProfileWalls![index]
                                        .data(),
                                trash: false,
                              ),
                              ShareButton(
                                  id: Provider.of<
                                          user_data
                                              .UserProfileProvider>(context)
                                      .userProfileWalls![index]
                                      .data()["id"]
                                      .toString(),
                                  provider: Provider.of<
                                          user_data
                                              .UserProfileProvider>(context)
                                      .userProfileWalls![index]
                                      .data()["wallpaper_provider"]
                                      .toString(),
                                  url: Provider.of<
                                          user_data
                                              .UserProfileProvider>(context)
                                      .userProfileWalls![index]
                                      .data()["wallpaper_url"]
                                      .toString(),
                                  thumbUrl: Provider.of<
                                          user_data
                                              .UserProfileProvider>(context)
                                      .userProfileWalls![index]
                                      .data()["wallpaper_thumb"]
                                      .toString()),
                              EditButton(
                                url: Provider.of<user_data.UserProfileProvider>(
                                        context)
                                    .userProfileWalls![index]
                                    .data()["wallpaper_url"]
                                    .toString(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            body: Stack(
              children: <Widget>[
                AnimatedBuilder(
                    animation: offsetAnimation,
                    builder: (buildContext, child) {
                      if (offsetAnimation.value < 0.0) {
                        logger.d('${offsetAnimation.value + 8.0}');
                      }
                      return GestureDetector(
                        onPanUpdate: (details) {
                          if (details.delta.dy < -10) {
                            panelController.open();
                          }
                        },
                        onLongPress: () {
                          setState(() {
                            colorChanged = false;
                          });
                          HapticFeedback.vibrate();
                          shakeController.forward(from: 0.0);
                        },
                        onTap: () {
                          HapticFeedback.vibrate();
                          !isLoading ? updateAccent() : logger.d("");
                          shakeController.forward(from: 0.0);
                        },
                        child: CachedNetworkImage(
                          imageUrl: Provider.of<user_data.UserProfileProvider>(
                                  context)
                              .userProfileWalls![index]
                              .data()["wallpaper_url"]
                              .toString(),
                          imageBuilder: (context, imageProvider) =>
                              RepaintBoundary(
                            key: genKey,
                            child: Container(
                              margin: EdgeInsets.symmetric(
                                  vertical: offsetAnimation.value * 1.25,
                                  horizontal: offsetAnimation.value / 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                    offsetAnimation.value),
                                image: DecorationImage(
                                  colorFilter: colorChanged
                                      ? ColorFilter.mode(accent!, BlendMode.hue)
                                      : null,
                                  image: imageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          progressIndicatorBuilder:
                              (context, url, downloadProgress) => Stack(
                            children: <Widget>[
                              const SizedBox.expand(child: Text("")),
                              Center(
                                child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation(
                                      Theme.of(context).errorColor,
                                    ),
                                    value: downloadProgress.progress),
                              ),
                            ],
                          ),
                          errorWidget: (context, url, error) => Center(
                            child: Icon(
                              JamIcons.close_circle_f,
                              color: isLoading
                                  ? Theme.of(context).accentColor
                                  : accent!.computeLuminance() > 0.5
                                      ? Colors.black
                                      : Colors.white,
                            ),
                          ),
                        ),
                      );
                    }),
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding:
                        EdgeInsets.fromLTRB(8.0, globals.notchSize! + 8, 8, 8),
                    child: IconButton(
                      onPressed: () {
                        navStack.removeLast();
                        logger.d(navStack.toString());
                        Navigator.pop(context);
                      },
                      color: isLoading
                          ? Theme.of(context).accentColor
                          : accent!.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                      icon: const Icon(
                        JamIcons.chevron_left,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding:
                        EdgeInsets.fromLTRB(8.0, globals.notchSize! + 8, 8, 8),
                    child: IconButton(
                      onPressed: () {
                        final link = Provider.of<user_data.UserProfileProvider>(
                                context,
                                listen: false)
                            .userProfileWalls![index]
                            .data()["wallpaper_url"];
                        Navigator.push(
                            context,
                            PageRouteBuilder(
                                transitionDuration:
                                    const Duration(milliseconds: 300),
                                pageBuilder:
                                    (context, animation, secondaryAnimation) {
                                  animation = Tween(begin: 0.0, end: 1.0)
                                      .animate(animation);
                                  return FadeTransition(
                                      opacity: animation,
                                      child: ClockOverlay(
                                        colorChanged: colorChanged,
                                        accent: accent,
                                        link: link.toString(),
                                        file: false,
                                      ));
                                },
                                fullscreenDialog: true,
                                opaque: false));
                      },
                      color: isLoading
                          ? Theme.of(context).accentColor
                          : accent!.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                      icon: const Icon(
                        JamIcons.clock,
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ));
  }
}
