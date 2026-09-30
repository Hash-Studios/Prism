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
mixin _$AutoRotateEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutoRotateEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _EntitlementChanged value)?  entitlementChanged,TResult Function( _FavouritesChanged value)?  favouritesChanged,TResult Function( _Toggled value)?  toggled,TResult Function( _IntervalChanged value)?  intervalChanged,TResult Function( _TargetChanged value)?  targetChanged,TResult Function( _ShuffleChanged value)?  shuffleChanged,TResult Function( _RotateNowPressed value)?  rotateNowPressed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _EntitlementChanged() when entitlementChanged != null:
return entitlementChanged(_that);case _FavouritesChanged() when favouritesChanged != null:
return favouritesChanged(_that);case _Toggled() when toggled != null:
return toggled(_that);case _IntervalChanged() when intervalChanged != null:
return intervalChanged(_that);case _TargetChanged() when targetChanged != null:
return targetChanged(_that);case _ShuffleChanged() when shuffleChanged != null:
return shuffleChanged(_that);case _RotateNowPressed() when rotateNowPressed != null:
return rotateNowPressed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _EntitlementChanged value)  entitlementChanged,required TResult Function( _FavouritesChanged value)  favouritesChanged,required TResult Function( _Toggled value)  toggled,required TResult Function( _IntervalChanged value)  intervalChanged,required TResult Function( _TargetChanged value)  targetChanged,required TResult Function( _ShuffleChanged value)  shuffleChanged,required TResult Function( _RotateNowPressed value)  rotateNowPressed,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _EntitlementChanged():
return entitlementChanged(_that);case _FavouritesChanged():
return favouritesChanged(_that);case _Toggled():
return toggled(_that);case _IntervalChanged():
return intervalChanged(_that);case _TargetChanged():
return targetChanged(_that);case _ShuffleChanged():
return shuffleChanged(_that);case _RotateNowPressed():
return rotateNowPressed(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _EntitlementChanged value)?  entitlementChanged,TResult? Function( _FavouritesChanged value)?  favouritesChanged,TResult? Function( _Toggled value)?  toggled,TResult? Function( _IntervalChanged value)?  intervalChanged,TResult? Function( _TargetChanged value)?  targetChanged,TResult? Function( _ShuffleChanged value)?  shuffleChanged,TResult? Function( _RotateNowPressed value)?  rotateNowPressed,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _EntitlementChanged() when entitlementChanged != null:
return entitlementChanged(_that);case _FavouritesChanged() when favouritesChanged != null:
return favouritesChanged(_that);case _Toggled() when toggled != null:
return toggled(_that);case _IntervalChanged() when intervalChanged != null:
return intervalChanged(_that);case _TargetChanged() when targetChanged != null:
return targetChanged(_that);case _ShuffleChanged() when shuffleChanged != null:
return shuffleChanged(_that);case _RotateNowPressed() when rotateNowPressed != null:
return rotateNowPressed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( List<String> favouriteUrls,  bool isPro)?  started,TResult Function( bool isPro,  String userId)?  entitlementChanged,TResult Function( List<String> favouriteUrls)?  favouritesChanged,TResult Function( bool enabled)?  toggled,TResult Function( int minutes)?  intervalChanged,TResult Function( WallpaperTarget target)?  targetChanged,TResult Function( bool shuffle)?  shuffleChanged,TResult Function()?  rotateNowPressed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.favouriteUrls,_that.isPro);case _EntitlementChanged() when entitlementChanged != null:
return entitlementChanged(_that.isPro,_that.userId);case _FavouritesChanged() when favouritesChanged != null:
return favouritesChanged(_that.favouriteUrls);case _Toggled() when toggled != null:
return toggled(_that.enabled);case _IntervalChanged() when intervalChanged != null:
return intervalChanged(_that.minutes);case _TargetChanged() when targetChanged != null:
return targetChanged(_that.target);case _ShuffleChanged() when shuffleChanged != null:
return shuffleChanged(_that.shuffle);case _RotateNowPressed() when rotateNowPressed != null:
return rotateNowPressed();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( List<String> favouriteUrls,  bool isPro)  started,required TResult Function( bool isPro,  String userId)  entitlementChanged,required TResult Function( List<String> favouriteUrls)  favouritesChanged,required TResult Function( bool enabled)  toggled,required TResult Function( int minutes)  intervalChanged,required TResult Function( WallpaperTarget target)  targetChanged,required TResult Function( bool shuffle)  shuffleChanged,required TResult Function()  rotateNowPressed,}) {final _that = this;
switch (_that) {
case _Started():
return started(_that.favouriteUrls,_that.isPro);case _EntitlementChanged():
return entitlementChanged(_that.isPro,_that.userId);case _FavouritesChanged():
return favouritesChanged(_that.favouriteUrls);case _Toggled():
return toggled(_that.enabled);case _IntervalChanged():
return intervalChanged(_that.minutes);case _TargetChanged():
return targetChanged(_that.target);case _ShuffleChanged():
return shuffleChanged(_that.shuffle);case _RotateNowPressed():
return rotateNowPressed();case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( List<String> favouriteUrls,  bool isPro)?  started,TResult? Function( bool isPro,  String userId)?  entitlementChanged,TResult? Function( List<String> favouriteUrls)?  favouritesChanged,TResult? Function( bool enabled)?  toggled,TResult? Function( int minutes)?  intervalChanged,TResult? Function( WallpaperTarget target)?  targetChanged,TResult? Function( bool shuffle)?  shuffleChanged,TResult? Function()?  rotateNowPressed,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.favouriteUrls,_that.isPro);case _EntitlementChanged() when entitlementChanged != null:
return entitlementChanged(_that.isPro,_that.userId);case _FavouritesChanged() when favouritesChanged != null:
return favouritesChanged(_that.favouriteUrls);case _Toggled() when toggled != null:
return toggled(_that.enabled);case _IntervalChanged() when intervalChanged != null:
return intervalChanged(_that.minutes);case _TargetChanged() when targetChanged != null:
return targetChanged(_that.target);case _ShuffleChanged() when shuffleChanged != null:
return shuffleChanged(_that.shuffle);case _RotateNowPressed() when rotateNowPressed != null:
return rotateNowPressed();case _:
  return null;

}
}

}

