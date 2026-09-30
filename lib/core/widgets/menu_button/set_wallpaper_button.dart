import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/startup/services/notification_permission_prompt_service.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SetWallpaperButton extends StatefulWidget {
  final String? url;

  /// When true, may show the OS notification permission prompt once after a successful set (e.g. wallpaper detail).
  final bool promptNotificationPermissionOnSuccess;
  final VoidCallback? onSet;

  /// Draws a compact accent button with a label instead of a round icon button.
  final bool primary;

  /// Shows a caption under the round icon button.
  final bool labelled;

  const SetWallpaperButton({
    super.key,
    required this.url,
    this.promptNotificationPermissionOnSuccess = false,
    this.onSet,
    this.primary = false,
    this.labelled = false,
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
    HapticFeedback.vibrate();
    Navigator.of(context).pop();
    setState(() {
      isLoading = true;
    });
    _setWallpaper(target);
  }

  void _openOptions() {
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
  }

  @override
  Widget build(BuildContext context) {
    if (widget.primary) {
      return Semantics(
        button: true,
        label: 'Set as wallpaper',
        excludeSemantics: true,
        onTap: _openOptions,
        child: PrismButton(
          label: 'Set wallpaper',
          size: PrismButtonSize.compact,
          loading: isLoading,
          onPressed: _openOptions,
        ),
      );
    }
    return CircularMenuButton(
      label: 'Set as wallpaper',
      caption: widget.labelled ? 'Set' : null,
      isLoading: isLoading,
      onTap: _openOptions,
      child: const Icon(JamIcons.picture),
    );
  }
}

/// The "Set wallpaper" sheet: home screen, lock screen or both.
class SetOptionsPanel extends StatelessWidget {
  final VoidCallback? onTap1;
  final VoidCallback? onTap2;
  final VoidCallback? onTap3;
  const SetOptionsPanel({super.key, this.onTap1, this.onTap2, this.onTap3});

  @override
  Widget build(BuildContext context) {
    return PrismSheetBody(
      title: 'Set wallpaper',
      message: 'Choose where to set this wallpaper. Both sets it on your home screen and lock screen.',
      child: PrismGroup(
        children: <Widget>[
          PrismRow(icon: Icons.home_rounded, title: 'Home screen', onTap: () => onTap1?.call()),
          PrismRow(icon: Icons.lock_rounded, title: 'Lock screen', onTap: () => onTap2?.call()),
          PrismRow(icon: Icons.layers_rounded, title: 'Both', onTap: () => onTap3?.call()),
        ],
      ),
    );
  }
}
