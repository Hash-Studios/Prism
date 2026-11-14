import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/photo_job.dart';
import 'package:Prism/features/user_search/data/photo_search_service.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The usual Extend and Restyle upload long side. Narrow photos keep a longer side so the short side stays at least 256 px.
const int photoExtendUploadSide = 2560;

/// The long side the app sends for Upscale. An Upscale photo is smaller than the screen, so it is sent at full size.
const int photoUpscaleUploadSide = 4096;

/// The callable can take up to 180 seconds. The app waits a little longer so a slow job is not dropped.
const Duration photoJobTimeout = Duration(seconds: 190);

typedef PhotoJobCall = Future<Object?> Function(Map<String, Object?> payload);

/// Picks a photo, makes a metadata-free upload copy, and runs a job on the `createPhotoWallpaper` callable.
class PhotoWallpaperRepository {
  PhotoWallpaperRepository([
    Future<Uint8List?> Function()? pick,
    Future<PhotoSize> Function(Uint8List bytes)? measure,
    Future<Uint8List> Function(Uint8List bytes, int longSide)? toUploadJpeg,
    PhotoJobCall? call,
    PhotoJobCall? lookup,
    Future<String?> Function()? readPending,
    Future<void> Function(String? json)? writePending,
    void Function(int balance)? onBalance,
  ]) : _pick = pick ?? _pickFromGallery,
       _measure = measure ?? _uprightSize,
       _toUploadJpeg = toUploadJpeg ?? _uploadJpegOf,
       _call = call ?? _callCallable,
       _lookup = lookup ?? _lookupCallable,
       _readPending = readPending ?? _readPendingSetting,
       _writePending = writePending ?? _writePendingSetting,
       _onBalance = onBalance ?? _applyServerBalance;

  final Future<Uint8List?> Function() _pick;
  final Future<PhotoSize> Function(Uint8List bytes) _measure;
  final Future<Uint8List> Function(Uint8List bytes, int longSide) _toUploadJpeg;
  final PhotoJobCall _call;
  final PhotoJobCall _lookup;
  final void Function(int balance) _onBalance;

  /// Applies the coin balance a job result carries, then returns [data] unchanged.
  Object? _withBalance(Object? data, ({String userId, int session})? owner) {
    if (data is Map && data['balance'] is int && _owns(owner)) {
      try {
        _onBalance(data['balance'] as int);
      } catch (error) {
        logger.w('[PhotoWallpaper] balance update failed (${error.runtimeType})');
      }
    }
    return data;
  }

  ({String userId, int session})? _currentOwner() =>
      app_state.prismUser.loggedIn && app_state.prismUser.id.trim().isNotEmpty
      ? (userId: app_state.prismUser.id, session: CoinsService.instance.economySession)
      : null;

  bool _owns(({String userId, int session})? owner) =>
      owner != null &&
      app_state.prismUser.loggedIn &&
      app_state.prismUser.id == owner.userId &&
      CoinsService.instance.economySession == owner.session;

  bool _ownerChanged(({String userId, int session})? owner) => owner != null && !_owns(owner);

  static void _applyServerBalance(int balance) => CoinsService.instance.applyServerBalance(balance);
  final Future<String?> Function() _readPending;
  final Future<void> Function(String? json) _writePending;

  // Pages share one setting, so their read-modify-write operations must not replace one another.
  static Future<void>? _pendingOperation;

  static Future<T> _serializePending<T>(Future<T> Function() operation) {
    final Future<void>? previous = _pendingOperation;
    final Future<T> result = previous == null ? Future<T>.sync(operation) : previous.then((_) => operation());
    late final Future<void> tail;
    tail = result.then<void>((_) {}, onError: (Object error, StackTrace stack) {}).whenComplete(() {
      if (identical(_pendingOperation, tail)) _pendingOperation = null;
    });
    _pendingOperation = tail;
    return result;
  }

  /// The owner's job from the previous app run, or null. Storage errors are not an empty slot.
  Future<PendingPhotoJob?> readPending({required String userId}) =>
      _serializePending(() async => (await _readPendingJobs())[userId]);

  /// Saves [job] before it can charge coins. An unresolved request cannot be replaced by another one.
  Future<void> savePending(PendingPhotoJob job) => _serializePending(() async {
    final Map<String, PendingPhotoJob> jobs = await _readPendingJobs();
    final PendingPhotoJob? previous = jobs[job.userId];
    if (previous != null && previous.requestId != job.requestId) {
      throw StateError('A photo job is still pending for this account.');
    }
    jobs[job.userId] = job;
    await _writePending(jsonEncode(jobs.values.map((PendingPhotoJob pending) => pending.toJson()).toList()));
  });

  /// Removes only the completed request, leaving other accounts and newer requests untouched.
  Future<void> clearPending({required String userId, required String requestId}) => _serializePending(() async {
    final Map<String, PendingPhotoJob> jobs = await _readPendingJobs();
    if (jobs[userId]?.requestId != requestId) return;
    jobs.remove(userId);
    await _writePending(
      jobs.isEmpty ? null : jsonEncode(jobs.values.map((PendingPhotoJob pending) => pending.toJson()).toList()),
    );
  });

