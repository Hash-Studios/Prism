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

@FirestoreStringConverter() String get id;@FirestoreStringConverter() String get name;@FirestoreStringConverter() String get email;@FirestoreStringConverter() String get username;@FirestoreStringConverter() String get profilePhoto;@FirestoreStringConverter() String get bio;@FirestoreStringListConverter() List<String> get followers;@FirestoreStringListConverter() List<String> get following;@FirestoreStringMapConverter() Map<String, String> get links; bool get premium;@FirestoreStringConverter() String get coverPhoto;
/// Create a copy of PublicUserDocDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicUserDocDtoCopyWith<PublicUserDocDto> get copyWith => _$PublicUserDocDtoCopyWithImpl<PublicUserDocDto>(this as PublicUserDocDto, _$identity);

  /// Serializes this PublicUserDocDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicUserDocDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.username, username) || other.username == username)&&(identical(other.profilePhoto, profilePhoto) || other.profilePhoto == profilePhoto)&&(identical(other.bio, bio) || other.bio == bio)&&const DeepCollectionEquality().equals(other.followers, followers)&&const DeepCollectionEquality().equals(other.following, following)&&const DeepCollectionEquality().equals(other.links, links)&&(identical(other.premium, premium) || other.premium == premium)&&(identical(other.coverPhoto, coverPhoto) || other.coverPhoto == coverPhoto));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,email,username,profilePhoto,bio,const DeepCollectionEquality().hash(followers),const DeepCollectionEquality().hash(following),const DeepCollectionEquality().hash(links),premium,coverPhoto);

@override
String toString() {
  return 'PublicUserDocDto(id: $id, name: $name, email: $email, username: $username, profilePhoto: $profilePhoto, bio: $bio, followers: $followers, following: $following, links: $links, premium: $premium, coverPhoto: $coverPhoto)';
}


}

/// @nodoc
abstract mixin class $PublicUserDocDtoCopyWith<$Res>  {
  factory $PublicUserDocDtoCopyWith(PublicUserDocDto value, $Res Function(PublicUserDocDto) _then) = _$PublicUserDocDtoCopyWithImpl;
@useResult
$Res call({
@FirestoreStringConverter() String id,@FirestoreStringConverter() String name,@FirestoreStringConverter() String email,@FirestoreStringConverter() String username,@FirestoreStringConverter() String profilePhoto,@FirestoreStringConverter() String bio,@FirestoreStringListConverter() List<String> followers,@FirestoreStringListConverter() List<String> following,@FirestoreStringMapConverter() Map<String, String> links, bool premium,@FirestoreStringConverter() String coverPhoto
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? email = null,Object? username = null,Object? profilePhoto = null,Object? bio = null,Object? followers = null,Object? following = null,Object? links = null,Object? premium = null,Object? coverPhoto = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,profilePhoto: null == profilePhoto ? _self.profilePhoto : profilePhoto // ignore: cast_nullable_to_non_nullable
as String,bio: null == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String,followers: null == followers ? _self.followers : followers // ignore: cast_nullable_to_non_nullable
as List<String>,following: null == following ? _self.following : following // ignore: cast_nullable_to_non_nullable
as List<String>,links: null == links ? _self.links : links // ignore: cast_nullable_to_non_nullable
as Map<String, String>,premium: null == premium ? _self.premium : premium // ignore: cast_nullable_to_non_nullable
as bool,coverPhoto: null == coverPhoto ? _self.coverPhoto : coverPhoto // ignore: cast_nullable_to_non_nullable
as String,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@FirestoreStringConverter()  String id, @FirestoreStringConverter()  String name, @FirestoreStringConverter()  String email, @FirestoreStringConverter()  String username, @FirestoreStringConverter()  String profilePhoto, @FirestoreStringConverter()  String bio, @FirestoreStringListConverter()  List<String> followers, @FirestoreStringListConverter()  List<String> following, @FirestoreStringMapConverter()  Map<String, String> links,  bool premium, @FirestoreStringConverter()  String coverPhoto)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublicUserDocDto() when $default != null:
return $default(_that.id,_that.name,_that.email,_that.username,_that.profilePhoto,_that.bio,_that.followers,_that.following,_that.links,_that.premium,_that.coverPhoto);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@FirestoreStringConverter()  String id, @FirestoreStringConverter()  String name, @FirestoreStringConverter()  String email, @FirestoreStringConverter()  String username, @FirestoreStringConverter()  String profilePhoto, @FirestoreStringConverter()  String bio, @FirestoreStringListConverter()  List<String> followers, @FirestoreStringListConverter()  List<String> following, @FirestoreStringMapConverter()  Map<String, String> links,  bool premium, @FirestoreStringConverter()  String coverPhoto)  $default,) {final _that = this;
switch (_that) {
case _PublicUserDocDto():
return $default(_that.id,_that.name,_that.email,_that.username,_that.profilePhoto,_that.bio,_that.followers,_that.following,_that.links,_that.premium,_that.coverPhoto);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@FirestoreStringConverter()  String id, @FirestoreStringConverter()  String name, @FirestoreStringConverter()  String email, @FirestoreStringConverter()  String username, @FirestoreStringConverter()  String profilePhoto, @FirestoreStringConverter()  String bio, @FirestoreStringListConverter()  List<String> followers, @FirestoreStringListConverter()  List<String> following, @FirestoreStringMapConverter()  Map<String, String> links,  bool premium, @FirestoreStringConverter()  String coverPhoto)?  $default,) {final _that = this;
switch (_that) {
case _PublicUserDocDto() when $default != null:
return $default(_that.id,_that.name,_that.email,_that.username,_that.profilePhoto,_that.bio,_that.followers,_that.following,_that.links,_that.premium,_that.coverPhoto);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PublicUserDocDto implements PublicUserDocDto {
  const _PublicUserDocDto({@FirestoreStringConverter() this.id = '', @FirestoreStringConverter() this.name = '', @FirestoreStringConverter() this.email = '', @FirestoreStringConverter() this.username = '', @FirestoreStringConverter() this.profilePhoto = '', @FirestoreStringConverter() this.bio = '', @FirestoreStringListConverter() final  List<String> followers = const <String>[], @FirestoreStringListConverter() final  List<String> following = const <String>[], @FirestoreStringMapConverter() final  Map<String, String> links = const <String, String>{}, this.premium = false, @FirestoreStringConverter() this.coverPhoto = ''}): _followers = followers,_following = following,_links = links;
  factory _PublicUserDocDto.fromJson(Map<String, dynamic> json) => _$PublicUserDocDtoFromJson(json);

@override@JsonKey()@FirestoreStringConverter() final  String id;
@override@JsonKey()@FirestoreStringConverter() final  String name;
@override@JsonKey()@FirestoreStringConverter() final  String email;
@override@JsonKey()@FirestoreStringConverter() final  String username;
@override@JsonKey()@FirestoreStringConverter() final  String profilePhoto;
@override@JsonKey()@FirestoreStringConverter() final  String bio;
 final  List<String> _followers;
@override@JsonKey()@FirestoreStringListConverter() List<String> get followers {
  if (_followers is EqualUnmodifiableListView) return _followers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_followers);
}

 final  List<String> _following;
@override@JsonKey()@FirestoreStringListConverter() List<String> get following {
  if (_following is EqualUnmodifiableListView) return _following;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_following);
}

 final  Map<String, String> _links;
@override@JsonKey()@FirestoreStringMapConverter() Map<String, String> get links {
  if (_links is EqualUnmodifiableMapView) return _links;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_links);
}

