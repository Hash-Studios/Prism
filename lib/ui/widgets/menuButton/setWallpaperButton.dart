import 'dart:io' show Platform;
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:device_info/device_info.dart';
// import 'package:Prism/ui/widgets/popup/proPopUp.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:Prism/main.dart' as main;

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
      if (widget.url.contains("com.hash.prism")) {
        result =
            await platform.invokeMethod("set_wallpaper_file", <String, dynamic>{
          'url': widget.url,
        });
      } else if (widget.url.contains("/0/")) {
        result =
            await platform.invokeMethod("set_wallpaper_file", <String, dynamic>{
          'url': "/" + widget.url.replaceAll("/0//", "/0/"),
        });
      } else {
        result = await platform.invokeMethod("set_wallpaper", <String, dynamic>{
          'url': widget.url,
        });
      }
      if (result) {
        print("Success");
        analytics.logEvent(
            name: 'set_wall',
            parameters: {'type': 'Both', 'result': 'Success'});
        // toasts.codeSend("Wallpaper set successfully!");
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

  void _setBothWallPaper() async {
    bool result;
    try {
      if (widget.url.contains("com.hash.prism")) {
        result = await platform
            .invokeMethod("set_both_wallpaper_file", <String, dynamic>{
          'url': widget.url,
        });
      } else if (widget.url.contains("/0/")) {
        result = await platform
            .invokeMethod("set_both_wallpaper_file", <String, dynamic>{
          'url': "/" + widget.url.replaceAll("/0//", "/0/"),
        });
      } else {
        result =
            await platform.invokeMethod("set_both_wallpaper", <String, dynamic>{
          'url': widget.url,
        });
      }
      if (result) {
        print("Success");
        analytics.logEvent(
            name: 'set_wall',
            parameters: {'type': 'Both', 'result': 'Success'});
        toasts.codeSend("Wallpaper set successfully!");
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
      if (widget.url.contains("com.hash.prism")) {
        result = await platform
            .invokeMethod("set_lock_wallpaper_file", <String, dynamic>{
          'url': widget.url,
        });
      } else if (widget.url.contains("/0/")) {
        result = await platform
            .invokeMethod("set_lock_wallpaper_file", <String, dynamic>{
          'url': "/" + widget.url.replaceAll("/0//", "/0/"),
        });
      } else {
        result =
            await platform.invokeMethod("set_lock_wallpaper", <String, dynamic>{
          'url': widget.url,
        });
      }
      if (result) {
        print("Success");
        analytics.logEvent(
            name: 'set_wall',
            parameters: {'type': 'Lock', 'result': 'Success'});
        toasts.codeSend("Wallpaper set successfully!");
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
      if (widget.url.contains("com.hash.prism")) {
        result = await platform
            .invokeMethod("set_home_wallpaper_file", <String, dynamic>{
          'url': widget.url,
        });
      } else if (widget.url.contains("/0/")) {
        result = await platform
            .invokeMethod("set_home_wallpaper_file", <String, dynamic>{
          'url': "/" + widget.url.replaceAll("/0//", "/0/"),
        });
      } else {
        result =
            await platform.invokeMethod("set_home_wallpaper", <String, dynamic>{
          'url': widget.url,
        });
      }
      if (result) {
        print("Success");
        analytics.logEvent(
            name: 'set_wall',
            parameters: {'type': 'Home', 'result': 'Success'});
        toasts.codeSend("Wallpaper set successfully!");
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

  void showPremiumPopUp(Function func) {
    if (!main.prefs.get("isLoggedin")) {
      toasts.codeSend("Variants are a premium feature.");
      googleSignInPopUp(context, () {
        if (!main.prefs.get("premium")) {
          Navigator.pushNamed(context, PremiumRoute);
          // premiumPopUp(context, func);
        } else {
          func();
        }
      });
    } else {
      if (!main.prefs.get("premium")) {
        toasts.codeSend("Variants are a premium feature.");
        Navigator.pushNamed(context, PremiumRoute);
        // premiumPopUp(context, func);
      } else {
        func();
      }
    }
  }

  void onPaint() async {
    HapticFeedback.vibrate();
    if (widget.colorChanged) {
      showPremiumPopUp(() async {
        setState(() {
          isLoading = true;
        });
        Future.delayed(Duration(seconds: 1)).then((value) => _setWallPaper());
      });
    } else {
      setState(() {
        isLoading = true;
      });
      Future.delayed(Duration(seconds: 1)).then((value) => _setWallPaper());
    }
  }

  void onTapPaint() async {
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
                            if (widget.colorChanged) {
                              showPremiumPopUp(() async {
                                setState(() {
                                  isLoading = true;
                                });
                                Future.delayed(Duration(seconds: 1))
                                    .then((value) => _setHomeWallPaper());
                              });
                            } else {
                              setState(() {
                                isLoading = true;
                              });
                              Future.delayed(Duration(seconds: 1))
                                  .then((value) => _setHomeWallPaper());
                            }
                          }
                        : index == 1
                            ? () async {
                                HapticFeedback.vibrate();
                                Navigator.of(context).pop();
                                if (widget.colorChanged) {
                                  showPremiumPopUp(() async {
                                    setState(() {
                                      isLoading = true;
                                    });
                                    Future.delayed(Duration(seconds: 1))
                                        .then((value) => _setLockWallPaper());
                                  });
                                } else {
                                  setState(() {
                                    isLoading = true;
                                  });
                                  Future.delayed(Duration(seconds: 1))
                                      .then((value) => _setLockWallPaper());
                                }
                              }
                            : () async {
                                HapticFeedback.vibrate();
                                Navigator.of(context).pop();
                                if (widget.colorChanged) {
                                  showPremiumPopUp(() async {
                                    setState(() {
                                      isLoading = true;
                                    });
                                    Future.delayed(Duration(seconds: 1))
                                        .then((value) => _setBothWallPaper());
                                  });
                                } else {
                                  setState(() {
                                    isLoading = true;
                                  });
                                  Future.delayed(Duration(seconds: 1))
                                      .then((value) => _setBothWallPaper());
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
      onLongPress: () async {
        if (Platform.isAndroid) {
          var androidInfo = await DeviceInfoPlugin().androidInfo;
          var sdkInt = androidInfo.version.sdkInt;
          print('(SDK $sdkInt)');
          isLoading
              ? print("")
              : sdkInt >= 24
                  ? onPaint()
                  : toasts
                      .error("Crop is supported for Android 7.0 and above!");
        } else {
          toasts.error("Sorry crop is supported for Android 7.0 and above!");
        }
      },
      onTap: () {
        isLoading ? print("") : onTapPaint();
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
