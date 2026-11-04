// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'day_night_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DayNightEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DayNightEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DayNightEvent()';
}


}

/// @nodoc
class $DayNightEventCopyWith<$Res>  {
$DayNightEventCopyWith(DayNightEvent _, $Res Function(DayNightEvent) __);
}


/// Adds pattern-matching-related methods to [DayNightEvent].
extension DayNightEventPatterns on DayNightEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _EntitlementChanged value)?  entitlementChanged,TResult Function( _WallPicked value)?  wallPicked,TResult Function( _VariantsPicked value)?  variantsPicked,TResult Function( _TimesChanged value)?  timesChanged,TResult Function( _TargetChanged value)?  targetChanged,TResult Function( _Toggled value)?  toggled,TResult Function( _RetryPressed value)?  retryPressed,TResult Function( _ProLapseAcknowledged value)?  proLapseAcknowledged,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EntitlementChanged() when entitlementChanged != null:
return entitlementChanged(_that);case _WallPicked() when wallPicked != null:
return wallPicked(_that);case _VariantsPicked() when variantsPicked != null:
return variantsPicked(_that);case _TimesChanged() when timesChanged != null:
return timesChanged(_that);case _TargetChanged() when targetChanged != null:
return targetChanged(_that);case _Toggled() when toggled != null:
return toggled(_that);case _RetryPressed() when retryPressed != null:
return retryPressed(_that);case _ProLapseAcknowledged() when proLapseAcknowledged != null:
return proLapseAcknowledged(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _EntitlementChanged value)  entitlementChanged,required TResult Function( _WallPicked value)  wallPicked,required TResult Function( _VariantsPicked value)  variantsPicked,required TResult Function( _TimesChanged value)  timesChanged,required TResult Function( _TargetChanged value)  targetChanged,required TResult Function( _Toggled value)  toggled,required TResult Function( _RetryPressed value)  retryPressed,required TResult Function( _ProLapseAcknowledged value)  proLapseAcknowledged,}){
final _that = this;
switch (_that) {
case _EntitlementChanged():
return entitlementChanged(_that);case _WallPicked():
return wallPicked(_that);case _VariantsPicked():
return variantsPicked(_that);case _TimesChanged():
return timesChanged(_that);case _TargetChanged():
return targetChanged(_that);case _Toggled():
return toggled(_that);case _RetryPressed():
return retryPressed(_that);case _ProLapseAcknowledged():
return proLapseAcknowledged(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _EntitlementChanged value)?  entitlementChanged,TResult? Function( _WallPicked value)?  wallPicked,TResult? Function( _VariantsPicked value)?  variantsPicked,TResult? Function( _TimesChanged value)?  timesChanged,TResult? Function( _TargetChanged value)?  targetChanged,TResult? Function( _Toggled value)?  toggled,TResult? Function( _RetryPressed value)?  retryPressed,TResult? Function( _ProLapseAcknowledged value)?  proLapseAcknowledged,}){
final _that = this;
switch (_that) {
case _EntitlementChanged() when entitlementChanged != null:
return entitlementChanged(_that);case _WallPicked() when wallPicked != null:
return wallPicked(_that);case _VariantsPicked() when variantsPicked != null:
return variantsPicked(_that);case _TimesChanged() when timesChanged != null:
return timesChanged(_that);case _TargetChanged() when targetChanged != null:
return targetChanged(_that);case _Toggled() when toggled != null:
return toggled(_that);case _RetryPressed() when retryPressed != null:
return retryPressed(_that);case _ProLapseAcknowledged() when proLapseAcknowledged != null:
return proLapseAcknowledged(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( bool isPro,  String userId)?  entitlementChanged,TResult Function( DayNightSlot slot,  DayNightWall wall)?  wallPicked,TResult Function( DayNightWall day,  DayNightWall night)?  variantsPicked,TResult Function( DayTime dayStart,  DayTime nightStart)?  timesChanged,TResult Function( WallpaperTarget target)?  targetChanged,TResult Function( bool enabled)?  toggled,TResult Function()?  retryPressed,TResult Function()?  proLapseAcknowledged,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EntitlementChanged() when entitlementChanged != null:
return entitlementChanged(_that.isPro,_that.userId);case _WallPicked() when wallPicked != null:
return wallPicked(_that.slot,_that.wall);case _VariantsPicked() when variantsPicked != null:
return variantsPicked(_that.day,_that.night);case _TimesChanged() when timesChanged != null:
return timesChanged(_that.dayStart,_that.nightStart);case _TargetChanged() when targetChanged != null:
return targetChanged(_that.target);case _Toggled() when toggled != null:
return toggled(_that.enabled);case _RetryPressed() when retryPressed != null:
return retryPressed();case _ProLapseAcknowledged() when proLapseAcknowledged != null:
return proLapseAcknowledged();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( bool isPro,  String userId)  entitlementChanged,required TResult Function( DayNightSlot slot,  DayNightWall wall)  wallPicked,required TResult Function( DayNightWall day,  DayNightWall night)  variantsPicked,required TResult Function( DayTime dayStart,  DayTime nightStart)  timesChanged,required TResult Function( WallpaperTarget target)  targetChanged,required TResult Function( bool enabled)  toggled,required TResult Function()  retryPressed,required TResult Function()  proLapseAcknowledged,}) {final _that = this;
switch (_that) {
case _EntitlementChanged():
return entitlementChanged(_that.isPro,_that.userId);case _WallPicked():
return wallPicked(_that.slot,_that.wall);case _VariantsPicked():
return variantsPicked(_that.day,_that.night);case _TimesChanged():
return timesChanged(_that.dayStart,_that.nightStart);case _TargetChanged():
return targetChanged(_that.target);case _Toggled():
return toggled(_that.enabled);case _RetryPressed():
return retryPressed();case _ProLapseAcknowledged():
return proLapseAcknowledged();case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( bool isPro,  String userId)?  entitlementChanged,TResult? Function( DayNightSlot slot,  DayNightWall wall)?  wallPicked,TResult? Function( DayNightWall day,  DayNightWall night)?  variantsPicked,TResult? Function( DayTime dayStart,  DayTime nightStart)?  timesChanged,TResult? Function( WallpaperTarget target)?  targetChanged,TResult? Function( bool enabled)?  toggled,TResult? Function()?  retryPressed,TResult? Function()?  proLapseAcknowledged,}) {final _that = this;
switch (_that) {
case _EntitlementChanged() when entitlementChanged != null:
return entitlementChanged(_that.isPro,_that.userId);case _WallPicked() when wallPicked != null:
return wallPicked(_that.slot,_that.wall);case _VariantsPicked() when variantsPicked != null:
return variantsPicked(_that.day,_that.night);case _TimesChanged() when timesChanged != null:
return timesChanged(_that.dayStart,_that.nightStart);case _TargetChanged() when targetChanged != null:
return targetChanged(_that.target);case _Toggled() when toggled != null:
return toggled(_that.enabled);case _RetryPressed() when retryPressed != null:
return retryPressed();case _ProLapseAcknowledged() when proLapseAcknowledged != null:
return proLapseAcknowledged();case _:
  return null;

}
}

}

