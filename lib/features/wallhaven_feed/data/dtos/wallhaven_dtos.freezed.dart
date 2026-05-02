// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wallhaven_dtos.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WallhavenSearchResponseDto {

 List<WallhavenWallpaperDto> get data; WallhavenMetaDto? get meta;
/// Create a copy of WallhavenSearchResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WallhavenSearchResponseDtoCopyWith<WallhavenSearchResponseDto> get copyWith => _$WallhavenSearchResponseDtoCopyWithImpl<WallhavenSearchResponseDto>(this as WallhavenSearchResponseDto, _$identity);

  /// Serializes this WallhavenSearchResponseDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WallhavenSearchResponseDto&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.meta, meta) || other.meta == meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data),meta);

@override
String toString() {
  return 'WallhavenSearchResponseDto(data: $data, meta: $meta)';
}


}

/// @nodoc
abstract mixin class $WallhavenSearchResponseDtoCopyWith<$Res>  {
  factory $WallhavenSearchResponseDtoCopyWith(WallhavenSearchResponseDto value, $Res Function(WallhavenSearchResponseDto) _then) = _$WallhavenSearchResponseDtoCopyWithImpl;
@useResult
$Res call({
 List<WallhavenWallpaperDto> data, WallhavenMetaDto? meta
});


$WallhavenMetaDtoCopyWith<$Res>? get meta;

}
/// @nodoc
class _$WallhavenSearchResponseDtoCopyWithImpl<$Res>
    implements $WallhavenSearchResponseDtoCopyWith<$Res> {
  _$WallhavenSearchResponseDtoCopyWithImpl(this._self, this._then);

  final WallhavenSearchResponseDto _self;
  final $Res Function(WallhavenSearchResponseDto) _then;

/// Create a copy of WallhavenSearchResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? meta = freezed,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<WallhavenWallpaperDto>,meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as WallhavenMetaDto?,
  ));
}
/// Create a copy of WallhavenSearchResponseDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WallhavenMetaDtoCopyWith<$Res>? get meta {
    if (_self.meta == null) {
    return null;
  }

  return $WallhavenMetaDtoCopyWith<$Res>(_self.meta!, (value) {
    return _then(_self.copyWith(meta: value));
  });
}
}


/// Adds pattern-matching-related methods to [WallhavenSearchResponseDto].
extension WallhavenSearchResponseDtoPatterns on WallhavenSearchResponseDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WallhavenSearchResponseDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WallhavenSearchResponseDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WallhavenSearchResponseDto value)  $default,){
final _that = this;
switch (_that) {
case _WallhavenSearchResponseDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WallhavenSearchResponseDto value)?  $default,){
final _that = this;
switch (_that) {
case _WallhavenSearchResponseDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<WallhavenWallpaperDto> data,  WallhavenMetaDto? meta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WallhavenSearchResponseDto() when $default != null:
return $default(_that.data,_that.meta);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<WallhavenWallpaperDto> data,  WallhavenMetaDto? meta)  $default,) {final _that = this;
switch (_that) {
case _WallhavenSearchResponseDto():
return $default(_that.data,_that.meta);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<WallhavenWallpaperDto> data,  WallhavenMetaDto? meta)?  $default,) {final _that = this;
switch (_that) {
case _WallhavenSearchResponseDto() when $default != null:
return $default(_that.data,_that.meta);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WallhavenSearchResponseDto implements WallhavenSearchResponseDto {
  const _WallhavenSearchResponseDto({final  List<WallhavenWallpaperDto> data = const <WallhavenWallpaperDto>[], this.meta}): _data = data;
  factory _WallhavenSearchResponseDto.fromJson(Map<String, dynamic> json) => _$WallhavenSearchResponseDtoFromJson(json);

 final  List<WallhavenWallpaperDto> _data;
@override@JsonKey() List<WallhavenWallpaperDto> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

@override final  WallhavenMetaDto? meta;

/// Create a copy of WallhavenSearchResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WallhavenSearchResponseDtoCopyWith<_WallhavenSearchResponseDto> get copyWith => __$WallhavenSearchResponseDtoCopyWithImpl<_WallhavenSearchResponseDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WallhavenSearchResponseDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WallhavenSearchResponseDto&&const DeepCollectionEquality().equals(other._data, _data)&&(identical(other.meta, meta) || other.meta == meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),meta);

@override
String toString() {
  return 'WallhavenSearchResponseDto(data: $data, meta: $meta)';
}


}

/// @nodoc
abstract mixin class _$WallhavenSearchResponseDtoCopyWith<$Res> implements $WallhavenSearchResponseDtoCopyWith<$Res> {
  factory _$WallhavenSearchResponseDtoCopyWith(_WallhavenSearchResponseDto value, $Res Function(_WallhavenSearchResponseDto) _then) = __$WallhavenSearchResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 List<WallhavenWallpaperDto> data, WallhavenMetaDto? meta
});


@override $WallhavenMetaDtoCopyWith<$Res>? get meta;

}
/// @nodoc
class __$WallhavenSearchResponseDtoCopyWithImpl<$Res>
    implements _$WallhavenSearchResponseDtoCopyWith<$Res> {
  __$WallhavenSearchResponseDtoCopyWithImpl(this._self, this._then);

  final _WallhavenSearchResponseDto _self;
  final $Res Function(_WallhavenSearchResponseDto) _then;

/// Create a copy of WallhavenSearchResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? meta = freezed,}) {
  return _then(_WallhavenSearchResponseDto(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<WallhavenWallpaperDto>,meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as WallhavenMetaDto?,
  ));
}

