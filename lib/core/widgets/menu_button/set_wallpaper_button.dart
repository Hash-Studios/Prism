import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/analytics_correlation.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/platform/wallpaper_set_feedback.dart';
import 'package:Prism/core/rating/rate_prompt_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/original_access_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/menu_button/original_access_prompt.dart';
import 'package:Prism/core/widgets/menu_button/pair_picker_sheet.dart';
import 'package:Prism/core/widgets/menu_button/prepare_source.dart';
import 'package:Prism/core/widgets/menu_button/primary_action_pill.dart';
import 'package:Prism/core/widgets/menu_button/set_options_panel.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_choice.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/startup/services/notification_permission_prompt_service.dart';
import 'package:Prism/l10n/l10n.dart';
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
    context,
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
    String? requestId,
    String? wallpaperId,
    WallpaperSource? wallpaperSource,
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
    String? requestId,
    String? wallpaperId,
    WallpaperSource? wallpaperSource,
  }) {
    return context.router.push<WallpaperSetResult>(
      WallpaperPositionRoute(
        imageUrl: url,
        thumbnailUrl: thumbnailUrl,
        entryPoint: entryPoint,
        requestId: requestId,
        wallpaperId: wallpaperId,
        wallpaperSource: wallpaperSource,
      ),
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
    String? wallpaperId,
    WallpaperSource? wallpaperSource,
    bool forceSheet = false,
    bool recordHistory = true,
    ValueChanged<bool>? onBusy,
    String? entryPoint,
    String? requestId,
    List<String> notes = const <String>[],
    VoidCallback? onMatchAccent,
    Future<String> Function(String source)? prepareAuthorized,
  }) async {
    final String owner = app_state.prismUser.id;
    final String? historyOriginalIdentity =
        prepareAuthorized == null &&
            wallpaperSource == WallpaperSource.prism &&
            (wallpaperId?.isNotEmpty ?? false) &&
            !url.startsWith('/') &&
            !url.startsWith('file:')
        ? 'prism:$wallpaperId'
        : null;
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    if (!context.mounted) return null;
    SetWallpaperChoice? choice;
    final WallpaperTarget? saved = forceSheet ? null : defaultTarget();
    bool usedDefault = false;
    if (saved != null && await _supportsTarget(saved)) {
      choice = SetWallpaperChoice(saved);
      usedDefault = true;
    }
    if (!context.mounted) return null;
    choice ??= await showSetWallpaperSheet(context, thumbnailUrl: thumbnailUrl, notes: notes, canAdjust: true);
    if (choice == null || !context.mounted || app_state.prismUser.id != owner) return null;
    if (choice.kind == SetChoiceKind.pair) {
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
        l10n: l10n,
        wallpaperId: wallpaperId,
        wallpaperSource: wallpaperSource,
        prepareAuthorized: prepareAuthorized,
      );
    }
    onBusy?.call(true);
    try {
      final authorized = await resolveOriginalWithConsent(
        context,
        url: url,
        wallpaperId: wallpaperId,
        wallpaperSource: wallpaperSource,
        action: OriginalAccessAction.set,
        requestId: requestId,
        label: l10n.coreSetWallpaper,
      );
      if (authorized == null) return null;
      url = authorized;
      if (prepareAuthorized != null) {
        final source = url;
        final prepared = await runPrepareSource(() => prepareAuthorized(source), l10n: l10n);
        if (prepared == null) return null;
        url = prepared;
      }
    } finally {
      onBusy?.call(false);
    }
    if (!context.mounted || app_state.prismUser.id != owner) return null;
    switch (choice.kind) {
      case SetChoiceKind.adjust:
        onBusy?.call(true);
        try {
          if (!context.mounted) return null;
          return await studioOpener(
            context,
            url: url,
            thumbnailUrl: thumbnailUrl,
            entryPoint: entryPoint,
            requestId: requestId,
            wallpaperId: wallpaperId,
            wallpaperSource: wallpaperSource,
          );
        } finally {
          onBusy?.call(false);
        }
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
          l10n: l10n,
          wallpaperId: wallpaperId,
          wallpaperSource: wallpaperSource,
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
          requestId: requestId,
          usedDefault: usedDefault,
          historyOriginalIdentity: historyOriginalIdentity,
          messenger: messenger,
          onMatchAccent: onMatchAccent,
          wallpaperId: wallpaperId,
          wallpaperSource: wallpaperSource,
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
    String? requestId,
    bool usedDefault = false,
    String? historyOriginalIdentity,
    ScaffoldMessengerState? messenger,
    AppLocalizations? localizations,
    VoidCallback? onMatchAccent,
    String? wallpaperId,
    WallpaperSource? wallpaperSource,
  }) async {
    final AppLocalizations l10n = localizations ?? context.l10n;
    final owner = app_state.prismUser.id;
    final ScaffoldMessengerState? host = messenger ?? (context.mounted ? ScaffoldMessenger.maybeOf(context) : null);
    final String operationId = AnalyticsCorrelation.newId();
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
        wallpaperId: wallpaperId,
        wallpaperSource: wallpaperSource,
        historyOriginalIdentity: historyOriginalIdentity,
      );
    } finally {
      onBusy?.call(false);
    }
    reportWallpaperSetResult(
      context.mounted ? context : null,
      result,
      l10n: l10n,
      target: choice.target,
      messenger: host,
      setContext: WallpaperSetContext(
        fit: choice.fit.name,
        entryPoint: entryPoint,
        usedDefault: usedDefault,
        operationId: operationId,
        itemId: wallpaperId,
        provider: wallpaperSource?.name,
        source: entryPoint,
        requestId: requestId,
      ),
      onMatchAccent: onMatchAccent,
      onRetry: (retryTarget) => unawaited(() async {
        if (owner != app_state.prismUser.id) return;
        final isLocal = url.startsWith('/') || url.startsWith('file:');
        if (!isLocal && !context.mounted) return;
        final retryUrl = isLocal
            ? url
            : await resolveOriginalWithConsent(
                context,
                url: url,
                wallpaperId: wallpaperId,
                wallpaperSource: wallpaperSource,
                action: OriginalAccessAction.set,
                label: l10n.coreSetWallpaper,
                requestId: requestId,
              );
        if (retryUrl == null || owner != app_state.prismUser.id) return;
        await apply(
          context,
          url: retryUrl,
          choice: SetWallpaperChoice(retryTarget, fit: choice.fit, useSystemCropper: choice.useSystemCropper),
          thumbnailUrl: thumbnailUrl,
          recordHistory: recordHistory,
          onBusy: onBusy,
          entryPoint: entryPoint,
          usedDefault: usedDefault,
          historyOriginalIdentity: historyOriginalIdentity,
          requestId: requestId,
          messenger: host,
          localizations: l10n,
          onMatchAccent: onMatchAccent,
          wallpaperId: wallpaperId,
          wallpaperSource: wallpaperSource,
        );
      }()),
    );
    if (result.isSuccess && wallpaperId != null && wallpaperSource == WallpaperSource.prism) {
      await OriginalAccessService.instance.complete(
        owner: owner,
        wallpaperId: wallpaperId,
        action: OriginalAccessAction.set,
      );
    }
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
    required AppLocalizations l10n,
    String? wallpaperId,
    WallpaperSource? wallpaperSource,
    Future<String> Function(String source)? prepareAuthorized,
  }) async {
    final owner = app_state.prismUser.id;
    final PairPick? pick = await pairPicker(context, excludeUrl: url);
    if (pick == null) return null;
    if (!context.mounted) return null;
    if (owner != app_state.prismUser.id) return null;
    final protectedAssets = <String>[];
    void addProtected(String sourceUrl, String? id, WallpaperSource? source) {
      if (!OriginalAccessService.requiresGrant(sourceUrl, id, source)) return;
      if (id == null || id.isEmpty) throw StateError('Original access identity unavailable');
      if (!protectedAssets.contains(id)) protectedAssets.add(id);
    }

    addProtected(url, wallpaperId, wallpaperSource);
    addProtected(pick.candidate.fullUrl, pick.candidate.wallpaperId, pick.candidate.wallpaperSource);
    int maxCoins = 0;
    if (protectedAssets.isNotEmpty) {
      final quote = await quoteOriginalWithConsent(
        context,
        url: '',
        wallpaperId: protectedAssets.first,
        wallpaperSource: WallpaperSource.prism,
        action: OriginalAccessAction.set,
        label: l10n.coreSetWallpaper,
        quoteProvider: () => OriginalAccessService.instance.quotePair(protectedAssets),
      );
      if (quote == null) return null;
      maxCoins = quote.requiredCoins;
    }
    if (!context.mounted || owner != app_state.prismUser.id) return null;
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
      l10n: l10n,
      wallpaperId: wallpaperId,
      wallpaperSource: wallpaperSource,
      protectedAssets: protectedAssets,
      maxCoins: maxCoins,
      prepareAuthorized: prepareAuthorized,
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
    required AppLocalizations l10n,
    String? wallpaperId,
    WallpaperSource? wallpaperSource,
    WallpaperSetResult? homeDone,
    List<String> protectedAssets = const [],
    int maxCoins = 0,
    Future<String> Function(String source)? prepareAuthorized,
  }) async {
    final owner = app_state.prismUser.id;
    onBusy?.call(true);
    final WallpaperSetResult home;
    WallpaperSetResult? lock;
    try {
      final grants = await OriginalAccessService.instance.resolvePair(protectedAssets, maxCoins: maxCoins);
      var homeUrl =
          grants[wallpaperId] ??
          await OriginalAccessService.instance.resolve(
            url: url,
            wallpaperId: wallpaperId,
            wallpaperSource: wallpaperSource,
            action: OriginalAccessAction.set,
          );
      final lockUrl =
          grants[pick.candidate.wallpaperId] ??
          await OriginalAccessService.instance.resolve(
            url: pick.candidate.fullUrl,
            wallpaperId: pick.candidate.wallpaperId,
            wallpaperSource: pick.candidate.wallpaperSource,
            action: OriginalAccessAction.set,
          );
      if (owner != app_state.prismUser.id) {
        return const WallpaperSetResult(WallpaperSetStatus.cancelled, '');
      }
      final originalHomeFile = prepareAuthorized != null && homeDone == null
          ? await WallpaperService.resolveToLocalFile(
              homeUrl,
              wallpaperId: wallpaperId,
              wallpaperSource: wallpaperSource,
            )
          : null;
      if (prepareAuthorized != null && homeDone == null) {
        final source = homeUrl;
        final prepared = await runPrepareSource(() => prepareAuthorized(source), l10n: l10n);
        if (prepared == null) return const WallpaperSetResult(WallpaperSetStatus.cancelled, '');
        homeUrl = prepared;
      }
      if (owner != app_state.prismUser.id) return const WallpaperSetResult(WallpaperSetStatus.cancelled, '');
      final homeFile = homeDone == null
          ? await WallpaperService.resolveToLocalFile(
              homeUrl,
              wallpaperId: wallpaperId,
              wallpaperSource: wallpaperSource,
            )
          : null;
      final lockFile = await WallpaperService.resolveToLocalFile(
        lockUrl,
        wallpaperId: pick.candidate.wallpaperId,
        wallpaperSource: pick.candidate.wallpaperSource,
      );
      if (owner != app_state.prismUser.id) {
        return const WallpaperSetResult(WallpaperSetStatus.cancelled, '');
      }
      home =
          homeDone ??
          await WallpaperService.setWallpaper(
            homeFile!.path,
            WallpaperTarget.home,
            fit: fit,
            thumbnailUrl: thumbnailUrl,
            recordHistory: recordHistory,
            wallpaperId: wallpaperId,
            wallpaperSource: wallpaperSource,
            historySource: originalHomeFile?.path ?? url,
            historyOriginalIdentity:
                originalHomeFile != null &&
                    wallpaperSource == WallpaperSource.prism &&
                    (wallpaperId?.isNotEmpty ?? false) &&
                    !url.startsWith('/') &&
                    !url.startsWith('file:')
                ? 'prism:$wallpaperId'
                : null,
          );
      if (home.isSuccess && owner == app_state.prismUser.id) {
        lock = await WallpaperService.setWallpaper(
          lockFile.path,
          WallpaperTarget.lock,
          fit: fit,
          thumbnailUrl: pick.candidate.thumbnailUrl,
          recordHistory: recordHistory,
          wallpaperId: pick.candidate.wallpaperId,
          wallpaperSource: pick.candidate.wallpaperSource,
          historySource: pick.candidate.fullUrl,
        );
      }
    } finally {
      onBusy?.call(false);
    }
    final WallpaperSetResult combined = _combinePair(home, lock, l10n: l10n);
    if (home.isSuccess && lock?.isSuccess == true && protectedAssets.isNotEmpty) {
      await OriginalAccessService.instance.completePair(protectedAssets, owner: owner);
    }
    _trackPair(entryPoint, pick, combined);
    reportWallpaperSetResult(
      context != null && context.mounted ? context : null,
      combined,
      l10n: l10n,
      target: lock == null ? WallpaperTarget.home : WallpaperTarget.both,
      messenger: messenger,
      track: false,
      onMatchAccent: onMatchAccent,
      onRetry: (retryTarget) {
        if (owner != app_state.prismUser.id) return;
        unawaited(
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
            l10n: l10n,
            wallpaperId: wallpaperId,
            wallpaperSource: wallpaperSource,
            homeDone: retryTarget == WallpaperTarget.lock ? home : null,
            protectedAssets: protectedAssets,
            maxCoins: maxCoins,
            prepareAuthorized: prepareAuthorized,
          ),
        );
      },
    );
    return combined;
  }

  static WallpaperSetResult _combinePair(
    WallpaperSetResult home,
    WallpaperSetResult? lock, {
    required AppLocalizations l10n,
  }) {
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
      l10n.coreWallpaperHomeSetLockFailed,
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
  final String? wallpaperId;
  final WallpaperSource? wallpaperSource;
  final String? thumbnailUrl;

  /// When true, may show the OS notification permission prompt once after a successful set (e.g. wallpaper detail).
  final bool promptNotificationPermissionOnSuccess;
  final VoidCallback? onSet;

  /// Text shown beside the circle. It sits inside the same tap target, so tapping it sets the wallpaper.
  final String? label;

  /// Names the screen in the `set_wall` event.
  final String? entryPoint;
  final String? requestId;

  /// Short warnings about this wall, shown as chips in the set sheet.
  final List<String> notes;

  /// Adds "Match accent" to the success snackbar when set.
  final VoidCallback? onMatchAccent;

  /// Makes the image to set, such as a colour variation, and returns its local path. It runs on tap, before the sheet
  /// opens, and the path replaces [url]. If it throws, the user is told and nothing is set.
  final Future<String> Function()? prepareSource;
  final Future<String> Function(String source)? prepareAuthorized;

  /// Draws a compact accent button with a label instead of a round icon button.
  final bool primary;

  /// Shows a caption under the round icon button.
  final bool labelled;

  const SetWallpaperButton({
    super.key,
    required this.url,
    this.wallpaperId,
    this.wallpaperSource,
    this.thumbnailUrl,
    this.promptNotificationPermissionOnSuccess = false,
    this.onSet,
    this.label,
    this.entryPoint,
    this.requestId,
    this.notes = const <String>[],
    this.onMatchAccent,
    this.prepareSource,
    this.prepareAuthorized,
    this.primary = false,
    this.labelled = false,
  });

  @override
  _SetWallpaperButtonState createState() => _SetWallpaperButtonState();
}

