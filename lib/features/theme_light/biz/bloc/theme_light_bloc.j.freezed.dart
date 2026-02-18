// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'theme_light_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ThemeLightEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThemeLightEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ThemeLightEvent()';
}


}

/// @nodoc
class $ThemeLightEventCopyWith<$Res>  {
$ThemeLightEventCopyWith(ThemeLightEvent _, $Res Function(ThemeLightEvent) __);
}


/// Adds pattern-matching-related methods to [ThemeLightEvent].
extension ThemeLightEventPatterns on ThemeLightEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _Reloaded value)?  reloaded,TResult Function( _ThemeChanged value)?  themeChanged,TResult Function( _AccentChanged value)?  accentChanged,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _Reloaded() when reloaded != null:
return reloaded(_that);case _ThemeChanged() when themeChanged != null:
return themeChanged(_that);case _AccentChanged() when accentChanged != null:
return accentChanged(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _Reloaded value)  reloaded,required TResult Function( _ThemeChanged value)  themeChanged,required TResult Function( _AccentChanged value)  accentChanged,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _Reloaded():
return reloaded(_that);case _ThemeChanged():
return themeChanged(_that);case _AccentChanged():
return accentChanged(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _Reloaded value)?  reloaded,TResult? Function( _ThemeChanged value)?  themeChanged,TResult? Function( _AccentChanged value)?  accentChanged,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _Reloaded() when reloaded != null:
return reloaded(_that);case _ThemeChanged() when themeChanged != null:
return themeChanged(_that);case _AccentChanged() when accentChanged != null:
return accentChanged(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  started,TResult Function()?  reloaded,TResult Function( String themeId)?  themeChanged,TResult Function( int accentColorValue)?  accentChanged,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _Reloaded() when reloaded != null:
return reloaded();case _ThemeChanged() when themeChanged != null:
return themeChanged(_that.themeId);case _AccentChanged() when accentChanged != null:
return accentChanged(_that.accentColorValue);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  started,required TResult Function()  reloaded,required TResult Function( String themeId)  themeChanged,required TResult Function( int accentColorValue)  accentChanged,}) {final _that = this;
switch (_that) {
case _Started():
return started();case _Reloaded():
return reloaded();case _ThemeChanged():
return themeChanged(_that.themeId);case _AccentChanged():
return accentChanged(_that.accentColorValue);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  started,TResult? Function()?  reloaded,TResult? Function( String themeId)?  themeChanged,TResult? Function( int accentColorValue)?  accentChanged,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _Reloaded() when reloaded != null:
return reloaded();case _ThemeChanged() when themeChanged != null:
return themeChanged(_that.themeId);case _AccentChanged() when accentChanged != null:
return accentChanged(_that.accentColorValue);case _:
  return null;

}
}

}

/// @nodoc


class _Started implements ThemeLightEvent {
  const _Started();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ThemeLightEvent.started()';
}


}




/// @nodoc


class _Reloaded implements ThemeLightEvent {
  const _Reloaded();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Reloaded);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ThemeLightEvent.reloaded()';
}


}




/// @nodoc


class _ThemeChanged implements ThemeLightEvent {
  const _ThemeChanged({required this.themeId});
  

 final  String themeId;

/// Create a copy of ThemeLightEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ThemeChangedCopyWith<_ThemeChanged> get copyWith => __$ThemeChangedCopyWithImpl<_ThemeChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ThemeChanged&&(identical(other.themeId, themeId) || other.themeId == themeId));
}


@override
int get hashCode => Object.hash(runtimeType,themeId);

@override
String toString() {
  return 'ThemeLightEvent.themeChanged(themeId: $themeId)';
}


}

