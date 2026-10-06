// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auto_rotate_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AutoRotateEvent implements DiagnosticableTreeMixin {




@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'AutoRotateEvent'))
    ;
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutoRotateEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'AutoRotateEvent()';
}


}

/// @nodoc
class $AutoRotateEventCopyWith<$Res>  {
$AutoRotateEventCopyWith(AutoRotateEvent _, $Res Function(AutoRotateEvent) __);
}


/// Adds pattern-matching-related methods to [AutoRotateEvent].
extension AutoRotateEventPatterns on AutoRotateEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _EntitlementChanged value)?  entitlementChanged,TResult Function( _FavouritesChanged value)?  favouritesChanged,TResult Function( _Toggled value)?  toggled,TResult Function( _IntervalChanged value)?  intervalChanged,TResult Function( _TargetChanged value)?  targetChanged,TResult Function( _ShuffleChanged value)?  shuffleChanged,TResult Function( _SourceChanged value)?  sourceChanged,TResult Function( _ChargingOnlyChanged value)?  chargingOnlyChanged,TResult Function( _RotateNowPressed value)?  rotateNowPressed,TResult Function( _FavouritesSettled value)?  favouritesSettled,TResult Function( _StatusRefreshed value)?  statusRefreshed,TResult Function( _BatteryTipDismissed value)?  batteryTipDismissed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _EntitlementChanged() when entitlementChanged != null:
return entitlementChanged(_that);case _FavouritesChanged() when favouritesChanged != null:
return favouritesChanged(_that);case _Toggled() when toggled != null:
return toggled(_that);case _IntervalChanged() when intervalChanged != null:
return intervalChanged(_that);case _TargetChanged() when targetChanged != null:
return targetChanged(_that);case _ShuffleChanged() when shuffleChanged != null:
return shuffleChanged(_that);case _SourceChanged() when sourceChanged != null:
return sourceChanged(_that);case _ChargingOnlyChanged() when chargingOnlyChanged != null:
return chargingOnlyChanged(_that);case _RotateNowPressed() when rotateNowPressed != null:
return rotateNowPressed(_that);case _FavouritesSettled() when favouritesSettled != null:
return favouritesSettled(_that);case _StatusRefreshed() when statusRefreshed != null:
return statusRefreshed(_that);case _BatteryTipDismissed() when batteryTipDismissed != null:
return batteryTipDismissed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _EntitlementChanged value)  entitlementChanged,required TResult Function( _FavouritesChanged value)  favouritesChanged,required TResult Function( _Toggled value)  toggled,required TResult Function( _IntervalChanged value)  intervalChanged,required TResult Function( _TargetChanged value)  targetChanged,required TResult Function( _ShuffleChanged value)  shuffleChanged,required TResult Function( _SourceChanged value)  sourceChanged,required TResult Function( _ChargingOnlyChanged value)  chargingOnlyChanged,required TResult Function( _RotateNowPressed value)  rotateNowPressed,required TResult Function( _FavouritesSettled value)  favouritesSettled,required TResult Function( _StatusRefreshed value)  statusRefreshed,required TResult Function( _BatteryTipDismissed value)  batteryTipDismissed,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _EntitlementChanged():
return entitlementChanged(_that);case _FavouritesChanged():
return favouritesChanged(_that);case _Toggled():
return toggled(_that);case _IntervalChanged():
return intervalChanged(_that);case _TargetChanged():
return targetChanged(_that);case _ShuffleChanged():
return shuffleChanged(_that);case _SourceChanged():
return sourceChanged(_that);case _ChargingOnlyChanged():
return chargingOnlyChanged(_that);case _RotateNowPressed():
return rotateNowPressed(_that);case _FavouritesSettled():
return favouritesSettled(_that);case _StatusRefreshed():
return statusRefreshed(_that);case _BatteryTipDismissed():
return batteryTipDismissed(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _EntitlementChanged value)?  entitlementChanged,TResult? Function( _FavouritesChanged value)?  favouritesChanged,TResult? Function( _Toggled value)?  toggled,TResult? Function( _IntervalChanged value)?  intervalChanged,TResult? Function( _TargetChanged value)?  targetChanged,TResult? Function( _ShuffleChanged value)?  shuffleChanged,TResult? Function( _SourceChanged value)?  sourceChanged,TResult? Function( _ChargingOnlyChanged value)?  chargingOnlyChanged,TResult? Function( _RotateNowPressed value)?  rotateNowPressed,TResult? Function( _FavouritesSettled value)?  favouritesSettled,TResult? Function( _StatusRefreshed value)?  statusRefreshed,TResult? Function( _BatteryTipDismissed value)?  batteryTipDismissed,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _EntitlementChanged() when entitlementChanged != null:
return entitlementChanged(_that);case _FavouritesChanged() when favouritesChanged != null:
return favouritesChanged(_that);case _Toggled() when toggled != null:
return toggled(_that);case _IntervalChanged() when intervalChanged != null:
return intervalChanged(_that);case _TargetChanged() when targetChanged != null:
return targetChanged(_that);case _ShuffleChanged() when shuffleChanged != null:
return shuffleChanged(_that);case _SourceChanged() when sourceChanged != null:
return sourceChanged(_that);case _ChargingOnlyChanged() when chargingOnlyChanged != null:
return chargingOnlyChanged(_that);case _RotateNowPressed() when rotateNowPressed != null:
return rotateNowPressed(_that);case _FavouritesSettled() when favouritesSettled != null:
return favouritesSettled(_that);case _StatusRefreshed() when statusRefreshed != null:
return statusRefreshed(_that);case _BatteryTipDismissed() when batteryTipDismissed != null:
return batteryTipDismissed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( List<String> favouriteUrls,  bool isPro)?  started,TResult Function( bool isPro,  String userId)?  entitlementChanged,TResult Function( List<String> favouriteUrls)?  favouritesChanged,TResult Function( bool enabled)?  toggled,TResult Function( int minutes)?  intervalChanged,TResult Function( WallpaperTarget target)?  targetChanged,TResult Function( bool shuffle)?  shuffleChanged,TResult Function( AutoRotateSource source)?  sourceChanged,TResult Function( bool chargingOnly)?  chargingOnlyChanged,TResult Function()?  rotateNowPressed,TResult Function()?  favouritesSettled,TResult Function()?  statusRefreshed,TResult Function()?  batteryTipDismissed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.favouriteUrls,_that.isPro);case _EntitlementChanged() when entitlementChanged != null:
return entitlementChanged(_that.isPro,_that.userId);case _FavouritesChanged() when favouritesChanged != null:
return favouritesChanged(_that.favouriteUrls);case _Toggled() when toggled != null:
return toggled(_that.enabled);case _IntervalChanged() when intervalChanged != null:
return intervalChanged(_that.minutes);case _TargetChanged() when targetChanged != null:
return targetChanged(_that.target);case _ShuffleChanged() when shuffleChanged != null:
return shuffleChanged(_that.shuffle);case _SourceChanged() when sourceChanged != null:
return sourceChanged(_that.source);case _ChargingOnlyChanged() when chargingOnlyChanged != null:
return chargingOnlyChanged(_that.chargingOnly);case _RotateNowPressed() when rotateNowPressed != null:
return rotateNowPressed();case _FavouritesSettled() when favouritesSettled != null:
return favouritesSettled();case _StatusRefreshed() when statusRefreshed != null:
return statusRefreshed();case _BatteryTipDismissed() when batteryTipDismissed != null:
return batteryTipDismissed();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( List<String> favouriteUrls,  bool isPro)  started,required TResult Function( bool isPro,  String userId)  entitlementChanged,required TResult Function( List<String> favouriteUrls)  favouritesChanged,required TResult Function( bool enabled)  toggled,required TResult Function( int minutes)  intervalChanged,required TResult Function( WallpaperTarget target)  targetChanged,required TResult Function( bool shuffle)  shuffleChanged,required TResult Function( AutoRotateSource source)  sourceChanged,required TResult Function( bool chargingOnly)  chargingOnlyChanged,required TResult Function()  rotateNowPressed,required TResult Function()  favouritesSettled,required TResult Function()  statusRefreshed,required TResult Function()  batteryTipDismissed,}) {final _that = this;
switch (_that) {
case _Started():
return started(_that.favouriteUrls,_that.isPro);case _EntitlementChanged():
return entitlementChanged(_that.isPro,_that.userId);case _FavouritesChanged():
return favouritesChanged(_that.favouriteUrls);case _Toggled():
return toggled(_that.enabled);case _IntervalChanged():
return intervalChanged(_that.minutes);case _TargetChanged():
return targetChanged(_that.target);case _ShuffleChanged():
return shuffleChanged(_that.shuffle);case _SourceChanged():
return sourceChanged(_that.source);case _ChargingOnlyChanged():
return chargingOnlyChanged(_that.chargingOnly);case _RotateNowPressed():
return rotateNowPressed();case _FavouritesSettled():
return favouritesSettled();case _StatusRefreshed():
return statusRefreshed();case _BatteryTipDismissed():
return batteryTipDismissed();case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( List<String> favouriteUrls,  bool isPro)?  started,TResult? Function( bool isPro,  String userId)?  entitlementChanged,TResult? Function( List<String> favouriteUrls)?  favouritesChanged,TResult? Function( bool enabled)?  toggled,TResult? Function( int minutes)?  intervalChanged,TResult? Function( WallpaperTarget target)?  targetChanged,TResult? Function( bool shuffle)?  shuffleChanged,TResult? Function( AutoRotateSource source)?  sourceChanged,TResult? Function( bool chargingOnly)?  chargingOnlyChanged,TResult? Function()?  rotateNowPressed,TResult? Function()?  favouritesSettled,TResult? Function()?  statusRefreshed,TResult? Function()?  batteryTipDismissed,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.favouriteUrls,_that.isPro);case _EntitlementChanged() when entitlementChanged != null:
return entitlementChanged(_that.isPro,_that.userId);case _FavouritesChanged() when favouritesChanged != null:
return favouritesChanged(_that.favouriteUrls);case _Toggled() when toggled != null:
return toggled(_that.enabled);case _IntervalChanged() when intervalChanged != null:
return intervalChanged(_that.minutes);case _TargetChanged() when targetChanged != null:
return targetChanged(_that.target);case _ShuffleChanged() when shuffleChanged != null:
return shuffleChanged(_that.shuffle);case _SourceChanged() when sourceChanged != null:
return sourceChanged(_that.source);case _ChargingOnlyChanged() when chargingOnlyChanged != null:
return chargingOnlyChanged(_that.chargingOnly);case _RotateNowPressed() when rotateNowPressed != null:
return rotateNowPressed();case _FavouritesSettled() when favouritesSettled != null:
return favouritesSettled();case _StatusRefreshed() when statusRefreshed != null:
return statusRefreshed();case _BatteryTipDismissed() when batteryTipDismissed != null:
return batteryTipDismissed();case _:
  return null;

}
}

}

