// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'prism_wall_doc_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PrismWallDocDto {

@FirestoreStringConverter() String get id;@JsonKey(name: 'wallpaper_url')@FirestoreStringConverter() String get wallpaperUrl;@JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter() String get wallpaperThumb;@JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter() String get wallpaperProvider;@FirestoreStringConverter() String get resolution;@JsonKey(name: 'file_size') int? get fileSize;@FirestoreDateTimeConverter() DateTime? get createdAt;@JsonKey(name: 'uploadedBy')@FirestoreStringConverter() String get uploadedBy;@FirestoreStringConverter() String get desc;@FirestoreStringListConverter() List<String> get collections;@FirestoreStringListConverter() List<String> get tags; bool get review;@JsonKey(name: 'aiMetadata')@FirestoreJsonMapConverter() Map<String, Object?> get aiMetadata;
/// Create a copy of PrismWallDocDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PrismWallDocDtoCopyWith<PrismWallDocDto> get copyWith => _$PrismWallDocDtoCopyWithImpl<PrismWallDocDto>(this as PrismWallDocDto, _$identity);

  /// Serializes this PrismWallDocDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PrismWallDocDto&&(identical(other.id, id) || other.id == id)&&(identical(other.wallpaperUrl, wallpaperUrl) || other.wallpaperUrl == wallpaperUrl)&&(identical(other.wallpaperThumb, wallpaperThumb) || other.wallpaperThumb == wallpaperThumb)&&(identical(other.wallpaperProvider, wallpaperProvider) || other.wallpaperProvider == wallpaperProvider)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.uploadedBy, uploadedBy) || other.uploadedBy == uploadedBy)&&(identical(other.desc, desc) || other.desc == desc)&&const DeepCollectionEquality().equals(other.collections, collections)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.review, review) || other.review == review)&&const DeepCollectionEquality().equals(other.aiMetadata, aiMetadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,wallpaperUrl,wallpaperThumb,wallpaperProvider,resolution,fileSize,createdAt,uploadedBy,desc,const DeepCollectionEquality().hash(collections),const DeepCollectionEquality().hash(tags),review,const DeepCollectionEquality().hash(aiMetadata));

@override
String toString() {
  return 'PrismWallDocDto(id: $id, wallpaperUrl: $wallpaperUrl, wallpaperThumb: $wallpaperThumb, wallpaperProvider: $wallpaperProvider, resolution: $resolution, fileSize: $fileSize, createdAt: $createdAt, uploadedBy: $uploadedBy, desc: $desc, collections: $collections, tags: $tags, review: $review, aiMetadata: $aiMetadata)';
}


}

/// @nodoc
abstract mixin class $PrismWallDocDtoCopyWith<$Res>  {
  factory $PrismWallDocDtoCopyWith(PrismWallDocDto value, $Res Function(PrismWallDocDto) _then) = _$PrismWallDocDtoCopyWithImpl;
@useResult
$Res call({
@FirestoreStringConverter() String id,@JsonKey(name: 'wallpaper_url')@FirestoreStringConverter() String wallpaperUrl,@JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter() String wallpaperThumb,@JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter() String wallpaperProvider,@FirestoreStringConverter() String resolution,@JsonKey(name: 'file_size') int? fileSize,@FirestoreDateTimeConverter() DateTime? createdAt,@JsonKey(name: 'uploadedBy')@FirestoreStringConverter() String uploadedBy,@FirestoreStringConverter() String desc,@FirestoreStringListConverter() List<String> collections,@FirestoreStringListConverter() List<String> tags, bool review,@JsonKey(name: 'aiMetadata')@FirestoreJsonMapConverter() Map<String, Object?> aiMetadata
});




}
/// @nodoc
class _$PrismWallDocDtoCopyWithImpl<$Res>
    implements $PrismWallDocDtoCopyWith<$Res> {
  _$PrismWallDocDtoCopyWithImpl(this._self, this._then);

  final PrismWallDocDto _self;
  final $Res Function(PrismWallDocDto) _then;

/// Create a copy of PrismWallDocDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? wallpaperUrl = null,Object? wallpaperThumb = null,Object? wallpaperProvider = null,Object? resolution = null,Object? fileSize = freezed,Object? createdAt = freezed,Object? uploadedBy = null,Object? desc = null,Object? collections = null,Object? tags = null,Object? review = null,Object? aiMetadata = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,wallpaperUrl: null == wallpaperUrl ? _self.wallpaperUrl : wallpaperUrl // ignore: cast_nullable_to_non_nullable
as String,wallpaperThumb: null == wallpaperThumb ? _self.wallpaperThumb : wallpaperThumb // ignore: cast_nullable_to_non_nullable
as String,wallpaperProvider: null == wallpaperProvider ? _self.wallpaperProvider : wallpaperProvider // ignore: cast_nullable_to_non_nullable
as String,resolution: null == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as String,fileSize: freezed == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,uploadedBy: null == uploadedBy ? _self.uploadedBy : uploadedBy // ignore: cast_nullable_to_non_nullable
as String,desc: null == desc ? _self.desc : desc // ignore: cast_nullable_to_non_nullable
as String,collections: null == collections ? _self.collections : collections // ignore: cast_nullable_to_non_nullable
as List<String>,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,review: null == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as bool,aiMetadata: null == aiMetadata ? _self.aiMetadata : aiMetadata // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

}