/// @nodoc


class _EntitlementChanged implements DayNightEvent {
  const _EntitlementChanged({required this.isPro, required this.userId});
  

 final  bool isPro;
 final  String userId;

/// Create a copy of DayNightEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EntitlementChangedCopyWith<_EntitlementChanged> get copyWith => __$EntitlementChangedCopyWithImpl<_EntitlementChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EntitlementChanged&&(identical(other.isPro, isPro) || other.isPro == isPro)&&(identical(other.userId, userId) || other.userId == userId));
}


@override
int get hashCode => Object.hash(runtimeType,isPro,userId);

@override
String toString() {
  return 'DayNightEvent.entitlementChanged(isPro: $isPro, userId: $userId)';
}


}

/// @nodoc
abstract mixin class _$EntitlementChangedCopyWith<$Res> implements $DayNightEventCopyWith<$Res> {
  factory _$EntitlementChangedCopyWith(_EntitlementChanged value, $Res Function(_EntitlementChanged) _then) = __$EntitlementChangedCopyWithImpl;
@useResult
$Res call({
 bool isPro, String userId
});




}
/// @nodoc
class __$EntitlementChangedCopyWithImpl<$Res>
    implements _$EntitlementChangedCopyWith<$Res> {
  __$EntitlementChangedCopyWithImpl(this._self, this._then);

  final _EntitlementChanged _self;
  final $Res Function(_EntitlementChanged) _then;

/// Create a copy of DayNightEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? isPro = null,Object? userId = null,}) {
  return _then(_EntitlementChanged(
isPro: null == isPro ? _self.isPro : isPro // ignore: cast_nullable_to_non_nullable
as bool,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _WallPicked implements DayNightEvent {
  const _WallPicked(this.slot, this.wall);
  

 final  DayNightSlot slot;
 final  DayNightWall wall;

/// Create a copy of DayNightEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WallPickedCopyWith<_WallPicked> get copyWith => __$WallPickedCopyWithImpl<_WallPicked>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WallPicked&&(identical(other.slot, slot) || other.slot == slot)&&(identical(other.wall, wall) || other.wall == wall));
}


@override
int get hashCode => Object.hash(runtimeType,slot,wall);

@override
String toString() {
  return 'DayNightEvent.wallPicked(slot: $slot, wall: $wall)';
}


}

/// @nodoc
abstract mixin class _$WallPickedCopyWith<$Res> implements $DayNightEventCopyWith<$Res> {
  factory _$WallPickedCopyWith(_WallPicked value, $Res Function(_WallPicked) _then) = __$WallPickedCopyWithImpl;
@useResult
$Res call({
 DayNightSlot slot, DayNightWall wall
});




}
/// @nodoc
class __$WallPickedCopyWithImpl<$Res>
    implements _$WallPickedCopyWith<$Res> {
  __$WallPickedCopyWithImpl(this._self, this._then);

  final _WallPicked _self;
  final $Res Function(_WallPicked) _then;

/// Create a copy of DayNightEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? slot = null,Object? wall = null,}) {
  return _then(_WallPicked(
null == slot ? _self.slot : slot // ignore: cast_nullable_to_non_nullable
as DayNightSlot,null == wall ? _self.wall : wall // ignore: cast_nullable_to_non_nullable
as DayNightWall,
  ));
}


}

/// @nodoc


class _VariantsPicked implements DayNightEvent {
  const _VariantsPicked({required this.day, required this.night});
  

 final  DayNightWall day;
 final  DayNightWall night;

/// Create a copy of DayNightEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VariantsPickedCopyWith<_VariantsPicked> get copyWith => __$VariantsPickedCopyWithImpl<_VariantsPicked>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VariantsPicked&&(identical(other.day, day) || other.day == day)&&(identical(other.night, night) || other.night == night));
}


@override
int get hashCode => Object.hash(runtimeType,day,night);

@override
String toString() {
  return 'DayNightEvent.variantsPicked(day: $day, night: $night)';
}


}

