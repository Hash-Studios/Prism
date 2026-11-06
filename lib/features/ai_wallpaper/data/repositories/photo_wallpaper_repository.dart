import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/photo_job.dart';
import 'package:Prism/features/user_search/data/photo_search_service.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// The long side of the photo the app sends for Extend. Bria places it in a canvas of at most 2560 px.
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
  ]) : _pick = pick ?? _pickFromGallery,
       _measure = measure ?? _uprightSize,
       _toUploadJpeg = toUploadJpeg ?? _uploadJpegOf,
       _call = call ?? _callCallable;

  final Future<Uint8List?> Function() _pick;
  final Future<PhotoSize> Function(Uint8List bytes) _measure;
  final Future<Uint8List> Function(Uint8List bytes, int longSide) _toUploadJpeg;
  final PhotoJobCall _call;

  /// The picked photo with its upright size, or null when the user picks none. Throws when it cannot be decoded.
  Future<PhotoSource?> pick() async {
    final Uint8List? bytes = await _pick();
    if (bytes == null) return null;
    return PhotoSource(bytes: bytes, size: await _measure(bytes));
  }

  /// Runs [job] once, and once more with the same [requestId] when the connection drops. The server replays a
  /// finished job for the same requestId, so the retry never charges twice.
  Future<PhotoJobState> run(
    PhotoJob job, {
    required String requestId,
    required PhotoSize targetSize,
    PhotoPlacement? placement,
  }) async {
    final Uint8List jpeg;
    try {
      jpeg = await _toUploadJpeg(
        job.source.bytes,
        job.mode == PhotoJobMode.extend ? photoExtendUploadSide : photoUpscaleUploadSide,
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
      'image': base64Encode(jpeg),
    };
    for (int attempt = 0; ; attempt++) {
      try {
        return parsePhotoJobResult(await _call(payload));
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

  static Future<Object?> _callCallable(Map<String, Object?> payload) async =>
      (await appFunctions
              .httpsCallable('createPhotoWallpaper', options: HttpsCallableOptions(timeout: photoJobTimeout))
              .call<Object?>(payload))
          .data;

  static Future<Uint8List?> _pickFromGallery() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: photoUpscaleUploadSide.toDouble(),
      maxHeight: photoUpscaleUploadSide.toDouble(),
      requestFullMetadata: false,
    );
    return file?.readAsBytes();
  }

  /// The upright size: the decoder reports the stored size, and a small upright decode gives the turn.
  static Future<PhotoSize> _uprightSize(Uint8List bytes) async {
    int storedLong = 0;
    final ui.Codec codec = await ui.instantiateImageCodecWithSize(
      await ui.ImmutableBuffer.fromUint8List(bytes),
      getTargetSize: (int width, int height) {
        storedLong = math.max(width, height);
        return width >= height ? const ui.TargetImageSize(width: 256) : const ui.TargetImageSize(height: 256);
      },
    );
    try {
      final ui.Image small = (await codec.getNextFrame()).image;
      try {
        final double scale = storedLong / math.max(small.width, small.height);
        return PhotoSize((small.width * scale).round(), (small.height * scale).round());
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

/// The job state from the callable's result.
PhotoJobState parsePhotoJobResult(Object? data) {
  if (data is! Map) return const PhotoJobFailed(reason: PhotoJobFailure.providerError, charged: false, refunded: false);
  if (data['state'] == 'succeeded' && data['imageUrl'] is String && data['width'] is int && data['height'] is int) {
    return PhotoJobSucceeded(
      jobId: data['jobId'] as String? ?? '',
      imageUrl: data['imageUrl'] as String,
      size: PhotoSize(data['width'] as int, data['height'] as int),
      watermarked: data['watermarked'] == true,
    );
  }
  return PhotoJobFailed(
    reason: PhotoJobFailure.fromWire(data['reason']),
    charged: data['state'] == 'failed',
    refunded: data['refunded'] == true,
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
