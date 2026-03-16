// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_discovery_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SearchDiscoveryEvent {




@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SearchDiscoveryEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SearchDiscoveryEvent()';
}


}

/// @nodoc
class $SearchDiscoveryEventCopyWith<$Res>  {
$SearchDiscoveryEventCopyWith(SearchDiscoveryEvent _, $Res Function(SearchDiscoveryEvent) __);
}


/// Adds pattern-matching-related methods to [SearchDiscoveryEvent].
extension SearchDiscoveryEventPatterns on SearchDiscoveryEvent {
/// A variant of `map` that fallback to returning `orElse`.
@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _FetchRequested value)?  fetchRequested,TResult Function( _RefreshRequested value)?  refreshRequested,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FetchRequested() when fetchRequested != null:
return fetchRequested(_that);case _RefreshRequested() when refreshRequested != null:
return refreshRequested(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _FetchRequested value)  fetchRequested,required TResult Function( _RefreshRequested value)  refreshRequested,}){
final _that = this;
switch (_that) {
case _FetchRequested():
return fetchRequested(_that);case _RefreshRequested():
return refreshRequested(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _FetchRequested value)?  fetchRequested,TResult? Function( _RefreshRequested value)?  refreshRequested,}){
final _that = this;
switch (_that) {
case _FetchRequested() when fetchRequested != null:
return fetchRequested(_that);case _RefreshRequested() when refreshRequested != null:
return refreshRequested(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  fetchRequested,TResult Function()?  refreshRequested,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FetchRequested() when fetchRequested != null:
return fetchRequested();case _RefreshRequested() when refreshRequested != null:
return refreshRequested();case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  fetchRequested,required TResult Function()  refreshRequested,}) {final _that = this;
switch (_that) {
case _FetchRequested():
return fetchRequested();case _RefreshRequested():
return refreshRequested();case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  fetchRequested,TResult? Function()?  refreshRequested,}) {final _that = this;
switch (_that) {
case _FetchRequested() when fetchRequested != null:
return fetchRequested();case _RefreshRequested() when refreshRequested != null:
return refreshRequested();case _:
  return null;

}
}

}

/// @nodoc


class _FetchRequested implements SearchDiscoveryEvent {
  const _FetchRequested();





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FetchRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SearchDiscoveryEvent.fetchRequested()';
}


}

/// @nodoc


class _RefreshRequested implements SearchDiscoveryEvent {
  const _RefreshRequested();





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefreshRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SearchDiscoveryEvent.refreshRequested()';
}


}




/// @nodoc
mixin _$SearchDiscoveryState {

 LoadStatus get status; List<WallhavenWallpaper> get trendingWalls; Failure? get failure;
/// Create a copy of SearchDiscoveryState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SearchDiscoveryStateCopyWith<SearchDiscoveryState> get copyWith => _$SearchDiscoveryStateCopyWithImpl<SearchDiscoveryState>(this as SearchDiscoveryState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SearchDiscoveryState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.trendingWalls, trendingWalls)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(trendingWalls),failure);

@override
String toString() {
  return 'SearchDiscoveryState(status: $status, trendingWalls: $trendingWalls, failure: $failure)';
}


}

/// @nodoc
abstract mixin class $SearchDiscoveryStateCopyWith<$Res>  {
  factory $SearchDiscoveryStateCopyWith(SearchDiscoveryState value, $Res Function(SearchDiscoveryState) _then) = _$SearchDiscoveryStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, List<WallhavenWallpaper> trendingWalls, Failure? failure
});




}
/// @nodoc
class _$SearchDiscoveryStateCopyWithImpl<$Res>
    implements $SearchDiscoveryStateCopyWith<$Res> {
  _$SearchDiscoveryStateCopyWithImpl(this._self, this._then);

  final SearchDiscoveryState _self;
  final $Res Function(SearchDiscoveryState) _then;

/// Create a copy of SearchDiscoveryState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? trendingWalls = null,Object? failure = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,trendingWalls: null == trendingWalls ? _self.trendingWalls : trendingWalls // ignore: cast_nullable_to_non_nullable
as List<WallhavenWallpaper>,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}

}


/// Adds pattern-matching-related methods to [SearchDiscoveryState].
extension SearchDiscoveryStatePatterns on SearchDiscoveryState {
/// A variant of `map` that fallback to returning `orElse`.
@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SearchDiscoveryState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SearchDiscoveryState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SearchDiscoveryState value)  $default,){
final _that = this;
switch (_that) {
case _SearchDiscoveryState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SearchDiscoveryState value)?  $default,){
final _that = this;
switch (_that) {
case _SearchDiscoveryState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  List<WallhavenWallpaper> trendingWalls,  Failure? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SearchDiscoveryState() when $default != null:
return $default(_that.status,_that.trendingWalls,_that.failure);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  List<WallhavenWallpaper> trendingWalls,  Failure? failure)  $default,) {final _that = this;
switch (_that) {
case _SearchDiscoveryState():
return $default(_that.status,_that.trendingWalls,_that.failure);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  List<WallhavenWallpaper> trendingWalls,  Failure? failure)?  $default,) {final _that = this;
switch (_that) {
case _SearchDiscoveryState() when $default != null:
return $default(_that.status,_that.trendingWalls,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _SearchDiscoveryState implements SearchDiscoveryState {
  const _SearchDiscoveryState({required this.status, required final  List<WallhavenWallpaper> trendingWalls, this.failure}): _trendingWalls = trendingWalls;


@override final  LoadStatus status;
 final  List<WallhavenWallpaper> _trendingWalls;
@override List<WallhavenWallpaper> get trendingWalls {
  if (_trendingWalls is EqualUnmodifiableListView) return _trendingWalls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_trendingWalls);
}

@override final  Failure? failure;

/// Create a copy of SearchDiscoveryState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SearchDiscoveryStateCopyWith<_SearchDiscoveryState> get copyWith => __$SearchDiscoveryStateCopyWithImpl<_SearchDiscoveryState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SearchDiscoveryState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._trendingWalls, _trendingWalls)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_trendingWalls),failure);

@override
String toString() {
  return 'SearchDiscoveryState(status: $status, trendingWalls: $trendingWalls, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$SearchDiscoveryStateCopyWith<$Res> implements $SearchDiscoveryStateCopyWith<$Res> {
  factory _$SearchDiscoveryStateCopyWith(_SearchDiscoveryState value, $Res Function(_SearchDiscoveryState) _then) = __$SearchDiscoveryStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, List<WallhavenWallpaper> trendingWalls, Failure? failure
});




}
/// @nodoc
class __$SearchDiscoveryStateCopyWithImpl<$Res>
    implements _$SearchDiscoveryStateCopyWith<$Res> {
  __$SearchDiscoveryStateCopyWithImpl(this._self, this._then);

  final _SearchDiscoveryState _self;
  final $Res Function(_SearchDiscoveryState) _then;

/// Create a copy of SearchDiscoveryState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? trendingWalls = null,Object? failure = freezed,}) {
  return _then(_SearchDiscoveryState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,trendingWalls: null == trendingWalls ? _self._trendingWalls : trendingWalls // ignore: cast_nullable_to_non_nullable
as List<WallhavenWallpaper>,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}


}

// dart format on