/// @nodoc


class _Started with DiagnosticableTreeMixin implements AutoRotateEvent {
  const _Started({required final  List<String> favouriteUrls, required this.isPro}): _favouriteUrls = favouriteUrls;
  

 final  List<String> _favouriteUrls;
 List<String> get favouriteUrls {
  if (_favouriteUrls is EqualUnmodifiableListView) return _favouriteUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_favouriteUrls);
}

 final  bool isPro;

/// Create a copy of AutoRotateEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StartedCopyWith<_Started> get copyWith => __$StartedCopyWithImpl<_Started>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'AutoRotateEvent.started'))
    ..add(DiagnosticsProperty('favouriteUrls', favouriteUrls))..add(DiagnosticsProperty('isPro', isPro));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started&&const DeepCollectionEquality().equals(other._favouriteUrls, _favouriteUrls)&&(identical(other.isPro, isPro) || other.isPro == isPro));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_favouriteUrls),isPro);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'AutoRotateEvent.started(favouriteUrls: $favouriteUrls, isPro: $isPro)';
}


}

/// @nodoc
abstract mixin class _$StartedCopyWith<$Res> implements $AutoRotateEventCopyWith<$Res> {
  factory _$StartedCopyWith(_Started value, $Res Function(_Started) _then) = __$StartedCopyWithImpl;
@useResult
$Res call({
 List<String> favouriteUrls, bool isPro
});




}
/// @nodoc
class __$StartedCopyWithImpl<$Res>
    implements _$StartedCopyWith<$Res> {
  __$StartedCopyWithImpl(this._self, this._then);

  final _Started _self;
  final $Res Function(_Started) _then;

/// Create a copy of AutoRotateEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? favouriteUrls = null,Object? isPro = null,}) {
  return _then(_Started(
favouriteUrls: null == favouriteUrls ? _self._favouriteUrls : favouriteUrls // ignore: cast_nullable_to_non_nullable
as List<String>,isPro: null == isPro ? _self.isPro : isPro // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class _EntitlementChanged with DiagnosticableTreeMixin implements AutoRotateEvent {
  const _EntitlementChanged({required this.isPro, required this.userId});
  

 final  bool isPro;
 final  String userId;

/// Create a copy of AutoRotateEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EntitlementChangedCopyWith<_EntitlementChanged> get copyWith => __$EntitlementChangedCopyWithImpl<_EntitlementChanged>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'AutoRotateEvent.entitlementChanged'))
    ..add(DiagnosticsProperty('isPro', isPro))..add(DiagnosticsProperty('userId', userId));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EntitlementChanged&&(identical(other.isPro, isPro) || other.isPro == isPro)&&(identical(other.userId, userId) || other.userId == userId));
}


@override
int get hashCode => Object.hash(runtimeType,isPro,userId);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'AutoRotateEvent.entitlementChanged(isPro: $isPro, userId: $userId)';
}


}

