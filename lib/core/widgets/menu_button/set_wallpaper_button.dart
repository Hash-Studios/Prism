import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/platform/wallpaper_set_feedback.dart';
import 'package:Prism/core/rating/rate_prompt_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/menu_button/pair_picker_sheet.dart';
import 'package:Prism/core/widgets/menu_button/primary_action_pill.dart';
import 'package:Prism/core/widgets/menu_button/set_options_panel.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_choice.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/startup/services/notification_permission_prompt_service.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

export 'package:Prism/core/widgets/menu_button/set_options_panel.dart';
export 'package:Prism/core/widgets/menu_button/set_wallpaper_choice.dart';

/// Opens the set sheet. [canAdjust] adds the position studio and the lock screen pair rows, which need a wall URL.
Future<SetWallpaperChoice?> showSetWallpaperSheet(
  BuildContext context, {
  String? thumbnailUrl,
  List<String> notes = const <String>[],
  bool canAdjust = false,
}) {
  return showPrismSheet<SetWallpaperChoice>(
    isScrollControlled: true,
    context: context,
    builder: (sheetContext) => SetOptionsPanel(
      thumbnailUrl: thumbnailUrl,
      notes: notes,
      canAdjust: canAdjust,
      onSelected: (choice) => Navigator.of(sheetContext).pop(choice),
    ),
  );
}

// ignore: avoid_classes_with_only_static_members
class SetWallpaperFlow {
  /// Opens the position studio and returns what it set. Tests replace it.
  @visibleForTesting
  static Future<WallpaperSetResult?> Function(
    BuildContext context, {
    required String url,
    String? thumbnailUrl,
    String? entryPoint,
  })
  studioOpener = _openStudio;

  /// Opens the lock screen picker. Tests replace it.
  @visibleForTesting
  static Future<PairPick?> Function(BuildContext context, {String? excludeUrl}) pairPicker = showPairPickerSheet;

  static Future<WallpaperSetResult?> _openStudio(
    BuildContext context, {
    required String url,
    String? thumbnailUrl,
    String? entryPoint,
  }) {
    return context.router.push<WallpaperSetResult>(
      WallpaperPositionRoute(imageUrl: url, thumbnailUrl: thumbnailUrl, entryPoint: entryPoint),
    );
  }

  /// The saved default target, or null when the user wants to be asked.
  static WallpaperTarget? defaultTarget() {
    try {
      if (!getIt.isRegistered<SettingsLocalDataSource>()) return null;
      final String saved = getIt<SettingsLocalDataSource>().get<String>(
        PersistenceKeys.defaultApplyTarget,
        defaultValue: 'ask',
      );
      for (final WallpaperTarget target in WallpaperTarget.values) {
        if (target.name == saved) return target;
      }
    } catch (error) {
      logger.w('SetWallpaperFlow: could not read default target', error: error);
    }
    return null;
  }

  /// Applies straight to the default target when one is saved, else opens the sheet.
  /// Returns null when the user closed the sheet.
  ///
  /// [notes] are short warnings for the sheet, [entryPoint] names the screen for analytics, and [onMatchAccent] adds
  /// "Match accent" to the success snackbar.
  static Future<WallpaperSetResult?> run(
    BuildContext context, {
    required String url,
    String? thumbnailUrl,
    bool forceSheet = false,
    bool recordHistory = true,
    ValueChanged<bool>? onBusy,
    String? entryPoint,
    List<String> notes = const <String>[],
    VoidCallback? onMatchAccent,
  }) async {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    SetWallpaperChoice? choice;
    final WallpaperTarget? saved = forceSheet ? null : defaultTarget();
    bool usedDefault = false;
    if (saved != null && await _supportsTarget(saved)) {
      choice = SetWallpaperChoice(saved);
      usedDefault = true;
    }
    if (!context.mounted) return null;
    choice ??= await showSetWallpaperSheet(context, thumbnailUrl: thumbnailUrl, notes: notes, canAdjust: true);
    if (choice == null || !context.mounted) return null;
    switch (choice.kind) {
      case SetChoiceKind.adjust:
        return studioOpener(context, url: url, thumbnailUrl: thumbnailUrl, entryPoint: entryPoint);
      case SetChoiceKind.pair:
        return _pair(
          context,
          url: url,
          thumbnailUrl: thumbnailUrl,
          fit: choice.fit,
          recordHistory: recordHistory,
          onBusy: onBusy,
          entryPoint: entryPoint,
          messenger: messenger,
          onMatchAccent: onMatchAccent,
        );
      case SetChoiceKind.apply:
        return apply(
          context,
          url: url,
          choice: choice,
          thumbnailUrl: thumbnailUrl,
          recordHistory: recordHistory,
          onBusy: onBusy,
          entryPoint: entryPoint,
          usedDefault: usedDefault,
          messenger: messenger,
          onMatchAccent: onMatchAccent,
        );
    }
  }

