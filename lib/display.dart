import 'package:cache_image/cache_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:wallpaper_manager/wallpaper_manager.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class Display extends StatefulWidget {
  String link = "";
  String thumb = "";
  String color = "";
  Display(this.link, this.thumb, this.color);
  @override
  _DisplayState createState() => _DisplayState();
}

class _DisplayState extends State<Display> {
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
          child: FadeInImage(
            image: CacheImage(widget.link),
            placeholder: CacheImage(widget.thumb),
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
                  onPressed: () async {
                    int location = WallpaperManager
                        .LOCK_SCREEN; // or location = WallpaperManager.LOCK_SCREEN;
                    String result;
                    var file =
                        await DefaultCacheManager().getSingleFile(widget.link);
                    final String result1 =
                        await WallpaperManager.setWallpaperFromFile(
                            file.path, location);
                  }),
            ))
      ],
    );
  }
}
