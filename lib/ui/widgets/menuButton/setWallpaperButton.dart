import 'dart:io' show Platform;
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

class SetWallpaperButton extends StatefulWidget {
  final String? url;
  final bool colorChanged;
  const SetWallpaperButton({
    Key? key,
    required this.url,
    required this.colorChanged,
  }) : super(key: key);

  @override
  _SetWallpaperButtonState createState() => _SetWallpaperButtonState();
}

class _SetWallpaperButtonState extends State<SetWallpaperButton> {
  static const platform = MethodChannel("flutter.prism.set_wallpaper");
  bool isLoading = false;

  Future<void> _setWallPaper() async {
    bool? result;
    try {
      if (widget.url!.contains("com.hash.prism")) {
        result =
            await platform.invokeMethod("set_wallpaper_file", <String, dynamic>{
          'url': widget.url,
        });
      } else if (widget.url!.contains("/0/")) {
        result =
            await platform.invokeMethod("set_wallpaper_file", <String, dynamic>{
          'url': "/${widget.url!.replaceAll("/0//", "/0/")}",
        });
      } else {
        result = await platform.invokeMethod("set_wallpaper", <String, dynamic>{
          'url': widget.url,
        });
      }
      if (result!) {
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
    bool? result;
    try {
      if (widget.url!.contains("com.hash.prism")) {
        result = await platform
            .invokeMethod("set_both_wallpaper_file", <String, dynamic>{
          'url': widget.url,
        });
      } else if (widget.url!.contains("/0/")) {
        result = await platform
            .invokeMethod("set_both_wallpaper_file", <String, dynamic>{
          'url': "/${widget.url!.replaceAll("/0//", "/0/")}",
        });
      } else {
        result =
            await platform.invokeMethod("set_both_wallpaper", <String, dynamic>{
          'url': widget.url,
        });
      }
      if (result!) {
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
    bool? result;
    try {
      if (widget.url!.contains("com.hash.prism")) {
        result = await platform
            .invokeMethod("set_lock_wallpaper_file", <String, dynamic>{
          'url': widget.url,
        });
      } else if (widget.url!.contains("/0/")) {
        result = await platform
            .invokeMethod("set_lock_wallpaper_file", <String, dynamic>{
          'url': "/${widget.url!.replaceAll("/0//", "/0/")}",
        });
      } else {
        result =
            await platform.invokeMethod("set_lock_wallpaper", <String, dynamic>{
          'url': widget.url,
        });
      }
      if (result!) {
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
    bool? result;
    try {
      if (widget.url!.contains("com.hash.prism")) {
        result = await platform
            .invokeMethod("set_home_wallpaper_file", <String, dynamic>{
          'url': widget.url,
        });
      } else if (widget.url!.contains("/0/")) {
        result = await platform
            .invokeMethod("set_home_wallpaper_file", <String, dynamic>{
          'url': "/${widget.url!.replaceAll("/0//", "/0/")}",
        });
      } else {
        result =
            await platform.invokeMethod("set_home_wallpaper", <String, dynamic>{
          'url': widget.url,
        });
      }
      if (result!) {
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
        isLoading
            ? debugPrint("")
            : showModalBottomSheet(
                isScrollControlled: true,
                context: context,
                builder: (context) => SetOptionsPanel(
                  onTap1: () {
                    HapticFeedback.vibrate();
                    Navigator.of(context).pop();
                    setState(() {
                      isLoading = true;
                    });
                    Future.delayed(const Duration(seconds: 1))
                        .then((value) => _setHomeWallPaper());
                  },
                  onTap2: () {
                    HapticFeedback.vibrate();
                    Navigator.of(context).pop();
                    setState(() {
                      isLoading = true;
                    });
                    Future.delayed(const Duration(seconds: 1))
                        .then((value) => _setLockWallPaper());
                  },
                  onTap3: () {
                    HapticFeedback.vibrate();
                    Navigator.of(context).pop();
                    setState(() {
                      isLoading = true;
                    });
                    Future.delayed(const Duration(seconds: 1))
                        .then((value) => _setBothWallPaper());
                  },
                ),
              );
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

class SetOptionsPanel extends StatefulWidget {
  final Function? onTap1;
  final Function? onTap2;
  final Function? onTap3;
  const SetOptionsPanel({
    Key? key,
    this.onTap1,
    this.onTap2,
    this.onTap3,
  }) : super(key: key);

  @override
  _SetOptionsPanelState createState() => _SetOptionsPanelState();
}

class _SetOptionsPanelState extends State<SetOptionsPanel> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.85;
    return Container(
      height: MediaQuery.of(context).size.height / 2 > 400
          ? MediaQuery.of(context).size.height / 2
          : 400,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  height: 5,
                  width: 30,
                  decoration: BoxDecoration(
                      color: Theme.of(context).hintColor,
                      borderRadius: BorderRadius.circular(500)),
                ),
              )
            ],
          ),
          const Spacer(),
          Text(
            "Set Wallpaper as",
            style: Theme.of(context).textTheme.headline2,
          ),
          const Spacer(flex: 2),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  onTap: () {
                    widget.onTap1!();
                  },
                  child: SizedBox(
                    width: width - 20,
                    height: 60,
                    child: Container(
                      width: width - 14,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Theme.of(context).errorColor.withOpacity(0.2),
                        border: Border.all(
                            color: Theme.of(context).errorColor, width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          "Home Screen",
                          style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).accentColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  onTap: () {
                    widget.onTap2!();
                  },
                  child: SizedBox(
                    width: width - 20,
                    height: 60,
                    child: Container(
                      width: width - 14,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Theme.of(context).errorColor.withOpacity(0.2),
                        border: Border.all(
                            color: Theme.of(context).errorColor, width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          "Lock Screen",
                          style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).accentColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  onTap: () {
                    widget.onTap3!();
                  },
                  child: SizedBox(
                    width: width - 20,
                    height: 60,
                    child: Container(
                      width: width - 14,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Theme.of(context).errorColor.withOpacity(0.2),
                        border: Border.all(
                            color: Theme.of(context).errorColor, width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          "Both",
                          style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).accentColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(flex: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Text(
                "Select where wallpaper you want to change with this wallpaper. Selecting both, will change the wallpaper on home screen as well as lock screen.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).accentColor,
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
