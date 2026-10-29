// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wallpaper_history_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WallpaperHistoryEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WallpaperHistoryEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'WallpaperHistoryEvent()';
}


}

/// @nodoc
class $WallpaperHistoryEventCopyWith<$Res>  {
$WallpaperHistoryEventCopyWith(WallpaperHistoryEvent _, $Res Function(WallpaperHistoryEvent) __);
}


/// Adds pattern-matching-related methods to [WallpaperHistoryEvent].
extension WallpaperHistoryEventPatterns on WallpaperHistoryEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _Cleared value)?  cleared,TResult Function( _ViewedCleared value)?  viewedCleared,TResult Function( _ViewingTurnedOn value)?  viewingTurnedOn,TResult Function( _Removed value)?  removed,TResult Function( _Restored value)?  restored,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _Cleared() when cleared != null:
return cleared(_that);case _ViewedCleared() when viewedCleared != null:
return viewedCleared(_that);case _ViewingTurnedOn() when viewingTurnedOn != null:
return viewingTurnedOn(_that);case _Removed() when removed != null:
return removed(_that);case _Restored() when restored != null:
return restored(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _Cleared value)  cleared,required TResult Function( _ViewedCleared value)  viewedCleared,required TResult Function( _ViewingTurnedOn value)  viewingTurnedOn,required TResult Function( _Removed value)  removed,required TResult Function( _Restored value)  restored,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _Cleared():
return cleared(_that);case _ViewedCleared():
return viewedCleared(_that);case _ViewingTurnedOn():
return viewingTurnedOn(_that);case _Removed():
return removed(_that);case _Restored():
return restored(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _Cleared value)?  cleared,TResult? Function( _ViewedCleared value)?  viewedCleared,TResult? Function( _ViewingTurnedOn value)?  viewingTurnedOn,TResult? Function( _Removed value)?  removed,TResult? Function( _Restored value)?  restored,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _Cleared() when cleared != null:
return cleared(_that);case _ViewedCleared() when viewedCleared != null:
return viewedCleared(_that);case _ViewingTurnedOn() when viewingTurnedOn != null:
return viewingTurnedOn(_that);case _Removed() when removed != null:
return removed(_that);case _Restored() when restored != null:
return restored(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  started,TResult Function()?  cleared,TResult Function()?  viewedCleared,TResult Function()?  viewingTurnedOn,TResult Function( String id)?  removed,TResult Function( AppliedWallpaper item)?  restored,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _Cleared() when cleared != null:
return cleared();case _ViewedCleared() when viewedCleared != null:
return viewedCleared();case _ViewingTurnedOn() when viewingTurnedOn != null:
return viewingTurnedOn();case _Removed() when removed != null:
return removed(_that.id);case _Restored() when restored != null:
return restored(_that.item);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  started,required TResult Function()  cleared,required TResult Function()  viewedCleared,required TResult Function()  viewingTurnedOn,required TResult Function( String id)  removed,required TResult Function( AppliedWallpaper item)  restored,}) {final _that = this;
switch (_that) {
case _Started():
return started();case _Cleared():
return cleared();case _ViewedCleared():
return viewedCleared();case _ViewingTurnedOn():
return viewingTurnedOn();case _Removed():
return removed(_that.id);case _Restored():
return restored(_that.item);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  started,TResult? Function()?  cleared,TResult? Function()?  viewedCleared,TResult? Function()?  viewingTurnedOn,TResult? Function( String id)?  removed,TResult? Function( AppliedWallpaper item)?  restored,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _Cleared() when cleared != null:
return cleared();case _ViewedCleared() when viewedCleared != null:
return viewedCleared();case _ViewingTurnedOn() when viewingTurnedOn != null:
return viewingTurnedOn();case _Removed() when removed != null:
return removed(_that.id);case _Restored() when restored != null:
return restored(_that.item);case _:
  return null;

}
}

}

/// @nodoc


class _Started implements WallpaperHistoryEvent {
  const _Started();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'WallpaperHistoryEvent.started()';
}


}




/// @nodoc


class _Cleared implements WallpaperHistoryEvent {
  const _Cleared();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Cleared);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'WallpaperHistoryEvent.cleared()';
}


}




/// @nodoc