/// @nodoc
abstract mixin class _$EntitlementChangedCopyWith<$Res> implements $AutoRotateEventCopyWith<$Res> {
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

/// Create a copy of AutoRotateEvent
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


class _FavouritesChanged with DiagnosticableTreeMixin implements AutoRotateEvent {
  const _FavouritesChanged(final  List<String> favouriteUrls): _favouriteUrls = favouriteUrls;
  

 final  List<String> _favouriteUrls;
 List<String> get favouriteUrls {
  if (_favouriteUrls is EqualUnmodifiableListView) return _favouriteUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_favouriteUrls);
}


/// Create a copy of AutoRotateEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FavouritesChangedCopyWith<_FavouritesChanged> get copyWith => __$FavouritesChangedCopyWithImpl<_FavouritesChanged>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'AutoRotateEvent.favouritesChanged'))
    ..add(DiagnosticsProperty('favouriteUrls', favouriteUrls));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FavouritesChanged&&const DeepCollectionEquality().equals(other._favouriteUrls, _favouriteUrls));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_favouriteUrls));

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'AutoRotateEvent.favouritesChanged(favouriteUrls: $favouriteUrls)';
}


}

/// @nodoc
abstract mixin class _$FavouritesChangedCopyWith<$Res> implements $AutoRotateEventCopyWith<$Res> {
  factory _$FavouritesChangedCopyWith(_FavouritesChanged value, $Res Function(_FavouritesChanged) _then) = __$FavouritesChangedCopyWithImpl;
@useResult
$Res call({
 List<String> favouriteUrls
});




}
/// @nodoc
class __$FavouritesChangedCopyWithImpl<$Res>
    implements _$FavouritesChangedCopyWith<$Res> {
  __$FavouritesChangedCopyWithImpl(this._self, this._then);

  final _FavouritesChanged _self;
  final $Res Function(_FavouritesChanged) _then;

/// Create a copy of AutoRotateEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? favouriteUrls = null,}) {
  return _then(_FavouritesChanged(
null == favouriteUrls ? _self._favouriteUrls : favouriteUrls // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc


class _Toggled with DiagnosticableTreeMixin implements AutoRotateEvent {
  const _Toggled(this.enabled);
  

 final  bool enabled;

/// Create a copy of AutoRotateEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ToggledCopyWith<_Toggled> get copyWith => __$ToggledCopyWithImpl<_Toggled>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'AutoRotateEvent.toggled'))
    ..add(DiagnosticsProperty('enabled', enabled));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Toggled&&(identical(other.enabled, enabled) || other.enabled == enabled));
}


@override
int get hashCode => Object.hash(runtimeType,enabled);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'AutoRotateEvent.toggled(enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class _$ToggledCopyWith<$Res> implements $AutoRotateEventCopyWith<$Res> {
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

/// Create a copy of AutoRotateEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? enabled = null,}) {
  return _then(_Toggled(
null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class _IntervalChanged with DiagnosticableTreeMixin implements AutoRotateEvent {
  const _IntervalChanged(this.minutes);
  

 final  int minutes;

/// Create a copy of AutoRotateEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$IntervalChangedCopyWith<_IntervalChanged> get copyWith => __$IntervalChangedCopyWithImpl<_IntervalChanged>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'AutoRotateEvent.intervalChanged'))
    ..add(DiagnosticsProperty('minutes', minutes));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _IntervalChanged&&(identical(other.minutes, minutes) || other.minutes == minutes));
}


@override
int get hashCode => Object.hash(runtimeType,minutes);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'AutoRotateEvent.intervalChanged(minutes: $minutes)';
}


}

/// @nodoc
abstract mixin class _$IntervalChangedCopyWith<$Res> implements $AutoRotateEventCopyWith<$Res> {
  factory _$IntervalChangedCopyWith(_IntervalChanged value, $Res Function(_IntervalChanged) _then) = __$IntervalChangedCopyWithImpl;
@useResult
$Res call({
 int minutes
});




}
/// @nodoc
class __$IntervalChangedCopyWithImpl<$Res>
    implements _$IntervalChangedCopyWith<$Res> {
  __$IntervalChangedCopyWithImpl(this._self, this._then);

  final _IntervalChanged _self;
  final $Res Function(_IntervalChanged) _then;

/// Create a copy of AutoRotateEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? minutes = null,}) {
  return _then(_IntervalChanged(
null == minutes ? _self.minutes : minutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _TargetChanged with DiagnosticableTreeMixin implements AutoRotateEvent {
  const _TargetChanged(this.target);
  

 final  WallpaperTarget target;

/// Create a copy of AutoRotateEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TargetChangedCopyWith<_TargetChanged> get copyWith => __$TargetChangedCopyWithImpl<_TargetChanged>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'AutoRotateEvent.targetChanged'))
    ..add(DiagnosticsProperty('target', target));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TargetChanged&&(identical(other.target, target) || other.target == target));
}


@override
int get hashCode => Object.hash(runtimeType,target);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'AutoRotateEvent.targetChanged(target: $target)';
}


}

/// @nodoc
abstract mixin class _$TargetChangedCopyWith<$Res> implements $AutoRotateEventCopyWith<$Res> {
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

/// Create a copy of AutoRotateEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? target = null,}) {
  return _then(_TargetChanged(
null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as WallpaperTarget,
  ));
}


}

