import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_wall_entity.freezed.dart';

@freezed
abstract class ProfileWallEntity with _$ProfileWallEntity {
  const factory ProfileWallEntity({
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
  }) = _ProfileWallEntity;
}
