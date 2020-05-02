import 'dart:io';
import 'dart:ui';
import 'package:fab_circular_menu/fab_circular_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:wallpapers_app/downloadmenu.dart';

class Display2 extends StatefulWidget {
  File image;
  Display2(this.image);
  @override
  _Display2State createState() => _Display2State();
}

class _Display2State extends State<Display2> {
  final GlobalKey<FabCircularMenuState> fabKey = GlobalKey();
  bool isOpen = false;
  double opacity = 0.0;
  bool isFile = false;

  @override
  void initState() {
    super.initState();
    isFile = false;
    isOpen = false;
    opacity = 0.0;
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
            tag: widget.image.path.toString(),
            child: Container(
              width: 720.w,
              height: 1440.h,
              decoration: BoxDecoration(
                  image: DecorationImage(
                image: FileImage(
                  widget.image,
                ),
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
        DownloadMenu(
          Color(0xFFFFFFFF),
          Color(0xFF000000),
          isOpen,
          widget.image,
          opacity,
          changeIsOpenTrue,
          changeIsOpenFalse,
        )
      ],
    );
  }
}
