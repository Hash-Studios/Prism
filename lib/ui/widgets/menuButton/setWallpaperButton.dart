import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

class SetWallpaperButton extends StatefulWidget {
  final String url;
  final bool colorChanged;
  const SetWallpaperButton({
    Key key,
    @required this.url,
    @required this.colorChanged,
  }) : super(key: key);

  @override
  _SetWallpaperButtonState createState() => _SetWallpaperButtonState();
}

class _SetWallpaperButtonState extends State<SetWallpaperButton> {
  static const platform = const MethodChannel("flutter.prism.set_wallpaper");
  bool isLoading = false;

  void _setWallPaper() async {
    bool result;
    try {
      result = await platform.invokeMethod("set_wallpaper", <String, dynamic>{
        'url': widget.url,
      });
      if (result) {
        print("Success");
        analytics.logEvent(
            name: 'set_wall',
            parameters: {'type': 'Both', 'result': 'Success'});
        toasts.setWallpaper();
      } else {
        print("Failed");
        toasts.error("Something went wrong!");
      }
      if (this.mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      analytics.logEvent(
          name: 'set_wall', parameters: {'type': 'Both', 'result': 'Failure'});
      print(e);
    }
  }

  void _setLockWallPaper() async {
    bool result;
    try {
      result =
          await platform.invokeMethod("set_lock_wallpaper", <String, dynamic>{
        'url': widget.url,
      });
      if (result) {
        print("Success");
        analytics.logEvent(
            name: 'set_wall',
            parameters: {'type': 'Lock', 'result': 'Success'});
        toasts.setWallpaper();
      } else {
        print("Failed");
        toasts.error("Something went wrong!");
      }
      if (this.mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print(e);
      analytics.logEvent(
          name: 'set_wall', parameters: {'type': 'Lock', 'result': 'Failure'});
    }
  }

  void _setHomeWallPaper() async {
    bool result;
    try {
      result =
          await platform.invokeMethod("set_home_wallpaper", <String, dynamic>{
        'url': widget.url,
      });
      if (result) {
        print("Success");
        analytics.logEvent(
            name: 'set_wall',
            parameters: {'type': 'Home', 'result': 'Success'});
        toasts.setWallpaper();
      } else {
        print("Failed");
        toasts.error("Something went wrong!");
      }
      if (this.mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print(e);
      analytics.logEvent(
          name: 'set_wall', parameters: {'type': 'Home', 'result': 'Failure'});
    }
  }

  void onPaint() async {
    showDialog(
      context: context,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(20),
          ),
        ),
        content: Container(
          height: 200,
          width: 250,
          child: Center(
            child: ListView.builder(
                itemCount: 3,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: Icon(
                      index == 0
                          ? JamIcons.phone
                          : index == 1 ? JamIcons.key : JamIcons.picture,
                      color: Theme.of(context).accentColor,
                    ),
                    title: Text(
                      index == 0
                          ? "Home Screen"
                          : index == 1 ? "Lock Screen" : "Both",
                      style: Theme.of(context).textTheme.headline4,
                    ),
                    onTap: index == 0
                        ? () async {
                            HapticFeedback.vibrate();
                            Navigator.of(context).pop();
                            setState(() {
                              isLoading = true;
                            });
                            if (widget.colorChanged) {
                              Future.delayed(Duration(seconds: 2)).then(
                                  (value) =>
                                      Future.delayed(Duration(seconds: 1)).then(
                                          (value) => _setHomeWallPaper()));
                            } else {
                              Future.delayed(Duration(seconds: 1))
                                  .then((value) => _setHomeWallPaper());
                            }
                          }
                        : index == 1
                            ? () async {
                                HapticFeedback.vibrate();
                                Navigator.of(context).pop();
                                setState(() {
                                  isLoading = true;
                                });
                                if (widget.colorChanged) {
                                  Future.delayed(Duration(seconds: 2)).then(
                                      (value) =>
                                          Future.delayed(Duration(seconds: 1))
                                              .then((value) =>
                                                  _setLockWallPaper()));
                                } else {
                                  Future.delayed(Duration(seconds: 1))
                                      .then((value) => _setLockWallPaper());
                                }
                              }
                            : () async {
                                HapticFeedback.vibrate();
                                Navigator.of(context).pop();
                                setState(() {
                                  isLoading = true;
                                });
                                if (widget.colorChanged) {
                                  Future.delayed(Duration(seconds: 2)).then(
                                      (value) => Future.delayed(
                                              Duration(seconds: 1))
                                          .then((value) => _setWallPaper()));
                                } else {
                                  Future.delayed(Duration(seconds: 1))
                                      .then((value) => _setWallPaper());
                                }
                              },
                  );
                }),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onPaint();
      },
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(.25),
                    blurRadius: 4,
                    offset: Offset(0, 4))
              ],
              borderRadius: BorderRadius.circular(500),
            ),
            padding: EdgeInsets.all(17),
            child: Icon(
              JamIcons.picture,
              color: Theme.of(context).accentColor,
              size: 30,
            ),
          ),
          Positioned(
              top: 0,
              left: 0,
              height: 63,
              width: 63,
              child: isLoading ? CircularProgressIndicator() : Container())
        ],
      ),
    );
  }
}
