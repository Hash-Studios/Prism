// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'startup_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StartupEvent {

 String? get currentVersion;
/// Create a copy of StartupEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StartupEventCopyWith<StartupEvent> get copyWith => _$StartupEventCopyWithImpl<StartupEvent>(this as StartupEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StartupEvent&&(identical(other.currentVersion, currentVersion) || other.currentVersion == currentVersion));
}


@override
int get hashCode => Object.hash(runtimeType,currentVersion);

@override
String toString() {
  return 'StartupEvent(currentVersion: $currentVersion)';
}


}

/// @nodoc
abstract mixin class $StartupEventCopyWith<$Res>  {
  factory $StartupEventCopyWith(StartupEvent value, $Res Function(StartupEvent) _then) = _$StartupEventCopyWithImpl;
@useResult
$Res call({
 String? currentVersion
});




}
/// @nodoc
class _$StartupEventCopyWithImpl<$Res>
    implements $StartupEventCopyWith<$Res> {
  _$StartupEventCopyWithImpl(this._self, this._then);

  final StartupEvent _self;
  final $Res Function(StartupEvent) _then;

/// Create a copy of StartupEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentVersion = freezed,}) {
  return _then(_self.copyWith(
currentVersion: freezed == currentVersion ? _self.currentVersion : currentVersion // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [StartupEvent].
extension StartupEventPatterns on StartupEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String? currentVersion)?  started,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.currentVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String? currentVersion)  started,}) {final _that = this;
switch (_that) {
case _Started():
return started(_that.currentVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String? currentVersion)?  started,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.currentVersion);case _:
  return null;

}
}

}

/// @nodoc


class _Started implements StartupEvent {
  const _Started({this.currentVersion});
  

@override final  String? currentVersion;

/// Create a copy of StartupEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StartedCopyWith<_Started> get copyWith => __$StartedCopyWithImpl<_Started>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started&&(identical(other.currentVersion, currentVersion) || other.currentVersion == currentVersion));
}


@override
int get hashCode => Object.hash(runtimeType,currentVersion);

@override
String toString() {
  return 'StartupEvent.started(currentVersion: $currentVersion)';
}


}

/// @nodoc
abstract mixin class _$StartedCopyWith<$Res> implements $StartupEventCopyWith<$Res> {
  factory _$StartedCopyWith(_Started value, $Res Function(_Started) _then) = __$StartedCopyWithImpl;
@override @useResult
$Res call({
 String? currentVersion
});




}
/// @nodoc
class __$StartedCopyWithImpl<$Res>
    implements _$StartedCopyWith<$Res> {
  __$StartedCopyWithImpl(this._self, this._then);

  final _Started _self;
  final $Res Function(_Started) _then;

/// Create a copy of StartupEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currentVersion = freezed,}) {
  return _then(_Started(
currentVersion: freezed == currentVersion ? _self.currentVersion : currentVersion // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$StartupState {

 LoadStatus get status; StartupConfigEntity? get config; bool get isObsoleteVersion;
/// Create a copy of StartupState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StartupStateCopyWith<StartupState> get copyWith => _$StartupStateCopyWithImpl<StartupState>(this as StartupState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StartupState&&(identical(other.status, status) || other.status == status)&&(identical(other.config, config) || other.config == config)&&(identical(other.isObsoleteVersion, isObsoleteVersion) || other.isObsoleteVersion == isObsoleteVersion));
}


@override
int get hashCode => Object.hash(runtimeType,status,config,isObsoleteVersion);

@override
String toString() {
  return 'StartupState(status: $status, config: $config, isObsoleteVersion: $isObsoleteVersion)';
}


}

/// @nodoc
abstract mixin class $StartupStateCopyWith<$Res>  {
  factory $StartupStateCopyWith(StartupState value, $Res Function(StartupState) _then) = _$StartupStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, StartupConfigEntity? config, bool isObsoleteVersion
});




}
/// @nodoc
class _$StartupStateCopyWithImpl<$Res>
    implements $StartupStateCopyWith<$Res> {
  _$StartupStateCopyWithImpl(this._self, this._then);

  final StartupState _self;
  final $Res Function(StartupState) _then;

/// Create a copy of StartupState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? config = freezed,Object? isObsoleteVersion = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,config: freezed == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as StartupConfigEntity?,isObsoleteVersion: null == isObsoleteVersion ? _self.isObsoleteVersion : isObsoleteVersion // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [StartupState].
extension StartupStatePatterns on StartupState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StartupState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StartupState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StartupState value)  $default,){
final _that = this;
switch (_that) {
case _StartupState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StartupState value)?  $default,){
final _that = this;
switch (_that) {
case _StartupState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  StartupConfigEntity? config,  bool isObsoleteVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StartupState() when $default != null:
return $default(_that.status,_that.config,_that.isObsoleteVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  StartupConfigEntity? config,  bool isObsoleteVersion)  $default,) {final _that = this;
switch (_that) {
case _StartupState():
return $default(_that.status,_that.config,_that.isObsoleteVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  StartupConfigEntity? config,  bool isObsoleteVersion)?  $default,) {final _that = this;
switch (_that) {
case _StartupState() when $default != null:
return $default(_that.status,_that.config,_that.isObsoleteVersion);case _:
  return null;

}
}

}

/// @nodoc


class _StartupState implements StartupState {
  const _StartupState({required this.status, required this.config, required this.isObsoleteVersion});
  

@override final  LoadStatus status;
@override final  StartupConfigEntity? config;
@override final  bool isObsoleteVersion;

/// Create a copy of StartupState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StartupStateCopyWith<_StartupState> get copyWith => __$StartupStateCopyWithImpl<_StartupState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StartupState&&(identical(other.status, status) || other.status == status)&&(identical(other.config, config) || other.config == config)&&(identical(other.isObsoleteVersion, isObsoleteVersion) || other.isObsoleteVersion == isObsoleteVersion));
}


@override
int get hashCode => Object.hash(runtimeType,status,config,isObsoleteVersion);

@override
String toString() {
  return 'StartupState(status: $status, config: $config, isObsoleteVersion: $isObsoleteVersion)';
}


}

/// @nodoc
abstract mixin class _$StartupStateCopyWith<$Res> implements $StartupStateCopyWith<$Res> {
  factory _$StartupStateCopyWith(_StartupState value, $Res Function(_StartupState) _then) = __$StartupStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, StartupConfigEntity? config, bool isObsoleteVersion
});




}
/// @nodoc
class __$StartupStateCopyWithImpl<$Res>
    implements _$StartupStateCopyWith<$Res> {
  __$StartupStateCopyWithImpl(this._self, this._then);

  final _StartupState _self;
  final $Res Function(_StartupState) _then;

/// Create a copy of StartupState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? config = freezed,Object? isObsoleteVersion = null,}) {
  return _then(_StartupState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,config: freezed == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as StartupConfigEntity?,isObsoleteVersion: null == isObsoleteVersion ? _self.isObsoleteVersion : isObsoleteVersion // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
