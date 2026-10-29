import 'dart:async';
import 'dart:io';

import 'package:Prism/core/debug/performance_probe.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/platform/system_color_schemes.dart';
import 'package:Prism/core/platform/wallpaper_error_messages.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_history/wallpaper_history.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

enum WallpaperTarget { home, lock, both }

/// How the image fills the screen. [fill] crops to cover the screen. [whole] shows the full image.
enum WallpaperFit { fill, whole }

enum WallpaperSetStatus { applied, cancelled, pending, unsupported, foregroundRequired, failed }

/// The wall that was on [target] before a set. Undo sets it again.
class WallpaperRestore {
  const WallpaperRestore(this.target, this.previous);

  final WallpaperTarget target;
  final AppliedWallpaper previous;
}

class WallpaperSetResult {
  const WallpaperSetResult(
    this.status,
    this.message, {
    this.errorCode,
    this.appliedTarget,
    this.failedTarget,
    this.restore = const <WallpaperRestore>[],
    this.historyIds = const <String>[],
  });

  final WallpaperSetStatus status;
  final String message;
  final String? errorCode;

  /// With `partial-apply`: the screen that changed, and the screen that did not.
  final WallpaperTarget? appliedTarget;
  final WallpaperTarget? failedTarget;

  /// What was on the screens before this set, as far as history knows. Empty when Undo is not possible.
  final List<WallpaperRestore> restore;

  /// The history rows this set wrote, so Undo can remove them.
  final List<String> historyIds;

  bool get isSuccess => status == WallpaperSetStatus.applied;
  bool get isSilent => status == WallpaperSetStatus.cancelled;
  bool get isInfo => status == WallpaperSetStatus.pending;
  bool get isPartial => appliedTarget != null && failedTarget != null;
  bool get canRetry =>
      (status == WallpaperSetStatus.failed || status == WallpaperSetStatus.foregroundRequired) &&
      canRetryWallpaperError(errorCode);
  bool get isFailure =>
      status == WallpaperSetStatus.failed ||
      status == WallpaperSetStatus.foregroundRequired ||
      status == WallpaperSetStatus.unsupported;

  /// Resolves the typed result to user-facing copy at the presentation boundary.
  String localizedMessage(AppLocalizations l10n, {bool live = false}) {
    if (isPartial) {
      return l10n.coreWallpaperPartialSet(
        _localizedScreenName(appliedTarget!, l10n),
        _localizedScreenName(failedTarget!, l10n),
      );
    }
    return switch (status) {
      WallpaperSetStatus.applied => l10n.coreWallpaperApplied,
      WallpaperSetStatus.cancelled => '',
      WallpaperSetStatus.pending => l10n.coreConfirmWallpaperPreview,
      WallpaperSetStatus.unsupported =>
        errorCode == 'wallpaper-not-allowed'
            ? wallpaperErrorMessage(errorCode, l10n, live: live)
            : l10n.coreDeviceCannotSetScreen,
      WallpaperSetStatus.foregroundRequired => l10n.coreKeepPrismOpen,
      WallpaperSetStatus.failed => switch (errorCode) {
        'offline_unavailable' => l10n.coreWallpaperOfflineUnavailable,
        'load_failed' || 'exception' => l10n.coreWallpaperErrorGeneric,
        _ => wallpaperErrorMessage(errorCode, l10n, live: live),
      },
    };
  }

  WallpaperSetResult withHistory({required List<WallpaperRestore> restore, required List<String> historyIds}) =>
      WallpaperSetResult(
        status,
        message,
        errorCode: errorCode,
        appliedTarget: appliedTarget,
        failedTarget: failedTarget,
        restore: restore,
        historyIds: historyIds,
      );

  static String _localizedScreenName(WallpaperTarget target, AppLocalizations l10n) => switch (target) {
    WallpaperTarget.home => l10n.coreWallpaperHomeScreen,
    WallpaperTarget.lock => l10n.coreWallpaperLockScreen,
    WallpaperTarget.both => l10n.coreWallpaperBothScreens,
  };
}

// ignore: avoid_classes_with_only_static_members
class WallpaperService {
  static int _historyWriteGeneration = 0;

  /// Invalidates history writes still waiting on a native set when auth changes.
  static void invalidatePendingHistoryWrites() => _historyWriteGeneration++;

