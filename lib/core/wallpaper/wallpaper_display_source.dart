import 'dart:io';
import 'dart:math' as math;

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/data/offline/bundled_wallpapers.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/wallpaper_detail_rules.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Longest side, in pixels, that a large surface decodes. A 4K original stays whole; an 8K one is halved.
const int maxWallpaperDecodeSide = 4096;

/// What a large wallpaper surface may draw: the [thumbnail] first, then [full].
///
/// [full] is a network URL, an `assets/` path, a file path, or empty when only the thumbnail may show. For a Prism
/// wall it is never the gated original: it is the server's display derivative, and the original shows only when the
/// signed-in user already holds it on this device (see [wallpaperOfflineCopy]).
@immutable
class WallpaperDisplaySource {
  const WallpaperDisplaySource({required this.thumbnail, required this.full, this.id, this.source, this.pixelSize});

  /// The best picture the user may see of [entity].
  factory WallpaperDisplaySource.of(FeedItemEntity entity, {String? projectId}) => WallpaperDisplaySource.forWall(
    id: entity.id,
    source: entity.source,
    thumbnail: entity.thumbnailUrl,
    fullUrl: entity.fullUrl,
    withheld: entity.maybeWhen(prism: (_, wall) => wall.isStreakExclusive, orElse: () => false),
    pixelSize: wallpaperPixelSize(entity.wallpaperCore),
    projectId: projectId,
  );

  /// The same rules as [WallpaperDisplaySource.of], from the fields a route carries.
  ///
  /// A Prism wall gets the preview derivative, or only its thumbnail when it is [withheld] (streak-exclusive) or
  /// the preview cannot be addressed. A bundled starter uses its file. Wallhaven and Pexels use their public original.
  /// A [fullUrl] that is not a network URL is never read as a path here: a feed field must not open a local file.
  factory WallpaperDisplaySource.forWall({
    required String id,
    required WallpaperSource source,
    required String thumbnail,
    String fullUrl = '',
    bool withheld = false,
    Size? pixelSize,
    String? projectId,
  }) {
    final String thumb = thumbnail.trim();
    final String original = fullUrl.trim();
    final String full;
    if (BundledWallpapers.isStarterIdentity(id, source)) {
      full = original;
    } else if (source == WallpaperSource.prism) {
      full = withheld ? '' : prismWallpaperPreviewUrl(id: id, thumbnail: thumb, projectId: projectId ?? _projectId());
    } else {
      full = isValidNetworkUrl(original) ? original : '';
    }
    return WallpaperDisplaySource(
      thumbnail: isValidNetworkUrl(thumb) ? thumb : '',
      full: full,
      id: id,
      source: source,
      pixelSize: pixelSize,
    );
  }

  final String thumbnail;
  final String full;
  final String? id;
  final WallpaperSource? source;

  /// The wall's own size in pixels, when known. It picks the side the decode follows.
  final Size? pixelSize;

  /// [full], or [thumbnail] when no full image may show. For a route that takes one link.
  String get bestLink => full.isNotEmpty ? full : thumbnail;

  @override
  bool operator ==(Object other) =>
      other is WallpaperDisplaySource &&
      other.thumbnail == thumbnail &&
      other.full == full &&
      other.id == id &&
      other.source == source &&
      other.pixelSize == pixelSize;

  @override
  int get hashCode => Object.hash(thumbnail, full, id, source, pixelSize);
}

String? _projectId() => Firebase.apps.isEmpty ? null : Firebase.app().options.projectId;

/// The server's display derivative of a Prism wall: at most 2560 px, never the original bytes. Empty when it cannot be
/// addressed, so the caller keeps the thumbnail.
String prismWallpaperPreviewUrl({required String id, required String thumbnail, required String? projectId}) {
  final String thumb = thumbnail.trim();
  if (id.isEmpty || thumb.isEmpty || projectId == null || projectId.isEmpty) return '';
  return Uri.https('us-central1-$projectId.cloudfunctions.net', '/wallpaperPreview', {
    'id': id,
    'thumb': thumb,
  }).toString();
}

/// [provider] resized for a wall drawn with [BoxFit.cover] in [box] logical pixels: enough pixels to cover the box,
/// at most [maxWallpaperDecodeSide] on the long side, and never more than the wall has. With an unknown [pixelSize]
/// the wall decodes at its own size within that cap, so a wide wall still covers a tall box.
ImageProvider sizedWallpaperImage(ImageProvider provider, Size box, double devicePixelRatio, Size? pixelSize) {
  final double boxWidth = math.max(1, box.width * devicePixelRatio);
  final double boxHeight = math.max(1, box.height * devicePixelRatio);
  if (pixelSize == null || pixelSize.isEmpty || !boxWidth.isFinite || !boxHeight.isFinite) {
    return ResizeImage(
      provider,
      width: maxWallpaperDecodeSide,
      height: maxWallpaperDecodeSide,
      policy: ResizeImagePolicy.fit,
    );
  }
  final double cover = math.max(boxWidth / pixelSize.width, boxHeight / pixelSize.height);
  final double scale = math.min(1, math.min(cover, maxWallpaperDecodeSide / pixelSize.longestSide));
  // One side only, so the decode keeps the wall's shape.
  return pixelSize.width / pixelSize.height > boxWidth / boxHeight
      ? ResizeImage(provider, height: math.max(1, (pixelSize.height * scale).round()))
      : ResizeImage(provider, width: math.max(1, (pixelSize.width * scale).round()));
}

/// The copy of [display] already on this device, or null: for a Prism wall the original the signed-in user downloaded,
/// then a kept copy of [WallpaperDisplaySource.full] itself. Never touches the network.
Future<File?> wallpaperOfflineCopy(WallpaperDisplaySource display) async {
  final String? id = display.id;
  final WallpaperSource? source = display.source;
  if (id == null || id.isEmpty || source == null || !isValidNetworkUrl(display.full)) return null;
  try {
    if (source == WallpaperSource.prism && getIt.isRegistered<DownloadedWallIndex>()) {
      final File? original = await getIt<DownloadedWallIndex>().localFileForIdentity(id: id, source: source);
      final File? verified = original == null ? null : await OfflineAssetStore.instance.lookup(original.path);
      if (verified != null) return verified;
    }
    return await WallpaperService.resolveToLocalFile(
      display.full,
      allowNetwork: false,
      wallpaperId: id,
      wallpaperSource: source,
    );
  } catch (_) {
    return null;
  }
}
