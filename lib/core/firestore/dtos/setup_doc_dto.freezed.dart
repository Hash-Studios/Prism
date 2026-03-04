// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'setup_doc_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SetupDocDto {

@FirestoreStringConverter() String get id;@FirestoreStringConverter() String get by;@FirestoreStringConverter() String get icon;@JsonKey(name: 'icon_url')@FirestoreStringConverter() String get iconUrl;@JsonKey(name: 'created_at')@FirestoreDateTimeConverter() DateTime? get createdAt;@FirestoreStringConverter() String get desc;@FirestoreStringConverter() String get email;@FirestoreStringConverter() String get image;@FirestoreStringConverter() String get name;@FirestoreStringConverter() String get userPhoto;@JsonKey(name: 'wall_id')@FirestoreStringConverter() String get wallId;@JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter() String get wallpaperProvider;@JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter() String get wallpaperThumb;@JsonKey(name: 'wallpaper_url')@FirestoreStringConverter() String get wallpaperUrl;@FirestoreStringConverter() String get widget;@FirestoreStringConverter() String get widget2;@JsonKey(name: 'widget_url')@FirestoreStringConverter() String get widgetUrl;@JsonKey(name: 'widget_url2')@FirestoreStringConverter() String get widgetUrl2;@FirestoreStringConverter() String get link; bool get review;@FirestoreStringConverter() String get resolution;@FirestoreStringConverter() String get size;
/// Create a copy of SetupDocDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SetupDocDtoCopyWith<SetupDocDto> get copyWith => _$SetupDocDtoCopyWithImpl<SetupDocDto>(this as SetupDocDto, _$identity);

  /// Serializes this SetupDocDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SetupDocDto&&(identical(other.id, id) || other.id == id)&&(identical(other.by, by) || other.by == by)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.desc, desc) || other.desc == desc)&&(identical(other.email, email) || other.email == email)&&(identical(other.image, image) || other.image == image)&&(identical(other.name, name) || other.name == name)&&(identical(other.userPhoto, userPhoto) || other.userPhoto == userPhoto)&&(identical(other.wallId, wallId) || other.wallId == wallId)&&(identical(other.wallpaperProvider, wallpaperProvider) || other.wallpaperProvider == wallpaperProvider)&&(identical(other.wallpaperThumb, wallpaperThumb) || other.wallpaperThumb == wallpaperThumb)&&(identical(other.wallpaperUrl, wallpaperUrl) || other.wallpaperUrl == wallpaperUrl)&&(identical(other.widget, widget) || other.widget == widget)&&(identical(other.widget2, widget2) || other.widget2 == widget2)&&(identical(other.widgetUrl, widgetUrl) || other.widgetUrl == widgetUrl)&&(identical(other.widgetUrl2, widgetUrl2) || other.widgetUrl2 == widgetUrl2)&&(identical(other.link, link) || other.link == link)&&(identical(other.review, review) || other.review == review)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.size, size) || other.size == size));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,by,icon,iconUrl,createdAt,desc,email,image,name,userPhoto,wallId,wallpaperProvider,wallpaperThumb,wallpaperUrl,widget,widget2,widgetUrl,widgetUrl2,link,review,resolution,size]);

@override
String toString() {
  return 'SetupDocDto(id: $id, by: $by, icon: $icon, iconUrl: $iconUrl, createdAt: $createdAt, desc: $desc, email: $email, image: $image, name: $name, userPhoto: $userPhoto, wallId: $wallId, wallpaperProvider: $wallpaperProvider, wallpaperThumb: $wallpaperThumb, wallpaperUrl: $wallpaperUrl, widget: $widget, widget2: $widget2, widgetUrl: $widgetUrl, widgetUrl2: $widgetUrl2, link: $link, review: $review, resolution: $resolution, size: $size)';
}


}