/// Adds pattern-matching-related methods to [PrismWallDocDto].
extension PrismWallDocDtoPatterns on PrismWallDocDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PrismWallDocDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PrismWallDocDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PrismWallDocDto value)  $default,){
final _that = this;
switch (_that) {
case _PrismWallDocDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PrismWallDocDto value)?  $default,){
final _that = this;
switch (_that) {
case _PrismWallDocDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@FirestoreStringConverter()  String id, @JsonKey(name: 'wallpaper_url')@FirestoreStringConverter()  String wallpaperUrl, @JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter()  String wallpaperThumb, @JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter()  String wallpaperProvider, @FirestoreStringConverter()  String resolution, @JsonKey(name: 'file_size')  int? fileSize, @FirestoreDateTimeConverter()  DateTime? createdAt, @JsonKey(name: 'uploadedBy')@FirestoreStringConverter()  String uploadedBy, @FirestoreStringConverter()  String desc, @FirestoreStringListConverter()  List<String> collections, @FirestoreStringListConverter()  List<String> tags,  bool review, @JsonKey(name: 'aiMetadata')@FirestoreJsonMapConverter()  Map<String, Object?> aiMetadata)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PrismWallDocDto() when $default != null:
return $default(_that.id,_that.wallpaperUrl,_that.wallpaperThumb,_that.wallpaperProvider,_that.resolution,_that.fileSize,_that.createdAt,_that.uploadedBy,_that.desc,_that.collections,_that.tags,_that.review,_that.aiMetadata);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@FirestoreStringConverter()  String id, @JsonKey(name: 'wallpaper_url')@FirestoreStringConverter()  String wallpaperUrl, @JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter()  String wallpaperThumb, @JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter()  String wallpaperProvider, @FirestoreStringConverter()  String resolution, @JsonKey(name: 'file_size')  int? fileSize, @FirestoreDateTimeConverter()  DateTime? createdAt, @JsonKey(name: 'uploadedBy')@FirestoreStringConverter()  String uploadedBy, @FirestoreStringConverter()  String desc, @FirestoreStringListConverter()  List<String> collections, @FirestoreStringListConverter()  List<String> tags,  bool review, @JsonKey(name: 'aiMetadata')@FirestoreJsonMapConverter()  Map<String, Object?> aiMetadata)  $default,) {final _that = this;
switch (_that) {
case _PrismWallDocDto():
return $default(_that.id,_that.wallpaperUrl,_that.wallpaperThumb,_that.wallpaperProvider,_that.resolution,_that.fileSize,_that.createdAt,_that.uploadedBy,_that.desc,_that.collections,_that.tags,_that.review,_that.aiMetadata);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@FirestoreStringConverter()  String id, @JsonKey(name: 'wallpaper_url')@FirestoreStringConverter()  String wallpaperUrl, @JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter()  String wallpaperThumb, @JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter()  String wallpaperProvider, @FirestoreStringConverter()  String resolution, @JsonKey(name: 'file_size')  int? fileSize, @FirestoreDateTimeConverter()  DateTime? createdAt, @JsonKey(name: 'uploadedBy')@FirestoreStringConverter()  String uploadedBy, @FirestoreStringConverter()  String desc, @FirestoreStringListConverter()  List<String> collections, @FirestoreStringListConverter()  List<String> tags,  bool review, @JsonKey(name: 'aiMetadata')@FirestoreJsonMapConverter()  Map<String, Object?> aiMetadata)?  $default,) {final _that = this;
switch (_that) {
case _PrismWallDocDto() when $default != null:
return $default(_that.id,_that.wallpaperUrl,_that.wallpaperThumb,_that.wallpaperProvider,_that.resolution,_that.fileSize,_that.createdAt,_that.uploadedBy,_that.desc,_that.collections,_that.tags,_that.review,_that.aiMetadata);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PrismWallDocDto implements PrismWallDocDto {
  const _PrismWallDocDto({@FirestoreStringConverter() this.id = '', @JsonKey(name: 'wallpaper_url')@FirestoreStringConverter() this.wallpaperUrl = '', @JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter() this.wallpaperThumb = '', @JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter() this.wallpaperProvider = '', @FirestoreStringConverter() this.resolution = '', @JsonKey(name: 'file_size') this.fileSize, @FirestoreDateTimeConverter() this.createdAt, @JsonKey(name: 'uploadedBy')@FirestoreStringConverter() this.uploadedBy = '', @FirestoreStringConverter() this.desc = '', @FirestoreStringListConverter() final  List<String> collections = const <String>[], @FirestoreStringListConverter() final  List<String> tags = const <String>[], this.review = false, @JsonKey(name: 'aiMetadata')@FirestoreJsonMapConverter() final  Map<String, Object?> aiMetadata = const <String, Object?>{}}): _collections = collections,_tags = tags,_aiMetadata = aiMetadata;
  factory _PrismWallDocDto.fromJson(Map<String, dynamic> json) => _$PrismWallDocDtoFromJson(json);

@override@JsonKey()@FirestoreStringConverter() final  String id;
@override@JsonKey(name: 'wallpaper_url')@FirestoreStringConverter() final  String wallpaperUrl;
@override@JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter() final  String wallpaperThumb;
@override@JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter() final  String wallpaperProvider;
@override@JsonKey()@FirestoreStringConverter() final  String resolution;
@override@JsonKey(name: 'file_size') final  int? fileSize;
@override@FirestoreDateTimeConverter() final  DateTime? createdAt;
@override@JsonKey(name: 'uploadedBy')@FirestoreStringConverter() final  String uploadedBy;
@override@JsonKey()@FirestoreStringConverter() final  String desc;
 final  List<String> _collections;
@override@JsonKey()@FirestoreStringListConverter() List<String> get collections {
  if (_collections is EqualUnmodifiableListView) return _collections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_collections);
}

 final  List<String> _tags;
@override@JsonKey()@FirestoreStringListConverter() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

@override@JsonKey() final  bool review;
 final  Map<String, Object?> _aiMetadata;
@override@JsonKey(name: 'aiMetadata')@FirestoreJsonMapConverter() Map<String, Object?> get aiMetadata {
  if (_aiMetadata is EqualUnmodifiableMapView) return _aiMetadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_aiMetadata);
}


/// Create a copy of PrismWallDocDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PrismWallDocDtoCopyWith<_PrismWallDocDto> get copyWith => __$PrismWallDocDtoCopyWithImpl<_PrismWallDocDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PrismWallDocDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PrismWallDocDto&&(identical(other.id, id) || other.id == id)&&(identical(other.wallpaperUrl, wallpaperUrl) || other.wallpaperUrl == wallpaperUrl)&&(identical(other.wallpaperThumb, wallpaperThumb) || other.wallpaperThumb == wallpaperThumb)&&(identical(other.wallpaperProvider, wallpaperProvider) || other.wallpaperProvider == wallpaperProvider)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.uploadedBy, uploadedBy) || other.uploadedBy == uploadedBy)&&(identical(other.desc, desc) || other.desc == desc)&&const DeepCollectionEquality().equals(other._collections, _collections)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.review, review) || other.review == review)&&const DeepCollectionEquality().equals(other._aiMetadata, _aiMetadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,wallpaperUrl,wallpaperThumb,wallpaperProvider,resolution,fileSize,createdAt,uploadedBy,desc,const DeepCollectionEquality().hash(_collections),const DeepCollectionEquality().hash(_tags),review,const DeepCollectionEquality().hash(_aiMetadata));

@override
String toString() {
  return 'PrismWallDocDto(id: $id, wallpaperUrl: $wallpaperUrl, wallpaperThumb: $wallpaperThumb, wallpaperProvider: $wallpaperProvider, resolution: $resolution, fileSize: $fileSize, createdAt: $createdAt, uploadedBy: $uploadedBy, desc: $desc, collections: $collections, tags: $tags, review: $review, aiMetadata: $aiMetadata)';
}


}

