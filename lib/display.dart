import 'package:cache_image/cache_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:wallpaper_manager/wallpaper_manager.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image/image.dart' as IMG;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class Display extends StatefulWidget {
  String link = "";
  String thumb = "";
  String color = "";
  Display(this.link, this.thumb, this.color);
  @override
  _DisplayState createState() => _DisplayState();
}

class _DisplayState extends State<Display> {
  var file;
  bool isFile = false;
  void getFile() async {
    file = await DefaultCacheManager().getSingleFile(widget.link);
    if (this.mounted) {
      setState(() {
        isFile = true;
      });
    }
    print(file.path.toString());
  }

  @override
  void initState() {
    super.initState();
    isFile = false;
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
      children: <Widget>[
        SizedBox(
          width: 720.w,
          height: 1440.h,
          child: Image(
            image: isFile ? AssetImage(file.path) : CacheImage(widget.thumb),
            fit: BoxFit.cover,
          ),
        ),
        Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: FloatingActionButton(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.format_paint),
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
                                                ? Icons.screen_lock_portrait
                                                : Icons.wallpaper),
                                        title: Text(index == 0
                                            ? "Home Screen"
                                            : index == 1
                                                ? "Lock Screen"
                                                : "Both"),
                                        onTap: index == 0
                                            ? () async {
                                                HapticFeedback.vibrate();
                                                Navigator.of(context).pop();
                                                Directory appDocDirectory =
                                                    await getApplicationDocumentsDirectory();
                                                IMG.Image image = IMG
                                                    .decodeImage(File(file.path)
                                                        .readAsBytesSync());

                                                IMG.Image newWall =
                                                    IMG.copyResize(image,
                                                        height: ScreenUtil
                                                            .screenHeight
                                                            .round());
                                                File(appDocDirectory.path +
                                                    '/' +
                                                    'wallpaper.png')
                                                  ..writeAsBytesSync(
                                                      IMG.encodePng(newWall));
                                                int location = WallpaperManager
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
                                                    HapticFeedback.vibrate();
                                                    Navigator.of(context).pop();
                                                    Directory appDocDirectory =
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
                                                    File(appDocDirectory.path +
                                                        '/' +
                                                        'wallpaper.png')
                                                      ..writeAsBytesSync(IMG
                                                          .encodePng(newWall));
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
                                                    HapticFeedback.vibrate();
                                                    Navigator.of(context).pop();
                                                    Directory appDocDirectory =
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
                                                    File(appDocDirectory.path +
                                                        '/' +
                                                        'wallpaper.png')
                                                      ..writeAsBytesSync(IMG
                                                          .encodePng(newWall));
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
                                                    location = WallpaperManager
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
            ))
      ],
    );
  }
}
