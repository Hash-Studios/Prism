// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'leaderboard_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LeaderboardEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LeaderboardEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LeaderboardEvent()';
}


}

/// @nodoc
class $LeaderboardEventCopyWith<$Res>  {
$LeaderboardEventCopyWith(LeaderboardEvent _, $Res Function(LeaderboardEvent) __);
}


/// Adds pattern-matching-related methods to [LeaderboardEvent].
extension LeaderboardEventPatterns on LeaderboardEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _TabChanged value)?  tabChanged,TResult Function( _Refreshed value)?  refreshed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _TabChanged() when tabChanged != null:
return tabChanged(_that);case _Refreshed() when refreshed != null:
return refreshed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _TabChanged value)  tabChanged,required TResult Function( _Refreshed value)  refreshed,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _TabChanged():
return tabChanged(_that);case _Refreshed():
return refreshed(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _TabChanged value)?  tabChanged,TResult? Function( _Refreshed value)?  refreshed,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _TabChanged() when tabChanged != null:
return tabChanged(_that);case _Refreshed() when refreshed != null:
return refreshed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  started,TResult Function( LeaderboardTab tab)?  tabChanged,TResult Function()?  refreshed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _TabChanged() when tabChanged != null:
return tabChanged(_that.tab);case _Refreshed() when refreshed != null:
return refreshed();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  started,required TResult Function( LeaderboardTab tab)  tabChanged,required TResult Function()  refreshed,}) {final _that = this;
switch (_that) {
case _Started():
return started();case _TabChanged():
return tabChanged(_that.tab);case _Refreshed():
return refreshed();case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  started,TResult? Function( LeaderboardTab tab)?  tabChanged,TResult? Function()?  refreshed,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _TabChanged() when tabChanged != null:
return tabChanged(_that.tab);case _Refreshed() when refreshed != null:
return refreshed();case _:
  return null;

}
}

}

/// @nodoc


class _Started implements LeaderboardEvent {
  const _Started();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LeaderboardEvent.started()';
}


}




/// @nodoc


class _TabChanged implements LeaderboardEvent {
  const _TabChanged(this.tab);
  

 final  LeaderboardTab tab;

/// Create a copy of LeaderboardEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TabChangedCopyWith<_TabChanged> get copyWith => __$TabChangedCopyWithImpl<_TabChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TabChanged&&(identical(other.tab, tab) || other.tab == tab));
}


@override
int get hashCode => Object.hash(runtimeType,tab);

@override
String toString() {
  return 'LeaderboardEvent.tabChanged(tab: $tab)';
}


}

/// @nodoc
abstract mixin class _$TabChangedCopyWith<$Res> implements $LeaderboardEventCopyWith<$Res> {
  factory _$TabChangedCopyWith(_TabChanged value, $Res Function(_TabChanged) _then) = __$TabChangedCopyWithImpl;
@useResult
$Res call({
 LeaderboardTab tab
});




}
/// @nodoc
class __$TabChangedCopyWithImpl<$Res>
    implements _$TabChangedCopyWith<$Res> {
  __$TabChangedCopyWithImpl(this._self, this._then);

  final _TabChanged _self;
  final $Res Function(_TabChanged) _then;

/// Create a copy of LeaderboardEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? tab = null,}) {
  return _then(_TabChanged(
null == tab ? _self.tab : tab // ignore: cast_nullable_to_non_nullable
as LeaderboardTab,
  ));
}


}

/// @nodoc


class _Refreshed implements LeaderboardEvent {
  const _Refreshed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Refreshed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LeaderboardEvent.refreshed()';
}


}




/// @nodoc
mixin _$LeaderboardState {

 LeaderboardTab get tab; LoadStatus get friendsStatus; LoadStatus get globalStatus; List<LeaderboardEntry> get friends; List<LeaderboardEntry> get global;
/// Create a copy of LeaderboardState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LeaderboardStateCopyWith<LeaderboardState> get copyWith => _$LeaderboardStateCopyWithImpl<LeaderboardState>(this as LeaderboardState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LeaderboardState&&(identical(other.tab, tab) || other.tab == tab)&&(identical(other.friendsStatus, friendsStatus) || other.friendsStatus == friendsStatus)&&(identical(other.globalStatus, globalStatus) || other.globalStatus == globalStatus)&&const DeepCollectionEquality().equals(other.friends, friends)&&const DeepCollectionEquality().equals(other.global, global));
}


@override
int get hashCode => Object.hash(runtimeType,tab,friendsStatus,globalStatus,const DeepCollectionEquality().hash(friends),const DeepCollectionEquality().hash(global));

@override
String toString() {
  return 'LeaderboardState(tab: $tab, friendsStatus: $friendsStatus, globalStatus: $globalStatus, friends: $friends, global: $global)';
}


}

/// @nodoc
abstract mixin class $LeaderboardStateCopyWith<$Res>  {
  factory $LeaderboardStateCopyWith(LeaderboardState value, $Res Function(LeaderboardState) _then) = _$LeaderboardStateCopyWithImpl;
@useResult
$Res call({
 LeaderboardTab tab, LoadStatus friendsStatus, LoadStatus globalStatus, List<LeaderboardEntry> friends, List<LeaderboardEntry> global
});




}
/// @nodoc
class _$LeaderboardStateCopyWithImpl<$Res>
    implements $LeaderboardStateCopyWith<$Res> {
  _$LeaderboardStateCopyWithImpl(this._self, this._then);

  final LeaderboardState _self;
  final $Res Function(LeaderboardState) _then;

/// Create a copy of LeaderboardState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tab = null,Object? friendsStatus = null,Object? globalStatus = null,Object? friends = null,Object? global = null,}) {
  return _then(_self.copyWith(
tab: null == tab ? _self.tab : tab // ignore: cast_nullable_to_non_nullable
as LeaderboardTab,friendsStatus: null == friendsStatus ? _self.friendsStatus : friendsStatus // ignore: cast_nullable_to_non_nullable
as LoadStatus,globalStatus: null == globalStatus ? _self.globalStatus : globalStatus // ignore: cast_nullable_to_non_nullable
as LoadStatus,friends: null == friends ? _self.friends : friends // ignore: cast_nullable_to_non_nullable
as List<LeaderboardEntry>,global: null == global ? _self.global : global // ignore: cast_nullable_to_non_nullable
as List<LeaderboardEntry>,
  ));
}

}


