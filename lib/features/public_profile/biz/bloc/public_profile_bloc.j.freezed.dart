// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'public_profile_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PublicProfileEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicProfileEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PublicProfileEvent()';
}


}

/// @nodoc
class $PublicProfileEventCopyWith<$Res>  {
$PublicProfileEventCopyWith(PublicProfileEvent _, $Res Function(PublicProfileEvent) __);
}


/// Adds pattern-matching-related methods to [PublicProfileEvent].
extension PublicProfileEventPatterns on PublicProfileEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _RefreshRequested value)?  refreshRequested,TResult Function( _FetchMoreWallsRequested value)?  fetchMoreWallsRequested,TResult Function( _FetchMoreSetupsRequested value)?  fetchMoreSetupsRequested,TResult Function( _FollowRequested value)?  followRequested,TResult Function( _UnfollowRequested value)?  unfollowRequested,TResult Function( _LinksUpdated value)?  linksUpdated,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _RefreshRequested() when refreshRequested != null:
return refreshRequested(_that);case _FetchMoreWallsRequested() when fetchMoreWallsRequested != null:
return fetchMoreWallsRequested(_that);case _FetchMoreSetupsRequested() when fetchMoreSetupsRequested != null:
return fetchMoreSetupsRequested(_that);case _FollowRequested() when followRequested != null:
return followRequested(_that);case _UnfollowRequested() when unfollowRequested != null:
return unfollowRequested(_that);case _LinksUpdated() when linksUpdated != null:
return linksUpdated(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _RefreshRequested value)  refreshRequested,required TResult Function( _FetchMoreWallsRequested value)  fetchMoreWallsRequested,required TResult Function( _FetchMoreSetupsRequested value)  fetchMoreSetupsRequested,required TResult Function( _FollowRequested value)  followRequested,required TResult Function( _UnfollowRequested value)  unfollowRequested,required TResult Function( _LinksUpdated value)  linksUpdated,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _RefreshRequested():
return refreshRequested(_that);case _FetchMoreWallsRequested():
return fetchMoreWallsRequested(_that);case _FetchMoreSetupsRequested():
return fetchMoreSetupsRequested(_that);case _FollowRequested():
return followRequested(_that);case _UnfollowRequested():
return unfollowRequested(_that);case _LinksUpdated():
return linksUpdated(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _RefreshRequested value)?  refreshRequested,TResult? Function( _FetchMoreWallsRequested value)?  fetchMoreWallsRequested,TResult? Function( _FetchMoreSetupsRequested value)?  fetchMoreSetupsRequested,TResult? Function( _FollowRequested value)?  followRequested,TResult? Function( _UnfollowRequested value)?  unfollowRequested,TResult? Function( _LinksUpdated value)?  linksUpdated,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _RefreshRequested() when refreshRequested != null:
return refreshRequested(_that);case _FetchMoreWallsRequested() when fetchMoreWallsRequested != null:
return fetchMoreWallsRequested(_that);case _FetchMoreSetupsRequested() when fetchMoreSetupsRequested != null:
return fetchMoreSetupsRequested(_that);case _FollowRequested() when followRequested != null:
return followRequested(_that);case _UnfollowRequested() when unfollowRequested != null:
return unfollowRequested(_that);case _LinksUpdated() when linksUpdated != null:
return linksUpdated(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String email)?  started,TResult Function()?  refreshRequested,TResult Function()?  fetchMoreWallsRequested,TResult Function()?  fetchMoreSetupsRequested,TResult Function( String currentUserId,  String currentUserEmail)?  followRequested,TResult Function( String currentUserId,  String currentUserEmail)?  unfollowRequested,TResult Function( String userId,  Map<String, String> links)?  linksUpdated,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.email);case _RefreshRequested() when refreshRequested != null:
return refreshRequested();case _FetchMoreWallsRequested() when fetchMoreWallsRequested != null:
return fetchMoreWallsRequested();case _FetchMoreSetupsRequested() when fetchMoreSetupsRequested != null:
return fetchMoreSetupsRequested();case _FollowRequested() when followRequested != null:
return followRequested(_that.currentUserId,_that.currentUserEmail);case _UnfollowRequested() when unfollowRequested != null:
return unfollowRequested(_that.currentUserId,_that.currentUserEmail);case _LinksUpdated() when linksUpdated != null:
return linksUpdated(_that.userId,_that.links);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String email)  started,required TResult Function()  refreshRequested,required TResult Function()  fetchMoreWallsRequested,required TResult Function()  fetchMoreSetupsRequested,required TResult Function( String currentUserId,  String currentUserEmail)  followRequested,required TResult Function( String currentUserId,  String currentUserEmail)  unfollowRequested,required TResult Function( String userId,  Map<String, String> links)  linksUpdated,}) {final _that = this;
switch (_that) {
case _Started():
return started(_that.email);case _RefreshRequested():
return refreshRequested();case _FetchMoreWallsRequested():
return fetchMoreWallsRequested();case _FetchMoreSetupsRequested():
return fetchMoreSetupsRequested();case _FollowRequested():
return followRequested(_that.currentUserId,_that.currentUserEmail);case _UnfollowRequested():
return unfollowRequested(_that.currentUserId,_that.currentUserEmail);case _LinksUpdated():
return linksUpdated(_that.userId,_that.links);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String email)?  started,TResult? Function()?  refreshRequested,TResult? Function()?  fetchMoreWallsRequested,TResult? Function()?  fetchMoreSetupsRequested,TResult? Function( String currentUserId,  String currentUserEmail)?  followRequested,TResult? Function( String currentUserId,  String currentUserEmail)?  unfollowRequested,TResult? Function( String userId,  Map<String, String> links)?  linksUpdated,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.email);case _RefreshRequested() when refreshRequested != null:
return refreshRequested();case _FetchMoreWallsRequested() when fetchMoreWallsRequested != null:
return fetchMoreWallsRequested();case _FetchMoreSetupsRequested() when fetchMoreSetupsRequested != null:
return fetchMoreSetupsRequested();case _FollowRequested() when followRequested != null:
return followRequested(_that.currentUserId,_that.currentUserEmail);case _UnfollowRequested() when unfollowRequested != null:
return unfollowRequested(_that.currentUserId,_that.currentUserEmail);case _LinksUpdated() when linksUpdated != null:
return linksUpdated(_that.userId,_that.links);case _:
  return null;

}
}

}

