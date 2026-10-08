import 'dart:async';
import 'dart:io';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/wallpaper_history/wallpaper_history.dart';
import 'package:Prism/logger/logger.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

enum WallpaperTarget { home, lock, both }

/// How the image fills the screen. [fill] crops to cover the screen. [whole] shows the full image.
enum WallpaperFit { fill, whole }

enum WallpaperSetStatus { applied, cancelled, pending, unsupported, foregroundRequired, failed }

class WallpaperSetResult {
  const WallpaperSetResult(this.status, this.message, {this.errorCode});

  final WallpaperSetStatus status;
  final String message;
  final String? errorCode;

  bool get isSuccess => status == WallpaperSetStatus.applied;
  bool get isSilent => status == WallpaperSetStatus.cancelled;
  bool get isInfo => status == WallpaperSetStatus.pending;
  bool get canRetry => status == WallpaperSetStatus.failed || status == WallpaperSetStatus.foregroundRequired;
  bool get isFailure => canRetry || status == WallpaperSetStatus.unsupported;
}

// ignore: avoid_classes_with_only_static_members
class WallpaperService {
  static const String appliedMessage = 'Wallpaper set successfully!';
  static const String pendingMessage = 'Confirm the wallpaper in the system preview.';
  static const String unsupportedMessage = "This device can't set that screen.";
  static const String foregroundMessage = 'Keep Prism open and try again.';
  static const String failedMessage = "Couldn't set the wallpaper.";
  static const String timeoutMessage = 'Timed out. Check your connection and try again.';

  /// Turns a local file into a content URI. The Android system cropper cannot read a file path.
  static const MethodChannel _cropChannel = MethodChannel('prism/wallpaper_crop');

  static Future<WallpaperSetResult> setWallpaper(
    String source,
    WallpaperTarget target, {
    WallpaperFit fit = WallpaperFit.fill,
    bool useSystemCropper = false,
    String? thumbnailUrl,
    bool recordHistory = true,
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
    final aw.WallpaperApplyStrategy firstStrategy = useSystemCropper
        ? aw.WallpaperApplyStrategy.systemCropper
        : aw.WallpaperApplyStrategy.direct;

    try {
      final aw.WallpaperSource wallpaperSource = useSystemCropper
          ? aw.WallpaperSource.contentUri((await _cropChannel.invokeMethod<String>('contentUri', filePath))!)
          : aw.WallpaperSource.filePath(filePath);
      aw.WallpaperOperationResult result = await _apply(wallpaperSource, target, scaleMode, firstStrategy);
      if (!useSystemCropper && result.status == aw.WallpaperOperationStatus.failed) {
        result = await _apply(wallpaperSource, target, scaleMode, aw.WallpaperApplyStrategy.automatic);
      }
      final WallpaperSetResult mapped = mapStatus(result);
      if (mapped.isSuccess && recordHistory) {
        await _record(normalizedSource, target, thumbnailUrl);
      }
      return mapped;
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
        unsupportedMessage,
        errorCode: result.errorCode,
      ),
      aw.WallpaperOperationStatus.foregroundRequired => WallpaperSetResult(
        WallpaperSetStatus.foregroundRequired,
        foregroundMessage,
        errorCode: result.errorCode,
      ),
      aw.WallpaperOperationStatus.failed => WallpaperSetResult(
        WallpaperSetStatus.failed,
        failedMessage,
        errorCode: result.errorCode,
      ),
    };
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

  static Future<void> _record(String source, WallpaperTarget target, String? thumbnailUrl) async {
    try {
      if (!getIt.isRegistered<WallpaperHistoryStore>() || await _isScratchFile(source)) return;
      final DateTime now = DateTime.now();
      await WallpaperHistoryStore.instance.record(
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
      final file = await DefaultCacheManager().getSingleFile(source).timeout(const Duration(seconds: 30));
      return file.path;
    }
    return source;
  }
}
