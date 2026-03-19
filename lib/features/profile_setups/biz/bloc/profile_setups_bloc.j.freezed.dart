// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_setups_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProfileSetupsEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileSetupsEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ProfileSetupsEvent()';
}


}

/// @nodoc
class $ProfileSetupsEventCopyWith<$Res>  {
$ProfileSetupsEventCopyWith(ProfileSetupsEvent _, $Res Function(ProfileSetupsEvent) __);
}


/// Adds pattern-matching-related methods to [ProfileSetupsEvent].
extension ProfileSetupsEventPatterns on ProfileSetupsEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _RefreshRequested value)?  refreshRequested,TResult Function( _FetchMoreRequested value)?  fetchMoreRequested,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _RefreshRequested() when refreshRequested != null:
return refreshRequested(_that);case _FetchMoreRequested() when fetchMoreRequested != null:
return fetchMoreRequested(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _RefreshRequested value)  refreshRequested,required TResult Function( _FetchMoreRequested value)  fetchMoreRequested,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _RefreshRequested():
return refreshRequested(_that);case _FetchMoreRequested():
return fetchMoreRequested(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _RefreshRequested value)?  refreshRequested,TResult? Function( _FetchMoreRequested value)?  fetchMoreRequested,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _RefreshRequested() when refreshRequested != null:
return refreshRequested(_that);case _FetchMoreRequested() when fetchMoreRequested != null:
return fetchMoreRequested(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String email)?  started,TResult Function()?  refreshRequested,TResult Function()?  fetchMoreRequested,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.email);case _RefreshRequested() when refreshRequested != null:
return refreshRequested();case _FetchMoreRequested() when fetchMoreRequested != null:
return fetchMoreRequested();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String email)  started,required TResult Function()  refreshRequested,required TResult Function()  fetchMoreRequested,}) {final _that = this;
switch (_that) {
case _Started():
return started(_that.email);case _RefreshRequested():
return refreshRequested();case _FetchMoreRequested():
return fetchMoreRequested();case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String email)?  started,TResult? Function()?  refreshRequested,TResult? Function()?  fetchMoreRequested,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.email);case _RefreshRequested() when refreshRequested != null:
return refreshRequested();case _FetchMoreRequested() when fetchMoreRequested != null:
return fetchMoreRequested();case _:
  return null;

}
}

}

/// @nodoc


class _Started implements ProfileSetupsEvent {
  const _Started({required this.email});
  

 final  String email;

/// Create a copy of ProfileSetupsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StartedCopyWith<_Started> get copyWith => __$StartedCopyWithImpl<_Started>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started&&(identical(other.email, email) || other.email == email));
}


@override
int get hashCode => Object.hash(runtimeType,email);

@override
String toString() {
  return 'ProfileSetupsEvent.started(email: $email)';
}


}

