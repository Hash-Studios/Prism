import 'dart:ui';
import 'package:cache_image/cache_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:Prism/ui/radialmenu.dart';

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
  String size = "";
  Display(this.link, this.thumb, this.color, this.color2, this.views,
      this.resolution, this.url, this.createdAt, this.favourites, this.size);
  @override
  _DisplayState createState() => _DisplayState();
}

class _DisplayState extends State<Display> {
  bool isOpen = false;
  double opacity = 0.0;
  var file;
  bool isFile = false;
  void getFile() async {
    file = await DefaultCacheManager().getSingleFile(widget.link);
    if (this.mounted) {
      setState(() {
        isFile = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    isFile = false;
    isOpen = false;
    opacity = 0.0;
    getFile();
  }

  @override
  void dispose() {
    super.dispose();
    SystemChrome.setEnabledSystemUIOverlays(
        [SystemUiOverlay.top, SystemUiOverlay.bottom]);
  }

  void changeIsOpenTrue() {
    if (this.mounted) {
      setState(() {
        isOpen = true;
      });
    }
  }

  void changeIsOpenFalse() {
    if (this.mounted) {
      setState(() {
        isOpen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIOverlays([]);
    ScreenUtil.init(context, width: 720, height: 1440, allowFontScaling: true);
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        new Hero(
            tag: widget.url,
            child: Container(
              width: 720.w,
              height: 1440.h,
              decoration: BoxDecoration(
                  image: DecorationImage(
                image: isFile ? FileImage(file) : CacheImage(widget.thumb),
                fit: BoxFit.cover,
              )),
            )),
        Container(
            width: 720.w,
            height: 1440.h,
            child: isOpen
                ? BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                    child: Container(color: Colors.transparent),
                  )
                : Container()),
        RadialMenu(
          Hexcolor("#${widget.color}"),
          Hexcolor("#${widget.color2}"),
          isOpen,
          isFile,
          file,
          widget.link,
          widget.thumb,
          widget.views,
          widget.resolution,
          widget.url,
          widget.createdAt,
          widget.favourites,
          widget.size,
          opacity,
          changeIsOpenTrue,
          changeIsOpenFalse,
        )
      ],
    );
  }
}