/// @nodoc


class _Started implements PublicProfileEvent {
  const _Started({required this.email});
  

 final  String email;

/// Create a copy of PublicProfileEvent
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
  return 'PublicProfileEvent.started(email: $email)';
}


}

/// @nodoc
abstract mixin class _$StartedCopyWith<$Res> implements $PublicProfileEventCopyWith<$Res> {
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

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? email = null,}) {
  return _then(_Started(
email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _RefreshRequested implements PublicProfileEvent {
  const _RefreshRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefreshRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PublicProfileEvent.refreshRequested()';
}


}




/// @nodoc


class _FetchMoreWallsRequested implements PublicProfileEvent {
  const _FetchMoreWallsRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FetchMoreWallsRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PublicProfileEvent.fetchMoreWallsRequested()';
}


}




/// @nodoc


class _FetchMoreSetupsRequested implements PublicProfileEvent {
  const _FetchMoreSetupsRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FetchMoreSetupsRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PublicProfileEvent.fetchMoreSetupsRequested()';
}


}




/// @nodoc


class _FollowRequested implements PublicProfileEvent {
  const _FollowRequested({required this.currentUserId, required this.currentUserEmail});
  

 final  String currentUserId;
 final  String currentUserEmail;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FollowRequestedCopyWith<_FollowRequested> get copyWith => __$FollowRequestedCopyWithImpl<_FollowRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FollowRequested&&(identical(other.currentUserId, currentUserId) || other.currentUserId == currentUserId)&&(identical(other.currentUserEmail, currentUserEmail) || other.currentUserEmail == currentUserEmail));
}


@override
int get hashCode => Object.hash(runtimeType,currentUserId,currentUserEmail);

@override
String toString() {
  return 'PublicProfileEvent.followRequested(currentUserId: $currentUserId, currentUserEmail: $currentUserEmail)';
}


}

