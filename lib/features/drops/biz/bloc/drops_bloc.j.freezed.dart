// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'drops_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DropsEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DropsEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DropsEvent()';
}


}

/// @nodoc
class $DropsEventCopyWith<$Res>  {
$DropsEventCopyWith(DropsEvent _, $Res Function(DropsEvent) __);
}


/// Adds pattern-matching-related methods to [DropsEvent].
extension DropsEventPatterns on DropsEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _Refreshed value)?  refreshed,TResult Function( _UnlockRequested value)?  unlockRequested,TResult Function( _Ticked value)?  ticked,TResult Function( _UnlockedChanged value)?  unlockedChanged,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _Refreshed() when refreshed != null:
return refreshed(_that);case _UnlockRequested() when unlockRequested != null:
return unlockRequested(_that);case _Ticked() when ticked != null:
return ticked(_that);case _UnlockedChanged() when unlockedChanged != null:
return unlockedChanged(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _Refreshed value)  refreshed,required TResult Function( _UnlockRequested value)  unlockRequested,required TResult Function( _Ticked value)  ticked,required TResult Function( _UnlockedChanged value)  unlockedChanged,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _Refreshed():
return refreshed(_that);case _UnlockRequested():
return unlockRequested(_that);case _Ticked():
return ticked(_that);case _UnlockedChanged():
return unlockedChanged(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _Refreshed value)?  refreshed,TResult? Function( _UnlockRequested value)?  unlockRequested,TResult? Function( _Ticked value)?  ticked,TResult? Function( _UnlockedChanged value)?  unlockedChanged,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _Refreshed() when refreshed != null:
return refreshed(_that);case _UnlockRequested() when unlockRequested != null:
return unlockRequested(_that);case _Ticked() when ticked != null:
return ticked(_that);case _UnlockedChanged() when unlockedChanged != null:
return unlockedChanged(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String? weekKey)?  started,TResult Function()?  refreshed,TResult Function( String? wallId)?  unlockRequested,TResult Function()?  ticked,TResult Function( Map<String, DropUnlock> unlocked)?  unlockedChanged,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.weekKey);case _Refreshed() when refreshed != null:
return refreshed();case _UnlockRequested() when unlockRequested != null:
return unlockRequested(_that.wallId);case _Ticked() when ticked != null:
return ticked();case _UnlockedChanged() when unlockedChanged != null:
return unlockedChanged(_that.unlocked);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String? weekKey)  started,required TResult Function()  refreshed,required TResult Function( String? wallId)  unlockRequested,required TResult Function()  ticked,required TResult Function( Map<String, DropUnlock> unlocked)  unlockedChanged,}) {final _that = this;
switch (_that) {
case _Started():
return started(_that.weekKey);case _Refreshed():
return refreshed();case _UnlockRequested():
return unlockRequested(_that.wallId);case _Ticked():
return ticked();case _UnlockedChanged():
return unlockedChanged(_that.unlocked);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String? weekKey)?  started,TResult? Function()?  refreshed,TResult? Function( String? wallId)?  unlockRequested,TResult? Function()?  ticked,TResult? Function( Map<String, DropUnlock> unlocked)?  unlockedChanged,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.weekKey);case _Refreshed() when refreshed != null:
return refreshed();case _UnlockRequested() when unlockRequested != null:
return unlockRequested(_that.wallId);case _Ticked() when ticked != null:
return ticked();case _UnlockedChanged() when unlockedChanged != null:
return unlockedChanged(_that.unlocked);case _:
  return null;

}
}

}

/// @nodoc


class _Started implements DropsEvent {
  const _Started({this.weekKey});
  

 final  String? weekKey;

/// Create a copy of DropsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StartedCopyWith<_Started> get copyWith => __$StartedCopyWithImpl<_Started>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started&&(identical(other.weekKey, weekKey) || other.weekKey == weekKey));
}


@override
int get hashCode => Object.hash(runtimeType,weekKey);

@override
String toString() {
  return 'DropsEvent.started(weekKey: $weekKey)';
}


}