class _ViewedCleared implements WallpaperHistoryEvent {
  const _ViewedCleared();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ViewedCleared);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'WallpaperHistoryEvent.viewedCleared()';
}


}




/// @nodoc


class _ViewingTurnedOn implements WallpaperHistoryEvent {
  const _ViewingTurnedOn();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ViewingTurnedOn);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'WallpaperHistoryEvent.viewingTurnedOn()';
}


}




/// @nodoc


class _Removed implements WallpaperHistoryEvent {
  const _Removed(this.id);
  

 final  String id;

/// Create a copy of WallpaperHistoryEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RemovedCopyWith<_Removed> get copyWith => __$RemovedCopyWithImpl<_Removed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Removed&&(identical(other.id, id) || other.id == id));
}


@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'WallpaperHistoryEvent.removed(id: $id)';
}


}

/// @nodoc
abstract mixin class _$RemovedCopyWith<$Res> implements $WallpaperHistoryEventCopyWith<$Res> {
  factory _$RemovedCopyWith(_Removed value, $Res Function(_Removed) _then) = __$RemovedCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class __$RemovedCopyWithImpl<$Res>
    implements _$RemovedCopyWith<$Res> {
  __$RemovedCopyWithImpl(this._self, this._then);

  final _Removed _self;
  final $Res Function(_Removed) _then;

/// Create a copy of WallpaperHistoryEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(_Removed(
null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _Restored implements WallpaperHistoryEvent {
  const _Restored(this.item);
  

 final  AppliedWallpaper item;

/// Create a copy of WallpaperHistoryEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RestoredCopyWith<_Restored> get copyWith => __$RestoredCopyWithImpl<_Restored>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Restored&&(identical(other.item, item) || other.item == item));
}


@override
int get hashCode => Object.hash(runtimeType,item);

@override
String toString() {
  return 'WallpaperHistoryEvent.restored(item: $item)';
}


}

/// @nodoc
abstract mixin class _$RestoredCopyWith<$Res> implements $WallpaperHistoryEventCopyWith<$Res> {
  factory _$RestoredCopyWith(_Restored value, $Res Function(_Restored) _then) = __$RestoredCopyWithImpl;
@useResult
$Res call({
 AppliedWallpaper item
});




}
/// @nodoc
class __$RestoredCopyWithImpl<$Res>
    implements _$RestoredCopyWith<$Res> {
  __$RestoredCopyWithImpl(this._self, this._then);

  final _Restored _self;
  final $Res Function(_Restored) _then;

/// Create a copy of WallpaperHistoryEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? item = null,}) {
  return _then(_Restored(
null == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as AppliedWallpaper,
  ));
}


}

/// @nodoc
mixin _$WallpaperHistoryState {

 List<AppliedWallpaper> get items; List<HistoryWall> get viewed; bool get viewingHistoryOn;
/// Create a copy of WallpaperHistoryState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WallpaperHistoryStateCopyWith<WallpaperHistoryState> get copyWith => _$WallpaperHistoryStateCopyWithImpl<WallpaperHistoryState>(this as WallpaperHistoryState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WallpaperHistoryState&&const DeepCollectionEquality().equals(other.items, items)&&const DeepCollectionEquality().equals(other.viewed, viewed)&&(identical(other.viewingHistoryOn, viewingHistoryOn) || other.viewingHistoryOn == viewingHistoryOn));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),const DeepCollectionEquality().hash(viewed),viewingHistoryOn);

@override
String toString() {
  return 'WallpaperHistoryState(items: $items, viewed: $viewed, viewingHistoryOn: $viewingHistoryOn)';
}


}

