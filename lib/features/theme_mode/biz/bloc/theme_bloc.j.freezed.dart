// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'theme_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ThemeEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThemeEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ThemeEvent()';
}


}

/// @nodoc
class $ThemeEventCopyWith<$Res>  {
$ThemeEventCopyWith(ThemeEvent _, $Res Function(ThemeEvent) __);
}


/// Adds pattern-matching-related methods to [ThemeEvent].
extension ThemeEventPatterns on ThemeEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _LightThemeChanged value)?  lightThemeChanged,TResult Function( _LightAccentChanged value)?  lightAccentChanged,TResult Function( _DarkThemeChanged value)?  darkThemeChanged,TResult Function( _DarkAccentChanged value)?  darkAccentChanged,TResult Function( _ModeChanged value)?  modeChanged,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _LightThemeChanged() when lightThemeChanged != null:
return lightThemeChanged(_that);case _LightAccentChanged() when lightAccentChanged != null:
return lightAccentChanged(_that);case _DarkThemeChanged() when darkThemeChanged != null:
return darkThemeChanged(_that);case _DarkAccentChanged() when darkAccentChanged != null:
return darkAccentChanged(_that);case _ModeChanged() when modeChanged != null:
return modeChanged(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _LightThemeChanged value)  lightThemeChanged,required TResult Function( _LightAccentChanged value)  lightAccentChanged,required TResult Function( _DarkThemeChanged value)  darkThemeChanged,required TResult Function( _DarkAccentChanged value)  darkAccentChanged,required TResult Function( _ModeChanged value)  modeChanged,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _LightThemeChanged():
return lightThemeChanged(_that);case _LightAccentChanged():
return lightAccentChanged(_that);case _DarkThemeChanged():
return darkThemeChanged(_that);case _DarkAccentChanged():
return darkAccentChanged(_that);case _ModeChanged():
return modeChanged(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _LightThemeChanged value)?  lightThemeChanged,TResult? Function( _LightAccentChanged value)?  lightAccentChanged,TResult? Function( _DarkThemeChanged value)?  darkThemeChanged,TResult? Function( _DarkAccentChanged value)?  darkAccentChanged,TResult? Function( _ModeChanged value)?  modeChanged,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _LightThemeChanged() when lightThemeChanged != null:
return lightThemeChanged(_that);case _LightAccentChanged() when lightAccentChanged != null:
return lightAccentChanged(_that);case _DarkThemeChanged() when darkThemeChanged != null:
return darkThemeChanged(_that);case _DarkAccentChanged() when darkAccentChanged != null:
return darkAccentChanged(_that);case _ModeChanged() when modeChanged != null:
return modeChanged(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  started,TResult Function( String themeId)?  lightThemeChanged,TResult Function( int accentColorValue)?  lightAccentChanged,TResult Function( String themeId)?  darkThemeChanged,TResult Function( int accentColorValue)?  darkAccentChanged,TResult Function( ThemeMode mode)?  modeChanged,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _LightThemeChanged() when lightThemeChanged != null:
return lightThemeChanged(_that.themeId);case _LightAccentChanged() when lightAccentChanged != null:
return lightAccentChanged(_that.accentColorValue);case _DarkThemeChanged() when darkThemeChanged != null:
return darkThemeChanged(_that.themeId);case _DarkAccentChanged() when darkAccentChanged != null:
return darkAccentChanged(_that.accentColorValue);case _ModeChanged() when modeChanged != null:
return modeChanged(_that.mode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  started,required TResult Function( String themeId)  lightThemeChanged,required TResult Function( int accentColorValue)  lightAccentChanged,required TResult Function( String themeId)  darkThemeChanged,required TResult Function( int accentColorValue)  darkAccentChanged,required TResult Function( ThemeMode mode)  modeChanged,}) {final _that = this;
switch (_that) {
case _Started():
return started();case _LightThemeChanged():
return lightThemeChanged(_that.themeId);case _LightAccentChanged():
return lightAccentChanged(_that.accentColorValue);case _DarkThemeChanged():
return darkThemeChanged(_that.themeId);case _DarkAccentChanged():
return darkAccentChanged(_that.accentColorValue);case _ModeChanged():
return modeChanged(_that.mode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  started,TResult? Function( String themeId)?  lightThemeChanged,TResult? Function( int accentColorValue)?  lightAccentChanged,TResult? Function( String themeId)?  darkThemeChanged,TResult? Function( int accentColorValue)?  darkAccentChanged,TResult? Function( ThemeMode mode)?  modeChanged,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _LightThemeChanged() when lightThemeChanged != null:
return lightThemeChanged(_that.themeId);case _LightAccentChanged() when lightAccentChanged != null:
return lightAccentChanged(_that.accentColorValue);case _DarkThemeChanged() when darkThemeChanged != null:
return darkThemeChanged(_that.themeId);case _DarkAccentChanged() when darkAccentChanged != null:
return darkAccentChanged(_that.accentColorValue);case _ModeChanged() when modeChanged != null:
return modeChanged(_that.mode);case _:
  return null;

}
}

}

