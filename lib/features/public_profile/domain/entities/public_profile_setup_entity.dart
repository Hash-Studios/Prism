import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_profile_setup_entity.freezed.dart';

@freezed
abstract class PublicProfileSetupEntity with _$PublicProfileSetupEntity {
  const factory PublicProfileSetupEntity({
    required String id,
    String? by,
    String? icon,
    String? iconUrl,
    DateTime? createdAt,
    String? desc,
    String? email,
    required String image,
    String? name,
    String? userPhoto,
    String? wallId,
    WallpaperSource? source,
    String? wallpaperThumb,
    String? wallpaperUrl,
    String? widget,
    String? widget2,
    String? widgetUrl,
    String? widgetUrl2,
    String? link,
    @Default(false) bool review,
    String? resolution,
    String? size,
  }) = _PublicProfileSetupEntity;
}
