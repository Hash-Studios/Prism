import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/wallpaper/original_access_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/core/widgets/animated/glint_toast.dart';
import 'package:Prism/features/wallpaper_history/wallpaper_history.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

const Duration _successSnackBarDuration = Duration(seconds: 8);

/// Why the set happened and how, for the `set_wall` event.
class WallpaperSetContext {
  const WallpaperSetContext({
    this.fit,
    this.entryPoint,
    this.usedDefault = false,
    this.targetChanged,
    this.operationId,
    this.itemId,
    this.provider,
    this.source,
    this.requestId,
  });

  final String? operationId;
  final String? itemId;
  final String? provider;
  final String? source;
  final String? requestId;

  final String? fit;
  final String? entryPoint;
  final bool usedDefault;

  /// True when the user changed the target on the Set screen. Null when no screen was shown.
  final bool? targetChanged;
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
  required AppLocalizations l10n,
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
  final String message = result.localizedMessage(l10n);
  if (result.isSuccess) {
    if (live != null) showGlintToast(live);
    _showSuccess(snackHost, result, target, onMatchAccent, l10n);
    return;
  }
  if (result.isInfo) {
    if (snackHost == null) {
      toasts.success(message, haptic: false);
      return;
    }
    snackHost
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    return;
  }
  if (snackHost == null || !result.canRetry || onRetry == null) {
    toasts.error(message);
    return;
  }
  final WallpaperTarget retryTarget = result.failedTarget ?? target;
  snackHost
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: result.isPartial ? l10n.coreRetryOnScreen(_screenLabel(retryTarget, l10n)) : l10n.coreTryAgain,
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
        targetChanged: setContext.targetChanged,
        operationId: setContext.operationId,
        itemId: setContext.itemId,
        provider: setContext.provider,
        source: setContext.source,
        requestId: setContext.requestId,
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
  AppLocalizations l10n,
) {
  final bool canUndo = result.restore.isNotEmpty && !_autoRotateOn();
  if (messenger == null || (!canUndo && onMatchAccent == null)) {
    toasts.success(result.localizedMessage(l10n));
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: _successSnackBarDuration,
        content: _SuccessContent(
          l10n: l10n,
          onMatchAccent: onMatchAccent == null
              ? null
              : () {
                  messenger.hideCurrentSnackBar();
                  onMatchAccent();
                },
        ),
        action: canUndo
            ? SnackBarAction(
                label: l10n.coreUndo,
                onPressed: () => unawaited(undoWallpaperSet(result, target: target, l10n: l10n)),
              )
            : null,
      ),
    );
}

class _SuccessContent extends StatelessWidget {
  const _SuccessContent({required this.onMatchAccent, required this.l10n});

  final VoidCallback? onMatchAccent;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final Text message = Text(l10n.coreWallpaperSet, maxLines: 2, overflow: TextOverflow.ellipsis);
    final VoidCallback? match = onMatchAccent;
    if (match == null) return message;
    return OverflowBar(
      alignment: MainAxisAlignment.spaceBetween,
      spacing: PrismSpace.xs,
      children: <Widget>[
        message,
        TextButton(
          onPressed: match,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.inversePrimary,
            padding: EdgeInsets.zero,
          ),
          child: Text(l10n.coreMatchAccent, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// Sets the wall that was there before [result] and removes the history rows the set wrote.
/// Returns true when every screen was restored.
Future<bool> undoWallpaperSet(
  WallpaperSetResult result, {
  required WallpaperTarget target,
  required AppLocalizations l10n,
}) async {
  bool restored = result.restore.isNotEmpty;
  for (final WallpaperRestore entry in result.restore) {
    String source;
    try {
      final previous = entry.previous;
      final uri = Uri.tryParse(previous.fullUrl);
      final local = uri?.scheme == 'file' ? uri!.toFilePath() : previous.fullUrl;
      if ((uri?.scheme == 'file' || previous.fullUrl.startsWith('/')) && await File(local).exists()) {
        source = local;
      } else {
        if (uri?.scheme != 'https') throw StateError('Previous wallpaper file unavailable');
        source = await OriginalAccessService.instance.resolve(
          url: previous.fullUrl,
          wallpaperId: previous.wallpaperId,
          wallpaperSource: WallpaperSourceX.fromWire(previous.source),
          action: OriginalAccessAction.set,
          maxCoins: 0,
        );
      }
    } catch (error) {
      logger.w('Wallpaper undo: original access unavailable', error: error);
      restored = false;
      continue;
    }
    final WallpaperSetResult back = await WallpaperService.setWallpaper(
      source,
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
    toasts.info(l10n.corePreviousWallpaperRestored);
  } else {
    toasts.error(l10n.coreRestorePreviousWallpaperFailed);
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

String _screenLabel(WallpaperTarget target, AppLocalizations l10n) => switch (target) {
  WallpaperTarget.home => l10n.coreHomeScreen,
  WallpaperTarget.lock => l10n.coreLockScreen,
  WallpaperTarget.both => l10n.coreBothScreens,
};
