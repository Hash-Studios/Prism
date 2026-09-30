import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'setup_entity.freezed.dart';

@freezed
abstract class SetupEntity with _$SetupEntity {
  const factory SetupEntity({
    required String id,
    @Default('') String by,
    @Default('') String icon,
    @Default('') String iconUrl,
    DateTime? createdAt,
    @Default('') String desc,
    @Default('') String email,
    required String image,
    @Default('') String name,
    @Default('') String userPhoto,
    @Default('') String wallId,
    WallpaperSource? source,
    @Default('') String wallpaperThumb,
    @Default('') String wallpaperUrl,
    @Default('') String widget,
    @Default('') String widget2,
    @Default('') String widgetUrl,
    @Default('') String widgetUrl2,
    @Default('') String link,
    @Default(false) bool review,
    @Default('') String resolution,
    @Default('') String size,

    /// Firestore document id in [setups] for UGC reporting.
    @Default('') String firestoreDocumentId,
  }) = _SetupEntity;
}