/// @nodoc
abstract mixin class _$VariantsPickedCopyWith<$Res> implements $DayNightEventCopyWith<$Res> {
  factory _$VariantsPickedCopyWith(_VariantsPicked value, $Res Function(_VariantsPicked) _then) = __$VariantsPickedCopyWithImpl;
@useResult
$Res call({
 DayNightWall day, DayNightWall night
});




}
/// @nodoc
class __$VariantsPickedCopyWithImpl<$Res>
    implements _$VariantsPickedCopyWith<$Res> {
  __$VariantsPickedCopyWithImpl(this._self, this._then);

  final _VariantsPicked _self;
  final $Res Function(_VariantsPicked) _then;

/// Create a copy of DayNightEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? day = null,Object? night = null,}) {
  return _then(_VariantsPicked(
day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as DayNightWall,night: null == night ? _self.night : night // ignore: cast_nullable_to_non_nullable
as DayNightWall,
  ));
}


}

/// @nodoc


class _TimesChanged implements DayNightEvent {
  const _TimesChanged({required this.dayStart, required this.nightStart});
  

 final  DayTime dayStart;
 final  DayTime nightStart;

/// Create a copy of DayNightEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TimesChangedCopyWith<_TimesChanged> get copyWith => __$TimesChangedCopyWithImpl<_TimesChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TimesChanged&&(identical(other.dayStart, dayStart) || other.dayStart == dayStart)&&(identical(other.nightStart, nightStart) || other.nightStart == nightStart));
}


