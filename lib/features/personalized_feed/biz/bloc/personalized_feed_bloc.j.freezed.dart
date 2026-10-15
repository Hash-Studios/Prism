// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'personalized_feed_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PersonalizedFeedEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PersonalizedFeedEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PersonalizedFeedEvent()';
}


}

/// @nodoc
class $PersonalizedFeedEventCopyWith<$Res>  {
$PersonalizedFeedEventCopyWith(PersonalizedFeedEvent _, $Res Function(PersonalizedFeedEvent) __);
}


/// Adds pattern-matching-related methods to [PersonalizedFeedEvent].
extension PersonalizedFeedEventPatterns on PersonalizedFeedEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _RefreshRequested value)?  refreshRequested,TResult Function( _FetchMoreRequested value)?  fetchMoreRequested,TResult Function( _LessLikeThisRequested value)?  lessLikeThisRequested,TResult Function( _LessLikeThisUndone value)?  lessLikeThisUndone,TResult Function( _SettingsChanged value)?  settingsChanged,TResult Function( _ChipSelected value)?  chipSelected,TResult Function( _TilesSeen value)?  tilesSeen,TResult Function( _BlockedCreatorsChanged value)?  blockedCreatorsChanged,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _RefreshRequested() when refreshRequested != null:
return refreshRequested(_that);case _FetchMoreRequested() when fetchMoreRequested != null:
return fetchMoreRequested(_that);case _LessLikeThisRequested() when lessLikeThisRequested != null:
return lessLikeThisRequested(_that);case _LessLikeThisUndone() when lessLikeThisUndone != null:
return lessLikeThisUndone(_that);case _SettingsChanged() when settingsChanged != null:
return settingsChanged(_that);case _ChipSelected() when chipSelected != null:
return chipSelected(_that);case _TilesSeen() when tilesSeen != null:
return tilesSeen(_that);case _BlockedCreatorsChanged() when blockedCreatorsChanged != null:
return blockedCreatorsChanged(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _RefreshRequested value)  refreshRequested,required TResult Function( _FetchMoreRequested value)  fetchMoreRequested,required TResult Function( _LessLikeThisRequested value)  lessLikeThisRequested,required TResult Function( _LessLikeThisUndone value)  lessLikeThisUndone,required TResult Function( _SettingsChanged value)  settingsChanged,required TResult Function( _ChipSelected value)  chipSelected,required TResult Function( _TilesSeen value)  tilesSeen,required TResult Function( _BlockedCreatorsChanged value)  blockedCreatorsChanged,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _RefreshRequested():
return refreshRequested(_that);case _FetchMoreRequested():
return fetchMoreRequested(_that);case _LessLikeThisRequested():
return lessLikeThisRequested(_that);case _LessLikeThisUndone():
return lessLikeThisUndone(_that);case _SettingsChanged():
return settingsChanged(_that);case _ChipSelected():
return chipSelected(_that);case _TilesSeen():
return tilesSeen(_that);case _BlockedCreatorsChanged():
return blockedCreatorsChanged(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _RefreshRequested value)?  refreshRequested,TResult? Function( _FetchMoreRequested value)?  fetchMoreRequested,TResult? Function( _LessLikeThisRequested value)?  lessLikeThisRequested,TResult? Function( _LessLikeThisUndone value)?  lessLikeThisUndone,TResult? Function( _SettingsChanged value)?  settingsChanged,TResult? Function( _ChipSelected value)?  chipSelected,TResult? Function( _TilesSeen value)?  tilesSeen,TResult? Function( _BlockedCreatorsChanged value)?  blockedCreatorsChanged,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _RefreshRequested() when refreshRequested != null:
return refreshRequested(_that);case _FetchMoreRequested() when fetchMoreRequested != null:
return fetchMoreRequested(_that);case _LessLikeThisRequested() when lessLikeThisRequested != null:
return lessLikeThisRequested(_that);case _LessLikeThisUndone() when lessLikeThisUndone != null:
return lessLikeThisUndone(_that);case _SettingsChanged() when settingsChanged != null:
return settingsChanged(_that);case _ChipSelected() when chipSelected != null:
return chipSelected(_that);case _TilesSeen() when tilesSeen != null:
return tilesSeen(_that);case _BlockedCreatorsChanged() when blockedCreatorsChanged != null:
return blockedCreatorsChanged(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  started,TResult Function()?  refreshRequested,TResult Function()?  fetchMoreRequested,TResult Function( FeedItemEntity item)?  lessLikeThisRequested,TResult Function( FeedItemEntity item,  int index)?  lessLikeThisUndone,TResult Function()?  settingsChanged,TResult Function( HomeFeedChip chip)?  chipSelected,TResult Function( List<String> keys)?  tilesSeen,TResult Function( Set<String> blocked)?  blockedCreatorsChanged,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _RefreshRequested() when refreshRequested != null:
return refreshRequested();case _FetchMoreRequested() when fetchMoreRequested != null:
return fetchMoreRequested();case _LessLikeThisRequested() when lessLikeThisRequested != null:
return lessLikeThisRequested(_that.item);case _LessLikeThisUndone() when lessLikeThisUndone != null:
return lessLikeThisUndone(_that.item,_that.index);case _SettingsChanged() when settingsChanged != null:
return settingsChanged();case _ChipSelected() when chipSelected != null:
return chipSelected(_that.chip);case _TilesSeen() when tilesSeen != null:
return tilesSeen(_that.keys);case _BlockedCreatorsChanged() when blockedCreatorsChanged != null:
return blockedCreatorsChanged(_that.blocked);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  started,required TResult Function()  refreshRequested,required TResult Function()  fetchMoreRequested,required TResult Function( FeedItemEntity item)  lessLikeThisRequested,required TResult Function( FeedItemEntity item,  int index)  lessLikeThisUndone,required TResult Function()  settingsChanged,required TResult Function( HomeFeedChip chip)  chipSelected,required TResult Function( List<String> keys)  tilesSeen,required TResult Function( Set<String> blocked)  blockedCreatorsChanged,}) {final _that = this;
switch (_that) {
case _Started():
return started();case _RefreshRequested():
return refreshRequested();case _FetchMoreRequested():
return fetchMoreRequested();case _LessLikeThisRequested():
return lessLikeThisRequested(_that.item);case _LessLikeThisUndone():
return lessLikeThisUndone(_that.item,_that.index);case _SettingsChanged():
return settingsChanged();case _ChipSelected():
return chipSelected(_that.chip);case _TilesSeen():
return tilesSeen(_that.keys);case _BlockedCreatorsChanged():
return blockedCreatorsChanged(_that.blocked);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  started,TResult? Function()?  refreshRequested,TResult? Function()?  fetchMoreRequested,TResult? Function( FeedItemEntity item)?  lessLikeThisRequested,TResult? Function( FeedItemEntity item,  int index)?  lessLikeThisUndone,TResult? Function()?  settingsChanged,TResult? Function( HomeFeedChip chip)?  chipSelected,TResult? Function( List<String> keys)?  tilesSeen,TResult? Function( Set<String> blocked)?  blockedCreatorsChanged,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _RefreshRequested() when refreshRequested != null:
return refreshRequested();case _FetchMoreRequested() when fetchMoreRequested != null:
return fetchMoreRequested();case _LessLikeThisRequested() when lessLikeThisRequested != null:
return lessLikeThisRequested(_that.item);case _LessLikeThisUndone() when lessLikeThisUndone != null:
return lessLikeThisUndone(_that.item,_that.index);case _SettingsChanged() when settingsChanged != null:
return settingsChanged();case _ChipSelected() when chipSelected != null:
return chipSelected(_that.chip);case _TilesSeen() when tilesSeen != null:
return tilesSeen(_that.keys);case _BlockedCreatorsChanged() when blockedCreatorsChanged != null:
return blockedCreatorsChanged(_that.blocked);case _:
  return null;

}
}

}