  static const String appliedMessage = 'applied';
  static const String pendingMessage = 'pending';
  static const String unsupportedMessage = 'unsupported';
  static const String foregroundMessage = 'foreground_required';
  static const String failedMessage = 'failed';
  static const String timeoutMessage = 'timeout';
  static const String offlineUnavailableMessage = 'offline_unavailable';

  /// Turns a local file into a content URI. The Android system cropper cannot read a file path.
  static const MethodChannel _cropChannel = MethodChannel('prism/wallpaper_crop');

  /// Sets [source] on [target].
  ///
  /// With [useSystemCropper] the Android system cropper opens first and the user picks the crop.
  /// History keeps [historySource] and [historyThumbnail] when given. Callers that set a rendered copy of a wall pass
  /// the original here, so history can set the wall again.
  /// [historyOriginalIdentity] keeps an acquired original's catalogue identity when applying a rendered copy.
  static Future<WallpaperSetResult> setWallpaper(
    String source,
    WallpaperTarget target, {
    WallpaperFit fit = WallpaperFit.fill,
    bool useSystemCropper = false,
    String? thumbnailUrl,
    bool recordHistory = true,
    String? historySource,
    String? historyThumbnail,
    String? historyOriginalIdentity,
    String? wallpaperId,
    WallpaperSource? wallpaperSource,
  }) async {
    final normalizedSource = _normalizeSource(source);
    final int historyWriteGeneration = _historyWriteGeneration;
    final bool historyOwnerLoggedIn = app_state.prismUser.loggedIn;
    final String historyOwnerId = app_state.prismUser.id.trim();
    final SyncedHistoryStore? historyStore = getIt.isRegistered<SyncedHistoryStore>()
        ? getIt<SyncedHistoryStore>()
        : null;
    final (String, int)? historyStoreSession = historyStore?.recordingSession;
    final String filePath;
    try {
      filePath = (await resolveToLocalFile(
        normalizedSource,
        wallpaperId: wallpaperId,
        wallpaperSource: wallpaperSource,
      )).path;
    } on TimeoutException {
      return const WallpaperSetResult(WallpaperSetStatus.failed, timeoutMessage, errorCode: 'timeout');
    } on OfflineAssetUnavailableException catch (error, stackTrace) {
      logger.w('WallpaperService: original is not available offline', error: error, stackTrace: stackTrace);
      return const WallpaperSetResult(
        WallpaperSetStatus.failed,
        offlineUnavailableMessage,
        errorCode: 'offline_unavailable',
      );
    } on SocketException catch (error, stackTrace) {
      logger.w('WallpaperService: network unavailable while loading the image', error: error, stackTrace: stackTrace);
      return const WallpaperSetResult(
        WallpaperSetStatus.failed,
        offlineUnavailableMessage,
        errorCode: 'offline_unavailable',
      );
    } catch (error, stackTrace) {
      logger.w('WallpaperService: could not load the image', error: error, stackTrace: stackTrace);
      return const WallpaperSetResult(WallpaperSetStatus.failed, failedMessage, errorCode: 'load_failed');
    }

    final aw.WallpaperScaleMode scaleMode = switch (fit) {
      WallpaperFit.fill => aw.WallpaperScaleMode.centerCrop,
      WallpaperFit.whole => aw.WallpaperScaleMode.fitCenter,
    };
    final aw.WallpaperApplyStrategy firstStrategy = useSystemCropper
        ? aw.WallpaperApplyStrategy.systemCropper
        : aw.WallpaperApplyStrategy.direct;

    try {
      final String requestedHistorySource = historySource ?? normalizedSource;
      final String? requestedHistoryThumbnail = _safeHistoryThumbnail(
        historyThumbnail ?? thumbnailUrl,
        source: wallpaperSource,
        normalizedSource: normalizedSource,
        historySource: requestedHistorySource,
      );
      final bool remoteOriginal =
          wallpaperSource == WallpaperSource.prism &&
          (wallpaperId?.isNotEmpty ?? false) &&
          !requestedHistorySource.startsWith('/') &&
          !requestedHistorySource.startsWith('file:');
      String recordedSource = remoteOriginal ? filePath : requestedHistorySource;
      String? originalIdentity = remoteOriginal
          ? '${wallpaperSource!.wireValue}:$wallpaperId'
          : historyOriginalIdentity;
      if (recordHistory && originalIdentity != null && await _isScratchFile(recordedSource)) {
        try {
          final original = await OfflineAssetStore.instance.resolve(recordedSource, allowNetwork: false);
          recordedSource = (await OfflineAssetStore.instance.retain(originalIdentity, file: original)).path;
        } catch (error, stackTrace) {
          logger.w('WallpaperService: could not retain history original', error: error, stackTrace: stackTrace);
        }
      }
      if (originalIdentity == null && getIt.isRegistered<WallpaperHistoryStore>()) {
        for (final item in WallpaperHistoryStore.instance.items()) {
          if (item.fullUrl == recordedSource &&
              item.wallpaperId == wallpaperId &&
              item.source == wallpaperSource?.wireValue &&
              item.originalIdentity != null) {
            originalIdentity = item.originalIdentity;
            break;
          }
        }
      }
      final bool canRecord = recordHistory && await _canRecord(recordedSource);
      final List<AppliedWallpaper?> previous = canRecord ? _previousFor(target) : const <AppliedWallpaper?>[];
      final aw.WallpaperSource platformSource = useSystemCropper
          ? aw.WallpaperSource.contentUri((await _cropChannel.invokeMethod<String>('contentUri', filePath))!)
          : aw.WallpaperSource.filePath(filePath);
      aw.WallpaperOperationResult result = await _apply(platformSource, target, scaleMode, firstStrategy);
      if (!useSystemCropper &&
          result.status == aw.WallpaperOperationStatus.failed &&
          canRetryWallpaperError(result.errorCode)) {
        result = await _apply(platformSource, target, scaleMode, aw.WallpaperApplyStrategy.automatic);
      }
      final WallpaperSetResult mapped = mapStatus(result);
      final WallpaperTarget? recordTarget = mapped.isSuccess ? target : mapped.appliedTarget;
      if (recordTarget != null && getIt.isRegistered<SystemColorSchemesSource>()) {
        unawaited(getIt<SystemColorSchemesSource>().refreshAfterWallpaperSet());
      }
      if (recordHistory &&
          recordTarget != null &&
          _historyOwnerIsCurrent(
            historyWriteGeneration,
            historyOwnerLoggedIn,
            historyOwnerId,
            historyStore,
            historyStoreSession,
          )) {
        unawaited(_recordSynced(wallpaperId, wallpaperSource, requestedHistoryThumbnail));
      }
      if (!canRecord ||
          recordTarget == null ||
          !_historyOwnerIsCurrent(
            historyWriteGeneration,
            historyOwnerLoggedIn,
            historyOwnerId,
            historyStore,
            historyStoreSession,
          )) {
        return mapped;
      }
      final String? id = await _record(
        recordedSource,
        recordTarget,
        requestedHistoryThumbnail,
        wallpaperId: wallpaperId,
        wallpaperSource: wallpaperSource,
        originalIdentity: originalIdentity,
      );
      if (id == null) return mapped;
      return mapped.withHistory(
        restore: _restoreEntries(target, recordTarget, previous, recordedSource),
        historyIds: <String>[id],
      );
    } on TimeoutException {
      return const WallpaperSetResult(WallpaperSetStatus.failed, timeoutMessage, errorCode: 'timeout');
    } catch (error, stackTrace) {
      logger.e('WallpaperService: apply failed', error: error, stackTrace: stackTrace);
      return const WallpaperSetResult(WallpaperSetStatus.failed, failedMessage, errorCode: 'exception');
    }
  }

