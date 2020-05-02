import 'package:flutter/material.dart';
import 'dart:math';
import 'package:vector_math/vector_math.dart' show radians;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:wallpaper_manager/wallpaper_manager.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gallery_saver/gallery_saver.dart';

class RadialMenu extends StatefulWidget {
  Color color;
  Color color2;
  bool isOpen;
  bool isFile;
  var file;
  String link = "";
  String thumb = "";
  String views = "";
  String resolution = "";
  String url = "";
  String createdAt = "";
  String favourites = "";
  String size = "";
  double opacity;
  Function changeIsOpenTrue;
  Function changeIsOpenFalse;
  RadialMenu(
      this.color,
      this.color2,
      this.isOpen,
      this.isFile,
      this.file,
      this.link,
      this.thumb,
      this.views,
      this.resolution,
      this.url,
      this.createdAt,
      this.favourites,
      this.size,
      this.opacity,
      this.changeIsOpenTrue,
      this.changeIsOpenFalse);
  createState() => _RadialMenuState();
}

class _RadialMenuState extends State<RadialMenu>
    with SingleTickerProviderStateMixin {
  AnimationController controller;
  @override
  void initState() {
    super.initState();
    controller =
        AnimationController(duration: Duration(milliseconds: 300), vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return RadialAnimation(
      controller: controller,
      color: widget.color,
      color2: widget.color2,
      isOpen: widget.isOpen,
      isFile: widget.isFile,
      file: widget.file,
      link: widget.link,
      thumb: widget.thumb,
      views: widget.views,
      resolution: widget.resolution,
      url: widget.url,
      createdAt: widget.createdAt,
      favourites: widget.favourites,
      size: widget.size,
      opacity: widget.opacity,
      changeIsOpenTrue: widget.changeIsOpenTrue,
      changeIsOpenFalse: widget.changeIsOpenFalse,
    );
  }
}

// The Animation
class RadialAnimation extends StatefulWidget {
  final AnimationController controller;
  final Animation<double> scale;
  final Animation<double> scale2;
  final Animation<double> translation;
  final Animation<double> rotation;
  Color color;
  Color color2;
  bool isOpen;
  bool isFile;
  var file;
  String link = "";
  String thumb = "";
  String views = "";
  String resolution = "";
  String url = "";
  String createdAt = "";
  String favourites = "";
  String size = "";
  double opacity;
  Function changeIsOpenTrue;
  Function changeIsOpenFalse;
  RadialAnimation(
      {Key key,
      this.controller,
      this.color,
      this.color2,
      this.isOpen,
      this.isFile,
      this.file,
      this.link,
      this.thumb,
      this.views,
      this.resolution,
      this.url,
      this.createdAt,
      this.favourites,
      this.size,
      this.opacity,
      this.changeIsOpenTrue,
      this.changeIsOpenFalse})
      : scale = Tween<double>(
          begin: 1.3,
          end: 0.0,
        ).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeOutSine),
        ),
        scale2 = Tween<double>(
          begin: 0.9,
          end: 0.0,
        ).animate(
          CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn),
        ),
        translation = Tween<double>(
          begin: 0.0,
          end: 100.0,
        ).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
        ),
        rotation = Tween<double>(
          begin: 0.0,
          end: 360.0,
        ).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(
              0.3,
              0.9,
              curve: Curves.decelerate,
            ),
          ),
        ),
        super(key: key);

  @override
  _RadialAnimationState createState() => _RadialAnimationState();
}