/// Create a copy of WallhavenSearchResponseDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WallhavenMetaDtoCopyWith<$Res>? get meta {
    if (_self.meta == null) {
    return null;
  }

  return $WallhavenMetaDtoCopyWith<$Res>(_self.meta!, (value) {
    return _then(_self.copyWith(meta: value));
  });
}
}


/// @nodoc
mixin _$WallhavenSingleResponseDto {

 WallhavenWallpaperDto? get data;
/// Create a copy of WallhavenSingleResponseDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WallhavenSingleResponseDtoCopyWith<WallhavenSingleResponseDto> get copyWith => _$WallhavenSingleResponseDtoCopyWithImpl<WallhavenSingleResponseDto>(this as WallhavenSingleResponseDto, _$identity);

  /// Serializes this WallhavenSingleResponseDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WallhavenSingleResponseDto&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'WallhavenSingleResponseDto(data: $data)';
}


}

/// @nodoc
abstract mixin class $WallhavenSingleResponseDtoCopyWith<$Res>  {
  factory $WallhavenSingleResponseDtoCopyWith(WallhavenSingleResponseDto value, $Res Function(WallhavenSingleResponseDto) _then) = _$WallhavenSingleResponseDtoCopyWithImpl;
@useResult
$Res call({
 WallhavenWallpaperDto? data
});


$WallhavenWallpaperDtoCopyWith<$Res>? get data;

}
/// @nodoc
class _$WallhavenSingleResponseDtoCopyWithImpl<$Res>
    implements $WallhavenSingleResponseDtoCopyWith<$Res> {
  _$WallhavenSingleResponseDtoCopyWithImpl(this._self, this._then);

  final WallhavenSingleResponseDto _self;
  final $Res Function(WallhavenSingleResponseDto) _then;

/// Create a copy of WallhavenSingleResponseDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = freezed,}) {
  return _then(_self.copyWith(
data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as WallhavenWallpaperDto?,
  ));
}
/// Create a copy of WallhavenSingleResponseDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WallhavenWallpaperDtoCopyWith<$Res>? get data {
    if (_self.data == null) {
    return null;
  }

  return $WallhavenWallpaperDtoCopyWith<$Res>(_self.data!, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [WallhavenSingleResponseDto].
extension WallhavenSingleResponseDtoPatterns on WallhavenSingleResponseDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WallhavenSingleResponseDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WallhavenSingleResponseDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WallhavenSingleResponseDto value)  $default,){
final _that = this;
switch (_that) {
case _WallhavenSingleResponseDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WallhavenSingleResponseDto value)?  $default,){
final _that = this;
switch (_that) {
case _WallhavenSingleResponseDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WallhavenWallpaperDto? data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WallhavenSingleResponseDto() when $default != null:
return $default(_that.data);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WallhavenWallpaperDto? data)  $default,) {final _that = this;
switch (_that) {
case _WallhavenSingleResponseDto():
return $default(_that.data);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WallhavenWallpaperDto? data)?  $default,) {final _that = this;
switch (_that) {
case _WallhavenSingleResponseDto() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WallhavenSingleResponseDto implements WallhavenSingleResponseDto {
  const _WallhavenSingleResponseDto({this.data});
  factory _WallhavenSingleResponseDto.fromJson(Map<String, dynamic> json) => _$WallhavenSingleResponseDtoFromJson(json);

@override final  WallhavenWallpaperDto? data;

/// Create a copy of WallhavenSingleResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WallhavenSingleResponseDtoCopyWith<_WallhavenSingleResponseDto> get copyWith => __$WallhavenSingleResponseDtoCopyWithImpl<_WallhavenSingleResponseDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WallhavenSingleResponseDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WallhavenSingleResponseDto&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'WallhavenSingleResponseDto(data: $data)';
}


}

/// @nodoc
abstract mixin class _$WallhavenSingleResponseDtoCopyWith<$Res> implements $WallhavenSingleResponseDtoCopyWith<$Res> {
  factory _$WallhavenSingleResponseDtoCopyWith(_WallhavenSingleResponseDto value, $Res Function(_WallhavenSingleResponseDto) _then) = __$WallhavenSingleResponseDtoCopyWithImpl;
@override @useResult
$Res call({
 WallhavenWallpaperDto? data
});


@override $WallhavenWallpaperDtoCopyWith<$Res>? get data;

}
/// @nodoc
class __$WallhavenSingleResponseDtoCopyWithImpl<$Res>
    implements _$WallhavenSingleResponseDtoCopyWith<$Res> {
  __$WallhavenSingleResponseDtoCopyWithImpl(this._self, this._then);

  final _WallhavenSingleResponseDto _self;
  final $Res Function(_WallhavenSingleResponseDto) _then;

/// Create a copy of WallhavenSingleResponseDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = freezed,}) {
  return _then(_WallhavenSingleResponseDto(
data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as WallhavenWallpaperDto?,
  ));
}

/// Create a copy of WallhavenSingleResponseDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WallhavenWallpaperDtoCopyWith<$Res>? get data {
    if (_self.data == null) {
    return null;
  }

  return $WallhavenWallpaperDtoCopyWith<$Res>(_self.data!, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// @nodoc
mixin _$WallhavenMetaDto {

@JsonKey(name: 'current_page') int get currentPage;@JsonKey(name: 'last_page') int get lastPage;
/// Create a copy of WallhavenMetaDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WallhavenMetaDtoCopyWith<WallhavenMetaDto> get copyWith => _$WallhavenMetaDtoCopyWithImpl<WallhavenMetaDto>(this as WallhavenMetaDto, _$identity);

  /// Serializes this WallhavenMetaDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WallhavenMetaDto&&(identical(other.currentPage, currentPage) || other.currentPage == currentPage)&&(identical(other.lastPage, lastPage) || other.lastPage == lastPage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,currentPage,lastPage);

@override
String toString() {
  return 'WallhavenMetaDto(currentPage: $currentPage, lastPage: $lastPage)';
}


}

/// @nodoc
abstract mixin class $WallhavenMetaDtoCopyWith<$Res>  {
  factory $WallhavenMetaDtoCopyWith(WallhavenMetaDto value, $Res Function(WallhavenMetaDto) _then) = _$WallhavenMetaDtoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'current_page') int currentPage,@JsonKey(name: 'last_page') int lastPage
});




}
/// @nodoc
class _$WallhavenMetaDtoCopyWithImpl<$Res>
    implements $WallhavenMetaDtoCopyWith<$Res> {
  _$WallhavenMetaDtoCopyWithImpl(this._self, this._then);

  final WallhavenMetaDto _self;
  final $Res Function(WallhavenMetaDto) _then;

/// Create a copy of WallhavenMetaDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentPage = null,Object? lastPage = null,}) {
  return _then(_self.copyWith(
currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,lastPage: null == lastPage ? _self.lastPage : lastPage // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [WallhavenMetaDto].
extension WallhavenMetaDtoPatterns on WallhavenMetaDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WallhavenMetaDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WallhavenMetaDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WallhavenMetaDto value)  $default,){
final _that = this;
switch (_that) {
case _WallhavenMetaDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WallhavenMetaDto value)?  $default,){
final _that = this;
switch (_that) {
case _WallhavenMetaDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'last_page')  int lastPage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WallhavenMetaDto() when $default != null:
return $default(_that.currentPage,_that.lastPage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'last_page')  int lastPage)  $default,) {final _that = this;
switch (_that) {
case _WallhavenMetaDto():
return $default(_that.currentPage,_that.lastPage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'current_page')  int currentPage, @JsonKey(name: 'last_page')  int lastPage)?  $default,) {final _that = this;
switch (_that) {
case _WallhavenMetaDto() when $default != null:
return $default(_that.currentPage,_that.lastPage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WallhavenMetaDto implements WallhavenMetaDto {
  const _WallhavenMetaDto({@JsonKey(name: 'current_page') this.currentPage = 1, @JsonKey(name: 'last_page') this.lastPage = 1});
  factory _WallhavenMetaDto.fromJson(Map<String, dynamic> json) => _$WallhavenMetaDtoFromJson(json);

@override@JsonKey(name: 'current_page') final  int currentPage;
@override@JsonKey(name: 'last_page') final  int lastPage;

/// Create a copy of WallhavenMetaDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WallhavenMetaDtoCopyWith<_WallhavenMetaDto> get copyWith => __$WallhavenMetaDtoCopyWithImpl<_WallhavenMetaDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WallhavenMetaDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WallhavenMetaDto&&(identical(other.currentPage, currentPage) || other.currentPage == currentPage)&&(identical(other.lastPage, lastPage) || other.lastPage == lastPage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,currentPage,lastPage);

@override
String toString() {
  return 'WallhavenMetaDto(currentPage: $currentPage, lastPage: $lastPage)';
}


}

/// @nodoc
abstract mixin class _$WallhavenMetaDtoCopyWith<$Res> implements $WallhavenMetaDtoCopyWith<$Res> {
  factory _$WallhavenMetaDtoCopyWith(_WallhavenMetaDto value, $Res Function(_WallhavenMetaDto) _then) = __$WallhavenMetaDtoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'current_page') int currentPage,@JsonKey(name: 'last_page') int lastPage
});




}
/// @nodoc
class __$WallhavenMetaDtoCopyWithImpl<$Res>
    implements _$WallhavenMetaDtoCopyWith<$Res> {
  __$WallhavenMetaDtoCopyWithImpl(this._self, this._then);

  final _WallhavenMetaDto _self;
  final $Res Function(_WallhavenMetaDto) _then;

/// Create a copy of WallhavenMetaDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currentPage = null,Object? lastPage = null,}) {
  return _then(_WallhavenMetaDto(
currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,lastPage: null == lastPage ? _self.lastPage : lastPage // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$WallhavenUploaderDto {

 String? get username;
/// Create a copy of WallhavenUploaderDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WallhavenUploaderDtoCopyWith<WallhavenUploaderDto> get copyWith => _$WallhavenUploaderDtoCopyWithImpl<WallhavenUploaderDto>(this as WallhavenUploaderDto, _$identity);

  /// Serializes this WallhavenUploaderDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WallhavenUploaderDto&&(identical(other.username, username) || other.username == username));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,username);

@override
String toString() {
  return 'WallhavenUploaderDto(username: $username)';
}


}

/// @nodoc
abstract mixin class $WallhavenUploaderDtoCopyWith<$Res>  {
  factory $WallhavenUploaderDtoCopyWith(WallhavenUploaderDto value, $Res Function(WallhavenUploaderDto) _then) = _$WallhavenUploaderDtoCopyWithImpl;
@useResult
$Res call({
 String? username
});




}
/// @nodoc
class _$WallhavenUploaderDtoCopyWithImpl<$Res>
    implements $WallhavenUploaderDtoCopyWith<$Res> {
  _$WallhavenUploaderDtoCopyWithImpl(this._self, this._then);

  final WallhavenUploaderDto _self;
  final $Res Function(WallhavenUploaderDto) _then;

/// Create a copy of WallhavenUploaderDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? username = freezed,}) {
  return _then(_self.copyWith(
username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [WallhavenUploaderDto].
extension WallhavenUploaderDtoPatterns on WallhavenUploaderDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WallhavenUploaderDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WallhavenUploaderDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WallhavenUploaderDto value)  $default,){
final _that = this;
switch (_that) {
case _WallhavenUploaderDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WallhavenUploaderDto value)?  $default,){
final _that = this;
switch (_that) {
case _WallhavenUploaderDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? username)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WallhavenUploaderDto() when $default != null:
return $default(_that.username);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? username)  $default,) {final _that = this;
switch (_that) {
case _WallhavenUploaderDto():
return $default(_that.username);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? username)?  $default,) {final _that = this;
switch (_that) {
case _WallhavenUploaderDto() when $default != null:
return $default(_that.username);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WallhavenUploaderDto implements WallhavenUploaderDto {
  const _WallhavenUploaderDto({this.username});
  factory _WallhavenUploaderDto.fromJson(Map<String, dynamic> json) => _$WallhavenUploaderDtoFromJson(json);

@override final  String? username;

/// Create a copy of WallhavenUploaderDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WallhavenUploaderDtoCopyWith<_WallhavenUploaderDto> get copyWith => __$WallhavenUploaderDtoCopyWithImpl<_WallhavenUploaderDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WallhavenUploaderDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WallhavenUploaderDto&&(identical(other.username, username) || other.username == username));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,username);

@override
String toString() {
  return 'WallhavenUploaderDto(username: $username)';
}


}

/// @nodoc
abstract mixin class _$WallhavenUploaderDtoCopyWith<$Res> implements $WallhavenUploaderDtoCopyWith<$Res> {
  factory _$WallhavenUploaderDtoCopyWith(_WallhavenUploaderDto value, $Res Function(_WallhavenUploaderDto) _then) = __$WallhavenUploaderDtoCopyWithImpl;
@override @useResult
$Res call({
 String? username
});




}
/// @nodoc
class __$WallhavenUploaderDtoCopyWithImpl<$Res>
    implements _$WallhavenUploaderDtoCopyWith<$Res> {
  __$WallhavenUploaderDtoCopyWithImpl(this._self, this._then);

  final _WallhavenUploaderDto _self;
  final $Res Function(_WallhavenUploaderDto) _then;

/// Create a copy of WallhavenUploaderDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? username = freezed,}) {
  return _then(_WallhavenUploaderDto(
username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$WallhavenWallpaperDto {

 String get id; String get path; String get resolution;@JsonKey(name: 'file_size') int? get fileSize; String get category; int? get views;@JsonKey(name: 'favorites') int? get favorites;@JsonKey(name: 'dimension_x') int? get dimensionX;@JsonKey(name: 'dimension_y') int? get dimensionY; List<String> get colors; WallhavenThumbsDto? get thumbs; List<WallhavenTagDto> get tags; WallhavenUploaderDto? get uploader;
/// Create a copy of WallhavenWallpaperDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WallhavenWallpaperDtoCopyWith<WallhavenWallpaperDto> get copyWith => _$WallhavenWallpaperDtoCopyWithImpl<WallhavenWallpaperDto>(this as WallhavenWallpaperDto, _$identity);

  /// Serializes this WallhavenWallpaperDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WallhavenWallpaperDto&&(identical(other.id, id) || other.id == id)&&(identical(other.path, path) || other.path == path)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize)&&(identical(other.category, category) || other.category == category)&&(identical(other.views, views) || other.views == views)&&(identical(other.favorites, favorites) || other.favorites == favorites)&&(identical(other.dimensionX, dimensionX) || other.dimensionX == dimensionX)&&(identical(other.dimensionY, dimensionY) || other.dimensionY == dimensionY)&&const DeepCollectionEquality().equals(other.colors, colors)&&(identical(other.thumbs, thumbs) || other.thumbs == thumbs)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.uploader, uploader) || other.uploader == uploader));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,path,resolution,fileSize,category,views,favorites,dimensionX,dimensionY,const DeepCollectionEquality().hash(colors),thumbs,const DeepCollectionEquality().hash(tags),uploader);

@override
String toString() {
  return 'WallhavenWallpaperDto(id: $id, path: $path, resolution: $resolution, fileSize: $fileSize, category: $category, views: $views, favorites: $favorites, dimensionX: $dimensionX, dimensionY: $dimensionY, colors: $colors, thumbs: $thumbs, tags: $tags, uploader: $uploader)';
}


}

/// @nodoc
abstract mixin class $WallhavenWallpaperDtoCopyWith<$Res>  {
  factory $WallhavenWallpaperDtoCopyWith(WallhavenWallpaperDto value, $Res Function(WallhavenWallpaperDto) _then) = _$WallhavenWallpaperDtoCopyWithImpl;
@useResult
$Res call({
 String id, String path, String resolution,@JsonKey(name: 'file_size') int? fileSize, String category, int? views,@JsonKey(name: 'favorites') int? favorites,@JsonKey(name: 'dimension_x') int? dimensionX,@JsonKey(name: 'dimension_y') int? dimensionY, List<String> colors, WallhavenThumbsDto? thumbs, List<WallhavenTagDto> tags, WallhavenUploaderDto? uploader
});


$WallhavenThumbsDtoCopyWith<$Res>? get thumbs;$WallhavenUploaderDtoCopyWith<$Res>? get uploader;

}
/// @nodoc
class _$WallhavenWallpaperDtoCopyWithImpl<$Res>
    implements $WallhavenWallpaperDtoCopyWith<$Res> {
  _$WallhavenWallpaperDtoCopyWithImpl(this._self, this._then);

  final WallhavenWallpaperDto _self;
  final $Res Function(WallhavenWallpaperDto) _then;

/// Create a copy of WallhavenWallpaperDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? path = null,Object? resolution = null,Object? fileSize = freezed,Object? category = null,Object? views = freezed,Object? favorites = freezed,Object? dimensionX = freezed,Object? dimensionY = freezed,Object? colors = null,Object? thumbs = freezed,Object? tags = null,Object? uploader = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,resolution: null == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as String,fileSize: freezed == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int?,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,views: freezed == views ? _self.views : views // ignore: cast_nullable_to_non_nullable
as int?,favorites: freezed == favorites ? _self.favorites : favorites // ignore: cast_nullable_to_non_nullable
as int?,dimensionX: freezed == dimensionX ? _self.dimensionX : dimensionX // ignore: cast_nullable_to_non_nullable
as int?,dimensionY: freezed == dimensionY ? _self.dimensionY : dimensionY // ignore: cast_nullable_to_non_nullable
as int?,colors: null == colors ? _self.colors : colors // ignore: cast_nullable_to_non_nullable
as List<String>,thumbs: freezed == thumbs ? _self.thumbs : thumbs // ignore: cast_nullable_to_non_nullable
as WallhavenThumbsDto?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<WallhavenTagDto>,uploader: freezed == uploader ? _self.uploader : uploader // ignore: cast_nullable_to_non_nullable
as WallhavenUploaderDto?,
  ));
}
/// Create a copy of WallhavenWallpaperDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WallhavenThumbsDtoCopyWith<$Res>? get thumbs {
    if (_self.thumbs == null) {
    return null;
  }

  return $WallhavenThumbsDtoCopyWith<$Res>(_self.thumbs!, (value) {
    return _then(_self.copyWith(thumbs: value));
  });
}/// Create a copy of WallhavenWallpaperDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WallhavenUploaderDtoCopyWith<$Res>? get uploader {
    if (_self.uploader == null) {
    return null;
  }

  return $WallhavenUploaderDtoCopyWith<$Res>(_self.uploader!, (value) {
    return _then(_self.copyWith(uploader: value));
  });
}
}


/// Adds pattern-matching-related methods to [WallhavenWallpaperDto].
extension WallhavenWallpaperDtoPatterns on WallhavenWallpaperDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WallhavenWallpaperDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WallhavenWallpaperDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WallhavenWallpaperDto value)  $default,){
final _that = this;
switch (_that) {
case _WallhavenWallpaperDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WallhavenWallpaperDto value)?  $default,){
final _that = this;
switch (_that) {
case _WallhavenWallpaperDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String path,  String resolution, @JsonKey(name: 'file_size')  int? fileSize,  String category,  int? views, @JsonKey(name: 'favorites')  int? favorites, @JsonKey(name: 'dimension_x')  int? dimensionX, @JsonKey(name: 'dimension_y')  int? dimensionY,  List<String> colors,  WallhavenThumbsDto? thumbs,  List<WallhavenTagDto> tags,  WallhavenUploaderDto? uploader)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WallhavenWallpaperDto() when $default != null:
return $default(_that.id,_that.path,_that.resolution,_that.fileSize,_that.category,_that.views,_that.favorites,_that.dimensionX,_that.dimensionY,_that.colors,_that.thumbs,_that.tags,_that.uploader);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String path,  String resolution, @JsonKey(name: 'file_size')  int? fileSize,  String category,  int? views, @JsonKey(name: 'favorites')  int? favorites, @JsonKey(name: 'dimension_x')  int? dimensionX, @JsonKey(name: 'dimension_y')  int? dimensionY,  List<String> colors,  WallhavenThumbsDto? thumbs,  List<WallhavenTagDto> tags,  WallhavenUploaderDto? uploader)  $default,) {final _that = this;
switch (_that) {
case _WallhavenWallpaperDto():
return $default(_that.id,_that.path,_that.resolution,_that.fileSize,_that.category,_that.views,_that.favorites,_that.dimensionX,_that.dimensionY,_that.colors,_that.thumbs,_that.tags,_that.uploader);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String path,  String resolution, @JsonKey(name: 'file_size')  int? fileSize,  String category,  int? views, @JsonKey(name: 'favorites')  int? favorites, @JsonKey(name: 'dimension_x')  int? dimensionX, @JsonKey(name: 'dimension_y')  int? dimensionY,  List<String> colors,  WallhavenThumbsDto? thumbs,  List<WallhavenTagDto> tags,  WallhavenUploaderDto? uploader)?  $default,) {final _that = this;
switch (_that) {
case _WallhavenWallpaperDto() when $default != null:
return $default(_that.id,_that.path,_that.resolution,_that.fileSize,_that.category,_that.views,_that.favorites,_that.dimensionX,_that.dimensionY,_that.colors,_that.thumbs,_that.tags,_that.uploader);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WallhavenWallpaperDto implements WallhavenWallpaperDto {
  const _WallhavenWallpaperDto({required this.id, this.path = '', this.resolution = '', @JsonKey(name: 'file_size') this.fileSize, this.category = '', this.views, @JsonKey(name: 'favorites') this.favorites, @JsonKey(name: 'dimension_x') this.dimensionX, @JsonKey(name: 'dimension_y') this.dimensionY, final  List<String> colors = const <String>[], this.thumbs, final  List<WallhavenTagDto> tags = const <WallhavenTagDto>[], this.uploader}): _colors = colors,_tags = tags;
  factory _WallhavenWallpaperDto.fromJson(Map<String, dynamic> json) => _$WallhavenWallpaperDtoFromJson(json);

@override final  String id;
@override@JsonKey() final  String path;
@override@JsonKey() final  String resolution;
@override@JsonKey(name: 'file_size') final  int? fileSize;
@override@JsonKey() final  String category;
@override final  int? views;
@override@JsonKey(name: 'favorites') final  int? favorites;
@override@JsonKey(name: 'dimension_x') final  int? dimensionX;
@override@JsonKey(name: 'dimension_y') final  int? dimensionY;
 final  List<String> _colors;
@override@JsonKey() List<String> get colors {
  if (_colors is EqualUnmodifiableListView) return _colors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_colors);
}

@override final  WallhavenThumbsDto? thumbs;
 final  List<WallhavenTagDto> _tags;
@override@JsonKey() List<WallhavenTagDto> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

@override final  WallhavenUploaderDto? uploader;

/// Create a copy of WallhavenWallpaperDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WallhavenWallpaperDtoCopyWith<_WallhavenWallpaperDto> get copyWith => __$WallhavenWallpaperDtoCopyWithImpl<_WallhavenWallpaperDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WallhavenWallpaperDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WallhavenWallpaperDto&&(identical(other.id, id) || other.id == id)&&(identical(other.path, path) || other.path == path)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize)&&(identical(other.category, category) || other.category == category)&&(identical(other.views, views) || other.views == views)&&(identical(other.favorites, favorites) || other.favorites == favorites)&&(identical(other.dimensionX, dimensionX) || other.dimensionX == dimensionX)&&(identical(other.dimensionY, dimensionY) || other.dimensionY == dimensionY)&&const DeepCollectionEquality().equals(other._colors, _colors)&&(identical(other.thumbs, thumbs) || other.thumbs == thumbs)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.uploader, uploader) || other.uploader == uploader));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,path,resolution,fileSize,category,views,favorites,dimensionX,dimensionY,const DeepCollectionEquality().hash(_colors),thumbs,const DeepCollectionEquality().hash(_tags),uploader);

@override
String toString() {
  return 'WallhavenWallpaperDto(id: $id, path: $path, resolution: $resolution, fileSize: $fileSize, category: $category, views: $views, favorites: $favorites, dimensionX: $dimensionX, dimensionY: $dimensionY, colors: $colors, thumbs: $thumbs, tags: $tags, uploader: $uploader)';
}


}

/// @nodoc
abstract mixin class _$WallhavenWallpaperDtoCopyWith<$Res> implements $WallhavenWallpaperDtoCopyWith<$Res> {
  factory _$WallhavenWallpaperDtoCopyWith(_WallhavenWallpaperDto value, $Res Function(_WallhavenWallpaperDto) _then) = __$WallhavenWallpaperDtoCopyWithImpl;
@override @useResult
$Res call({
 String id, String path, String resolution,@JsonKey(name: 'file_size') int? fileSize, String category, int? views,@JsonKey(name: 'favorites') int? favorites,@JsonKey(name: 'dimension_x') int? dimensionX,@JsonKey(name: 'dimension_y') int? dimensionY, List<String> colors, WallhavenThumbsDto? thumbs, List<WallhavenTagDto> tags, WallhavenUploaderDto? uploader
});


@override $WallhavenThumbsDtoCopyWith<$Res>? get thumbs;@override $WallhavenUploaderDtoCopyWith<$Res>? get uploader;

}
/// @nodoc
class __$WallhavenWallpaperDtoCopyWithImpl<$Res>
    implements _$WallhavenWallpaperDtoCopyWith<$Res> {
  __$WallhavenWallpaperDtoCopyWithImpl(this._self, this._then);

  final _WallhavenWallpaperDto _self;
  final $Res Function(_WallhavenWallpaperDto) _then;

/// Create a copy of WallhavenWallpaperDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? path = null,Object? resolution = null,Object? fileSize = freezed,Object? category = null,Object? views = freezed,Object? favorites = freezed,Object? dimensionX = freezed,Object? dimensionY = freezed,Object? colors = null,Object? thumbs = freezed,Object? tags = null,Object? uploader = freezed,}) {
  return _then(_WallhavenWallpaperDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,resolution: null == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as String,fileSize: freezed == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int?,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,views: freezed == views ? _self.views : views // ignore: cast_nullable_to_non_nullable
as int?,favorites: freezed == favorites ? _self.favorites : favorites // ignore: cast_nullable_to_non_nullable
as int?,dimensionX: freezed == dimensionX ? _self.dimensionX : dimensionX // ignore: cast_nullable_to_non_nullable
as int?,dimensionY: freezed == dimensionY ? _self.dimensionY : dimensionY // ignore: cast_nullable_to_non_nullable
as int?,colors: null == colors ? _self._colors : colors // ignore: cast_nullable_to_non_nullable
as List<String>,thumbs: freezed == thumbs ? _self.thumbs : thumbs // ignore: cast_nullable_to_non_nullable
as WallhavenThumbsDto?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<WallhavenTagDto>,uploader: freezed == uploader ? _self.uploader : uploader // ignore: cast_nullable_to_non_nullable
as WallhavenUploaderDto?,
  ));
}

