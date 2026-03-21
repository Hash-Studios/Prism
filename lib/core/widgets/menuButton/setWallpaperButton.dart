import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/startup/services/notification_permission_prompt_service.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SetWallpaperButton extends StatefulWidget {
  final String? url;
  final bool colorChanged;

  /// When true, may show the OS notification permission prompt once after a successful set (e.g. wallpaper detail).
  final bool promptNotificationPermissionOnSuccess;

  const SetWallpaperButton({
    super.key,
    required this.url,
    required this.colorChanged,
    this.promptNotificationPermissionOnSuccess = false,
  });

  @override
  _SetWallpaperButtonState createState() => _SetWallpaperButtonState();
}

class _SetWallpaperButtonState extends State<SetWallpaperButton> {
  bool isLoading = false;

  String _errorMessage(Object e) {
    if (e is TimeoutException) return "Timed out - check your connection and try again.";
    return "Something went wrong!";
  }

  Future<void> _maybePromptNotificationPermission() async {
    if (!widget.promptNotificationPermissionOnSuccess || !mounted) return;
    await NotificationPermissionPromptService.instance.maybePromptAfterValueAction(
      context,
      sourceTag: 'notifications.permission_after_set_wallpaper',
    );
  }

  Future<void> _setBothWallPaper() async {
    bool? result;
    try {
      result = await WallpaperService.setWallpaperFromSource(widget.url!, WallpaperTarget.both);
      if (result) {
        logger.d("Success");
        analytics.track(
          const SetWallEvent(wallpaperTarget: WallpaperTargetValue.both, result: BinaryResultValue.success),
        );
        toasts.codeSend("Wallpaper set successfully!");
        await _maybePromptNotificationPermission();
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
      analytics.track(
        const SetWallEvent(wallpaperTarget: WallpaperTargetValue.both, result: BinaryResultValue.failure),
      );
      logger.d(e.toString());
      toasts.error(_errorMessage(e));
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _setLockWallPaper() async {
    bool? result;
    try {
      result = await WallpaperService.setWallpaperFromSource(widget.url!, WallpaperTarget.lock);
      if (result) {
        logger.d("Success");
        analytics.track(
          const SetWallEvent(wallpaperTarget: WallpaperTargetValue.lock, result: BinaryResultValue.success),
        );
        toasts.codeSend("Wallpaper set successfully!");
        await _maybePromptNotificationPermission();
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
      analytics.track(
        const SetWallEvent(wallpaperTarget: WallpaperTargetValue.lock, result: BinaryResultValue.failure),
      );
      toasts.error(_errorMessage(e));
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _setHomeWallPaper() async {
    bool? result;
    try {
      result = await WallpaperService.setWallpaperFromSource(widget.url!, WallpaperTarget.home);
      if (result) {
        logger.d("Success");
        analytics.track(
          const SetWallEvent(wallpaperTarget: WallpaperTargetValue.home, result: BinaryResultValue.success),
        );
        toasts.codeSend("Wallpaper set successfully!");
        await _maybePromptNotificationPermission();
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
      analytics.track(
        const SetWallEvent(wallpaperTarget: WallpaperTargetValue.home, result: BinaryResultValue.failure),
      );
      toasts.error(_errorMessage(e));
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
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
                  onTap1: () {
                    HapticFeedback.vibrate();
                    Navigator.of(context).pop();
                    setState(() {
                      isLoading = true;
                    });
                    _setHomeWallPaper();
                  },
                  onTap2: () {
                    HapticFeedback.vibrate();
                    Navigator.of(context).pop();
                    setState(() {
                      isLoading = true;
                    });
                    _setLockWallPaper();
                  },
                  onTap3: () {
                    HapticFeedback.vibrate();
                    Navigator.of(context).pop();
                    setState(() {
                      isLoading = true;
                    });
                    _setBothWallPaper();
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
                BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 4, offset: const Offset(0, 4)),
              ],
              borderRadius: BorderRadius.circular(500),
            ),
            padding: const EdgeInsets.all(17),
            child: Icon(JamIcons.picture, color: Theme.of(context).colorScheme.secondary, size: 20),
          ),
          Positioned(
            top: 0,
            left: 0,
            height: 53,
            width: 53,
            child: isLoading ? const CircularProgressIndicator() : Container(),
          ),
        ],
      ),
    );
  }
}

class SetOptionsPanel extends StatefulWidget {
  final Function? onTap1;
  final Function? onTap2;
  final Function? onTap3;
  const SetOptionsPanel({super.key, this.onTap1, this.onTap2, this.onTap3});

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
      height: MediaQuery.of(context).size.height / 2 > 400 ? MediaQuery.of(context).size.height / 2 : 400,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
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
                    borderRadius: BorderRadius.circular(500),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text("Set Wallpaper as", style: Theme.of(context).textTheme.displayMedium),
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
                        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                        border: Border.all(color: Theme.of(context).colorScheme.error, width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          "Home Screen",
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
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
                        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                        border: Border.all(color: Theme.of(context).colorScheme.error, width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          "Lock Screen",
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
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
                        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                        border: Border.all(color: Theme.of(context).colorScheme.error, width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          "Both",
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.secondary,
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
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.secondary),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
