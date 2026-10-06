// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'favourite_walls_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FavouriteWallsEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FavouriteWallsEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FavouriteWallsEvent()';
}


}

/// @nodoc
class $FavouriteWallsEventCopyWith<$Res>  {
$FavouriteWallsEventCopyWith(FavouriteWallsEvent _, $Res Function(FavouriteWallsEvent) __);
}


/// Adds pattern-matching-related methods to [FavouriteWallsEvent].
extension FavouriteWallsEventPatterns on FavouriteWallsEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _RefreshRequested value)?  refreshRequested,TResult Function( _ToggleRequested value)?  toggleRequested,TResult Function( _ClearRequested value)?  clearRequested,TResult Function( _SortChanged value)?  sortChanged,TResult Function( _SourceFilterChanged value)?  sourceFilterChanged,TResult Function( _QueryChanged value)?  queryChanged,TResult Function( _RemoveRequested value)?  removeRequested,TResult Function( _RestoreRequested value)?  restoreRequested,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _RefreshRequested() when refreshRequested != null:
return refreshRequested(_that);case _ToggleRequested() when toggleRequested != null:
return toggleRequested(_that);case _ClearRequested() when clearRequested != null:
return clearRequested(_that);case _SortChanged() when sortChanged != null:
return sortChanged(_that);case _SourceFilterChanged() when sourceFilterChanged != null:
return sourceFilterChanged(_that);case _QueryChanged() when queryChanged != null:
return queryChanged(_that);case _RemoveRequested() when removeRequested != null:
return removeRequested(_that);case _RestoreRequested() when restoreRequested != null:
return restoreRequested(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _RefreshRequested value)  refreshRequested,required TResult Function( _ToggleRequested value)  toggleRequested,required TResult Function( _ClearRequested value)  clearRequested,required TResult Function( _SortChanged value)  sortChanged,required TResult Function( _SourceFilterChanged value)  sourceFilterChanged,required TResult Function( _QueryChanged value)  queryChanged,required TResult Function( _RemoveRequested value)  removeRequested,required TResult Function( _RestoreRequested value)  restoreRequested,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _RefreshRequested():
return refreshRequested(_that);case _ToggleRequested():
return toggleRequested(_that);case _ClearRequested():
return clearRequested(_that);case _SortChanged():
return sortChanged(_that);case _SourceFilterChanged():
return sourceFilterChanged(_that);case _QueryChanged():
return queryChanged(_that);case _RemoveRequested():
return removeRequested(_that);case _RestoreRequested():
return restoreRequested(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _RefreshRequested value)?  refreshRequested,TResult? Function( _ToggleRequested value)?  toggleRequested,TResult? Function( _ClearRequested value)?  clearRequested,TResult? Function( _SortChanged value)?  sortChanged,TResult? Function( _SourceFilterChanged value)?  sourceFilterChanged,TResult? Function( _QueryChanged value)?  queryChanged,TResult? Function( _RemoveRequested value)?  removeRequested,TResult? Function( _RestoreRequested value)?  restoreRequested,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _RefreshRequested() when refreshRequested != null:
return refreshRequested(_that);case _ToggleRequested() when toggleRequested != null:
return toggleRequested(_that);case _ClearRequested() when clearRequested != null:
return clearRequested(_that);case _SortChanged() when sortChanged != null:
return sortChanged(_that);case _SourceFilterChanged() when sourceFilterChanged != null:
return sourceFilterChanged(_that);case _QueryChanged() when queryChanged != null:
return queryChanged(_that);case _RemoveRequested() when removeRequested != null:
return removeRequested(_that);case _RestoreRequested() when restoreRequested != null:
return restoreRequested(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String userId,  int operationId)?  started,TResult Function( int operationId)?  refreshRequested,TResult Function( FavouriteWallEntity wall,  int operationId)?  toggleRequested,TResult Function( int operationId)?  clearRequested,TResult Function( FavouriteSort sort)?  sortChanged,TResult Function( WallpaperSource? source)?  sourceFilterChanged,TResult Function( String query)?  queryChanged,TResult Function( List<String> wallIds,  int operationId)?  removeRequested,TResult Function( List<FavouriteWallEntity> walls,  int operationId)?  restoreRequested,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.userId,_that.operationId);case _RefreshRequested() when refreshRequested != null:
return refreshRequested(_that.operationId);case _ToggleRequested() when toggleRequested != null:
return toggleRequested(_that.wall,_that.operationId);case _ClearRequested() when clearRequested != null:
return clearRequested(_that.operationId);case _SortChanged() when sortChanged != null:
return sortChanged(_that.sort);case _SourceFilterChanged() when sourceFilterChanged != null:
return sourceFilterChanged(_that.source);case _QueryChanged() when queryChanged != null:
return queryChanged(_that.query);case _RemoveRequested() when removeRequested != null:
return removeRequested(_that.wallIds,_that.operationId);case _RestoreRequested() when restoreRequested != null:
return restoreRequested(_that.walls,_that.operationId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String userId,  int operationId)  started,required TResult Function( int operationId)  refreshRequested,required TResult Function( FavouriteWallEntity wall,  int operationId)  toggleRequested,required TResult Function( int operationId)  clearRequested,required TResult Function( FavouriteSort sort)  sortChanged,required TResult Function( WallpaperSource? source)  sourceFilterChanged,required TResult Function( String query)  queryChanged,required TResult Function( List<String> wallIds,  int operationId)  removeRequested,required TResult Function( List<FavouriteWallEntity> walls,  int operationId)  restoreRequested,}) {final _that = this;
switch (_that) {
case _Started():
return started(_that.userId,_that.operationId);case _RefreshRequested():
return refreshRequested(_that.operationId);case _ToggleRequested():
return toggleRequested(_that.wall,_that.operationId);case _ClearRequested():
return clearRequested(_that.operationId);case _SortChanged():
return sortChanged(_that.sort);case _SourceFilterChanged():
return sourceFilterChanged(_that.source);case _QueryChanged():
return queryChanged(_that.query);case _RemoveRequested():
return removeRequested(_that.wallIds,_that.operationId);case _RestoreRequested():
return restoreRequested(_that.walls,_that.operationId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String userId,  int operationId)?  started,TResult? Function( int operationId)?  refreshRequested,TResult? Function( FavouriteWallEntity wall,  int operationId)?  toggleRequested,TResult? Function( int operationId)?  clearRequested,TResult? Function( FavouriteSort sort)?  sortChanged,TResult? Function( WallpaperSource? source)?  sourceFilterChanged,TResult? Function( String query)?  queryChanged,TResult? Function( List<String> wallIds,  int operationId)?  removeRequested,TResult? Function( List<FavouriteWallEntity> walls,  int operationId)?  restoreRequested,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.userId,_that.operationId);case _RefreshRequested() when refreshRequested != null:
return refreshRequested(_that.operationId);case _ToggleRequested() when toggleRequested != null:
return toggleRequested(_that.wall,_that.operationId);case _ClearRequested() when clearRequested != null:
return clearRequested(_that.operationId);case _SortChanged() when sortChanged != null:
return sortChanged(_that.sort);case _SourceFilterChanged() when sourceFilterChanged != null:
return sourceFilterChanged(_that.source);case _QueryChanged() when queryChanged != null:
return queryChanged(_that.query);case _RemoveRequested() when removeRequested != null:
return removeRequested(_that.wallIds,_that.operationId);case _RestoreRequested() when restoreRequested != null:
return restoreRequested(_that.walls,_that.operationId);case _:
  return null;

}
}

}