/// @nodoc
abstract mixin class $SetupDocDtoCopyWith<$Res>  {
  factory $SetupDocDtoCopyWith(SetupDocDto value, $Res Function(SetupDocDto) _then) = _$SetupDocDtoCopyWithImpl;
@useResult
$Res call({
@FirestoreStringConverter() String id,@FirestoreStringConverter() String by,@FirestoreStringConverter() String icon,@JsonKey(name: 'icon_url')@FirestoreStringConverter() String iconUrl,@JsonKey(name: 'created_at')@FirestoreDateTimeConverter() DateTime? createdAt,@FirestoreStringConverter() String desc,@FirestoreStringConverter() String email,@FirestoreStringConverter() String image,@FirestoreStringConverter() String name,@FirestoreStringConverter() String userPhoto,@JsonKey(name: 'wall_id')@FirestoreStringConverter() String wallId,@JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter() String wallpaperProvider,@JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter() String wallpaperThumb,@JsonKey(name: 'wallpaper_url')@FirestoreStringConverter() String wallpaperUrl,@FirestoreStringConverter() String widget,@FirestoreStringConverter() String widget2,@JsonKey(name: 'widget_url')@FirestoreStringConverter() String widgetUrl,@JsonKey(name: 'widget_url2')@FirestoreStringConverter() String widgetUrl2,@FirestoreStringConverter() String link, bool review,@FirestoreStringConverter() String resolution,@FirestoreStringConverter() String size
});




}
/// @nodoc
class _$SetupDocDtoCopyWithImpl<$Res>
    implements $SetupDocDtoCopyWith<$Res> {
  _$SetupDocDtoCopyWithImpl(this._self, this._then);

  final SetupDocDto _self;
  final $Res Function(SetupDocDto) _then;

/// Create a copy of SetupDocDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? by = null,Object? icon = null,Object? iconUrl = null,Object? createdAt = freezed,Object? desc = null,Object? email = null,Object? image = null,Object? name = null,Object? userPhoto = null,Object? wallId = null,Object? wallpaperProvider = null,Object? wallpaperThumb = null,Object? wallpaperUrl = null,Object? widget = null,Object? widget2 = null,Object? widgetUrl = null,Object? widgetUrl2 = null,Object? link = null,Object? review = null,Object? resolution = null,Object? size = null,}) {
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
as String,wallpaperProvider: null == wallpaperProvider ? _self.wallpaperProvider : wallpaperProvider // ignore: cast_nullable_to_non_nullable
as String,wallpaperThumb: null == wallpaperThumb ? _self.wallpaperThumb : wallpaperThumb // ignore: cast_nullable_to_non_nullable
as String,wallpaperUrl: null == wallpaperUrl ? _self.wallpaperUrl : wallpaperUrl // ignore: cast_nullable_to_non_nullable
as String,widget: null == widget ? _self.widget : widget // ignore: cast_nullable_to_non_nullable
as String,widget2: null == widget2 ? _self.widget2 : widget2 // ignore: cast_nullable_to_non_nullable
as String,widgetUrl: null == widgetUrl ? _self.widgetUrl : widgetUrl // ignore: cast_nullable_to_non_nullable
as String,widgetUrl2: null == widgetUrl2 ? _self.widgetUrl2 : widgetUrl2 // ignore: cast_nullable_to_non_nullable
as String,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,review: null == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as bool,resolution: null == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SetupDocDto].
extension SetupDocDtoPatterns on SetupDocDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SetupDocDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SetupDocDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SetupDocDto value)  $default,){
final _that = this;
switch (_that) {
case _SetupDocDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SetupDocDto value)?  $default,){
final _that = this;
switch (_that) {
case _SetupDocDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@FirestoreStringConverter()  String id, @FirestoreStringConverter()  String by, @FirestoreStringConverter()  String icon, @JsonKey(name: 'icon_url')@FirestoreStringConverter()  String iconUrl, @JsonKey(name: 'created_at')@FirestoreDateTimeConverter()  DateTime? createdAt, @FirestoreStringConverter()  String desc, @FirestoreStringConverter()  String email, @FirestoreStringConverter()  String image, @FirestoreStringConverter()  String name, @FirestoreStringConverter()  String userPhoto, @JsonKey(name: 'wall_id')@FirestoreStringConverter()  String wallId, @JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter()  String wallpaperProvider, @JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter()  String wallpaperThumb, @JsonKey(name: 'wallpaper_url')@FirestoreStringConverter()  String wallpaperUrl, @FirestoreStringConverter()  String widget, @FirestoreStringConverter()  String widget2, @JsonKey(name: 'widget_url')@FirestoreStringConverter()  String widgetUrl, @JsonKey(name: 'widget_url2')@FirestoreStringConverter()  String widgetUrl2, @FirestoreStringConverter()  String link,  bool review, @FirestoreStringConverter()  String resolution, @FirestoreStringConverter()  String size)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SetupDocDto() when $default != null:
return $default(_that.id,_that.by,_that.icon,_that.iconUrl,_that.createdAt,_that.desc,_that.email,_that.image,_that.name,_that.userPhoto,_that.wallId,_that.wallpaperProvider,_that.wallpaperThumb,_that.wallpaperUrl,_that.widget,_that.widget2,_that.widgetUrl,_that.widgetUrl2,_that.link,_that.review,_that.resolution,_that.size);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@FirestoreStringConverter()  String id, @FirestoreStringConverter()  String by, @FirestoreStringConverter()  String icon, @JsonKey(name: 'icon_url')@FirestoreStringConverter()  String iconUrl, @JsonKey(name: 'created_at')@FirestoreDateTimeConverter()  DateTime? createdAt, @FirestoreStringConverter()  String desc, @FirestoreStringConverter()  String email, @FirestoreStringConverter()  String image, @FirestoreStringConverter()  String name, @FirestoreStringConverter()  String userPhoto, @JsonKey(name: 'wall_id')@FirestoreStringConverter()  String wallId, @JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter()  String wallpaperProvider, @JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter()  String wallpaperThumb, @JsonKey(name: 'wallpaper_url')@FirestoreStringConverter()  String wallpaperUrl, @FirestoreStringConverter()  String widget, @FirestoreStringConverter()  String widget2, @JsonKey(name: 'widget_url')@FirestoreStringConverter()  String widgetUrl, @JsonKey(name: 'widget_url2')@FirestoreStringConverter()  String widgetUrl2, @FirestoreStringConverter()  String link,  bool review, @FirestoreStringConverter()  String resolution, @FirestoreStringConverter()  String size)  $default,) {final _that = this;
switch (_that) {
case _SetupDocDto():
return $default(_that.id,_that.by,_that.icon,_that.iconUrl,_that.createdAt,_that.desc,_that.email,_that.image,_that.name,_that.userPhoto,_that.wallId,_that.wallpaperProvider,_that.wallpaperThumb,_that.wallpaperUrl,_that.widget,_that.widget2,_that.widgetUrl,_that.widgetUrl2,_that.link,_that.review,_that.resolution,_that.size);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@FirestoreStringConverter()  String id, @FirestoreStringConverter()  String by, @FirestoreStringConverter()  String icon, @JsonKey(name: 'icon_url')@FirestoreStringConverter()  String iconUrl, @JsonKey(name: 'created_at')@FirestoreDateTimeConverter()  DateTime? createdAt, @FirestoreStringConverter()  String desc, @FirestoreStringConverter()  String email, @FirestoreStringConverter()  String image, @FirestoreStringConverter()  String name, @FirestoreStringConverter()  String userPhoto, @JsonKey(name: 'wall_id')@FirestoreStringConverter()  String wallId, @JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter()  String wallpaperProvider, @JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter()  String wallpaperThumb, @JsonKey(name: 'wallpaper_url')@FirestoreStringConverter()  String wallpaperUrl, @FirestoreStringConverter()  String widget, @FirestoreStringConverter()  String widget2, @JsonKey(name: 'widget_url')@FirestoreStringConverter()  String widgetUrl, @JsonKey(name: 'widget_url2')@FirestoreStringConverter()  String widgetUrl2, @FirestoreStringConverter()  String link,  bool review, @FirestoreStringConverter()  String resolution, @FirestoreStringConverter()  String size)?  $default,) {final _that = this;
switch (_that) {
case _SetupDocDto() when $default != null:
return $default(_that.id,_that.by,_that.icon,_that.iconUrl,_that.createdAt,_that.desc,_that.email,_that.image,_that.name,_that.userPhoto,_that.wallId,_that.wallpaperProvider,_that.wallpaperThumb,_that.wallpaperUrl,_that.widget,_that.widget2,_that.widgetUrl,_that.widgetUrl2,_that.link,_that.review,_that.resolution,_that.size);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SetupDocDto implements SetupDocDto {
  const _SetupDocDto({@FirestoreStringConverter() this.id = '', @FirestoreStringConverter() this.by = '', @FirestoreStringConverter() this.icon = '', @JsonKey(name: 'icon_url')@FirestoreStringConverter() this.iconUrl = '', @JsonKey(name: 'created_at')@FirestoreDateTimeConverter() this.createdAt, @FirestoreStringConverter() this.desc = '', @FirestoreStringConverter() this.email = '', @FirestoreStringConverter() this.image = '', @FirestoreStringConverter() this.name = '', @FirestoreStringConverter() this.userPhoto = '', @JsonKey(name: 'wall_id')@FirestoreStringConverter() this.wallId = '', @JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter() this.wallpaperProvider = '', @JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter() this.wallpaperThumb = '', @JsonKey(name: 'wallpaper_url')@FirestoreStringConverter() this.wallpaperUrl = '', @FirestoreStringConverter() this.widget = '', @FirestoreStringConverter() this.widget2 = '', @JsonKey(name: 'widget_url')@FirestoreStringConverter() this.widgetUrl = '', @JsonKey(name: 'widget_url2')@FirestoreStringConverter() this.widgetUrl2 = '', @FirestoreStringConverter() this.link = '', this.review = false, @FirestoreStringConverter() this.resolution = '', @FirestoreStringConverter() this.size = ''});
  factory _SetupDocDto.fromJson(Map<String, dynamic> json) => _$SetupDocDtoFromJson(json);

@override@JsonKey()@FirestoreStringConverter() final  String id;
@override@JsonKey()@FirestoreStringConverter() final  String by;
@override@JsonKey()@FirestoreStringConverter() final  String icon;
@override@JsonKey(name: 'icon_url')@FirestoreStringConverter() final  String iconUrl;
@override@JsonKey(name: 'created_at')@FirestoreDateTimeConverter() final  DateTime? createdAt;
@override@JsonKey()@FirestoreStringConverter() final  String desc;
@override@JsonKey()@FirestoreStringConverter() final  String email;
@override@JsonKey()@FirestoreStringConverter() final  String image;
@override@JsonKey()@FirestoreStringConverter() final  String name;
@override@JsonKey()@FirestoreStringConverter() final  String userPhoto;
@override@JsonKey(name: 'wall_id')@FirestoreStringConverter() final  String wallId;
@override@JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter() final  String wallpaperProvider;
@override@JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter() final  String wallpaperThumb;
@override@JsonKey(name: 'wallpaper_url')@FirestoreStringConverter() final  String wallpaperUrl;
@override@JsonKey()@FirestoreStringConverter() final  String widget;
@override@JsonKey()@FirestoreStringConverter() final  String widget2;
@override@JsonKey(name: 'widget_url')@FirestoreStringConverter() final  String widgetUrl;
@override@JsonKey(name: 'widget_url2')@FirestoreStringConverter() final  String widgetUrl2;
@override@JsonKey()@FirestoreStringConverter() final  String link;
@override@JsonKey() final  bool review;
@override@JsonKey()@FirestoreStringConverter() final  String resolution;
@override@JsonKey()@FirestoreStringConverter() final  String size;

/// Create a copy of SetupDocDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SetupDocDtoCopyWith<_SetupDocDto> get copyWith => __$SetupDocDtoCopyWithImpl<_SetupDocDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SetupDocDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SetupDocDto&&(identical(other.id, id) || other.id == id)&&(identical(other.by, by) || other.by == by)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.desc, desc) || other.desc == desc)&&(identical(other.email, email) || other.email == email)&&(identical(other.image, image) || other.image == image)&&(identical(other.name, name) || other.name == name)&&(identical(other.userPhoto, userPhoto) || other.userPhoto == userPhoto)&&(identical(other.wallId, wallId) || other.wallId == wallId)&&(identical(other.wallpaperProvider, wallpaperProvider) || other.wallpaperProvider == wallpaperProvider)&&(identical(other.wallpaperThumb, wallpaperThumb) || other.wallpaperThumb == wallpaperThumb)&&(identical(other.wallpaperUrl, wallpaperUrl) || other.wallpaperUrl == wallpaperUrl)&&(identical(other.widget, widget) || other.widget == widget)&&(identical(other.widget2, widget2) || other.widget2 == widget2)&&(identical(other.widgetUrl, widgetUrl) || other.widgetUrl == widgetUrl)&&(identical(other.widgetUrl2, widgetUrl2) || other.widgetUrl2 == widgetUrl2)&&(identical(other.link, link) || other.link == link)&&(identical(other.review, review) || other.review == review)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.size, size) || other.size == size));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,by,icon,iconUrl,createdAt,desc,email,image,name,userPhoto,wallId,wallpaperProvider,wallpaperThumb,wallpaperUrl,widget,widget2,widgetUrl,widgetUrl2,link,review,resolution,size]);

@override
String toString() {
  return 'SetupDocDto(id: $id, by: $by, icon: $icon, iconUrl: $iconUrl, createdAt: $createdAt, desc: $desc, email: $email, image: $image, name: $name, userPhoto: $userPhoto, wallId: $wallId, wallpaperProvider: $wallpaperProvider, wallpaperThumb: $wallpaperThumb, wallpaperUrl: $wallpaperUrl, widget: $widget, widget2: $widget2, widgetUrl: $widgetUrl, widgetUrl2: $widgetUrl2, link: $link, review: $review, resolution: $resolution, size: $size)';
}


}

/// @nodoc
abstract mixin class _$SetupDocDtoCopyWith<$Res> implements $SetupDocDtoCopyWith<$Res> {
  factory _$SetupDocDtoCopyWith(_SetupDocDto value, $Res Function(_SetupDocDto) _then) = __$SetupDocDtoCopyWithImpl;
@override @useResult
$Res call({
@FirestoreStringConverter() String id,@FirestoreStringConverter() String by,@FirestoreStringConverter() String icon,@JsonKey(name: 'icon_url')@FirestoreStringConverter() String iconUrl,@JsonKey(name: 'created_at')@FirestoreDateTimeConverter() DateTime? createdAt,@FirestoreStringConverter() String desc,@FirestoreStringConverter() String email,@FirestoreStringConverter() String image,@FirestoreStringConverter() String name,@FirestoreStringConverter() String userPhoto,@JsonKey(name: 'wall_id')@FirestoreStringConverter() String wallId,@JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter() String wallpaperProvider,@JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter() String wallpaperThumb,@JsonKey(name: 'wallpaper_url')@FirestoreStringConverter() String wallpaperUrl,@FirestoreStringConverter() String widget,@FirestoreStringConverter() String widget2,@JsonKey(name: 'widget_url')@FirestoreStringConverter() String widgetUrl,@JsonKey(name: 'widget_url2')@FirestoreStringConverter() String widgetUrl2,@FirestoreStringConverter() String link, bool review,@FirestoreStringConverter() String resolution,@FirestoreStringConverter() String size
});




}
/// @nodoc
class __$SetupDocDtoCopyWithImpl<$Res>
    implements _$SetupDocDtoCopyWith<$Res> {
  __$SetupDocDtoCopyWithImpl(this._self, this._then);

  final _SetupDocDto _self;
  final $Res Function(_SetupDocDto) _then;

/// Create a copy of SetupDocDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? by = null,Object? icon = null,Object? iconUrl = null,Object? createdAt = freezed,Object? desc = null,Object? email = null,Object? image = null,Object? name = null,Object? userPhoto = null,Object? wallId = null,Object? wallpaperProvider = null,Object? wallpaperThumb = null,Object? wallpaperUrl = null,Object? widget = null,Object? widget2 = null,Object? widgetUrl = null,Object? widgetUrl2 = null,Object? link = null,Object? review = null,Object? resolution = null,Object? size = null,}) {
  return _then(_SetupDocDto(
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
as String,wallpaperProvider: null == wallpaperProvider ? _self.wallpaperProvider : wallpaperProvider // ignore: cast_nullable_to_non_nullable
as String,wallpaperThumb: null == wallpaperThumb ? _self.wallpaperThumb : wallpaperThumb // ignore: cast_nullable_to_non_nullable
as String,wallpaperUrl: null == wallpaperUrl ? _self.wallpaperUrl : wallpaperUrl // ignore: cast_nullable_to_non_nullable
as String,widget: null == widget ? _self.widget : widget // ignore: cast_nullable_to_non_nullable
as String,widget2: null == widget2 ? _self.widget2 : widget2 // ignore: cast_nullable_to_non_nullable
as String,widgetUrl: null == widgetUrl ? _self.widgetUrl : widgetUrl // ignore: cast_nullable_to_non_nullable
as String,widgetUrl2: null == widgetUrl2 ? _self.widgetUrl2 : widgetUrl2 // ignore: cast_nullable_to_non_nullable
as String,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,review: null == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as bool,resolution: null == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
