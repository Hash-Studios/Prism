// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pexels_dtos.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PexelsSearchResponseDto {

 int get page;@JsonKey(name: 'per_page') int get perPage;@JsonKey(name: 'total_results') int get totalResults; List<PexelsPhotoDto> get photos;
/// Create a copy of PexelsSearchResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PexelsSearchResponseDtoCopyWith<PexelsSearchResponseDto> get copyWith => _$PexelsSearchResponseDtoCopyWithImpl<PexelsSearchResponseDto>(this as PexelsSearchResponseDto, _$identity);

  /// Serializes this PexelsSearchResponseDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PexelsSearchResponseDto&&(identical(other.page, page) || other.page == page)&&(identical(other.perPage, perPage) || other.perPage == perPage)&&(identical(other.totalResults, totalResults) || other.totalResults == totalResults)&&const DeepCollectionEquality().equals(other.photos, photos));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,page,perPage,totalResults,const DeepCollectionEquality().hash(photos));

@override
String toString() {
  return 'PexelsSearchResponseDto(page: $page, perPage: $perPage, totalResults: $totalResults, photos: $photos)';
}


}

/// @nodoc
abstract mixin class $PexelsSearchResponseDtoCopyWith<$Res>  {
  factory $PexelsSearchResponseDtoCopyWith(PexelsSearchResponseDto value, $Res Function(PexelsSearchResponseDto) _then) = _$PexelsSearchResponseDtoCopyWithImpl;
@useResult
$Res call({
 int page,@JsonKey(name: 'per_page') int perPage,@JsonKey(name: 'total_results') int totalResults, List<PexelsPhotoDto> photos
});




}
/// @nodoc
class _$PexelsSearchResponseDtoCopyWithImpl<$Res>
    implements $PexelsSearchResponseDtoCopyWith<$Res> {
  _$PexelsSearchResponseDtoCopyWithImpl(this._self, this._then);

  final PexelsSearchResponseDto _self;
  final $Res Function(PexelsSearchResponseDto) _then;

/// Create a copy of PexelsSearchResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? page = null,Object? perPage = null,Object? totalResults = null,Object? photos = null,}) {
  return _then(_self.copyWith(
page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,perPage: null == perPage ? _self.perPage : perPage // ignore: cast_nullable_to_non_nullable
as int,totalResults: null == totalResults ? _self.totalResults : totalResults // ignore: cast_nullable_to_non_nullable
as int,photos: null == photos ? _self.photos : photos // ignore: cast_nullable_to_non_nullable
as List<PexelsPhotoDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [PexelsSearchResponseDto].
extension PexelsSearchResponseDtoPatterns on PexelsSearchResponseDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PexelsSearchResponseDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PexelsSearchResponseDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PexelsSearchResponseDto value)  $default,){
final _that = this;
switch (_that) {
case _PexelsSearchResponseDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PexelsSearchResponseDto value)?  $default,){
final _that = this;
switch (_that) {
case _PexelsSearchResponseDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int page, @JsonKey(name: 'per_page')  int perPage, @JsonKey(name: 'total_results')  int totalResults,  List<PexelsPhotoDto> photos)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PexelsSearchResponseDto() when $default != null:
return $default(_that.page,_that.perPage,_that.totalResults,_that.photos);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int page, @JsonKey(name: 'per_page')  int perPage, @JsonKey(name: 'total_results')  int totalResults,  List<PexelsPhotoDto> photos)  $default,) {final _that = this;
switch (_that) {
case _PexelsSearchResponseDto():
return $default(_that.page,_that.perPage,_that.totalResults,_that.photos);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int page, @JsonKey(name: 'per_page')  int perPage, @JsonKey(name: 'total_results')  int totalResults,  List<PexelsPhotoDto> photos)?  $default,) {final _that = this;
switch (_that) {
case _PexelsSearchResponseDto() when $default != null:
return $default(_that.page,_that.perPage,_that.totalResults,_that.photos);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PexelsSearchResponseDto implements PexelsSearchResponseDto {
  const _PexelsSearchResponseDto({this.page = 1, @JsonKey(name: 'per_page') this.perPage = 0, @JsonKey(name: 'total_results') this.totalResults = 0, final  List<PexelsPhotoDto> photos = const <PexelsPhotoDto>[]}): _photos = photos;
  factory _PexelsSearchResponseDto.fromJson(Map<String, dynamic> json) => _$PexelsSearchResponseDtoFromJson(json);

@override@JsonKey() final  int page;
@override@JsonKey(name: 'per_page') final  int perPage;
@override@JsonKey(name: 'total_results') final  int totalResults;
 final  List<PexelsPhotoDto> _photos;
@override@JsonKey() List<PexelsPhotoDto> get photos {
  if (_photos is EqualUnmodifiableListView) return _photos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_photos);
}


/// Create a copy of PexelsSearchResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PexelsSearchResponseDtoCopyWith<_PexelsSearchResponseDto> get copyWith => __$PexelsSearchResponseDtoCopyWithImpl<_PexelsSearchResponseDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PexelsSearchResponseDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PexelsSearchResponseDto&&(identical(other.page, page) || other.page == page)&&(identical(other.perPage, perPage) || other.perPage == perPage)&&(identical(other.totalResults, totalResults) || other.totalResults == totalResults)&&const DeepCollectionEquality().equals(other._photos, _photos));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,page,perPage,totalResults,const DeepCollectionEquality().hash(_photos));

@override
String toString() {
  return 'PexelsSearchResponseDto(page: $page, perPage: $perPage, totalResults: $totalResults, photos: $photos)';
}


}

/// @nodoc
abstract mixin class _$PexelsSearchResponseDtoCopyWith<$Res> implements $PexelsSearchResponseDtoCopyWith<$Res> {
  factory _$PexelsSearchResponseDtoCopyWith(_PexelsSearchResponseDto value, $Res Function(_PexelsSearchResponseDto) _then) = __$PexelsSearchResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 int page,@JsonKey(name: 'per_page') int perPage,@JsonKey(name: 'total_results') int totalResults, List<PexelsPhotoDto> photos
});




}
/// @nodoc
class __$PexelsSearchResponseDtoCopyWithImpl<$Res>
    implements _$PexelsSearchResponseDtoCopyWith<$Res> {
  __$PexelsSearchResponseDtoCopyWithImpl(this._self, this._then);

  final _PexelsSearchResponseDto _self;
  final $Res Function(_PexelsSearchResponseDto) _then;

/// Create a copy of PexelsSearchResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? page = null,Object? perPage = null,Object? totalResults = null,Object? photos = null,}) {
  return _then(_PexelsSearchResponseDto(
page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,perPage: null == perPage ? _self.perPage : perPage // ignore: cast_nullable_to_non_nullable
as int,totalResults: null == totalResults ? _self.totalResults : totalResults // ignore: cast_nullable_to_non_nullable
as int,photos: null == photos ? _self._photos : photos // ignore: cast_nullable_to_non_nullable
as List<PexelsPhotoDto>,
  ));
}


}