/// @nodoc


class _Started implements ThemeEvent {
  const _Started();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ThemeEvent.started()';
}


}




/// @nodoc


class _LightThemeChanged implements ThemeEvent {
  const _LightThemeChanged({required this.themeId});
  

 final  String themeId;

/// Create a copy of ThemeEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LightThemeChangedCopyWith<_LightThemeChanged> get copyWith => __$LightThemeChangedCopyWithImpl<_LightThemeChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LightThemeChanged&&(identical(other.themeId, themeId) || other.themeId == themeId));
}


@override
int get hashCode => Object.hash(runtimeType,themeId);

@override
String toString() {
  return 'ThemeEvent.lightThemeChanged(themeId: $themeId)';
}


}

/// @nodoc
abstract mixin class _$LightThemeChangedCopyWith<$Res> implements $ThemeEventCopyWith<$Res> {
  factory _$LightThemeChangedCopyWith(_LightThemeChanged value, $Res Function(_LightThemeChanged) _then) = __$LightThemeChangedCopyWithImpl;
@useResult
$Res call({
 String themeId
});




}
/// @nodoc
class __$LightThemeChangedCopyWithImpl<$Res>
    implements _$LightThemeChangedCopyWith<$Res> {
  __$LightThemeChangedCopyWithImpl(this._self, this._then);

  final _LightThemeChanged _self;
  final $Res Function(_LightThemeChanged) _then;

/// Create a copy of ThemeEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? themeId = null,}) {
  return _then(_LightThemeChanged(
themeId: null == themeId ? _self.themeId : themeId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _LightAccentChanged implements ThemeEvent {
  const _LightAccentChanged({required this.accentColorValue});
  

 final  int accentColorValue;

/// Create a copy of ThemeEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LightAccentChangedCopyWith<_LightAccentChanged> get copyWith => __$LightAccentChangedCopyWithImpl<_LightAccentChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LightAccentChanged&&(identical(other.accentColorValue, accentColorValue) || other.accentColorValue == accentColorValue));
}


@override
int get hashCode => Object.hash(runtimeType,accentColorValue);

@override
String toString() {
  return 'ThemeEvent.lightAccentChanged(accentColorValue: $accentColorValue)';
}


}

/// @nodoc
abstract mixin class _$LightAccentChangedCopyWith<$Res> implements $ThemeEventCopyWith<$Res> {
  factory _$LightAccentChangedCopyWith(_LightAccentChanged value, $Res Function(_LightAccentChanged) _then) = __$LightAccentChangedCopyWithImpl;
@useResult
$Res call({
 int accentColorValue
});




}
/// @nodoc
class __$LightAccentChangedCopyWithImpl<$Res>
    implements _$LightAccentChangedCopyWith<$Res> {
  __$LightAccentChangedCopyWithImpl(this._self, this._then);

  final _LightAccentChanged _self;
  final $Res Function(_LightAccentChanged) _then;

/// Create a copy of ThemeEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? accentColorValue = null,}) {
  return _then(_LightAccentChanged(
accentColorValue: null == accentColorValue ? _self.accentColorValue : accentColorValue // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _DarkThemeChanged implements ThemeEvent {
  const _DarkThemeChanged({required this.themeId});
  

 final  String themeId;

/// Create a copy of ThemeEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DarkThemeChangedCopyWith<_DarkThemeChanged> get copyWith => __$DarkThemeChangedCopyWithImpl<_DarkThemeChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DarkThemeChanged&&(identical(other.themeId, themeId) || other.themeId == themeId));
}


@override
int get hashCode => Object.hash(runtimeType,themeId);

@override
String toString() {
  return 'ThemeEvent.darkThemeChanged(themeId: $themeId)';
}


}

/// @nodoc
abstract mixin class _$DarkThemeChangedCopyWith<$Res> implements $ThemeEventCopyWith<$Res> {
  factory _$DarkThemeChangedCopyWith(_DarkThemeChanged value, $Res Function(_DarkThemeChanged) _then) = __$DarkThemeChangedCopyWithImpl;
@useResult
$Res call({
 String themeId
});




}
/// @nodoc
class __$DarkThemeChangedCopyWithImpl<$Res>
    implements _$DarkThemeChangedCopyWith<$Res> {
  __$DarkThemeChangedCopyWithImpl(this._self, this._then);

  final _DarkThemeChanged _self;
  final $Res Function(_DarkThemeChanged) _then;

/// Create a copy of ThemeEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? themeId = null,}) {
  return _then(_DarkThemeChanged(
themeId: null == themeId ? _self.themeId : themeId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _DarkAccentChanged implements ThemeEvent {
  const _DarkAccentChanged({required this.accentColorValue});
  

 final  int accentColorValue;

/// Create a copy of ThemeEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DarkAccentChangedCopyWith<_DarkAccentChanged> get copyWith => __$DarkAccentChangedCopyWithImpl<_DarkAccentChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DarkAccentChanged&&(identical(other.accentColorValue, accentColorValue) || other.accentColorValue == accentColorValue));
}


@override
int get hashCode => Object.hash(runtimeType,accentColorValue);

@override
String toString() {
  return 'ThemeEvent.darkAccentChanged(accentColorValue: $accentColorValue)';
}


}

/// @nodoc
abstract mixin class _$DarkAccentChangedCopyWith<$Res> implements $ThemeEventCopyWith<$Res> {
  factory _$DarkAccentChangedCopyWith(_DarkAccentChanged value, $Res Function(_DarkAccentChanged) _then) = __$DarkAccentChangedCopyWithImpl;
@useResult
$Res call({
 int accentColorValue
});




}
/// @nodoc
class __$DarkAccentChangedCopyWithImpl<$Res>
    implements _$DarkAccentChangedCopyWith<$Res> {
  __$DarkAccentChangedCopyWithImpl(this._self, this._then);

  final _DarkAccentChanged _self;
  final $Res Function(_DarkAccentChanged) _then;

/// Create a copy of ThemeEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? accentColorValue = null,}) {
  return _then(_DarkAccentChanged(
accentColorValue: null == accentColorValue ? _self.accentColorValue : accentColorValue // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _ModeChanged implements ThemeEvent {
  const _ModeChanged({required this.mode});
  

 final  ThemeMode mode;

/// Create a copy of ThemeEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModeChangedCopyWith<_ModeChanged> get copyWith => __$ModeChangedCopyWithImpl<_ModeChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ModeChanged&&(identical(other.mode, mode) || other.mode == mode));
}


@override
int get hashCode => Object.hash(runtimeType,mode);

@override
String toString() {
  return 'ThemeEvent.modeChanged(mode: $mode)';
}


}

/// @nodoc
abstract mixin class _$ModeChangedCopyWith<$Res> implements $ThemeEventCopyWith<$Res> {
  factory _$ModeChangedCopyWith(_ModeChanged value, $Res Function(_ModeChanged) _then) = __$ModeChangedCopyWithImpl;
@useResult
$Res call({
 ThemeMode mode
});




}
/// @nodoc
class __$ModeChangedCopyWithImpl<$Res>
    implements _$ModeChangedCopyWith<$Res> {
  __$ModeChangedCopyWithImpl(this._self, this._then);

  final _ModeChanged _self;
  final $Res Function(_ModeChanged) _then;

/// Create a copy of ThemeEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mode = null,}) {
  return _then(_ModeChanged(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as ThemeMode,
  ));
}


}

/// @nodoc
mixin _$ThemeState {

 LoadStatus get status; ActionStatus get actionStatus; ThemeSelection get light; ThemeSelection get dark; ThemeMode get mode; Failure? get failure;
/// Create a copy of ThemeState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ThemeStateCopyWith<ThemeState> get copyWith => _$ThemeStateCopyWithImpl<ThemeState>(this as ThemeState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThemeState&&(identical(other.status, status) || other.status == status)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&(identical(other.light, light) || other.light == light)&&(identical(other.dark, dark) || other.dark == dark)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,status,actionStatus,light,dark,mode,failure);

@override
String toString() {
  return 'ThemeState(status: $status, actionStatus: $actionStatus, light: $light, dark: $dark, mode: $mode, failure: $failure)';
}


}

/// @nodoc
abstract mixin class $ThemeStateCopyWith<$Res>  {
  factory $ThemeStateCopyWith(ThemeState value, $Res Function(ThemeState) _then) = _$ThemeStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, ActionStatus actionStatus, ThemeSelection light, ThemeSelection dark, ThemeMode mode, Failure? failure
});




}
/// @nodoc
class _$ThemeStateCopyWithImpl<$Res>
    implements $ThemeStateCopyWith<$Res> {
  _$ThemeStateCopyWithImpl(this._self, this._then);

  final ThemeState _self;
  final $Res Function(ThemeState) _then;

/// Create a copy of ThemeState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? actionStatus = null,Object? light = null,Object? dark = null,Object? mode = null,Object? failure = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,actionStatus: null == actionStatus ? _self.actionStatus : actionStatus // ignore: cast_nullable_to_non_nullable
as ActionStatus,light: null == light ? _self.light : light // ignore: cast_nullable_to_non_nullable
as ThemeSelection,dark: null == dark ? _self.dark : dark // ignore: cast_nullable_to_non_nullable
as ThemeSelection,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as ThemeMode,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}

}


/// Adds pattern-matching-related methods to [ThemeState].
extension ThemeStatePatterns on ThemeState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ThemeState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ThemeState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ThemeState value)  $default,){
final _that = this;
switch (_that) {
case _ThemeState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ThemeState value)?  $default,){
final _that = this;
switch (_that) {
case _ThemeState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  ActionStatus actionStatus,  ThemeSelection light,  ThemeSelection dark,  ThemeMode mode,  Failure? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ThemeState() when $default != null:
return $default(_that.status,_that.actionStatus,_that.light,_that.dark,_that.mode,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  ActionStatus actionStatus,  ThemeSelection light,  ThemeSelection dark,  ThemeMode mode,  Failure? failure)  $default,) {final _that = this;
switch (_that) {
case _ThemeState():
return $default(_that.status,_that.actionStatus,_that.light,_that.dark,_that.mode,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  ActionStatus actionStatus,  ThemeSelection light,  ThemeSelection dark,  ThemeMode mode,  Failure? failure)?  $default,) {final _that = this;
switch (_that) {
case _ThemeState() when $default != null:
return $default(_that.status,_that.actionStatus,_that.light,_that.dark,_that.mode,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _ThemeState implements ThemeState {
  const _ThemeState({required this.status, required this.actionStatus, required this.light, required this.dark, required this.mode, this.failure});
  

@override final  LoadStatus status;
@override final  ActionStatus actionStatus;
@override final  ThemeSelection light;
@override final  ThemeSelection dark;
@override final  ThemeMode mode;
@override final  Failure? failure;

/// Create a copy of ThemeState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ThemeStateCopyWith<_ThemeState> get copyWith => __$ThemeStateCopyWithImpl<_ThemeState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ThemeState&&(identical(other.status, status) || other.status == status)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&(identical(other.light, light) || other.light == light)&&(identical(other.dark, dark) || other.dark == dark)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,status,actionStatus,light,dark,mode,failure);

@override
String toString() {
  return 'ThemeState(status: $status, actionStatus: $actionStatus, light: $light, dark: $dark, mode: $mode, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$ThemeStateCopyWith<$Res> implements $ThemeStateCopyWith<$Res> {
  factory _$ThemeStateCopyWith(_ThemeState value, $Res Function(_ThemeState) _then) = __$ThemeStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, ActionStatus actionStatus, ThemeSelection light, ThemeSelection dark, ThemeMode mode, Failure? failure
});




}
/// @nodoc
class __$ThemeStateCopyWithImpl<$Res>
    implements _$ThemeStateCopyWith<$Res> {
  __$ThemeStateCopyWithImpl(this._self, this._then);

  final _ThemeState _self;
  final $Res Function(_ThemeState) _then;

/// Create a copy of ThemeState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? actionStatus = null,Object? light = null,Object? dark = null,Object? mode = null,Object? failure = freezed,}) {
  return _then(_ThemeState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,actionStatus: null == actionStatus ? _self.actionStatus : actionStatus // ignore: cast_nullable_to_non_nullable
as ActionStatus,light: null == light ? _self.light : light // ignore: cast_nullable_to_non_nullable
as ThemeSelection,dark: null == dark ? _self.dark : dark // ignore: cast_nullable_to_non_nullable
as ThemeSelection,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as ThemeMode,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}


}

// dart format on