/// @nodoc


class _Started implements FavouriteWallsEvent {
  const _Started({required this.userId, this.operationId = 0});
  

 final  String userId;
@JsonKey() final  int operationId;

/// Create a copy of FavouriteWallsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StartedCopyWith<_Started> get copyWith => __$StartedCopyWithImpl<_Started>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.operationId, operationId) || other.operationId == operationId));
}


@override
int get hashCode => Object.hash(runtimeType,userId,operationId);

@override
String toString() {
  return 'FavouriteWallsEvent.started(userId: $userId, operationId: $operationId)';
}


}

/// @nodoc
abstract mixin class _$StartedCopyWith<$Res> implements $FavouriteWallsEventCopyWith<$Res> {
  factory _$StartedCopyWith(_Started value, $Res Function(_Started) _then) = __$StartedCopyWithImpl;
@useResult
$Res call({
 String userId, int operationId
});




}
/// @nodoc
class __$StartedCopyWithImpl<$Res>
    implements _$StartedCopyWith<$Res> {
  __$StartedCopyWithImpl(this._self, this._then);

  final _Started _self;
  final $Res Function(_Started) _then;

/// Create a copy of FavouriteWallsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? operationId = null,}) {
  return _then(_Started(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,operationId: null == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _RefreshRequested implements FavouriteWallsEvent {
  const _RefreshRequested({this.operationId = 0});
  

@JsonKey() final  int operationId;

/// Create a copy of FavouriteWallsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RefreshRequestedCopyWith<_RefreshRequested> get copyWith => __$RefreshRequestedCopyWithImpl<_RefreshRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefreshRequested&&(identical(other.operationId, operationId) || other.operationId == operationId));
}


@override
int get hashCode => Object.hash(runtimeType,operationId);

@override
String toString() {
  return 'FavouriteWallsEvent.refreshRequested(operationId: $operationId)';
}


}

/// @nodoc
abstract mixin class _$RefreshRequestedCopyWith<$Res> implements $FavouriteWallsEventCopyWith<$Res> {
  factory _$RefreshRequestedCopyWith(_RefreshRequested value, $Res Function(_RefreshRequested) _then) = __$RefreshRequestedCopyWithImpl;
@useResult
$Res call({
 int operationId
});




}
/// @nodoc
class __$RefreshRequestedCopyWithImpl<$Res>
    implements _$RefreshRequestedCopyWith<$Res> {
  __$RefreshRequestedCopyWithImpl(this._self, this._then);

  final _RefreshRequested _self;
  final $Res Function(_RefreshRequested) _then;

/// Create a copy of FavouriteWallsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? operationId = null,}) {
  return _then(_RefreshRequested(
operationId: null == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _ToggleRequested implements FavouriteWallsEvent {
  const _ToggleRequested({required this.wall, this.operationId = 0});
  

 final  FavouriteWallEntity wall;
@JsonKey() final  int operationId;

/// Create a copy of FavouriteWallsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ToggleRequestedCopyWith<_ToggleRequested> get copyWith => __$ToggleRequestedCopyWithImpl<_ToggleRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ToggleRequested&&(identical(other.wall, wall) || other.wall == wall)&&(identical(other.operationId, operationId) || other.operationId == operationId));
}


@override
int get hashCode => Object.hash(runtimeType,wall,operationId);

@override
String toString() {
  return 'FavouriteWallsEvent.toggleRequested(wall: $wall, operationId: $operationId)';
}


}

/// @nodoc
abstract mixin class _$ToggleRequestedCopyWith<$Res> implements $FavouriteWallsEventCopyWith<$Res> {
  factory _$ToggleRequestedCopyWith(_ToggleRequested value, $Res Function(_ToggleRequested) _then) = __$ToggleRequestedCopyWithImpl;
@useResult
$Res call({
 FavouriteWallEntity wall, int operationId
});




}
/// @nodoc
class __$ToggleRequestedCopyWithImpl<$Res>
    implements _$ToggleRequestedCopyWith<$Res> {
  __$ToggleRequestedCopyWithImpl(this._self, this._then);

  final _ToggleRequested _self;
  final $Res Function(_ToggleRequested) _then;

/// Create a copy of FavouriteWallsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? wall = null,Object? operationId = null,}) {
  return _then(_ToggleRequested(
wall: null == wall ? _self.wall : wall // ignore: cast_nullable_to_non_nullable
as FavouriteWallEntity,operationId: null == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _ClearRequested implements FavouriteWallsEvent {
  const _ClearRequested({this.operationId = 0});
  

@JsonKey() final  int operationId;

/// Create a copy of FavouriteWallsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClearRequestedCopyWith<_ClearRequested> get copyWith => __$ClearRequestedCopyWithImpl<_ClearRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClearRequested&&(identical(other.operationId, operationId) || other.operationId == operationId));
}


@override
int get hashCode => Object.hash(runtimeType,operationId);

@override
String toString() {
  return 'FavouriteWallsEvent.clearRequested(operationId: $operationId)';
}


}

/// @nodoc
abstract mixin class _$ClearRequestedCopyWith<$Res> implements $FavouriteWallsEventCopyWith<$Res> {
  factory _$ClearRequestedCopyWith(_ClearRequested value, $Res Function(_ClearRequested) _then) = __$ClearRequestedCopyWithImpl;
@useResult
$Res call({
 int operationId
});




}
/// @nodoc
class __$ClearRequestedCopyWithImpl<$Res>
    implements _$ClearRequestedCopyWith<$Res> {
  __$ClearRequestedCopyWithImpl(this._self, this._then);

  final _ClearRequested _self;
  final $Res Function(_ClearRequested) _then;

/// Create a copy of FavouriteWallsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? operationId = null,}) {
  return _then(_ClearRequested(
operationId: null == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _SortChanged implements FavouriteWallsEvent {
  const _SortChanged({required this.sort});
  

 final  FavouriteSort sort;

/// Create a copy of FavouriteWallsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SortChangedCopyWith<_SortChanged> get copyWith => __$SortChangedCopyWithImpl<_SortChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SortChanged&&(identical(other.sort, sort) || other.sort == sort));
}


@override
int get hashCode => Object.hash(runtimeType,sort);

@override
String toString() {
  return 'FavouriteWallsEvent.sortChanged(sort: $sort)';
}


}

/// @nodoc
abstract mixin class _$SortChangedCopyWith<$Res> implements $FavouriteWallsEventCopyWith<$Res> {
  factory _$SortChangedCopyWith(_SortChanged value, $Res Function(_SortChanged) _then) = __$SortChangedCopyWithImpl;
@useResult
$Res call({
 FavouriteSort sort
});




}
/// @nodoc
class __$SortChangedCopyWithImpl<$Res>
    implements _$SortChangedCopyWith<$Res> {
  __$SortChangedCopyWithImpl(this._self, this._then);

  final _SortChanged _self;
  final $Res Function(_SortChanged) _then;

/// Create a copy of FavouriteWallsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sort = null,}) {
  return _then(_SortChanged(
sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as FavouriteSort,
  ));
}


}

/// @nodoc


class _SourceFilterChanged implements FavouriteWallsEvent {
  const _SourceFilterChanged({this.source});
  

 final  WallpaperSource? source;

/// Create a copy of FavouriteWallsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SourceFilterChangedCopyWith<_SourceFilterChanged> get copyWith => __$SourceFilterChangedCopyWithImpl<_SourceFilterChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SourceFilterChanged&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode => Object.hash(runtimeType,source);

@override
String toString() {
  return 'FavouriteWallsEvent.sourceFilterChanged(source: $source)';
}


}

/// @nodoc
abstract mixin class _$SourceFilterChangedCopyWith<$Res> implements $FavouriteWallsEventCopyWith<$Res> {
  factory _$SourceFilterChangedCopyWith(_SourceFilterChanged value, $Res Function(_SourceFilterChanged) _then) = __$SourceFilterChangedCopyWithImpl;
@useResult
$Res call({
 WallpaperSource? source
});




}
/// @nodoc
class __$SourceFilterChangedCopyWithImpl<$Res>
    implements _$SourceFilterChangedCopyWith<$Res> {
  __$SourceFilterChangedCopyWithImpl(this._self, this._then);

  final _SourceFilterChanged _self;
  final $Res Function(_SourceFilterChanged) _then;

/// Create a copy of FavouriteWallsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = freezed,}) {
  return _then(_SourceFilterChanged(
source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as WallpaperSource?,
  ));
}


}

/// @nodoc


class _QueryChanged implements FavouriteWallsEvent {
  const _QueryChanged({required this.query});
  

 final  String query;

/// Create a copy of FavouriteWallsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QueryChangedCopyWith<_QueryChanged> get copyWith => __$QueryChangedCopyWithImpl<_QueryChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QueryChanged&&(identical(other.query, query) || other.query == query));
}


@override
int get hashCode => Object.hash(runtimeType,query);

@override
String toString() {
  return 'FavouriteWallsEvent.queryChanged(query: $query)';
}


}

/// @nodoc
abstract mixin class _$QueryChangedCopyWith<$Res> implements $FavouriteWallsEventCopyWith<$Res> {
  factory _$QueryChangedCopyWith(_QueryChanged value, $Res Function(_QueryChanged) _then) = __$QueryChangedCopyWithImpl;
@useResult
$Res call({
 String query
});




}
/// @nodoc
class __$QueryChangedCopyWithImpl<$Res>
    implements _$QueryChangedCopyWith<$Res> {
  __$QueryChangedCopyWithImpl(this._self, this._then);

  final _QueryChanged _self;
  final $Res Function(_QueryChanged) _then;

/// Create a copy of FavouriteWallsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? query = null,}) {
  return _then(_QueryChanged(
query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _RemoveRequested implements FavouriteWallsEvent {
  const _RemoveRequested({required final  List<String> wallIds, this.operationId = 0}): _wallIds = wallIds;
  

 final  List<String> _wallIds;
 List<String> get wallIds {
  if (_wallIds is EqualUnmodifiableListView) return _wallIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_wallIds);
}

@JsonKey() final  int operationId;

/// Create a copy of FavouriteWallsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RemoveRequestedCopyWith<_RemoveRequested> get copyWith => __$RemoveRequestedCopyWithImpl<_RemoveRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RemoveRequested&&const DeepCollectionEquality().equals(other._wallIds, _wallIds)&&(identical(other.operationId, operationId) || other.operationId == operationId));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_wallIds),operationId);

@override
String toString() {
  return 'FavouriteWallsEvent.removeRequested(wallIds: $wallIds, operationId: $operationId)';
}


}

/// @nodoc
abstract mixin class _$RemoveRequestedCopyWith<$Res> implements $FavouriteWallsEventCopyWith<$Res> {
  factory _$RemoveRequestedCopyWith(_RemoveRequested value, $Res Function(_RemoveRequested) _then) = __$RemoveRequestedCopyWithImpl;
@useResult
$Res call({
 List<String> wallIds, int operationId
});




}
/// @nodoc
class __$RemoveRequestedCopyWithImpl<$Res>
    implements _$RemoveRequestedCopyWith<$Res> {
  __$RemoveRequestedCopyWithImpl(this._self, this._then);

  final _RemoveRequested _self;
  final $Res Function(_RemoveRequested) _then;

/// Create a copy of FavouriteWallsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? wallIds = null,Object? operationId = null,}) {
  return _then(_RemoveRequested(
wallIds: null == wallIds ? _self._wallIds : wallIds // ignore: cast_nullable_to_non_nullable
as List<String>,operationId: null == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _RestoreRequested implements FavouriteWallsEvent {
  const _RestoreRequested({required final  List<FavouriteWallEntity> walls, this.operationId = 0}): _walls = walls;
  

 final  List<FavouriteWallEntity> _walls;
 List<FavouriteWallEntity> get walls {
  if (_walls is EqualUnmodifiableListView) return _walls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_walls);
}

@JsonKey() final  int operationId;

/// Create a copy of FavouriteWallsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RestoreRequestedCopyWith<_RestoreRequested> get copyWith => __$RestoreRequestedCopyWithImpl<_RestoreRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RestoreRequested&&const DeepCollectionEquality().equals(other._walls, _walls)&&(identical(other.operationId, operationId) || other.operationId == operationId));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_walls),operationId);

@override
String toString() {
  return 'FavouriteWallsEvent.restoreRequested(walls: $walls, operationId: $operationId)';
}


}

/// @nodoc
abstract mixin class _$RestoreRequestedCopyWith<$Res> implements $FavouriteWallsEventCopyWith<$Res> {
  factory _$RestoreRequestedCopyWith(_RestoreRequested value, $Res Function(_RestoreRequested) _then) = __$RestoreRequestedCopyWithImpl;
@useResult
$Res call({
 List<FavouriteWallEntity> walls, int operationId
});




}
/// @nodoc
class __$RestoreRequestedCopyWithImpl<$Res>
    implements _$RestoreRequestedCopyWith<$Res> {
  __$RestoreRequestedCopyWithImpl(this._self, this._then);

  final _RestoreRequested _self;
  final $Res Function(_RestoreRequested) _then;

/// Create a copy of FavouriteWallsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? walls = null,Object? operationId = null,}) {
  return _then(_RestoreRequested(
walls: null == walls ? _self._walls : walls // ignore: cast_nullable_to_non_nullable
as List<FavouriteWallEntity>,operationId: null == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$FavouriteWallsState {

 LoadStatus get status; ActionStatus get actionStatus; String get userId; List<FavouriteWallEntity> get items; FavouriteSort get sort; WallpaperSource? get sourceFilter; String get query; int get completedOperationId; Failure? get failure;
/// Create a copy of FavouriteWallsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FavouriteWallsStateCopyWith<FavouriteWallsState> get copyWith => _$FavouriteWallsStateCopyWithImpl<FavouriteWallsState>(this as FavouriteWallsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FavouriteWallsState&&(identical(other.status, status) || other.status == status)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&(identical(other.userId, userId) || other.userId == userId)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.sort, sort) || other.sort == sort)&&(identical(other.sourceFilter, sourceFilter) || other.sourceFilter == sourceFilter)&&(identical(other.query, query) || other.query == query)&&(identical(other.completedOperationId, completedOperationId) || other.completedOperationId == completedOperationId)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,status,actionStatus,userId,const DeepCollectionEquality().hash(items),sort,sourceFilter,query,completedOperationId,failure);

@override
String toString() {
  return 'FavouriteWallsState(status: $status, actionStatus: $actionStatus, userId: $userId, items: $items, sort: $sort, sourceFilter: $sourceFilter, query: $query, completedOperationId: $completedOperationId, failure: $failure)';
}


}

/// @nodoc
abstract mixin class $FavouriteWallsStateCopyWith<$Res>  {
  factory $FavouriteWallsStateCopyWith(FavouriteWallsState value, $Res Function(FavouriteWallsState) _then) = _$FavouriteWallsStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, ActionStatus actionStatus, String userId, List<FavouriteWallEntity> items, FavouriteSort sort, WallpaperSource? sourceFilter, String query, int completedOperationId, Failure? failure
});




}
/// @nodoc
class _$FavouriteWallsStateCopyWithImpl<$Res>
    implements $FavouriteWallsStateCopyWith<$Res> {
  _$FavouriteWallsStateCopyWithImpl(this._self, this._then);

  final FavouriteWallsState _self;
  final $Res Function(FavouriteWallsState) _then;

/// Create a copy of FavouriteWallsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? actionStatus = null,Object? userId = null,Object? items = null,Object? sort = null,Object? sourceFilter = freezed,Object? query = null,Object? completedOperationId = null,Object? failure = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,actionStatus: null == actionStatus ? _self.actionStatus : actionStatus // ignore: cast_nullable_to_non_nullable
as ActionStatus,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<FavouriteWallEntity>,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as FavouriteSort,sourceFilter: freezed == sourceFilter ? _self.sourceFilter : sourceFilter // ignore: cast_nullable_to_non_nullable
as WallpaperSource?,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,completedOperationId: null == completedOperationId ? _self.completedOperationId : completedOperationId // ignore: cast_nullable_to_non_nullable
as int,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}

}


/// Adds pattern-matching-related methods to [FavouriteWallsState].
extension FavouriteWallsStatePatterns on FavouriteWallsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FavouriteWallsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FavouriteWallsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FavouriteWallsState value)  $default,){
final _that = this;
switch (_that) {
case _FavouriteWallsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FavouriteWallsState value)?  $default,){
final _that = this;
switch (_that) {
case _FavouriteWallsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  ActionStatus actionStatus,  String userId,  List<FavouriteWallEntity> items,  FavouriteSort sort,  WallpaperSource? sourceFilter,  String query,  int completedOperationId,  Failure? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FavouriteWallsState() when $default != null:
return $default(_that.status,_that.actionStatus,_that.userId,_that.items,_that.sort,_that.sourceFilter,_that.query,_that.completedOperationId,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  ActionStatus actionStatus,  String userId,  List<FavouriteWallEntity> items,  FavouriteSort sort,  WallpaperSource? sourceFilter,  String query,  int completedOperationId,  Failure? failure)  $default,) {final _that = this;
switch (_that) {
case _FavouriteWallsState():
return $default(_that.status,_that.actionStatus,_that.userId,_that.items,_that.sort,_that.sourceFilter,_that.query,_that.completedOperationId,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  ActionStatus actionStatus,  String userId,  List<FavouriteWallEntity> items,  FavouriteSort sort,  WallpaperSource? sourceFilter,  String query,  int completedOperationId,  Failure? failure)?  $default,) {final _that = this;
switch (_that) {
case _FavouriteWallsState() when $default != null:
return $default(_that.status,_that.actionStatus,_that.userId,_that.items,_that.sort,_that.sourceFilter,_that.query,_that.completedOperationId,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _FavouriteWallsState extends FavouriteWallsState {
  const _FavouriteWallsState({required this.status, required this.actionStatus, required this.userId, required final  List<FavouriteWallEntity> items, this.sort = FavouriteSort.recentlyAdded, this.sourceFilter, this.query = '', this.completedOperationId = 0, this.failure}): _items = items,super._();
  

@override final  LoadStatus status;
@override final  ActionStatus actionStatus;
@override final  String userId;
 final  List<FavouriteWallEntity> _items;
@override List<FavouriteWallEntity> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@JsonKey() final  FavouriteSort sort;
@override final  WallpaperSource? sourceFilter;
@override@JsonKey() final  String query;
@override@JsonKey() final  int completedOperationId;
@override final  Failure? failure;

/// Create a copy of FavouriteWallsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FavouriteWallsStateCopyWith<_FavouriteWallsState> get copyWith => __$FavouriteWallsStateCopyWithImpl<_FavouriteWallsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FavouriteWallsState&&(identical(other.status, status) || other.status == status)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&(identical(other.userId, userId) || other.userId == userId)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.sort, sort) || other.sort == sort)&&(identical(other.sourceFilter, sourceFilter) || other.sourceFilter == sourceFilter)&&(identical(other.query, query) || other.query == query)&&(identical(other.completedOperationId, completedOperationId) || other.completedOperationId == completedOperationId)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,status,actionStatus,userId,const DeepCollectionEquality().hash(_items),sort,sourceFilter,query,completedOperationId,failure);

@override
String toString() {
  return 'FavouriteWallsState(status: $status, actionStatus: $actionStatus, userId: $userId, items: $items, sort: $sort, sourceFilter: $sourceFilter, query: $query, completedOperationId: $completedOperationId, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$FavouriteWallsStateCopyWith<$Res> implements $FavouriteWallsStateCopyWith<$Res> {
  factory _$FavouriteWallsStateCopyWith(_FavouriteWallsState value, $Res Function(_FavouriteWallsState) _then) = __$FavouriteWallsStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, ActionStatus actionStatus, String userId, List<FavouriteWallEntity> items, FavouriteSort sort, WallpaperSource? sourceFilter, String query, int completedOperationId, Failure? failure
});




}
/// @nodoc
class __$FavouriteWallsStateCopyWithImpl<$Res>
    implements _$FavouriteWallsStateCopyWith<$Res> {
  __$FavouriteWallsStateCopyWithImpl(this._self, this._then);

  final _FavouriteWallsState _self;
  final $Res Function(_FavouriteWallsState) _then;

/// Create a copy of FavouriteWallsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? actionStatus = null,Object? userId = null,Object? items = null,Object? sort = null,Object? sourceFilter = freezed,Object? query = null,Object? completedOperationId = null,Object? failure = freezed,}) {
  return _then(_FavouriteWallsState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,actionStatus: null == actionStatus ? _self.actionStatus : actionStatus // ignore: cast_nullable_to_non_nullable
as ActionStatus,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<FavouriteWallEntity>,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as FavouriteSort,sourceFilter: freezed == sourceFilter ? _self.sourceFilter : sourceFilter // ignore: cast_nullable_to_non_nullable
as WallpaperSource?,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,completedOperationId: null == completedOperationId ? _self.completedOperationId : completedOperationId // ignore: cast_nullable_to_non_nullable
as int,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}


}

// dart format on