/// @nodoc
mixin _$PexelsPhotoDto {

 int get id; int? get width; int? get height; String get url; String? get photographer;@JsonKey(name: 'photographer_url') String? get photographerUrl; PexelsSrcDto? get src;
/// Create a copy of PexelsPhotoDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PexelsPhotoDtoCopyWith<PexelsPhotoDto> get copyWith => _$PexelsPhotoDtoCopyWithImpl<PexelsPhotoDto>(this as PexelsPhotoDto, _$identity);

  /// Serializes this PexelsPhotoDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PexelsPhotoDto&&(identical(other.id, id) || other.id == id)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.url, url) || other.url == url)&&(identical(other.photographer, photographer) || other.photographer == photographer)&&(identical(other.photographerUrl, photographerUrl) || other.photographerUrl == photographerUrl)&&(identical(other.src, src) || other.src == src));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,width,height,url,photographer,photographerUrl,src);

@override
String toString() {
  return 'PexelsPhotoDto(id: $id, width: $width, height: $height, url: $url, photographer: $photographer, photographerUrl: $photographerUrl, src: $src)';
}


}

/// @nodoc
abstract mixin class $PexelsPhotoDtoCopyWith<$Res>  {
  factory $PexelsPhotoDtoCopyWith(PexelsPhotoDto value, $Res Function(PexelsPhotoDto) _then) = _$PexelsPhotoDtoCopyWithImpl;
@useResult
$Res call({
 int id, int? width, int? height, String url, String? photographer,@JsonKey(name: 'photographer_url') String? photographerUrl, PexelsSrcDto? src
});


$PexelsSrcDtoCopyWith<$Res>? get src;

}
/// @nodoc
class _$PexelsPhotoDtoCopyWithImpl<$Res>
    implements $PexelsPhotoDtoCopyWith<$Res> {
  _$PexelsPhotoDtoCopyWithImpl(this._self, this._then);

  final PexelsPhotoDto _self;
  final $Res Function(PexelsPhotoDto) _then;

/// Create a copy of PexelsPhotoDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? width = freezed,Object? height = freezed,Object? url = null,Object? photographer = freezed,Object? photographerUrl = freezed,Object? src = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,photographer: freezed == photographer ? _self.photographer : photographer // ignore: cast_nullable_to_non_nullable
as String?,photographerUrl: freezed == photographerUrl ? _self.photographerUrl : photographerUrl // ignore: cast_nullable_to_non_nullable
as String?,src: freezed == src ? _self.src : src // ignore: cast_nullable_to_non_nullable
as PexelsSrcDto?,
  ));
}
/// Create a copy of PexelsPhotoDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PexelsSrcDtoCopyWith<$Res>? get src {
    if (_self.src == null) {
    return null;
  }

  return $PexelsSrcDtoCopyWith<$Res>(_self.src!, (value) {
    return _then(_self.copyWith(src: value));
  });
}
}