/// @nodoc


class _Started implements PersonalizedFeedEvent {
  const _Started();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PersonalizedFeedEvent.started()';
}


}




/// @nodoc


class _RefreshRequested implements PersonalizedFeedEvent {
  const _RefreshRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefreshRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PersonalizedFeedEvent.refreshRequested()';
}


}




/// @nodoc


class _FetchMoreRequested implements PersonalizedFeedEvent {
  const _FetchMoreRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FetchMoreRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PersonalizedFeedEvent.fetchMoreRequested()';
}


}




/// @nodoc


class _LessLikeThisRequested implements PersonalizedFeedEvent {
  const _LessLikeThisRequested(this.item);
  

 final  FeedItemEntity item;

/// Create a copy of PersonalizedFeedEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LessLikeThisRequestedCopyWith<_LessLikeThisRequested> get copyWith => __$LessLikeThisRequestedCopyWithImpl<_LessLikeThisRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LessLikeThisRequested&&(identical(other.item, item) || other.item == item));
}


@override
int get hashCode => Object.hash(runtimeType,item);

@override
String toString() {
  return 'PersonalizedFeedEvent.lessLikeThisRequested(item: $item)';
}


}

/// @nodoc
abstract mixin class _$LessLikeThisRequestedCopyWith<$Res> implements $PersonalizedFeedEventCopyWith<$Res> {
  factory _$LessLikeThisRequestedCopyWith(_LessLikeThisRequested value, $Res Function(_LessLikeThisRequested) _then) = __$LessLikeThisRequestedCopyWithImpl;
@useResult
$Res call({
 FeedItemEntity item
});


$FeedItemEntityCopyWith<$Res> get item;

}
/// @nodoc
class __$LessLikeThisRequestedCopyWithImpl<$Res>
    implements _$LessLikeThisRequestedCopyWith<$Res> {
  __$LessLikeThisRequestedCopyWithImpl(this._self, this._then);

  final _LessLikeThisRequested _self;
  final $Res Function(_LessLikeThisRequested) _then;

/// Create a copy of PersonalizedFeedEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? item = null,}) {
  return _then(_LessLikeThisRequested(
null == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as FeedItemEntity,
  ));
}

