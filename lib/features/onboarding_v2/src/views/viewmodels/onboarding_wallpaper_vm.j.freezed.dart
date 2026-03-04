// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'onboarding_wallpaper_vm.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$OnboardingWallpaperVm {

 String get fullUrl; String get thumbnailUrl; String get title; String get authorName; String get sourceCategory;
/// Create a copy of OnboardingWallpaperVm
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OnboardingWallpaperVmCopyWith<OnboardingWallpaperVm> get copyWith => _$OnboardingWallpaperVmCopyWithImpl<OnboardingWallpaperVm>(this as OnboardingWallpaperVm, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OnboardingWallpaperVm&&(identical(other.fullUrl, fullUrl) || other.fullUrl == fullUrl)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.title, title) || other.title == title)&&(identical(other.authorName, authorName) || other.authorName == authorName)&&(identical(other.sourceCategory, sourceCategory) || other.sourceCategory == sourceCategory));
}


@override
int get hashCode => Object.hash(runtimeType,fullUrl,thumbnailUrl,title,authorName,sourceCategory);

@override
String toString() {
  return 'OnboardingWallpaperVm(fullUrl: $fullUrl, thumbnailUrl: $thumbnailUrl, title: $title, authorName: $authorName, sourceCategory: $sourceCategory)';
}


}

/// @nodoc
abstract mixin class $OnboardingWallpaperVmCopyWith<$Res>  {
  factory $OnboardingWallpaperVmCopyWith(OnboardingWallpaperVm value, $Res Function(OnboardingWallpaperVm) _then) = _$OnboardingWallpaperVmCopyWithImpl;
@useResult
$Res call({
 String fullUrl, String thumbnailUrl, String title, String authorName, String sourceCategory
});




}
/// @nodoc
class _$OnboardingWallpaperVmCopyWithImpl<$Res>
    implements $OnboardingWallpaperVmCopyWith<$Res> {
  _$OnboardingWallpaperVmCopyWithImpl(this._self, this._then);

  final OnboardingWallpaperVm _self;
  final $Res Function(OnboardingWallpaperVm) _then;

/// Create a copy of OnboardingWallpaperVm
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fullUrl = null,Object? thumbnailUrl = null,Object? title = null,Object? authorName = null,Object? sourceCategory = null,}) {
  return _then(_self.copyWith(
fullUrl: null == fullUrl ? _self.fullUrl : fullUrl // ignore: cast_nullable_to_non_nullable
as String,thumbnailUrl: null == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,authorName: null == authorName ? _self.authorName : authorName // ignore: cast_nullable_to_non_nullable
as String,sourceCategory: null == sourceCategory ? _self.sourceCategory : sourceCategory // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [OnboardingWallpaperVm].
extension OnboardingWallpaperVmPatterns on OnboardingWallpaperVm {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OnboardingWallpaperVm value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OnboardingWallpaperVm() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OnboardingWallpaperVm value)  $default,){
final _that = this;
switch (_that) {
case _OnboardingWallpaperVm():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OnboardingWallpaperVm value)?  $default,){
final _that = this;
switch (_that) {
case _OnboardingWallpaperVm() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fullUrl,  String thumbnailUrl,  String title,  String authorName,  String sourceCategory)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OnboardingWallpaperVm() when $default != null:
return $default(_that.fullUrl,_that.thumbnailUrl,_that.title,_that.authorName,_that.sourceCategory);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fullUrl,  String thumbnailUrl,  String title,  String authorName,  String sourceCategory)  $default,) {final _that = this;
switch (_that) {
case _OnboardingWallpaperVm():
return $default(_that.fullUrl,_that.thumbnailUrl,_that.title,_that.authorName,_that.sourceCategory);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fullUrl,  String thumbnailUrl,  String title,  String authorName,  String sourceCategory)?  $default,) {final _that = this;
switch (_that) {
case _OnboardingWallpaperVm() when $default != null:
return $default(_that.fullUrl,_that.thumbnailUrl,_that.title,_that.authorName,_that.sourceCategory);case _:
  return null;

}
}

}

/// @nodoc


class _OnboardingWallpaperVm implements OnboardingWallpaperVm {
  const _OnboardingWallpaperVm({required this.fullUrl, required this.thumbnailUrl, required this.title, required this.authorName, required this.sourceCategory});
  

@override final  String fullUrl;
@override final  String thumbnailUrl;
@override final  String title;
@override final  String authorName;
@override final  String sourceCategory;

/// Create a copy of OnboardingWallpaperVm
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OnboardingWallpaperVmCopyWith<_OnboardingWallpaperVm> get copyWith => __$OnboardingWallpaperVmCopyWithImpl<_OnboardingWallpaperVm>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OnboardingWallpaperVm&&(identical(other.fullUrl, fullUrl) || other.fullUrl == fullUrl)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.title, title) || other.title == title)&&(identical(other.authorName, authorName) || other.authorName == authorName)&&(identical(other.sourceCategory, sourceCategory) || other.sourceCategory == sourceCategory));
}


@override
int get hashCode => Object.hash(runtimeType,fullUrl,thumbnailUrl,title,authorName,sourceCategory);

@override
String toString() {
  return 'OnboardingWallpaperVm(fullUrl: $fullUrl, thumbnailUrl: $thumbnailUrl, title: $title, authorName: $authorName, sourceCategory: $sourceCategory)';
}


}

/// @nodoc
abstract mixin class _$OnboardingWallpaperVmCopyWith<$Res> implements $OnboardingWallpaperVmCopyWith<$Res> {
  factory _$OnboardingWallpaperVmCopyWith(_OnboardingWallpaperVm value, $Res Function(_OnboardingWallpaperVm) _then) = __$OnboardingWallpaperVmCopyWithImpl;
@override @useResult
$Res call({
 String fullUrl, String thumbnailUrl, String title, String authorName, String sourceCategory
});




}
/// @nodoc
class __$OnboardingWallpaperVmCopyWithImpl<$Res>
    implements _$OnboardingWallpaperVmCopyWith<$Res> {
  __$OnboardingWallpaperVmCopyWithImpl(this._self, this._then);

  final _OnboardingWallpaperVm _self;
  final $Res Function(_OnboardingWallpaperVm) _then;

/// Create a copy of OnboardingWallpaperVm
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fullUrl = null,Object? thumbnailUrl = null,Object? title = null,Object? authorName = null,Object? sourceCategory = null,}) {
  return _then(_OnboardingWallpaperVm(
fullUrl: null == fullUrl ? _self.fullUrl : fullUrl // ignore: cast_nullable_to_non_nullable
as String,thumbnailUrl: null == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,authorName: null == authorName ? _self.authorName : authorName // ignore: cast_nullable_to_non_nullable
as String,sourceCategory: null == sourceCategory ? _self.sourceCategory : sourceCategory // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