/// @nodoc
abstract mixin class _$FollowRequestedCopyWith<$Res> implements $PublicProfileEventCopyWith<$Res> {
  factory _$FollowRequestedCopyWith(_FollowRequested value, $Res Function(_FollowRequested) _then) = __$FollowRequestedCopyWithImpl;
@useResult
$Res call({
 String currentUserId, String currentUserEmail
});




}
/// @nodoc
class __$FollowRequestedCopyWithImpl<$Res>
    implements _$FollowRequestedCopyWith<$Res> {
  __$FollowRequestedCopyWithImpl(this._self, this._then);

  final _FollowRequested _self;
  final $Res Function(_FollowRequested) _then;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? currentUserId = null,Object? currentUserEmail = null,}) {
  return _then(_FollowRequested(
currentUserId: null == currentUserId ? _self.currentUserId : currentUserId // ignore: cast_nullable_to_non_nullable
as String,currentUserEmail: null == currentUserEmail ? _self.currentUserEmail : currentUserEmail // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _UnfollowRequested implements PublicProfileEvent {
  const _UnfollowRequested({required this.currentUserId, required this.currentUserEmail});
  

 final  String currentUserId;
 final  String currentUserEmail;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UnfollowRequestedCopyWith<_UnfollowRequested> get copyWith => __$UnfollowRequestedCopyWithImpl<_UnfollowRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UnfollowRequested&&(identical(other.currentUserId, currentUserId) || other.currentUserId == currentUserId)&&(identical(other.currentUserEmail, currentUserEmail) || other.currentUserEmail == currentUserEmail));
}


@override
int get hashCode => Object.hash(runtimeType,currentUserId,currentUserEmail);

@override
String toString() {
  return 'PublicProfileEvent.unfollowRequested(currentUserId: $currentUserId, currentUserEmail: $currentUserEmail)';
}


}

/// @nodoc
abstract mixin class _$UnfollowRequestedCopyWith<$Res> implements $PublicProfileEventCopyWith<$Res> {
  factory _$UnfollowRequestedCopyWith(_UnfollowRequested value, $Res Function(_UnfollowRequested) _then) = __$UnfollowRequestedCopyWithImpl;
@useResult
$Res call({
 String currentUserId, String currentUserEmail
});




}
/// @nodoc
class __$UnfollowRequestedCopyWithImpl<$Res>
    implements _$UnfollowRequestedCopyWith<$Res> {
  __$UnfollowRequestedCopyWithImpl(this._self, this._then);

  final _UnfollowRequested _self;
  final $Res Function(_UnfollowRequested) _then;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? currentUserId = null,Object? currentUserEmail = null,}) {
  return _then(_UnfollowRequested(
currentUserId: null == currentUserId ? _self.currentUserId : currentUserId // ignore: cast_nullable_to_non_nullable
as String,currentUserEmail: null == currentUserEmail ? _self.currentUserEmail : currentUserEmail // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _LinksUpdated implements PublicProfileEvent {
  const _LinksUpdated({required this.userId, required final  Map<String, String> links}): _links = links;
  

 final  String userId;
 final  Map<String, String> _links;
 Map<String, String> get links {
  if (_links is EqualUnmodifiableMapView) return _links;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_links);
}


/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LinksUpdatedCopyWith<_LinksUpdated> get copyWith => __$LinksUpdatedCopyWithImpl<_LinksUpdated>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LinksUpdated&&(identical(other.userId, userId) || other.userId == userId)&&const DeepCollectionEquality().equals(other._links, _links));
}


@override
int get hashCode => Object.hash(runtimeType,userId,const DeepCollectionEquality().hash(_links));

@override
String toString() {
  return 'PublicProfileEvent.linksUpdated(userId: $userId, links: $links)';
}


}

