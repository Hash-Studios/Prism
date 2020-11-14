import 'dart:io' show Platform;
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:animations/animations.dart';
import 'package:device_info/device_info.dart';
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
  static const platform = MethodChannel("flutter.prism.set_wallpaper");
  bool isLoading = false;

  Future<void> _setWallPaper() async {
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
          'url': "/${widget.url.replaceAll("/0//", "/0/")}",
        });
      } else {
        result = await platform.invokeMethod("set_wallpaper", <String, dynamic>{
          'url': widget.url,
        });
      }
      if (result) {
        debugPrint("Success");
        analytics.logEvent(
            name: 'set_wall',
            parameters: {'type': 'Both', 'result': 'Success'});
      } else {
        debugPrint("Failed");
        toasts.error("Something went wrong!");
      }
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      analytics.logEvent(
          name: 'set_wall', parameters: {'type': 'Both', 'result': 'Failure'});
      debugPrint(e.toString());
    }
  }

  Future<void> _setBothWallPaper() async {
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
          'url': "/${widget.url.replaceAll("/0//", "/0/")}",
        });
      } else {
        result =
            await platform.invokeMethod("set_both_wallpaper", <String, dynamic>{
          'url': widget.url,
        });
      }
      if (result) {
        debugPrint("Success");
        analytics.logEvent(
            name: 'set_wall',
            parameters: {'type': 'Both', 'result': 'Success'});
        toasts.codeSend("Wallpaper set successfully!");
      } else {
        debugPrint("Failed");
        toasts.error("Something went wrong!");
      }
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      analytics.logEvent(
          name: 'set_wall', parameters: {'type': 'Both', 'result': 'Failure'});
      debugPrint(e.toString());
    }
  }

  Future<void> _setLockWallPaper() async {
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
          'url': "/${widget.url.replaceAll("/0//", "/0/")}",
        });
      } else {
        result =
            await platform.invokeMethod("set_lock_wallpaper", <String, dynamic>{
          'url': widget.url,
        });
      }
      if (result) {
        debugPrint("Success");
        analytics.logEvent(
            name: 'set_wall',
            parameters: {'type': 'Lock', 'result': 'Success'});
        toasts.codeSend("Wallpaper set successfully!");
      } else {
        debugPrint("Failed");
        toasts.error("Something went wrong!");
      }
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
      analytics.logEvent(
          name: 'set_wall', parameters: {'type': 'Lock', 'result': 'Failure'});
    }
  }

  Future<void> _setHomeWallPaper() async {
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
          'url': "/${widget.url.replaceAll("/0//", "/0/")}",
        });
      } else {
        result =
            await platform.invokeMethod("set_home_wallpaper", <String, dynamic>{
          'url': widget.url,
        });
      }
      if (result) {
        debugPrint("Success");
        analytics.logEvent(
            name: 'set_wall',
            parameters: {'type': 'Home', 'result': 'Success'});
        toasts.codeSend("Wallpaper set successfully!");
      } else {
        debugPrint("Failed");
        toasts.error("Something went wrong!");
      }
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
      analytics.logEvent(
          name: 'set_wall', parameters: {'type': 'Home', 'result': 'Failure'});
    }
  }

  // void showPremiumPopUp(Function func) {
  //   if (main.prefs.get("isLoggedin") == false) {
  //     toasts.codeSend("Variants are a premium feature.");
  //     googleSignInPopUp(context, () {
  //       if (main.prefs.get("premium") == false) {
  //         Navigator.pushNamed(context, premiumRoute);
  //       } else {
  //         func();
  //       }
  //     });
  //   } else {
  //     if (main.prefs.get("premium") == false) {
  //       toasts.codeSend("Variants are a premium feature.");
  //       Navigator.pushNamed(context, premiumRoute);
  //     } else {
  //       func();
  //     }
  //   }
  // }

  Future<void> onPaint() async {
    HapticFeedback.vibrate();
    if (widget.colorChanged) {
      // showPremiumPopUp(() async {
      setState(() {
        isLoading = true;
      });
      Future.delayed(const Duration(seconds: 1))
          .then((value) => _setWallPaper());
      // });
    } else {
      setState(() {
        isLoading = true;
      });
      Future.delayed(const Duration(seconds: 1))
          .then((value) => _setWallPaper());
    }
  }

  Future<void> onTapPaint() async {
    showModal(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(),
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).hintColor,
        shape: const RoundedRectangleBorder(
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
                          : index == 1
                              ? JamIcons.key
                              : JamIcons.picture,
                      color: Theme.of(context).accentColor,
                    ),
                    title: Text(
                      index == 0
                          ? "Home Screen"
                          : index == 1
                              ? "Lock Screen"
                              : "Both",
                      style: Theme.of(context).textTheme.headline4,
                    ),
                    onTap: index == 0
                        ? () async {
                            HapticFeedback.vibrate();
                            Navigator.of(context).pop();
                            if (widget.colorChanged) {
                              // showPremiumPopUp(() async {
                              setState(() {
                                isLoading = true;
                              });
                              Future.delayed(const Duration(seconds: 1))
                                  .then((value) => _setHomeWallPaper());
                              // });
                            } else {
                              setState(() {
                                isLoading = true;
                              });
                              Future.delayed(const Duration(seconds: 1))
                                  .then((value) => _setHomeWallPaper());
                            }
                          }
                        : index == 1
                            ? () async {
                                HapticFeedback.vibrate();
                                Navigator.of(context).pop();
                                if (widget.colorChanged) {
                                  // showPremiumPopUp(() async {
                                  setState(() {
                                    isLoading = true;
                                  });
                                  Future.delayed(const Duration(seconds: 1))
                                      .then((value) => _setLockWallPaper());
                                  // });
                                } else {
                                  setState(() {
                                    isLoading = true;
                                  });
                                  Future.delayed(const Duration(seconds: 1))
                                      .then((value) => _setLockWallPaper());
                                }
                              }
                            : () async {
                                HapticFeedback.vibrate();
                                Navigator.of(context).pop();
                                if (widget.colorChanged) {
                                  // showPremiumPopUp(() async {
                                  setState(() {
                                    isLoading = true;
                                  });
                                  Future.delayed(const Duration(seconds: 1))
                                      .then((value) => _setBothWallPaper());
                                  // });
                                } else {
                                  setState(() {
                                    isLoading = true;
                                  });
                                  Future.delayed(const Duration(seconds: 1))
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
          final androidInfo = await DeviceInfoPlugin().androidInfo;
          final sdkInt = androidInfo.version.sdkInt;
          debugPrint('(SDK $sdkInt)');
          isLoading
              ? debugPrint("")
              : sdkInt >= 24
                  ? onPaint()
                  : toasts
                      .error("Crop is supported for Android 7.0 and above!");
        } else {
          toasts.error("Sorry crop is supported for Android 7.0 and above!");
        }
      },
      onTap: () {
        isLoading ? debugPrint("") : onTapPaint();
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
                    offset: const Offset(0, 4))
              ],
              borderRadius: BorderRadius.circular(500),
            ),
            padding: const EdgeInsets.all(17),
            child: Icon(
              JamIcons.picture,
              color: Theme.of(context).accentColor,
              size: 20,
            ),
          ),
          Positioned(
              top: 0,
              left: 0,
              height: 53,
              width: 53,
              child:
                  isLoading ? const CircularProgressIndicator() : Container())
        ],
      ),
    );
  }
}