class _SetWallpaperButtonState extends State<SetWallpaperButton> {
  bool isLoading = false;
  bool _flowActive = false;

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

  Future<void> _start({bool forceSheet = false, bool playTapHaptic = true}) async {
    final String owner = app_state.prismUser.id;
    final String? url = widget.url;
    if (isLoading || _flowActive || url == null) return;
    final AppLocalizations l10n = context.l10n;
    if (playTapHaptic) PrismHaptics.tap();
    String source = url;
    final Future<String> Function()? prepare = widget.prepareAuthorized == null ? widget.prepareSource : null;
    if (prepare != null) {
      setState(() => isLoading = true);
      final String? prepared = await runPrepareSource(prepare, l10n: l10n);
      if (mounted) setState(() => isLoading = false);
      if (prepared == null || !mounted) return;
      source = prepared;
    }
    WallpaperSetResult? result;
    if (app_state.prismUser.id != owner) return;
    _flowActive = true;
    try {
      result = await SetWallpaperFlow.run(
        context,
        url: source,
        thumbnailUrl: widget.thumbnailUrl,
        wallpaperId: widget.wallpaperId,
        wallpaperSource: widget.wallpaperSource,
        prepareAuthorized: widget.prepareAuthorized,
        forceSheet: forceSheet,
        entryPoint: widget.entryPoint,
        requestId: widget.requestId,
        notes: widget.notes,
        onMatchAccent: widget.onMatchAccent,
        onBusy: (busy) {
          if (mounted) setState(() => isLoading = busy);
        },
      );
    } catch (e, st) {
      logger.e('Set wallpaper failed', error: e, stackTrace: st);
      toasts.error(l10n.coreWallpaperSaveFailed);
      unawaited(RatePromptService.instance.recordFailure());
    } finally {
      _flowActive = false;
      if (mounted) setState(() => isLoading = false);
    }
    if (result?.isFailure ?? false) {
      unawaited(RatePromptService.instance.recordFailure());
    }
    if (result?.isSuccess ?? false) {
      if (!mounted) return;
      widget.onSet?.call();
      await _maybePromptNotificationPermission();
      if (!mounted) return;
      unawaited(RatePromptService.instance.maybePrompt(RatePromptTrigger.wallpaperSet));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WallpaperTarget? saved = SetWallpaperFlow.defaultTarget();
    final String semanticLabel = saved == null
        ? context.l10n.coreSetWallpaper
        : context.l10n.coreSetWallpaperOn(_targetLabel(saved, context.l10n));
    final String? label = widget.label;
    final Widget button = widget.primary
        ? Semantics(
            button: true,
            label: semanticLabel,
            excludeSemantics: true,
            onTap: _start,
            child: PrismButton(
              label: label ?? context.l10n.coreSetWallpaper,
              size: PrismButtonSize.compact,
              loading: isLoading,
              onPressed: () => _start(playTapHaptic: false),
            ),
          )
        : label == null
        ? CircularMenuButton(
            label: semanticLabel,
            caption: widget.labelled ? context.l10n.coreSet : null,
            isLoading: isLoading,
            child: const Icon(JamIcons.picture),
          )
        : PrimaryActionPill(label: label, semanticLabel: semanticLabel, isLoading: isLoading);
    final Widget setTarget = GestureDetector(
      behavior: label == null && !widget.primary ? HitTestBehavior.deferToChild : HitTestBehavior.opaque,
      onTap: widget.primary ? null : _start,
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
          label: context.l10n.coreChangeWallpaperTarget,
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

String _targetLabel(WallpaperTarget target, AppLocalizations l10n) => switch (target) {
  WallpaperTarget.home => l10n.coreHomeScreen,
  WallpaperTarget.lock => l10n.coreLockScreen,
  WallpaperTarget.both => l10n.coreBothScreens,
};