/// @nodoc
abstract mixin class _$StartedCopyWith<$Res> implements $ProfileSetupsEventCopyWith<$Res> {
  factory _$StartedCopyWith(_Started value, $Res Function(_Started) _then) = __$StartedCopyWithImpl;
@useResult
$Res call({
 String email
});




}
/// @nodoc
class __$StartedCopyWithImpl<$Res>
    implements _$StartedCopyWith<$Res> {
  __$StartedCopyWithImpl(this._self, this._then);

  final _Started _self;
  final $Res Function(_Started) _then;

/// Create a copy of ProfileSetupsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,}) {
  return _then(_Started(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _RefreshRequested implements ProfileSetupsEvent {
  const _RefreshRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefreshRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ProfileSetupsEvent.refreshRequested()';
}


}




/// @nodoc


class _FetchMoreRequested implements ProfileSetupsEvent {
  const _FetchMoreRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FetchMoreRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ProfileSetupsEvent.fetchMoreRequested()';
}


}




/// @nodoc
mixin _$ProfileSetupsState {

 LoadStatus get status; ActionStatus get actionStatus; String get email; List<ProfileSetupEntity> get items; bool get hasMore; String? get nextCursor; bool get isFetchingMore; Failure? get failure;
/// Create a copy of ProfileSetupsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileSetupsStateCopyWith<ProfileSetupsState> get copyWith => _$ProfileSetupsStateCopyWithImpl<ProfileSetupsState>(this as ProfileSetupsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileSetupsState&&(identical(other.status, status) || other.status == status)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&(identical(other.email, email) || other.email == email)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.isFetchingMore, isFetchingMore) || other.isFetchingMore == isFetchingMore)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,status,actionStatus,email,const DeepCollectionEquality().hash(items),hasMore,nextCursor,isFetchingMore,failure);

@override
String toString() {
  return 'ProfileSetupsState(status: $status, actionStatus: $actionStatus, email: $email, items: $items, hasMore: $hasMore, nextCursor: $nextCursor, isFetchingMore: $isFetchingMore, failure: $failure)';
}


}

/// @nodoc
abstract mixin class $ProfileSetupsStateCopyWith<$Res>  {
  factory $ProfileSetupsStateCopyWith(ProfileSetupsState value, $Res Function(ProfileSetupsState) _then) = _$ProfileSetupsStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, ActionStatus actionStatus, String email, List<ProfileSetupEntity> items, bool hasMore, String? nextCursor, bool isFetchingMore, Failure? failure
});




}
/// @nodoc
class _$ProfileSetupsStateCopyWithImpl<$Res>
    implements $ProfileSetupsStateCopyWith<$Res> {
  _$ProfileSetupsStateCopyWithImpl(this._self, this._then);

  final ProfileSetupsState _self;
  final $Res Function(ProfileSetupsState) _then;

/// Create a copy of ProfileSetupsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? actionStatus = null,Object? email = null,Object? items = null,Object? hasMore = null,Object? nextCursor = freezed,Object? isFetchingMore = null,Object? failure = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,actionStatus: null == actionStatus ? _self.actionStatus : actionStatus // ignore: cast_nullable_to_non_nullable
as ActionStatus,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<ProfileSetupEntity>,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,isFetchingMore: null == isFetchingMore ? _self.isFetchingMore : isFetchingMore // ignore: cast_nullable_to_non_nullable
as bool,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProfileSetupsState].
extension ProfileSetupsStatePatterns on ProfileSetupsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileSetupsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileSetupsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileSetupsState value)  $default,){
final _that = this;
switch (_that) {
case _ProfileSetupsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileSetupsState value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileSetupsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  ActionStatus actionStatus,  String email,  List<ProfileSetupEntity> items,  bool hasMore,  String? nextCursor,  bool isFetchingMore,  Failure? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileSetupsState() when $default != null:
return $default(_that.status,_that.actionStatus,_that.email,_that.items,_that.hasMore,_that.nextCursor,_that.isFetchingMore,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  ActionStatus actionStatus,  String email,  List<ProfileSetupEntity> items,  bool hasMore,  String? nextCursor,  bool isFetchingMore,  Failure? failure)  $default,) {final _that = this;
switch (_that) {
case _ProfileSetupsState():
return $default(_that.status,_that.actionStatus,_that.email,_that.items,_that.hasMore,_that.nextCursor,_that.isFetchingMore,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  ActionStatus actionStatus,  String email,  List<ProfileSetupEntity> items,  bool hasMore,  String? nextCursor,  bool isFetchingMore,  Failure? failure)?  $default,) {final _that = this;
switch (_that) {
case _ProfileSetupsState() when $default != null:
return $default(_that.status,_that.actionStatus,_that.email,_that.items,_that.hasMore,_that.nextCursor,_that.isFetchingMore,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _ProfileSetupsState implements ProfileSetupsState {
  const _ProfileSetupsState({required this.status, required this.actionStatus, required this.email, required final  List<ProfileSetupEntity> items, required this.hasMore, required this.nextCursor, required this.isFetchingMore, this.failure}): _items = items;
  

@override final  LoadStatus status;
@override final  ActionStatus actionStatus;
@override final  String email;
 final  List<ProfileSetupEntity> _items;
@override List<ProfileSetupEntity> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  bool hasMore;
@override final  String? nextCursor;
@override final  bool isFetchingMore;
@override final  Failure? failure;

/// Create a copy of ProfileSetupsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileSetupsStateCopyWith<_ProfileSetupsState> get copyWith => __$ProfileSetupsStateCopyWithImpl<_ProfileSetupsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileSetupsState&&(identical(other.status, status) || other.status == status)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&(identical(other.email, email) || other.email == email)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.isFetchingMore, isFetchingMore) || other.isFetchingMore == isFetchingMore)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,status,actionStatus,email,const DeepCollectionEquality().hash(_items),hasMore,nextCursor,isFetchingMore,failure);

@override
String toString() {
  return 'ProfileSetupsState(status: $status, actionStatus: $actionStatus, email: $email, items: $items, hasMore: $hasMore, nextCursor: $nextCursor, isFetchingMore: $isFetchingMore, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$ProfileSetupsStateCopyWith<$Res> implements $ProfileSetupsStateCopyWith<$Res> {
  factory _$ProfileSetupsStateCopyWith(_ProfileSetupsState value, $Res Function(_ProfileSetupsState) _then) = __$ProfileSetupsStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, ActionStatus actionStatus, String email, List<ProfileSetupEntity> items, bool hasMore, String? nextCursor, bool isFetchingMore, Failure? failure
});




}
/// @nodoc
class __$ProfileSetupsStateCopyWithImpl<$Res>
    implements _$ProfileSetupsStateCopyWith<$Res> {
  __$ProfileSetupsStateCopyWithImpl(this._self, this._then);

  final _ProfileSetupsState _self;
  final $Res Function(_ProfileSetupsState) _then;

/// Create a copy of ProfileSetupsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? actionStatus = null,Object? email = null,Object? items = null,Object? hasMore = null,Object? nextCursor = freezed,Object? isFetchingMore = null,Object? failure = freezed,}) {
  return _then(_ProfileSetupsState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,actionStatus: null == actionStatus ? _self.actionStatus : actionStatus // ignore: cast_nullable_to_non_nullable
as ActionStatus,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<ProfileSetupEntity>,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,isFetchingMore: null == isFetchingMore ? _self.isFetchingMore : isFetchingMore // ignore: cast_nullable_to_non_nullable
as bool,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}


}

// dart format on
