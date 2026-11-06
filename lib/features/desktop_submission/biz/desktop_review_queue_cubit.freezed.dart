// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'desktop_review_queue_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DesktopReviewQueueState {

 List<DesktopSubmission>? get submissions; bool get error;
/// Create a copy of DesktopReviewQueueState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DesktopReviewQueueStateCopyWith<DesktopReviewQueueState> get copyWith => _$DesktopReviewQueueStateCopyWithImpl<DesktopReviewQueueState>(this as DesktopReviewQueueState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DesktopReviewQueueState&&const DeepCollectionEquality().equals(other.submissions, submissions)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(submissions),error);

@override
String toString() {
  return 'DesktopReviewQueueState(submissions: $submissions, error: $error)';
}


}

/// @nodoc
abstract mixin class $DesktopReviewQueueStateCopyWith<$Res>  {
  factory $DesktopReviewQueueStateCopyWith(DesktopReviewQueueState value, $Res Function(DesktopReviewQueueState) _then) = _$DesktopReviewQueueStateCopyWithImpl;
@useResult
$Res call({
 List<DesktopSubmission>? submissions, bool error
});




}
/// @nodoc
class _$DesktopReviewQueueStateCopyWithImpl<$Res>
    implements $DesktopReviewQueueStateCopyWith<$Res> {
  _$DesktopReviewQueueStateCopyWithImpl(this._self, this._then);

  final DesktopReviewQueueState _self;
  final $Res Function(DesktopReviewQueueState) _then;

/// Create a copy of DesktopReviewQueueState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? submissions = freezed,Object? error = null,}) {
  return _then(_self.copyWith(
submissions: freezed == submissions ? _self.submissions : submissions // ignore: cast_nullable_to_non_nullable
as List<DesktopSubmission>?,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [DesktopReviewQueueState].
extension DesktopReviewQueueStatePatterns on DesktopReviewQueueState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DesktopReviewQueueState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DesktopReviewQueueState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DesktopReviewQueueState value)  $default,){
final _that = this;
switch (_that) {
case _DesktopReviewQueueState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DesktopReviewQueueState value)?  $default,){
final _that = this;
switch (_that) {
case _DesktopReviewQueueState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<DesktopSubmission>? submissions,  bool error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DesktopReviewQueueState() when $default != null:
return $default(_that.submissions,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<DesktopSubmission>? submissions,  bool error)  $default,) {final _that = this;
switch (_that) {
case _DesktopReviewQueueState():
return $default(_that.submissions,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<DesktopSubmission>? submissions,  bool error)?  $default,) {final _that = this;
switch (_that) {
case _DesktopReviewQueueState() when $default != null:
return $default(_that.submissions,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _DesktopReviewQueueState implements DesktopReviewQueueState {
  const _DesktopReviewQueueState({final  List<DesktopSubmission>? submissions, this.error = false}): _submissions = submissions;
  

 final  List<DesktopSubmission>? _submissions;
@override List<DesktopSubmission>? get submissions {
  final value = _submissions;
  if (value == null) return null;
  if (_submissions is EqualUnmodifiableListView) return _submissions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey() final  bool error;

/// Create a copy of DesktopReviewQueueState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DesktopReviewQueueStateCopyWith<_DesktopReviewQueueState> get copyWith => __$DesktopReviewQueueStateCopyWithImpl<_DesktopReviewQueueState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DesktopReviewQueueState&&const DeepCollectionEquality().equals(other._submissions, _submissions)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_submissions),error);

@override
String toString() {
  return 'DesktopReviewQueueState(submissions: $submissions, error: $error)';
}


}

/// @nodoc
abstract mixin class _$DesktopReviewQueueStateCopyWith<$Res> implements $DesktopReviewQueueStateCopyWith<$Res> {
  factory _$DesktopReviewQueueStateCopyWith(_DesktopReviewQueueState value, $Res Function(_DesktopReviewQueueState) _then) = __$DesktopReviewQueueStateCopyWithImpl;
@override @useResult
$Res call({
 List<DesktopSubmission>? submissions, bool error
});




}
/// @nodoc
class __$DesktopReviewQueueStateCopyWithImpl<$Res>
    implements _$DesktopReviewQueueStateCopyWith<$Res> {
  __$DesktopReviewQueueStateCopyWithImpl(this._self, this._then);

  final _DesktopReviewQueueState _self;
  final $Res Function(_DesktopReviewQueueState) _then;

/// Create a copy of DesktopReviewQueueState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? submissions = freezed,Object? error = null,}) {
  return _then(_DesktopReviewQueueState(
submissions: freezed == submissions ? _self._submissions : submissions // ignore: cast_nullable_to_non_nullable
as List<DesktopSubmission>?,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
