// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'onboarding_creator_vm.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$OnboardingCreatorVm {

 String get userId; String get email; String get name; String get photoUrl; List<String> get previewUrls; int get rank; bool get isSelected; String get bio; int get followerCount;
/// Create a copy of OnboardingCreatorVm
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnboardingCreatorVmCopyWith<OnboardingCreatorVm> get copyWith => _$OnboardingCreatorVmCopyWithImpl<OnboardingCreatorVm>(this as OnboardingCreatorVm, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnboardingCreatorVm&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.email, email) || other.email == email)&&(identical(other.name, name) || other.name == name)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&const DeepCollectionEquality().equals(other.previewUrls, previewUrls)&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.isSelected, isSelected) || other.isSelected == isSelected)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.followerCount, followerCount) || other.followerCount == followerCount));
}


@override
int get hashCode => Object.hash(runtimeType,userId,email,name,photoUrl,const DeepCollectionEquality().hash(previewUrls),rank,isSelected,bio,followerCount);

@override
String toString() {
  return 'OnboardingCreatorVm(userId: $userId, email: $email, name: $name, photoUrl: $photoUrl, previewUrls: $previewUrls, rank: $rank, isSelected: $isSelected, bio: $bio, followerCount: $followerCount)';
}


}

/// @nodoc
abstract mixin class $OnboardingCreatorVmCopyWith<$Res>  {
  factory $OnboardingCreatorVmCopyWith(OnboardingCreatorVm value, $Res Function(OnboardingCreatorVm) _then) = _$OnboardingCreatorVmCopyWithImpl;
@useResult
$Res call({
 String userId, String email, String name, String photoUrl, List<String> previewUrls, int rank, bool isSelected, String bio, int followerCount
});




}
/// @nodoc
class _$OnboardingCreatorVmCopyWithImpl<$Res>
    implements $OnboardingCreatorVmCopyWith<$Res> {
  _$OnboardingCreatorVmCopyWithImpl(this._self, this._then);

  final OnboardingCreatorVm _self;
  final $Res Function(OnboardingCreatorVm) _then;

/// Create a copy of OnboardingCreatorVm
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? email = null,Object? name = null,Object? photoUrl = null,Object? previewUrls = null,Object? rank = null,Object? isSelected = null,Object? bio = null,Object? followerCount = null,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,photoUrl: null == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String,previewUrls: null == previewUrls ? _self.previewUrls : previewUrls // ignore: cast_nullable_to_non_nullable
as List<String>,rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int,isSelected: null == isSelected ? _self.isSelected : isSelected // ignore: cast_nullable_to_non_nullable
as bool,bio: null == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String,followerCount: null == followerCount ? _self.followerCount : followerCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [OnboardingCreatorVm].
extension OnboardingCreatorVmPatterns on OnboardingCreatorVm {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnboardingCreatorVm value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnboardingCreatorVm() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnboardingCreatorVm value)  $default,){
final _that = this;
switch (_that) {
case _OnboardingCreatorVm():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnboardingCreatorVm value)?  $default,){
final _that = this;
switch (_that) {
case _OnboardingCreatorVm() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userId,  String email,  String name,  String photoUrl,  List<String> previewUrls,  int rank,  bool isSelected,  String bio,  int followerCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnboardingCreatorVm() when $default != null:
return $default(_that.userId,_that.email,_that.name,_that.photoUrl,_that.previewUrls,_that.rank,_that.isSelected,_that.bio,_that.followerCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userId,  String email,  String name,  String photoUrl,  List<String> previewUrls,  int rank,  bool isSelected,  String bio,  int followerCount)  $default,) {final _that = this;
switch (_that) {
case _OnboardingCreatorVm():
return $default(_that.userId,_that.email,_that.name,_that.photoUrl,_that.previewUrls,_that.rank,_that.isSelected,_that.bio,_that.followerCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userId,  String email,  String name,  String photoUrl,  List<String> previewUrls,  int rank,  bool isSelected,  String bio,  int followerCount)?  $default,) {final _that = this;
switch (_that) {
case _OnboardingCreatorVm() when $default != null:
return $default(_that.userId,_that.email,_that.name,_that.photoUrl,_that.previewUrls,_that.rank,_that.isSelected,_that.bio,_that.followerCount);case _:
  return null;

}
}

}

/// @nodoc


class _OnboardingCreatorVm implements OnboardingCreatorVm {
  const _OnboardingCreatorVm({required this.userId, required this.email, required this.name, required this.photoUrl, required final  List<String> previewUrls, required this.rank, required this.isSelected, required this.bio, required this.followerCount}): _previewUrls = previewUrls;
  

@override final  String userId;
@override final  String email;
@override final  String name;
@override final  String photoUrl;
 final  List<String> _previewUrls;
@override List<String> get previewUrls {
  if (_previewUrls is EqualUnmodifiableListView) return _previewUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_previewUrls);
}

@override final  int rank;
@override final  bool isSelected;
@override final  String bio;
@override final  int followerCount;

/// Create a copy of OnboardingCreatorVm
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnboardingCreatorVmCopyWith<_OnboardingCreatorVm> get copyWith => __$OnboardingCreatorVmCopyWithImpl<_OnboardingCreatorVm>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnboardingCreatorVm&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.email, email) || other.email == email)&&(identical(other.name, name) || other.name == name)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&const DeepCollectionEquality().equals(other._previewUrls, _previewUrls)&&(identical(other.rank, rank) || other.rank == rank)&&(identical(other.isSelected, isSelected) || other.isSelected == isSelected)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.followerCount, followerCount) || other.followerCount == followerCount));
}