/// @nodoc


class _ShuffleChanged with DiagnosticableTreeMixin implements AutoRotateEvent {
  const _ShuffleChanged(this.shuffle);
  

 final  bool shuffle;

/// Create a copy of AutoRotateEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShuffleChangedCopyWith<_ShuffleChanged> get copyWith => __$ShuffleChangedCopyWithImpl<_ShuffleChanged>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'AutoRotateEvent.shuffleChanged'))
    ..add(DiagnosticsProperty('shuffle', shuffle));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShuffleChanged&&(identical(other.shuffle, shuffle) || other.shuffle == shuffle));
}


@override
int get hashCode => Object.hash(runtimeType,shuffle);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'AutoRotateEvent.shuffleChanged(shuffle: $shuffle)';
}


}

/// @nodoc
abstract mixin class _$ShuffleChangedCopyWith<$Res> implements $AutoRotateEventCopyWith<$Res> {
  factory _$ShuffleChangedCopyWith(_ShuffleChanged value, $Res Function(_ShuffleChanged) _then) = __$ShuffleChangedCopyWithImpl;
@useResult
$Res call({
 bool shuffle
});




}
/// @nodoc
class __$ShuffleChangedCopyWithImpl<$Res>
    implements _$ShuffleChangedCopyWith<$Res> {
  __$ShuffleChangedCopyWithImpl(this._self, this._then);

  final _ShuffleChanged _self;
  final $Res Function(_ShuffleChanged) _then;

/// Create a copy of AutoRotateEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? shuffle = null,}) {
  return _then(_ShuffleChanged(
null == shuffle ? _self.shuffle : shuffle // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class _SourceChanged with DiagnosticableTreeMixin implements AutoRotateEvent {
  const _SourceChanged(this.source);
  

 final  AutoRotateSource source;

/// Create a copy of AutoRotateEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SourceChangedCopyWith<_SourceChanged> get copyWith => __$SourceChangedCopyWithImpl<_SourceChanged>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'AutoRotateEvent.sourceChanged'))
    ..add(DiagnosticsProperty('source', source));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SourceChanged&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode => Object.hash(runtimeType,source);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'AutoRotateEvent.sourceChanged(source: $source)';
}


}

/// @nodoc
abstract mixin class _$SourceChangedCopyWith<$Res> implements $AutoRotateEventCopyWith<$Res> {
  factory _$SourceChangedCopyWith(_SourceChanged value, $Res Function(_SourceChanged) _then) = __$SourceChangedCopyWithImpl;
@useResult
$Res call({
 AutoRotateSource source
});




}
/// @nodoc
class __$SourceChangedCopyWithImpl<$Res>
    implements _$SourceChangedCopyWith<$Res> {
  __$SourceChangedCopyWithImpl(this._self, this._then);

  final _SourceChanged _self;
  final $Res Function(_SourceChanged) _then;

/// Create a copy of AutoRotateEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,}) {
  return _then(_SourceChanged(
null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as AutoRotateSource,
  ));
}


}