@override@JsonKey() final  bool premium;
@override@JsonKey()@FirestoreStringConverter() final  String coverPhoto;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublicUserDocDto&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.username, username) || other.username == username)&&(identical(other.profilePhoto, profilePhoto) || other.profilePhoto == profilePhoto)&&(identical(other.bio, bio) || other.bio == bio)&&const DeepCollectionEquality().equals(other._followers, _followers)&&const DeepCollectionEquality().equals(other._following, _following)&&const DeepCollectionEquality().equals(other._links, _links)&&(identical(other.premium, premium) || other.premium == premium)&&(identical(other.coverPhoto, coverPhoto) || other.coverPhoto == coverPhoto));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,email,username,profilePhoto,bio,const DeepCollectionEquality().hash(_followers),const DeepCollectionEquality().hash(_following),const DeepCollectionEquality().hash(_links),premium,coverPhoto);

@override
String toString() {
  return 'PublicUserDocDto(id: $id, name: $name, email: $email, username: $username, profilePhoto: $profilePhoto, bio: $bio, followers: $followers, following: $following, links: $links, premium: $premium, coverPhoto: $coverPhoto)';
}


}

/// @nodoc
abstract mixin class _$PublicUserDocDtoCopyWith<$Res> implements $PublicUserDocDtoCopyWith<$Res> {
  factory _$PublicUserDocDtoCopyWith(_PublicUserDocDto value, $Res Function(_PublicUserDocDto) _then) = __$PublicUserDocDtoCopyWithImpl;
@override @useResult
$Res call({
@FirestoreStringConverter() String id,@FirestoreStringConverter() String name,@FirestoreStringConverter() String email,@FirestoreStringConverter() String username,@FirestoreStringConverter() String profilePhoto,@FirestoreStringConverter() String bio,@FirestoreStringListConverter() List<String> followers,@FirestoreStringListConverter() List<String> following,@FirestoreStringMapConverter() Map<String, String> links, bool premium,@FirestoreStringConverter() String coverPhoto
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? email = null,Object? username = null,Object? profilePhoto = null,Object? bio = null,Object? followers = null,Object? following = null,Object? links = null,Object? premium = null,Object? coverPhoto = null,}) {
  return _then(_PublicUserDocDto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,profilePhoto: null == profilePhoto ? _self.profilePhoto : profilePhoto // ignore: cast_nullable_to_non_nullable
as String,bio: null == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String,followers: null == followers ? _self._followers : followers // ignore: cast_nullable_to_non_nullable
as List<String>,following: null == following ? _self._following : following // ignore: cast_nullable_to_non_nullable
as List<String>,links: null == links ? _self._links : links // ignore: cast_nullable_to_non_nullable
as Map<String, String>,premium: null == premium ? _self.premium : premium // ignore: cast_nullable_to_non_nullable
as bool,coverPhoto: null == coverPhoto ? _self.coverPhoto : coverPhoto // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
