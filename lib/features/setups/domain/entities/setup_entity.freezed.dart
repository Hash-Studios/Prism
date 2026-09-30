// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'setup_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SetupEntity {

 String get id; String get by; String get icon; String get iconUrl; DateTime? get createdAt; String get desc; String get email; String get image; String get name; String get userPhoto; String get wallId; WallpaperSource? get source; String get wallpaperThumb; String get wallpaperUrl; String get widget; String get widget2; String get widgetUrl; String get widgetUrl2; String get link; bool get review; String get resolution; String get size;/// Firestore document id in [setups] for UGC reporting.
 String get firestoreDocumentId;
/// Create a copy of SetupEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SetupEntityCopyWith<SetupEntity> get copyWith => _$SetupEntityCopyWithImpl<SetupEntity>(this as SetupEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SetupEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.by, by) || other.by == by)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.desc, desc) || other.desc == desc)&&(identical(other.email, email) || other.email == email)&&(identical(other.image, image) || other.image == image)&&(identical(other.name, name) || other.name == name)&&(identical(other.userPhoto, userPhoto) || other.userPhoto == userPhoto)&&(identical(other.wallId, wallId) || other.wallId == wallId)&&(identical(other.source, source) || other.source == source)&&(identical(other.wallpaperThumb, wallpaperThumb) || other.wallpaperThumb == wallpaperThumb)&&(identical(other.wallpaperUrl, wallpaperUrl) || other.wallpaperUrl == wallpaperUrl)&&(identical(other.widget, widget) || other.widget == widget)&&(identical(other.widget2, widget2) || other.widget2 == widget2)&&(identical(other.widgetUrl, widgetUrl) || other.widgetUrl == widgetUrl)&&(identical(other.widgetUrl2, widgetUrl2) || other.widgetUrl2 == widgetUrl2)&&(identical(other.link, link) || other.link == link)&&(identical(other.review, review) || other.review == review)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.size, size) || other.size == size)&&(identical(other.firestoreDocumentId, firestoreDocumentId) || other.firestoreDocumentId == firestoreDocumentId));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,by,icon,iconUrl,createdAt,desc,email,image,name,userPhoto,wallId,source,wallpaperThumb,wallpaperUrl,widget,widget2,widgetUrl,widgetUrl2,link,review,resolution,size,firestoreDocumentId]);

@override
String toString() {
  return 'SetupEntity(id: $id, by: $by, icon: $icon, iconUrl: $iconUrl, createdAt: $createdAt, desc: $desc, email: $email, image: $image, name: $name, userPhoto: $userPhoto, wallId: $wallId, source: $source, wallpaperThumb: $wallpaperThumb, wallpaperUrl: $wallpaperUrl, widget: $widget, widget2: $widget2, widgetUrl: $widgetUrl, widgetUrl2: $widgetUrl2, link: $link, review: $review, resolution: $resolution, size: $size, firestoreDocumentId: $firestoreDocumentId)';
}


}

