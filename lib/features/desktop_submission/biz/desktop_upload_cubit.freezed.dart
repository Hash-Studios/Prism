// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'desktop_upload_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DesktopUploadState {

 bool get sending; bool get sent; DesktopSubmitFailure? get failure;
/// Create a copy of DesktopUploadState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DesktopUploadStateCopyWith<DesktopUploadState> get copyWith => _$DesktopUploadStateCopyWithImpl<DesktopUploadState>(this as DesktopUploadState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DesktopUploadState&&(identical(other.sending, sending) || other.sending == sending)&&(identical(other.sent, sent) || other.sent == sent)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,sending,sent,failure);

@override
String toString() {
  return 'DesktopUploadState(sending: $sending, sent: $sent, failure: $failure)';
}


}

/// @nodoc
abstract mixin class $DesktopUploadStateCopyWith<$Res>  {
  factory $DesktopUploadStateCopyWith(DesktopUploadState value, $Res Function(DesktopUploadState) _then) = _$DesktopUploadStateCopyWithImpl;
@useResult
$Res call({
 bool sending, bool sent, DesktopSubmitFailure? failure
});




}
/// @nodoc
class _$DesktopUploadStateCopyWithImpl<$Res>
    implements $DesktopUploadStateCopyWith<$Res> {
  _$DesktopUploadStateCopyWithImpl(this._self, this._then);

  final DesktopUploadState _self;
  final $Res Function(DesktopUploadState) _then;

/// Create a copy of DesktopUploadState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sending = null,Object? sent = null,Object? failure = freezed,}) {
  return _then(_self.copyWith(
sending: null == sending ? _self.sending : sending // ignore: cast_nullable_to_non_nullable
as bool,sent: null == sent ? _self.sent : sent // ignore: cast_nullable_to_non_nullable
as bool,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as DesktopSubmitFailure?,
  ));
}

}


/// Adds pattern-matching-related methods to [DesktopUploadState].
extension DesktopUploadStatePatterns on DesktopUploadState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DesktopUploadState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DesktopUploadState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DesktopUploadState value)  $default,){
final _that = this;
switch (_that) {
case _DesktopUploadState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DesktopUploadState value)?  $default,){
final _that = this;
switch (_that) {
case _DesktopUploadState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool sending,  bool sent,  DesktopSubmitFailure? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DesktopUploadState() when $default != null:
return $default(_that.sending,_that.sent,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool sending,  bool sent,  DesktopSubmitFailure? failure)  $default,) {final _that = this;
switch (_that) {
case _DesktopUploadState():
return $default(_that.sending,_that.sent,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool sending,  bool sent,  DesktopSubmitFailure? failure)?  $default,) {final _that = this;
switch (_that) {
case _DesktopUploadState() when $default != null:
return $default(_that.sending,_that.sent,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _DesktopUploadState implements DesktopUploadState {
  const _DesktopUploadState({this.sending = false, this.sent = false, this.failure});
  

@override@JsonKey() final  bool sending;
@override@JsonKey() final  bool sent;
@override final  DesktopSubmitFailure? failure;

/// Create a copy of DesktopUploadState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DesktopUploadStateCopyWith<_DesktopUploadState> get copyWith => __$DesktopUploadStateCopyWithImpl<_DesktopUploadState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DesktopUploadState&&(identical(other.sending, sending) || other.sending == sending)&&(identical(other.sent, sent) || other.sent == sent)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,sending,sent,failure);

@override
String toString() {
  return 'DesktopUploadState(sending: $sending, sent: $sent, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$DesktopUploadStateCopyWith<$Res> implements $DesktopUploadStateCopyWith<$Res> {
  factory _$DesktopUploadStateCopyWith(_DesktopUploadState value, $Res Function(_DesktopUploadState) _then) = __$DesktopUploadStateCopyWithImpl;
@override @useResult
$Res call({
 bool sending, bool sent, DesktopSubmitFailure? failure
});




}
/// @nodoc
class __$DesktopUploadStateCopyWithImpl<$Res>
    implements _$DesktopUploadStateCopyWith<$Res> {
  __$DesktopUploadStateCopyWithImpl(this._self, this._then);

  final _DesktopUploadState _self;
  final $Res Function(_DesktopUploadState) _then;

/// Create a copy of DesktopUploadState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sending = null,Object? sent = null,Object? failure = freezed,}) {
  return _then(_DesktopUploadState(
sending: null == sending ? _self.sending : sending // ignore: cast_nullable_to_non_nullable
as bool,sent: null == sent ? _self.sent : sent // ignore: cast_nullable_to_non_nullable
as bool,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as DesktopSubmitFailure?,
  ));
}


}

// dart format on