/// @nodoc


class _Started implements AutoRotateEvent {
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
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started&&const DeepCollectionEquality().equals(other._favouriteUrls, _favouriteUrls)&&(identical(other.isPro, isPro) || other.isPro == isPro));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_favouriteUrls),isPro);

@override
String toString() {
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


class _EntitlementChanged implements AutoRotateEvent {
  const _EntitlementChanged({required this.isPro, required this.userId});


 final  bool isPro;
 final  String userId;

/// Create a copy of AutoRotateEvent
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


class _FavouritesChanged implements AutoRotateEvent {
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
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FavouritesChanged&&const DeepCollectionEquality().equals(other._favouriteUrls, _favouriteUrls));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_favouriteUrls));

@override
String toString() {
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


class _Toggled implements AutoRotateEvent {
  const _Toggled(this.enabled);
  

 final  bool enabled;

/// Create a copy of AutoRotateEvent
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


class _IntervalChanged implements AutoRotateEvent {
  const _IntervalChanged(this.minutes);
  

 final  int minutes;

/// Create a copy of AutoRotateEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$IntervalChangedCopyWith<_IntervalChanged> get copyWith => __$IntervalChangedCopyWithImpl<_IntervalChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _IntervalChanged&&(identical(other.minutes, minutes) || other.minutes == minutes));
}


@override
int get hashCode => Object.hash(runtimeType,minutes);

@override
String toString() {
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


class _TargetChanged implements AutoRotateEvent {
  const _TargetChanged(this.target);
  

 final  WallpaperTarget target;

/// Create a copy of AutoRotateEvent
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


class _ShuffleChanged implements AutoRotateEvent {
  const _ShuffleChanged(this.shuffle);
  

 final  bool shuffle;

/// Create a copy of AutoRotateEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShuffleChangedCopyWith<_ShuffleChanged> get copyWith => __$ShuffleChangedCopyWithImpl<_ShuffleChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShuffleChanged&&(identical(other.shuffle, shuffle) || other.shuffle == shuffle));
}


@override
int get hashCode => Object.hash(runtimeType,shuffle);

@override
String toString() {
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


class _RotateNowPressed implements AutoRotateEvent {
  const _RotateNowPressed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RotateNowPressed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AutoRotateEvent.rotateNowPressed()';
}


}




/// @nodoc
mixin _$AutoRotateState {

 bool get loaded; AutoRotateConfig get config; AutoRotateStatus get status; int get favouriteCount; bool get isPro; bool get startFailed;
/// Create a copy of AutoRotateState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AutoRotateStateCopyWith<AutoRotateState> get copyWith => _$AutoRotateStateCopyWithImpl<AutoRotateState>(this as AutoRotateState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutoRotateState&&(identical(other.loaded, loaded) || other.loaded == loaded)&&(identical(other.config, config) || other.config == config)&&(identical(other.status, status) || other.status == status)&&(identical(other.favouriteCount, favouriteCount) || other.favouriteCount == favouriteCount)&&(identical(other.isPro, isPro) || other.isPro == isPro)&&(identical(other.startFailed, startFailed) || other.startFailed == startFailed));
}


@override
int get hashCode => Object.hash(runtimeType,loaded,config,status,favouriteCount,isPro,startFailed);

@override
String toString() {
  return 'AutoRotateState(loaded: $loaded, config: $config, status: $status, favouriteCount: $favouriteCount, isPro: $isPro, startFailed: $startFailed)';
}


}

/// @nodoc
abstract mixin class $AutoRotateStateCopyWith<$Res>  {
  factory $AutoRotateStateCopyWith(AutoRotateState value, $Res Function(AutoRotateState) _then) = _$AutoRotateStateCopyWithImpl;
@useResult
$Res call({
 bool loaded, AutoRotateConfig config, AutoRotateStatus status, int favouriteCount, bool isPro, bool startFailed
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
@pragma('vm:prefer-inline') @override $Res call({Object? loaded = null,Object? config = null,Object? status = null,Object? favouriteCount = null,Object? isPro = null,Object? startFailed = null,}) {
  return _then(_self.copyWith(
loaded: null == loaded ? _self.loaded : loaded // ignore: cast_nullable_to_non_nullable
as bool,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as AutoRotateConfig,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AutoRotateStatus,favouriteCount: null == favouriteCount ? _self.favouriteCount : favouriteCount // ignore: cast_nullable_to_non_nullable
as int,isPro: null == isPro ? _self.isPro : isPro // ignore: cast_nullable_to_non_nullable
as bool,startFailed: null == startFailed ? _self.startFailed : startFailed // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool loaded,  AutoRotateConfig config,  AutoRotateStatus status,  int favouriteCount,  bool isPro,  bool startFailed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AutoRotateState() when $default != null:
return $default(_that.loaded,_that.config,_that.status,_that.favouriteCount,_that.isPro,_that.startFailed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool loaded,  AutoRotateConfig config,  AutoRotateStatus status,  int favouriteCount,  bool isPro,  bool startFailed)  $default,) {final _that = this;
switch (_that) {
case _AutoRotateState():
return $default(_that.loaded,_that.config,_that.status,_that.favouriteCount,_that.isPro,_that.startFailed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool loaded,  AutoRotateConfig config,  AutoRotateStatus status,  int favouriteCount,  bool isPro,  bool startFailed)?  $default,) {final _that = this;
switch (_that) {
case _AutoRotateState() when $default != null:
return $default(_that.loaded,_that.config,_that.status,_that.favouriteCount,_that.isPro,_that.startFailed);case _:
  return null;

}
}

}

/// @nodoc


class _AutoRotateState implements AutoRotateState {
  const _AutoRotateState({required this.loaded, required this.config, required this.status, required this.favouriteCount, required this.isPro, required this.startFailed});
  

@override final  bool loaded;
@override final  AutoRotateConfig config;
@override final  AutoRotateStatus status;
@override final  int favouriteCount;
@override final  bool isPro;
@override final  bool startFailed;

/// Create a copy of AutoRotateState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AutoRotateStateCopyWith<_AutoRotateState> get copyWith => __$AutoRotateStateCopyWithImpl<_AutoRotateState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AutoRotateState&&(identical(other.loaded, loaded) || other.loaded == loaded)&&(identical(other.config, config) || other.config == config)&&(identical(other.status, status) || other.status == status)&&(identical(other.favouriteCount, favouriteCount) || other.favouriteCount == favouriteCount)&&(identical(other.isPro, isPro) || other.isPro == isPro)&&(identical(other.startFailed, startFailed) || other.startFailed == startFailed));
}


@override
int get hashCode => Object.hash(runtimeType,loaded,config,status,favouriteCount,isPro,startFailed);

@override
String toString() {
  return 'AutoRotateState(loaded: $loaded, config: $config, status: $status, favouriteCount: $favouriteCount, isPro: $isPro, startFailed: $startFailed)';
}


}

/// @nodoc
abstract mixin class _$AutoRotateStateCopyWith<$Res> implements $AutoRotateStateCopyWith<$Res> {
  factory _$AutoRotateStateCopyWith(_AutoRotateState value, $Res Function(_AutoRotateState) _then) = __$AutoRotateStateCopyWithImpl;
@override @useResult
$Res call({
 bool loaded, AutoRotateConfig config, AutoRotateStatus status, int favouriteCount, bool isPro, bool startFailed
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
@override @pragma('vm:prefer-inline') $Res call({Object? loaded = null,Object? config = null,Object? status = null,Object? favouriteCount = null,Object? isPro = null,Object? startFailed = null,}) {
  return _then(_AutoRotateState(
loaded: null == loaded ? _self.loaded : loaded // ignore: cast_nullable_to_non_nullable
as bool,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as AutoRotateConfig,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as AutoRotateStatus,favouriteCount: null == favouriteCount ? _self.favouriteCount : favouriteCount // ignore: cast_nullable_to_non_nullable
as int,isPro: null == isPro ? _self.isPro : isPro // ignore: cast_nullable_to_non_nullable
as bool,startFailed: null == startFailed ? _self.startFailed : startFailed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