@override
int get hashCode => Object.hash(runtimeType,dayStart,nightStart);

@override
String toString() {
  return 'DayNightEvent.timesChanged(dayStart: $dayStart, nightStart: $nightStart)';
}


}

/// @nodoc
abstract mixin class _$TimesChangedCopyWith<$Res> implements $DayNightEventCopyWith<$Res> {
  factory _$TimesChangedCopyWith(_TimesChanged value, $Res Function(_TimesChanged) _then) = __$TimesChangedCopyWithImpl;
@useResult
$Res call({
 DayTime dayStart, DayTime nightStart
});




}
/// @nodoc
class __$TimesChangedCopyWithImpl<$Res>
    implements _$TimesChangedCopyWith<$Res> {
  __$TimesChangedCopyWithImpl(this._self, this._then);

  final _TimesChanged _self;
  final $Res Function(_TimesChanged) _then;

/// Create a copy of DayNightEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? dayStart = null,Object? nightStart = null,}) {
  return _then(_TimesChanged(
dayStart: null == dayStart ? _self.dayStart : dayStart // ignore: cast_nullable_to_non_nullable
as DayTime,nightStart: null == nightStart ? _self.nightStart : nightStart // ignore: cast_nullable_to_non_nullable
as DayTime,
  ));
}


}

/// @nodoc


class _TargetChanged implements DayNightEvent {
  const _TargetChanged(this.target);
  

 final  WallpaperTarget target;

/// Create a copy of DayNightEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TargetChangedCopyWith<_TargetChanged> get copyWith => __$TargetChangedCopyWithImpl<_TargetChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TargetChanged&&(identical(other.target, target) || other.target == target));
}


@override
int get hashCode => Object.hash(runtimeType,target);

@override
String toString() {
  return 'DayNightEvent.targetChanged(target: $target)';
}


}

/// @nodoc
abstract mixin class _$TargetChangedCopyWith<$Res> implements $DayNightEventCopyWith<$Res> {
  factory _$TargetChangedCopyWith(_TargetChanged value, $Res Function(_TargetChanged) _then) = __$TargetChangedCopyWithImpl;
@useResult
$Res call({
 WallpaperTarget target
});




}
/// @nodoc
class __$TargetChangedCopyWithImpl<$Res>
    implements _$TargetChangedCopyWith<$Res> {
  __$TargetChangedCopyWithImpl(this._self, this._then);

  final _TargetChanged _self;
  final $Res Function(_TargetChanged) _then;

/// Create a copy of DayNightEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? target = null,}) {
  return _then(_TargetChanged(
null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as WallpaperTarget,
  ));
}


}

/// @nodoc


class _Toggled implements DayNightEvent {
  const _Toggled(this.enabled);
  

 final  bool enabled;

/// Create a copy of DayNightEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ToggledCopyWith<_Toggled> get copyWith => __$ToggledCopyWithImpl<_Toggled>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Toggled&&(identical(other.enabled, enabled) || other.enabled == enabled));
}


@override
int get hashCode => Object.hash(runtimeType,enabled);

