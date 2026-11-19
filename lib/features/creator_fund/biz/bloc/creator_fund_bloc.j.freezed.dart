// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'creator_fund_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CreatorFundState {

 bool get loading; bool get failed; CreatorFundStatus? get status;
/// Create a copy of CreatorFundState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CreatorFundStateCopyWith<CreatorFundState> get copyWith => _$CreatorFundStateCopyWithImpl<CreatorFundState>(this as CreatorFundState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CreatorFundState&&(identical(other.loading, loading) || other.loading == loading)&&(identical(other.failed, failed) || other.failed == failed)&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode => Object.hash(runtimeType,loading,failed,status);

@override
String toString() {
  return 'CreatorFundState(loading: $loading, failed: $failed, status: $status)';
}


}

/// @nodoc
abstract mixin class $CreatorFundStateCopyWith<$Res>  {
  factory $CreatorFundStateCopyWith(CreatorFundState value, $Res Function(CreatorFundState) _then) = _$CreatorFundStateCopyWithImpl;
@useResult
$Res call({
 bool loading, bool failed, CreatorFundStatus? status
});




}
/// @nodoc
class _$CreatorFundStateCopyWithImpl<$Res>
    implements $CreatorFundStateCopyWith<$Res> {
  _$CreatorFundStateCopyWithImpl(this._self, this._then);

  final CreatorFundState _self;
  final $Res Function(CreatorFundState) _then;

/// Create a copy of CreatorFundState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? loading = null,Object? failed = null,Object? status = freezed,}) {
  return _then(_self.copyWith(
loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,failed: null == failed ? _self.failed : failed // ignore: cast_nullable_to_non_nullable
as bool,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CreatorFundStatus?,
  ));
}

}


/// Adds pattern-matching-related methods to [CreatorFundState].
extension CreatorFundStatePatterns on CreatorFundState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CreatorFundState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CreatorFundState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CreatorFundState value)  $default,){
final _that = this;
switch (_that) {
case _CreatorFundState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CreatorFundState value)?  $default,){
final _that = this;
switch (_that) {
case _CreatorFundState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool loading,  bool failed,  CreatorFundStatus? status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CreatorFundState() when $default != null:
return $default(_that.loading,_that.failed,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool loading,  bool failed,  CreatorFundStatus? status)  $default,) {final _that = this;
switch (_that) {
case _CreatorFundState():
return $default(_that.loading,_that.failed,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool loading,  bool failed,  CreatorFundStatus? status)?  $default,) {final _that = this;
switch (_that) {
case _CreatorFundState() when $default != null:
return $default(_that.loading,_that.failed,_that.status);case _:
  return null;

}
}

}

/// @nodoc


class _CreatorFundState implements CreatorFundState {
  const _CreatorFundState({this.loading = false, this.failed = false, this.status});
  

@override@JsonKey() final  bool loading;
@override@JsonKey() final  bool failed;
@override final  CreatorFundStatus? status;

/// Create a copy of CreatorFundState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CreatorFundStateCopyWith<_CreatorFundState> get copyWith => __$CreatorFundStateCopyWithImpl<_CreatorFundState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CreatorFundState&&(identical(other.loading, loading) || other.loading == loading)&&(identical(other.failed, failed) || other.failed == failed)&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode => Object.hash(runtimeType,loading,failed,status);

@override
String toString() {
  return 'CreatorFundState(loading: $loading, failed: $failed, status: $status)';
}


}

/// @nodoc
abstract mixin class _$CreatorFundStateCopyWith<$Res> implements $CreatorFundStateCopyWith<$Res> {
  factory _$CreatorFundStateCopyWith(_CreatorFundState value, $Res Function(_CreatorFundState) _then) = __$CreatorFundStateCopyWithImpl;
@override @useResult
$Res call({
 bool loading, bool failed, CreatorFundStatus? status
});




}
/// @nodoc
class __$CreatorFundStateCopyWithImpl<$Res>
    implements _$CreatorFundStateCopyWith<$Res> {
  __$CreatorFundStateCopyWithImpl(this._self, this._then);

  final _CreatorFundState _self;
  final $Res Function(_CreatorFundState) _then;

/// Create a copy of CreatorFundState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? loading = null,Object? failed = null,Object? status = freezed,}) {
  return _then(_CreatorFundState(
loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,failed: null == failed ? _self.failed : failed // ignore: cast_nullable_to_non_nullable
as bool,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CreatorFundStatus?,
  ));
}


}

/// @nodoc
mixin _$CreatorFundEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CreatorFundEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CreatorFundEvent()';
}


}

/// @nodoc
class $CreatorFundEventCopyWith<$Res>  {
$CreatorFundEventCopyWith(CreatorFundEvent _, $Res Function(CreatorFundEvent) __);
}


/// Adds pattern-matching-related methods to [CreatorFundEvent].
extension CreatorFundEventPatterns on CreatorFundEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( LoadCreatorFund value)?  load,required TResult orElse(),}){
final _that = this;
switch (_that) {
case LoadCreatorFund() when load != null:
return load(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( LoadCreatorFund value)  load,}){
final _that = this;
switch (_that) {
case LoadCreatorFund():
return load(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( LoadCreatorFund value)?  load,}){
final _that = this;
switch (_that) {
case LoadCreatorFund() when load != null:
return load(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  load,required TResult orElse(),}) {final _that = this;
switch (_that) {
case LoadCreatorFund() when load != null:
return load();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  load,}) {final _that = this;
switch (_that) {
case LoadCreatorFund():
return load();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  load,}) {final _that = this;
switch (_that) {
case LoadCreatorFund() when load != null:
return load();case _:
  return null;

}
}

}

/// @nodoc


class LoadCreatorFund implements CreatorFundEvent {
  const LoadCreatorFund();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoadCreatorFund);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CreatorFundEvent.load()';
}


}




// dart format on
