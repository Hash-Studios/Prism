// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wotd_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WotdEvent {

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WotdEvent);
}

@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'WotdEvent()';
}

}

/// @nodoc
class $WotdEventCopyWith<$Res>  {
$WotdEventCopyWith(WotdEvent _, $Res Function(WotdEvent) __);
}


/// Adds pattern-matching-related methods to [WotdEvent].
extension WotdEventPatterns on WotdEvent {

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _:
  return orElse();

}
}

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _:
  throw StateError('Unexpected subclass');

}
}

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _:
  return null;

}
}

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  started,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _:
  return orElse();

}
}

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  started,}) {final _that = this;
switch (_that) {
case _Started():
return started();case _:
  throw StateError('Unexpected subclass');

}
}

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  started,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _:
  return null;

}
}

}

/// @nodoc


class _Started implements WotdEvent {
  const _Started();

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started);
}

@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'WotdEvent.started()';
}

}




/// @nodoc
mixin _$WotdState {

 LoadStatus get status; WallOfTheDayEntity? get entity; Failure? get failure;
/// Create a copy of WotdState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WotdStateCopyWith<WotdState> get copyWith => _$WotdStateCopyWithImpl<WotdState>(this as WotdState, _$identity);

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WotdState&&(identical(other.status, status) || other.status == status)&&(identical(other.entity, entity) || other.entity == entity)&&(identical(other.failure, failure) || other.failure == failure));
}

@override
int get hashCode => Object.hash(runtimeType,status,entity,failure);

@override
String toString() {
  return 'WotdState(status: $status, entity: $entity, failure: $failure)';
}

}

/// @nodoc
abstract mixin class $WotdStateCopyWith<$Res>  {
  factory $WotdStateCopyWith(WotdState value, $Res Function(WotdState) _then) = _$WotdStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, WallOfTheDayEntity? entity, Failure? failure
});

}
/// @nodoc
class _$WotdStateCopyWithImpl<$Res>
    implements $WotdStateCopyWith<$Res> {
  _$WotdStateCopyWithImpl(this._self, this._then);

  final WotdState _self;
  final $Res Function(WotdState) _then;

/// Create a copy of WotdState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? entity = freezed,Object? failure = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,entity: freezed == entity ? _self.entity : entity // ignore: cast_nullable_to_non_nullable
as WallOfTheDayEntity?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}

}


/// Adds pattern-matching-related methods to [WotdState].
extension WotdStatePatterns on WotdState {

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WotdState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WotdState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WotdState value)  $default,){
final _that = this;
switch (_that) {
case _WotdState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WotdState value)?  $default,){
final _that = this;
switch (_that) {
case _WotdState() when $default != null:
return $default(_that);case _:
  return null;

}
}

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  WallOfTheDayEntity? entity,  Failure? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WotdState() when $default != null:
return $default(_that.status,_that.entity,_that.failure);case _:
  return orElse();

}
}

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  WallOfTheDayEntity? entity,  Failure? failure)  $default,) {final _that = this;
switch (_that) {
case _WotdState():
return $default(_that.status,_that.entity,_that.failure);case _:
  throw StateError('Unexpected subclass');

}
}

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  WallOfTheDayEntity? entity,  Failure? failure)?  $default,) {final _that = this;
switch (_that) {
case _WotdState() when $default != null:
return $default(_that.status,_that.entity,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _WotdState implements WotdState {
  const _WotdState({required this.status, this.entity, this.failure});
  
@override final  LoadStatus status;
@override final  WallOfTheDayEntity? entity;
@override final  Failure? failure;

/// Create a copy of WotdState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WotdStateCopyWith<_WotdState> get copyWith => __$WotdStateCopyWithImpl<_WotdState>(this, _$identity);

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WotdState&&(identical(other.status, status) || other.status == status)&&(identical(other.entity, entity) || other.entity == entity)&&(identical(other.failure, failure) || other.failure == failure));
}

@override
int get hashCode => Object.hash(runtimeType,status,entity,failure);

@override
String toString() {
  return 'WotdState(status: $status, entity: $entity, failure: $failure)';
}

}

/// @nodoc
abstract mixin class _$WotdStateCopyWith<$Res> implements $WotdStateCopyWith<$Res> {
  factory _$WotdStateCopyWith(_WotdState value, $Res Function(_WotdState) _then) = __$WotdStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, WallOfTheDayEntity? entity, Failure? failure
});

}
/// @nodoc
class __$WotdStateCopyWithImpl<$Res>
    implements _$WotdStateCopyWith<$Res> {
  __$WotdStateCopyWithImpl(this._self, this._then);

  final _WotdState _self;
  final $Res Function(_WotdState) _then;

/// Create a copy of WotdState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? entity = freezed,Object? failure = freezed,}) {
  return _then(_WotdState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,entity: freezed == entity ? _self.entity : entity // ignore: cast_nullable_to_non_nullable
as WallOfTheDayEntity?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}

}

// dart format on