@override
String toString() {
  return 'DayNightEvent.toggled(enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class _$ToggledCopyWith<$Res> implements $DayNightEventCopyWith<$Res> {
  factory _$ToggledCopyWith(_Toggled value, $Res Function(_Toggled) _then) = __$ToggledCopyWithImpl;
@useResult
$Res call({
 bool enabled
});




}
/// @nodoc
class __$ToggledCopyWithImpl<$Res>
    implements _$ToggledCopyWith<$Res> {
  __$ToggledCopyWithImpl(this._self, this._then);

  final _Toggled _self;
  final $Res Function(_Toggled) _then;

/// Create a copy of DayNightEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? enabled = null,}) {
  return _then(_Toggled(
null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class _RetryPressed implements DayNightEvent {
  const _RetryPressed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RetryPressed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DayNightEvent.retryPressed()';
}


}




/// @nodoc


class _ProLapseAcknowledged implements DayNightEvent {
  const _ProLapseAcknowledged();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProLapseAcknowledged);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DayNightEvent.proLapseAcknowledged()';
}


}




/// @nodoc
mixin _$DayNightState {

 DayNightPair get pair; bool get loaded; bool get isPro; String get userId; bool get preparing; DayNightIssue? get issue; bool get proLapsed;
/// Create a copy of DayNightState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DayNightStateCopyWith<DayNightState> get copyWith => _$DayNightStateCopyWithImpl<DayNightState>(this as DayNightState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DayNightState&&(identical(other.pair, pair) || other.pair == pair)&&(identical(other.loaded, loaded) || other.loaded == loaded)&&(identical(other.isPro, isPro) || other.isPro == isPro)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.preparing, preparing) || other.preparing == preparing)&&(identical(other.issue, issue) || other.issue == issue)&&(identical(other.proLapsed, proLapsed) || other.proLapsed == proLapsed));
}


@override
int get hashCode => Object.hash(runtimeType,pair,loaded,isPro,userId,preparing,issue,proLapsed);

@override
String toString() {
  return 'DayNightState(pair: $pair, loaded: $loaded, isPro: $isPro, userId: $userId, preparing: $preparing, issue: $issue, proLapsed: $proLapsed)';
}


}