/// @nodoc
abstract mixin class $SetupEntityCopyWith<$Res>  {
  factory $SetupEntityCopyWith(SetupEntity value, $Res Function(SetupEntity) _then) = _$SetupEntityCopyWithImpl;
@useResult
$Res call({
 String id, String by, String icon, String iconUrl, DateTime? createdAt, String desc, String email, String image, String name, String userPhoto, String wallId, WallpaperSource? source, String wallpaperThumb, String wallpaperUrl, String widget, String widget2, String widgetUrl, String widgetUrl2, String link, bool review, String resolution, String size, String firestoreDocumentId
});




}
/// @nodoc
class _$SetupEntityCopyWithImpl<$Res>
    implements $SetupEntityCopyWith<$Res> {
  _$SetupEntityCopyWithImpl(this._self, this._then);

  final SetupEntity _self;
  final $Res Function(SetupEntity) _then;

/// Create a copy of SetupEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? by = null,Object? icon = null,Object? iconUrl = null,Object? createdAt = freezed,Object? desc = null,Object? email = null,Object? image = null,Object? name = null,Object? userPhoto = null,Object? wallId = null,Object? source = freezed,Object? wallpaperThumb = null,Object? wallpaperUrl = null,Object? widget = null,Object? widget2 = null,Object? widgetUrl = null,Object? widgetUrl2 = null,Object? link = null,Object? review = null,Object? resolution = null,Object? size = null,Object? firestoreDocumentId = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,by: null == by ? _self.by : by // ignore: cast_nullable_to_non_nullable
as String,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,iconUrl: null == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,desc: null == desc ? _self.desc : desc // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,image: null == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,userPhoto: null == userPhoto ? _self.userPhoto : userPhoto // ignore: cast_nullable_to_non_nullable
as String,wallId: null == wallId ? _self.wallId : wallId // ignore: cast_nullable_to_non_nullable
as String,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as WallpaperSource?,wallpaperThumb: null == wallpaperThumb ? _self.wallpaperThumb : wallpaperThumb // ignore: cast_nullable_to_non_nullable
as String,wallpaperUrl: null == wallpaperUrl ? _self.wallpaperUrl : wallpaperUrl // ignore: cast_nullable_to_non_nullable
as String,widget: null == widget ? _self.widget : widget // ignore: cast_nullable_to_non_nullable
as String,widget2: null == widget2 ? _self.widget2 : widget2 // ignore: cast_nullable_to_non_nullable
as String,widgetUrl: null == widgetUrl ? _self.widgetUrl : widgetUrl // ignore: cast_nullable_to_non_nullable
as String,widgetUrl2: null == widgetUrl2 ? _self.widgetUrl2 : widgetUrl2 // ignore: cast_nullable_to_non_nullable
as String,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,review: null == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as bool,resolution: null == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as String,firestoreDocumentId: null == firestoreDocumentId ? _self.firestoreDocumentId : firestoreDocumentId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SetupEntity].
extension SetupEntityPatterns on SetupEntity {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SetupEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SetupEntity() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SetupEntity value)  $default,){
final _that = this;
switch (_that) {
case _SetupEntity():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SetupEntity value)?  $default,){
final _that = this;
switch (_that) {
case _SetupEntity() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String by,  String icon,  String iconUrl,  DateTime? createdAt,  String desc,  String email,  String image,  String name,  String userPhoto,  String wallId,  WallpaperSource? source,  String wallpaperThumb,  String wallpaperUrl,  String widget,  String widget2,  String widgetUrl,  String widgetUrl2,  String link,  bool review,  String resolution,  String size,  String firestoreDocumentId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SetupEntity() when $default != null:
return $default(_that.id,_that.by,_that.icon,_that.iconUrl,_that.createdAt,_that.desc,_that.email,_that.image,_that.name,_that.userPhoto,_that.wallId,_that.source,_that.wallpaperThumb,_that.wallpaperUrl,_that.widget,_that.widget2,_that.widgetUrl,_that.widgetUrl2,_that.link,_that.review,_that.resolution,_that.size,_that.firestoreDocumentId);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String by,  String icon,  String iconUrl,  DateTime? createdAt,  String desc,  String email,  String image,  String name,  String userPhoto,  String wallId,  WallpaperSource? source,  String wallpaperThumb,  String wallpaperUrl,  String widget,  String widget2,  String widgetUrl,  String widgetUrl2,  String link,  bool review,  String resolution,  String size,  String firestoreDocumentId)  $default,) {final _that = this;
switch (_that) {
case _SetupEntity():
return $default(_that.id,_that.by,_that.icon,_that.iconUrl,_that.createdAt,_that.desc,_that.email,_that.image,_that.name,_that.userPhoto,_that.wallId,_that.source,_that.wallpaperThumb,_that.wallpaperUrl,_that.widget,_that.widget2,_that.widgetUrl,_that.widgetUrl2,_that.link,_that.review,_that.resolution,_that.size,_that.firestoreDocumentId);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String by,  String icon,  String iconUrl,  DateTime? createdAt,  String desc,  String email,  String image,  String name,  String userPhoto,  String wallId,  WallpaperSource? source,  String wallpaperThumb,  String wallpaperUrl,  String widget,  String widget2,  String widgetUrl,  String widgetUrl2,  String link,  bool review,  String resolution,  String size,  String firestoreDocumentId)?  $default,) {final _that = this;
switch (_that) {
case _SetupEntity() when $default != null:
return $default(_that.id,_that.by,_that.icon,_that.iconUrl,_that.createdAt,_that.desc,_that.email,_that.image,_that.name,_that.userPhoto,_that.wallId,_that.source,_that.wallpaperThumb,_that.wallpaperUrl,_that.widget,_that.widget2,_that.widgetUrl,_that.widgetUrl2,_that.link,_that.review,_that.resolution,_that.size,_that.firestoreDocumentId);case _:
  return null;

}
}

}