  /// True when the device can set [target]. If the plugin cannot answer, the answer is yes and the apply reports any error.
  static Future<bool> _supportsTarget(WallpaperTarget target) async {
    try {
      return isWallpaperTargetSupported(await aw.AsyncWallpaper.getCapabilities(), target);
    } catch (error, stackTrace) {
      logger.w('SetWallpaperFlow: could not read capabilities', error: error, stackTrace: stackTrace);
      return true;
    }
  }

  /// Sets [url] on the chosen target and shows the result.
  ///
  /// The root messenger is taken before the first await. Retry and Undo use it, so they keep working after the user
  /// leaves the screen.
  static Future<WallpaperSetResult?> apply(
    BuildContext context, {
    required String url,
    required SetWallpaperChoice choice,
    String? thumbnailUrl,
    bool recordHistory = true,
    ValueChanged<bool>? onBusy,
    String? entryPoint,
    bool usedDefault = false,
    ScaffoldMessengerState? messenger,
    VoidCallback? onMatchAccent,
  }) async {
    final ScaffoldMessengerState? host = messenger ?? (context.mounted ? ScaffoldMessenger.maybeOf(context) : null);
    onBusy?.call(true);
    final WallpaperSetResult result;
    try {
      result = await WallpaperService.setWallpaper(
        url,
        choice.target,
        fit: choice.fit,
        useSystemCropper: choice.useSystemCropper,
        thumbnailUrl: thumbnailUrl,
        recordHistory: recordHistory,
      );
    } finally {
      onBusy?.call(false);
    }
    reportWallpaperSetResult(
      context.mounted ? context : null,
      result,
      target: choice.target,
      messenger: host,
      setContext: WallpaperSetContext(fit: choice.fit.name, entryPoint: entryPoint, usedDefault: usedDefault),
      onMatchAccent: onMatchAccent,
      onRetry: (retryTarget) => unawaited(
        apply(
          context,
          url: url,
          choice: SetWallpaperChoice(retryTarget, fit: choice.fit, useSystemCropper: choice.useSystemCropper),
          thumbnailUrl: thumbnailUrl,
          recordHistory: recordHistory,
          onBusy: onBusy,
          entryPoint: entryPoint,
          usedDefault: usedDefault,
          messenger: host,
          onMatchAccent: onMatchAccent,
        ),
      ),
    );
    return result;
  }

  static Future<WallpaperSetResult?> _pair(
    BuildContext context, {
    required String url,
    required String? thumbnailUrl,
    required WallpaperFit fit,
    required bool recordHistory,
    required ValueChanged<bool>? onBusy,
    required String? entryPoint,
    required ScaffoldMessengerState? messenger,
    required VoidCallback? onMatchAccent,
  }) async {
    final PairPick? pick = await pairPicker(context, excludeUrl: url);
    if (pick == null) return null;
    return _applyPair(
      context.mounted ? context : null,
      url: url,
      thumbnailUrl: thumbnailUrl,
      pick: pick,
      fit: fit,
      recordHistory: recordHistory,
      onBusy: onBusy,
      entryPoint: entryPoint,
      messenger: messenger,
      onMatchAccent: onMatchAccent,
    );
  }

  /// Sets the wall on the home screen, then the pick on the lock screen, and shows one combined result.
  /// [homeDone] is the home result when only the lock screen is retried.
  static Future<WallpaperSetResult> _applyPair(
    BuildContext? context, {
    required String url,
    required String? thumbnailUrl,
    required PairPick pick,
    required WallpaperFit fit,
    required bool recordHistory,
    required ValueChanged<bool>? onBusy,
    required String? entryPoint,
    required ScaffoldMessengerState? messenger,
    required VoidCallback? onMatchAccent,
    WallpaperSetResult? homeDone,
  }) async {
    onBusy?.call(true);
    final WallpaperSetResult home;
    WallpaperSetResult? lock;
    try {
      home =
          homeDone ??
          await WallpaperService.setWallpaper(
            url,
            WallpaperTarget.home,
            fit: fit,
            thumbnailUrl: thumbnailUrl,
            recordHistory: recordHistory,
          );
      if (home.isSuccess) {
        lock = await WallpaperService.setWallpaper(
          pick.candidate.fullUrl,
          WallpaperTarget.lock,
          fit: fit,
          thumbnailUrl: pick.candidate.thumbnailUrl,
          recordHistory: recordHistory,
        );
      }
    } finally {
      onBusy?.call(false);
    }
    final WallpaperSetResult combined = _combinePair(home, lock);
    _trackPair(entryPoint, pick, combined);
    reportWallpaperSetResult(
      context != null && context.mounted ? context : null,
      combined,
      target: lock == null ? WallpaperTarget.home : WallpaperTarget.both,
      messenger: messenger,
      track: false,
      onMatchAccent: onMatchAccent,
      onRetry: (retryTarget) => unawaited(
        _applyPair(
          context,
          url: url,
          thumbnailUrl: thumbnailUrl,
          pick: pick,
          fit: fit,
          recordHistory: recordHistory,
          onBusy: onBusy,
          entryPoint: entryPoint,
          messenger: messenger,
          onMatchAccent: onMatchAccent,
          homeDone: retryTarget == WallpaperTarget.lock ? home : null,
        ),
      ),
    );
    return combined;
  }

