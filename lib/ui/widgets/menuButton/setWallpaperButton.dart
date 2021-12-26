import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SetWallpaperButton extends StatefulWidget {
  final String? url;
  final bool colorChanged;
  final Future<File> Function()? screenshotCallback;
  const SetWallpaperButton({
    Key? key,
    required this.url,
    required this.colorChanged,
    this.screenshotCallback,
  }) : super(key: key);

  @override
  _SetWallpaperButtonState createState() => _SetWallpaperButtonState();
}

class _SetWallpaperButtonState extends State<SetWallpaperButton> {
  bool isLoading = false;
  late String url;

  @override
  void initState() {
    super.initState();
    url = widget.url ?? "";
  }

  Future<void> _setWallPaper() async {
    String? result;
    try {
      if (widget.colorChanged) {
        result = await AsyncWallpaper.setWallpaperFromFileNative(
          url,
        );
      } else {
        result = await AsyncWallpaper.setWallpaperNative(
          url,
        );
      }
      if (result == 'Wallpaper set') {
        logger.d("Success");
        analytics.logEvent(
            name: 'set_wall',
            parameters: {'type': 'Both', 'result': 'Success'});
      } else {
        logger.d("Failed");
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
      logger.d(e.toString());
    }
  }

  Future<void> _setBothWallPaper() async {
    String? result;
    try {
      if (widget.colorChanged) {
        result = await AsyncWallpaper.setWallpaperFromFile(
          url,
          AsyncWallpaper.BOTH_SCREENS,
        );
      } else {
        result = await AsyncWallpaper.setWallpaper(
          url,
          AsyncWallpaper.BOTH_SCREENS,
        );
      }
      if (result == 'Wallpaper set') {
        logger.d("Success");
        analytics.logEvent(
            name: 'set_wall',
            parameters: {'type': 'Both', 'result': 'Success'});
        toasts.codeSend("Wallpaper set successfully!");
      } else {
        logger.d("Failed");
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
      logger.d(e.toString());
    }
  }

  Future<void> _setLockWallPaper() async {
    String? result;
    try {
      if (widget.colorChanged) {
        result = await AsyncWallpaper.setWallpaperFromFile(
          url,
          AsyncWallpaper.LOCK_SCREEN,
        );
      } else {
        result = await AsyncWallpaper.setWallpaper(
          url,
          AsyncWallpaper.LOCK_SCREEN,
        );
      }
      if (result == 'Wallpaper set') {
        logger.d("Success");
        analytics.logEvent(
            name: 'set_wall',
            parameters: {'type': 'Lock', 'result': 'Success'});
        toasts.codeSend("Wallpaper set successfully!");
      } else {
        logger.d("Failed");
        toasts.error("Something went wrong!");
      }
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      logger.d(e.toString());
      analytics.logEvent(
          name: 'set_wall', parameters: {'type': 'Lock', 'result': 'Failure'});
    }
  }

  Future<void> _setHomeWallPaper() async {
    String? result;
    try {
      if (widget.colorChanged) {
        result = await AsyncWallpaper.setWallpaperFromFile(
          url,
          AsyncWallpaper.HOME_SCREEN,
        );
      } else {
        result = await AsyncWallpaper.setWallpaper(
          url,
          AsyncWallpaper.HOME_SCREEN,
        );
      }
      if (result == 'Wallpaper set') {
        logger.d("Success");
        analytics.logEvent(
            name: 'set_wall',
            parameters: {'type': 'Home', 'result': 'Success'});
        toasts.codeSend("Wallpaper set successfully!");
      } else {
        logger.d("Failed");
        toasts.error("Something went wrong!");
      }
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      logger.d(e.toString());
      analytics.logEvent(
          name: 'set_wall', parameters: {'type': 'Home', 'result': 'Failure'});
    }
  }

  Future<void> onPaint() async {
    HapticFeedback.vibrate();
    if (widget.colorChanged) {
      final File file = await widget.screenshotCallback?.call() as File;
      setState(() {
        isLoading = true;
        url = file.path;
      });
      Future.delayed(const Duration(seconds: 1))
          .then((value) => _setWallPaper());
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
      onTap: () {
        isLoading
            ? logger.d("")
            : showModalBottomSheet(
                isScrollControlled: true,
                context: context,
                builder: (context) => SetOptionsPanel(
                  onTap1: () async {
                    logger.d(widget.colorChanged);
                    HapticFeedback.vibrate();
                    Navigator.of(context).pop();
                    File? file;
                    if (widget.colorChanged) {
                      file = await widget.screenshotCallback?.call() as File;
                    }
                    setState(() {
                      isLoading = true;
                      if (widget.colorChanged && file != null) {
                        url = file.path;
                      }
                    });
                    Future.delayed(const Duration(seconds: 1))
                        .then((value) => _setHomeWallPaper());
                  },
                  onTap2: () async {
                    logger.d(widget.colorChanged);
                    HapticFeedback.vibrate();
                    Navigator.of(context).pop();
                    File? file;
                    if (widget.colorChanged) {
                      file = await widget.screenshotCallback?.call() as File;
                    }
                    setState(() {
                      isLoading = true;
                      if (widget.colorChanged && file != null) {
                        url = file.path;
                      }
                    });
                    Future.delayed(const Duration(seconds: 1))
                        .then((value) => _setLockWallPaper());
                  },
                  onTap3: () async {
                    logger.d(widget.colorChanged);
                    HapticFeedback.vibrate();
                    Navigator.of(context).pop();
                    File? file;
                    if (widget.colorChanged) {
                      file = await widget.screenshotCallback?.call() as File;
                    }
                    setState(() {
                      isLoading = true;
                      if (widget.colorChanged && file != null) {
                        url = file.path;
                      }
                    });
                    Future.delayed(const Duration(seconds: 1))
                        .then((value) => _setBothWallPaper());
                  },
                  onTap4: () async {
                    logger.d(widget.colorChanged);
                    HapticFeedback.vibrate();
                    Navigator.of(context).pop();
                    if (Platform.isAndroid) {
                      final androidInfo = await DeviceInfoPlugin().androidInfo;
                      final sdkInt = androidInfo.version.sdkInt;
                      logger.d('(SDK $sdkInt)');
                      isLoading
                          ? logger.d("")
                          : sdkInt >= 24
                              ? onPaint()
                              : toasts.error(
                                  "Crop is supported for Android 7.0 and above!");
                    } else {
                      toasts.error(
                          "Sorry crop is supported for Android 7.0 and above!");
                    }
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
  final Function? onTap4;
  const SetOptionsPanel({
    Key? key,
    this.onTap1,
    this.onTap2,
    this.onTap3,
    this.onTap4,
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
      height: MediaQuery.of(context).size.height / 1.7 > 400
          ? MediaQuery.of(context).size.height / 1.7
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
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  onTap: () {
                    widget.onTap4!();
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
                          "External...",
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).accentColor,
                            fontWeight: FontWeight.bold,
                          ),
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