/// @nodoc


class _SetupEntity implements SetupEntity {
  const _SetupEntity({required this.id, this.by = '', this.icon = '', this.iconUrl = '', this.createdAt, this.desc = '', this.email = '', required this.image, this.name = '', this.userPhoto = '', this.wallId = '', this.source, this.wallpaperThumb = '', this.wallpaperUrl = '', this.widget = '', this.widget2 = '', this.widgetUrl = '', this.widgetUrl2 = '', this.link = '', this.review = false, this.resolution = '', this.size = '', this.firestoreDocumentId = ''});
  

@override final  String id;
@override@JsonKey() final  String by;
@override@JsonKey() final  String icon;
@override@JsonKey() final  String iconUrl;
@override final  DateTime? createdAt;
@override@JsonKey() final  String desc;
@override@JsonKey() final  String email;
@override final  String image;
@override@JsonKey() final  String name;
@override@JsonKey() final  String userPhoto;
@override@JsonKey() final  String wallId;
@override final  WallpaperSource? source;
@override@JsonKey() final  String wallpaperThumb;
@override@JsonKey() final  String wallpaperUrl;
@override@JsonKey() final  String widget;
@override@JsonKey() final  String widget2;
@override@JsonKey() final  String widgetUrl;
@override@JsonKey() final  String widgetUrl2;
@override@JsonKey() final  String link;
@override@JsonKey() final  bool review;
@override@JsonKey() final  String resolution;
@override@JsonKey() final  String size;
/// Firestore document id in [setups] for UGC reporting.
@override@JsonKey() final  String firestoreDocumentId;

/// Create a copy of SetupEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SetupEntityCopyWith<_SetupEntity> get copyWith => __$SetupEntityCopyWithImpl<_SetupEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SetupEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.by, by) || other.by == by)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.desc, desc) || other.desc == desc)&&(identical(other.email, email) || other.email == email)&&(identical(other.image, image) || other.image == image)&&(identical(other.name, name) || other.name == name)&&(identical(other.userPhoto, userPhoto) || other.userPhoto == userPhoto)&&(identical(other.wallId, wallId) || other.wallId == wallId)&&(identical(other.source, source) || other.source == source)&&(identical(other.wallpaperThumb, wallpaperThumb) || other.wallpaperThumb == wallpaperThumb)&&(identical(other.wallpaperUrl, wallpaperUrl) || other.wallpaperUrl == wallpaperUrl)&&(identical(other.widget, widget) || other.widget == widget)&&(identical(other.widget2, widget2) || other.widget2 == widget2)&&(identical(other.widgetUrl, widgetUrl) || other.widgetUrl == widgetUrl)&&(identical(other.widgetUrl2, widgetUrl2) || other.widgetUrl2 == widgetUrl2)&&(identical(other.link, link) || other.link == link)&&(identical(other.review, review) || other.review == review)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.size, size) || other.size == size)&&(identical(other.firestoreDocumentId, firestoreDocumentId) || other.firestoreDocumentId == firestoreDocumentId));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,by,icon,iconUrl,createdAt,desc,email,image,name,userPhoto,wallId,source,wallpaperThumb,wallpaperUrl,widget,widget2,widgetUrl,widgetUrl2,link,review,resolution,size,firestoreDocumentId]);

@override
String toString() {
  return 'SetupEntity(id: $id, by: $by, icon: $icon, iconUrl: $iconUrl, createdAt: $createdAt, desc: $desc, email: $email, image: $image, name: $name, userPhoto: $userPhoto, wallId: $wallId, source: $source, wallpaperThumb: $wallpaperThumb, wallpaperUrl: $wallpaperUrl, widget: $widget, widget2: $widget2, widgetUrl: $widgetUrl, widgetUrl2: $widgetUrl2, link: $link, review: $review, resolution: $resolution, size: $size, firestoreDocumentId: $firestoreDocumentId)';
}


}