/// @nodoc


class _ChargingOnlyChanged with DiagnosticableTreeMixin implements AutoRotateEvent {
  const _ChargingOnlyChanged(this.chargingOnly);
  

 final  bool chargingOnly;

/// Create a copy of AutoRotateEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChargingOnlyChangedCopyWith<_ChargingOnlyChanged> get copyWith => __$ChargingOnlyChangedCopyWithImpl<_ChargingOnlyChanged>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'AutoRotateEvent.chargingOnlyChanged'))
    ..add(DiagnosticsProperty('chargingOnly', chargingOnly));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChargingOnlyChanged&&(identical(other.chargingOnly, chargingOnly) || other.chargingOnly == chargingOnly));
}


@override
int get hashCode => Object.hash(runtimeType,chargingOnly);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'AutoRotateEvent.chargingOnlyChanged(chargingOnly: $chargingOnly)';
}


}

/// @nodoc
abstract mixin class _$ChargingOnlyChangedCopyWith<$Res> implements $AutoRotateEventCopyWith<$Res> {
  factory _$ChargingOnlyChangedCopyWith(_ChargingOnlyChanged value, $Res Function(_ChargingOnlyChanged) _then) = __$ChargingOnlyChangedCopyWithImpl;
@useResult
$Res call({
 bool chargingOnly
});




}
/// @nodoc
class __$ChargingOnlyChangedCopyWithImpl<$Res>
    implements _$ChargingOnlyChangedCopyWith<$Res> {
  __$ChargingOnlyChangedCopyWithImpl(this._self, this._then);

  final _ChargingOnlyChanged _self;
  final $Res Function(_ChargingOnlyChanged) _then;

/// Create a copy of AutoRotateEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? chargingOnly = null,}) {
  return _then(_ChargingOnlyChanged(
null == chargingOnly ? _self.chargingOnly : chargingOnly // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class _RotateNowPressed with DiagnosticableTreeMixin implements AutoRotateEvent {
  const _RotateNowPressed();
  





@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'AutoRotateEvent.rotateNowPressed'))
    ;
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RotateNowPressed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'AutoRotateEvent.rotateNowPressed()';
}


}




