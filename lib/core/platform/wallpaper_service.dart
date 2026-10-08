import 'dart:async';
import 'dart:io';

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/platform/wallpaper_error_messages.dart';
import 'package:Prism/features/wallpaper_history/wallpaper_history.dart';
import 'package:Prism/logger/logger.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
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
}

// ignore: avoid_classes_with_only_static_members
class WallpaperService {
  static const String appliedMessage = 'Wallpaper set successfully!';
  static const String pendingMessage = 'Confirm the wallpaper in the system preview.';
  static const String unsupportedMessage = "This device can't set that screen.";
  static const String foregroundMessage = 'Keep Prism open and try again.';
  static const String failedMessage = "Couldn't set the wallpaper.";
  static const String timeoutMessage = 'Timed out. Check your connection and try again.';

  /// Sets [source] on [target].
  ///
  /// History keeps [historySource] and [historyThumbnail] when given. Callers that set a rendered copy of a wall pass
  /// the original here, so history can set the wall again.
  static Future<WallpaperSetResult> setWallpaper(
    String source,
    WallpaperTarget target, {
    WallpaperFit fit = WallpaperFit.fill,
    String? thumbnailUrl,
    bool recordHistory = true,
    String? historySource,
    String? historyThumbnail,
  }) async {
    final normalizedSource = _normalizeSource(source);
    final String filePath;
    try {
      filePath = await _resolveToLocalFile(normalizedSource);
    } on TimeoutException {
      return const WallpaperSetResult(WallpaperSetStatus.failed, timeoutMessage, errorCode: 'timeout');
    } catch (error, stackTrace) {
      logger.w('WallpaperService: could not load the image', error: error, stackTrace: stackTrace);
      return const WallpaperSetResult(WallpaperSetStatus.failed, failedMessage, errorCode: 'load_failed');
    }

    final aw.WallpaperScaleMode scaleMode = switch (fit) {
      WallpaperFit.fill => aw.WallpaperScaleMode.centerCrop,
      WallpaperFit.whole => aw.WallpaperScaleMode.fitCenter,
    };

    try {
      final String recordedSource = historySource ?? normalizedSource;
      final bool canRecord = recordHistory && await _canRecord(recordedSource);
      final List<AppliedWallpaper?> previous = canRecord ? _previousFor(target) : const <AppliedWallpaper?>[];
      aw.WallpaperOperationResult result = await _apply(filePath, target, scaleMode, aw.WallpaperApplyStrategy.direct);
      if (result.status == aw.WallpaperOperationStatus.failed && canRetryWallpaperError(result.errorCode)) {
        result = await _apply(filePath, target, scaleMode, aw.WallpaperApplyStrategy.automatic);
      }
      final WallpaperSetResult mapped = mapStatus(result);
      final WallpaperTarget? recordTarget = mapped.isSuccess ? target : mapped.appliedTarget;
      if (!canRecord || recordTarget == null) return mapped;
      final String? id = await _record(recordedSource, recordTarget, historyThumbnail ?? thumbnailUrl);
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

  /// Same as [setWallpaper] for callers that only need to know whether the wallpaper changed.
  static Future<bool> setWallpaperFromSource(String source, WallpaperTarget target) async {
    return (await setWallpaper(source, target)).isSuccess;
  }

  static WallpaperSetResult mapStatus(aw.WallpaperOperationResult result) {
    return switch (result.status) {
      aw.WallpaperOperationStatus.applied => const WallpaperSetResult(WallpaperSetStatus.applied, appliedMessage),
      aw.WallpaperOperationStatus.cancelled => const WallpaperSetResult(WallpaperSetStatus.cancelled, ''),
      aw.WallpaperOperationStatus.previewOpened || aw.WallpaperOperationStatus.awaitingUserConfirmation =>
        const WallpaperSetResult(WallpaperSetStatus.pending, pendingMessage),
      aw.WallpaperOperationStatus.unsupported => WallpaperSetResult(
        WallpaperSetStatus.unsupported,
        result.errorCode == 'wallpaper-not-allowed' ? wallpaperErrorMessage(result.errorCode) : unsupportedMessage,
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
        '${_screenName(applied)} set. ${_screenName(failed)} failed.',
        errorCode: result.errorCode,
        appliedTarget: applied,
        failedTarget: failed,
      );
    }
    return WallpaperSetResult(
      WallpaperSetStatus.failed,
      wallpaperErrorMessage(result.errorCode),
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

  static String _screenName(WallpaperTarget target) => switch (target) {
    WallpaperTarget.home => 'Home screen',
    WallpaperTarget.lock => 'Lock screen',
    WallpaperTarget.both => 'Both screens',
  };

  static Future<aw.WallpaperOperationResult> _apply(
    String filePath,
    WallpaperTarget target,
    aw.WallpaperScaleMode scaleMode,
    aw.WallpaperApplyStrategy strategy,
  ) {
    final request = aw.StaticWallpaperRequest(
      source: aw.WallpaperSource.filePath(filePath),
      target: aw.WallpaperTarget.values.byName(target.name),
      scaleMode: scaleMode,
      strategy: strategy,
    );
    return aw.AsyncWallpaper.applyWallpaper(request).timeout(const Duration(seconds: 30));
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

  static Future<String?> _record(String source, WallpaperTarget target, String? thumbnailUrl) async {
    try {
      final DateTime now = DateTime.now();
      return await WallpaperHistoryStore.instance.record(
        AppliedWallpaper(
          id: '${now.microsecondsSinceEpoch}',
          source: _historySource(source),
          thumbnailUrl: thumbnailUrl ?? source,
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

  static String _historySource(String source) {
    final String host = Uri.tryParse(source)?.host ?? '';
    if (host.contains('wallhaven')) return 'wallhaven';
    if (host.contains('pexels')) return 'pexels';
    if (host.isEmpty) return 'local';
    return 'prism';
  }

  static String _normalizeSource(String source) {
    final Uri? uri = Uri.tryParse(source);
    if (uri?.scheme == 'file') {
      return uri!.toFilePath();
    }
    if (source.startsWith('/')) {
      return source.replaceAll('/0//', '/0/');
    }
    return source;
  }

  static Future<String> _resolveToLocalFile(String source) async {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      final file = await PrismFullImageCache.instance.getSingleFile(source).timeout(const Duration(seconds: 30));
      return file.path;
    }
    return source;
  }
}