  Future<Map<String, PendingPhotoJob>> _readPendingJobs() async {
    final String? raw = await _readPending();
    if (raw == null) return <String, PendingPhotoJob>{};
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return <String, PendingPhotoJob>{};
    }
    // Read the original single-job format as well as the account-isolated list.
    final Iterable<Object?> records = decoded is List ? decoded : <Object?>[decoded];
    final Map<String, PendingPhotoJob> jobs = <String, PendingPhotoJob>{};
    for (final Object? record in records) {
      final PendingPhotoJob? job = PendingPhotoJob.fromJson(record);
      if (job != null) jobs[job.userId] = job;
    }
    return jobs;
  }

  /// The server state of a job started before the app restarted. Null when the server has no such job.
  Future<PhotoJobState?> recover(String requestId) async {
    final ({String userId, int session})? owner = _currentOwner();
    try {
      final Object? data = _withBalance(await _lookup(<String, Object?>{'requestId': requestId}), owner);
      if (data is Map && data['state'] == 'unknown') return null;
      if (data is Map && data['state'] == 'running') return PhotoJobRunning(requestId);
      return parsePhotoJobResult(data);
    } on FirebaseFunctionsException catch (error) {
      logger.w('[PhotoWallpaper] job lookup failed: ${error.code}');
      return const PhotoJobFailed(reason: PhotoJobFailure.network, charged: false, refunded: false);
    } catch (error) {
      logger.w('[PhotoWallpaper] job lookup failed (${error.runtimeType})');
      return const PhotoJobFailed(reason: PhotoJobFailure.network, charged: false, refunded: false);
    }
  }

  /// The picked photo with its upright size, or null when the user picks none. Throws when it cannot be decoded.
  Future<PhotoSource?> pick() async {
    final Uint8List? bytes = await _pick();
    if (bytes == null) return null;
    return source(bytes);
  }

  /// [bytes] with its upright size. Throws when they cannot be decoded.
  Future<PhotoSource> source(Uint8List bytes) async => PhotoSource(bytes: bytes, size: await _measure(bytes));

  /// Runs [job] once, and once more with the same [requestId] when the connection drops. The server replays a
  /// finished job for the same requestId, so the retry never charges twice.
  Future<PhotoJobState> run(
    PhotoJob job, {
    required String requestId,
    required PhotoSize targetSize,
    PhotoPlacement? placement,
  }) async {
    final ({String userId, int session})? owner = _currentOwner();
    final Uint8List jpeg;
    try {
      final PhotoSize size = job.source.size;
      final int minimumLongSide = (256 * math.max(size.width, size.height) / size.shortSide).ceil();
      final int extendSide = math
          .max(photoExtendUploadSide, minimumLongSide)
          .clamp(photoExtendUploadSide, photoUpscaleUploadSide);
      jpeg = await _toUploadJpeg(
        job.source.bytes,
        job.mode == PhotoJobMode.upscale ? photoUpscaleUploadSide : extendSide,
      );
    } catch (_) {
      return const PhotoJobFailed(reason: PhotoJobFailure.unreadable, charged: false, refunded: false);
    }
    final Map<String, Object?> payload = <String, Object?>{
      'requestId': requestId,
      'mode': job.mode.name,
      'target': job.target.name,
      if (job.target == PhotoJobTarget.phone) ...<String, Object?>{
        'targetWidth': targetSize.width,
        'targetHeight': targetSize.height,
      },
      if (job.mode == PhotoJobMode.extend && placement != null) 'placement': placement.toJson(),
      if (job.style case final AiStylePreset style) 'styleId': style.apiValue,
      'image': base64Encode(jpeg),
    };
    for (int attempt = 0; ; attempt++) {
      if (_ownerChanged(owner)) {
        return const PhotoJobFailed(reason: PhotoJobFailure.network, charged: false, refunded: false);
      }
      try {
        return parsePhotoJobResult(_withBalance(await _call(payload), owner));
      } on FirebaseFunctionsException catch (error) {
        logger.w('[PhotoWallpaper] job call failed: ${error.code}');
        final bool dropped = const <String>{'deadline-exceeded', 'unavailable', 'internal'}.contains(error.code);
        if (dropped && attempt == 0) continue;
        return photoJobFailureFor(error.code, error.message);
      } catch (error) {
        logger.w('[PhotoWallpaper] job call failed (${error.runtimeType})');
        if (attempt == 0) continue;
        return const PhotoJobFailed(reason: PhotoJobFailure.network, charged: false, refunded: false);
      }
    }
  }

  static Future<Object?> _lookupCallable(Map<String, Object?> payload) async =>
      (await appFunctions.httpsCallable('getPhotoWallpaper').call<Object?>(payload)).data;

  static Future<String?> _readPendingSetting() async =>
      getIt<SettingsLocalDataSource>().get<String?>(PersistenceKeys.photoWallPendingJob);

  static Future<void> _writePendingSetting(String? json) => json == null
      ? getIt<SettingsLocalDataSource>().delete(PersistenceKeys.photoWallPendingJob)
      : getIt<SettingsLocalDataSource>().set(PersistenceKeys.photoWallPendingJob, json);

  static Future<Object?> _callCallable(Map<String, Object?> payload) async =>
      (await appFunctions
              .httpsCallable('createPhotoWallpaper', options: HttpsCallableOptions(timeout: photoJobTimeout))
              .call<Object?>(payload))
          .data;

  static Future<Uint8List?> _pickFromGallery() async {
    final XFile? file = await ImagePicker().pickImage(source: ImageSource.gallery, requestFullMetadata: false);
    if (file == null) return null;
    final Directory temporaryDirectory = Platform.isIOS ? Directory.systemTemp : await getTemporaryDirectory();
    return readAndCleanupPickedPhoto(file, temporaryDirectory: temporaryDirectory);
  }

  /// The upright size: the decoder reports the stored size, and a small upright decode gives the turn.
  static Future<PhotoSize> _uprightSize(Uint8List bytes) async {
    int storedWidth = 0;
    int storedHeight = 0;
    final ui.Codec codec = await ui.instantiateImageCodecWithSize(
      await ui.ImmutableBuffer.fromUint8List(bytes),
      getTargetSize: (int width, int height) {
        storedWidth = width;
        storedHeight = height;
        return width >= height ? const ui.TargetImageSize(width: 256) : const ui.TargetImageSize(height: 256);
      },
    );
    try {
      final ui.Image small = (await codec.getNextFrame()).image;
      try {
        final bool turned = small.width != small.height && (storedWidth > storedHeight) != (small.width > small.height);
        return turned ? PhotoSize(storedHeight, storedWidth) : PhotoSize(storedWidth, storedHeight);
      } finally {
        small.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  /// Decodes to raw pixels, then encodes a JPEG. A JPEG made from raw pixels has no EXIF, GPS or other metadata.
  static Future<Uint8List> _uploadJpegOf(Uint8List bytes, int longSide) async {
    final ui.Image image = await decodePhotoAtMost(bytes, longSide);
    try {
      final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw const FormatException('The photo could not be decoded.');
      return await FlutterImageCompress.compressWithList(
        png.buffer.asUint8List(),
        minWidth: image.width,
        minHeight: image.height,
        quality: 92,
        autoCorrectionAngle: false,
      );
    } finally {
      image.dispose();
    }
  }
}

/// Reads a picker-owned cache copy and removes it. Never deletes a path outside the app's temporary directory.
Future<Uint8List> readAndCleanupPickedPhoto(XFile file, {required Directory temporaryDirectory}) async {
  try {
    return await file.readAsBytes();
  } finally {
    // Best effort: a cleanup error must not replace the photo that was read.
    try {
      final String tempPath = p.normalize(p.absolute(temporaryDirectory.path));
      final String pickedPath = p.normalize(p.absolute(file.path));
      final FileSystemEntityType type = await FileSystemEntity.type(pickedPath, followLinks: false);
      if (type == FileSystemEntityType.file) {
        final String realTempPath = await Directory(tempPath).resolveSymbolicLinks();
        final String realPickedPath = await File(pickedPath).resolveSymbolicLinks();
        if (p.isWithin(realTempPath, realPickedPath)) await File(pickedPath).delete();
      }
    } catch (error) {
      logger.w('[PhotoWallpaper] picker copy cleanup failed (${error.runtimeType})');
    }
  }
}

/// The job state from the callable's result.
PhotoJobState parsePhotoJobResult(Object? data) {
  if (data is! Map) return const PhotoJobFailed(reason: PhotoJobFailure.network, charged: false, refunded: false);
  if (data['state'] == 'succeeded' && data['imageUrl'] is String && data['width'] is int && data['height'] is int) {
    return PhotoJobSucceeded(
      jobId: data['jobId'] as String? ?? '',
      imageUrl: data['imageUrl'] as String,
      size: PhotoSize(data['width'] as int, data['height'] as int),
      watermarked: data['watermarked'] == true,
    );
  }
  if (data['state'] != 'failed') {
    return const PhotoJobFailed(reason: PhotoJobFailure.network, charged: false, refunded: false);
  }
  final Object? cost = data['cost'];
  return PhotoJobFailed(
    reason: PhotoJobFailure.fromWire(data['reason']),
    charged: true,
    refunded: data['refunded'] == true,
    cost: cost is int && cost >= 0 ? cost : null,
  );
}

/// A refusal from the callable. Every refusal except `aborted` happens before the charge.
PhotoJobFailed photoJobFailureFor(String code, String? message) {
  final PhotoJobFailure reason = switch (code) {
    'unauthenticated' => PhotoJobFailure.signIn,
    'resource-exhausted' => message == 'busy' ? PhotoJobFailure.busy : PhotoJobFailure.dailyLimit,
    'failed-precondition' =>
      message == 'insufficient_coins' ? PhotoJobFailure.insufficientCoins : PhotoJobFailure.unreadable,
    'invalid-argument' => PhotoJobFailure.unreadable,
    'aborted' => PhotoJobFailure.inProgress,
    _ => PhotoJobFailure.network,
  };
  return PhotoJobFailed(reason: reason, charged: false, refunded: false);
}
