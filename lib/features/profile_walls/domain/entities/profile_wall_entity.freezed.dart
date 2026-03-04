// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_wall_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProfileWallEntity {

 String get id; String? get by; String? get desc; String? get size; String? get resolution; String? get email; WallpaperSource? get source; String? get wallpaperThumb; String get wallpaperUrl; List<String>? get collections; DateTime? get createdAt; bool get review;
/// Create a copy of ProfileWallEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileWallEntityCopyWith<ProfileWallEntity> get copyWith => _$ProfileWallEntityCopyWithImpl<ProfileWallEntity>(this as ProfileWallEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileWallEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.by, by) || other.by == by)&&(identical(other.desc, desc) || other.desc == desc)&&(identical(other.size, size) || other.size == size)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.email, email) || other.email == email)&&(identical(other.source, source) || other.source == source)&&(identical(other.wallpaperThumb, wallpaperThumb) || other.wallpaperThumb == wallpaperThumb)&&(identical(other.wallpaperUrl, wallpaperUrl) || other.wallpaperUrl == wallpaperUrl)&&const DeepCollectionEquality().equals(other.collections, collections)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.review, review) || other.review == review));
}


@override
int get hashCode => Object.hash(runtimeType,id,by,desc,size,resolution,email,source,wallpaperThumb,wallpaperUrl,const DeepCollectionEquality().hash(collections),createdAt,review);

@override
String toString() {
  return 'ProfileWallEntity(id: $id, by: $by, desc: $desc, size: $size, resolution: $resolution, email: $email, source: $source, wallpaperThumb: $wallpaperThumb, wallpaperUrl: $wallpaperUrl, collections: $collections, createdAt: $createdAt, review: $review)';
}


}

/// @nodoc
abstract mixin class $ProfileWallEntityCopyWith<$Res>  {
  factory $ProfileWallEntityCopyWith(ProfileWallEntity value, $Res Function(ProfileWallEntity) _then) = _$ProfileWallEntityCopyWithImpl;
@useResult
$Res call({
 String id, String? by, String? desc, String? size, String? resolution, String? email, WallpaperSource? source, String? wallpaperThumb, String wallpaperUrl, List<String>? collections, DateTime? createdAt, bool review
});




}
/// @nodoc
class _$ProfileWallEntityCopyWithImpl<$Res>
    implements $ProfileWallEntityCopyWith<$Res> {
  _$ProfileWallEntityCopyWithImpl(this._self, this._then);

  final ProfileWallEntity _self;
  final $Res Function(ProfileWallEntity) _then;

/// Create a copy of ProfileWallEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? by = freezed,Object? desc = freezed,Object? size = freezed,Object? resolution = freezed,Object? email = freezed,Object? source = freezed,Object? wallpaperThumb = freezed,Object? wallpaperUrl = null,Object? collections = freezed,Object? createdAt = freezed,Object? review = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,by: freezed == by ? _self.by : by // ignore: cast_nullable_to_non_nullable
as String?,desc: freezed == desc ? _self.desc : desc // ignore: cast_nullable_to_non_nullable
as String?,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as String?,resolution: freezed == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as WallpaperSource?,wallpaperThumb: freezed == wallpaperThumb ? _self.wallpaperThumb : wallpaperThumb // ignore: cast_nullable_to_non_nullable
as String?,wallpaperUrl: null == wallpaperUrl ? _self.wallpaperUrl : wallpaperUrl // ignore: cast_nullable_to_non_nullable
as String,collections: freezed == collections ? _self.collections : collections // ignore: cast_nullable_to_non_nullable
as List<String>?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,review: null == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ProfileWallEntity].
extension ProfileWallEntityPatterns on ProfileWallEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileWallEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileWallEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileWallEntity value)  $default,){
final _that = this;
switch (_that) {
case _ProfileWallEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileWallEntity value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileWallEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? by,  String? desc,  String? size,  String? resolution,  String? email,  WallpaperSource? source,  String? wallpaperThumb,  String wallpaperUrl,  List<String>? collections,  DateTime? createdAt,  bool review)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileWallEntity() when $default != null:
return $default(_that.id,_that.by,_that.desc,_that.size,_that.resolution,_that.email,_that.source,_that.wallpaperThumb,_that.wallpaperUrl,_that.collections,_that.createdAt,_that.review);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? by,  String? desc,  String? size,  String? resolution,  String? email,  WallpaperSource? source,  String? wallpaperThumb,  String wallpaperUrl,  List<String>? collections,  DateTime? createdAt,  bool review)  $default,) {final _that = this;
switch (_that) {
case _ProfileWallEntity():
return $default(_that.id,_that.by,_that.desc,_that.size,_that.resolution,_that.email,_that.source,_that.wallpaperThumb,_that.wallpaperUrl,_that.collections,_that.createdAt,_that.review);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? by,  String? desc,  String? size,  String? resolution,  String? email,  WallpaperSource? source,  String? wallpaperThumb,  String wallpaperUrl,  List<String>? collections,  DateTime? createdAt,  bool review)?  $default,) {final _that = this;
switch (_that) {
case _ProfileWallEntity() when $default != null:
return $default(_that.id,_that.by,_that.desc,_that.size,_that.resolution,_that.email,_that.source,_that.wallpaperThumb,_that.wallpaperUrl,_that.collections,_that.createdAt,_that.review);case _:
  return null;

}
}

}