/// @nodoc
abstract mixin class _$StartedCopyWith<$Res> implements $DropsEventCopyWith<$Res> {
  factory _$StartedCopyWith(_Started value, $Res Function(_Started) _then) = __$StartedCopyWithImpl;
@useResult
$Res call({
 String? weekKey
});




}
/// @nodoc
class __$StartedCopyWithImpl<$Res>
    implements _$StartedCopyWith<$Res> {
  __$StartedCopyWithImpl(this._self, this._then);

  final _Started _self;
  final $Res Function(_Started) _then;

/// Create a copy of DropsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? weekKey = freezed,}) {
  return _then(_Started(
weekKey: freezed == weekKey ? _self.weekKey : weekKey // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class _Refreshed implements DropsEvent {
  const _Refreshed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Refreshed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DropsEvent.refreshed()';
}


}




/// @nodoc


class _UnlockRequested implements DropsEvent {
  const _UnlockRequested({this.wallId});
  

 final  String? wallId;

/// Create a copy of DropsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UnlockRequestedCopyWith<_UnlockRequested> get copyWith => __$UnlockRequestedCopyWithImpl<_UnlockRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UnlockRequested&&(identical(other.wallId, wallId) || other.wallId == wallId));
}


@override
int get hashCode => Object.hash(runtimeType,wallId);

@override
String toString() {
  return 'DropsEvent.unlockRequested(wallId: $wallId)';
}


}

/// @nodoc
abstract mixin class _$UnlockRequestedCopyWith<$Res> implements $DropsEventCopyWith<$Res> {
  factory _$UnlockRequestedCopyWith(_UnlockRequested value, $Res Function(_UnlockRequested) _then) = __$UnlockRequestedCopyWithImpl;
@useResult
$Res call({
 String? wallId
});




}
/// @nodoc
class __$UnlockRequestedCopyWithImpl<$Res>
    implements _$UnlockRequestedCopyWith<$Res> {
  __$UnlockRequestedCopyWithImpl(this._self, this._then);

  final _UnlockRequested _self;
  final $Res Function(_UnlockRequested) _then;

/// Create a copy of DropsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? wallId = freezed,}) {
  return _then(_UnlockRequested(
wallId: freezed == wallId ? _self.wallId : wallId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class _Ticked implements DropsEvent {
  const _Ticked();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Ticked);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DropsEvent.ticked()';
}


}




/// @nodoc


class _UnlockedChanged implements DropsEvent {
  const _UnlockedChanged(final  Map<String, DropUnlock> unlocked): _unlocked = unlocked;
  

 final  Map<String, DropUnlock> _unlocked;
 Map<String, DropUnlock> get unlocked {
  if (_unlocked is EqualUnmodifiableMapView) return _unlocked;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_unlocked);
}


/// Create a copy of DropsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UnlockedChangedCopyWith<_UnlockedChanged> get copyWith => __$UnlockedChangedCopyWithImpl<_UnlockedChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UnlockedChanged&&const DeepCollectionEquality().equals(other._unlocked, _unlocked));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_unlocked));

@override
String toString() {
  return 'DropsEvent.unlockedChanged(unlocked: $unlocked)';
}


}

/// @nodoc
abstract mixin class _$UnlockedChangedCopyWith<$Res> implements $DropsEventCopyWith<$Res> {
  factory _$UnlockedChangedCopyWith(_UnlockedChanged value, $Res Function(_UnlockedChanged) _then) = __$UnlockedChangedCopyWithImpl;
@useResult
$Res call({
 Map<String, DropUnlock> unlocked
});




}
/// @nodoc
class __$UnlockedChangedCopyWithImpl<$Res>
    implements _$UnlockedChangedCopyWith<$Res> {
  __$UnlockedChangedCopyWithImpl(this._self, this._then);

  final _UnlockedChanged _self;
  final $Res Function(_UnlockedChanged) _then;

/// Create a copy of DropsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? unlocked = null,}) {
  return _then(_UnlockedChanged(
null == unlocked ? _self._unlocked : unlocked // ignore: cast_nullable_to_non_nullable
as Map<String, DropUnlock>,
  ));
}


}