/// Adds pattern-matching-related methods to [LeaderboardState].
extension LeaderboardStatePatterns on LeaderboardState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LeaderboardState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LeaderboardState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LeaderboardState value)  $default,){
final _that = this;
switch (_that) {
case _LeaderboardState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LeaderboardState value)?  $default,){
final _that = this;
switch (_that) {
case _LeaderboardState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LeaderboardTab tab,  LoadStatus friendsStatus,  LoadStatus globalStatus,  List<LeaderboardEntry> friends,  List<LeaderboardEntry> global)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LeaderboardState() when $default != null:
return $default(_that.tab,_that.friendsStatus,_that.globalStatus,_that.friends,_that.global);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LeaderboardTab tab,  LoadStatus friendsStatus,  LoadStatus globalStatus,  List<LeaderboardEntry> friends,  List<LeaderboardEntry> global)  $default,) {final _that = this;
switch (_that) {
case _LeaderboardState():
return $default(_that.tab,_that.friendsStatus,_that.globalStatus,_that.friends,_that.global);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LeaderboardTab tab,  LoadStatus friendsStatus,  LoadStatus globalStatus,  List<LeaderboardEntry> friends,  List<LeaderboardEntry> global)?  $default,) {final _that = this;
switch (_that) {
case _LeaderboardState() when $default != null:
return $default(_that.tab,_that.friendsStatus,_that.globalStatus,_that.friends,_that.global);case _:
  return null;

}
}

}

/// @nodoc


class _LeaderboardState implements LeaderboardState {
  const _LeaderboardState({required this.tab, required this.friendsStatus, required this.globalStatus, required final  List<LeaderboardEntry> friends, required final  List<LeaderboardEntry> global}): _friends = friends,_global = global;
  

@override final  LeaderboardTab tab;
@override final  LoadStatus friendsStatus;
@override final  LoadStatus globalStatus;
 final  List<LeaderboardEntry> _friends;
@override List<LeaderboardEntry> get friends {
  if (_friends is EqualUnmodifiableListView) return _friends;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_friends);
}

 final  List<LeaderboardEntry> _global;
@override List<LeaderboardEntry> get global {
  if (_global is EqualUnmodifiableListView) return _global;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_global);
}


/// Create a copy of LeaderboardState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LeaderboardStateCopyWith<_LeaderboardState> get copyWith => __$LeaderboardStateCopyWithImpl<_LeaderboardState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LeaderboardState&&(identical(other.tab, tab) || other.tab == tab)&&(identical(other.friendsStatus, friendsStatus) || other.friendsStatus == friendsStatus)&&(identical(other.globalStatus, globalStatus) || other.globalStatus == globalStatus)&&const DeepCollectionEquality().equals(other._friends, _friends)&&const DeepCollectionEquality().equals(other._global, _global));
}


@override
int get hashCode => Object.hash(runtimeType,tab,friendsStatus,globalStatus,const DeepCollectionEquality().hash(_friends),const DeepCollectionEquality().hash(_global));

@override
String toString() {
  return 'LeaderboardState(tab: $tab, friendsStatus: $friendsStatus, globalStatus: $globalStatus, friends: $friends, global: $global)';
}


}

/// @nodoc
abstract mixin class _$LeaderboardStateCopyWith<$Res> implements $LeaderboardStateCopyWith<$Res> {
  factory _$LeaderboardStateCopyWith(_LeaderboardState value, $Res Function(_LeaderboardState) _then) = __$LeaderboardStateCopyWithImpl;
@override @useResult
$Res call({
 LeaderboardTab tab, LoadStatus friendsStatus, LoadStatus globalStatus, List<LeaderboardEntry> friends, List<LeaderboardEntry> global
});




}
/// @nodoc
class __$LeaderboardStateCopyWithImpl<$Res>
    implements _$LeaderboardStateCopyWith<$Res> {
  __$LeaderboardStateCopyWithImpl(this._self, this._then);

  final _LeaderboardState _self;
  final $Res Function(_LeaderboardState) _then;

/// Create a copy of LeaderboardState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tab = null,Object? friendsStatus = null,Object? globalStatus = null,Object? friends = null,Object? global = null,}) {
  return _then(_LeaderboardState(
tab: null == tab ? _self.tab : tab // ignore: cast_nullable_to_non_nullable
as LeaderboardTab,friendsStatus: null == friendsStatus ? _self.friendsStatus : friendsStatus // ignore: cast_nullable_to_non_nullable
as LoadStatus,globalStatus: null == globalStatus ? _self.globalStatus : globalStatus // ignore: cast_nullable_to_non_nullable
as LoadStatus,friends: null == friends ? _self._friends : friends // ignore: cast_nullable_to_non_nullable
as List<LeaderboardEntry>,global: null == global ? _self._global : global // ignore: cast_nullable_to_non_nullable
as List<LeaderboardEntry>,
  ));
}


}

// dart format on