/// @nodoc
abstract mixin class $DayNightStateCopyWith<$Res>  {
  factory $DayNightStateCopyWith(DayNightState value, $Res Function(DayNightState) _then) = _$DayNightStateCopyWithImpl;
@useResult
$Res call({
 DayNightPair pair, bool loaded, bool isPro, String userId, bool preparing, DayNightIssue? issue, bool proLapsed
});




}
/// @nodoc
class _$DayNightStateCopyWithImpl<$Res>
    implements $DayNightStateCopyWith<$Res> {
  _$DayNightStateCopyWithImpl(this._self, this._then);

  final DayNightState _self;
  final $Res Function(DayNightState) _then;

/// Create a copy of DayNightState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pair = null,Object? loaded = null,Object? isPro = null,Object? userId = null,Object? preparing = null,Object? issue = freezed,Object? proLapsed = null,}) {
  return _then(_self.copyWith(
pair: null == pair ? _self.pair : pair // ignore: cast_nullable_to_non_nullable
as DayNightPair,loaded: null == loaded ? _self.loaded : loaded // ignore: cast_nullable_to_non_nullable
as bool,isPro: null == isPro ? _self.isPro : isPro // ignore: cast_nullable_to_non_nullable
as bool,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,preparing: null == preparing ? _self.preparing : preparing // ignore: cast_nullable_to_non_nullable
as bool,issue: freezed == issue ? _self.issue : issue // ignore: cast_nullable_to_non_nullable
as DayNightIssue?,proLapsed: null == proLapsed ? _self.proLapsed : proLapsed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [DayNightState].
extension DayNightStatePatterns on DayNightState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DayNightState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DayNightState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DayNightState value)  $default,){
final _that = this;
switch (_that) {
case _DayNightState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DayNightState value)?  $default,){
final _that = this;
switch (_that) {
case _DayNightState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DayNightPair pair,  bool loaded,  bool isPro,  String userId,  bool preparing,  DayNightIssue? issue,  bool proLapsed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DayNightState() when $default != null:
return $default(_that.pair,_that.loaded,_that.isPro,_that.userId,_that.preparing,_that.issue,_that.proLapsed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DayNightPair pair,  bool loaded,  bool isPro,  String userId,  bool preparing,  DayNightIssue? issue,  bool proLapsed)  $default,) {final _that = this;
switch (_that) {
case _DayNightState():
return $default(_that.pair,_that.loaded,_that.isPro,_that.userId,_that.preparing,_that.issue,_that.proLapsed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DayNightPair pair,  bool loaded,  bool isPro,  String userId,  bool preparing,  DayNightIssue? issue,  bool proLapsed)?  $default,) {final _that = this;
switch (_that) {
case _DayNightState() when $default != null:
return $default(_that.pair,_that.loaded,_that.isPro,_that.userId,_that.preparing,_that.issue,_that.proLapsed);case _:
  return null;

}
}

}

/// @nodoc


class _DayNightState implements DayNightState {
  const _DayNightState({required this.pair, this.loaded = false, this.isPro = false, this.userId = '', this.preparing = false, this.issue, this.proLapsed = false});
  

@override final  DayNightPair pair;
@override@JsonKey() final  bool loaded;
@override@JsonKey() final  bool isPro;
@override@JsonKey() final  String userId;
@override@JsonKey() final  bool preparing;
@override final  DayNightIssue? issue;
@override@JsonKey() final  bool proLapsed;

/// Create a copy of DayNightState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DayNightStateCopyWith<_DayNightState> get copyWith => __$DayNightStateCopyWithImpl<_DayNightState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DayNightState&&(identical(other.pair, pair) || other.pair == pair)&&(identical(other.loaded, loaded) || other.loaded == loaded)&&(identical(other.isPro, isPro) || other.isPro == isPro)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.preparing, preparing) || other.preparing == preparing)&&(identical(other.issue, issue) || other.issue == issue)&&(identical(other.proLapsed, proLapsed) || other.proLapsed == proLapsed));
}


@override
int get hashCode => Object.hash(runtimeType,pair,loaded,isPro,userId,preparing,issue,proLapsed);

@override
String toString() {
  return 'DayNightState(pair: $pair, loaded: $loaded, isPro: $isPro, userId: $userId, preparing: $preparing, issue: $issue, proLapsed: $proLapsed)';
}


}

/// @nodoc
abstract mixin class _$DayNightStateCopyWith<$Res> implements $DayNightStateCopyWith<$Res> {
  factory _$DayNightStateCopyWith(_DayNightState value, $Res Function(_DayNightState) _then) = __$DayNightStateCopyWithImpl;
@override @useResult
$Res call({
 DayNightPair pair, bool loaded, bool isPro, String userId, bool preparing, DayNightIssue? issue, bool proLapsed
});




}
/// @nodoc
class __$DayNightStateCopyWithImpl<$Res>
    implements _$DayNightStateCopyWith<$Res> {
  __$DayNightStateCopyWithImpl(this._self, this._then);

  final _DayNightState _self;
  final $Res Function(_DayNightState) _then;

/// Create a copy of DayNightState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pair = null,Object? loaded = null,Object? isPro = null,Object? userId = null,Object? preparing = null,Object? issue = freezed,Object? proLapsed = null,}) {
  return _then(_DayNightState(
pair: null == pair ? _self.pair : pair // ignore: cast_nullable_to_non_nullable
as DayNightPair,loaded: null == loaded ? _self.loaded : loaded // ignore: cast_nullable_to_non_nullable
as bool,isPro: null == isPro ? _self.isPro : isPro // ignore: cast_nullable_to_non_nullable
as bool,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,preparing: null == preparing ? _self.preparing : preparing // ignore: cast_nullable_to_non_nullable
as bool,issue: freezed == issue ? _self.issue : issue // ignore: cast_nullable_to_non_nullable
as DayNightIssue?,proLapsed: null == proLapsed ? _self.proLapsed : proLapsed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