/// Adds pattern-matching-related methods to [PexelsPhotoDto].
extension PexelsPhotoDtoPatterns on PexelsPhotoDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PexelsPhotoDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PexelsPhotoDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PexelsPhotoDto value)  $default,){
final _that = this;
switch (_that) {
case _PexelsPhotoDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PexelsPhotoDto value)?  $default,){
final _that = this;
switch (_that) {
case _PexelsPhotoDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int? width,  int? height,  String url,  String? photographer, @JsonKey(name: 'photographer_url')  String? photographerUrl,  PexelsSrcDto? src)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PexelsPhotoDto() when $default != null:
return $default(_that.id,_that.width,_that.height,_that.url,_that.photographer,_that.photographerUrl,_that.src);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int? width,  int? height,  String url,  String? photographer, @JsonKey(name: 'photographer_url')  String? photographerUrl,  PexelsSrcDto? src)  $default,) {final _that = this;
switch (_that) {
case _PexelsPhotoDto():
return $default(_that.id,_that.width,_that.height,_that.url,_that.photographer,_that.photographerUrl,_that.src);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int? width,  int? height,  String url,  String? photographer, @JsonKey(name: 'photographer_url')  String? photographerUrl,  PexelsSrcDto? src)?  $default,) {final _that = this;
switch (_that) {
case _PexelsPhotoDto() when $default != null:
return $default(_that.id,_that.width,_that.height,_that.url,_that.photographer,_that.photographerUrl,_that.src);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PexelsPhotoDto implements PexelsPhotoDto {
  const _PexelsPhotoDto({required this.id, this.width, this.height, this.url = '', this.photographer, @JsonKey(name: 'photographer_url') this.photographerUrl, this.src});
  factory _PexelsPhotoDto.fromJson(Map<String, dynamic> json) => _$PexelsPhotoDtoFromJson(json);

@override final  int id;
@override final  int? width;
@override final  int? height;
@override@JsonKey() final  String url;
@override final  String? photographer;
@override@JsonKey(name: 'photographer_url') final  String? photographerUrl;
@override final  PexelsSrcDto? src;

/// Create a copy of PexelsPhotoDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PexelsPhotoDtoCopyWith<_PexelsPhotoDto> get copyWith => __$PexelsPhotoDtoCopyWithImpl<_PexelsPhotoDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PexelsPhotoDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PexelsPhotoDto&&(identical(other.id, id) || other.id == id)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.url, url) || other.url == url)&&(identical(other.photographer, photographer) || other.photographer == photographer)&&(identical(other.photographerUrl, photographerUrl) || other.photographerUrl == photographerUrl)&&(identical(other.src, src) || other.src == src));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,width,height,url,photographer,photographerUrl,src);

@override
String toString() {
  return 'PexelsPhotoDto(id: $id, width: $width, height: $height, url: $url, photographer: $photographer, photographerUrl: $photographerUrl, src: $src)';
}


}

/// @nodoc
abstract mixin class _$PexelsPhotoDtoCopyWith<$Res> implements $PexelsPhotoDtoCopyWith<$Res> {
  factory _$PexelsPhotoDtoCopyWith(_PexelsPhotoDto value, $Res Function(_PexelsPhotoDto) _then) = __$PexelsPhotoDtoCopyWithImpl;
@override @useResult
$Res call({
 int id, int? width, int? height, String url, String? photographer,@JsonKey(name: 'photographer_url') String? photographerUrl, PexelsSrcDto? src
});


@override $PexelsSrcDtoCopyWith<$Res>? get src;

}
/// @nodoc
class __$PexelsPhotoDtoCopyWithImpl<$Res>
    implements _$PexelsPhotoDtoCopyWith<$Res> {
  __$PexelsPhotoDtoCopyWithImpl(this._self, this._then);

  final _PexelsPhotoDto _self;
  final $Res Function(_PexelsPhotoDto) _then;

/// Create a copy of PexelsPhotoDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? width = freezed,Object? height = freezed,Object? url = null,Object? photographer = freezed,Object? photographerUrl = freezed,Object? src = freezed,}) {
  return _then(_PexelsPhotoDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,photographer: freezed == photographer ? _self.photographer : photographer // ignore: cast_nullable_to_non_nullable
as String?,photographerUrl: freezed == photographerUrl ? _self.photographerUrl : photographerUrl // ignore: cast_nullable_to_non_nullable
as String?,src: freezed == src ? _self.src : src // ignore: cast_nullable_to_non_nullable
as PexelsSrcDto?,
  ));
}

/// Create a copy of PexelsPhotoDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PexelsSrcDtoCopyWith<$Res>? get src {
    if (_self.src == null) {
    return null;
  }

  return $PexelsSrcDtoCopyWith<$Res>(_self.src!, (value) {
    return _then(_self.copyWith(src: value));
  });
}
}


