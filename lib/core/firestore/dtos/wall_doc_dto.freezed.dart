// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wall_doc_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WallDocDto {

@FirestoreStringConverter() String get id;@FirestoreStringConverter() String get by;@FirestoreStringConverter() String get desc;@FirestoreStringConverter() String get size;@FirestoreStringConverter() String get resolution;@FirestoreStringConverter() String get email;@JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter() String get wallpaperProvider;@JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter() String get wallpaperThumb;@JsonKey(name: 'wallpaper_url')@FirestoreStringConverter() String get wallpaperUrl;@FirestoreStringListConverter() List<String> get collections;@FirestoreDateTimeConverter() DateTime? get createdAt; bool get review;
/// Create a copy of WallDocDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WallDocDtoCopyWith<WallDocDto> get copyWith => _$WallDocDtoCopyWithImpl<WallDocDto>(this as WallDocDto, _$identity);

  /// Serializes this WallDocDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WallDocDto&&(identical(other.id, id) || other.id == id)&&(identical(other.by, by) || other.by == by)&&(identical(other.desc, desc) || other.desc == desc)&&(identical(other.size, size) || other.size == size)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.email, email) || other.email == email)&&(identical(other.wallpaperProvider, wallpaperProvider) || other.wallpaperProvider == wallpaperProvider)&&(identical(other.wallpaperThumb, wallpaperThumb) || other.wallpaperThumb == wallpaperThumb)&&(identical(other.wallpaperUrl, wallpaperUrl) || other.wallpaperUrl == wallpaperUrl)&&const DeepCollectionEquality().equals(other.collections, collections)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.review, review) || other.review == review));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,by,desc,size,resolution,email,wallpaperProvider,wallpaperThumb,wallpaperUrl,const DeepCollectionEquality().hash(collections),createdAt,review);

@override
String toString() {
  return 'WallDocDto(id: $id, by: $by, desc: $desc, size: $size, resolution: $resolution, email: $email, wallpaperProvider: $wallpaperProvider, wallpaperThumb: $wallpaperThumb, wallpaperUrl: $wallpaperUrl, collections: $collections, createdAt: $createdAt, review: $review)';
}


}