/// Create a copy of WallhavenWallpaperDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WallhavenThumbsDtoCopyWith<$Res>? get thumbs {
    if (_self.thumbs == null) {
    return null;
  }

  return $WallhavenThumbsDtoCopyWith<$Res>(_self.thumbs!, (value) {
    return _then(_self.copyWith(thumbs: value));
  });
}/// Create a copy of WallhavenWallpaperDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WallhavenUploaderDtoCopyWith<$Res>? get uploader {
    if (_self.uploader == null) {
    return null;
  }

  return $WallhavenUploaderDtoCopyWith<$Res>(_self.uploader!, (value) {
    return _then(_self.copyWith(uploader: value));
  });
}
}


/// @nodoc
mixin _$WallhavenThumbsDto {

 String? get large; String? get original; String? get small;
/// Create a copy of WallhavenThumbsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WallhavenThumbsDtoCopyWith<WallhavenThumbsDto> get copyWith => _$WallhavenThumbsDtoCopyWithImpl<WallhavenThumbsDto>(this as WallhavenThumbsDto, _$identity);

  /// Serializes this WallhavenThumbsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WallhavenThumbsDto&&(identical(other.large, large) || other.large == large)&&(identical(other.original, original) || other.original == original)&&(identical(other.small, small) || other.small == small));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,large,original,small);

@override
String toString() {
  return 'WallhavenThumbsDto(large: $large, original: $original, small: $small)';
}


}

