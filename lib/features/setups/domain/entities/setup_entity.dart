import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'setup_entity.freezed.dart';

@freezed
abstract class SetupEntity with _$SetupEntity {
  const factory SetupEntity({
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

    /// Firestore document id in [setups] for UGC reporting.
    String? firestoreDocumentId,
  }) = _SetupEntity;
}