  static WallpaperSetResult mapStatus(aw.WallpaperOperationResult result) {
    return switch (result.status) {
      aw.WallpaperOperationStatus.applied => const WallpaperSetResult(WallpaperSetStatus.applied, appliedMessage),
      aw.WallpaperOperationStatus.cancelled => const WallpaperSetResult(WallpaperSetStatus.cancelled, ''),
      aw.WallpaperOperationStatus.previewOpened || aw.WallpaperOperationStatus.awaitingUserConfirmation =>
        const WallpaperSetResult(WallpaperSetStatus.pending, pendingMessage),
      aw.WallpaperOperationStatus.unsupported => WallpaperSetResult(
        WallpaperSetStatus.unsupported,
        result.errorCode ?? unsupportedMessage,
        errorCode: result.errorCode,
      ),
      aw.WallpaperOperationStatus.foregroundRequired => WallpaperSetResult(
        WallpaperSetStatus.foregroundRequired,
        foregroundMessage,
        errorCode: result.errorCode,
      ),
      aw.WallpaperOperationStatus.failed => _mapFailed(result),
    };
  }

  static WallpaperSetResult _mapFailed(aw.WallpaperOperationResult result) {
    final WallpaperTarget? applied = _appliedHalf(result);
    if (result.errorCode == 'partial-apply' && applied != null) {
      final WallpaperTarget failed = applied == WallpaperTarget.home ? WallpaperTarget.lock : WallpaperTarget.home;
      return WallpaperSetResult(
        WallpaperSetStatus.failed,
        'partial-apply',
        errorCode: result.errorCode,
        appliedTarget: applied,
        failedTarget: failed,
      );
    }
    return WallpaperSetResult(
      WallpaperSetStatus.failed,
      result.errorCode ?? failedMessage,
      errorCode: result.errorCode,
    );
  }

