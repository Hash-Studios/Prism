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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _Cleared value)?  cleared,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _Cleared() when cleared != null:
return cleared(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _Cleared value)  cleared,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _Cleared():
return cleared(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _Cleared value)?  cleared,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _Cleared() when cleared != null:
return cleared(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  started,TResult Function()?  cleared,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _Cleared() when cleared != null:
return cleared();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  started,required TResult Function()  cleared,}) {final _that = this;
switch (_that) {
case _Started():
return started();case _Cleared():
return cleared();case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  started,TResult? Function()?  cleared,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _Cleared() when cleared != null:
return cleared();case _:
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
mixin _$WallpaperHistoryState {

 List<AppliedWallpaper> get items;
/// Create a copy of WallpaperHistoryState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WallpaperHistoryStateCopyWith<WallpaperHistoryState> get copyWith => _$WallpaperHistoryStateCopyWithImpl<WallpaperHistoryState>(this as WallpaperHistoryState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WallpaperHistoryState&&const DeepCollectionEquality().equals(other.items, items));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'WallpaperHistoryState(items: $items)';
}


}

/// @nodoc
abstract mixin class $WallpaperHistoryStateCopyWith<$Res>  {
  factory $WallpaperHistoryStateCopyWith(WallpaperHistoryState value, $Res Function(WallpaperHistoryState) _then) = _$WallpaperHistoryStateCopyWithImpl;
@useResult
$Res call({
 List<AppliedWallpaper> items
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
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<AppliedWallpaper>,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<AppliedWallpaper> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WallpaperHistoryState() when $default != null:
return $default(_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<AppliedWallpaper> items)  $default,) {final _that = this;
switch (_that) {
case _WallpaperHistoryState():
return $default(_that.items);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<AppliedWallpaper> items)?  $default,) {final _that = this;
switch (_that) {
case _WallpaperHistoryState() when $default != null:
return $default(_that.items);case _:
  return null;

}
}

}

/// @nodoc


class _WallpaperHistoryState implements WallpaperHistoryState {
  const _WallpaperHistoryState({required final  List<AppliedWallpaper> items}): _items = items;
  

 final  List<AppliedWallpaper> _items;
@override List<AppliedWallpaper> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of WallpaperHistoryState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WallpaperHistoryStateCopyWith<_WallpaperHistoryState> get copyWith => __$WallpaperHistoryStateCopyWithImpl<_WallpaperHistoryState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WallpaperHistoryState&&const DeepCollectionEquality().equals(other._items, _items));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'WallpaperHistoryState(items: $items)';
}


}

/// @nodoc
abstract mixin class _$WallpaperHistoryStateCopyWith<$Res> implements $WallpaperHistoryStateCopyWith<$Res> {
  factory _$WallpaperHistoryStateCopyWith(_WallpaperHistoryState value, $Res Function(_WallpaperHistoryState) _then) = __$WallpaperHistoryStateCopyWithImpl;
@override @useResult
$Res call({
 List<AppliedWallpaper> items
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
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,}) {
  return _then(_WallpaperHistoryState(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<AppliedWallpaper>,
  ));
}


}

// dart format on
