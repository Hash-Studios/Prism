// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setup_doc_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SetupDocDto _$SetupDocDtoFromJson(Map<String, dynamic> json) => _SetupDocDto(
  id: json['id'] == null ? '' : const FirestoreStringConverter().fromJson(json['id']),
  by: json['by'] == null ? '' : const FirestoreStringConverter().fromJson(json['by']),
  icon: json['icon'] == null ? '' : const FirestoreStringConverter().fromJson(json['icon']),
  iconUrl: json['icon_url'] == null ? '' : const FirestoreStringConverter().fromJson(json['icon_url']),
  createdAt: const FirestoreDateTimeConverter().fromJson(json['created_at']),
  desc: json['desc'] == null ? '' : const FirestoreStringConverter().fromJson(json['desc']),
  email: json['email'] == null ? '' : const FirestoreStringConverter().fromJson(json['email']),
  image: json['image'] == null ? '' : const FirestoreStringConverter().fromJson(json['image']),
  name: json['name'] == null ? '' : const FirestoreStringConverter().fromJson(json['name']),
  userPhoto: json['userPhoto'] == null ? '' : const FirestoreStringConverter().fromJson(json['userPhoto']),
  wallId: json['wall_id'] == null ? '' : const FirestoreStringConverter().fromJson(json['wall_id']),
  wallpaperProvider: json['wallpaper_provider'] == null
      ? ''
      : const FirestoreStringConverter().fromJson(json['wallpaper_provider']),
  wallpaperThumb: json['wallpaper_thumb'] == null
      ? ''
      : const FirestoreStringConverter().fromJson(json['wallpaper_thumb']),
  wallpaperUrl: json['wallpaper_url'] == null ? '' : const FirestoreStringConverter().fromJson(json['wallpaper_url']),
  widget: json['widget'] == null ? '' : const FirestoreStringConverter().fromJson(json['widget']),
  widget2: json['widget2'] == null ? '' : const FirestoreStringConverter().fromJson(json['widget2']),
  widgetUrl: json['widget_url'] == null ? '' : const FirestoreStringConverter().fromJson(json['widget_url']),
  widgetUrl2: json['widget_url2'] == null ? '' : const FirestoreStringConverter().fromJson(json['widget_url2']),
  link: json['link'] == null ? '' : const FirestoreStringConverter().fromJson(json['link']),
  review: json['review'] as bool? ?? false,
  resolution: json['resolution'] == null ? '' : const FirestoreStringConverter().fromJson(json['resolution']),
  size: json['size'] == null ? '' : const FirestoreStringConverter().fromJson(json['size']),
);

Map<String, dynamic> _$SetupDocDtoToJson(_SetupDocDto instance) => <String, dynamic>{
  'id': const FirestoreStringConverter().toJson(instance.id),
  'by': const FirestoreStringConverter().toJson(instance.by),
  'icon': const FirestoreStringConverter().toJson(instance.icon),
  'icon_url': const FirestoreStringConverter().toJson(instance.iconUrl),
  'created_at': const FirestoreDateTimeConverter().toJson(instance.createdAt),
  'desc': const FirestoreStringConverter().toJson(instance.desc),
  'email': const FirestoreStringConverter().toJson(instance.email),
  'image': const FirestoreStringConverter().toJson(instance.image),
  'name': const FirestoreStringConverter().toJson(instance.name),
  'userPhoto': const FirestoreStringConverter().toJson(instance.userPhoto),
  'wall_id': const FirestoreStringConverter().toJson(instance.wallId),
  'wallpaper_provider': const FirestoreStringConverter().toJson(instance.wallpaperProvider),
  'wallpaper_thumb': const FirestoreStringConverter().toJson(instance.wallpaperThumb),
  'wallpaper_url': const FirestoreStringConverter().toJson(instance.wallpaperUrl),
  'widget': const FirestoreStringConverter().toJson(instance.widget),
  'widget2': const FirestoreStringConverter().toJson(instance.widget2),
  'widget_url': const FirestoreStringConverter().toJson(instance.widgetUrl),
  'widget_url2': const FirestoreStringConverter().toJson(instance.widgetUrl2),
  'link': const FirestoreStringConverter().toJson(instance.link),
  'review': instance.review,
  'resolution': const FirestoreStringConverter().toJson(instance.resolution),
  'size': const FirestoreStringConverter().toJson(instance.size),
};
