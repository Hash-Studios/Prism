// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wotd_archive_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WotdArchiveEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WotdArchiveEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'WotdArchiveEvent()';
}


}

/// @nodoc
class $WotdArchiveEventCopyWith<$Res>  {
$WotdArchiveEventCopyWith(WotdArchiveEvent _, $Res Function(WotdArchiveEvent) __);
}


/// Adds pattern-matching-related methods to [WotdArchiveEvent].
extension WotdArchiveEventPatterns on WotdArchiveEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _RefreshRequested value)?  refreshRequested,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _RefreshRequested() when refreshRequested != null:
return refreshRequested(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _RefreshRequested value)  refreshRequested,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _RefreshRequested():
return refreshRequested(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _RefreshRequested value)?  refreshRequested,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _RefreshRequested() when refreshRequested != null:
return refreshRequested(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  started,TResult Function()?  refreshRequested,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _RefreshRequested() when refreshRequested != null:
return refreshRequested();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  started,required TResult Function()  refreshRequested,}) {final _that = this;
switch (_that) {
case _Started():
return started();case _RefreshRequested():
return refreshRequested();case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  started,TResult? Function()?  refreshRequested,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _RefreshRequested() when refreshRequested != null:
return refreshRequested();case _:
  return null;

}
}

}

/// @nodoc


class _Started implements WotdArchiveEvent {
  const _Started();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'WotdArchiveEvent.started()';
}


}




/// @nodoc


class _RefreshRequested implements WotdArchiveEvent {
  const _RefreshRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefreshRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'WotdArchiveEvent.refreshRequested()';
}


}




/// @nodoc
mixin _$WotdArchiveState {

 LoadStatus get status; List<WotdPastPick> get picks; Failure? get failure;
/// Create a copy of WotdArchiveState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WotdArchiveStateCopyWith<WotdArchiveState> get copyWith => _$WotdArchiveStateCopyWithImpl<WotdArchiveState>(this as WotdArchiveState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WotdArchiveState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.picks, picks)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(picks),failure);

@override
String toString() {
  return 'WotdArchiveState(status: $status, picks: $picks, failure: $failure)';
}


}

/// @nodoc
abstract mixin class $WotdArchiveStateCopyWith<$Res>  {
  factory $WotdArchiveStateCopyWith(WotdArchiveState value, $Res Function(WotdArchiveState) _then) = _$WotdArchiveStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, List<WotdPastPick> picks, Failure? failure
});




}
/// @nodoc
class _$WotdArchiveStateCopyWithImpl<$Res>
    implements $WotdArchiveStateCopyWith<$Res> {
  _$WotdArchiveStateCopyWithImpl(this._self, this._then);

  final WotdArchiveState _self;
  final $Res Function(WotdArchiveState) _then;

/// Create a copy of WotdArchiveState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? picks = null,Object? failure = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,picks: null == picks ? _self.picks : picks // ignore: cast_nullable_to_non_nullable
as List<WotdPastPick>,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}

}


/// Adds pattern-matching-related methods to [WotdArchiveState].
extension WotdArchiveStatePatterns on WotdArchiveState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WotdArchiveState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WotdArchiveState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WotdArchiveState value)  $default,){
final _that = this;
switch (_that) {
case _WotdArchiveState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WotdArchiveState value)?  $default,){
final _that = this;
switch (_that) {
case _WotdArchiveState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  List<WotdPastPick> picks,  Failure? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WotdArchiveState() when $default != null:
return $default(_that.status,_that.picks,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  List<WotdPastPick> picks,  Failure? failure)  $default,) {final _that = this;
switch (_that) {
case _WotdArchiveState():
return $default(_that.status,_that.picks,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  List<WotdPastPick> picks,  Failure? failure)?  $default,) {final _that = this;
switch (_that) {
case _WotdArchiveState() when $default != null:
return $default(_that.status,_that.picks,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _WotdArchiveState implements WotdArchiveState {
  const _WotdArchiveState({required this.status, required final  List<WotdPastPick> picks, this.failure}): _picks = picks;
  

@override final  LoadStatus status;
 final  List<WotdPastPick> _picks;
@override List<WotdPastPick> get picks {
  if (_picks is EqualUnmodifiableListView) return _picks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_picks);
}

@override final  Failure? failure;

/// Create a copy of WotdArchiveState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WotdArchiveStateCopyWith<_WotdArchiveState> get copyWith => __$WotdArchiveStateCopyWithImpl<_WotdArchiveState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WotdArchiveState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._picks, _picks)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_picks),failure);

@override
String toString() {
  return 'WotdArchiveState(status: $status, picks: $picks, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$WotdArchiveStateCopyWith<$Res> implements $WotdArchiveStateCopyWith<$Res> {
  factory _$WotdArchiveStateCopyWith(_WotdArchiveState value, $Res Function(_WotdArchiveState) _then) = __$WotdArchiveStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, List<WotdPastPick> picks, Failure? failure
});




}
/// @nodoc
class __$WotdArchiveStateCopyWithImpl<$Res>
    implements _$WotdArchiveStateCopyWith<$Res> {
  __$WotdArchiveStateCopyWithImpl(this._self, this._then);

  final _WotdArchiveState _self;
  final $Res Function(_WotdArchiveState) _then;

/// Create a copy of WotdArchiveState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? picks = null,Object? failure = freezed,}) {
  return _then(_WotdArchiveState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,picks: null == picks ? _self._picks : picks // ignore: cast_nullable_to_non_nullable
as List<WotdPastPick>,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}


}

// dart format on
