import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/widgets/animated/glint_toast.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/startup/services/notification_permission_prompt_service.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

class SetWallpaperButton extends StatefulWidget {
  final String? url;

  /// When true, may show the OS notification permission prompt once after a successful set (e.g. wallpaper detail).
  final bool promptNotificationPermissionOnSuccess;
  final VoidCallback? onSet;

  const SetWallpaperButton({
    super.key,
    required this.url,
    this.promptNotificationPermissionOnSuccess = false,
    this.onSet,
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
    try {
      await NotificationPermissionPromptService.instance.maybePromptAfterValueAction(
        context,
        sourceTag: 'notifications.permission_after_set_wallpaper',
      );
    } catch (e, st) {
      logger.w('_maybePromptNotificationPermission: maybePromptAfterValueAction failed', error: e, stackTrace: st);
    }
  }

  Future<void> _setWallpaper(WallpaperTarget target) async {
    try {
      final bool result = await WallpaperService.setWallpaperFromSource(widget.url!, target);
      if (result) {
        analytics.track(SetWallEvent(wallpaperTarget: target, result: BinaryResultValue.success));
        if (mounted) showGlintToast(context);
        toasts.success("Wallpaper set successfully!");
        widget.onSet?.call();
        await _maybePromptNotificationPermission();
      } else {
        toasts.error("Something went wrong!");
      }
    } catch (e) {
      analytics.track(SetWallEvent(wallpaperTarget: target, result: BinaryResultValue.failure));
      logger.e('Set wallpaper failed', error: e);
      toasts.error(_errorMessage(e));
    }
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _onTargetSelected(WallpaperTarget target) {
    PrismHaptics.tap();
    Navigator.of(context).pop();
    setState(() {
      isLoading = true;
    });
    _setWallpaper(target);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (isLoading) return;
        showPrismSheet<void>(
          isScrollControlled: true,
          context: context,
          builder: (context) => SetOptionsPanel(
            onTap1: () => _onTargetSelected(WallpaperTarget.home),
            onTap2: () => _onTargetSelected(WallpaperTarget.lock),
            onTap3: () => _onTargetSelected(WallpaperTarget.both),
          ),
        );
      },
      child: CircularMenuButton(
        label: 'Set as wallpaper',
        isLoading: isLoading,
        child: Icon(JamIcons.picture, color: Theme.of(context).colorScheme.secondary, size: 20),
      ),
    );
  }
}

class SetOptionsPanel extends StatefulWidget {
  final VoidCallback? onTap1;
  final VoidCallback? onTap2;
  final VoidCallback? onTap3;
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
                "Choose where to set this wallpaper. Both sets it on your home screen and lock screen.",
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
