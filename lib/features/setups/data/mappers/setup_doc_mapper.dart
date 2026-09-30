import 'package:Prism/core/firestore/dtos/setup_doc_dto.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';

extension SetupDocDtoX on SetupDocDto {
  SetupEntity toSetupEntity(String docId) {
    return SetupEntity(
      id: id.isNotEmpty ? id : docId,
      by: by,
      icon: icon,
      iconUrl: iconUrl,
      createdAt: createdAt,
      desc: desc,
      email: email,
      image: image,
      name: name,
      userPhoto: userPhoto,
      wallId: wallId,
      source: WallpaperSourceX.fromWire(wallpaperProvider),
      wallpaperThumb: normalizeWallpaperThumbnailUrl(wallpaperThumb),
      wallpaperUrl: wallpaperUrl,
      widget: widget,
      widget2: widget2,
      widgetUrl: widgetUrl,
      widgetUrl2: widgetUrl2,
      link: link,
      review: review,
      resolution: resolution,
      size: size,
      firestoreDocumentId: docId,
    );
  }
}

extension SetupEntityFirestoreX on SetupEntity {
  Map<String, dynamic> toFirestoreMap() {
    return <String, dynamic>{
      'id': id,
      'by': by,
      'icon': icon,
      'icon_url': iconUrl,
      'created_at': createdAt ?? DateTime.now().toUtc(),
      'desc': desc,
      'email': email,
      'image': image,
      'name': name,
      'userPhoto': userPhoto,
      'wall_id': wallId,
      'wallpaper_provider': source?.legacyProviderString,
      'wallpaper_thumb': wallpaperThumb,
      'wallpaper_url': wallpaperUrl,
      'widget': widget,
      'widget2': widget2,
      'widget_url': widgetUrl,
      'widget_url2': widgetUrl2,
      'link': link,
      'review': review,
      'resolution': resolution,
      'size': size,
    };
  }
}