  /// The one screen that changed when only half of a Both request worked. Null when both or neither changed.
  static WallpaperTarget? _appliedHalf(aw.WallpaperOperationResult result) {
    final bool home = result.home?.status == aw.WallpaperTargetStatus.applied;
    final bool lock = result.lock?.status == aw.WallpaperTargetStatus.applied;
    if (home == lock) return null;
    return home ? WallpaperTarget.home : WallpaperTarget.lock;
  }

  static Future<aw.WallpaperOperationResult> _apply(
    aw.WallpaperSource source,
    WallpaperTarget target,
    aw.WallpaperScaleMode scaleMode,
    aw.WallpaperApplyStrategy strategy,
  ) {
    final request = aw.StaticWallpaperRequest(
      source: source,
      target: aw.WallpaperTarget.values.byName(target.name),
      scaleMode: scaleMode,
      strategy: strategy,
    );
    return PerformanceProbe.measure(
      'native',
      'set_wallpaper.${target.name}',
      () => aw.AsyncWallpaper.applyWallpaper(request).timeout(const Duration(seconds: 30)),
    );
  }

  /// True for a local file in the temp or cache directory. Those files go away, so history cannot reopen them.
  static Future<bool> _isScratchFile(String source) async {
    if (source.startsWith('http://') || source.startsWith('https://')) return false;
    try {
      final List<Directory> scratchDirs = <Directory>[
        await getTemporaryDirectory(),
        await getApplicationCacheDirectory(),
      ];
      return scratchDirs.any((dir) => path.isWithin(dir.path, source));
    } catch (error, stackTrace) {
      logger.w('WallpaperService: could not check the temp directory', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  /// True when history is on and [source] is a wall history can open again.
  static Future<bool> _canRecord(String source) async =>
      getIt.isRegistered<WallpaperHistoryStore>() && !await _isScratchFile(source);

  /// The history rows now on each screen [target] will change: one entry for home and lock, in that order.
  static List<AppliedWallpaper?> _previousFor(WallpaperTarget target) {
    final WallpaperHistoryStore store = WallpaperHistoryStore.instance;
    return switch (target) {
      WallpaperTarget.home => <AppliedWallpaper?>[store.currentFor('home')],
      WallpaperTarget.lock => <AppliedWallpaper?>[store.currentFor('lock')],
      WallpaperTarget.both => <AppliedWallpaper?>[store.currentFor('home'), store.currentFor('lock')],
    };
  }

  /// Undo entries for the screens that changed. Two screens with the same previous wall become one `both` entry.
  static List<WallpaperRestore> _restoreEntries(
    WallpaperTarget requested,
    WallpaperTarget changed,
    List<AppliedWallpaper?> previous,
    String newSource,
  ) {
    final AppliedWallpaper? home = switch (requested) {
      WallpaperTarget.lock => null,
      _ => previous.first,
    };
    final AppliedWallpaper? lock = switch (requested) {
      WallpaperTarget.home => null,
      WallpaperTarget.lock => previous.first,
      WallpaperTarget.both => previous.last,
    };
    AppliedWallpaper? usable(AppliedWallpaper? item, bool changedScreen) =>
        changedScreen && item != null && item.fullUrl != newSource ? item : null;
    final AppliedWallpaper? homeBefore = usable(home, changed != WallpaperTarget.lock);
    final AppliedWallpaper? lockBefore = usable(lock, changed != WallpaperTarget.home);
    if (homeBefore != null && lockBefore != null && homeBefore.fullUrl == lockBefore.fullUrl) {
      return <WallpaperRestore>[WallpaperRestore(WallpaperTarget.both, homeBefore)];
    }
    return <WallpaperRestore>[
      if (homeBefore != null) WallpaperRestore(WallpaperTarget.home, homeBefore),
      if (lockBefore != null) WallpaperRestore(WallpaperTarget.lock, lockBefore),
    ];
  }

  static Future<String?> _record(
    String source,
    WallpaperTarget target,
    String? thumbnailUrl, {
    String? wallpaperId,
    WallpaperSource? wallpaperSource,
    String? originalIdentity,
  }) async {
    try {
      final DateTime now = DateTime.now();
      return await WallpaperHistoryStore.instance.record(
        AppliedWallpaper(
          id: '${now.microsecondsSinceEpoch}',
          source: wallpaperSource?.wireValue ?? _historySource(source),
          wallpaperId: wallpaperId,
          originalIdentity: originalIdentity,
          thumbnailUrl: thumbnailUrl ?? (wallpaperSource == WallpaperSource.prism ? '' : source),
          fullUrl: source,
          target: target.name,
          appliedAt: now,
        ),
      );
    } catch (error, stackTrace) {
      logger.w('WallpaperService: could not record history', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  static String? _safeHistoryThumbnail(
    String? thumbnail, {
    required WallpaperSource? source,
    required String normalizedSource,
    required String historySource,
  }) {
    final String? candidate = thumbnail?.trim();
    if (candidate == null || candidate.isEmpty) return null;
    if (source == WallpaperSource.prism && (candidate == normalizedSource || candidate == historySource)) return null;
    return candidate;
  }

  static bool _historyOwnerIsCurrent(
    int generation,
    bool loggedIn,
    String ownerId,
    SyncedHistoryStore? store,
    (String, int)? storeSession,
  ) {
    if (generation != _historyWriteGeneration ||
        app_state.prismUser.loggedIn != loggedIn ||
        app_state.prismUser.id.trim() != ownerId) {
      return false;
    }
    if (store == null) return true;
    return getIt.isRegistered<SyncedHistoryStore>() &&
        identical(getIt<SyncedHistoryStore>(), store) &&
        store.recordingSession == storeSession;
  }

  /// Adds a set catalogue wall to the account history. Local files and walls without a public thumbnail stay out.
  static Future<void> _recordSynced(String? wallpaperId, WallpaperSource? source, String? thumbnailUrl) async {
    final HistoryWall? wall = HistoryWall.tryCreate(
      id: wallpaperId,
      source: source,
      thumbnailUrl: thumbnailUrl,
      action: HistoryAction.set,
      at: DateTime.now(),
    );
    if (wall == null || !getIt.isRegistered<SyncedHistoryStore>()) return;
    try {
      await getIt<SyncedHistoryStore>().record(wall);
    } catch (error, stackTrace) {
      logger.w('WallpaperService: could not sync history', error: error, stackTrace: stackTrace);
    }
  }

  static String _historySource(String source) {
    final String host = Uri.tryParse(source)?.host ?? '';
    if (host.contains('wallhaven')) return 'wallhaven';
    if (host.contains('pexels')) return 'pexels';
    if (host.isEmpty) return 'local';
    return 'prism';
  }

  static Future<File> resolveToLocalFile(
    String source, {
    bool allowNetwork = true,
    String? wallpaperId,
    WallpaperSource? wallpaperSource,
  }) async {
    final String normalizedSource = _normalizeSource(source);
    final OfflineAssetStore assetStore = OfflineAssetStore.instance;
    if (wallpaperId != null && wallpaperSource != null && getIt.isRegistered<DownloadedWallIndex>()) {
      final File? downloaded = await getIt<DownloadedWallIndex>().localFileFor(
        link: normalizedSource,
        id: wallpaperId,
        source: wallpaperSource,
      );
      if (downloaded != null) {
        final File? verified = await assetStore.lookup(downloaded.path);
        if (verified != null) return verified;
      }
    } else if (getIt.isRegistered<DownloadedWallIndex>()) {
      final File? downloaded = await getIt<DownloadedWallIndex>().localFileForLink(normalizedSource);
      if (downloaded != null) {
        final File? verified = await assetStore.lookup(downloaded.path);
        if (verified != null) return verified;
      }
    }
    final Future<File> resolved = assetStore.resolve(normalizedSource, allowNetwork: allowNetwork);
    return allowNetwork ? resolved.timeout(const Duration(seconds: 30)) : resolved;
  }

  static String _normalizeSource(String source) {
    final Uri? uri = Uri.tryParse(source);
    if (uri?.scheme == 'file') return uri!.toFilePath();
    if (source.startsWith('/')) return source.replaceAll('/0//', '/0/');
    return source;
  }
}
