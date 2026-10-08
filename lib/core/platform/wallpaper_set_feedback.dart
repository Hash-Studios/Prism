import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/widgets/animated/glint_toast.dart';
import 'package:Prism/features/wallpaper_history/wallpaper_history.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

const Duration _successSnackBarDuration = Duration(seconds: 8);

/// Why the set happened and how, for the `set_wall` event.
class WallpaperSetContext {
  const WallpaperSetContext({this.fit, this.entryPoint, this.usedDefault = false});

  final String? fit;
  final String? entryPoint;
  final bool usedDefault;
}

/// Tracks the outcome and shows one piece of feedback for it. Cancelled sets stay silent.
///
/// [context] is null when the screen is gone. Pass the [messenger] taken before the set started. The snackbar then
/// outlives the screen, and its actions need no live [BuildContext]. [onRetry] gets the screen to try again: only the
/// failed one after a partial set.
/// [onMatchAccent] adds a "Match accent" button to the success snackbar.
void reportWallpaperSetResult(
  BuildContext? context,
  WallpaperSetResult result, {
  required WallpaperTarget target,
  ScaffoldMessengerState? messenger,
  WallpaperSetContext setContext = const WallpaperSetContext(),
  ValueChanged<WallpaperTarget>? onRetry,
  VoidCallback? onMatchAccent,
  bool track = true,
}) {
  if (track) _trackSetResult(result, target, setContext);
  if (result.isSilent) return;
  final BuildContext? live = context != null && context.mounted ? context : null;
  final ScaffoldMessengerState? host = messenger ?? (live == null ? null : ScaffoldMessenger.maybeOf(live));
  final ScaffoldMessengerState? snackHost = host != null && host.mounted ? host : null;
  if (result.isSuccess) {
    if (live != null) showGlintToast(live);
    _showSuccess(snackHost, result, target, onMatchAccent);
    return;
  }
  if (result.isInfo) {
    if (snackHost == null) {
      toasts.success(result.message, haptic: false);
      return;
    }
    snackHost
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(result.message)));
    return;
  }
  if (snackHost == null || !result.canRetry || onRetry == null) {
    toasts.error(result.message);
    return;
  }
  final WallpaperTarget retryTarget = result.failedTarget ?? target;
  snackHost
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(result.message),
        action: SnackBarAction(
          label: result.isPartial ? 'Retry ${_screenLabel(retryTarget)}' : 'Try again',
          onPressed: () => onRetry(retryTarget),
        ),
      ),
    );
}

void _trackSetResult(WallpaperSetResult result, WallpaperTarget target, WallpaperSetContext setContext) {
  try {
    if (!result.isSuccess && !result.isFailure) return;
    analytics.track(
      SetWallEvent(
        wallpaperTarget: target,
        result: result.isSuccess ? BinaryResultValue.success : BinaryResultValue.failure,
        errorCode: result.isSuccess ? null : result.errorCode,
        fit: setContext.fit,
        entryPoint: setContext.entryPoint,
        usedDefault: setContext.usedDefault,
      ),
    );
  } catch (error) {
    logger.w('Wallpaper set analytics failed', error: error);
  }
}

void _showSuccess(
  ScaffoldMessengerState? messenger,
  WallpaperSetResult result,
  WallpaperTarget target,
  VoidCallback? onMatchAccent,
) {
  final bool canUndo = result.restore.isNotEmpty && !_autoRotateOn();
  if (messenger == null || (!canUndo && onMatchAccent == null)) {
    toasts.success(result.message);
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: _successSnackBarDuration,
        content: _SuccessContent(
          onMatchAccent: onMatchAccent == null
              ? null
              : () {
                  messenger.hideCurrentSnackBar();
                  onMatchAccent();
                },
        ),
        action: canUndo
            ? SnackBarAction(
                label: 'Undo',
                onPressed: () => unawaited(undoWallpaperSet(result, target: target)),
              )
            : null,
      ),
    );
}

class _SuccessContent extends StatelessWidget {
  const _SuccessContent({required this.onMatchAccent});

  final VoidCallback? onMatchAccent;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? match = onMatchAccent;
    if (match == null) return const Text('Wallpaper set');
    return Row(
      children: <Widget>[
        const Expanded(child: Text('Wallpaper set')),
        TextButton(
          onPressed: match,
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.inversePrimary),
          child: const Text('Match accent'),
        ),
      ],
    );
  }
}

/// Sets the wall that was there before [result] and removes the history rows the set wrote.
/// Returns true when every screen was restored.
Future<bool> undoWallpaperSet(WallpaperSetResult result, {required WallpaperTarget target}) async {
  bool restored = result.restore.isNotEmpty;
  for (final WallpaperRestore entry in result.restore) {
    final WallpaperSetResult back = await WallpaperService.setWallpaper(
      entry.previous.fullUrl,
      entry.target,
      thumbnailUrl: entry.previous.thumbnailUrl,
      recordHistory: false,
    );
    if (!back.isSuccess && !back.isInfo) restored = false;
  }
  if (restored) {
    try {
      for (final String id in result.historyIds) {
        await WallpaperHistoryStore.instance.remove(id);
      }
    } catch (error, stackTrace) {
      logger.w('Wallpaper undo: could not update history', error: error, stackTrace: stackTrace);
    }
  }
  try {
    unawaited(
      analytics.track(
        SetWallUndoneEvent(
          wallpaperTarget: target,
          result: restored ? BinaryResultValue.success : BinaryResultValue.failure,
        ),
      ),
    );
  } catch (error) {
    logger.w('Wallpaper undo analytics failed', error: error);
  }
  if (restored) {
    toasts.info('Previous wallpaper restored');
  } else {
    toasts.error("Couldn't restore the previous wallpaper. Set it again from Wallpaper history.");
  }
  return restored;
}

bool _autoRotateOn() {
  try {
    if (!getIt.isRegistered<SettingsLocalDataSource>()) return false;
    return getIt<SettingsLocalDataSource>().get<bool>(PersistenceKeys.autoRotateEnabled, defaultValue: false);
  } catch (error) {
    logger.w('Wallpaper set: could not read auto-rotate', error: error);
    return false;
  }
}

String _screenLabel(WallpaperTarget target) => switch (target) {
  WallpaperTarget.home => 'home screen',
  WallpaperTarget.lock => 'lock screen',
  WallpaperTarget.both => 'both screens',
};