/// Create a copy of PersonalizedFeedEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FeedItemEntityCopyWith<$Res> get item {
  
  return $FeedItemEntityCopyWith<$Res>(_self.item, (value) {
    return _then(_self.copyWith(item: value));
  });
}
}

/// @nodoc


class _LessLikeThisUndone implements PersonalizedFeedEvent {
  const _LessLikeThisUndone(this.item, {required this.index});
  

 final  FeedItemEntity item;
 final  int index;

/// Create a copy of PersonalizedFeedEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LessLikeThisUndoneCopyWith<_LessLikeThisUndone> get copyWith => __$LessLikeThisUndoneCopyWithImpl<_LessLikeThisUndone>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LessLikeThisUndone&&(identical(other.item, item) || other.item == item)&&(identical(other.index, index) || other.index == index));
}


@override
int get hashCode => Object.hash(runtimeType,item,index);

@override
String toString() {
  return 'PersonalizedFeedEvent.lessLikeThisUndone(item: $item, index: $index)';
}


}

/// @nodoc
abstract mixin class _$LessLikeThisUndoneCopyWith<$Res> implements $PersonalizedFeedEventCopyWith<$Res> {
  factory _$LessLikeThisUndoneCopyWith(_LessLikeThisUndone value, $Res Function(_LessLikeThisUndone) _then) = __$LessLikeThisUndoneCopyWithImpl;
@useResult
$Res call({
 FeedItemEntity item, int index
});


$FeedItemEntityCopyWith<$Res> get item;

}
/// @nodoc
class __$LessLikeThisUndoneCopyWithImpl<$Res>
    implements _$LessLikeThisUndoneCopyWith<$Res> {
  __$LessLikeThisUndoneCopyWithImpl(this._self, this._then);

  final _LessLikeThisUndone _self;
  final $Res Function(_LessLikeThisUndone) _then;

/// Create a copy of PersonalizedFeedEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? item = null,Object? index = null,}) {
  return _then(_LessLikeThisUndone(
null == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as FeedItemEntity,index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of PersonalizedFeedEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FeedItemEntityCopyWith<$Res> get item {
  
  return $FeedItemEntityCopyWith<$Res>(_self.item, (value) {
    return _then(_self.copyWith(item: value));
  });
}
}

/// @nodoc


class _SettingsChanged implements PersonalizedFeedEvent {
  const _SettingsChanged();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SettingsChanged);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PersonalizedFeedEvent.settingsChanged()';
}


}




