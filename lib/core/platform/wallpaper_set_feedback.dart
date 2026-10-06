import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/widgets/animated/glint_toast.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

/// Tracks the outcome and shows one piece of feedback for it. Cancelled sets stay silent.
void reportWallpaperSetResult(
  BuildContext context,
  WallpaperSetResult result, {
  required WallpaperTarget target,
  VoidCallback? onRetry,
}) {
  try {
    if (result.isSuccess) {
      analytics.track(SetWallEvent(wallpaperTarget: target, result: BinaryResultValue.success));
    } else if (result.isFailure) {
      analytics.track(SetWallEvent(wallpaperTarget: target, result: BinaryResultValue.failure));
    }
  } catch (error) {
    logger.w('Wallpaper set analytics failed', error: error);
  }
  if (!context.mounted || result.isSilent) return;
  if (result.isSuccess) {
    showGlintToast(context);
    toasts.success(result.message);
    return;
  }
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (result.isInfo) {
    if (messenger == null) {
      toasts.success(result.message, haptic: false);
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(result.message)));
    return;
  }
  if (messenger == null || !result.canRetry || onRetry == null) {
    toasts.error(result.message);
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(result.message),
        action: SnackBarAction(label: 'Retry', onPressed: onRetry),
      ),
    );
}