/// @nodoc
abstract mixin class $WallpaperHistoryStateCopyWith<$Res>  {
  factory $WallpaperHistoryStateCopyWith(WallpaperHistoryState value, $Res Function(WallpaperHistoryState) _then) = _$WallpaperHistoryStateCopyWithImpl;
@useResult
$Res call({
 List<AppliedWallpaper> items, List<HistoryWall> viewed, bool viewingHistoryOn
});




}
/// @nodoc
class _$WallpaperHistoryStateCopyWithImpl<$Res>
    implements $WallpaperHistoryStateCopyWith<$Res> {
  _$WallpaperHistoryStateCopyWithImpl(this._self, this._then);

  final WallpaperHistoryState _self;
  final $Res Function(WallpaperHistoryState) _then;

/// Create a copy of WallpaperHistoryState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? viewed = null,Object? viewingHistoryOn = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<AppliedWallpaper>,viewed: null == viewed ? _self.viewed : viewed // ignore: cast_nullable_to_non_nullable
as List<HistoryWall>,viewingHistoryOn: null == viewingHistoryOn ? _self.viewingHistoryOn : viewingHistoryOn // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [WallpaperHistoryState].
extension WallpaperHistoryStatePatterns on WallpaperHistoryState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WallpaperHistoryState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WallpaperHistoryState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WallpaperHistoryState value)  $default,){
final _that = this;
switch (_that) {
case _WallpaperHistoryState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WallpaperHistoryState value)?  $default,){
final _that = this;
switch (_that) {
case _WallpaperHistoryState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AppliedWallpaper> items,  List<HistoryWall> viewed,  bool viewingHistoryOn)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WallpaperHistoryState() when $default != null:
return $default(_that.items,_that.viewed,_that.viewingHistoryOn);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AppliedWallpaper> items,  List<HistoryWall> viewed,  bool viewingHistoryOn)  $default,) {final _that = this;
switch (_that) {
case _WallpaperHistoryState():
return $default(_that.items,_that.viewed,_that.viewingHistoryOn);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AppliedWallpaper> items,  List<HistoryWall> viewed,  bool viewingHistoryOn)?  $default,) {final _that = this;
switch (_that) {
case _WallpaperHistoryState() when $default != null:
return $default(_that.items,_that.viewed,_that.viewingHistoryOn);case _:
  return null;

}
}

}

/// @nodoc


class _WallpaperHistoryState implements WallpaperHistoryState {
  const _WallpaperHistoryState({required final  List<AppliedWallpaper> items, final  List<HistoryWall> viewed = const <HistoryWall>[], this.viewingHistoryOn = true}): _items = items,_viewed = viewed;
  

 final  List<AppliedWallpaper> _items;
@override List<AppliedWallpaper> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

 final  List<HistoryWall> _viewed;
@override@JsonKey() List<HistoryWall> get viewed {
  if (_viewed is EqualUnmodifiableListView) return _viewed;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_viewed);
}

@override@JsonKey() final  bool viewingHistoryOn;

/// Create a copy of WallpaperHistoryState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WallpaperHistoryStateCopyWith<_WallpaperHistoryState> get copyWith => __$WallpaperHistoryStateCopyWithImpl<_WallpaperHistoryState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WallpaperHistoryState&&const DeepCollectionEquality().equals(other._items, _items)&&const DeepCollectionEquality().equals(other._viewed, _viewed)&&(identical(other.viewingHistoryOn, viewingHistoryOn) || other.viewingHistoryOn == viewingHistoryOn));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),const DeepCollectionEquality().hash(_viewed),viewingHistoryOn);

@override
String toString() {
  return 'WallpaperHistoryState(items: $items, viewed: $viewed, viewingHistoryOn: $viewingHistoryOn)';
}


}

/// @nodoc
abstract mixin class _$WallpaperHistoryStateCopyWith<$Res> implements $WallpaperHistoryStateCopyWith<$Res> {
  factory _$WallpaperHistoryStateCopyWith(_WallpaperHistoryState value, $Res Function(_WallpaperHistoryState) _then) = __$WallpaperHistoryStateCopyWithImpl;
@override @useResult
$Res call({
 List<AppliedWallpaper> items, List<HistoryWall> viewed, bool viewingHistoryOn
});




}
/// @nodoc
class __$WallpaperHistoryStateCopyWithImpl<$Res>
    implements _$WallpaperHistoryStateCopyWith<$Res> {
  __$WallpaperHistoryStateCopyWithImpl(this._self, this._then);

  final _WallpaperHistoryState _self;
  final $Res Function(_WallpaperHistoryState) _then;

/// Create a copy of WallpaperHistoryState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? viewed = null,Object? viewingHistoryOn = null,}) {
  return _then(_WallpaperHistoryState(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<AppliedWallpaper>,viewed: null == viewed ? _self._viewed : viewed // ignore: cast_nullable_to_non_nullable
as List<HistoryWall>,viewingHistoryOn: null == viewingHistoryOn ? _self.viewingHistoryOn : viewingHistoryOn // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