/// @nodoc


class _FavouritesSettled with DiagnosticableTreeMixin implements AutoRotateEvent {
  const _FavouritesSettled();
  





@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'AutoRotateEvent.favouritesSettled'))
    ;
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FavouritesSettled);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'AutoRotateEvent.favouritesSettled()';
}


}




/// @nodoc


class _StatusRefreshed with DiagnosticableTreeMixin implements AutoRotateEvent {
  const _StatusRefreshed();
  





@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'AutoRotateEvent.statusRefreshed'))
    ;
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StatusRefreshed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'AutoRotateEvent.statusRefreshed()';
}


}




/// @nodoc


class _BatteryTipDismissed with DiagnosticableTreeMixin implements AutoRotateEvent {
  const _BatteryTipDismissed();
  





@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'AutoRotateEvent.batteryTipDismissed'))
    ;
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BatteryTipDismissed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'AutoRotateEvent.batteryTipDismissed()';
}


}




/// @nodoc
mixin _$AutoRotateState implements DiagnosticableTreeMixin {

 bool get loaded; AutoRotateConfig get config; AutoRotateStatus get status; int get favouriteCount; int get downloadCount; bool get sourcesCapped; bool get isPro; bool get startFailed; bool get starting; bool get showBatteryTip;
/// Create a copy of AutoRotateState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AutoRotateStateCopyWith<AutoRotateState> get copyWith => _$AutoRotateStateCopyWithImpl<AutoRotateState>(this as AutoRotateState, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'AutoRotateState'))
    ..add(DiagnosticsProperty('loaded', loaded))..add(DiagnosticsProperty('config', config))..add(DiagnosticsProperty('status', status))..add(DiagnosticsProperty('favouriteCount', favouriteCount))..add(DiagnosticsProperty('downloadCount', downloadCount))..add(DiagnosticsProperty('sourcesCapped', sourcesCapped))..add(DiagnosticsProperty('isPro', isPro))..add(DiagnosticsProperty('startFailed', startFailed))..add(DiagnosticsProperty('starting', starting))..add(DiagnosticsProperty('showBatteryTip', showBatteryTip));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutoRotateState&&(identical(other.loaded, loaded) || other.loaded == loaded)&&(identical(other.config, config) || other.config == config)&&(identical(other.status, status) || other.status == status)&&(identical(other.favouriteCount, favouriteCount) || other.favouriteCount == favouriteCount)&&(identical(other.downloadCount, downloadCount) || other.downloadCount == downloadCount)&&(identical(other.sourcesCapped, sourcesCapped) || other.sourcesCapped == sourcesCapped)&&(identical(other.isPro, isPro) || other.isPro == isPro)&&(identical(other.startFailed, startFailed) || other.startFailed == startFailed)&&(identical(other.starting, starting) || other.starting == starting)&&(identical(other.showBatteryTip, showBatteryTip) || other.showBatteryTip == showBatteryTip));
}


@override
int get hashCode => Object.hash(runtimeType,loaded,config,status,favouriteCount,downloadCount,sourcesCapped,isPro,startFailed,starting,showBatteryTip);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'AutoRotateState(loaded: $loaded, config: $config, status: $status, favouriteCount: $favouriteCount, downloadCount: $downloadCount, sourcesCapped: $sourcesCapped, isPro: $isPro, startFailed: $startFailed, starting: $starting, showBatteryTip: $showBatteryTip)';
}


}