/// @nodoc
abstract mixin class _$PrismWallDocDtoCopyWith<$Res> implements $PrismWallDocDtoCopyWith<$Res> {
  factory _$PrismWallDocDtoCopyWith(_PrismWallDocDto value, $Res Function(_PrismWallDocDto) _then) = __$PrismWallDocDtoCopyWithImpl;
@override @useResult
$Res call({
@FirestoreStringConverter() String id,@JsonKey(name: 'wallpaper_url')@FirestoreStringConverter() String wallpaperUrl,@JsonKey(name: 'wallpaper_thumb')@FirestoreStringConverter() String wallpaperThumb,@JsonKey(name: 'wallpaper_provider')@FirestoreStringConverter() String wallpaperProvider,@FirestoreStringConverter() String resolution,@JsonKey(name: 'file_size') int? fileSize,@FirestoreDateTimeConverter() DateTime? createdAt,@JsonKey(name: 'uploadedBy')@FirestoreStringConverter() String uploadedBy,@FirestoreStringConverter() String desc,@FirestoreStringListConverter() List<String> collections,@FirestoreStringListConverter() List<String> tags, bool review,@JsonKey(name: 'aiMetadata')@FirestoreJsonMapConverter() Map<String, Object?> aiMetadata
});




}
/// @nodoc
class __$PrismWallDocDtoCopyWithImpl<$Res>
    implements _$PrismWallDocDtoCopyWith<$Res> {
  __$PrismWallDocDtoCopyWithImpl(this._self, this._then);

  final _PrismWallDocDto _self;
  final $Res Function(_PrismWallDocDto) _then;

/// Create a copy of PrismWallDocDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? wallpaperUrl = null,Object? wallpaperThumb = null,Object? wallpaperProvider = null,Object? resolution = null,Object? fileSize = freezed,Object? createdAt = freezed,Object? uploadedBy = null,Object? desc = null,Object? collections = null,Object? tags = null,Object? review = null,Object? aiMetadata = null,}) {
  return _then(_PrismWallDocDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,wallpaperUrl: null == wallpaperUrl ? _self.wallpaperUrl : wallpaperUrl // ignore: cast_nullable_to_non_nullable
as String,wallpaperThumb: null == wallpaperThumb ? _self.wallpaperThumb : wallpaperThumb // ignore: cast_nullable_to_non_nullable
as String,wallpaperProvider: null == wallpaperProvider ? _self.wallpaperProvider : wallpaperProvider // ignore: cast_nullable_to_non_nullable
as String,resolution: null == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as String,fileSize: freezed == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,uploadedBy: null == uploadedBy ? _self.uploadedBy : uploadedBy // ignore: cast_nullable_to_non_nullable
as String,desc: null == desc ? _self.desc : desc // ignore: cast_nullable_to_non_nullable
as String,collections: null == collections ? _self._collections : collections // ignore: cast_nullable_to_non_nullable
as List<String>,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,review: null == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as bool,aiMetadata: null == aiMetadata ? _self._aiMetadata : aiMetadata // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}

// dart format on