  static WallpaperSetResult _combinePair(WallpaperSetResult home, WallpaperSetResult? lock) {
    if (lock == null) return home;
    if (lock.isSuccess) {
      return WallpaperSetResult(
        WallpaperSetStatus.applied,
        WallpaperService.appliedMessage,
        restore: <WallpaperRestore>[...home.restore, ...lock.restore],
        historyIds: <String>[...home.historyIds, ...lock.historyIds],
      );
    }
    if (lock.isInfo) return lock;
    return WallpaperSetResult(
      lock.status == WallpaperSetStatus.foregroundRequired ? lock.status : WallpaperSetStatus.failed,
      'Home screen set. Lock screen failed.',
      errorCode: lock.errorCode,
      appliedTarget: WallpaperTarget.home,
      failedTarget: WallpaperTarget.lock,
      restore: home.restore,
      historyIds: home.historyIds,
    );
  }

  static void _trackPair(String? entryPoint, PairPick pick, WallpaperSetResult combined) {
    try {
      unawaited(
        analytics.track(
          SetWallPairEvent(
            homeSource: entryPoint ?? 'unknown',
            lockSource: pick.source.name,
            result: combined.isSuccess
                ? 'success'
                : combined.isPartial
                ? 'partial'
                : 'failure',
          ),
        ),
      );
    } catch (error) {
      logger.w('Wallpaper pair analytics failed', error: error);
    }
  }
}

class SetWallpaperButton extends StatefulWidget {
  final String? url;
  final String? thumbnailUrl;

  /// When true, may show the OS notification permission prompt once after a successful set (e.g. wallpaper detail).
  final bool promptNotificationPermissionOnSuccess;
  final VoidCallback? onSet;

  /// Text shown beside the circle. It sits inside the same tap target, so tapping it sets the wallpaper.
  final String? label;

  /// Names the screen in the `set_wall` event.
  final String? entryPoint;

  /// Short warnings about this wall, shown as chips in the set sheet.
  final List<String> notes;

  /// Adds "Match accent" to the success snackbar when set.
  final VoidCallback? onMatchAccent;

  const SetWallpaperButton({
    super.key,
    required this.url,
    this.thumbnailUrl,
    this.promptNotificationPermissionOnSuccess = false,
    this.onSet,
    this.label,
    this.entryPoint,
    this.notes = const <String>[],
    this.onMatchAccent,
  });

  @override
  _SetWallpaperButtonState createState() => _SetWallpaperButtonState();
}

class _SetWallpaperButtonState extends State<SetWallpaperButton> {
  bool isLoading = false;

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

  Future<void> _start({bool forceSheet = false}) async {
    final String? url = widget.url;
    if (isLoading || url == null) return;
    PrismHaptics.tap();
    WallpaperSetResult? result;
    try {
      result = await SetWallpaperFlow.run(
        context,
        url: url,
        thumbnailUrl: widget.thumbnailUrl,
        forceSheet: forceSheet,
        entryPoint: widget.entryPoint,
        notes: widget.notes,
        onMatchAccent: widget.onMatchAccent,
        onBusy: (busy) {
          if (mounted) setState(() => isLoading = busy);
        },
      );
    } catch (e, st) {
      logger.e('Set wallpaper failed', error: e, stackTrace: st);
      toasts.error("Couldn't set the wallpaper. Try again.");
    }
    if (result?.isSuccess ?? false) {
      if (!mounted) return;
      widget.onSet?.call();
      await _maybePromptNotificationPermission();
      if (!mounted) return;
      unawaited(RatePromptService.instance.maybePrompt(context, RatePromptTrigger.wallpaperSet));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WallpaperTarget? saved = SetWallpaperFlow.defaultTarget();
    final String semanticLabel = saved == null ? 'Set as wallpaper' : 'Set as wallpaper on ${_targetLabel(saved)}';
    final String? label = widget.label;
    final Widget button = label == null
        ? CircularMenuButton(
            label: semanticLabel,
            isLoading: isLoading,
            child: Icon(JamIcons.picture, color: theme.colorScheme.secondary, size: 20),
          )
        : PrimaryActionPill(icon: JamIcons.picture, label: label, semanticLabel: semanticLabel, isLoading: isLoading);
    final Widget setTarget = GestureDetector(
      behavior: label == null ? HitTestBehavior.deferToChild : HitTestBehavior.opaque,
      onTap: _start,
      onLongPress: () => _start(forceSheet: true),
      child: button,
    );
    if (saved == null) return setTarget;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        setTarget,
        Semantics(
          button: true,
          label: 'Change where wallpaper is set',
          excludeSemantics: true,
          child: GestureDetector(
            key: const ValueKey<String>('set-tune-badge'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _start(forceSheet: true),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primary,
                  child: Icon(Icons.tune, size: 16, color: onColor(theme.colorScheme.primary)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _targetLabel(WallpaperTarget target) => switch (target) {
  WallpaperTarget.home => 'home screen',
  WallpaperTarget.lock => 'lock screen',
  WallpaperTarget.both => 'both screens',
};