/// @nodoc
abstract mixin class $AutoRotateStateCopyWith<$Res>  {
  factory $AutoRotateStateCopyWith(AutoRotateState value, $Res Function(AutoRotateState) _then) = _$AutoRotateStateCopyWithImpl;
@useResult
$Res call({
 bool loaded, AutoRotateConfig config, AutoRotateStatus status, int favouriteCount, int downloadCount, bool sourcesCapped, bool isPro, bool startFailed, bool starting, bool showBatteryTip
});




}
/// @nodoc
class _$AutoRotateStateCopyWithImpl<$Res>
    implements $AutoRotateStateCopyWith<$Res> {
  _$AutoRotateStateCopyWithImpl(this._self, this._then);

  final AutoRotateState _self;
  final $Res Function(AutoRotateState) _then;

/// Create a copy of AutoRotateState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? loaded = null,Object? config = null,Object? status = null,Object? favouriteCount = null,Object? downloadCount = null,Object? sourcesCapped = null,Object? isPro = null,Object? startFailed = null,Object? starting = null,Object? showBatteryTip = null,}) {
  return _then(_self.copyWith(
loaded: null == loaded ? _self.loaded : loaded // ignore: cast_nullable_to_non_nullable
as bool,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as AutoRotateConfig,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AutoRotateStatus,favouriteCount: null == favouriteCount ? _self.favouriteCount : favouriteCount // ignore: cast_nullable_to_non_nullable
as int,downloadCount: null == downloadCount ? _self.downloadCount : downloadCount // ignore: cast_nullable_to_non_nullable
as int,sourcesCapped: null == sourcesCapped ? _self.sourcesCapped : sourcesCapped // ignore: cast_nullable_to_non_nullable
as bool,isPro: null == isPro ? _self.isPro : isPro // ignore: cast_nullable_to_non_nullable
as bool,startFailed: null == startFailed ? _self.startFailed : startFailed // ignore: cast_nullable_to_non_nullable
as bool,starting: null == starting ? _self.starting : starting // ignore: cast_nullable_to_non_nullable
as bool,showBatteryTip: null == showBatteryTip ? _self.showBatteryTip : showBatteryTip // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AutoRotateState].
extension AutoRotateStatePatterns on AutoRotateState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AutoRotateState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AutoRotateState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AutoRotateState value)  $default,){
final _that = this;
switch (_that) {
case _AutoRotateState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AutoRotateState value)?  $default,){
final _that = this;
switch (_that) {
case _AutoRotateState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool loaded,  AutoRotateConfig config,  AutoRotateStatus status,  int favouriteCount,  int downloadCount,  bool sourcesCapped,  bool isPro,  bool startFailed,  bool starting,  bool showBatteryTip)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AutoRotateState() when $default != null:
return $default(_that.loaded,_that.config,_that.status,_that.favouriteCount,_that.downloadCount,_that.sourcesCapped,_that.isPro,_that.startFailed,_that.starting,_that.showBatteryTip);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool loaded,  AutoRotateConfig config,  AutoRotateStatus status,  int favouriteCount,  int downloadCount,  bool sourcesCapped,  bool isPro,  bool startFailed,  bool starting,  bool showBatteryTip)  $default,) {final _that = this;
switch (_that) {
case _AutoRotateState():
return $default(_that.loaded,_that.config,_that.status,_that.favouriteCount,_that.downloadCount,_that.sourcesCapped,_that.isPro,_that.startFailed,_that.starting,_that.showBatteryTip);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool loaded,  AutoRotateConfig config,  AutoRotateStatus status,  int favouriteCount,  int downloadCount,  bool sourcesCapped,  bool isPro,  bool startFailed,  bool starting,  bool showBatteryTip)?  $default,) {final _that = this;
switch (_that) {
case _AutoRotateState() when $default != null:
return $default(_that.loaded,_that.config,_that.status,_that.favouriteCount,_that.downloadCount,_that.sourcesCapped,_that.isPro,_that.startFailed,_that.starting,_that.showBatteryTip);case _:
  return null;

}
}

}

/// @nodoc