/// @nodoc
abstract mixin class _$LinksUpdatedCopyWith<$Res> implements $PublicProfileEventCopyWith<$Res> {
  factory _$LinksUpdatedCopyWith(_LinksUpdated value, $Res Function(_LinksUpdated) _then) = __$LinksUpdatedCopyWithImpl;
@useResult
$Res call({
 String userId, Map<String, String> links
});




}
/// @nodoc
class __$LinksUpdatedCopyWithImpl<$Res>
    implements _$LinksUpdatedCopyWith<$Res> {
  __$LinksUpdatedCopyWithImpl(this._self, this._then);

  final _LinksUpdated _self;
  final $Res Function(_LinksUpdated) _then;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? links = null,}) {
  return _then(_LinksUpdated(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,links: null == links ? _self._links : links // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}

/// @nodoc
mixin _$PublicProfileState {

 LoadStatus get status; ActionStatus get actionStatus; String get email; PublicProfileEntity get profile; List<PublicProfileWallEntity> get walls; List<PublicProfileSetupEntity> get setups; bool get hasMoreWalls; bool get hasMoreSetups; String? get wallsCursor; String? get setupsCursor; bool get isFetchingMoreWalls; bool get isFetchingMoreSetups; Failure? get failure;
/// Create a copy of PublicProfileState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicProfileStateCopyWith<PublicProfileState> get copyWith => _$PublicProfileStateCopyWithImpl<PublicProfileState>(this as PublicProfileState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicProfileState&&(identical(other.status, status) || other.status == status)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&(identical(other.email, email) || other.email == email)&&(identical(other.profile, profile) || other.profile == profile)&&const DeepCollectionEquality().equals(other.walls, walls)&&const DeepCollectionEquality().equals(other.setups, setups)&&(identical(other.hasMoreWalls, hasMoreWalls) || other.hasMoreWalls == hasMoreWalls)&&(identical(other.hasMoreSetups, hasMoreSetups) || other.hasMoreSetups == hasMoreSetups)&&(identical(other.wallsCursor, wallsCursor) || other.wallsCursor == wallsCursor)&&(identical(other.setupsCursor, setupsCursor) || other.setupsCursor == setupsCursor)&&(identical(other.isFetchingMoreWalls, isFetchingMoreWalls) || other.isFetchingMoreWalls == isFetchingMoreWalls)&&(identical(other.isFetchingMoreSetups, isFetchingMoreSetups) || other.isFetchingMoreSetups == isFetchingMoreSetups)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,status,actionStatus,email,profile,const DeepCollectionEquality().hash(walls),const DeepCollectionEquality().hash(setups),hasMoreWalls,hasMoreSetups,wallsCursor,setupsCursor,isFetchingMoreWalls,isFetchingMoreSetups,failure);

@override
String toString() {
  return 'PublicProfileState(status: $status, actionStatus: $actionStatus, email: $email, profile: $profile, walls: $walls, setups: $setups, hasMoreWalls: $hasMoreWalls, hasMoreSetups: $hasMoreSetups, wallsCursor: $wallsCursor, setupsCursor: $setupsCursor, isFetchingMoreWalls: $isFetchingMoreWalls, isFetchingMoreSetups: $isFetchingMoreSetups, failure: $failure)';
}


}

/// @nodoc
abstract mixin class $PublicProfileStateCopyWith<$Res>  {
  factory $PublicProfileStateCopyWith(PublicProfileState value, $Res Function(PublicProfileState) _then) = _$PublicProfileStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, ActionStatus actionStatus, String email, PublicProfileEntity profile, List<PublicProfileWallEntity> walls, List<PublicProfileSetupEntity> setups, bool hasMoreWalls, bool hasMoreSetups, String? wallsCursor, String? setupsCursor, bool isFetchingMoreWalls, bool isFetchingMoreSetups, Failure? failure
});




}
/// @nodoc
class _$PublicProfileStateCopyWithImpl<$Res>
    implements $PublicProfileStateCopyWith<$Res> {
  _$PublicProfileStateCopyWithImpl(this._self, this._then);

  final PublicProfileState _self;
  final $Res Function(PublicProfileState) _then;

/// Create a copy of PublicProfileState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? actionStatus = null,Object? email = null,Object? profile = null,Object? walls = null,Object? setups = null,Object? hasMoreWalls = null,Object? hasMoreSetups = null,Object? wallsCursor = freezed,Object? setupsCursor = freezed,Object? isFetchingMoreWalls = null,Object? isFetchingMoreSetups = null,Object? failure = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,actionStatus: null == actionStatus ? _self.actionStatus : actionStatus // ignore: cast_nullable_to_non_nullable
as ActionStatus,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,profile: null == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as PublicProfileEntity,walls: null == walls ? _self.walls : walls // ignore: cast_nullable_to_non_nullable
as List<PublicProfileWallEntity>,setups: null == setups ? _self.setups : setups // ignore: cast_nullable_to_non_nullable
as List<PublicProfileSetupEntity>,hasMoreWalls: null == hasMoreWalls ? _self.hasMoreWalls : hasMoreWalls // ignore: cast_nullable_to_non_nullable
as bool,hasMoreSetups: null == hasMoreSetups ? _self.hasMoreSetups : hasMoreSetups // ignore: cast_nullable_to_non_nullable
as bool,wallsCursor: freezed == wallsCursor ? _self.wallsCursor : wallsCursor // ignore: cast_nullable_to_non_nullable
as String?,setupsCursor: freezed == setupsCursor ? _self.setupsCursor : setupsCursor // ignore: cast_nullable_to_non_nullable
as String?,isFetchingMoreWalls: null == isFetchingMoreWalls ? _self.isFetchingMoreWalls : isFetchingMoreWalls // ignore: cast_nullable_to_non_nullable
as bool,isFetchingMoreSetups: null == isFetchingMoreSetups ? _self.isFetchingMoreSetups : isFetchingMoreSetups // ignore: cast_nullable_to_non_nullable
as bool,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}

}