/// @nodoc
abstract mixin class $WallDocDtoCopyWith<$Res>  {
  factory $WallDocDtoCopyWith(WallDocDto value, $Res Function(WallDocDto) _then) = _$WallDocDtoCopyWithImpl;
@useResult
$Res call({
@FirestoreStringConverter() String id,@FirestoreStringConverter() String by,@FirestoreStringConverter() String desc,@FirestoreStringConverter() String size,@FirestoreStringConverter() String resolution,@FirestoreStringConverter() String email,@JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter() String wallpaperProvider,@JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter() String wallpaperThumb,@JsonKey(name: 'wallpaper_url')@FirestoreStringConverter() String wallpaperUrl,@FirestoreStringListConverter() List<String> collections,@FirestoreDateTimeConverter() DateTime? createdAt, bool review
});




}
/// @nodoc
class _$WallDocDtoCopyWithImpl<$Res>
    implements $WallDocDtoCopyWith<$Res> {
  _$WallDocDtoCopyWithImpl(this._self, this._then);

  final WallDocDto _self;
  final $Res Function(WallDocDto) _then;

/// Create a copy of WallDocDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? by = null,Object? desc = null,Object? size = null,Object? resolution = null,Object? email = null,Object? wallpaperProvider = null,Object? wallpaperThumb = null,Object? wallpaperUrl = null,Object? collections = null,Object? createdAt = freezed,Object? review = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,by: null == by ? _self.by : by // ignore: cast_nullable_to_non_nullable
as String,desc: null == desc ? _self.desc : desc // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as String,resolution: null == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,wallpaperProvider: null == wallpaperProvider ? _self.wallpaperProvider : wallpaperProvider // ignore: cast_nullable_to_non_nullable
as String,wallpaperThumb: null == wallpaperThumb ? _self.wallpaperThumb : wallpaperThumb // ignore: cast_nullable_to_non_nullable
as String,wallpaperUrl: null == wallpaperUrl ? _self.wallpaperUrl : wallpaperUrl // ignore: cast_nullable_to_non_nullable
as String,collections: null == collections ? _self.collections : collections // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,review: null == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [WallDocDto].
extension WallDocDtoPatterns on WallDocDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WallDocDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WallDocDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WallDocDto value)  $default,){
final _that = this;
switch (_that) {
case _WallDocDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WallDocDto value)?  $default,){
final _that = this;
switch (_that) {
case _WallDocDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@FirestoreStringConverter()  String id, @FirestoreStringConverter()  String by, @FirestoreStringConverter()  String desc, @FirestoreStringConverter()  String size, @FirestoreStringConverter()  String resolution, @FirestoreStringConverter()  String email, @JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter()  String wallpaperProvider, @JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter()  String wallpaperThumb, @JsonKey(name: 'wallpaper_url')@FirestoreStringConverter()  String wallpaperUrl, @FirestoreStringListConverter()  List<String> collections, @FirestoreDateTimeConverter()  DateTime? createdAt,  bool review)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WallDocDto() when $default != null:
return $default(_that.id,_that.by,_that.desc,_that.size,_that.resolution,_that.email,_that.wallpaperProvider,_that.wallpaperThumb,_that.wallpaperUrl,_that.collections,_that.createdAt,_that.review);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@FirestoreStringConverter()  String id, @FirestoreStringConverter()  String by, @FirestoreStringConverter()  String desc, @FirestoreStringConverter()  String size, @FirestoreStringConverter()  String resolution, @FirestoreStringConverter()  String email, @JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter()  String wallpaperProvider, @JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter()  String wallpaperThumb, @JsonKey(name: 'wallpaper_url')@FirestoreStringConverter()  String wallpaperUrl, @FirestoreStringListConverter()  List<String> collections, @FirestoreDateTimeConverter()  DateTime? createdAt,  bool review)  $default,) {final _that = this;
switch (_that) {
case _WallDocDto():
return $default(_that.id,_that.by,_that.desc,_that.size,_that.resolution,_that.email,_that.wallpaperProvider,_that.wallpaperThumb,_that.wallpaperUrl,_that.collections,_that.createdAt,_that.review);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@FirestoreStringConverter()  String id, @FirestoreStringConverter()  String by, @FirestoreStringConverter()  String desc, @FirestoreStringConverter()  String size, @FirestoreStringConverter()  String resolution, @FirestoreStringConverter()  String email, @JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter()  String wallpaperProvider, @JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter()  String wallpaperThumb, @JsonKey(name: 'wallpaper_url')@FirestoreStringConverter()  String wallpaperUrl, @FirestoreStringListConverter()  List<String> collections, @FirestoreDateTimeConverter()  DateTime? createdAt,  bool review)?  $default,) {final _that = this;
switch (_that) {
case _WallDocDto() when $default != null:
return $default(_that.id,_that.by,_that.desc,_that.size,_that.resolution,_that.email,_that.wallpaperProvider,_that.wallpaperThumb,_that.wallpaperUrl,_that.collections,_that.createdAt,_that.review);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WallDocDto implements WallDocDto {
  const _WallDocDto({@FirestoreStringConverter() this.id = '', @FirestoreStringConverter() this.by = '', @FirestoreStringConverter() this.desc = '', @FirestoreStringConverter() this.size = '', @FirestoreStringConverter() this.resolution = '', @FirestoreStringConverter() this.email = '', @JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter() this.wallpaperProvider = '', @JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter() this.wallpaperThumb = '', @JsonKey(name: 'wallpaper_url')@FirestoreStringConverter() this.wallpaperUrl = '', @FirestoreStringListConverter() final  List<String> collections = const <String>[], @FirestoreDateTimeConverter() this.createdAt, this.review = false}): _collections = collections;
  factory _WallDocDto.fromJson(Map<String, dynamic> json) => _$WallDocDtoFromJson(json);

@override@JsonKey()@FirestoreStringConverter() final  String id;
@override@JsonKey()@FirestoreStringConverter() final  String by;
@override@JsonKey()@FirestoreStringConverter() final  String desc;
@override@JsonKey()@FirestoreStringConverter() final  String size;
@override@JsonKey()@FirestoreStringConverter() final  String resolution;
@override@JsonKey()@FirestoreStringConverter() final  String email;
@override@JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter() final  String wallpaperProvider;
@override@JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter() final  String wallpaperThumb;
@override@JsonKey(name: 'wallpaper_url')@FirestoreStringConverter() final  String wallpaperUrl;
 final  List<String> _collections;
@override@JsonKey()@FirestoreStringListConverter() List<String> get collections {
  if (_collections is EqualUnmodifiableListView) return _collections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_collections);
}

@override@FirestoreDateTimeConverter() final  DateTime? createdAt;
@override@JsonKey() final  bool review;

/// Create a copy of WallDocDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WallDocDtoCopyWith<_WallDocDto> get copyWith => __$WallDocDtoCopyWithImpl<_WallDocDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WallDocDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WallDocDto&&(identical(other.id, id) || other.id == id)&&(identical(other.by, by) || other.by == by)&&(identical(other.desc, desc) || other.desc == desc)&&(identical(other.size, size) || other.size == size)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.email, email) || other.email == email)&&(identical(other.wallpaperProvider, wallpaperProvider) || other.wallpaperProvider == wallpaperProvider)&&(identical(other.wallpaperThumb, wallpaperThumb) || other.wallpaperThumb == wallpaperThumb)&&(identical(other.wallpaperUrl, wallpaperUrl) || other.wallpaperUrl == wallpaperUrl)&&const DeepCollectionEquality().equals(other._collections, _collections)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.review, review) || other.review == review));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,by,desc,size,resolution,email,wallpaperProvider,wallpaperThumb,wallpaperUrl,const DeepCollectionEquality().hash(_collections),createdAt,review);

@override
String toString() {
  return 'WallDocDto(id: $id, by: $by, desc: $desc, size: $size, resolution: $resolution, email: $email, wallpaperProvider: $wallpaperProvider, wallpaperThumb: $wallpaperThumb, wallpaperUrl: $wallpaperUrl, collections: $collections, createdAt: $createdAt, review: $review)';
}


}

/// @nodoc
abstract mixin class _$WallDocDtoCopyWith<$Res> implements $WallDocDtoCopyWith<$Res> {
  factory _$WallDocDtoCopyWith(_WallDocDto value, $Res Function(_WallDocDto) _then) = __$WallDocDtoCopyWithImpl;
@override @useResult
$Res call({
@FirestoreStringConverter() String id,@FirestoreStringConverter() String by,@FirestoreStringConverter() String desc,@FirestoreStringConverter() String size,@FirestoreStringConverter() String resolution,@FirestoreStringConverter() String email,@JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter() String wallpaperProvider,@JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter() String wallpaperThumb,@JsonKey(name: 'wallpaper_url')@FirestoreStringConverter() String wallpaperUrl,@FirestoreStringListConverter() List<String> collections,@FirestoreDateTimeConverter() DateTime? createdAt, bool review
});




}
/// @nodoc
class __$WallDocDtoCopyWithImpl<$Res>
    implements _$WallDocDtoCopyWith<$Res> {
  __$WallDocDtoCopyWithImpl(this._self, this._then);

  final _WallDocDto _self;
  final $Res Function(_WallDocDto) _then;

/// Create a copy of WallDocDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? by = null,Object? desc = null,Object? size = null,Object? resolution = null,Object? email = null,Object? wallpaperProvider = null,Object? wallpaperThumb = null,Object? wallpaperUrl = null,Object? collections = null,Object? createdAt = freezed,Object? review = null,}) {
  return _then(_WallDocDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,by: null == by ? _self.by : by // ignore: cast_nullable_to_non_nullable
as String,desc: null == desc ? _self.desc : desc // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as String,resolution: null == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,wallpaperProvider: null == wallpaperProvider ? _self.wallpaperProvider : wallpaperProvider // ignore: cast_nullable_to_non_nullable
as String,wallpaperThumb: null == wallpaperThumb ? _self.wallpaperThumb : wallpaperThumb // ignore: cast_nullable_to_non_nullable
as String,wallpaperUrl: null == wallpaperUrl ? _self.wallpaperUrl : wallpaperUrl // ignore: cast_nullable_to_non_nullable
as String,collections: null == collections ? _self._collections : collections // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,review: null == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$FavouriteWallDocDto {

@FirestoreStringConverter() String get id;@FirestoreStringConverter() String get provider;@FirestoreStringConverter() String get url;@FirestoreStringConverter() String get thumb;@FirestoreStringConverter() String get category;@FirestoreStringConverter() String get views;@FirestoreStringConverter() String get resolution;@FirestoreStringConverter() String get fav;@FirestoreStringConverter() String get size;@FirestoreStringConverter() String get photographer;@FirestoreStringListConverter() List<String> get collections;@FirestoreDateTimeConverter() DateTime? get createdAt;
/// Create a copy of FavouriteWallDocDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FavouriteWallDocDtoCopyWith<FavouriteWallDocDto> get copyWith => _$FavouriteWallDocDtoCopyWithImpl<FavouriteWallDocDto>(this as FavouriteWallDocDto, _$identity);

  /// Serializes this FavouriteWallDocDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FavouriteWallDocDto&&(identical(other.id, id) || other.id == id)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.url, url) || other.url == url)&&(identical(other.thumb, thumb) || other.thumb == thumb)&&(identical(other.category, category) || other.category == category)&&(identical(other.views, views) || other.views == views)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.fav, fav) || other.fav == fav)&&(identical(other.size, size) || other.size == size)&&(identical(other.photographer, photographer) || other.photographer == photographer)&&const DeepCollectionEquality().equals(other.collections, collections)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,provider,url,thumb,category,views,resolution,fav,size,photographer,const DeepCollectionEquality().hash(collections),createdAt);

@override
String toString() {
  return 'FavouriteWallDocDto(id: $id, provider: $provider, url: $url, thumb: $thumb, category: $category, views: $views, resolution: $resolution, fav: $fav, size: $size, photographer: $photographer, collections: $collections, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $FavouriteWallDocDtoCopyWith<$Res>  {
  factory $FavouriteWallDocDtoCopyWith(FavouriteWallDocDto value, $Res Function(FavouriteWallDocDto) _then) = _$FavouriteWallDocDtoCopyWithImpl;
@useResult
$Res call({
@FirestoreStringConverter() String id,@FirestoreStringConverter() String provider,@FirestoreStringConverter() String url,@FirestoreStringConverter() String thumb,@FirestoreStringConverter() String category,@FirestoreStringConverter() String views,@FirestoreStringConverter() String resolution,@FirestoreStringConverter() String fav,@FirestoreStringConverter() String size,@FirestoreStringConverter() String photographer,@FirestoreStringListConverter() List<String> collections,@FirestoreDateTimeConverter() DateTime? createdAt
});




}
/// @nodoc
class _$FavouriteWallDocDtoCopyWithImpl<$Res>
    implements $FavouriteWallDocDtoCopyWith<$Res> {
  _$FavouriteWallDocDtoCopyWithImpl(this._self, this._then);

  final FavouriteWallDocDto _self;
  final $Res Function(FavouriteWallDocDto) _then;

/// Create a copy of FavouriteWallDocDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? provider = null,Object? url = null,Object? thumb = null,Object? category = null,Object? views = null,Object? resolution = null,Object? fav = null,Object? size = null,Object? photographer = null,Object? collections = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,thumb: null == thumb ? _self.thumb : thumb // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,views: null == views ? _self.views : views // ignore: cast_nullable_to_non_nullable
as String,resolution: null == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as String,fav: null == fav ? _self.fav : fav // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as String,photographer: null == photographer ? _self.photographer : photographer // ignore: cast_nullable_to_non_nullable
as String,collections: null == collections ? _self.collections : collections // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [FavouriteWallDocDto].
extension FavouriteWallDocDtoPatterns on FavouriteWallDocDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FavouriteWallDocDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FavouriteWallDocDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FavouriteWallDocDto value)  $default,){
final _that = this;
switch (_that) {
case _FavouriteWallDocDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FavouriteWallDocDto value)?  $default,){
final _that = this;
switch (_that) {
case _FavouriteWallDocDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@FirestoreStringConverter()  String id, @FirestoreStringConverter()  String provider, @FirestoreStringConverter()  String url, @FirestoreStringConverter()  String thumb, @FirestoreStringConverter()  String category, @FirestoreStringConverter()  String views, @FirestoreStringConverter()  String resolution, @FirestoreStringConverter()  String fav, @FirestoreStringConverter()  String size, @FirestoreStringConverter()  String photographer, @FirestoreStringListConverter()  List<String> collections, @FirestoreDateTimeConverter()  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FavouriteWallDocDto() when $default != null:
return $default(_that.id,_that.provider,_that.url,_that.thumb,_that.category,_that.views,_that.resolution,_that.fav,_that.size,_that.photographer,_that.collections,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@FirestoreStringConverter()  String id, @FirestoreStringConverter()  String provider, @FirestoreStringConverter()  String url, @FirestoreStringConverter()  String thumb, @FirestoreStringConverter()  String category, @FirestoreStringConverter()  String views, @FirestoreStringConverter()  String resolution, @FirestoreStringConverter()  String fav, @FirestoreStringConverter()  String size, @FirestoreStringConverter()  String photographer, @FirestoreStringListConverter()  List<String> collections, @FirestoreDateTimeConverter()  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _FavouriteWallDocDto():
return $default(_that.id,_that.provider,_that.url,_that.thumb,_that.category,_that.views,_that.resolution,_that.fav,_that.size,_that.photographer,_that.collections,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@FirestoreStringConverter()  String id, @FirestoreStringConverter()  String provider, @FirestoreStringConverter()  String url, @FirestoreStringConverter()  String thumb, @FirestoreStringConverter()  String category, @FirestoreStringConverter()  String views, @FirestoreStringConverter()  String resolution, @FirestoreStringConverter()  String fav, @FirestoreStringConverter()  String size, @FirestoreStringConverter()  String photographer, @FirestoreStringListConverter()  List<String> collections, @FirestoreDateTimeConverter()  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _FavouriteWallDocDto() when $default != null:
return $default(_that.id,_that.provider,_that.url,_that.thumb,_that.category,_that.views,_that.resolution,_that.fav,_that.size,_that.photographer,_that.collections,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FavouriteWallDocDto implements FavouriteWallDocDto {
  const _FavouriteWallDocDto({@FirestoreStringConverter() this.id = '', @FirestoreStringConverter() this.provider = '', @FirestoreStringConverter() this.url = '', @FirestoreStringConverter() this.thumb = '', @FirestoreStringConverter() this.category = '', @FirestoreStringConverter() this.views = '', @FirestoreStringConverter() this.resolution = '', @FirestoreStringConverter() this.fav = '', @FirestoreStringConverter() this.size = '', @FirestoreStringConverter() this.photographer = '', @FirestoreStringListConverter() final  List<String> collections = const <String>[], @FirestoreDateTimeConverter() this.createdAt}): _collections = collections;
  factory _FavouriteWallDocDto.fromJson(Map<String, dynamic> json) => _$FavouriteWallDocDtoFromJson(json);

@override@JsonKey()@FirestoreStringConverter() final  String id;
@override@JsonKey()@FirestoreStringConverter() final  String provider;
@override@JsonKey()@FirestoreStringConverter() final  String url;
@override@JsonKey()@FirestoreStringConverter() final  String thumb;
@override@JsonKey()@FirestoreStringConverter() final  String category;
@override@JsonKey()@FirestoreStringConverter() final  String views;
@override@JsonKey()@FirestoreStringConverter() final  String resolution;
@override@JsonKey()@FirestoreStringConverter() final  String fav;
@override@JsonKey()@FirestoreStringConverter() final  String size;
@override@JsonKey()@FirestoreStringConverter() final  String photographer;
 final  List<String> _collections;
@override@JsonKey()@FirestoreStringListConverter() List<String> get collections {
  if (_collections is EqualUnmodifiableListView) return _collections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_collections);
}

@override@FirestoreDateTimeConverter() final  DateTime? createdAt;

/// Create a copy of FavouriteWallDocDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FavouriteWallDocDtoCopyWith<_FavouriteWallDocDto> get copyWith => __$FavouriteWallDocDtoCopyWithImpl<_FavouriteWallDocDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FavouriteWallDocDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FavouriteWallDocDto&&(identical(other.id, id) || other.id == id)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.url, url) || other.url == url)&&(identical(other.thumb, thumb) || other.thumb == thumb)&&(identical(other.category, category) || other.category == category)&&(identical(other.views, views) || other.views == views)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.fav, fav) || other.fav == fav)&&(identical(other.size, size) || other.size == size)&&(identical(other.photographer, photographer) || other.photographer == photographer)&&const DeepCollectionEquality().equals(other._collections, _collections)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,provider,url,thumb,category,views,resolution,fav,size,photographer,const DeepCollectionEquality().hash(_collections),createdAt);

@override
String toString() {
  return 'FavouriteWallDocDto(id: $id, provider: $provider, url: $url, thumb: $thumb, category: $category, views: $views, resolution: $resolution, fav: $fav, size: $size, photographer: $photographer, collections: $collections, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$FavouriteWallDocDtoCopyWith<$Res> implements $FavouriteWallDocDtoCopyWith<$Res> {
  factory _$FavouriteWallDocDtoCopyWith(_FavouriteWallDocDto value, $Res Function(_FavouriteWallDocDto) _then) = __$FavouriteWallDocDtoCopyWithImpl;
@override @useResult
$Res call({
@FirestoreStringConverter() String id,@FirestoreStringConverter() String provider,@FirestoreStringConverter() String url,@FirestoreStringConverter() String thumb,@FirestoreStringConverter() String category,@FirestoreStringConverter() String views,@FirestoreStringConverter() String resolution,@FirestoreStringConverter() String fav,@FirestoreStringConverter() String size,@FirestoreStringConverter() String photographer,@FirestoreStringListConverter() List<String> collections,@FirestoreDateTimeConverter() DateTime? createdAt
});




}
/// @nodoc
class __$FavouriteWallDocDtoCopyWithImpl<$Res>
    implements _$FavouriteWallDocDtoCopyWith<$Res> {
  __$FavouriteWallDocDtoCopyWithImpl(this._self, this._then);

  final _FavouriteWallDocDto _self;
  final $Res Function(_FavouriteWallDocDto) _then;

/// Create a copy of FavouriteWallDocDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? provider = null,Object? url = null,Object? thumb = null,Object? category = null,Object? views = null,Object? resolution = null,Object? fav = null,Object? size = null,Object? photographer = null,Object? collections = null,Object? createdAt = freezed,}) {
  return _then(_FavouriteWallDocDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,thumb: null == thumb ? _self.thumb : thumb // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,views: null == views ? _self.views : views // ignore: cast_nullable_to_non_nullable
as String,resolution: null == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as String,fav: null == fav ? _self.fav : fav // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as String,photographer: null == photographer ? _self.photographer : photographer // ignore: cast_nullable_to_non_nullable
as String,collections: null == collections ? _self._collections : collections // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