/// @nodoc
mixin _$DropsState {

 LoadStatus get status; DateTime get now; DropEntity? get drop; List<DropEntity> get past; Map<String, DropUnlock> get unlocked;/// The wall id being unlocked, or [DropsBloc.packKey] for the pack.
 String? get busyKey;/// The newest unlock reply. The page toasts it once.
 DropUnlockResult? get lastResult;
/// Create a copy of DropsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DropsStateCopyWith<DropsState> get copyWith => _$DropsStateCopyWithImpl<DropsState>(this as DropsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DropsState&&(identical(other.status, status) || other.status == status)&&(identical(other.now, now) || other.now == now)&&(identical(other.drop, drop) || other.drop == drop)&&const DeepCollectionEquality().equals(other.past, past)&&const DeepCollectionEquality().equals(other.unlocked, unlocked)&&(identical(other.busyKey, busyKey) || other.busyKey == busyKey)&&(identical(other.lastResult, lastResult) || other.lastResult == lastResult));
}


@override
int get hashCode => Object.hash(runtimeType,status,now,drop,const DeepCollectionEquality().hash(past),const DeepCollectionEquality().hash(unlocked),busyKey,lastResult);

@override
String toString() {
  return 'DropsState(status: $status, now: $now, drop: $drop, past: $past, unlocked: $unlocked, busyKey: $busyKey, lastResult: $lastResult)';
}


}

/// @nodoc
abstract mixin class $DropsStateCopyWith<$Res>  {
  factory $DropsStateCopyWith(DropsState value, $Res Function(DropsState) _then) = _$DropsStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, DateTime now, DropEntity? drop, List<DropEntity> past, Map<String, DropUnlock> unlocked, String? busyKey, DropUnlockResult? lastResult
});




}
/// @nodoc
class _$DropsStateCopyWithImpl<$Res>
    implements $DropsStateCopyWith<$Res> {
  _$DropsStateCopyWithImpl(this._self, this._then);

  final DropsState _self;
  final $Res Function(DropsState) _then;

/// Create a copy of DropsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? now = null,Object? drop = freezed,Object? past = null,Object? unlocked = null,Object? busyKey = freezed,Object? lastResult = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,now: null == now ? _self.now : now // ignore: cast_nullable_to_non_nullable
as DateTime,drop: freezed == drop ? _self.drop : drop // ignore: cast_nullable_to_non_nullable
as DropEntity?,past: null == past ? _self.past : past // ignore: cast_nullable_to_non_nullable
as List<DropEntity>,unlocked: null == unlocked ? _self.unlocked : unlocked // ignore: cast_nullable_to_non_nullable
as Map<String, DropUnlock>,busyKey: freezed == busyKey ? _self.busyKey : busyKey // ignore: cast_nullable_to_non_nullable
as String?,lastResult: freezed == lastResult ? _self.lastResult : lastResult // ignore: cast_nullable_to_non_nullable
as DropUnlockResult?,
  ));
}

}


/// Adds pattern-matching-related methods to [DropsState].
extension DropsStatePatterns on DropsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DropsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DropsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DropsState value)  $default,){
final _that = this;
switch (_that) {
case _DropsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DropsState value)?  $default,){
final _that = this;
switch (_that) {
case _DropsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  DateTime now,  DropEntity? drop,  List<DropEntity> past,  Map<String, DropUnlock> unlocked,  String? busyKey,  DropUnlockResult? lastResult)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DropsState() when $default != null:
return $default(_that.status,_that.now,_that.drop,_that.past,_that.unlocked,_that.busyKey,_that.lastResult);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  DateTime now,  DropEntity? drop,  List<DropEntity> past,  Map<String, DropUnlock> unlocked,  String? busyKey,  DropUnlockResult? lastResult)  $default,) {final _that = this;
switch (_that) {
case _DropsState():
return $default(_that.status,_that.now,_that.drop,_that.past,_that.unlocked,_that.busyKey,_that.lastResult);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  DateTime now,  DropEntity? drop,  List<DropEntity> past,  Map<String, DropUnlock> unlocked,  String? busyKey,  DropUnlockResult? lastResult)?  $default,) {final _that = this;
switch (_that) {
case _DropsState() when $default != null:
return $default(_that.status,_that.now,_that.drop,_that.past,_that.unlocked,_that.busyKey,_that.lastResult);case _:
  return null;

}
}

}