/// @nodoc


class _ChipSelected implements PersonalizedFeedEvent {
  const _ChipSelected(this.chip);
  

 final  HomeFeedChip chip;

/// Create a copy of PersonalizedFeedEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChipSelectedCopyWith<_ChipSelected> get copyWith => __$ChipSelectedCopyWithImpl<_ChipSelected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChipSelected&&(identical(other.chip, chip) || other.chip == chip));
}


@override
int get hashCode => Object.hash(runtimeType,chip);

@override
String toString() {
  return 'PersonalizedFeedEvent.chipSelected(chip: $chip)';
}


}

/// @nodoc
abstract mixin class _$ChipSelectedCopyWith<$Res> implements $PersonalizedFeedEventCopyWith<$Res> {
  factory _$ChipSelectedCopyWith(_ChipSelected value, $Res Function(_ChipSelected) _then) = __$ChipSelectedCopyWithImpl;
@useResult
$Res call({
 HomeFeedChip chip
});




}
/// @nodoc
class __$ChipSelectedCopyWithImpl<$Res>
    implements _$ChipSelectedCopyWith<$Res> {
  __$ChipSelectedCopyWithImpl(this._self, this._then);

  final _ChipSelected _self;
  final $Res Function(_ChipSelected) _then;

/// Create a copy of PersonalizedFeedEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? chip = null,}) {
  return _then(_ChipSelected(
null == chip ? _self.chip : chip // ignore: cast_nullable_to_non_nullable
as HomeFeedChip,
  ));
}


}

/// @nodoc


class _TilesSeen implements PersonalizedFeedEvent {
  const _TilesSeen(final  List<String> keys): _keys = keys;
  

 final  List<String> _keys;
 List<String> get keys {
  if (_keys is EqualUnmodifiableListView) return _keys;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_keys);
}


/// Create a copy of PersonalizedFeedEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TilesSeenCopyWith<_TilesSeen> get copyWith => __$TilesSeenCopyWithImpl<_TilesSeen>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TilesSeen&&const DeepCollectionEquality().equals(other._keys, _keys));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_keys));

@override
String toString() {
  return 'PersonalizedFeedEvent.tilesSeen(keys: $keys)';
}


}

