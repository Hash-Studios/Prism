import 'package:Prism/features/favourite_setups/domain/entities/favourite_setup_entity.dart';
import 'package:Prism/features/profile_setups/domain/entities/profile_setup_entity.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_setup_entity.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';

extension SetupEntityToFavouriteSetupX on SetupEntity {
  FavouriteSetupEntity toFavouriteSetupEntity() {
    return FavouriteSetupEntity(
      id: id,
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
      source: source,
      wallpaperThumb: wallpaperThumb,
      wallpaperUrl: wallpaperUrl,
      widget: widget,
      widget2: widget2,
      widgetUrl: widgetUrl,
      widgetUrl2: widgetUrl2,
      link: link,
      review: review,
      resolution: resolution,
      size: size,
      firestoreDocumentId: firestoreDocumentId,
    );
  }
}

extension ProfileSetupEntityToFavouriteSetupX on ProfileSetupEntity {
  FavouriteSetupEntity toFavouriteSetupEntity() {
    return FavouriteSetupEntity(
      id: id,
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
      source: source,
      wallpaperThumb: wallpaperThumb,
      wallpaperUrl: wallpaperUrl,
      widget: widget,
      widget2: widget2,
      widgetUrl: widgetUrl,
      widgetUrl2: widgetUrl2,
      link: link,
      review: review,
      resolution: resolution,
      size: size,
      firestoreDocumentId: firestoreDocumentId,
    );
  }
}

extension PublicProfileSetupEntityToFavouriteSetupX on PublicProfileSetupEntity {
  FavouriteSetupEntity toFavouriteSetupEntity() {
    return FavouriteSetupEntity(
      id: id,
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
      source: source,
      wallpaperThumb: wallpaperThumb,
      wallpaperUrl: wallpaperUrl,
      widget: widget,
      widget2: widget2,
      widgetUrl: widgetUrl,
      widgetUrl2: widgetUrl2,
      link: link,
      review: review,
      resolution: resolution,
      size: size,
      firestoreDocumentId: firestoreDocumentId,
    );
  }
}
