import 'dart:ui';
import 'package:cache_image/cache_image.dart';
import 'package:fab_circular_menu/fab_circular_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:wallpaper_manager/wallpaper_manager.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image/image.dart' as IMG;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class Display extends StatefulWidget {
  String link = "";
  String thumb = "";
  String color = "";
  String color2 = "";
  String views = "";
  String resolution = "";
  String url = "";
  String createdAt = "";
  String favourites = "";
  Display(this.link, this.thumb, this.color, this.color2, this.views,
      this.resolution, this.url, this.createdAt, this.favourites);
  @override
  _DisplayState createState() => _DisplayState();
}

class _DisplayState extends State<Display> {
  final GlobalKey<FabCircularMenuState> fabKey = GlobalKey();
  bool isOpen = false;
  var file;
  bool isFile = false;
  void getFile() async {
    file = await DefaultCacheManager().getSingleFile(widget.link);
    if (this.mounted) {
      setState(() {
        isFile = true;
      });
    }
    // print(file.path.toString());
  }

  @override
  void initState() {
    super.initState();
    isFile = false;
    isOpen = false;
    getFile();
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
    ScreenUtil.init(context, width: 720, height: 1440, allowFontScaling: true);
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Container(
            width: 720.w,
            height: 1440.h,
            decoration: BoxDecoration(
                image: DecorationImage(
              image: isFile ? FileImage(file) : CacheImage(widget.thumb),
              fit: BoxFit.cover,
            )),
            child: isOpen
                ? BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(
                      color: Colors.transparent,
                    ),
                  )
                : Container(
                    child: Text(""),
                  )),
        Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                padding: EdgeInsets.fromLTRB(0, 0, 50.w, 0),
                width: 720.w,
                height: 1440.h,
                child: FabCircularMenu(
                  key: fabKey,
                  animationCurve: Curves.easeOutSine,
                  fabOpenIcon: Icon(
                    Icons.info_outline,
                    color: Hexcolor("#${widget.color2}"),
                  ),
                  fabCloseIcon: Icon(
                    Icons.close,
                    color: Hexcolor("#${widget.color2}"),
                  ),
                  ringDiameter: 600.w,
                  animationDuration: Duration(milliseconds: 500),
                  alignment: Alignment.bottomCenter,
                  ringColor: Colors.transparent,
                  fabColor: Hexcolor("#${widget.color}"),
                  children: <Widget>[
                    FloatingActionButton(
                        child: Icon(
                          Icons.file_download,
                          color: Hexcolor("#${widget.color2}"),
                        ),
                        backgroundColor: Hexcolor("#${widget.color}"),
                        onPressed: () {
                          // print('Home');
                        }),
                    FloatingActionButton(
                        backgroundColor: Hexcolor("#${widget.color}"),
                        child: Icon(
                          Icons.format_paint,
                          color: Hexcolor("#${widget.color2}"),
                        ),
                        onPressed: isFile
                            ? () async {
                                showDialog(
                                  context: context,
                                  child: AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(24),
                                      ),
                                    ),
                                    content: Container(
                                      height: 270.h,
                                      width: 200.w,
                                      child: ListView.builder(
                                          itemCount: 3,
                                          itemBuilder: (context, index) {
                                            return ListTile(
                                              leading: Icon(index == 0
                                                  ? Icons.add_to_home_screen
                                                  : index == 1
                                                      ? Icons
                                                          .screen_lock_portrait
                                                      : Icons.wallpaper),
                                              title: Text(index == 0
                                                  ? "Home Screen"
                                                  : index == 1
                                                      ? "Lock Screen"
                                                      : "Both"),
                                              onTap: index == 0
                                                  ? () async {
                                                      HapticFeedback.vibrate();
                                                      Navigator.of(context)
                                                          .pop();
                                                      Directory
                                                          appDocDirectory =
                                                          await getApplicationDocumentsDirectory();
                                                      IMG.Image image =
                                                          IMG.decodeImage(File(
                                                                  file.path)
                                                              .readAsBytesSync());

                                                      IMG.Image newWall =
                                                          IMG.copyResize(image,
                                                              height: ScreenUtil
                                                                  .screenHeight
                                                                  .round());
                                                      File(
                                                          appDocDirectory.path +
                                                              '/' +
                                                              'wallpaper.png')
                                                        ..writeAsBytesSync(
                                                            IMG.encodePng(
                                                                newWall));
                                                      int location =
                                                          WallpaperManager
                                                              .HOME_SCREEN;

                                                      final String result1 =
                                                          await WallpaperManager
                                                              .setWallpaperFromFile(
                                                                  appDocDirectory
                                                                          .path +
                                                                      '/' +
                                                                      'wallpaper.png',
                                                                  location);
                                                    }
                                                  : index == 1
                                                      ? () async {
                                                          HapticFeedback
                                                              .vibrate();
                                                          Navigator.of(context)
                                                              .pop();
                                                          Directory
                                                              appDocDirectory =
                                                              await getApplicationDocumentsDirectory();
                                                          IMG.Image image = IMG
                                                              .decodeImage(File(
                                                                      file.path)
                                                                  .readAsBytesSync());

                                                          IMG.Image newWall =
                                                              IMG.copyResize(
                                                                  image,
                                                                  height: ScreenUtil
                                                                      .screenHeight
                                                                      .round());
                                                          File(appDocDirectory
                                                                  .path +
                                                              '/' +
                                                              'wallpaper.png')
                                                            ..writeAsBytesSync(
                                                                IMG.encodePng(
                                                                    newWall));
                                                          int location =
                                                              WallpaperManager
                                                                  .LOCK_SCREEN;
                                                          final String result2 =
                                                              await WallpaperManager
                                                                  .setWallpaperFromFile(
                                                                      appDocDirectory
                                                                              .path +
                                                                          '/' +
                                                                          'wallpaper.png',
                                                                      location);
                                                        }
                                                      : () async {
                                                          HapticFeedback
                                                              .vibrate();
                                                          Navigator.of(context)
                                                              .pop();
                                                          Directory
                                                              appDocDirectory =
                                                              await getApplicationDocumentsDirectory();
                                                          IMG.Image image = IMG
                                                              .decodeImage(File(
                                                                      file.path)
                                                                  .readAsBytesSync());

                                                          IMG.Image newWall =
                                                              IMG.copyResize(
                                                                  image,
                                                                  height: ScreenUtil
                                                                      .screenHeight
                                                                      .round());
                                                          File(appDocDirectory
                                                                  .path +
                                                              '/' +
                                                              'wallpaper.png')
                                                            ..writeAsBytesSync(
                                                                IMG.encodePng(
                                                                    newWall));
                                                          int location =
                                                              WallpaperManager
                                                                  .HOME_SCREEN;

                                                          final String result1 =
                                                              await WallpaperManager
                                                                  .setWallpaperFromFile(
                                                                      appDocDirectory
                                                                              .path +
                                                                          '/' +
                                                                          'wallpaper.png',
                                                                      location);
                                                          location =
                                                              WallpaperManager
                                                                  .LOCK_SCREEN;
                                                          final String result2 =
                                                              await WallpaperManager
                                                                  .setWallpaperFromFile(
                                                                      appDocDirectory
                                                                              .path +
                                                                          '/' +
                                                                          'wallpaper.png',
                                                                      location);
                                                        },
                                            );
                                          }),
                                    ),
                                  ),
                                );
                              }
                            : null),
                    FloatingActionButton(
                      child: Icon(
                        Icons.favorite,
                        color: Hexcolor("#${widget.color2}"),
                      ),
                      backgroundColor: Hexcolor("#${widget.color}"),
                      onPressed: () {
                        // print('Favorite');
                      },
                    )
                  ],
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: () {
                    if (isOpen) {
                      fabKey.currentState.close();
                      setState(() {
                        isOpen = false;
                      });
                    } else {
                      fabKey.currentState.open();
                      setState(() {
                        isOpen = true;
                      });
                    }
                  },
                  child: Container(
                    width: 100.w,
                    height: 100.h,
                    color: Colors.transparent,
                  ),
                ),
              ),
              isOpen
                  ? Card(
                      color: Hexcolor("#${widget.color}"),
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(24),
                        ),
                      ),
                      child: SizedBox(
                        width: 500.w,
                        height: 400.h,
                        child: Container(
                          padding:
                              EdgeInsets.fromLTRB(100.w, 20.w, 100.w, 20.w),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Icon(
                                      Icons.remove_red_eye,
                                      color: Hexcolor("#${widget.color2}"),
                                    ),
                                    Text(
                                      "${widget.views}",
                                      style: TextStyle(
                                        color: Hexcolor("#${widget.color2}"),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Icon(
                                      Icons.favorite,
                                      color: Hexcolor("#${widget.color2}"),
                                    ),
                                    Text(
                                      "${widget.favourites}",
                                      style: TextStyle(
                                        color: Hexcolor("#${widget.color2}"),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Icon(
                                      Icons.photo_size_select_large,
                                      color: Hexcolor("#${widget.color2}"),
                                    ),
                                    Text(
                                      "${widget.resolution}",
                                      style: TextStyle(
                                        color: Hexcolor("#${widget.color2}"),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Icon(
                                      Icons.link,
                                      color: Hexcolor("#${widget.color2}"),
                                    ),
                                    Text(
                                      "${widget.url}",
                                      style: TextStyle(
                                        color: Hexcolor("#${widget.color2}"),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Icon(
                                      Icons.calendar_today,
                                      color: Hexcolor("#${widget.color2}"),
                                    ),
                                    Text(
                                      "${widget.createdAt}",
                                      style: TextStyle(
                                        color: Hexcolor("#${widget.color2}"),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Container()
            ],
          ),
          // FloatingActionButton(
          //     backgroundColor: Hexcolor("#${widget.color}"),
          //     child: Icon(Icons.format_paint, color: widget.color!="000000" ? Colors.black38 : Colors.white,),
          //     onPressed: isFile
          //         ? () async {
          //             showDialog(
          //               context: context,
          //               child: AlertDialog(
          // shape: RoundedRectangleBorder(
          //   borderRadius: BorderRadius.all(
          //     Radius.circular(24),
          //                   ),
          //                 ),
          //                 content: Container(
          //                   height: 270.h,
          //                   width: 200.w,
          //                   child: ListView.builder(
          //                       itemCount: 3,
          //                       itemBuilder: (context, index) {
          //                         return ListTile(
          //                           leading: Icon(index == 0
          //                               ? Icons.add_to_home_screen
          //                               : index == 1
          //                                   ? Icons.screen_lock_portrait
          //                                   : Icons.wallpaper),
          //                           title: Text(index == 0
          //                               ? "Home Screen"
          //                               : index == 1
          //                                   ? "Lock Screen"
          //                                   : "Both"),
          //                           onTap: index == 0
          //                               ? () async {
          //                                   HapticFeedback.vibrate();
          //                                   Navigator.of(context).pop();
          //                                   Directory appDocDirectory =
          //                                       await getApplicationDocumentsDirectory();
          //                                   IMG.Image image = IMG
          //                                       .decodeImage(File(file.path)
          //                                           .readAsBytesSync());

          //                                   IMG.Image newWall =
          //                                       IMG.copyResize(image,
          //                                           height: ScreenUtil
          //                                               .screenHeight
          //                                               .round());
          //                                   File(appDocDirectory.path +
          //                                       '/' +
          //                                       'wallpaper.png')
          //                                     ..writeAsBytesSync(
          //                                         IMG.encodePng(newWall));
          //                                   int location = WallpaperManager
          //                                       .HOME_SCREEN;

          //                                   final String result1 =
          //                                       await WallpaperManager
          //                                           .setWallpaperFromFile(
          //                                               appDocDirectory
          //                                                       .path +
          //                                                   '/' +
          //                                                   'wallpaper.png',
          //                                               location);
          //                                 }
          //                               : index == 1
          //                                   ? () async {
          //                                       HapticFeedback.vibrate();
          //                                       Navigator.of(context).pop();
          //                                       Directory appDocDirectory =
          //                                           await getApplicationDocumentsDirectory();
          //                                       IMG.Image image =
          //                                           IMG.decodeImage(File(
          //                                                   file.path)
          //                                               .readAsBytesSync());

          //                                       IMG.Image newWall =
          //                                           IMG.copyResize(image,
          //                                               height: ScreenUtil
          //                                                   .screenHeight
          //                                                   .round());
          //                                       File(appDocDirectory.path +
          //                                           '/' +
          //                                           'wallpaper.png')
          //                                         ..writeAsBytesSync(IMG
          //                                             .encodePng(newWall));
          //                                       int location =
          //                                           WallpaperManager
          //                                               .LOCK_SCREEN;
          //                                       final String result2 =
          //                                           await WallpaperManager
          //                                               .setWallpaperFromFile(
          //                                                   appDocDirectory
          //                                                           .path +
          //                                                       '/' +
          //                                                       'wallpaper.png',
          //                                                   location);
          //                                     }
          //                                   : () async {
          //                                       HapticFeedback.vibrate();
          //                                       Navigator.of(context).pop();
          //                                       Directory appDocDirectory =
          //                                           await getApplicationDocumentsDirectory();
          //                                       IMG.Image image =
          //                                           IMG.decodeImage(File(
          //                                                   file.path)
          //                                               .readAsBytesSync());

          //                                       IMG.Image newWall =
          //                                           IMG.copyResize(image,
          //                                               height: ScreenUtil
          //                                                   .screenHeight
          //                                                   .round());
          //                                       File(appDocDirectory.path +
          //                                           '/' +
          //                                           'wallpaper.png')
          //                                         ..writeAsBytesSync(IMG
          //                                             .encodePng(newWall));
          //                                       int location =
          //                                           WallpaperManager
          //                                               .HOME_SCREEN;

          //                                       final String result1 =
          //                                           await WallpaperManager
          //                                               .setWallpaperFromFile(
          //                                                   appDocDirectory
          //                                                           .path +
          //                                                       '/' +
          //                                                       'wallpaper.png',
          //                                                   location);
          //                                       location = WallpaperManager
          //                                           .LOCK_SCREEN;
          //                                       final String result2 =
          //                                           await WallpaperManager
          //                                               .setWallpaperFromFile(
          //                                                   appDocDirectory
          //                                                           .path +
          //                                                       '/' +
          //                                                       'wallpaper.png',
          //                                                   location);
          //                                     },
          //                         );
          //                       }),
          //                 ),
          //               ),
          //             );
          //           }
          //         : null),
        )
      ],
    );
  }
}