/// @nodoc
abstract mixin class _$TilesSeenCopyWith<$Res> implements $PersonalizedFeedEventCopyWith<$Res> {
  factory _$TilesSeenCopyWith(_TilesSeen value, $Res Function(_TilesSeen) _then) = __$TilesSeenCopyWithImpl;
@useResult
$Res call({
 List<String> keys
});




}
/// @nodoc
class __$TilesSeenCopyWithImpl<$Res>
    implements _$TilesSeenCopyWith<$Res> {
  __$TilesSeenCopyWithImpl(this._self, this._then);

  final _TilesSeen _self;
  final $Res Function(_TilesSeen) _then;

/// Create a copy of PersonalizedFeedEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? keys = null,}) {
  return _then(_TilesSeen(
null == keys ? _self._keys : keys // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc


class _BlockedCreatorsChanged implements PersonalizedFeedEvent {
  const _BlockedCreatorsChanged({required final  Set<String> blocked}): _blocked = blocked;
  

 final  Set<String> _blocked;
 Set<String> get blocked {
  if (_blocked is EqualUnmodifiableSetView) return _blocked;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_blocked);
}


/// Create a copy of PersonalizedFeedEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BlockedCreatorsChangedCopyWith<_BlockedCreatorsChanged> get copyWith => __$BlockedCreatorsChangedCopyWithImpl<_BlockedCreatorsChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BlockedCreatorsChanged&&const DeepCollectionEquality().equals(other._blocked, _blocked));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_blocked));

@override
String toString() {
  return 'PersonalizedFeedEvent.blockedCreatorsChanged(blocked: $blocked)';
}


}

/// @nodoc
abstract mixin class _$BlockedCreatorsChangedCopyWith<$Res> implements $PersonalizedFeedEventCopyWith<$Res> {
  factory _$BlockedCreatorsChangedCopyWith(_BlockedCreatorsChanged value, $Res Function(_BlockedCreatorsChanged) _then) = __$BlockedCreatorsChangedCopyWithImpl;
@useResult
$Res call({
 Set<String> blocked
});




}
/// @nodoc
class __$BlockedCreatorsChangedCopyWithImpl<$Res>
    implements _$BlockedCreatorsChangedCopyWith<$Res> {
  __$BlockedCreatorsChangedCopyWithImpl(this._self, this._then);

  final _BlockedCreatorsChanged _self;
  final $Res Function(_BlockedCreatorsChanged) _then;

/// Create a copy of PersonalizedFeedEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? blocked = null,}) {
  return _then(_BlockedCreatorsChanged(
blocked: null == blocked ? _self._blocked : blocked // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}


}

/// @nodoc
mixin _$PersonalizedFeedState {

 LoadStatus get status; ActionStatus get actionStatus; List<FeedItemEntity> get items; bool get hasMore; bool get isFetchingMore; int get page; List<String> get seenKeys; HomeFeedChip get chip;/// Cached items are on screen while the fresh page loads.
 bool get isRefreshing;/// The last refresh failed. Items from before it stay on screen.
 bool get refreshFailed; Failure? get failure;
/// Create a copy of PersonalizedFeedState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PersonalizedFeedStateCopyWith<PersonalizedFeedState> get copyWith => _$PersonalizedFeedStateCopyWithImpl<PersonalizedFeedState>(this as PersonalizedFeedState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PersonalizedFeedState&&(identical(other.status, status) || other.status == status)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.isFetchingMore, isFetchingMore) || other.isFetchingMore == isFetchingMore)&&(identical(other.page, page) || other.page == page)&&const DeepCollectionEquality().equals(other.seenKeys, seenKeys)&&(identical(other.chip, chip) || other.chip == chip)&&(identical(other.isRefreshing, isRefreshing) || other.isRefreshing == isRefreshing)&&(identical(other.refreshFailed, refreshFailed) || other.refreshFailed == refreshFailed)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,status,actionStatus,const DeepCollectionEquality().hash(items),hasMore,isFetchingMore,page,const DeepCollectionEquality().hash(seenKeys),chip,isRefreshing,refreshFailed,failure);

@override
String toString() {
  return 'PersonalizedFeedState(status: $status, actionStatus: $actionStatus, items: $items, hasMore: $hasMore, isFetchingMore: $isFetchingMore, page: $page, seenKeys: $seenKeys, chip: $chip, isRefreshing: $isRefreshing, refreshFailed: $refreshFailed, failure: $failure)';
}


}

/// @nodoc
abstract mixin class $PersonalizedFeedStateCopyWith<$Res>  {
  factory $PersonalizedFeedStateCopyWith(PersonalizedFeedState value, $Res Function(PersonalizedFeedState) _then) = _$PersonalizedFeedStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, ActionStatus actionStatus, List<FeedItemEntity> items, bool hasMore, bool isFetchingMore, int page, List<String> seenKeys, HomeFeedChip chip, bool isRefreshing, bool refreshFailed, Failure? failure
});




}
/// @nodoc
class _$PersonalizedFeedStateCopyWithImpl<$Res>
    implements $PersonalizedFeedStateCopyWith<$Res> {
  _$PersonalizedFeedStateCopyWithImpl(this._self, this._then);

  final PersonalizedFeedState _self;
  final $Res Function(PersonalizedFeedState) _then;

/// Create a copy of PersonalizedFeedState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? actionStatus = null,Object? items = null,Object? hasMore = null,Object? isFetchingMore = null,Object? page = null,Object? seenKeys = null,Object? chip = null,Object? isRefreshing = null,Object? refreshFailed = null,Object? failure = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,actionStatus: null == actionStatus ? _self.actionStatus : actionStatus // ignore: cast_nullable_to_non_nullable
as ActionStatus,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<FeedItemEntity>,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,isFetchingMore: null == isFetchingMore ? _self.isFetchingMore : isFetchingMore // ignore: cast_nullable_to_non_nullable
as bool,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,seenKeys: null == seenKeys ? _self.seenKeys : seenKeys // ignore: cast_nullable_to_non_nullable
as List<String>,chip: null == chip ? _self.chip : chip // ignore: cast_nullable_to_non_nullable
as HomeFeedChip,isRefreshing: null == isRefreshing ? _self.isRefreshing : isRefreshing // ignore: cast_nullable_to_non_nullable
as bool,refreshFailed: null == refreshFailed ? _self.refreshFailed : refreshFailed // ignore: cast_nullable_to_non_nullable
as bool,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}

}


/// Adds pattern-matching-related methods to [PersonalizedFeedState].
extension PersonalizedFeedStatePatterns on PersonalizedFeedState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PersonalizedFeedState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PersonalizedFeedState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PersonalizedFeedState value)  $default,){
final _that = this;
switch (_that) {
case _PersonalizedFeedState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PersonalizedFeedState value)?  $default,){
final _that = this;
switch (_that) {
case _PersonalizedFeedState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  ActionStatus actionStatus,  List<FeedItemEntity> items,  bool hasMore,  bool isFetchingMore,  int page,  List<String> seenKeys,  HomeFeedChip chip,  bool isRefreshing,  bool refreshFailed,  Failure? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PersonalizedFeedState() when $default != null:
return $default(_that.status,_that.actionStatus,_that.items,_that.hasMore,_that.isFetchingMore,_that.page,_that.seenKeys,_that.chip,_that.isRefreshing,_that.refreshFailed,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  ActionStatus actionStatus,  List<FeedItemEntity> items,  bool hasMore,  bool isFetchingMore,  int page,  List<String> seenKeys,  HomeFeedChip chip,  bool isRefreshing,  bool refreshFailed,  Failure? failure)  $default,) {final _that = this;
switch (_that) {
case _PersonalizedFeedState():
return $default(_that.status,_that.actionStatus,_that.items,_that.hasMore,_that.isFetchingMore,_that.page,_that.seenKeys,_that.chip,_that.isRefreshing,_that.refreshFailed,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  ActionStatus actionStatus,  List<FeedItemEntity> items,  bool hasMore,  bool isFetchingMore,  int page,  List<String> seenKeys,  HomeFeedChip chip,  bool isRefreshing,  bool refreshFailed,  Failure? failure)?  $default,) {final _that = this;
switch (_that) {
case _PersonalizedFeedState() when $default != null:
return $default(_that.status,_that.actionStatus,_that.items,_that.hasMore,_that.isFetchingMore,_that.page,_that.seenKeys,_that.chip,_that.isRefreshing,_that.refreshFailed,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _PersonalizedFeedState implements PersonalizedFeedState {
  const _PersonalizedFeedState({required this.status, required this.actionStatus, required final  List<FeedItemEntity> items, required this.hasMore, required this.isFetchingMore, required this.page, required final  List<String> seenKeys, required this.chip, required this.isRefreshing, required this.refreshFailed, this.failure}): _items = items,_seenKeys = seenKeys;
  

@override final  LoadStatus status;
@override final  ActionStatus actionStatus;
 final  List<FeedItemEntity> _items;
@override List<FeedItemEntity> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  bool hasMore;
@override final  bool isFetchingMore;
@override final  int page;
 final  List<String> _seenKeys;
@override List<String> get seenKeys {
  if (_seenKeys is EqualUnmodifiableListView) return _seenKeys;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_seenKeys);
}

@override final  HomeFeedChip chip;
/// Cached items are on screen while the fresh page loads.
@override final  bool isRefreshing;
/// The last refresh failed. Items from before it stay on screen.
@override final  bool refreshFailed;
@override final  Failure? failure;

/// Create a copy of PersonalizedFeedState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PersonalizedFeedStateCopyWith<_PersonalizedFeedState> get copyWith => __$PersonalizedFeedStateCopyWithImpl<_PersonalizedFeedState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PersonalizedFeedState&&(identical(other.status, status) || other.status == status)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.isFetchingMore, isFetchingMore) || other.isFetchingMore == isFetchingMore)&&(identical(other.page, page) || other.page == page)&&const DeepCollectionEquality().equals(other._seenKeys, _seenKeys)&&(identical(other.chip, chip) || other.chip == chip)&&(identical(other.isRefreshing, isRefreshing) || other.isRefreshing == isRefreshing)&&(identical(other.refreshFailed, refreshFailed) || other.refreshFailed == refreshFailed)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,status,actionStatus,const DeepCollectionEquality().hash(_items),hasMore,isFetchingMore,page,const DeepCollectionEquality().hash(_seenKeys),chip,isRefreshing,refreshFailed,failure);

@override
String toString() {
  return 'PersonalizedFeedState(status: $status, actionStatus: $actionStatus, items: $items, hasMore: $hasMore, isFetchingMore: $isFetchingMore, page: $page, seenKeys: $seenKeys, chip: $chip, isRefreshing: $isRefreshing, refreshFailed: $refreshFailed, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$PersonalizedFeedStateCopyWith<$Res> implements $PersonalizedFeedStateCopyWith<$Res> {
  factory _$PersonalizedFeedStateCopyWith(_PersonalizedFeedState value, $Res Function(_PersonalizedFeedState) _then) = __$PersonalizedFeedStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, ActionStatus actionStatus, List<FeedItemEntity> items, bool hasMore, bool isFetchingMore, int page, List<String> seenKeys, HomeFeedChip chip, bool isRefreshing, bool refreshFailed, Failure? failure
});




}
/// @nodoc
class __$PersonalizedFeedStateCopyWithImpl<$Res>
    implements _$PersonalizedFeedStateCopyWith<$Res> {
  __$PersonalizedFeedStateCopyWithImpl(this._self, this._then);

  final _PersonalizedFeedState _self;
  final $Res Function(_PersonalizedFeedState) _then;

/// Create a copy of PersonalizedFeedState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? actionStatus = null,Object? items = null,Object? hasMore = null,Object? isFetchingMore = null,Object? page = null,Object? seenKeys = null,Object? chip = null,Object? isRefreshing = null,Object? refreshFailed = null,Object? failure = freezed,}) {
  return _then(_PersonalizedFeedState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,actionStatus: null == actionStatus ? _self.actionStatus : actionStatus // ignore: cast_nullable_to_non_nullable
as ActionStatus,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<FeedItemEntity>,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,isFetchingMore: null == isFetchingMore ? _self.isFetchingMore : isFetchingMore // ignore: cast_nullable_to_non_nullable
as bool,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,seenKeys: null == seenKeys ? _self._seenKeys : seenKeys // ignore: cast_nullable_to_non_nullable
as List<String>,chip: null == chip ? _self.chip : chip // ignore: cast_nullable_to_non_nullable
as HomeFeedChip,isRefreshing: null == isRefreshing ? _self.isRefreshing : isRefreshing // ignore: cast_nullable_to_non_nullable
as bool,refreshFailed: null == refreshFailed ? _self.refreshFailed : refreshFailed // ignore: cast_nullable_to_non_nullable
as bool,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}


}

// dart format on