@override
int get hashCode => Object.hash(runtimeType,userId,email,name,photoUrl,const DeepCollectionEquality().hash(_previewUrls),rank,isSelected,bio,followerCount);

@override
String toString() {
  return 'OnboardingCreatorVm(userId: $userId, email: $email, name: $name, photoUrl: $photoUrl, previewUrls: $previewUrls, rank: $rank, isSelected: $isSelected, bio: $bio, followerCount: $followerCount)';
}


}

/// @nodoc
abstract mixin class _$OnboardingCreatorVmCopyWith<$Res> implements $OnboardingCreatorVmCopyWith<$Res> {
  factory _$OnboardingCreatorVmCopyWith(_OnboardingCreatorVm value, $Res Function(_OnboardingCreatorVm) _then) = __$OnboardingCreatorVmCopyWithImpl;
@override @useResult
$Res call({
 String userId, String email, String name, String photoUrl, List<String> previewUrls, int rank, bool isSelected, String bio, int followerCount
});




}
/// @nodoc
class __$OnboardingCreatorVmCopyWithImpl<$Res>
    implements _$OnboardingCreatorVmCopyWith<$Res> {
  __$OnboardingCreatorVmCopyWithImpl(this._self, this._then);

  final _OnboardingCreatorVm _self;
  final $Res Function(_OnboardingCreatorVm) _then;

/// Create a copy of OnboardingCreatorVm
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? email = null,Object? name = null,Object? photoUrl = null,Object? previewUrls = null,Object? rank = null,Object? isSelected = null,Object? bio = null,Object? followerCount = null,}) {
  return _then(_OnboardingCreatorVm(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,photoUrl: null == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String,previewUrls: null == previewUrls ? _self._previewUrls : previewUrls // ignore: cast_nullable_to_non_nullable
as List<String>,rank: null == rank ? _self.rank : rank // ignore: cast_nullable_to_non_nullable
as int,isSelected: null == isSelected ? _self.isSelected : isSelected // ignore: cast_nullable_to_non_nullable
as bool,bio: null == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String,followerCount: null == followerCount ? _self.followerCount : followerCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
