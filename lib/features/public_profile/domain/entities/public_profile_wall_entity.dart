import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/wallpaper/wall_spatial.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_profile_wall_entity.freezed.dart';

@freezed
abstract class PublicProfileWallEntity with _$PublicProfileWallEntity {
  const factory PublicProfileWallEntity({
    required String id,

    /// The Firestore document id. It can differ from [id], the wall's own id field.
    String? firestoreDocumentId,
    String? by,
    String? desc,
    String? category,
    String? size,
    String? resolution,
    String? email,
    String? creatorUid,
    WallpaperSource? source,
    String? wallpaperThumb,
    required String wallpaperUrl,
    List<String>? collections,
    DateTime? createdAt,
    @Default(false) bool review,
    WallDepthTier? depthTier,
    WallSpatial? spatial,
  }) = _PublicProfileWallEntity;

  const PublicProfileWallEntity._();

  FeedItemEntity toFeedItem() {
    final wallpaper = PrismWallpaper(
      core: WallpaperCore(
        id: id,
        source: source ?? WallpaperSource.prism,
        fullUrl: wallpaperUrl,
        thumbnailUrl: wallpaperThumb ?? wallpaperUrl,
        resolution: resolution,
        sizeBytes: size != null ? int.tryParse(size!) : null,
        authorName: by,
        authorEmail: email,
        authorUid: creatorUid,
        category: category?.trim().isEmpty == true ? null : category,
        createdAt: createdAt,
      ),
      collections: collections,
      firestoreDocumentId: firestoreDocumentId,
      review: review,
      depthTier: depthTier,
      spatial: spatial,
    );
    return PrismFeedItem(id: wallpaper.id, wallpaper: wallpaper);
  }
}
