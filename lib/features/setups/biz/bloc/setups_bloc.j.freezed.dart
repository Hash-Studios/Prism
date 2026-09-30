// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'setups_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SetupsEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SetupsEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SetupsEvent()';
}


}

/// @nodoc
class $SetupsEventCopyWith<$Res>  {
$SetupsEventCopyWith(SetupsEvent _, $Res Function(SetupsEvent) __);
}


/// Adds pattern-matching-related methods to [SetupsEvent].
extension SetupsEventPatterns on SetupsEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _FetchMoreRequested value)?  fetchMoreRequested,TResult Function( _BlockedCreatorsChanged value)?  blockedCreatorsChanged,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _FetchMoreRequested() when fetchMoreRequested != null:
return fetchMoreRequested(_that);case _BlockedCreatorsChanged() when blockedCreatorsChanged != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _FetchMoreRequested value)  fetchMoreRequested,required TResult Function( _BlockedCreatorsChanged value)  blockedCreatorsChanged,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _FetchMoreRequested():
return fetchMoreRequested(_that);case _BlockedCreatorsChanged():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _FetchMoreRequested value)?  fetchMoreRequested,TResult? Function( _BlockedCreatorsChanged value)?  blockedCreatorsChanged,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _FetchMoreRequested() when fetchMoreRequested != null:
return fetchMoreRequested(_that);case _BlockedCreatorsChanged() when blockedCreatorsChanged != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  started,TResult Function()?  fetchMoreRequested,TResult Function( Set<String> blocked)?  blockedCreatorsChanged,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _FetchMoreRequested() when fetchMoreRequested != null:
return fetchMoreRequested();case _BlockedCreatorsChanged() when blockedCreatorsChanged != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  started,required TResult Function()  fetchMoreRequested,required TResult Function( Set<String> blocked)  blockedCreatorsChanged,}) {final _that = this;
switch (_that) {
case _Started():
return started();case _FetchMoreRequested():
return fetchMoreRequested();case _BlockedCreatorsChanged():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  started,TResult? Function()?  fetchMoreRequested,TResult? Function( Set<String> blocked)?  blockedCreatorsChanged,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _FetchMoreRequested() when fetchMoreRequested != null:
return fetchMoreRequested();case _BlockedCreatorsChanged() when blockedCreatorsChanged != null:
return blockedCreatorsChanged(_that.blocked);case _:
  return null;

}
}

}

/// @nodoc


class _Started implements SetupsEvent {
  const _Started();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SetupsEvent.started()';
}


}




/// @nodoc


class _FetchMoreRequested implements SetupsEvent {
  const _FetchMoreRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FetchMoreRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SetupsEvent.fetchMoreRequested()';
}


}




/// @nodoc


class _BlockedCreatorsChanged implements SetupsEvent {
  const _BlockedCreatorsChanged(final  Set<String> blocked): _blocked = blocked;
  

 final  Set<String> _blocked;
 Set<String> get blocked {
  if (_blocked is EqualUnmodifiableSetView) return _blocked;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_blocked);
}


/// Create a copy of SetupsEvent
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
  return 'SetupsEvent.blockedCreatorsChanged(blocked: $blocked)';
}


}

/// @nodoc
abstract mixin class _$BlockedCreatorsChangedCopyWith<$Res> implements $SetupsEventCopyWith<$Res> {
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

/// Create a copy of SetupsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? blocked = null,}) {
  return _then(_BlockedCreatorsChanged(
null == blocked ? _self._blocked : blocked // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}


}

/// @nodoc
mixin _$SetupsState {

 LoadStatus get status; List<SetupEntity> get items; bool get hasMore; bool get isFetchingMore;
/// Create a copy of SetupsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SetupsStateCopyWith<SetupsState> get copyWith => _$SetupsStateCopyWithImpl<SetupsState>(this as SetupsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SetupsState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.isFetchingMore, isFetchingMore) || other.isFetchingMore == isFetchingMore));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(items),hasMore,isFetchingMore);

@override
String toString() {
  return 'SetupsState(status: $status, items: $items, hasMore: $hasMore, isFetchingMore: $isFetchingMore)';
}


}

/// @nodoc
abstract mixin class $SetupsStateCopyWith<$Res>  {
  factory $SetupsStateCopyWith(SetupsState value, $Res Function(SetupsState) _then) = _$SetupsStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, List<SetupEntity> items, bool hasMore, bool isFetchingMore
});




}
/// @nodoc
class _$SetupsStateCopyWithImpl<$Res>
    implements $SetupsStateCopyWith<$Res> {
  _$SetupsStateCopyWithImpl(this._self, this._then);

  final SetupsState _self;
  final $Res Function(SetupsState) _then;

/// Create a copy of SetupsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? items = null,Object? hasMore = null,Object? isFetchingMore = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<SetupEntity>,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,isFetchingMore: null == isFetchingMore ? _self.isFetchingMore : isFetchingMore // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SetupsState].
extension SetupsStatePatterns on SetupsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SetupsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SetupsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SetupsState value)  $default,){
final _that = this;
switch (_that) {
case _SetupsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SetupsState value)?  $default,){
final _that = this;
switch (_that) {
case _SetupsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  List<SetupEntity> items,  bool hasMore,  bool isFetchingMore)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SetupsState() when $default != null:
return $default(_that.status,_that.items,_that.hasMore,_that.isFetchingMore);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  List<SetupEntity> items,  bool hasMore,  bool isFetchingMore)  $default,) {final _that = this;
switch (_that) {
case _SetupsState():
return $default(_that.status,_that.items,_that.hasMore,_that.isFetchingMore);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  List<SetupEntity> items,  bool hasMore,  bool isFetchingMore)?  $default,) {final _that = this;
switch (_that) {
case _SetupsState() when $default != null:
return $default(_that.status,_that.items,_that.hasMore,_that.isFetchingMore);case _:
  return null;

}
}

}

/// @nodoc


class _SetupsState implements SetupsState {
  const _SetupsState({required this.status, required final  List<SetupEntity> items, required this.hasMore, required this.isFetchingMore}): _items = items;
  

@override final  LoadStatus status;
 final  List<SetupEntity> _items;
@override List<SetupEntity> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  bool hasMore;
@override final  bool isFetchingMore;

/// Create a copy of SetupsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SetupsStateCopyWith<_SetupsState> get copyWith => __$SetupsStateCopyWithImpl<_SetupsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SetupsState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.isFetchingMore, isFetchingMore) || other.isFetchingMore == isFetchingMore));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_items),hasMore,isFetchingMore);

@override
String toString() {
  return 'SetupsState(status: $status, items: $items, hasMore: $hasMore, isFetchingMore: $isFetchingMore)';
}


}

/// @nodoc
abstract mixin class _$SetupsStateCopyWith<$Res> implements $SetupsStateCopyWith<$Res> {
  factory _$SetupsStateCopyWith(_SetupsState value, $Res Function(_SetupsState) _then) = __$SetupsStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, List<SetupEntity> items, bool hasMore, bool isFetchingMore
});




}
/// @nodoc
class __$SetupsStateCopyWithImpl<$Res>
    implements _$SetupsStateCopyWith<$Res> {
  __$SetupsStateCopyWithImpl(this._self, this._then);

  final _SetupsState _self;
  final $Res Function(_SetupsState) _then;

/// Create a copy of SetupsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? items = null,Object? hasMore = null,Object? isFetchingMore = null,}) {
  return _then(_SetupsState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<SetupEntity>,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,isFetchingMore: null == isFetchingMore ? _self.isFetchingMore : isFetchingMore // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
