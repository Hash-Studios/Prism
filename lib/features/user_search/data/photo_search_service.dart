import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_correlation.dart';
import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/features/user_search/data/photo_palette.dart';
import 'package:Prism/features/user_search/domain/entities/photo_query.dart';
import 'package:Prism/logger/logger.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';

/// The long side of the copy that is sent for labels.
const int photoUploadSize = 512;

/// The daily number of photo searches with labels, the same as `MAX_PHOTO_SEARCHES_PER_DAY` in
/// `functions/src/photoSearchLabels.ts`.
const int photoSearchDailyCap = 20;

/// A photo decoded on the phone: a PNG with a long side of at most [photoUploadSize], and RGBA pixels with a long side
/// of at most [photoPaletteSampleSize] for the palette.
typedef PreparedPhoto = ({Uint8List png, Uint8List sample});

typedef PhotoLabels = ({PhotoLabelsStatus status, List<String> labels, String? category});

/// Builds two copies of [original] from its decoded pixels. Neither copy holds the EXIF, location or other metadata
/// of [original], because a PNG made from raw pixels has nowhere to carry it.
Future<PreparedPhoto> preparePhoto(Uint8List original) async {
  final ui.Image large = await _decode(original, photoUploadSize);
  try {
    final ui.Image small = await _decode(original, photoPaletteSampleSize);
    try {
      final ByteData? png = await large.toByteData(format: ui.ImageByteFormat.png);
      final ByteData? rgba = await small.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      if (png == null || rgba == null) throw const FormatException('The photo could not be decoded.');
      return (png: png.buffer.asUint8List(), sample: rgba.buffer.asUint8List());
    } finally {
      small.dispose();
    }
  } finally {
    large.dispose();
  }
}

Future<ui.Image> _decode(Uint8List bytes, int longSide) async {
  final ui.Codec codec = await ui.instantiateImageCodecWithSize(
    await ui.ImmutableBuffer.fromUint8List(bytes),
    getTargetSize: (width, height) => width <= longSide && height <= longSide
        ? ui.TargetImageSize(width: width, height: height)
        : width >= height
        ? ui.TargetImageSize(width: longSide)
        : ui.TargetImageSize(height: longSide),
  );
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

/// Turns a picked photo into a [PhotoQuery].
@lazySingleton
class PhotoSearchService {
  PhotoSearchService([
    @ignoreParam Future<Uint8List?> Function()? pick,
    @ignoreParam Future<Uint8List> Function(Uint8List png)? toJpeg,
    @ignoreParam FirebaseFunctions? functions,
  ]) : _pick = pick ?? _pickFromGallery,
       _toJpeg = toJpeg ?? _jpegOf,
       _functions = functions;

  final Future<Uint8List?> Function() _pick;
  final Future<Uint8List> Function(Uint8List png) _toJpeg;
  final FirebaseFunctions? _functions;

  /// The bytes of a photo from the camera roll, or `null` when the user picks none.
  Future<Uint8List?> pick() => _pick();

  /// Reads the palette of [original] on the phone. For a [signedIn] user it also asks the `photoSearchLabels`
  /// callable for labels. A guest's photo never leaves the phone. Throws when [original] cannot be decoded.
  Future<PhotoQuery> queryFor(Uint8List original, {required bool signedIn}) async {
    final PreparedPhoto prepared = await preparePhoto(original);
    final Uint8List jpeg = await _toJpeg(prepared.png);
    final (List<PaletteShare> palette, PhotoLabels labels) = await (
      paletteOfPixelsInIsolate(prepared.sample),
      signedIn
          ? _labelsFor(jpeg)
          : Future<PhotoLabels>.value((status: PhotoLabelsStatus.guest, labels: const <String>[], category: null)),
    ).wait;
    return PhotoQuery(
      preview: jpeg,
      palette: palette,
      labels: labels.labels,
      category: labels.category,
      labelsStatus: labels.status,
    );
  }

  Future<PhotoLabels> _labelsFor(Uint8List jpeg) async {
    const PhotoLabels none = (status: PhotoLabelsStatus.unavailable, labels: <String>[], category: null);
    try {
      final HttpsCallableResult<Object?> result = await (_functions ?? appFunctions)
          .httpsCallable('photoSearchLabels', options: HttpsCallableOptions(timeout: const Duration(seconds: 20)))
          .call<Object?>(<String, Object>{'image': base64Encode(jpeg), 'requestId': AnalyticsCorrelation.newId()});
      final Object? data = result.data;
      if (data is! Map) return none;
      final Object? labels = data['labels'];
      final Object? category = data['category'];
      return (
        status: PhotoLabelsStatus.found,
        labels: labels is List ? labels.whereType<String>().take(5).toList(growable: false) : const <String>[],
        category: category is String && category.isNotEmpty ? category : null,
      );
    } on FirebaseFunctionsException catch (error) {
      logger.w('[PhotoSearch] labels call failed: ${error.code}');
      return switch (error.code) {
        'resource-exhausted' => (status: PhotoLabelsStatus.capped, labels: const <String>[], category: null),
        'unauthenticated' => (status: PhotoLabelsStatus.guest, labels: const <String>[], category: null),
        _ => none,
      };
    } catch (error) {
      logger.w('[PhotoSearch] labels call failed (${error.runtimeType})');
      return none;
    }
  }

  static Future<Uint8List?> _pickFromGallery() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      requestFullMetadata: false,
    );
    return file?.readAsBytes();
  }

  /// The input is a metadata-free PNG, so the JPEG has no metadata either.
  static Future<Uint8List> _jpegOf(Uint8List png) => FlutterImageCompress.compressWithList(
    png,
    minWidth: photoUploadSize,
    minHeight: photoUploadSize,
    quality: 85,
    autoCorrectionAngle: false,
  );
}
