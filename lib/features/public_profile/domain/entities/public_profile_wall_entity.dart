import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_profile_wall_entity.freezed.dart';

@freezed
abstract class PublicProfileWallEntity with _$PublicProfileWallEntity {
  const factory PublicProfileWallEntity({
    required String id,
    String? by,
    String? desc,
    String? size,
    String? resolution,
    String? email,
    WallpaperSource? source,
    String? wallpaperThumb,
    required String wallpaperUrl,
    List<String>? collections,
    DateTime? createdAt,
    @Default(false) bool review,
  }) = _PublicProfileWallEntity;
}
