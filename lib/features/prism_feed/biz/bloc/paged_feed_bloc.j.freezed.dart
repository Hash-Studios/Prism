// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'paged_feed_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PagedFeedEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PagedFeedEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PagedFeedEvent()';
}


}

/// @nodoc
class $PagedFeedEventCopyWith<$Res>  {
$PagedFeedEventCopyWith(PagedFeedEvent _, $Res Function(PagedFeedEvent) __);
}


/// Adds pattern-matching-related methods to [PagedFeedEvent].
extension PagedFeedEventPatterns on PagedFeedEvent {
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  started,TResult Function()?  refreshRequested,TResult Function()?  fetchMoreRequested,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _RefreshRequested() when refreshRequested != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  started,required TResult Function()  refreshRequested,required TResult Function()  fetchMoreRequested,}) {final _that = this;
switch (_that) {
case _Started():
return started();case _RefreshRequested():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  started,TResult? Function()?  refreshRequested,TResult? Function()?  fetchMoreRequested,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _RefreshRequested() when refreshRequested != null:
return refreshRequested();case _FetchMoreRequested() when fetchMoreRequested != null:
return fetchMoreRequested();case _:
  return null;

}
}

}

/// @nodoc


class _Started implements PagedFeedEvent {
  const _Started();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PagedFeedEvent.started()';
}


}




/// @nodoc


class _RefreshRequested implements PagedFeedEvent {
  const _RefreshRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefreshRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PagedFeedEvent.refreshRequested()';
}


}




/// @nodoc


class _FetchMoreRequested implements PagedFeedEvent {
  const _FetchMoreRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FetchMoreRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PagedFeedEvent.fetchMoreRequested()';
}


}




/// @nodoc
mixin _$PagedFeedState {

 LoadStatus get status; ActionStatus get actionStatus; List<FeedItemEntity> get items; bool get hasMore; bool get isFetchingMore; int get page; Failure? get failure;
/// Create a copy of PagedFeedState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PagedFeedStateCopyWith<PagedFeedState> get copyWith => _$PagedFeedStateCopyWithImpl<PagedFeedState>(this as PagedFeedState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PagedFeedState&&(identical(other.status, status) || other.status == status)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.isFetchingMore, isFetchingMore) || other.isFetchingMore == isFetchingMore)&&(identical(other.page, page) || other.page == page)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,status,actionStatus,const DeepCollectionEquality().hash(items),hasMore,isFetchingMore,page,failure);

@override
String toString() {
  return 'PagedFeedState(status: $status, actionStatus: $actionStatus, items: $items, hasMore: $hasMore, isFetchingMore: $isFetchingMore, page: $page, failure: $failure)';
}


}

/// @nodoc
abstract mixin class $PagedFeedStateCopyWith<$Res>  {
  factory $PagedFeedStateCopyWith(PagedFeedState value, $Res Function(PagedFeedState) _then) = _$PagedFeedStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, ActionStatus actionStatus, List<FeedItemEntity> items, bool hasMore, bool isFetchingMore, int page, Failure? failure
});




}
/// @nodoc
class _$PagedFeedStateCopyWithImpl<$Res>
    implements $PagedFeedStateCopyWith<$Res> {
  _$PagedFeedStateCopyWithImpl(this._self, this._then);

  final PagedFeedState _self;
  final $Res Function(PagedFeedState) _then;

/// Create a copy of PagedFeedState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? actionStatus = null,Object? items = null,Object? hasMore = null,Object? isFetchingMore = null,Object? page = null,Object? failure = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,actionStatus: null == actionStatus ? _self.actionStatus : actionStatus // ignore: cast_nullable_to_non_nullable
as ActionStatus,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<FeedItemEntity>,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,isFetchingMore: null == isFetchingMore ? _self.isFetchingMore : isFetchingMore // ignore: cast_nullable_to_non_nullable
as bool,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}

}


/// Adds pattern-matching-related methods to [PagedFeedState].
extension PagedFeedStatePatterns on PagedFeedState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PagedFeedState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PagedFeedState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PagedFeedState value)  $default,){
final _that = this;
switch (_that) {
case _PagedFeedState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PagedFeedState value)?  $default,){
final _that = this;
switch (_that) {
case _PagedFeedState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  ActionStatus actionStatus,  List<FeedItemEntity> items,  bool hasMore,  bool isFetchingMore,  int page,  Failure? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PagedFeedState() when $default != null:
return $default(_that.status,_that.actionStatus,_that.items,_that.hasMore,_that.isFetchingMore,_that.page,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  ActionStatus actionStatus,  List<FeedItemEntity> items,  bool hasMore,  bool isFetchingMore,  int page,  Failure? failure)  $default,) {final _that = this;
switch (_that) {
case _PagedFeedState():
return $default(_that.status,_that.actionStatus,_that.items,_that.hasMore,_that.isFetchingMore,_that.page,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  ActionStatus actionStatus,  List<FeedItemEntity> items,  bool hasMore,  bool isFetchingMore,  int page,  Failure? failure)?  $default,) {final _that = this;
switch (_that) {
case _PagedFeedState() when $default != null:
return $default(_that.status,_that.actionStatus,_that.items,_that.hasMore,_that.isFetchingMore,_that.page,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _PagedFeedState implements PagedFeedState {
  const _PagedFeedState({required this.status, required this.actionStatus, required final  List<FeedItemEntity> items, required this.hasMore, required this.isFetchingMore, required this.page, this.failure}): _items = items;
  

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
@override final  Failure? failure;

/// Create a copy of PagedFeedState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PagedFeedStateCopyWith<_PagedFeedState> get copyWith => __$PagedFeedStateCopyWithImpl<_PagedFeedState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PagedFeedState&&(identical(other.status, status) || other.status == status)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.isFetchingMore, isFetchingMore) || other.isFetchingMore == isFetchingMore)&&(identical(other.page, page) || other.page == page)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,status,actionStatus,const DeepCollectionEquality().hash(_items),hasMore,isFetchingMore,page,failure);

@override
String toString() {
  return 'PagedFeedState(status: $status, actionStatus: $actionStatus, items: $items, hasMore: $hasMore, isFetchingMore: $isFetchingMore, page: $page, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$PagedFeedStateCopyWith<$Res> implements $PagedFeedStateCopyWith<$Res> {
  factory _$PagedFeedStateCopyWith(_PagedFeedState value, $Res Function(_PagedFeedState) _then) = __$PagedFeedStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, ActionStatus actionStatus, List<FeedItemEntity> items, bool hasMore, bool isFetchingMore, int page, Failure? failure
});




}
/// @nodoc
class __$PagedFeedStateCopyWithImpl<$Res>
    implements _$PagedFeedStateCopyWith<$Res> {
  __$PagedFeedStateCopyWithImpl(this._self, this._then);

  final _PagedFeedState _self;
  final $Res Function(_PagedFeedState) _then;

/// Create a copy of PagedFeedState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? actionStatus = null,Object? items = null,Object? hasMore = null,Object? isFetchingMore = null,Object? page = null,Object? failure = freezed,}) {
  return _then(_PagedFeedState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,actionStatus: null == actionStatus ? _self.actionStatus : actionStatus // ignore: cast_nullable_to_non_nullable
as ActionStatus,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<FeedItemEntity>,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,isFetchingMore: null == isFetchingMore ? _self.isFetchingMore : isFetchingMore // ignore: cast_nullable_to_non_nullable
as bool,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}


}

// dart format on