/// @nodoc


class _DropsState extends DropsState {
  const _DropsState({required this.status, required this.now, this.drop, final  List<DropEntity> past = const <DropEntity>[], final  Map<String, DropUnlock> unlocked = const <String, DropUnlock>{}, this.busyKey, this.lastResult}): _past = past,_unlocked = unlocked,super._();
  

@override final  LoadStatus status;
@override final  DateTime now;
@override final  DropEntity? drop;
 final  List<DropEntity> _past;
@override@JsonKey() List<DropEntity> get past {
  if (_past is EqualUnmodifiableListView) return _past;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_past);
}

 final  Map<String, DropUnlock> _unlocked;
@override@JsonKey() Map<String, DropUnlock> get unlocked {
  if (_unlocked is EqualUnmodifiableMapView) return _unlocked;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_unlocked);
}

/// The wall id being unlocked, or [DropsBloc.packKey] for the pack.
@override final  String? busyKey;
/// The newest unlock reply. The page toasts it once.
@override final  DropUnlockResult? lastResult;

/// Create a copy of DropsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DropsStateCopyWith<_DropsState> get copyWith => __$DropsStateCopyWithImpl<_DropsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DropsState&&(identical(other.status, status) || other.status == status)&&(identical(other.now, now) || other.now == now)&&(identical(other.drop, drop) || other.drop == drop)&&const DeepCollectionEquality().equals(other._past, _past)&&const DeepCollectionEquality().equals(other._unlocked, _unlocked)&&(identical(other.busyKey, busyKey) || other.busyKey == busyKey)&&(identical(other.lastResult, lastResult) || other.lastResult == lastResult));
}


@override
int get hashCode => Object.hash(runtimeType,status,now,drop,const DeepCollectionEquality().hash(_past),const DeepCollectionEquality().hash(_unlocked),busyKey,lastResult);

@override
String toString() {
  return 'DropsState(status: $status, now: $now, drop: $drop, past: $past, unlocked: $unlocked, busyKey: $busyKey, lastResult: $lastResult)';
}


}

/// @nodoc
abstract mixin class _$DropsStateCopyWith<$Res> implements $DropsStateCopyWith<$Res> {
  factory _$DropsStateCopyWith(_DropsState value, $Res Function(_DropsState) _then) = __$DropsStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, DateTime now, DropEntity? drop, List<DropEntity> past, Map<String, DropUnlock> unlocked, String? busyKey, DropUnlockResult? lastResult
});




}
/// @nodoc
class __$DropsStateCopyWithImpl<$Res>
    implements _$DropsStateCopyWith<$Res> {
  __$DropsStateCopyWithImpl(this._self, this._then);

  final _DropsState _self;
  final $Res Function(_DropsState) _then;

/// Create a copy of DropsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? now = null,Object? drop = freezed,Object? past = null,Object? unlocked = null,Object? busyKey = freezed,Object? lastResult = freezed,}) {
  return _then(_DropsState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,now: null == now ? _self.now : now // ignore: cast_nullable_to_non_nullable
as DateTime,drop: freezed == drop ? _self.drop : drop // ignore: cast_nullable_to_non_nullable
as DropEntity?,past: null == past ? _self._past : past // ignore: cast_nullable_to_non_nullable
as List<DropEntity>,unlocked: null == unlocked ? _self._unlocked : unlocked // ignore: cast_nullable_to_non_nullable
as Map<String, DropUnlock>,busyKey: freezed == busyKey ? _self.busyKey : busyKey // ignore: cast_nullable_to_non_nullable
as String?,lastResult: freezed == lastResult ? _self.lastResult : lastResult // ignore: cast_nullable_to_non_nullable
as DropUnlockResult?,
  ));
}


}

// dart format on