/// Adds pattern-matching-related methods to [PublicProfileState].
extension PublicProfileStatePatterns on PublicProfileState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PublicProfileState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PublicProfileState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PublicProfileState value)  $default,){
final _that = this;
switch (_that) {
case _PublicProfileState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PublicProfileState value)?  $default,){
final _that = this;
switch (_that) {
case _PublicProfileState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  ActionStatus actionStatus,  String email,  PublicProfileEntity profile,  List<PublicProfileWallEntity> walls,  List<PublicProfileSetupEntity> setups,  bool hasMoreWalls,  bool hasMoreSetups,  String? wallsCursor,  String? setupsCursor,  bool isFetchingMoreWalls,  bool isFetchingMoreSetups,  Failure? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublicProfileState() when $default != null:
return $default(_that.status,_that.actionStatus,_that.email,_that.profile,_that.walls,_that.setups,_that.hasMoreWalls,_that.hasMoreSetups,_that.wallsCursor,_that.setupsCursor,_that.isFetchingMoreWalls,_that.isFetchingMoreSetups,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  ActionStatus actionStatus,  String email,  PublicProfileEntity profile,  List<PublicProfileWallEntity> walls,  List<PublicProfileSetupEntity> setups,  bool hasMoreWalls,  bool hasMoreSetups,  String? wallsCursor,  String? setupsCursor,  bool isFetchingMoreWalls,  bool isFetchingMoreSetups,  Failure? failure)  $default,) {final _that = this;
switch (_that) {
case _PublicProfileState():
return $default(_that.status,_that.actionStatus,_that.email,_that.profile,_that.walls,_that.setups,_that.hasMoreWalls,_that.hasMoreSetups,_that.wallsCursor,_that.setupsCursor,_that.isFetchingMoreWalls,_that.isFetchingMoreSetups,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  ActionStatus actionStatus,  String email,  PublicProfileEntity profile,  List<PublicProfileWallEntity> walls,  List<PublicProfileSetupEntity> setups,  bool hasMoreWalls,  bool hasMoreSetups,  String? wallsCursor,  String? setupsCursor,  bool isFetchingMoreWalls,  bool isFetchingMoreSetups,  Failure? failure)?  $default,) {final _that = this;
switch (_that) {
case _PublicProfileState() when $default != null:
return $default(_that.status,_that.actionStatus,_that.email,_that.profile,_that.walls,_that.setups,_that.hasMoreWalls,_that.hasMoreSetups,_that.wallsCursor,_that.setupsCursor,_that.isFetchingMoreWalls,_that.isFetchingMoreSetups,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _PublicProfileState implements PublicProfileState {
  const _PublicProfileState({required this.status, required this.actionStatus, required this.email, required this.profile, required final  List<PublicProfileWallEntity> walls, required final  List<PublicProfileSetupEntity> setups, required this.hasMoreWalls, required this.hasMoreSetups, required this.wallsCursor, required this.setupsCursor, required this.isFetchingMoreWalls, required this.isFetchingMoreSetups, this.failure}): _walls = walls,_setups = setups;
  

@override final  LoadStatus status;
@override final  ActionStatus actionStatus;
@override final  String email;
@override final  PublicProfileEntity profile;
 final  List<PublicProfileWallEntity> _walls;
@override List<PublicProfileWallEntity> get walls {
  if (_walls is EqualUnmodifiableListView) return _walls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_walls);
}

 final  List<PublicProfileSetupEntity> _setups;
@override List<PublicProfileSetupEntity> get setups {
  if (_setups is EqualUnmodifiableListView) return _setups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_setups);
}

@override final  bool hasMoreWalls;
@override final  bool hasMoreSetups;
@override final  String? wallsCursor;
@override final  String? setupsCursor;
@override final  bool isFetchingMoreWalls;
@override final  bool isFetchingMoreSetups;
@override final  Failure? failure;

/// Create a copy of PublicProfileState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PublicProfileStateCopyWith<_PublicProfileState> get copyWith => __$PublicProfileStateCopyWithImpl<_PublicProfileState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublicProfileState&&(identical(other.status, status) || other.status == status)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&(identical(other.email, email) || other.email == email)&&(identical(other.profile, profile) || other.profile == profile)&&const DeepCollectionEquality().equals(other._walls, _walls)&&const DeepCollectionEquality().equals(other._setups, _setups)&&(identical(other.hasMoreWalls, hasMoreWalls) || other.hasMoreWalls == hasMoreWalls)&&(identical(other.hasMoreSetups, hasMoreSetups) || other.hasMoreSetups == hasMoreSetups)&&(identical(other.wallsCursor, wallsCursor) || other.wallsCursor == wallsCursor)&&(identical(other.setupsCursor, setupsCursor) || other.setupsCursor == setupsCursor)&&(identical(other.isFetchingMoreWalls, isFetchingMoreWalls) || other.isFetchingMoreWalls == isFetchingMoreWalls)&&(identical(other.isFetchingMoreSetups, isFetchingMoreSetups) || other.isFetchingMoreSetups == isFetchingMoreSetups)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,status,actionStatus,email,profile,const DeepCollectionEquality().hash(_walls),const DeepCollectionEquality().hash(_setups),hasMoreWalls,hasMoreSetups,wallsCursor,setupsCursor,isFetchingMoreWalls,isFetchingMoreSetups,failure);

@override
String toString() {
  return 'PublicProfileState(status: $status, actionStatus: $actionStatus, email: $email, profile: $profile, walls: $walls, setups: $setups, hasMoreWalls: $hasMoreWalls, hasMoreSetups: $hasMoreSetups, wallsCursor: $wallsCursor, setupsCursor: $setupsCursor, isFetchingMoreWalls: $isFetchingMoreWalls, isFetchingMoreSetups: $isFetchingMoreSetups, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$PublicProfileStateCopyWith<$Res> implements $PublicProfileStateCopyWith<$Res> {
  factory _$PublicProfileStateCopyWith(_PublicProfileState value, $Res Function(_PublicProfileState) _then) = __$PublicProfileStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, ActionStatus actionStatus, String email, PublicProfileEntity profile, List<PublicProfileWallEntity> walls, List<PublicProfileSetupEntity> setups, bool hasMoreWalls, bool hasMoreSetups, String? wallsCursor, String? setupsCursor, bool isFetchingMoreWalls, bool isFetchingMoreSetups, Failure? failure
});




}
/// @nodoc
class __$PublicProfileStateCopyWithImpl<$Res>
    implements _$PublicProfileStateCopyWith<$Res> {
  __$PublicProfileStateCopyWithImpl(this._self, this._then);

  final _PublicProfileState _self;
  final $Res Function(_PublicProfileState) _then;

/// Create a copy of PublicProfileState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? actionStatus = null,Object? email = null,Object? profile = null,Object? walls = null,Object? setups = null,Object? hasMoreWalls = null,Object? hasMoreSetups = null,Object? wallsCursor = freezed,Object? setupsCursor = freezed,Object? isFetchingMoreWalls = null,Object? isFetchingMoreSetups = null,Object? failure = freezed,}) {
  return _then(_PublicProfileState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,actionStatus: null == actionStatus ? _self.actionStatus : actionStatus // ignore: cast_nullable_to_non_nullable
as ActionStatus,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,profile: null == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as PublicProfileEntity,walls: null == walls ? _self._walls : walls // ignore: cast_nullable_to_non_nullable
as List<PublicProfileWallEntity>,setups: null == setups ? _self._setups : setups // ignore: cast_nullable_to_non_nullable
as List<PublicProfileSetupEntity>,hasMoreWalls: null == hasMoreWalls ? _self.hasMoreWalls : hasMoreWalls // ignore: cast_nullable_to_non_nullable
as bool,hasMoreSetups: null == hasMoreSetups ? _self.hasMoreSetups : hasMoreSetups // ignore: cast_nullable_to_non_nullable
as bool,wallsCursor: freezed == wallsCursor ? _self.wallsCursor : wallsCursor // ignore: cast_nullable_to_non_nullable
as String?,setupsCursor: freezed == setupsCursor ? _self.setupsCursor : setupsCursor // ignore: cast_nullable_to_non_nullable
as String?,isFetchingMoreWalls: null == isFetchingMoreWalls ? _self.isFetchingMoreWalls : isFetchingMoreWalls // ignore: cast_nullable_to_non_nullable
as bool,isFetchingMoreSetups: null == isFetchingMoreSetups ? _self.isFetchingMoreSetups : isFetchingMoreSetups // ignore: cast_nullable_to_non_nullable
as bool,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}


}

// dart format on