/// @nodoc
abstract mixin class _$SetupEntityCopyWith<$Res> implements $SetupEntityCopyWith<$Res> {
  factory _$SetupEntityCopyWith(_SetupEntity value, $Res Function(_SetupEntity) _then) = __$SetupEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String by, String icon, String iconUrl, DateTime? createdAt, String desc, String email, String image, String name, String userPhoto, String wallId, WallpaperSource? source, String wallpaperThumb, String wallpaperUrl, String widget, String widget2, String widgetUrl, String widgetUrl2, String link, bool review, String resolution, String size, String firestoreDocumentId
});




}
/// @nodoc
class __$SetupEntityCopyWithImpl<$Res>
    implements _$SetupEntityCopyWith<$Res> {
  __$SetupEntityCopyWithImpl(this._self, this._then);

  final _SetupEntity _self;
  final $Res Function(_SetupEntity) _then;

/// Create a copy of SetupEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? by = null,Object? icon = null,Object? iconUrl = null,Object? createdAt = freezed,Object? desc = null,Object? email = null,Object? image = null,Object? name = null,Object? userPhoto = null,Object? wallId = null,Object? source = freezed,Object? wallpaperThumb = null,Object? wallpaperUrl = null,Object? widget = null,Object? widget2 = null,Object? widgetUrl = null,Object? widgetUrl2 = null,Object? link = null,Object? review = null,Object? resolution = null,Object? size = null,Object? firestoreDocumentId = null,}) {
  return _then(_SetupEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,by: null == by ? _self.by : by // ignore: cast_nullable_to_non_nullable
as String,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,iconUrl: null == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,desc: null == desc ? _self.desc : desc // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,image: null == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,userPhoto: null == userPhoto ? _self.userPhoto : userPhoto // ignore: cast_nullable_to_non_nullable
as String,wallId: null == wallId ? _self.wallId : wallId // ignore: cast_nullable_to_non_nullable
as String,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as WallpaperSource?,wallpaperThumb: null == wallpaperThumb ? _self.wallpaperThumb : wallpaperThumb // ignore: cast_nullable_to_non_nullable
as String,wallpaperUrl: null == wallpaperUrl ? _self.wallpaperUrl : wallpaperUrl // ignore: cast_nullable_to_non_nullable
as String,widget: null == widget ? _self.widget : widget // ignore: cast_nullable_to_non_nullable
as String,widget2: null == widget2 ? _self.widget2 : widget2 // ignore: cast_nullable_to_non_nullable
as String,widgetUrl: null == widgetUrl ? _self.widgetUrl : widgetUrl // ignore: cast_nullable_to_non_nullable
as String,widgetUrl2: null == widgetUrl2 ? _self.widgetUrl2 : widgetUrl2 // ignore: cast_nullable_to_non_nullable
as String,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,review: null == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as bool,resolution: null == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as String,firestoreDocumentId: null == firestoreDocumentId ? _self.firestoreDocumentId : firestoreDocumentId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