class _RadialAnimationState extends State<RadialAnimation> {
  Future<bool> _onBackPressed() {
    _close();
    if (widget.isOpen) {
      widget.changeIsOpenFalse();
      Navigator.canPop(context);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  build(context) {
    ScreenUtil.init(context, width: 720, height: 1440);
    return WillPopScope(
      onWillPop: _onBackPressed,
      child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, builder) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 1060.h,
                  width: 720.w,
                ),
                Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    SizedBox(
                      height: 500.h,
                    ),
                    Transform(
                      transform: Matrix4.identity()
                        ..translate(0.1, -(widget.translation.value.h) * 6.5),
                      child: Transform.scale(
                        scale: 1.3 - widget.scale.value,
                        child: Card(
                          color: widget.color,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                          elevation: 8,
                          child: SizedBox(
                            height: 400.h,
                            width: 500.w,
                            child: Container(
                              padding:
                                  EdgeInsets.fromLTRB(60.w, 20.w, 60.w, 20.w),
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
                                          color: widget.color2,
                                        ),
                                        Text(
                                          "${widget.views}",
                                          style: TextStyle(
                                            color: widget.color2,
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
                                          color: widget.color2,
                                        ),
                                        Text(
                                          "${widget.favourites}",
                                          style: TextStyle(
                                            color: widget.color2,
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
                                          color: widget.color2,
                                        ),
                                        Text(
                                          "${widget.resolution}",
                                          style: TextStyle(
                                            color: widget.color2,
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
                                          Icons.file_download,
                                          color: widget.color2,
                                        ),
                                        Text(
                                          "${double.parse(((double.parse(widget.size) / 1000000).toString())).toStringAsFixed(2)} MB",
                                          style: TextStyle(
                                            color: widget.color2,
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
                                          color: widget.color2,
                                        ),
                                        Text(
                                          "${widget.createdAt}",
                                          style: TextStyle(
                                            color: widget.color2,
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildButton(215,
                        color: widget.color,
                        color2: widget.color2,
                        icon: Icons.file_download,
                        func: onDownload),
                    _buildButton(270,
                        color: widget.color,
                        color2: widget.color2,
                        icon: Icons.format_paint,
                        func: onPaint),
                    _buildButton(325,
                        color: widget.color,
                        color2: widget.color2,
                        icon: Icons.favorite,
                        func: _close),
                    Transform.scale(
                      scale: 1.3 - widget.scale.value,
                      child: FloatingActionButton(
                          heroTag: 1,
                          child: Icon(
                            Icons.close,
                            color: Colors.black,
                          ),
                          onPressed: () {
                            HapticFeedback.vibrate();
                            widget.changeIsOpenFalse();
                            _close();
                          },
                          backgroundColor: Colors.white),
                    ),
                    Transform.scale(
                      scale: widget.scale.value,
                      child: FloatingActionButton(
                          mini: true,
                          heroTag: 2,
                          child: Icon(
                            Icons.info_outline,
                            color: Colors.black,
                            size: 20,
                          ),
                          backgroundColor: Colors.white,
                          onPressed: () {
                            HapticFeedback.vibrate();
                            widget.changeIsOpenTrue();
                            _open();
                          }),
                    )
                  ],
                ),
              ],
            );
          }),
    );
  }

  _open() {
    widget.controller.forward();
  }

  _close() {
    widget.controller.reverse();
  }

  _buildButton(double angle,
      {Color color, Color color2, IconData icon, Function func}) {
    final double rad = radians(angle);
    return Transform.scale(
      scale: 0.9 - widget.scale2.value,
      child: Transform(
          transform: Matrix4.identity()
            ..translate((widget.translation.value) * cos(rad) * 1.2,
                (widget.translation.value) * sin(rad) * 1.2),
          child: FloatingActionButton(
              heroTag: 3 * angle,
              child: Icon(
                icon,
                color: color2,
              ),
              backgroundColor: color,
              onPressed: () {
                HapticFeedback.vibrate();
                widget.changeIsOpenFalse();
                _close();
                func();
              },
              elevation: 8)),
    );
  }

  void onPaint() async {
    if (widget.isFile) {
      if (this.mounted) {
        setState(() {
          widget.isOpen = false;
          widget.opacity = 0.0;
        });
      }
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
                        : index == 1 ? "Lock Screen" : "Both"),
                    onTap: index == 0
                        ? () async {
                            HapticFeedback.vibrate();
                            Navigator.of(context).pop();
                            int location = WallpaperManager.HOME_SCREEN;

                            final String result1 =
                                await WallpaperManager.setWallpaperFromFile(
                                    widget.file.path, location);
                            Fluttertoast.showToast(
                                msg: "Wallpaper Applied Successfully!",
                                toastLength: Toast.LENGTH_LONG,
                                timeInSecForIosWeb: 1,
                                textColor: Colors.white,
                                fontSize: 16.0);
                          }
                        : index == 1
                            ? () async {
                                HapticFeedback.vibrate();
                                Navigator.of(context).pop();

                                int location = WallpaperManager.LOCK_SCREEN;
                                final String result2 =
                                    await WallpaperManager.setWallpaperFromFile(
                                        widget.file.path, location);
                                Fluttertoast.showToast(
                                    msg: "Wallpaper Applied Successfully!",
                                    toastLength: Toast.LENGTH_LONG,
                                    timeInSecForIosWeb: 1,
                                    textColor: Colors.white,
                                    fontSize: 16.0);
                              }
                            : () async {
                                HapticFeedback.vibrate();
                                Navigator.of(context).pop();

                                int location = WallpaperManager.HOME_SCREEN;

                                final String result1 =
                                    await WallpaperManager.setWallpaperFromFile(
                                        widget.file.path, location);
                                location = WallpaperManager.LOCK_SCREEN;
                                final String result2 =
                                    await WallpaperManager.setWallpaperFromFile(
                                        widget.file.path, location);
                                Fluttertoast.showToast(
                                    msg: "Wallpaper Applied Successfully!",
                                    toastLength: Toast.LENGTH_LONG,
                                    timeInSecForIosWeb: 1,
                                    textColor: Colors.white,
                                    fontSize: 16.0);
                              },
                  );
                }),
          ),
        ),
      );
    } else {
      Fluttertoast.showToast(
          msg: "Wallpaper not loaded yet!",
          toastLength: Toast.LENGTH_LONG,
          timeInSecForIosWeb: 1,
          textColor: Colors.white,
          fontSize: 16.0);
    }
  }

  void onDownload() async {
    if (this.mounted) {
      setState(() {
        widget.isOpen = false;
        widget.opacity = 0.0;
      });
    }
    Fluttertoast.showToast(
        msg: "Starting Download",
        toastLength: Toast.LENGTH_LONG,
        timeInSecForIosWeb: 1,
        textColor: Colors.white,
        fontSize: 16.0);
    GallerySaver.saveImage(widget.link, albumName: "Prism").then((value) =>
        Fluttertoast.showToast(
            msg: "Downloaded image in Pictures/Prism!",
            toastLength: Toast.LENGTH_LONG,
            timeInSecForIosWeb: 1,
            textColor: Colors.white,
            fontSize: 16.0));
  }
}
