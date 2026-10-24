// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'public_user_doc_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PublicUserDocDto {

@FirestoreStringConverter() String get name;@FirestoreStringConverter() String get username;@FirestoreStringConverter() String get profilePhoto;@FirestoreStringConverter() String get bio;@FirestoreStringMapConverter() Map<String, String> get links;@FirestoreStringConverter() String get coverPhoto;@FirestoreStringListConverter() List<String> get badges; int get xp;@FirestoreStringMapConverter() Map<String, String> get cosmetics; int get followerCount; int get followingCount;
/// Create a copy of PublicUserDocDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicUserDocDtoCopyWith<PublicUserDocDto> get copyWith => _$PublicUserDocDtoCopyWithImpl<PublicUserDocDto>(this as PublicUserDocDto, _$identity);

  /// Serializes this PublicUserDocDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicUserDocDto&&(identical(other.name, name) || other.name == name)&&(identical(other.username, username) || other.username == username)&&(identical(other.profilePhoto, profilePhoto) || other.profilePhoto == profilePhoto)&&(identical(other.bio, bio) || other.bio == bio)&&const DeepCollectionEquality().equals(other.links, links)&&(identical(other.coverPhoto, coverPhoto) || other.coverPhoto == coverPhoto)&&const DeepCollectionEquality().equals(other.badges, badges)&&(identical(other.xp, xp) || other.xp == xp)&&const DeepCollectionEquality().equals(other.cosmetics, cosmetics)&&(identical(other.followerCount, followerCount) || other.followerCount == followerCount)&&(identical(other.followingCount, followingCount) || other.followingCount == followingCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,username,profilePhoto,bio,const DeepCollectionEquality().hash(links),coverPhoto,const DeepCollectionEquality().hash(badges),xp,const DeepCollectionEquality().hash(cosmetics),followerCount,followingCount);

@override
String toString() {
  return 'PublicUserDocDto(name: $name, username: $username, profilePhoto: $profilePhoto, bio: $bio, links: $links, coverPhoto: $coverPhoto, badges: $badges, xp: $xp, cosmetics: $cosmetics, followerCount: $followerCount, followingCount: $followingCount)';
}


}