/// @nodoc
abstract mixin class $WallhavenThumbsDtoCopyWith<$Res>  {
  factory $WallhavenThumbsDtoCopyWith(WallhavenThumbsDto value, $Res Function(WallhavenThumbsDto) _then) = _$WallhavenThumbsDtoCopyWithImpl;
@useResult
$Res call({
 String? large, String? original, String? small
});




}
/// @nodoc
class _$WallhavenThumbsDtoCopyWithImpl<$Res>
    implements $WallhavenThumbsDtoCopyWith<$Res> {
  _$WallhavenThumbsDtoCopyWithImpl(this._self, this._then);

  final WallhavenThumbsDto _self;
  final $Res Function(WallhavenThumbsDto) _then;

/// Create a copy of WallhavenThumbsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? large = freezed,Object? original = freezed,Object? small = freezed,}) {
  return _then(_self.copyWith(
large: freezed == large ? _self.large : large // ignore: cast_nullable_to_non_nullable
as String?,original: freezed == original ? _self.original : original // ignore: cast_nullable_to_non_nullable
as String?,small: freezed == small ? _self.small : small // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [WallhavenThumbsDto].
extension WallhavenThumbsDtoPatterns on WallhavenThumbsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WallhavenThumbsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WallhavenThumbsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WallhavenThumbsDto value)  $default,){
final _that = this;
switch (_that) {
case _WallhavenThumbsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WallhavenThumbsDto value)?  $default,){
final _that = this;
switch (_that) {
case _WallhavenThumbsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? large,  String? original,  String? small)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WallhavenThumbsDto() when $default != null:
return $default(_that.large,_that.original,_that.small);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? large,  String? original,  String? small)  $default,) {final _that = this;
switch (_that) {
case _WallhavenThumbsDto():
return $default(_that.large,_that.original,_that.small);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? large,  String? original,  String? small)?  $default,) {final _that = this;
switch (_that) {
case _WallhavenThumbsDto() when $default != null:
return $default(_that.large,_that.original,_that.small);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WallhavenThumbsDto implements WallhavenThumbsDto {
  const _WallhavenThumbsDto({this.large, this.original, this.small});
  factory _WallhavenThumbsDto.fromJson(Map<String, dynamic> json) => _$WallhavenThumbsDtoFromJson(json);

@override final  String? large;
@override final  String? original;
@override final  String? small;

/// Create a copy of WallhavenThumbsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WallhavenThumbsDtoCopyWith<_WallhavenThumbsDto> get copyWith => __$WallhavenThumbsDtoCopyWithImpl<_WallhavenThumbsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WallhavenThumbsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WallhavenThumbsDto&&(identical(other.large, large) || other.large == large)&&(identical(other.original, original) || other.original == original)&&(identical(other.small, small) || other.small == small));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,large,original,small);

@override
String toString() {
  return 'WallhavenThumbsDto(large: $large, original: $original, small: $small)';
}


}

/// @nodoc
abstract mixin class _$WallhavenThumbsDtoCopyWith<$Res> implements $WallhavenThumbsDtoCopyWith<$Res> {
  factory _$WallhavenThumbsDtoCopyWith(_WallhavenThumbsDto value, $Res Function(_WallhavenThumbsDto) _then) = __$WallhavenThumbsDtoCopyWithImpl;
@override @useResult
$Res call({
 String? large, String? original, String? small
});




}
/// @nodoc
class __$WallhavenThumbsDtoCopyWithImpl<$Res>
    implements _$WallhavenThumbsDtoCopyWith<$Res> {
  __$WallhavenThumbsDtoCopyWithImpl(this._self, this._then);

  final _WallhavenThumbsDto _self;
  final $Res Function(_WallhavenThumbsDto) _then;

/// Create a copy of WallhavenThumbsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? large = freezed,Object? original = freezed,Object? small = freezed,}) {
  return _then(_WallhavenThumbsDto(
large: freezed == large ? _self.large : large // ignore: cast_nullable_to_non_nullable
as String?,original: freezed == original ? _self.original : original // ignore: cast_nullable_to_non_nullable
as String?,small: freezed == small ? _self.small : small // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$WallhavenTagDto {

 String get name;
/// Create a copy of WallhavenTagDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WallhavenTagDtoCopyWith<WallhavenTagDto> get copyWith => _$WallhavenTagDtoCopyWithImpl<WallhavenTagDto>(this as WallhavenTagDto, _$identity);

  /// Serializes this WallhavenTagDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WallhavenTagDto&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name);

@override
String toString() {
  return 'WallhavenTagDto(name: $name)';
}


}

/// @nodoc
abstract mixin class $WallhavenTagDtoCopyWith<$Res>  {
  factory $WallhavenTagDtoCopyWith(WallhavenTagDto value, $Res Function(WallhavenTagDto) _then) = _$WallhavenTagDtoCopyWithImpl;
@useResult
$Res call({
 String name
});




}
/// @nodoc
class _$WallhavenTagDtoCopyWithImpl<$Res>
    implements $WallhavenTagDtoCopyWith<$Res> {
  _$WallhavenTagDtoCopyWithImpl(this._self, this._then);

  final WallhavenTagDto _self;
  final $Res Function(WallhavenTagDto) _then;

/// Create a copy of WallhavenTagDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [WallhavenTagDto].
extension WallhavenTagDtoPatterns on WallhavenTagDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WallhavenTagDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WallhavenTagDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WallhavenTagDto value)  $default,){
final _that = this;
switch (_that) {
case _WallhavenTagDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WallhavenTagDto value)?  $default,){
final _that = this;
switch (_that) {
case _WallhavenTagDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WallhavenTagDto() when $default != null:
return $default(_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name)  $default,) {final _that = this;
switch (_that) {
case _WallhavenTagDto():
return $default(_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name)?  $default,) {final _that = this;
switch (_that) {
case _WallhavenTagDto() when $default != null:
return $default(_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WallhavenTagDto implements WallhavenTagDto {
  const _WallhavenTagDto({this.name = ''});
  factory _WallhavenTagDto.fromJson(Map<String, dynamic> json) => _$WallhavenTagDtoFromJson(json);

@override@JsonKey() final  String name;

/// Create a copy of WallhavenTagDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WallhavenTagDtoCopyWith<_WallhavenTagDto> get copyWith => __$WallhavenTagDtoCopyWithImpl<_WallhavenTagDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WallhavenTagDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WallhavenTagDto&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name);

@override
String toString() {
  return 'WallhavenTagDto(name: $name)';
}


}

/// @nodoc
abstract mixin class _$WallhavenTagDtoCopyWith<$Res> implements $WallhavenTagDtoCopyWith<$Res> {
  factory _$WallhavenTagDtoCopyWith(_WallhavenTagDto value, $Res Function(_WallhavenTagDto) _then) = __$WallhavenTagDtoCopyWithImpl;
@override @useResult
$Res call({
 String name
});




}
/// @nodoc
class __$WallhavenTagDtoCopyWithImpl<$Res>
    implements _$WallhavenTagDtoCopyWith<$Res> {
  __$WallhavenTagDtoCopyWithImpl(this._self, this._then);

  final _WallhavenTagDto _self;
  final $Res Function(_WallhavenTagDto) _then;

/// Create a copy of WallhavenTagDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,}) {
  return _then(_WallhavenTagDto(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