/// @nodoc
abstract mixin class _$ThemeChangedCopyWith<$Res> implements $ThemeLightEventCopyWith<$Res> {
  factory _$ThemeChangedCopyWith(_ThemeChanged value, $Res Function(_ThemeChanged) _then) = __$ThemeChangedCopyWithImpl;
@useResult
$Res call({
 String themeId
});




}
/// @nodoc
class __$ThemeChangedCopyWithImpl<$Res>
    implements _$ThemeChangedCopyWith<$Res> {
  __$ThemeChangedCopyWithImpl(this._self, this._then);

  final _ThemeChanged _self;
  final $Res Function(_ThemeChanged) _then;

/// Create a copy of ThemeLightEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? themeId = null,}) {
  return _then(_ThemeChanged(
themeId: null == themeId ? _self.themeId : themeId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _AccentChanged implements ThemeLightEvent {
  const _AccentChanged({required this.accentColorValue});
  

 final  int accentColorValue;

/// Create a copy of ThemeLightEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccentChangedCopyWith<_AccentChanged> get copyWith => __$AccentChangedCopyWithImpl<_AccentChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccentChanged&&(identical(other.accentColorValue, accentColorValue) || other.accentColorValue == accentColorValue));
}


@override
int get hashCode => Object.hash(runtimeType,accentColorValue);

@override
String toString() {
  return 'ThemeLightEvent.accentChanged(accentColorValue: $accentColorValue)';
}


}

/// @nodoc
abstract mixin class _$AccentChangedCopyWith<$Res> implements $ThemeLightEventCopyWith<$Res> {
  factory _$AccentChangedCopyWith(_AccentChanged value, $Res Function(_AccentChanged) _then) = __$AccentChangedCopyWithImpl;
@useResult
$Res call({
 int accentColorValue
});




}
/// @nodoc
class __$AccentChangedCopyWithImpl<$Res>
    implements _$AccentChangedCopyWith<$Res> {
  __$AccentChangedCopyWithImpl(this._self, this._then);

  final _AccentChanged _self;
  final $Res Function(_AccentChanged) _then;

/// Create a copy of ThemeLightEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? accentColorValue = null,}) {
  return _then(_AccentChanged(
accentColorValue: null == accentColorValue ? _self.accentColorValue : accentColorValue // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$ThemeLightState {

 LoadStatus get status; ActionStatus get actionStatus; ThemeLightEntity get theme; Failure? get failure;
/// Create a copy of ThemeLightState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ThemeLightStateCopyWith<ThemeLightState> get copyWith => _$ThemeLightStateCopyWithImpl<ThemeLightState>(this as ThemeLightState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThemeLightState&&(identical(other.status, status) || other.status == status)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&(identical(other.theme, theme) || other.theme == theme)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,status,actionStatus,theme,failure);

@override
String toString() {
  return 'ThemeLightState(status: $status, actionStatus: $actionStatus, theme: $theme, failure: $failure)';
}


}

/// @nodoc
abstract mixin class $ThemeLightStateCopyWith<$Res>  {
  factory $ThemeLightStateCopyWith(ThemeLightState value, $Res Function(ThemeLightState) _then) = _$ThemeLightStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, ActionStatus actionStatus, ThemeLightEntity theme, Failure? failure
});




}
/// @nodoc
class _$ThemeLightStateCopyWithImpl<$Res>
    implements $ThemeLightStateCopyWith<$Res> {
  _$ThemeLightStateCopyWithImpl(this._self, this._then);

  final ThemeLightState _self;
  final $Res Function(ThemeLightState) _then;

/// Create a copy of ThemeLightState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? actionStatus = null,Object? theme = null,Object? failure = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,actionStatus: null == actionStatus ? _self.actionStatus : actionStatus // ignore: cast_nullable_to_non_nullable
as ActionStatus,theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as ThemeLightEntity,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}

}


/// Adds pattern-matching-related methods to [ThemeLightState].
extension ThemeLightStatePatterns on ThemeLightState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ThemeLightState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ThemeLightState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ThemeLightState value)  $default,){
final _that = this;
switch (_that) {
case _ThemeLightState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ThemeLightState value)?  $default,){
final _that = this;
switch (_that) {
case _ThemeLightState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  ActionStatus actionStatus,  ThemeLightEntity theme,  Failure? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ThemeLightState() when $default != null:
return $default(_that.status,_that.actionStatus,_that.theme,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  ActionStatus actionStatus,  ThemeLightEntity theme,  Failure? failure)  $default,) {final _that = this;
switch (_that) {
case _ThemeLightState():
return $default(_that.status,_that.actionStatus,_that.theme,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  ActionStatus actionStatus,  ThemeLightEntity theme,  Failure? failure)?  $default,) {final _that = this;
switch (_that) {
case _ThemeLightState() when $default != null:
return $default(_that.status,_that.actionStatus,_that.theme,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _ThemeLightState implements ThemeLightState {
  const _ThemeLightState({required this.status, required this.actionStatus, required this.theme, this.failure});
  

@override final  LoadStatus status;
@override final  ActionStatus actionStatus;
@override final  ThemeLightEntity theme;
@override final  Failure? failure;

/// Create a copy of ThemeLightState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ThemeLightStateCopyWith<_ThemeLightState> get copyWith => __$ThemeLightStateCopyWithImpl<_ThemeLightState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ThemeLightState&&(identical(other.status, status) || other.status == status)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&(identical(other.theme, theme) || other.theme == theme)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,status,actionStatus,theme,failure);

@override
String toString() {
  return 'ThemeLightState(status: $status, actionStatus: $actionStatus, theme: $theme, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$ThemeLightStateCopyWith<$Res> implements $ThemeLightStateCopyWith<$Res> {
  factory _$ThemeLightStateCopyWith(_ThemeLightState value, $Res Function(_ThemeLightState) _then) = __$ThemeLightStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, ActionStatus actionStatus, ThemeLightEntity theme, Failure? failure
});




}
/// @nodoc
class __$ThemeLightStateCopyWithImpl<$Res>
    implements _$ThemeLightStateCopyWith<$Res> {
  __$ThemeLightStateCopyWithImpl(this._self, this._then);

  final _ThemeLightState _self;
  final $Res Function(_ThemeLightState) _then;

/// Create a copy of ThemeLightState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? actionStatus = null,Object? theme = null,Object? failure = freezed,}) {
  return _then(_ThemeLightState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,actionStatus: null == actionStatus ? _self.actionStatus : actionStatus // ignore: cast_nullable_to_non_nullable
as ActionStatus,theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as ThemeLightEntity,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}


}

// dart format on