/// @nodoc
abstract mixin class $PublicUserDocDtoCopyWith<$Res>  {
  factory $PublicUserDocDtoCopyWith(PublicUserDocDto value, $Res Function(PublicUserDocDto) _then) = _$PublicUserDocDtoCopyWithImpl;
@useResult
$Res call({
@FirestoreStringConverter() String name,@FirestoreStringConverter() String username,@FirestoreStringConverter() String profilePhoto,@FirestoreStringConverter() String bio,@FirestoreStringMapConverter() Map<String, String> links,@FirestoreStringConverter() String coverPhoto,@FirestoreStringListConverter() List<String> badges, int xp,@FirestoreStringMapConverter() Map<String, String> cosmetics, int followerCount, int followingCount
});




}
/// @nodoc
class _$PublicUserDocDtoCopyWithImpl<$Res>
    implements $PublicUserDocDtoCopyWith<$Res> {
  _$PublicUserDocDtoCopyWithImpl(this._self, this._then);

  final PublicUserDocDto _self;
  final $Res Function(PublicUserDocDto) _then;

/// Create a copy of PublicUserDocDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? username = null,Object? profilePhoto = null,Object? bio = null,Object? links = null,Object? coverPhoto = null,Object? badges = null,Object? xp = null,Object? cosmetics = null,Object? followerCount = null,Object? followingCount = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,profilePhoto: null == profilePhoto ? _self.profilePhoto : profilePhoto // ignore: cast_nullable_to_non_nullable
as String,bio: null == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String,links: null == links ? _self.links : links // ignore: cast_nullable_to_non_nullable
as Map<String, String>,coverPhoto: null == coverPhoto ? _self.coverPhoto : coverPhoto // ignore: cast_nullable_to_non_nullable
as String,badges: null == badges ? _self.badges : badges // ignore: cast_nullable_to_non_nullable
as List<String>,xp: null == xp ? _self.xp : xp // ignore: cast_nullable_to_non_nullable
as int,cosmetics: null == cosmetics ? _self.cosmetics : cosmetics // ignore: cast_nullable_to_non_nullable
as Map<String, String>,followerCount: null == followerCount ? _self.followerCount : followerCount // ignore: cast_nullable_to_non_nullable
as int,followingCount: null == followingCount ? _self.followingCount : followingCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PublicUserDocDto].
extension PublicUserDocDtoPatterns on PublicUserDocDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PublicUserDocDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PublicUserDocDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PublicUserDocDto value)  $default,){
final _that = this;
switch (_that) {
case _PublicUserDocDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PublicUserDocDto value)?  $default,){
final _that = this;
switch (_that) {
case _PublicUserDocDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@FirestoreStringConverter()  String name, @FirestoreStringConverter()  String username, @FirestoreStringConverter()  String profilePhoto, @FirestoreStringConverter()  String bio, @FirestoreStringMapConverter()  Map<String, String> links, @FirestoreStringConverter()  String coverPhoto, @FirestoreStringListConverter()  List<String> badges,  int xp, @FirestoreStringMapConverter()  Map<String, String> cosmetics,  int followerCount,  int followingCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublicUserDocDto() when $default != null:
return $default(_that.name,_that.username,_that.profilePhoto,_that.bio,_that.links,_that.coverPhoto,_that.badges,_that.xp,_that.cosmetics,_that.followerCount,_that.followingCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@FirestoreStringConverter()  String name, @FirestoreStringConverter()  String username, @FirestoreStringConverter()  String profilePhoto, @FirestoreStringConverter()  String bio, @FirestoreStringMapConverter()  Map<String, String> links, @FirestoreStringConverter()  String coverPhoto, @FirestoreStringListConverter()  List<String> badges,  int xp, @FirestoreStringMapConverter()  Map<String, String> cosmetics,  int followerCount,  int followingCount)  $default,) {final _that = this;
switch (_that) {
case _PublicUserDocDto():
return $default(_that.name,_that.username,_that.profilePhoto,_that.bio,_that.links,_that.coverPhoto,_that.badges,_that.xp,_that.cosmetics,_that.followerCount,_that.followingCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@FirestoreStringConverter()  String name, @FirestoreStringConverter()  String username, @FirestoreStringConverter()  String profilePhoto, @FirestoreStringConverter()  String bio, @FirestoreStringMapConverter()  Map<String, String> links, @FirestoreStringConverter()  String coverPhoto, @FirestoreStringListConverter()  List<String> badges,  int xp, @FirestoreStringMapConverter()  Map<String, String> cosmetics,  int followerCount,  int followingCount)?  $default,) {final _that = this;
switch (_that) {
case _PublicUserDocDto() when $default != null:
return $default(_that.name,_that.username,_that.profilePhoto,_that.bio,_that.links,_that.coverPhoto,_that.badges,_that.xp,_that.cosmetics,_that.followerCount,_that.followingCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PublicUserDocDto implements PublicUserDocDto {
  const _PublicUserDocDto({@FirestoreStringConverter() this.name = '', @FirestoreStringConverter() this.username = '', @FirestoreStringConverter() this.profilePhoto = '', @FirestoreStringConverter() this.bio = '', @FirestoreStringMapConverter() final  Map<String, String> links = const <String, String>{}, @FirestoreStringConverter() this.coverPhoto = '', @FirestoreStringListConverter() final  List<String> badges = const <String>[], this.xp = 0, @FirestoreStringMapConverter() final  Map<String, String> cosmetics = const <String, String>{}, this.followerCount = 0, this.followingCount = 0}): _links = links,_badges = badges,_cosmetics = cosmetics;
  factory _PublicUserDocDto.fromJson(Map<String, dynamic> json) => _$PublicUserDocDtoFromJson(json);

@override@JsonKey()@FirestoreStringConverter() final  String name;
@override@JsonKey()@FirestoreStringConverter() final  String username;
@override@JsonKey()@FirestoreStringConverter() final  String profilePhoto;
@override@JsonKey()@FirestoreStringConverter() final  String bio;
 final  Map<String, String> _links;
@override@JsonKey()@FirestoreStringMapConverter() Map<String, String> get links {
  if (_links is EqualUnmodifiableMapView) return _links;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_links);
}

@override@JsonKey()@FirestoreStringConverter() final  String coverPhoto;
 final  List<String> _badges;
@override@JsonKey()@FirestoreStringListConverter() List<String> get badges {
  if (_badges is EqualUnmodifiableListView) return _badges;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_badges);
}

@override@JsonKey() final  int xp;
 final  Map<String, String> _cosmetics;
@override@JsonKey()@FirestoreStringMapConverter() Map<String, String> get cosmetics {
  if (_cosmetics is EqualUnmodifiableMapView) return _cosmetics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_cosmetics);
}

@override@JsonKey() final  int followerCount;
@override@JsonKey() final  int followingCount;

/// Create a copy of PublicUserDocDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PublicUserDocDtoCopyWith<_PublicUserDocDto> get copyWith => __$PublicUserDocDtoCopyWithImpl<_PublicUserDocDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PublicUserDocDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublicUserDocDto&&(identical(other.name, name) || other.name == name)&&(identical(other.username, username) || other.username == username)&&(identical(other.profilePhoto, profilePhoto) || other.profilePhoto == profilePhoto)&&(identical(other.bio, bio) || other.bio == bio)&&const DeepCollectionEquality().equals(other._links, _links)&&(identical(other.coverPhoto, coverPhoto) || other.coverPhoto == coverPhoto)&&const DeepCollectionEquality().equals(other._badges, _badges)&&(identical(other.xp, xp) || other.xp == xp)&&const DeepCollectionEquality().equals(other._cosmetics, _cosmetics)&&(identical(other.followerCount, followerCount) || other.followerCount == followerCount)&&(identical(other.followingCount, followingCount) || other.followingCount == followingCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,username,profilePhoto,bio,const DeepCollectionEquality().hash(_links),coverPhoto,const DeepCollectionEquality().hash(_badges),xp,const DeepCollectionEquality().hash(_cosmetics),followerCount,followingCount);

@override
String toString() {
  return 'PublicUserDocDto(name: $name, username: $username, profilePhoto: $profilePhoto, bio: $bio, links: $links, coverPhoto: $coverPhoto, badges: $badges, xp: $xp, cosmetics: $cosmetics, followerCount: $followerCount, followingCount: $followingCount)';
}


}

/// @nodoc
abstract mixin class _$PublicUserDocDtoCopyWith<$Res> implements $PublicUserDocDtoCopyWith<$Res> {
  factory _$PublicUserDocDtoCopyWith(_PublicUserDocDto value, $Res Function(_PublicUserDocDto) _then) = __$PublicUserDocDtoCopyWithImpl;
@override @useResult
$Res call({
@FirestoreStringConverter() String name,@FirestoreStringConverter() String username,@FirestoreStringConverter() String profilePhoto,@FirestoreStringConverter() String bio,@FirestoreStringMapConverter() Map<String, String> links,@FirestoreStringConverter() String coverPhoto,@FirestoreStringListConverter() List<String> badges, int xp,@FirestoreStringMapConverter() Map<String, String> cosmetics, int followerCount, int followingCount
});




}
/// @nodoc
class __$PublicUserDocDtoCopyWithImpl<$Res>
    implements _$PublicUserDocDtoCopyWith<$Res> {
  __$PublicUserDocDtoCopyWithImpl(this._self, this._then);

  final _PublicUserDocDto _self;
  final $Res Function(_PublicUserDocDto) _then;

/// Create a copy of PublicUserDocDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? username = null,Object? profilePhoto = null,Object? bio = null,Object? links = null,Object? coverPhoto = null,Object? badges = null,Object? xp = null,Object? cosmetics = null,Object? followerCount = null,Object? followingCount = null,}) {
  return _then(_PublicUserDocDto(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,profilePhoto: null == profilePhoto ? _self.profilePhoto : profilePhoto // ignore: cast_nullable_to_non_nullable
as String,bio: null == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String,links: null == links ? _self._links : links // ignore: cast_nullable_to_non_nullable
as Map<String, String>,coverPhoto: null == coverPhoto ? _self.coverPhoto : coverPhoto // ignore: cast_nullable_to_non_nullable
as String,badges: null == badges ? _self._badges : badges // ignore: cast_nullable_to_non_nullable
as List<String>,xp: null == xp ? _self.xp : xp // ignore: cast_nullable_to_non_nullable
as int,cosmetics: null == cosmetics ? _self._cosmetics : cosmetics // ignore: cast_nullable_to_non_nullable
as Map<String, String>,followerCount: null == followerCount ? _self.followerCount : followerCount // ignore: cast_nullable_to_non_nullable
as int,followingCount: null == followingCount ? _self.followingCount : followingCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