/// @nodoc


class _ProfileWallEntity implements ProfileWallEntity {
  const _ProfileWallEntity({required this.id, this.by, this.desc, this.size, this.resolution, this.email, this.source, this.wallpaperThumb, required this.wallpaperUrl, final  List<String>? collections, this.createdAt, this.review = false}): _collections = collections;
  

@override final  String id;
@override final  String? by;
@override final  String? desc;
@override final  String? size;
@override final  String? resolution;
@override final  String? email;
@override final  WallpaperSource? source;
@override final  String? wallpaperThumb;
@override final  String wallpaperUrl;
 final  List<String>? _collections;
@override List<String>? get collections {
  final value = _collections;
  if (value == null) return null;
  if (_collections is EqualUnmodifiableListView) return _collections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  DateTime? createdAt;
@override@JsonKey() final  bool review;

/// Create a copy of ProfileWallEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileWallEntityCopyWith<_ProfileWallEntity> get copyWith => __$ProfileWallEntityCopyWithImpl<_ProfileWallEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileWallEntity&&(identical(other.id, id) || other.id == id)&&(identical(other.by, by) || other.by == by)&&(identical(other.desc, desc) || other.desc == desc)&&(identical(other.size, size) || other.size == size)&&(identical(other.resolution, resolution) || other.resolution == resolution)&&(identical(other.email, email) || other.email == email)&&(identical(other.source, source) || other.source == source)&&(identical(other.wallpaperThumb, wallpaperThumb) || other.wallpaperThumb == wallpaperThumb)&&(identical(other.wallpaperUrl, wallpaperUrl) || other.wallpaperUrl == wallpaperUrl)&&const DeepCollectionEquality().equals(other._collections, _collections)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.review, review) || other.review == review));
}


@override
int get hashCode => Object.hash(runtimeType,id,by,desc,size,resolution,email,source,wallpaperThumb,wallpaperUrl,const DeepCollectionEquality().hash(_collections),createdAt,review);

@override
String toString() {
  return 'ProfileWallEntity(id: $id, by: $by, desc: $desc, size: $size, resolution: $resolution, email: $email, source: $source, wallpaperThumb: $wallpaperThumb, wallpaperUrl: $wallpaperUrl, collections: $collections, createdAt: $createdAt, review: $review)';
}


}

/// @nodoc
abstract mixin class _$ProfileWallEntityCopyWith<$Res> implements $ProfileWallEntityCopyWith<$Res> {
  factory _$ProfileWallEntityCopyWith(_ProfileWallEntity value, $Res Function(_ProfileWallEntity) _then) = __$ProfileWallEntityCopyWithImpl;
@override @useResult
$Res call({
 String id, String? by, String? desc, String? size, String? resolution, String? email, WallpaperSource? source, String? wallpaperThumb, String wallpaperUrl, List<String>? collections, DateTime? createdAt, bool review
});




}
/// @nodoc
class __$ProfileWallEntityCopyWithImpl<$Res>
    implements _$ProfileWallEntityCopyWith<$Res> {
  __$ProfileWallEntityCopyWithImpl(this._self, this._then);

  final _ProfileWallEntity _self;
  final $Res Function(_ProfileWallEntity) _then;

/// Create a copy of ProfileWallEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? by = freezed,Object? desc = freezed,Object? size = freezed,Object? resolution = freezed,Object? email = freezed,Object? source = freezed,Object? wallpaperThumb = freezed,Object? wallpaperUrl = null,Object? collections = freezed,Object? createdAt = freezed,Object? review = null,}) {
  return _then(_ProfileWallEntity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,by: freezed == by ? _self.by : by // ignore: cast_nullable_to_non_nullable
as String?,desc: freezed == desc ? _self.desc : desc // ignore: cast_nullable_to_non_nullable
as String?,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as String?,resolution: freezed == resolution ? _self.resolution : resolution // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as WallpaperSource?,wallpaperThumb: freezed == wallpaperThumb ? _self.wallpaperThumb : wallpaperThumb // ignore: cast_nullable_to_non_nullable
as String?,wallpaperUrl: null == wallpaperUrl ? _self.wallpaperUrl : wallpaperUrl // ignore: cast_nullable_to_non_nullable
as String,collections: freezed == collections ? _self._collections : collections // ignore: cast_nullable_to_non_nullable
as List<String>?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,review: null == review ? _self.review : review // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