class _AutoRotateState extends AutoRotateState with DiagnosticableTreeMixin {
  const _AutoRotateState({required this.loaded, required this.config, required this.status, required this.favouriteCount, required this.downloadCount, required this.sourcesCapped, required this.isPro, required this.startFailed, required this.starting, required this.showBatteryTip}): super._();
  

@override final  bool loaded;
@override final  AutoRotateConfig config;
@override final  AutoRotateStatus status;
@override final  int favouriteCount;
@override final  int downloadCount;
@override final  bool sourcesCapped;
@override final  bool isPro;
@override final  bool startFailed;
@override final  bool starting;
@override final  bool showBatteryTip;

/// Create a copy of AutoRotateState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AutoRotateStateCopyWith<_AutoRotateState> get copyWith => __$AutoRotateStateCopyWithImpl<_AutoRotateState>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'AutoRotateState'))
    ..add(DiagnosticsProperty('loaded', loaded))..add(DiagnosticsProperty('config', config))..add(DiagnosticsProperty('status', status))..add(DiagnosticsProperty('favouriteCount', favouriteCount))..add(DiagnosticsProperty('downloadCount', downloadCount))..add(DiagnosticsProperty('sourcesCapped', sourcesCapped))..add(DiagnosticsProperty('isPro', isPro))..add(DiagnosticsProperty('startFailed', startFailed))..add(DiagnosticsProperty('starting', starting))..add(DiagnosticsProperty('showBatteryTip', showBatteryTip));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AutoRotateState&&(identical(other.loaded, loaded) || other.loaded == loaded)&&(identical(other.config, config) || other.config == config)&&(identical(other.status, status) || other.status == status)&&(identical(other.favouriteCount, favouriteCount) || other.favouriteCount == favouriteCount)&&(identical(other.downloadCount, downloadCount) || other.downloadCount == downloadCount)&&(identical(other.sourcesCapped, sourcesCapped) || other.sourcesCapped == sourcesCapped)&&(identical(other.isPro, isPro) || other.isPro == isPro)&&(identical(other.startFailed, startFailed) || other.startFailed == startFailed)&&(identical(other.starting, starting) || other.starting == starting)&&(identical(other.showBatteryTip, showBatteryTip) || other.showBatteryTip == showBatteryTip));
}


@override
int get hashCode => Object.hash(runtimeType,loaded,config,status,favouriteCount,downloadCount,sourcesCapped,isPro,startFailed,starting,showBatteryTip);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'AutoRotateState(loaded: $loaded, config: $config, status: $status, favouriteCount: $favouriteCount, downloadCount: $downloadCount, sourcesCapped: $sourcesCapped, isPro: $isPro, startFailed: $startFailed, starting: $starting, showBatteryTip: $showBatteryTip)';
}


}

/// @nodoc
abstract mixin class _$AutoRotateStateCopyWith<$Res> implements $AutoRotateStateCopyWith<$Res> {
  factory _$AutoRotateStateCopyWith(_AutoRotateState value, $Res Function(_AutoRotateState) _then) = __$AutoRotateStateCopyWithImpl;
@override @useResult
$Res call({
 bool loaded, AutoRotateConfig config, AutoRotateStatus status, int favouriteCount, int downloadCount, bool sourcesCapped, bool isPro, bool startFailed, bool starting, bool showBatteryTip
});




}
/// @nodoc
class __$AutoRotateStateCopyWithImpl<$Res>
    implements _$AutoRotateStateCopyWith<$Res> {
  __$AutoRotateStateCopyWithImpl(this._self, this._then);

  final _AutoRotateState _self;
  final $Res Function(_AutoRotateState) _then;

/// Create a copy of AutoRotateState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? loaded = null,Object? config = null,Object? status = null,Object? favouriteCount = null,Object? downloadCount = null,Object? sourcesCapped = null,Object? isPro = null,Object? startFailed = null,Object? starting = null,Object? showBatteryTip = null,}) {
  return _then(_AutoRotateState(
loaded: null == loaded ? _self.loaded : loaded // ignore: cast_nullable_to_non_nullable
as bool,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as AutoRotateConfig,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AutoRotateStatus,favouriteCount: null == favouriteCount ? _self.favouriteCount : favouriteCount // ignore: cast_nullable_to_non_nullable
as int,downloadCount: null == downloadCount ? _self.downloadCount : downloadCount // ignore: cast_nullable_to_non_nullable
as int,sourcesCapped: null == sourcesCapped ? _self.sourcesCapped : sourcesCapped // ignore: cast_nullable_to_non_nullable
as bool,isPro: null == isPro ? _self.isPro : isPro // ignore: cast_nullable_to_non_nullable
as bool,startFailed: null == startFailed ? _self.startFailed : startFailed // ignore: cast_nullable_to_non_nullable
as bool,starting: null == starting ? _self.starting : starting // ignore: cast_nullable_to_non_nullable
as bool,showBatteryTip: null == showBatteryTip ? _self.showBatteryTip : showBatteryTip // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
