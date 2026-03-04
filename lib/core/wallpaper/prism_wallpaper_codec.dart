import 'package:Prism/core/firestore/firestore_codec.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

class PrismWallpaperCodec implements FirestoreCodec<PrismWallpaper> {
  const PrismWallpaperCodec();

  @override
  PrismWallpaper decode(JsonMap data, String docId) {
    final String id = parseString(firstPresent(data, <String>['id', '__docId']) ?? docId, fallback: docId);
    final String fullUrl = parseString(firstPresent(data, <String>['wallpaper_url', 'url']));
    final String thumbnailUrl = parseString(
      firstPresent(data, <String>['wallpaper_thumb', 'thumb', 'thumbnailUrl']) ?? fullUrl,
    );
    final WallpaperSource source = WallpaperSourceX.fromWire(
      firstPresent(data, <String>['wallpaper_provider', 'provider', 'source']),
    );
    final String? resolution = parseString(data['resolution']) == '' ? null : parseString(data['resolution']);
    final int? sizeBytes = parseInt(firstPresent(data, <String>['file_size', 'fileSize', 'sizeBytes']));
    final DateTime? createdAt = parseDateTime(data['createdAt']);

    final Object? collectionsRaw = data['collections'];
    final List<String>? collections = collectionsRaw != null ? parseStringList(collectionsRaw) : null;
    final Object? tagsRaw = data['tags'];
    final List<String>? tags = tagsRaw != null ? parseStringList(tagsRaw) : null;

    final Object? reviewRaw = data['review'];
    bool? review;
    if (reviewRaw is bool) {
      review = reviewRaw;
    } else if (reviewRaw != null) {
      review = reviewRaw.toString().toLowerCase() == 'true';
    }

    JsonMap? aiMetadata;
    final Object? aiRaw = data['aiMetadata'] ?? data['ai_metadata'];
    if (aiRaw is Map) {
      aiMetadata = <String, Object?>{};
      for (final MapEntry<Object?, Object?> e in aiRaw.entries) {
        aiMetadata[e.key.toString()] = e.value;
      }
    }

    final WallpaperCore core = WallpaperCore(
      id: id,
      source: source == WallpaperSource.unknown ? WallpaperSource.prism : source,
      fullUrl: fullUrl,
      thumbnailUrl: thumbnailUrl,
      resolution: resolution,
      sizeBytes: sizeBytes,
      authorName: parseString(data['by']) == '' ? null : parseString(data['by']),
      authorEmail: parseString(data['email']) == '' ? null : parseString(data['email']),
      authorPhoto: parseString(data['userPhoto']) == '' ? null : parseString(data['userPhoto']),
      category: parseString(data['desc']) == '' ? null : parseString(data['desc']),
      createdAt: createdAt,
    );

    return PrismWallpaper(core: core, collections: collections, review: review, tags: tags, aiMetadata: aiMetadata);
  }

  @override
  JsonMap encode(PrismWallpaper value) {
    return <String, Object?>{
      'id': value.id,
      'wallpaper_url': value.fullUrl,
      'wallpaper_thumb': value.thumbnailUrl,
      'wallpaper_provider': value.source.legacyProviderString,
      if (value.core.resolution != null) 'resolution': value.core.resolution,
      if (value.core.sizeBytes != null) 'file_size': value.core.sizeBytes,
      if (value.collections != null) 'collections': value.collections,
      if (value.review != null) 'review': value.review,
      if (value.tags != null) 'tags': value.tags,
      if (value.core.createdAt != null) 'createdAt': value.core.createdAt!.toIso8601String(),
      if (value.aiMetadata != null) 'aiMetadata': value.aiMetadata,
    };
  }
}
