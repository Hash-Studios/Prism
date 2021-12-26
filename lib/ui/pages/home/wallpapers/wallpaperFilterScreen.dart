import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/ui/pages/home/wallpapers/customFilters.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/menuButton/setWallpaperButton.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:image/image.dart' as imagelib;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photofilters/filters/filters.dart';
import 'package:photofilters/filters/preset_filters.dart';

class WallpaperFilterScreen extends StatefulWidget {
  final imagelib.Image image;
  final imagelib.Image finalImage;
  final String filename;
  final String finalFilename;

  const WallpaperFilterScreen({
    Key? key,
    required this.image,
    required this.finalImage,
    required this.filename,
    required this.finalFilename,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _WallpaperFilterScreenState();
}

class _WallpaperFilterScreenState extends State<WallpaperFilterScreen> {
  String? filename;
  String? finalFilename;
  Map<String, List<int>?> cachedFilters = {};
  Filter? _filter;
  imagelib.Image? image;
  imagelib.Image? finalImage;
  late bool loading;
  late bool isLoading;
  List<Filter> selectedFilters = [
    NoFilter(),
    AddictiveBlueFilter(),
    AddictiveRedFilter(),
    AdenFilter(),
    AmaroFilter(),
    AshbyFilter(),
    BlurFilter(),
    BlurMaxFilter(),
    BrannanFilter(),
    BrooklynFilter(),
    CharmesFilter(),
    ClarendonFilter(),
    CremaFilter(),
    DogpatchFilter(),
    EarlybirdFilter(),
    EdgeDetectionFilter(),
    EmbossFilter(),
    F1977Filter(),
    GinghamFilter(),
    GinzaFilter(),
    HefeFilter(),
    HelenaFilter(),
    HighPassFilter(),
    HudsonFilter(),
    InkwellFilter(),
    InvertFilter(),
    JunoFilter(),
    KelvinFilter(),
    LarkFilter(),
    LoFiFilter(),
    LowPassFilter(),
    LudwigFilter(),
    MavenFilter(),
    MayfairFilter(),
    MeanFilter(),
    MoonFilter(),
    NashvilleFilter(),
    PerpetuaFilter(),
    ReyesFilter(),
    RiseFilter(),
    SharpenFilter(),
    SierraFilter(),
    SkylineFilter(),
    SlumberFilter(),
    StinsonFilter(),
    SutroFilter(),
    ToasterFilter(),
    ValenciaFilter(),
    VesperFilter(),
    WaldenFilter(),
    WillowFilter(),
    XProIIFilter(),
  ];

  @override
  void initState() {
    super.initState();
    loading = false;
    isLoading = false;
    _filter = selectedFilters[0];
    filename = widget.filename;
    finalFilename = widget.finalFilename;
    image = widget.image;
    finalImage = widget.finalImage;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    logger.d(navStack.toString());
    return true;
  }

  Future<void> _setWallPaper(String link) async {
    String? result;
    try {
      result = await AsyncWallpaper.setWallpaperFromFileNative(
        link,
      );
      if (result == 'Wallpaper set') {
        logger.d("Success");
        analytics.logEvent(
            name: 'set_wall',
            parameters: {'type': 'Both', 'result': 'Success'});
      } else {
        logger.d("Failed");
        toasts.error("Something went wrong!");
      }
    } catch (e) {
      analytics.logEvent(
          name: 'set_wall', parameters: {'type': 'Both', 'result': 'Failure'});
      logger.d(e.toString());
    }
  }

  Future<void> _setBothWallPaper(String url) async {
    String? result;
    try {
      result = await AsyncWallpaper.setWallpaperFromFile(
        url,
        AsyncWallpaper.BOTH_SCREENS,
      );
      if (result == 'Wallpaper set') {
        logger.d("Success");
        analytics.logEvent(
            name: 'set_wall',
            parameters: {'type': 'Both', 'result': 'Success'});
        toasts.codeSend("Wallpaper set successfully!");
      } else {
        logger.d("Failed");
        toasts.error("Something went wrong!");
      }
    } catch (e) {
      analytics.logEvent(
          name: 'set_wall', parameters: {'type': 'Both', 'result': 'Failure'});
      logger.d(e.toString());
    }
    Navigator.of(context).pop();
  }

  Future<void> _setLockWallPaper(String url) async {
    String? result;
    try {
      result = await AsyncWallpaper.setWallpaperFromFile(
        url,
        AsyncWallpaper.LOCK_SCREEN,
      );
      if (result == 'Wallpaper set') {
        logger.d("Success");
        analytics.logEvent(
            name: 'set_wall',
            parameters: {'type': 'Lock', 'result': 'Success'});
        toasts.codeSend("Wallpaper set successfully!");
      } else {
        logger.d("Failed");
        toasts.error("Something went wrong!");
      }
    } catch (e) {
      logger.d(e.toString());
      analytics.logEvent(
          name: 'set_wall', parameters: {'type': 'Lock', 'result': 'Failure'});
    }
    Navigator.of(context).pop();
  }

  Future<void> _setHomeWallPaper(String url) async {
    String? result;
    try {
      result = await AsyncWallpaper.setWallpaperFromFile(
        url,
        AsyncWallpaper.HOME_SCREEN,
      );
      if (result == 'Wallpaper set') {
        logger.d("Success");
        analytics.logEvent(
            name: 'set_wall',
            parameters: {'type': 'Home', 'result': 'Success'});
        toasts.codeSend("Wallpaper set successfully!");
      } else {
        logger.d("Failed");
        toasts.error("Something went wrong!");
      }
    } catch (e) {
      logger.d(e.toString());
      analytics.logEvent(
          name: 'set_wall', parameters: {'type': 'Home', 'result': 'Failure'});
    }
    Navigator.of(context).pop();
  }

  Future<void> onPaint(String url) async {
    HapticFeedback.vibrate();
    Future.delayed(const Duration(seconds: 1))
        .then((value) => _setWallPaper(url));
  }

  void showPremiumPopUp(Function func) {
    if (globals.prismUser.loggedIn == false) {
      toasts.codeSend("Editing Wallpaper is a premium feature.");
      googleSignInPopUp(context, () {
        if (globals.prismUser.premium == false) {
          Navigator.pushNamed(context, premiumRoute);
        } else {
          func();
        }
      });
    } else {
      if (globals.prismUser.premium == false) {
        toasts.codeSend("Editing Wallpaper is a premium feature.");
        Navigator.pushNamed(context, premiumRoute);
      } else {
        func();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Edit Wallpaper",
            style: Theme.of(context).textTheme.headline3,
          ),
          leading: IconButton(
              icon: const Icon(JamIcons.close),
              onPressed: () {
                navStack.removeLast();
                logger.d(navStack.toString());
                Navigator.pop(context);
              }),
          backgroundColor: Theme.of(context).primaryColor,
          actions: <Widget>[
            if (loading)
              Container()
            else if (isLoading)
              Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Theme.of(context).errorColor)),
              )
            else
              IconButton(
                icon: const Icon(JamIcons.download),
                onPressed: () async {
                  toasts.codeSend("Processing Wallpaper");
                  final imageFile = await saveFilteredImage();
                  final status = await Permission.storage.status;
                  if (!status.isGranted) {
                    await Permission.storage.request();
                  }
                  setState(() {
                    isLoading = true;
                  });
                  GallerySaver.saveImage(imageFile.path, albumName: "Prism")
                      .then((value) {
                    analytics.logEvent(
                        name: 'download_wallpaper',
                        parameters: {'link': imageFile.path});
                    toasts.codeSend("Wall Saved in Pictures!");
                    setState(() {
                      isLoading = false;
                    });
                    // main.localNotification.cancelDownloadNotification();
                  }).catchError((e) {
                    setState(() {
                      isLoading = false;
                    });
                    // TODO Cancel all
                    // main.localNotification.cancelDownloadNotification();
                  });
                },
              ),
            if (loading)
              Container()
            else
              IconButton(
                icon: const Icon(JamIcons.check),
                onPressed: () async {
                  toasts.codeSend("Processing Wallpaper");
                  final imageFile = await saveFilteredImage();
                  showModalBottomSheet(
                    isScrollControlled: true,
                    context: context,
                    builder: (context) => SetOptionsPanel(
                      onTap1: () async {
                        HapticFeedback.vibrate();
                        Navigator.of(context).pop();
                        Future.delayed(const Duration(seconds: 1))
                            .then((value) => _setHomeWallPaper(imageFile.path));
                      },
                      onTap4: () async {
                        HapticFeedback.vibrate();
                        Navigator.of(context).pop();
                        if (Platform.isAndroid) {
                          final androidInfo =
                              await DeviceInfoPlugin().androidInfo;
                          final sdkInt = androidInfo.version.sdkInt;
                          logger.d('(SDK $sdkInt)');
                          sdkInt >= 24
                              ? onPaint(imageFile.path)
                              : toasts.error(
                                  "Crop is supported for Android 7.0 and above!");
                        } else {
                          toasts.error(
                              "Sorry crop is supported for Android 7.0 and above!");
                        }
                      },
                      onTap2: () {
                        HapticFeedback.vibrate();
                        Navigator.of(context).pop();
                        Future.delayed(const Duration(seconds: 1))
                            .then((value) => _setLockWallPaper(imageFile.path));
                      },
                      onTap3: () {
                        HapticFeedback.vibrate();
                        Navigator.of(context).pop();
                        Future.delayed(const Duration(seconds: 1))
                            .then((value) => _setBothWallPaper(imageFile.path));
                      },
                    ),
                  );
                },
              )
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        body: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: loading
              ? Center(child: Loader())
              : Column(
                  children: [
                    Expanded(
                      flex: 6,
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: _buildFilteredImage(
                          _filter,
                          finalImage,
                          finalFilename,
                        ),
                      ),
                    ),
                    const Divider(
                      height: 1,
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        color: Theme.of(context).primaryColor,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          scrollDirection: Axis.horizontal,
                          itemCount: selectedFilters.length,
                          itemBuilder: (BuildContext context, int index) {
                            return GestureDetector(
                              onTap: () => setState(() {
                                _filter = selectedFilters[index];
                              }),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        _buildFilterThumbnail(
                                            selectedFilters[index],
                                            image,
                                            filename),
                                        if (_filter == selectedFilters[index])
                                          Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(500),
                                                color: Colors.white,
                                              ),
                                              child: const Icon(
                                                JamIcons.check,
                                                color: Colors.black,
                                              ))
                                        else
                                          Container(),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 10.0,
                                    ),
                                    Text(
                                      selectedFilters[index].name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyText2!
                                          .copyWith(
                                              color: Theme.of(context)
                                                  .accentColor),
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFilterThumbnail(
      Filter filter, imagelib.Image? image, String? filename) {
    if (cachedFilters[filter.name ?? "_"] == null) {
      return FutureBuilder<List<int>>(
        future: compute(applyFilter, <String, dynamic>{
          "filter": filter,
          "image": image,
          "filename": filename,
        }),
        builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
            case ConnectionState.active:
            case ConnectionState.waiting:
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 90.0,
                  height: MediaQuery.of(context).size.height * 0.15,
                  color: Theme.of(context).primaryColor,
                  child: Center(
                    child: Loader(),
                  ),
                ),
              );
            case ConnectionState.done:
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              cachedFilters[filter.name ?? "_"] = snapshot.data;
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 90.0,
                  height: MediaQuery.of(context).size.height * 0.15,
                  color: Theme.of(context).primaryColor,
                  child: Image(
                    image: MemoryImage(
                      (snapshot.data as Uint8List?)!,
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              );
          }
        },
      );
    } else {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 90.0,
          height: MediaQuery.of(context).size.height * 0.15,
          color: Theme.of(context).primaryColor,
          child: Image(
            image: MemoryImage(
              (cachedFilters[filter.name ?? "_"] as Uint8List?)!,
            ),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
  }

  Future<String> get _localPath async {
    final directory = await getTemporaryDirectory();

    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/filtered_${_filter?.name ?? "_"}_$finalFilename');
  }

  Future<File> saveFilteredImage() async {
    final imageFile = await _localFile;
    final List<int> finalFilterImageBytes =
        await compute(applyFilter, <String, dynamic>{
      "filter": _filter,
      "image": finalImage,
      "filename": finalFilename,
    });
    await imageFile.writeAsBytes(finalFilterImageBytes);
    return imageFile;
  }

  Widget _buildFilteredImage(
      Filter? filter, imagelib.Image? image, String? filename) {
    return FutureBuilder<List<int>>(
      future: compute(applyFilter, <String, dynamic>{
        "filter": filter,
        "image": image,
        "filename": filename,
      }),
      builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
            return cachedFilters[filter?.name ?? "_"] == null
                ? Center(child: Loader())
                : Stack(
                    children: [
                      PhotoView(
                        imageProvider: MemoryImage(
                          (cachedFilters[filter?.name ?? "_"] as Uint8List?)!,
                        ),
                        backgroundDecoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              height: 25,
                              width: 25,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(
                                  // Provider.of<ThemeModeExtended>(context)
                                  //                 .getCurrentModeStyle(
                                  //                     MediaQuery.of(context)
                                  //                         .platformBrightness) ==
                                  //             "Dark" &&
                                  //         Provider.of<DarkThemeModel>(context)
                                  //                 .currentTheme ==
                                  //             kDarkTheme2
                                  //     ? Theme.of(context).errorColor ==
                                  //             Colors.black
                                  //         ? Theme.of(context).accentColor
                                  //         : Theme.of(context).errorColor
                                  //     :
                                  Theme.of(context).errorColor,
                                ),
                              ),
                            ),
                            Icon(Icons.high_quality_rounded,
                                color: Theme.of(context).accentColor),
                          ],
                        ),
                      ),
                    ],
                  );
          case ConnectionState.active:
          case ConnectionState.waiting:
            return cachedFilters[filter?.name ?? "_"] == null
                ? Center(child: Loader())
                : Stack(
                    children: [
                      PhotoView(
                        imageProvider: MemoryImage(
                          (cachedFilters[filter?.name ?? "_"] as Uint8List?)!,
                        ),
                        backgroundDecoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              height: 25,
                              width: 25,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(
                                  // Provider.of<ThemeModeExtended>(context)
                                  //                 .getCurrentModeStyle(
                                  //                     MediaQuery.of(context)
                                  //                         .platformBrightness) ==
                                  //             "Dark" &&
                                  //         Provider.of<DarkThemeModel>(context)
                                  //                 .currentTheme ==
                                  //             kDarkTheme2
                                  //     ? Theme.of(context).errorColor ==
                                  //             Colors.black
                                  //         ? Theme.of(context).accentColor
                                  //         : Theme.of(context).errorColor
                                  //     :
                                  Theme.of(context).errorColor,
                                ),
                              ),
                            ),
                            Icon(Icons.high_quality_rounded,
                                color: Theme.of(context).accentColor),
                          ],
                        ),
                      ),
                    ],
                  );
          case ConnectionState.done:
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            cachedFilters[filter?.name ?? "_"] = snapshot.data;
            return PhotoView(
              imageProvider: MemoryImage(
                (snapshot.data as Uint8List?)!,
              ),
              backgroundDecoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
            );
        }
      },
    );
  }
}

///The global applyfilter function
List<int> applyFilter(Map<String, dynamic> params) {
  final Filter? filter = params["filter"] as Filter?;
  final imagelib.Image image = params["image"] as imagelib.Image;
  final String filename = params["filename"] as String;
  List<int> _bytes = image.getBytes();
  if (filter != null) {
    filter.apply(_bytes as Uint8List, image.width, image.height);
  }
  final imagelib.Image _image =
      imagelib.Image.fromBytes(image.width, image.height, _bytes);

  return _bytes = imagelib.encodeNamedImage(_image, filename)!;
}

///The global buildThumbnail function
List<int> buildThumbnail(Map<String, dynamic> params) {
  final int width = params["width"] as int;
  params["image"] =
      imagelib.copyResize(params["image"] as imagelib.Image, width: width);
  return applyFilter(params);
}