/// @nodoc
mixin _$PexelsSrcDto {

 String get original; String? get large2x; String? get large; String? get medium; String? get small; String? get portrait; String? get landscape; String? get tiny;
/// Create a copy of PexelsSrcDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PexelsSrcDtoCopyWith<PexelsSrcDto> get copyWith => _$PexelsSrcDtoCopyWithImpl<PexelsSrcDto>(this as PexelsSrcDto, _$identity);

  /// Serializes this PexelsSrcDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PexelsSrcDto&&(identical(other.original, original) || other.original == original)&&(identical(other.large2x, large2x) || other.large2x == large2x)&&(identical(other.large, large) || other.large == large)&&(identical(other.medium, medium) || other.medium == medium)&&(identical(other.small, small) || other.small == small)&&(identical(other.portrait, portrait) || other.portrait == portrait)&&(identical(other.landscape, landscape) || other.landscape == landscape)&&(identical(other.tiny, tiny) || other.tiny == tiny));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,original,large2x,large,medium,small,portrait,landscape,tiny);

@override
String toString() {
  return 'PexelsSrcDto(original: $original, large2x: $large2x, large: $large, medium: $medium, small: $small, portrait: $portrait, landscape: $landscape, tiny: $tiny)';
}


}

/// @nodoc
abstract mixin class $PexelsSrcDtoCopyWith<$Res>  {
  factory $PexelsSrcDtoCopyWith(PexelsSrcDto value, $Res Function(PexelsSrcDto) _then) = _$PexelsSrcDtoCopyWithImpl;
@useResult
$Res call({
 String original, String? large2x, String? large, String? medium, String? small, String? portrait, String? landscape, String? tiny
});




}
/// @nodoc
class _$PexelsSrcDtoCopyWithImpl<$Res>
    implements $PexelsSrcDtoCopyWith<$Res> {
  _$PexelsSrcDtoCopyWithImpl(this._self, this._then);

  final PexelsSrcDto _self;
  final $Res Function(PexelsSrcDto) _then;

/// Create a copy of PexelsSrcDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? original = null,Object? large2x = freezed,Object? large = freezed,Object? medium = freezed,Object? small = freezed,Object? portrait = freezed,Object? landscape = freezed,Object? tiny = freezed,}) {
  return _then(_self.copyWith(
original: null == original ? _self.original : original // ignore: cast_nullable_to_non_nullable
as String,large2x: freezed == large2x ? _self.large2x : large2x // ignore: cast_nullable_to_non_nullable
as String?,large: freezed == large ? _self.large : large // ignore: cast_nullable_to_non_nullable
as String?,medium: freezed == medium ? _self.medium : medium // ignore: cast_nullable_to_non_nullable
as String?,small: freezed == small ? _self.small : small // ignore: cast_nullable_to_non_nullable
as String?,portrait: freezed == portrait ? _self.portrait : portrait // ignore: cast_nullable_to_non_nullable
as String?,landscape: freezed == landscape ? _self.landscape : landscape // ignore: cast_nullable_to_non_nullable
as String?,tiny: freezed == tiny ? _self.tiny : tiny // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PexelsSrcDto].
extension PexelsSrcDtoPatterns on PexelsSrcDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PexelsSrcDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PexelsSrcDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PexelsSrcDto value)  $default,){
final _that = this;
switch (_that) {
case _PexelsSrcDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PexelsSrcDto value)?  $default,){
final _that = this;
switch (_that) {
case _PexelsSrcDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String original,  String? large2x,  String? large,  String? medium,  String? small,  String? portrait,  String? landscape,  String? tiny)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PexelsSrcDto() when $default != null:
return $default(_that.original,_that.large2x,_that.large,_that.medium,_that.small,_that.portrait,_that.landscape,_that.tiny);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String original,  String? large2x,  String? large,  String? medium,  String? small,  String? portrait,  String? landscape,  String? tiny)  $default,) {final _that = this;
switch (_that) {
case _PexelsSrcDto():
return $default(_that.original,_that.large2x,_that.large,_that.medium,_that.small,_that.portrait,_that.landscape,_that.tiny);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String original,  String? large2x,  String? large,  String? medium,  String? small,  String? portrait,  String? landscape,  String? tiny)?  $default,) {final _that = this;
switch (_that) {
case _PexelsSrcDto() when $default != null:
return $default(_that.original,_that.large2x,_that.large,_that.medium,_that.small,_that.portrait,_that.landscape,_that.tiny);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PexelsSrcDto implements PexelsSrcDto {
  const _PexelsSrcDto({this.original = '', this.large2x, this.large, this.medium, this.small, this.portrait, this.landscape, this.tiny});
  factory _PexelsSrcDto.fromJson(Map<String, dynamic> json) => _$PexelsSrcDtoFromJson(json);

@override@JsonKey() final  String original;
@override final  String? large2x;
@override final  String? large;
@override final  String? medium;
@override final  String? small;
@override final  String? portrait;
@override final  String? landscape;
@override final  String? tiny;

/// Create a copy of PexelsSrcDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PexelsSrcDtoCopyWith<_PexelsSrcDto> get copyWith => __$PexelsSrcDtoCopyWithImpl<_PexelsSrcDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PexelsSrcDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PexelsSrcDto&&(identical(other.original, original) || other.original == original)&&(identical(other.large2x, large2x) || other.large2x == large2x)&&(identical(other.large, large) || other.large == large)&&(identical(other.medium, medium) || other.medium == medium)&&(identical(other.small, small) || other.small == small)&&(identical(other.portrait, portrait) || other.portrait == portrait)&&(identical(other.landscape, landscape) || other.landscape == landscape)&&(identical(other.tiny, tiny) || other.tiny == tiny));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,original,large2x,large,medium,small,portrait,landscape,tiny);

@override
String toString() {
  return 'PexelsSrcDto(original: $original, large2x: $large2x, large: $large, medium: $medium, small: $small, portrait: $portrait, landscape: $landscape, tiny: $tiny)';
}


}

/// @nodoc
abstract mixin class _$PexelsSrcDtoCopyWith<$Res> implements $PexelsSrcDtoCopyWith<$Res> {
  factory _$PexelsSrcDtoCopyWith(_PexelsSrcDto value, $Res Function(_PexelsSrcDto) _then) = __$PexelsSrcDtoCopyWithImpl;
@override @useResult
$Res call({
 String original, String? large2x, String? large, String? medium, String? small, String? portrait, String? landscape, String? tiny
});




}
/// @nodoc
class __$PexelsSrcDtoCopyWithImpl<$Res>
    implements _$PexelsSrcDtoCopyWith<$Res> {
  __$PexelsSrcDtoCopyWithImpl(this._self, this._then);

  final _PexelsSrcDto _self;
  final $Res Function(_PexelsSrcDto) _then;

/// Create a copy of PexelsSrcDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? original = null,Object? large2x = freezed,Object? large = freezed,Object? medium = freezed,Object? small = freezed,Object? portrait = freezed,Object? landscape = freezed,Object? tiny = freezed,}) {
  return _then(_PexelsSrcDto(
original: null == original ? _self.original : original // ignore: cast_nullable_to_non_nullable
as String,large2x: freezed == large2x ? _self.large2x : large2x // ignore: cast_nullable_to_non_nullable
as String?,large: freezed == large ? _self.large : large // ignore: cast_nullable_to_non_nullable
as String?,medium: freezed == medium ? _self.medium : medium // ignore: cast_nullable_to_non_nullable
as String?,small: freezed == small ? _self.small : small // ignore: cast_nullable_to_non_nullable
as String?,portrait: freezed == portrait ? _self.portrait : portrait // ignore: cast_nullable_to_non_nullable
as String?,landscape: freezed == landscape ? _self.landscape : landscape // ignore: cast_nullable_to_non_nullable
as String?,tiny: freezed == tiny ? _self.tiny : tiny // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
