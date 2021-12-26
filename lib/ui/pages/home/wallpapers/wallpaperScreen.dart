import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/data/informatics/dataManager.dart';
import 'package:Prism/data/palette/paletteNotifier.dart';
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as pdata;
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as data;
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart'
    as wdata;
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
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
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:url_launcher/url_launcher.dart';

class WallpaperScreen extends StatefulWidget {
  final List? arguments;
  const WallpaperScreen({required this.arguments});
  @override
  _WallpaperScreenState createState() => _WallpaperScreenState();
}

class _WallpaperScreenState extends State<WallpaperScreen>
    with SingleTickerProviderStateMixin {
  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    logger.d(navStack.toString());
    return true;
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey genKey = GlobalKey();
  String? provider;
  late int index;
  late String link;
  String? path;
  int progress = 0;
  bool downloading = false;
  bool applying = false;
  bool downloaded = false;
  final ReceivePort _port = ReceivePort();
  late AnimationController shakeController;
  List<Color?>? colors;
  Color? accent = Colors.white;
  bool colorChanged = false;
  bool screenshotTaken = false;
  PanelController panelController = PanelController();
  bool panelClosed = true;
  bool panelCollapsed = true;
  Future<String>? _futureView;
  int firstTime = 0;

  Future<void> _updatePaletteGenerator() async {
    final PaletteNotifier _paletteNotifier =
        Provider.of<PaletteNotifier>(context, listen: false);
    final paletteGenerator =
        await _paletteNotifier.updatePaletteGenerator(link);
    colors = paletteGenerator.colors.toList();
    if (paletteGenerator.colors.length > 5) {
      colors = colors!.sublist(0, 5);
    }
    setState(() {
      accent = colors![0];
    });
    Future.delayed(const Duration(milliseconds: 500)).then((value) {
      if (accent!.computeLuminance() > 0.5) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark
            .copyWith(statusBarIconBrightness: Brightness.dark));
      } else {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark
            .copyWith(statusBarIconBrightness: Brightness.light));
      }
    });
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
    if (firstTime == 0) {
      toasts.codeSend("Long press to reset.");
      firstTime = 1;
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

  Future<File> _captureAMOLEDPng() async {
    const int blackThreshold = 18;
    final RenderRepaintBoundary boundary =
        genKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 3);
    final directory = (await getTemporaryDirectory()).path;
    final ByteData? byteData = await image.toByteData();
    for (int i = 0; i < image.height; i++) {
      for (int j = 0; j < image.width; j++) {
        final pixelData = byteData?.getUint32((i * image.width + j) * 4);
        if (pixelData != null) {
          final int red = pixelData >> 24 & 0xFF;
          final int green = pixelData >> 16 & 0xFF;
          final int blue = pixelData >> 8 & 0xFF;
          final int alpha = pixelData & 0xFF;
          if ((red <= blackThreshold) &&
              (green <= blackThreshold) &&
              (blue <= blackThreshold) &&
              alpha != 0) {
            byteData?.setUint32((i * image.width + j) * 4, 0x000000FF);
          }
        }
      }
    }
    ui.Image? imageEdit;
    File? imgFileEdit;
    ui.decodeImageFromPixels(
      byteData?.buffer.asUint8List() as Uint8List,
      image.width,
      image.height,
      ui.PixelFormat.rgba8888,
      (ui.Image result) async {
        imageEdit = result;
        final ByteData? byteDataEdit =
            await imageEdit?.toByteData(format: ui.ImageByteFormat.png);
        final Uint8List pngBytes = byteDataEdit!.buffer.asUint8List();
        final r = Random();
        String rNum = "";
        for (var i = 0; i < 6; i++) {
          rNum = "$rNum${r.nextInt(9)}";
        }
        final File imgFile = File('$directory/photo_$rNum.png');
        await imgFile.writeAsBytes(pngBytes);
        logger.d(imgFile.path);
        imgFileEdit = imgFile;
      },
    );
    await Future.delayed(const Duration(seconds: 3));
    if (imgFileEdit == null) {
      await Future.delayed(const Duration(seconds: 3));
    }
    return imgFileEdit!;
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
    provider = widget.arguments![0] as String;
    index = widget.arguments![1] as int;
    link = widget.arguments![2] as String;
    if (provider == "Prism") {
      updateViews(data.subPrismWalls![index]["id"].toString().toUpperCase());
      _futureView =
          getViews(data.subPrismWalls![index]["id"].toString().toUpperCase());
    }
    Future.delayed(const Duration()).then((value) => _updatePaletteGenerator());
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
    final PaletteNotifier paletteNotifier =
        Provider.of<PaletteNotifier>(context);
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
      child: provider == "WallHaven"
          ? Scaffold(
              key: _scaffoldKey,
              backgroundColor: paletteNotifier.isLoading
                  ? Theme.of(context).primaryColor
                  : accent,
              body: SlidingUpPanel(
                onPanelOpened: () {
                  setState(() {
                    panelCollapsed = false;
                  });
                  setState(() {
                    panelCollapsed = false;
                  });
                  if (panelClosed) {
                    logger.d('Screenshot Starting');
                    setState(() {
                      panelClosed = false;
                    });
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
                                padding:
                                    const EdgeInsets.fromLTRB(35, 0, 35, 10),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              0, 5, 0, 10),
                                          child: Text(
                                            wdata.walls[index].id
                                                .toString()
                                                .toUpperCase(),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyText1!
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
                                              color: Theme.of(context)
                                                  .accentColor
                                                  .withOpacity(.7),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              wdata.walls[index].views
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
                                              JamIcons.heart_f,
                                              size: 20,
                                              color: Theme.of(context)
                                                  .accentColor
                                                  .withOpacity(.7),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              wdata.walls[index].favourites
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
                                              "${double.parse((double.parse(wdata.walls[index].file_size.toString()) / 1000000).toString()).toStringAsFixed(2)} MB",
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: <Widget>[
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              0, 0, 0, 0),
                                          child: Row(
                                            children: [
                                              Text(
                                                wdata.walls[index].category
                                                        .toString()[0]
                                                        .toUpperCase() +
                                                    wdata.walls[index].category
                                                        .toString()
                                                        .substring(1),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyText2!
                                                    .copyWith(
                                                        color: Theme.of(context)
                                                            .accentColor),
                                              ),
                                              const SizedBox(width: 10),
                                              Icon(
                                                JamIcons.unordered_list,
                                                size: 20,
                                                color: Theme.of(context)
                                                    .accentColor
                                                    .withOpacity(.7),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            Text(
                                              wdata.walls[index].resolution
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
                                              provider.toString(),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: <Widget>[
                                  DownloadButtonNew(
                                    colorChanged: colorChanged,
                                    screenshotCallback: () async {
                                      final File file = await _capturePng();
                                      return file;
                                    },
                                    loading: downloading,
                                    path: path ?? "",
                                    progress: (progress / 100.0)
                                        .clamp(0, 100)
                                        .toInt(),
                                    link: wdata.walls[index].path.toString(),
                                  ),
                                  SetWallpaperButton(
                                    colorChanged: colorChanged,
                                    screenshotCallback: () async {
                                      final File file = await _capturePng();
                                      return file;
                                    },
                                    url: wdata.walls[index].path,
                                  ),
                                  FavouriteWallpaperButton(
                                    id: wdata.walls[index].id.toString(),
                                    provider: "WallHaven",
                                    wallhaven: wdata.walls[index],
                                    trash: false,
                                  ),
                                  ShareButton(
                                      id: wdata.walls[index].id,
                                      provider: provider,
                                      url: wdata.walls[index].path,
                                      thumbUrl: wdata
                                          .walls[index].thumbs!["original"]
                                          .toString()),
                                  EditButton(
                                    url: wdata.walls[index].path,
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
                              !paletteNotifier.isLoading
                                  ? updateAccent()
                                  : logger.d("");
                              shakeController.forward(from: 0.0);
                            },
                            child: CachedNetworkImage(
                              imageUrl: wdata.walls[index].path!,
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
                                          ? ColorFilter.mode(
                                              accent!, BlendMode.hue)
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
                                  color: paletteNotifier.isLoading
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
                        padding: EdgeInsets.fromLTRB(
                            8.0, globals.notchSize! + 8, 8, 8),
                        child: IconButton(
                          onPressed: () {
                            navStack.removeLast();
                            logger.d(navStack.toString());
                            Navigator.pop(context);
                          },
                          color: paletteNotifier.isLoading
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
                        padding: EdgeInsets.fromLTRB(
                            8.0, globals.notchSize! + 8, 8, 8),
                        child: IconButton(
                          onPressed: () {
                            final link = wdata.walls[index].path;
                            Navigator.push(
                                context,
                                PageRouteBuilder(
                                    transitionDuration:
                                        const Duration(milliseconds: 300),
                                    pageBuilder: (context, animation,
                                        secondaryAnimation) {
                                      animation = Tween(begin: 0.0, end: 1.0)
                                          .animate(animation);
                                      return FadeTransition(
                                          opacity: animation,
                                          child: ClockOverlay(
                                            colorChanged: colorChanged,
                                            accent: accent,
                                            link: link,
                                            file: false,
                                          ));
                                    },
                                    fullscreenDialog: true,
                                    opaque: false));
                          },
                          color: paletteNotifier.isLoading
                              ? Theme.of(context).accentColor
                              : accent!.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white,
                          icon: const Icon(
                            JamIcons.clock,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : provider == "Prism"
              ? Scaffold(
                  key: _scaffoldKey,
                  backgroundColor: paletteNotifier.isLoading
                      ? Theme.of(context).primaryColor
                      : accent,
                  body: SlidingUpPanel(
                    onPanelOpened: () {
                      setState(() {
                        panelCollapsed = false;
                      });
                      if (panelClosed) {
                        logger.d('Screenshot Starting');
                        setState(() {
                          panelClosed = false;
                        });
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
                          filter:
                              ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 750),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              color: panelCollapsed
                                  ? Theme.of(context)
                                      .primaryColor
                                      .withOpacity(1)
                                  : Theme.of(context)
                                      .primaryColor
                                      .withOpacity(.5),
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
                                    padding: const EdgeInsets.fromLTRB(
                                        35, 0, 35, 10),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: <Widget>[
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            SizedBox(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.36,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                        0, 5, 0, 10),
                                                child: Row(
                                                  children: [
                                                    Text(
                                                      data.subPrismWalls![index]
                                                              ["id"]
                                                          .toString()
                                                          .toUpperCase(),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyText1!
                                                          .copyWith(
                                                              color: Theme.of(
                                                                      context)
                                                                  .accentColor,
                                                              fontSize: 16),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets
                                                              .symmetric(
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
                                                      builder:
                                                          (context, snapshot) {
                                                        switch (snapshot
                                                            .connectionState) {
                                                          case ConnectionState
                                                              .waiting:
                                                            return Text(
                                                              "",
                                                              style: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .bodyText1!
                                                                  .copyWith(
                                                                      color: Theme.of(
                                                                              context)
                                                                          .accentColor,
                                                                      fontSize:
                                                                          16),
                                                            );
                                                          case ConnectionState
                                                              .none:
                                                            return Text(
                                                              "",
                                                              style: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .bodyText1!
                                                                  .copyWith(
                                                                      color: Theme.of(
                                                                              context)
                                                                          .accentColor,
                                                                      fontSize:
                                                                          16),
                                                            );
                                                          default:
                                                            if (snapshot
                                                                .hasError) {
                                                              return Text(
                                                                "",
                                                                style: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .bodyText1!
                                                                    .copyWith(
                                                                        color: Theme.of(context)
                                                                            .accentColor,
                                                                        fontSize:
                                                                            16),
                                                              );
                                                            } else {
                                                              return Text(
                                                                "${snapshot.data} views",
                                                                overflow:
                                                                    TextOverflow
                                                                        .fade,
                                                                softWrap: false,
                                                                style: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .bodyText1!
                                                                    .copyWith(
                                                                        color: Theme.of(context)
                                                                            .accentColor,
                                                                        fontSize:
                                                                            16),
                                                              );
                                                            }
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
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
                                                  data.subPrismWalls![index]
                                                          ["desc"]
                                                      .toString(),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyText2!
                                                      .copyWith(
                                                          color:
                                                              Theme.of(context)
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
                                                  data.subPrismWalls![index]
                                                          ["size"]
                                                      .toString(),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyText2!
                                                      .copyWith(
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: <Widget>[
                                            SizedBox(
                                              width: 160,
                                              child: Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Stack(
                                                  children: [
                                                    Align(
                                                      alignment:
                                                          Alignment.topRight,
                                                      child: ActionChip(
                                                        onPressed: () {
                                                          Navigator.pushNamed(
                                                              context,
                                                              followerProfileRoute,
                                                              arguments: [
                                                                data.subPrismWalls![
                                                                        index]
                                                                    ["email"],
                                                              ]);
                                                        },
                                                        padding:
                                                            const EdgeInsets
                                                                    .symmetric(
                                                                vertical: 5,
                                                                horizontal: 5),
                                                        avatar: CircleAvatar(
                                                          backgroundImage:
                                                              CachedNetworkImageProvider(data
                                                                  .subPrismWalls![
                                                                      index][
                                                                      "userPhoto"]
                                                                  .toString()),
                                                        ),
                                                        labelPadding:
                                                            const EdgeInsets
                                                                    .fromLTRB(
                                                                7, 3, 7, 3),
                                                        label: Text(
                                                          data.subPrismWalls![
                                                                  index]["by"]
                                                              .toString(),
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .bodyText2!
                                                              .copyWith(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .accentColor)
                                                              .copyWith(
                                                                  fontSize: 16),
                                                          overflow:
                                                              TextOverflow.fade,
                                                        ),
                                                      ),
                                                    ),
                                                    if (globals.verifiedUsers
                                                        .contains(data
                                                            .subPrismWalls![
                                                                index]["email"]
                                                            .toString()))
                                                      Align(
                                                        alignment:
                                                            Alignment.topRight,
                                                        child: SizedBox(
                                                          width: 20,
                                                          height: 20,
                                                          child: SvgPicture.string(verifiedIcon.replaceAll(
                                                              "E57697",
                                                              Theme.of(context)
                                                                          .errorColor ==
                                                                      Colors
                                                                          .black
                                                                  ? "E57697"
                                                                  : Theme.of(
                                                                          context)
                                                                      .errorColor
                                                                      .toString()
                                                                      .replaceAll(
                                                                          "Color(0xff",
                                                                          "")
                                                                      .replaceAll(
                                                                          ")",
                                                                          ""))),
                                                        ),
                                                      )
                                                    else
                                                      Container(),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Row(
                                              children: [
                                                Text(
                                                  data.subPrismWalls![index]
                                                          ["resolution"]
                                                      .toString(),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyText2!
                                                      .copyWith(
                                                          color:
                                                              Theme.of(context)
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
                                            GestureDetector(
                                              onTap: () async {
                                                await createCopyrightLink(
                                                    false, context,
                                                    id: data
                                                        .subPrismWalls![index]
                                                            ["id"]
                                                        .toString(),
                                                    provider: provider,
                                                    url: data
                                                        .subPrismWalls![index]
                                                            ["wallpaper_url"]
                                                        .toString(),
                                                    thumbUrl: data
                                                        .subPrismWalls![index]
                                                            ["wallpaper_thumb"]
                                                        .toString());
                                              },
                                              child: Row(
                                                children: [
                                                  Text(
                                                    "Report",
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyText2!
                                                        .copyWith(
                                                            decoration:
                                                                TextDecoration
                                                                    .underline,
                                                            color: Theme.of(
                                                                    context)
                                                                .accentColor),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Icon(
                                                    JamIcons.info,
                                                    size: 20,
                                                    color: Theme.of(context)
                                                        .accentColor
                                                        .withOpacity(.7),
                                                  ),
                                                ],
                                              ),
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: <Widget>[
                                      DownloadButtonNew(
                                        colorChanged: colorChanged,
                                        screenshotCallback: () async {
                                          final File file = await _capturePng();
                                          return file;
                                        },
                                        loading: downloading,
                                        path: path ?? "",
                                        progress: (progress / 100.0)
                                            .clamp(0, 100)
                                            .toInt(),
                                        link: data.subPrismWalls![index]
                                                ["wallpaper_url"]
                                            .toString(),
                                      ),
                                      SetWallpaperButton(
                                        colorChanged: colorChanged,
                                        screenshotCallback: () async {
                                          final File file = await _capturePng();
                                          return file;
                                        },
                                        url: data.subPrismWalls![index]
                                                ["wallpaper_url"]
                                            .toString(),
                                      ),
                                      FavouriteWallpaperButton(
                                        id: data.subPrismWalls![index]["id"]
                                            .toString(),
                                        provider: "Prism",
                                        prism:
                                            data.subPrismWalls![index] as Map,
                                        trash: false,
                                      ),
                                      ShareButton(
                                          id: data.subPrismWalls![index]["id"]
                                              .toString(),
                                          provider: provider,
                                          url: data.subPrismWalls![index]
                                                  ["wallpaper_url"]
                                              .toString(),
                                          thumbUrl: data.subPrismWalls![index]
                                                  ["wallpaper_thumb"]
                                              .toString()),
                                      EditButton(
                                          url: data.subPrismWalls![index]
                                                  ["wallpaper_url"]
                                              .toString()),
                                    ],
                                  ),
                                )
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
                                  !paletteNotifier.isLoading
                                      ? updateAccent()
                                      : logger.d("");
                                  shakeController.forward(from: 0.0);
                                },
                                child: CachedNetworkImage(
                                  imageUrl: data.subPrismWalls![index]
                                          ["wallpaper_url"]
                                      .toString(),
                                  imageBuilder: (context, imageProvider) =>
                                      RepaintBoundary(
                                    key: genKey,
                                    child: Container(
                                      margin: EdgeInsets.symmetric(
                                          vertical:
                                              offsetAnimation.value * 1.25,
                                          horizontal:
                                              offsetAnimation.value / 2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                            offsetAnimation.value),
                                        image: DecorationImage(
                                          colorFilter: colorChanged
                                              ? ColorFilter.mode(
                                                  accent!, BlendMode.hue)
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
                                      color: paletteNotifier.isLoading
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
                            padding: EdgeInsets.fromLTRB(
                                8.0, globals.notchSize! + 8, 8, 8),
                            child: IconButton(
                              onPressed: () {
                                navStack.removeLast();
                                logger.d(navStack.toString());
                                Navigator.pop(context);
                              },
                              color: paletteNotifier.isLoading
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
                            padding: EdgeInsets.fromLTRB(
                                8.0, globals.notchSize! + 8, 8, 8),
                            child: IconButton(
                              onPressed: () async {
                                final link =
                                    data.subPrismWalls![index]["wallpaper_url"];
                                Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                        transitionDuration:
                                            const Duration(milliseconds: 300),
                                        pageBuilder: (context, animation,
                                            secondaryAnimation) {
                                          animation =
                                              Tween(begin: 0.0, end: 1.0)
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
                              color: paletteNotifier.isLoading
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
                )
              : provider == "Pexels"
                  ? Scaffold(
                      key: _scaffoldKey,
                      backgroundColor: paletteNotifier.isLoading
                          ? Theme.of(context).primaryColor
                          : accent,
                      body: SlidingUpPanel(
                        onPanelOpened: () {
                          setState(() {
                            panelCollapsed = false;
                          });
                          if (panelClosed) {
                            logger.d('Screenshot Starting');
                            setState(() {
                              panelClosed = false;
                            });
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
                              filter: ui.ImageFilter.blur(
                                  sigmaX: 12.0, sigmaY: 12.0),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 750),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  color: panelCollapsed
                                      ? Theme.of(context)
                                          .primaryColor
                                          .withOpacity(1)
                                      : Theme.of(context)
                                          .primaryColor
                                          .withOpacity(.5),
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
                                            color:
                                                Theme.of(context).accentColor,
                                          ),
                                        ),
                                      ),
                                    )),
                                    ColorBar(colors: colors),
                                    Expanded(
                                      flex: 8,
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            35, 0, 35, 15),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      0, 5, 0, 10),
                                              child: SizedBox(
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    .8,
                                                child: Text(
                                                  pdata.wallsP[index].url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "").length > 8
                                                      ? pdata.wallsP[index].url
                                                              .toString()
                                                              .replaceAll(
                                                                  "https://www.pexels.com/photo/", "")
                                                              .replaceAll(
                                                                  "-", " ")
                                                              .replaceAll(
                                                                  "/", "")[0]
                                                              .toUpperCase() +
                                                          pdata.wallsP[index].url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "").substring(
                                                              1,
                                                              pdata.wallsP[index].url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "").length -
                                                                  7)
                                                      : pdata.wallsP[index].url
                                                              .toString()
                                                              .replaceAll(
                                                                  "https://www.pexels.com/photo/", "")
                                                              .replaceAll(
                                                                  "-", " ")
                                                              .replaceAll(
                                                                  "/", "")[0]
                                                              .toUpperCase() +
                                                          pdata.wallsP[index].url
                                                              .toString()
                                                              .replaceAll(
                                                                  "https://www.pexels.com/photo/", "")
                                                              .replaceAll("-", " ")
                                                              .replaceAll("/", "")
                                                              .substring(1),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyText1!
                                                      .copyWith(
                                                          color:
                                                              Theme.of(context)
                                                                  .accentColor),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: <Widget>[
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: <Widget>[
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          JamIcons.info,
                                                          size: 20,
                                                          color: Theme.of(
                                                                  context)
                                                              .accentColor
                                                              .withOpacity(.7),
                                                        ),
                                                        const SizedBox(
                                                            width: 10),
                                                        Text(
                                                          pdata.wallsP[index].id
                                                              .toString(),
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .bodyText2!
                                                              .copyWith(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .accentColor),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 5),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          JamIcons.set_square,
                                                          size: 20,
                                                          color: Theme.of(
                                                                  context)
                                                              .accentColor
                                                              .withOpacity(.7),
                                                        ),
                                                        const SizedBox(
                                                            width: 10),
                                                        Text(
                                                          "${pdata.wallsP[index].width.toString()}x${pdata.wallsP[index].height.toString()}",
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .bodyText2!
                                                              .copyWith(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .accentColor),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: <Widget>[
                                                    SizedBox(
                                                      width: 160,
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        child: ActionChip(
                                                          onPressed: () {
                                                            launch(pdata
                                                                .wallsP[index]
                                                                .url!);
                                                          },
                                                          padding:
                                                              const EdgeInsets
                                                                      .symmetric(
                                                                  vertical: 5,
                                                                  horizontal:
                                                                      5),
                                                          avatar: Icon(
                                                              JamIcons.camera,
                                                              color: Theme.of(
                                                                      context)
                                                                  .accentColor),
                                                          labelPadding:
                                                              const EdgeInsets
                                                                      .fromLTRB(
                                                                  7, 3, 7, 3),
                                                          label: Text(
                                                            pdata.wallsP[index]
                                                                .photographer
                                                                .toString(),
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .bodyText2!
                                                                .copyWith(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .accentColor)
                                                                .copyWith(
                                                                    fontSize:
                                                                        16),
                                                            overflow:
                                                                TextOverflow
                                                                    .fade,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          provider.toString(),
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .bodyText2!
                                                              .copyWith(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .accentColor),
                                                        ),
                                                        const SizedBox(
                                                            width: 10),
                                                        Icon(
                                                          JamIcons.database,
                                                          size: 20,
                                                          color: Theme.of(
                                                                  context)
                                                              .accentColor
                                                              .withOpacity(.7),
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
                                      flex: 5,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: <Widget>[
                                          DownloadButtonNew(
                                            colorChanged: colorChanged,
                                            screenshotCallback: () async {
                                              final File file =
                                                  await _capturePng();
                                              return file;
                                            },
                                            loading: downloading,
                                            path: path ?? "",
                                            progress: (progress / 100.0)
                                                .clamp(0, 100)
                                                .toInt(),
                                            link: pdata
                                                .wallsP[index].src!["original"]
                                                .toString(),
                                          ),
                                          SetWallpaperButton(
                                            colorChanged: colorChanged,
                                            screenshotCallback: () async {
                                              final File file =
                                                  await _capturePng();
                                              return file;
                                            },
                                            url: pdata
                                                .wallsP[index].src!["original"]
                                                .toString(),
                                          ),
                                          FavouriteWallpaperButton(
                                            id: pdata.wallsP[index].id
                                                .toString(),
                                            provider: "Pexels",
                                            pexels: pdata.wallsP[index],
                                            trash: false,
                                          ),
                                          ShareButton(
                                              id: pdata.wallsP[index].id,
                                              provider: provider,
                                              url: pdata.wallsP[index]
                                                  .src!["original"]
                                                  .toString(),
                                              thumbUrl: pdata
                                                  .wallsP[index].src!["medium"]
                                                  .toString()),
                                          EditButton(
                                            url: pdata
                                                .wallsP[index].src!["original"]
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
                                      !paletteNotifier.isLoading
                                          ? updateAccent()
                                          : logger.d("");
                                      shakeController.forward(from: 0.0);
                                    },
                                    child: CachedNetworkImage(
                                      imageUrl: pdata
                                          .wallsP[index].src!["original"]
                                          .toString(),
                                      imageBuilder: (context, imageProvider) =>
                                          RepaintBoundary(
                                        key: genKey,
                                        child: Container(
                                          margin: EdgeInsets.symmetric(
                                              vertical:
                                                  offsetAnimation.value * 1.25,
                                              horizontal:
                                                  offsetAnimation.value / 2),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                                offsetAnimation.value),
                                            image: DecorationImage(
                                              colorFilter: colorChanged
                                                  ? ColorFilter.mode(
                                                      accent!, BlendMode.hue)
                                                  : null,
                                              image: imageProvider,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ),
                                      progressIndicatorBuilder:
                                          (context, url, downloadProgress) =>
                                              Stack(
                                        children: <Widget>[
                                          const SizedBox.expand(
                                              child: Text("")),
                                          Center(
                                            child: CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                        Theme.of(context)
                                                            .errorColor),
                                                value:
                                                    downloadProgress.progress),
                                          ),
                                        ],
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Center(
                                        child: Icon(
                                          JamIcons.close_circle_f,
                                          color: paletteNotifier.isLoading
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
                                padding: EdgeInsets.fromLTRB(
                                    8.0, globals.notchSize! + 8, 8, 8),
                                child: IconButton(
                                  onPressed: () {
                                    navStack.removeLast();
                                    logger.d(navStack.toString());
                                    Navigator.pop(context);
                                  },
                                  color: paletteNotifier.isLoading
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
                                padding: EdgeInsets.fromLTRB(
                                    8.0, globals.notchSize! + 8, 8, 8),
                                child: IconButton(
                                  onPressed: () async {
                                    final link =
                                        pdata.wallsP[index].src!["original"];
                                    Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                            transitionDuration: const Duration(
                                                milliseconds: 300),
                                            pageBuilder: (context, animation,
                                                secondaryAnimation) {
                                              animation =
                                                  Tween(begin: 0.0, end: 1.0)
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
                                  color: paletteNotifier.isLoading
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
                    )
                  : provider!.length > 6 &&
                          provider!.substring(0, 6) == "Colors"
                      ? Scaffold(
                          key: _scaffoldKey,
                          backgroundColor: paletteNotifier.isLoading
                              ? Theme.of(context).primaryColor
                              : accent,
                          body: SlidingUpPanel(
                            onPanelOpened: () {
                              setState(() {
                                panelCollapsed = false;
                              });
                              if (panelClosed) {
                                logger.d('Screenshot Starting');
                                setState(() {
                                  panelClosed = false;
                                });
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
                                  filter: ui.ImageFilter.blur(
                                      sigmaX: 12.0, sigmaY: 12.0),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 750),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      color: panelCollapsed
                                          ? Theme.of(context)
                                              .primaryColor
                                              .withOpacity(1)
                                          : Theme.of(context)
                                              .primaryColor
                                              .withOpacity(.5),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                color: Theme.of(context)
                                                    .accentColor,
                                              ),
                                            ),
                                          ),
                                        )),
                                        ColorBar(colors: colors),
                                        Expanded(
                                          flex: 8,
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                35, 0, 35, 15),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          0, 5, 0, 10),
                                                  child: SizedBox(
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            .8,
                                                    child: Text(
                                                      pdata.wallsC[index].url
                                                                  .toString()
                                                                  .replaceAll(
                                                                      "https://www.pexels.com/photo/", "")
                                                                  .replaceAll(
                                                                      "-", " ")
                                                                  .replaceAll(
                                                                      "/", "")
                                                                  .length >
                                                              8
                                                          ? pdata.wallsC[index].url
                                                                  .toString()
                                                                  .replaceAll(
                                                                      "https://www.pexels.com/photo/", "")
                                                                  .replaceAll(
                                                                      "-", " ")
                                                                  .replaceAll(
                                                                      "/",
                                                                      "")[0]
                                                                  .toUpperCase() +
                                                              pdata
                                                                  .wallsC[index]
                                                                  .url
                                                                  .toString()
                                                                  .replaceAll(
                                                                      "https://www.pexels.com/photo/", "")
                                                                  .replaceAll(
                                                                      "-", " ")
                                                                  .replaceAll("/", "")
                                                                  .substring(1, pdata.wallsC[index].url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "").length - 7)
                                                          : pdata.wallsC[index].url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "")[0].toUpperCase() + pdata.wallsC[index].url.toString().replaceAll("https://www.pexels.com/photo/", "").replaceAll("-", " ").replaceAll("/", "").substring(1),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyText1!
                                                          .copyWith(
                                                              color: Theme.of(
                                                                      context)
                                                                  .accentColor),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                ),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: <Widget>[
                                                    Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: <Widget>[
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              JamIcons.info,
                                                              size: 20,
                                                              color: Theme.of(
                                                                      context)
                                                                  .accentColor
                                                                  .withOpacity(
                                                                      .7),
                                                            ),
                                                            const SizedBox(
                                                                width: 10),
                                                            Text(
                                                              pdata
                                                                  .wallsC[index]
                                                                  .id
                                                                  .toString(),
                                                              style: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .bodyText2!
                                                                  .copyWith(
                                                                      color: Theme.of(
                                                                              context)
                                                                          .accentColor),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                            height: 5),
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              JamIcons
                                                                  .set_square,
                                                              size: 20,
                                                              color: Theme.of(
                                                                      context)
                                                                  .accentColor
                                                                  .withOpacity(
                                                                      .7),
                                                            ),
                                                            const SizedBox(
                                                                width: 10),
                                                            Text(
                                                              "${pdata.wallsC[index].width.toString()}x${pdata.wallsC[index].height.toString()}",
                                                              style: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .bodyText2!
                                                                  .copyWith(
                                                                      color: Theme.of(
                                                                              context)
                                                                          .accentColor),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                    Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .end,
                                                      children: <Widget>[
                                                        SizedBox(
                                                          width: 160,
                                                          child: Align(
                                                            alignment: Alignment
                                                                .centerRight,
                                                            child: ActionChip(
                                                              onPressed: () {
                                                                launch(pdata
                                                                    .wallsC[
                                                                        index]
                                                                    .url!);
                                                              },
                                                              padding: const EdgeInsets
                                                                      .symmetric(
                                                                  vertical: 5,
                                                                  horizontal:
                                                                      5),
                                                              avatar: Icon(
                                                                  JamIcons
                                                                      .camera,
                                                                  color: Theme.of(
                                                                          context)
                                                                      .accentColor),
                                                              labelPadding:
                                                                  const EdgeInsets
                                                                          .fromLTRB(
                                                                      7,
                                                                      3,
                                                                      7,
                                                                      3),
                                                              label: Text(
                                                                pdata
                                                                    .wallsC[
                                                                        index]
                                                                    .photographer
                                                                    .toString(),
                                                                style: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .bodyText2!
                                                                    .copyWith(
                                                                        color: Theme.of(context)
                                                                            .accentColor)
                                                                    .copyWith(
                                                                        fontSize:
                                                                            16),
                                                                overflow:
                                                                    TextOverflow
                                                                        .fade,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        Row(
                                                          children: [
                                                            Text(
                                                              "Pexels",
                                                              style: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .bodyText2!
                                                                  .copyWith(
                                                                      color: Theme.of(
                                                                              context)
                                                                          .accentColor),
                                                            ),
                                                            const SizedBox(
                                                                width: 10),
                                                            Icon(
                                                              JamIcons.database,
                                                              size: 20,
                                                              color: Theme.of(
                                                                      context)
                                                                  .accentColor
                                                                  .withOpacity(
                                                                      .7),
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
                                          flex: 5,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: <Widget>[
                                              DownloadButtonNew(
                                                colorChanged: colorChanged,
                                                screenshotCallback: () async {
                                                  final File file =
                                                      await _capturePng();
                                                  return file;
                                                },
                                                loading: downloading,
                                                path: path ?? "",
                                                progress: (progress / 100.0)
                                                    .clamp(0, 100)
                                                    .toInt(),
                                                link: pdata.wallsC[index]
                                                    .src!["original"]
                                                    .toString(),
                                              ),
                                              SetWallpaperButton(
                                                colorChanged: colorChanged,
                                                screenshotCallback: () async {
                                                  final File file =
                                                      await _capturePng();
                                                  return file;
                                                },
                                                url: pdata.wallsC[index]
                                                    .src!["original"]
                                                    .toString(),
                                              ),
                                              FavouriteWallpaperButton(
                                                id: pdata.wallsC[index].id
                                                    .toString(),
                                                provider: "Pexels",
                                                pexels: pdata.wallsC[index],
                                                trash: false,
                                              ),
                                              ShareButton(
                                                  id: pdata.wallsC[index].id,
                                                  provider: "Pexels",
                                                  url: pdata.wallsC[index]
                                                      .src!["original"]
                                                      .toString(),
                                                  thumbUrl: pdata.wallsC[index]
                                                      .src!["medium"]
                                                      .toString()),
                                              EditButton(
                                                url: pdata.wallsC[index]
                                                    .src!["original"]
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
                                if (pdata.wallsC == null)
                                  Container()
                                else
                                  AnimatedBuilder(
                                      animation: offsetAnimation,
                                      builder: (buildContext, child) {
                                        if (offsetAnimation.value < 0.0) {
                                          logger.d(
                                              '${offsetAnimation.value + 8.0}');
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
                                            !paletteNotifier.isLoading
                                                ? updateAccent()
                                                : logger.d("");
                                            shakeController.forward(from: 0.0);
                                          },
                                          child: CachedNetworkImage(
                                            imageUrl: pdata
                                                .wallsC[index].src!["original"]
                                                .toString(),
                                            imageBuilder:
                                                (context, imageProvider) =>
                                                    RepaintBoundary(
                                              key: genKey,
                                              child: Container(
                                                margin: EdgeInsets.symmetric(
                                                    vertical:
                                                        offsetAnimation.value *
                                                            1.25,
                                                    horizontal:
                                                        offsetAnimation.value /
                                                            2),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          offsetAnimation
                                                              .value),
                                                  image: DecorationImage(
                                                    colorFilter: colorChanged
                                                        ? ColorFilter.mode(
                                                            accent!,
                                                            BlendMode.hue)
                                                        : null,
                                                    image: imageProvider,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            progressIndicatorBuilder: (context,
                                                    url, downloadProgress) =>
                                                Stack(
                                              children: <Widget>[
                                                const SizedBox.expand(
                                                    child: Text("")),
                                                Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                          valueColor:
                                                              AlwaysStoppedAnimation(
                                                            Theme.of(context)
                                                                .errorColor,
                                                          ),
                                                          value:
                                                              downloadProgress
                                                                  .progress),
                                                ),
                                              ],
                                            ),
                                            errorWidget:
                                                (context, url, error) => Center(
                                              child: Icon(
                                                JamIcons.close_circle_f,
                                                color: paletteNotifier.isLoading
                                                    ? Theme.of(context)
                                                        .accentColor
                                                    : accent!.computeLuminance() >
                                                            0.5
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
                                    padding: EdgeInsets.fromLTRB(
                                        8.0, globals.notchSize! + 8, 8, 8),
                                    child: IconButton(
                                      onPressed: () {
                                        navStack.removeLast();
                                        logger.d(navStack.toString());
                                        Navigator.pop(context);
                                      },
                                      color: paletteNotifier.isLoading
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
                                    padding: EdgeInsets.fromLTRB(
                                        8.0, globals.notchSize! + 8, 8, 8),
                                    child: IconButton(
                                      onPressed: () async {
                                        final link = pdata
                                            .wallsC[index].src!["original"];
                                        Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                                transitionDuration:
                                                    const Duration(
                                                        milliseconds: 300),
                                                pageBuilder: (context,
                                                    animation,
                                                    secondaryAnimation) {
                                                  animation = Tween(
                                                          begin: 0.0, end: 1.0)
                                                      .animate(animation);
                                                  return FadeTransition(
                                                      opacity: animation,
                                                      child: ClockOverlay(
                                                        colorChanged:
                                                            colorChanged,
                                                        accent: accent,
                                                        link: link.toString(),
                                                        file: false,
                                                      ));
                                                },
                                                fullscreenDialog: true,
                                                opaque: false));
                                      },
                                      color: paletteNotifier.isLoading
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
                        )
                      : Scaffold(
                          key: _scaffoldKey,
                          backgroundColor: paletteNotifier.isLoading
                              ? Theme.of(context).primaryColor
                              : accent,
                          body: SlidingUpPanel(
                            onPanelOpened: () {
                              setState(() {
                                panelCollapsed = false;
                              });
                              if (panelClosed) {
                                logger.d('Screenshot Starting');
                                setState(() {
                                  panelClosed = false;
                                });
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
                                  filter: ui.ImageFilter.blur(
                                      sigmaX: 12.0, sigmaY: 12.0),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 750),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      color: panelCollapsed
                                          ? Theme.of(context)
                                              .primaryColor
                                              .withOpacity(1)
                                          : Theme.of(context)
                                              .primaryColor
                                              .withOpacity(.5),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                color: Theme.of(context)
                                                    .accentColor,
                                              ),
                                            ),
                                          ),
                                        )),
                                        ColorBar(colors: colors),
                                        Expanded(
                                          flex: 8,
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                35, 0, 35, 15),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: <Widget>[
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: <Widget>[
                                                    Padding(
                                                      padding: const EdgeInsets
                                                              .fromLTRB(
                                                          0, 5, 0, 10),
                                                      child: Text(
                                                        wdata.wallsS[index].id
                                                            .toString()
                                                            .toUpperCase(),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyText1!
                                                            .copyWith(
                                                                color: Theme.of(
                                                                        context)
                                                                    .accentColor),
                                                      ),
                                                    ),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          JamIcons.eye,
                                                          size: 20,
                                                          color: Theme.of(
                                                                  context)
                                                              .accentColor
                                                              .withOpacity(.7),
                                                        ),
                                                        const SizedBox(
                                                            width: 10),
                                                        Text(
                                                          wdata.wallsS[index]
                                                              .views
                                                              .toString(),
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .bodyText2!
                                                              .copyWith(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .accentColor),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 5),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          JamIcons.heart_f,
                                                          size: 20,
                                                          color: Theme.of(
                                                                  context)
                                                              .accentColor
                                                              .withOpacity(.7),
                                                        ),
                                                        const SizedBox(
                                                            width: 10),
                                                        Text(
                                                          wdata.wallsS[index]
                                                              .favourites
                                                              .toString(),
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .bodyText2!
                                                              .copyWith(
                                                                  color: Theme.of(
                                                                          context)
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
                                                          color: Theme.of(
                                                                  context)
                                                              .accentColor
                                                              .withOpacity(.7),
                                                        ),
                                                        const SizedBox(
                                                            width: 10),
                                                        Text(
                                                          "${double.parse((double.parse(wdata.wallsS[index].file_size.toString()) / 1000000).toString()).toStringAsFixed(2)} MB",
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .bodyText2!
                                                              .copyWith(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .accentColor),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: <Widget>[
                                                    Padding(
                                                      padding: const EdgeInsets
                                                          .fromLTRB(0, 0, 0, 0),
                                                      child: Row(
                                                        children: [
                                                          Text(
                                                            wdata.wallsS[index]
                                                                    .category
                                                                    .toString()[
                                                                        0]
                                                                    .toUpperCase() +
                                                                wdata
                                                                    .wallsS[
                                                                        index]
                                                                    .category
                                                                    .toString()
                                                                    .substring(
                                                                        1),
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .bodyText2!
                                                                .copyWith(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .accentColor),
                                                          ),
                                                          const SizedBox(
                                                              width: 10),
                                                          Icon(
                                                            JamIcons
                                                                .unordered_list,
                                                            size: 20,
                                                            color: Theme.of(
                                                                    context)
                                                                .accentColor
                                                                .withOpacity(
                                                                    .7),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 5),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          wdata.wallsS[index]
                                                              .resolution
                                                              .toString(),
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .bodyText2!
                                                              .copyWith(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .accentColor),
                                                        ),
                                                        const SizedBox(
                                                            width: 10),
                                                        Icon(
                                                          JamIcons.set_square,
                                                          size: 20,
                                                          color: Theme.of(
                                                                  context)
                                                              .accentColor
                                                              .withOpacity(.7),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 5),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          provider!.isNotEmpty
                                                              ? provider
                                                                      .toString()[
                                                                          0]
                                                                      .toUpperCase() +
                                                                  provider
                                                                      .toString()
                                                                      .substring(
                                                                          1)
                                                              : "Search",
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .bodyText2!
                                                              .copyWith(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .accentColor),
                                                        ),
                                                        const SizedBox(
                                                            width: 10),
                                                        Icon(
                                                          JamIcons.search,
                                                          size: 20,
                                                          color: Theme.of(
                                                                  context)
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
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: <Widget>[
                                              DownloadButtonNew(
                                                colorChanged: colorChanged,
                                                screenshotCallback: () async {
                                                  final File file =
                                                      await _capturePng();
                                                  return file;
                                                },
                                                loading: downloading,
                                                path: path ?? "",
                                                progress: (progress / 100.0)
                                                    .clamp(0, 100)
                                                    .toInt(),
                                                link: wdata.wallsS[index].path
                                                    .toString(),
                                              ),
                                              SetWallpaperButton(
                                                colorChanged: colorChanged,
                                                screenshotCallback: () async {
                                                  final File file =
                                                      await _capturePng();
                                                  return file;
                                                },
                                                url: wdata.wallsS[index].path,
                                              ),
                                              FavouriteWallpaperButton(
                                                id: wdata.wallsS[index].id
                                                    .toString(),
                                                provider: "WallHaven",
                                                wallhaven: wdata.wallsS[index],
                                                trash: false,
                                              ),
                                              ShareButton(
                                                  id: wdata.wallsS[index].id,
                                                  provider: "WallHaven",
                                                  url: wdata.wallsS[index].path,
                                                  thumbUrl: wdata.wallsS[index]
                                                      .thumbs!["original"]
                                                      .toString()),
                                              EditButton(
                                                url: wdata.wallsS[index].path,
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
                                        logger.d(
                                            '${offsetAnimation.value + 8.0}');
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
                                          !paletteNotifier.isLoading
                                              ? updateAccent()
                                              : logger.d("");
                                          shakeController.forward(from: 0.0);
                                        },
                                        child: CachedNetworkImage(
                                          imageUrl: wdata.wallsS[index].path!,
                                          imageBuilder:
                                              (context, imageProvider) =>
                                                  RepaintBoundary(
                                            key: genKey,
                                            child: Container(
                                              margin: EdgeInsets.symmetric(
                                                  vertical:
                                                      offsetAnimation.value *
                                                          1.25,
                                                  horizontal:
                                                      offsetAnimation.value /
                                                          2),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        offsetAnimation.value),
                                                image: DecorationImage(
                                                  colorFilter: colorChanged
                                                      ? ColorFilter.mode(
                                                          accent!,
                                                          BlendMode.hue)
                                                      : null,
                                                  image: imageProvider,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                          ),
                                          progressIndicatorBuilder: (context,
                                                  url, downloadProgress) =>
                                              Stack(
                                            children: <Widget>[
                                              const SizedBox.expand(
                                                  child: Text("")),
                                              Center(
                                                child:
                                                    CircularProgressIndicator(
                                                        valueColor:
                                                            AlwaysStoppedAnimation(
                                                          Theme.of(context)
                                                              .errorColor,
                                                        ),
                                                        value: downloadProgress
                                                            .progress),
                                              ),
                                            ],
                                          ),
                                          errorWidget: (context, url, error) =>
                                              Center(
                                            child: Icon(
                                              JamIcons.close_circle_f,
                                              color: paletteNotifier.isLoading
                                                  ? Theme.of(context)
                                                      .accentColor
                                                  : accent!.computeLuminance() >
                                                          0.5
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
                                    padding: EdgeInsets.fromLTRB(
                                        8.0, globals.notchSize! + 8, 8, 8),
                                    child: IconButton(
                                      onPressed: () {
                                        navStack.removeLast();
                                        logger.d(navStack.toString());
                                        Navigator.pop(context);
                                      },
                                      color: paletteNotifier.isLoading
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
                                    padding: EdgeInsets.fromLTRB(
                                        8.0, globals.notchSize! + 8, 8, 8),
                                    child: IconButton(
                                      onPressed: () async {
                                        final link = wdata.wallsS[index].path;
                                        Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                                transitionDuration:
                                                    const Duration(
                                                        milliseconds: 300),
                                                pageBuilder: (context,
                                                    animation,
                                                    secondaryAnimation) {
                                                  animation = Tween(
                                                          begin: 0.0, end: 1.0)
                                                      .animate(animation);
                                                  return FadeTransition(
                                                      opacity: animation,
                                                      child: ClockOverlay(
                                                        colorChanged:
                                                            colorChanged,
                                                        accent: accent,
                                                        link: link,
                                                        file: false,
                                                      ));
                                                },
                                                fullscreenDialog: true,
                                                opaque: false));
                                      },
                                      color: paletteNotifier.isLoading
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
                        ),
    );
  }
}
