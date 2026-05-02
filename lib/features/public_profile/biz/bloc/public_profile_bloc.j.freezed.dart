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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _RefreshRequested value)?  refreshRequested,TResult Function( _FetchMoreWallsRequested value)?  fetchMoreWallsRequested,TResult Function( _FetchMoreSetupsRequested value)?  fetchMoreSetupsRequested,TResult Function( _FollowRequested value)?  followRequested,TResult Function( _UnfollowRequested value)?  unfollowRequested,TResult Function( _LinksUpdated value)?  linksUpdated,TResult Function( _FetchFollowerSummariesPageRequested value)?  fetchFollowerSummariesPageRequested,TResult Function( _FetchFollowingSummariesPageRequested value)?  fetchFollowingSummariesPageRequested,TResult Function( _SearchFollowerSummariesRequested value)?  searchFollowerSummariesRequested,TResult Function( _SearchFollowingSummariesRequested value)?  searchFollowingSummariesRequested,TResult Function( _ClearFollowerSearch value)?  clearFollowerSearch,TResult Function( _ClearFollowingSearch value)?  clearFollowingSearch,TResult Function( _FollowFromListRequested value)?  followFromListRequested,TResult Function( _UnfollowFromListRequested value)?  unfollowFromListRequested,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _RefreshRequested() when refreshRequested != null:
return refreshRequested(_that);case _FetchMoreWallsRequested() when fetchMoreWallsRequested != null:
return fetchMoreWallsRequested(_that);case _FetchMoreSetupsRequested() when fetchMoreSetupsRequested != null:
return fetchMoreSetupsRequested(_that);case _FollowRequested() when followRequested != null:
return followRequested(_that);case _UnfollowRequested() when unfollowRequested != null:
return unfollowRequested(_that);case _LinksUpdated() when linksUpdated != null:
return linksUpdated(_that);case _FetchFollowerSummariesPageRequested() when fetchFollowerSummariesPageRequested != null:
return fetchFollowerSummariesPageRequested(_that);case _FetchFollowingSummariesPageRequested() when fetchFollowingSummariesPageRequested != null:
return fetchFollowingSummariesPageRequested(_that);case _SearchFollowerSummariesRequested() when searchFollowerSummariesRequested != null:
return searchFollowerSummariesRequested(_that);case _SearchFollowingSummariesRequested() when searchFollowingSummariesRequested != null:
return searchFollowingSummariesRequested(_that);case _ClearFollowerSearch() when clearFollowerSearch != null:
return clearFollowerSearch(_that);case _ClearFollowingSearch() when clearFollowingSearch != null:
return clearFollowingSearch(_that);case _FollowFromListRequested() when followFromListRequested != null:
return followFromListRequested(_that);case _UnfollowFromListRequested() when unfollowFromListRequested != null:
return unfollowFromListRequested(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _RefreshRequested value)  refreshRequested,required TResult Function( _FetchMoreWallsRequested value)  fetchMoreWallsRequested,required TResult Function( _FetchMoreSetupsRequested value)  fetchMoreSetupsRequested,required TResult Function( _FollowRequested value)  followRequested,required TResult Function( _UnfollowRequested value)  unfollowRequested,required TResult Function( _LinksUpdated value)  linksUpdated,required TResult Function( _FetchFollowerSummariesPageRequested value)  fetchFollowerSummariesPageRequested,required TResult Function( _FetchFollowingSummariesPageRequested value)  fetchFollowingSummariesPageRequested,required TResult Function( _SearchFollowerSummariesRequested value)  searchFollowerSummariesRequested,required TResult Function( _SearchFollowingSummariesRequested value)  searchFollowingSummariesRequested,required TResult Function( _ClearFollowerSearch value)  clearFollowerSearch,required TResult Function( _ClearFollowingSearch value)  clearFollowingSearch,required TResult Function( _FollowFromListRequested value)  followFromListRequested,required TResult Function( _UnfollowFromListRequested value)  unfollowFromListRequested,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _RefreshRequested():
return refreshRequested(_that);case _FetchMoreWallsRequested():
return fetchMoreWallsRequested(_that);case _FetchMoreSetupsRequested():
return fetchMoreSetupsRequested(_that);case _FollowRequested():
return followRequested(_that);case _UnfollowRequested():
return unfollowRequested(_that);case _LinksUpdated():
return linksUpdated(_that);case _FetchFollowerSummariesPageRequested():
return fetchFollowerSummariesPageRequested(_that);case _FetchFollowingSummariesPageRequested():
return fetchFollowingSummariesPageRequested(_that);case _SearchFollowerSummariesRequested():
return searchFollowerSummariesRequested(_that);case _SearchFollowingSummariesRequested():
return searchFollowingSummariesRequested(_that);case _ClearFollowerSearch():
return clearFollowerSearch(_that);case _ClearFollowingSearch():
return clearFollowingSearch(_that);case _FollowFromListRequested():
return followFromListRequested(_that);case _UnfollowFromListRequested():
return unfollowFromListRequested(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _RefreshRequested value)?  refreshRequested,TResult? Function( _FetchMoreWallsRequested value)?  fetchMoreWallsRequested,TResult? Function( _FetchMoreSetupsRequested value)?  fetchMoreSetupsRequested,TResult? Function( _FollowRequested value)?  followRequested,TResult? Function( _UnfollowRequested value)?  unfollowRequested,TResult? Function( _LinksUpdated value)?  linksUpdated,TResult? Function( _FetchFollowerSummariesPageRequested value)?  fetchFollowerSummariesPageRequested,TResult? Function( _FetchFollowingSummariesPageRequested value)?  fetchFollowingSummariesPageRequested,TResult? Function( _SearchFollowerSummariesRequested value)?  searchFollowerSummariesRequested,TResult? Function( _SearchFollowingSummariesRequested value)?  searchFollowingSummariesRequested,TResult? Function( _ClearFollowerSearch value)?  clearFollowerSearch,TResult? Function( _ClearFollowingSearch value)?  clearFollowingSearch,TResult? Function( _FollowFromListRequested value)?  followFromListRequested,TResult? Function( _UnfollowFromListRequested value)?  unfollowFromListRequested,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _RefreshRequested() when refreshRequested != null:
return refreshRequested(_that);case _FetchMoreWallsRequested() when fetchMoreWallsRequested != null:
return fetchMoreWallsRequested(_that);case _FetchMoreSetupsRequested() when fetchMoreSetupsRequested != null:
return fetchMoreSetupsRequested(_that);case _FollowRequested() when followRequested != null:
return followRequested(_that);case _UnfollowRequested() when unfollowRequested != null:
return unfollowRequested(_that);case _LinksUpdated() when linksUpdated != null:
return linksUpdated(_that);case _FetchFollowerSummariesPageRequested() when fetchFollowerSummariesPageRequested != null:
return fetchFollowerSummariesPageRequested(_that);case _FetchFollowingSummariesPageRequested() when fetchFollowingSummariesPageRequested != null:
return fetchFollowingSummariesPageRequested(_that);case _SearchFollowerSummariesRequested() when searchFollowerSummariesRequested != null:
return searchFollowerSummariesRequested(_that);case _SearchFollowingSummariesRequested() when searchFollowingSummariesRequested != null:
return searchFollowingSummariesRequested(_that);case _ClearFollowerSearch() when clearFollowerSearch != null:
return clearFollowerSearch(_that);case _ClearFollowingSearch() when clearFollowingSearch != null:
return clearFollowingSearch(_that);case _FollowFromListRequested() when followFromListRequested != null:
return followFromListRequested(_that);case _UnfollowFromListRequested() when unfollowFromListRequested != null:
return unfollowFromListRequested(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String email)?  started,TResult Function()?  refreshRequested,TResult Function()?  fetchMoreWallsRequested,TResult Function()?  fetchMoreSetupsRequested,TResult Function( String currentUserId,  String currentUserEmail)?  followRequested,TResult Function( String currentUserId,  String currentUserEmail)?  unfollowRequested,TResult Function( String userId,  Map<String, String> links)?  linksUpdated,TResult Function( List<String> allEmails,  String currentUserEmail,  int page,  int pageSize)?  fetchFollowerSummariesPageRequested,TResult Function( List<String> allEmails,  String currentUserEmail,  int page,  int pageSize)?  fetchFollowingSummariesPageRequested,TResult Function( String query,  List<String> allEmails,  String currentUserEmail)?  searchFollowerSummariesRequested,TResult Function( String query,  List<String> allEmails,  String currentUserEmail)?  searchFollowingSummariesRequested,TResult Function()?  clearFollowerSearch,TResult Function()?  clearFollowingSearch,TResult Function( String currentUserId,  String currentUserEmail,  String targetUserId,  String targetUserEmail)?  followFromListRequested,TResult Function( String currentUserId,  String currentUserEmail,  String targetUserId,  String targetUserEmail)?  unfollowFromListRequested,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.email);case _RefreshRequested() when refreshRequested != null:
return refreshRequested();case _FetchMoreWallsRequested() when fetchMoreWallsRequested != null:
return fetchMoreWallsRequested();case _FetchMoreSetupsRequested() when fetchMoreSetupsRequested != null:
return fetchMoreSetupsRequested();case _FollowRequested() when followRequested != null:
return followRequested(_that.currentUserId,_that.currentUserEmail);case _UnfollowRequested() when unfollowRequested != null:
return unfollowRequested(_that.currentUserId,_that.currentUserEmail);case _LinksUpdated() when linksUpdated != null:
return linksUpdated(_that.userId,_that.links);case _FetchFollowerSummariesPageRequested() when fetchFollowerSummariesPageRequested != null:
return fetchFollowerSummariesPageRequested(_that.allEmails,_that.currentUserEmail,_that.page,_that.pageSize);case _FetchFollowingSummariesPageRequested() when fetchFollowingSummariesPageRequested != null:
return fetchFollowingSummariesPageRequested(_that.allEmails,_that.currentUserEmail,_that.page,_that.pageSize);case _SearchFollowerSummariesRequested() when searchFollowerSummariesRequested != null:
return searchFollowerSummariesRequested(_that.query,_that.allEmails,_that.currentUserEmail);case _SearchFollowingSummariesRequested() when searchFollowingSummariesRequested != null:
return searchFollowingSummariesRequested(_that.query,_that.allEmails,_that.currentUserEmail);case _ClearFollowerSearch() when clearFollowerSearch != null:
return clearFollowerSearch();case _ClearFollowingSearch() when clearFollowingSearch != null:
return clearFollowingSearch();case _FollowFromListRequested() when followFromListRequested != null:
return followFromListRequested(_that.currentUserId,_that.currentUserEmail,_that.targetUserId,_that.targetUserEmail);case _UnfollowFromListRequested() when unfollowFromListRequested != null:
return unfollowFromListRequested(_that.currentUserId,_that.currentUserEmail,_that.targetUserId,_that.targetUserEmail);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String email)  started,required TResult Function()  refreshRequested,required TResult Function()  fetchMoreWallsRequested,required TResult Function()  fetchMoreSetupsRequested,required TResult Function( String currentUserId,  String currentUserEmail)  followRequested,required TResult Function( String currentUserId,  String currentUserEmail)  unfollowRequested,required TResult Function( String userId,  Map<String, String> links)  linksUpdated,required TResult Function( List<String> allEmails,  String currentUserEmail,  int page,  int pageSize)  fetchFollowerSummariesPageRequested,required TResult Function( List<String> allEmails,  String currentUserEmail,  int page,  int pageSize)  fetchFollowingSummariesPageRequested,required TResult Function( String query,  List<String> allEmails,  String currentUserEmail)  searchFollowerSummariesRequested,required TResult Function( String query,  List<String> allEmails,  String currentUserEmail)  searchFollowingSummariesRequested,required TResult Function()  clearFollowerSearch,required TResult Function()  clearFollowingSearch,required TResult Function( String currentUserId,  String currentUserEmail,  String targetUserId,  String targetUserEmail)  followFromListRequested,required TResult Function( String currentUserId,  String currentUserEmail,  String targetUserId,  String targetUserEmail)  unfollowFromListRequested,}) {final _that = this;
switch (_that) {
case _Started():
return started(_that.email);case _RefreshRequested():
return refreshRequested();case _FetchMoreWallsRequested():
return fetchMoreWallsRequested();case _FetchMoreSetupsRequested():
return fetchMoreSetupsRequested();case _FollowRequested():
return followRequested(_that.currentUserId,_that.currentUserEmail);case _UnfollowRequested():
return unfollowRequested(_that.currentUserId,_that.currentUserEmail);case _LinksUpdated():
return linksUpdated(_that.userId,_that.links);case _FetchFollowerSummariesPageRequested():
return fetchFollowerSummariesPageRequested(_that.allEmails,_that.currentUserEmail,_that.page,_that.pageSize);case _FetchFollowingSummariesPageRequested():
return fetchFollowingSummariesPageRequested(_that.allEmails,_that.currentUserEmail,_that.page,_that.pageSize);case _SearchFollowerSummariesRequested():
return searchFollowerSummariesRequested(_that.query,_that.allEmails,_that.currentUserEmail);case _SearchFollowingSummariesRequested():
return searchFollowingSummariesRequested(_that.query,_that.allEmails,_that.currentUserEmail);case _ClearFollowerSearch():
return clearFollowerSearch();case _ClearFollowingSearch():
return clearFollowingSearch();case _FollowFromListRequested():
return followFromListRequested(_that.currentUserId,_that.currentUserEmail,_that.targetUserId,_that.targetUserEmail);case _UnfollowFromListRequested():
return unfollowFromListRequested(_that.currentUserId,_that.currentUserEmail,_that.targetUserId,_that.targetUserEmail);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String email)?  started,TResult? Function()?  refreshRequested,TResult? Function()?  fetchMoreWallsRequested,TResult? Function()?  fetchMoreSetupsRequested,TResult? Function( String currentUserId,  String currentUserEmail)?  followRequested,TResult? Function( String currentUserId,  String currentUserEmail)?  unfollowRequested,TResult? Function( String userId,  Map<String, String> links)?  linksUpdated,TResult? Function( List<String> allEmails,  String currentUserEmail,  int page,  int pageSize)?  fetchFollowerSummariesPageRequested,TResult? Function( List<String> allEmails,  String currentUserEmail,  int page,  int pageSize)?  fetchFollowingSummariesPageRequested,TResult? Function( String query,  List<String> allEmails,  String currentUserEmail)?  searchFollowerSummariesRequested,TResult? Function( String query,  List<String> allEmails,  String currentUserEmail)?  searchFollowingSummariesRequested,TResult? Function()?  clearFollowerSearch,TResult? Function()?  clearFollowingSearch,TResult? Function( String currentUserId,  String currentUserEmail,  String targetUserId,  String targetUserEmail)?  followFromListRequested,TResult? Function( String currentUserId,  String currentUserEmail,  String targetUserId,  String targetUserEmail)?  unfollowFromListRequested,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.email);case _RefreshRequested() when refreshRequested != null:
return refreshRequested();case _FetchMoreWallsRequested() when fetchMoreWallsRequested != null:
return fetchMoreWallsRequested();case _FetchMoreSetupsRequested() when fetchMoreSetupsRequested != null:
return fetchMoreSetupsRequested();case _FollowRequested() when followRequested != null:
return followRequested(_that.currentUserId,_that.currentUserEmail);case _UnfollowRequested() when unfollowRequested != null:
return unfollowRequested(_that.currentUserId,_that.currentUserEmail);case _LinksUpdated() when linksUpdated != null:
return linksUpdated(_that.userId,_that.links);case _FetchFollowerSummariesPageRequested() when fetchFollowerSummariesPageRequested != null:
return fetchFollowerSummariesPageRequested(_that.allEmails,_that.currentUserEmail,_that.page,_that.pageSize);case _FetchFollowingSummariesPageRequested() when fetchFollowingSummariesPageRequested != null:
return fetchFollowingSummariesPageRequested(_that.allEmails,_that.currentUserEmail,_that.page,_that.pageSize);case _SearchFollowerSummariesRequested() when searchFollowerSummariesRequested != null:
return searchFollowerSummariesRequested(_that.query,_that.allEmails,_that.currentUserEmail);case _SearchFollowingSummariesRequested() when searchFollowingSummariesRequested != null:
return searchFollowingSummariesRequested(_that.query,_that.allEmails,_that.currentUserEmail);case _ClearFollowerSearch() when clearFollowerSearch != null:
return clearFollowerSearch();case _ClearFollowingSearch() when clearFollowingSearch != null:
return clearFollowingSearch();case _FollowFromListRequested() when followFromListRequested != null:
return followFromListRequested(_that.currentUserId,_that.currentUserEmail,_that.targetUserId,_that.targetUserEmail);case _UnfollowFromListRequested() when unfollowFromListRequested != null:
return unfollowFromListRequested(_that.currentUserId,_that.currentUserEmail,_that.targetUserId,_that.targetUserEmail);case _:
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


class _FetchFollowerSummariesPageRequested implements PublicProfileEvent {
  const _FetchFollowerSummariesPageRequested({required final  List<String> allEmails, required this.currentUserEmail, required this.page, this.pageSize = 20}): _allEmails = allEmails;
  

 final  List<String> _allEmails;
 List<String> get allEmails {
  if (_allEmails is EqualUnmodifiableListView) return _allEmails;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_allEmails);
}

 final  String currentUserEmail;
 final  int page;
@JsonKey() final  int pageSize;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FetchFollowerSummariesPageRequestedCopyWith<_FetchFollowerSummariesPageRequested> get copyWith => __$FetchFollowerSummariesPageRequestedCopyWithImpl<_FetchFollowerSummariesPageRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FetchFollowerSummariesPageRequested&&const DeepCollectionEquality().equals(other._allEmails, _allEmails)&&(identical(other.currentUserEmail, currentUserEmail) || other.currentUserEmail == currentUserEmail)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_allEmails),currentUserEmail,page,pageSize);

@override
String toString() {
  return 'PublicProfileEvent.fetchFollowerSummariesPageRequested(allEmails: $allEmails, currentUserEmail: $currentUserEmail, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class _$FetchFollowerSummariesPageRequestedCopyWith<$Res> implements $PublicProfileEventCopyWith<$Res> {
  factory _$FetchFollowerSummariesPageRequestedCopyWith(_FetchFollowerSummariesPageRequested value, $Res Function(_FetchFollowerSummariesPageRequested) _then) = __$FetchFollowerSummariesPageRequestedCopyWithImpl;
@useResult
$Res call({
 List<String> allEmails, String currentUserEmail, int page, int pageSize
});




}
/// @nodoc
class __$FetchFollowerSummariesPageRequestedCopyWithImpl<$Res>
    implements _$FetchFollowerSummariesPageRequestedCopyWith<$Res> {
  __$FetchFollowerSummariesPageRequestedCopyWithImpl(this._self, this._then);

  final _FetchFollowerSummariesPageRequested _self;
  final $Res Function(_FetchFollowerSummariesPageRequested) _then;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? allEmails = null,Object? currentUserEmail = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_FetchFollowerSummariesPageRequested(
allEmails: null == allEmails ? _self._allEmails : allEmails // ignore: cast_nullable_to_non_nullable
as List<String>,currentUserEmail: null == currentUserEmail ? _self.currentUserEmail : currentUserEmail // ignore: cast_nullable_to_non_nullable
as String,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _FetchFollowingSummariesPageRequested implements PublicProfileEvent {
  const _FetchFollowingSummariesPageRequested({required final  List<String> allEmails, required this.currentUserEmail, required this.page, this.pageSize = 20}): _allEmails = allEmails;
  

 final  List<String> _allEmails;
 List<String> get allEmails {
  if (_allEmails is EqualUnmodifiableListView) return _allEmails;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_allEmails);
}

 final  String currentUserEmail;
 final  int page;
@JsonKey() final  int pageSize;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FetchFollowingSummariesPageRequestedCopyWith<_FetchFollowingSummariesPageRequested> get copyWith => __$FetchFollowingSummariesPageRequestedCopyWithImpl<_FetchFollowingSummariesPageRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FetchFollowingSummariesPageRequested&&const DeepCollectionEquality().equals(other._allEmails, _allEmails)&&(identical(other.currentUserEmail, currentUserEmail) || other.currentUserEmail == currentUserEmail)&&(identical(other.page, page) || other.page == page)&&(identical(other.pageSize, pageSize) || other.pageSize == pageSize));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_allEmails),currentUserEmail,page,pageSize);

@override
String toString() {
  return 'PublicProfileEvent.fetchFollowingSummariesPageRequested(allEmails: $allEmails, currentUserEmail: $currentUserEmail, page: $page, pageSize: $pageSize)';
}


}

/// @nodoc
abstract mixin class _$FetchFollowingSummariesPageRequestedCopyWith<$Res> implements $PublicProfileEventCopyWith<$Res> {
  factory _$FetchFollowingSummariesPageRequestedCopyWith(_FetchFollowingSummariesPageRequested value, $Res Function(_FetchFollowingSummariesPageRequested) _then) = __$FetchFollowingSummariesPageRequestedCopyWithImpl;
@useResult
$Res call({
 List<String> allEmails, String currentUserEmail, int page, int pageSize
});




}
/// @nodoc
class __$FetchFollowingSummariesPageRequestedCopyWithImpl<$Res>
    implements _$FetchFollowingSummariesPageRequestedCopyWith<$Res> {
  __$FetchFollowingSummariesPageRequestedCopyWithImpl(this._self, this._then);

  final _FetchFollowingSummariesPageRequested _self;
  final $Res Function(_FetchFollowingSummariesPageRequested) _then;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? allEmails = null,Object? currentUserEmail = null,Object? page = null,Object? pageSize = null,}) {
  return _then(_FetchFollowingSummariesPageRequested(
allEmails: null == allEmails ? _self._allEmails : allEmails // ignore: cast_nullable_to_non_nullable
as List<String>,currentUserEmail: null == currentUserEmail ? _self.currentUserEmail : currentUserEmail // ignore: cast_nullable_to_non_nullable
as String,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,pageSize: null == pageSize ? _self.pageSize : pageSize // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _SearchFollowerSummariesRequested implements PublicProfileEvent {
  const _SearchFollowerSummariesRequested({required this.query, required final  List<String> allEmails, required this.currentUserEmail}): _allEmails = allEmails;
  

 final  String query;
 final  List<String> _allEmails;
 List<String> get allEmails {
  if (_allEmails is EqualUnmodifiableListView) return _allEmails;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_allEmails);
}

 final  String currentUserEmail;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SearchFollowerSummariesRequestedCopyWith<_SearchFollowerSummariesRequested> get copyWith => __$SearchFollowerSummariesRequestedCopyWithImpl<_SearchFollowerSummariesRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SearchFollowerSummariesRequested&&(identical(other.query, query) || other.query == query)&&const DeepCollectionEquality().equals(other._allEmails, _allEmails)&&(identical(other.currentUserEmail, currentUserEmail) || other.currentUserEmail == currentUserEmail));
}


@override
int get hashCode => Object.hash(runtimeType,query,const DeepCollectionEquality().hash(_allEmails),currentUserEmail);

@override
String toString() {
  return 'PublicProfileEvent.searchFollowerSummariesRequested(query: $query, allEmails: $allEmails, currentUserEmail: $currentUserEmail)';
}


}

/// @nodoc
abstract mixin class _$SearchFollowerSummariesRequestedCopyWith<$Res> implements $PublicProfileEventCopyWith<$Res> {
  factory _$SearchFollowerSummariesRequestedCopyWith(_SearchFollowerSummariesRequested value, $Res Function(_SearchFollowerSummariesRequested) _then) = __$SearchFollowerSummariesRequestedCopyWithImpl;
@useResult
$Res call({
 String query, List<String> allEmails, String currentUserEmail
});




}
/// @nodoc
class __$SearchFollowerSummariesRequestedCopyWithImpl<$Res>
    implements _$SearchFollowerSummariesRequestedCopyWith<$Res> {
  __$SearchFollowerSummariesRequestedCopyWithImpl(this._self, this._then);

  final _SearchFollowerSummariesRequested _self;
  final $Res Function(_SearchFollowerSummariesRequested) _then;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? query = null,Object? allEmails = null,Object? currentUserEmail = null,}) {
  return _then(_SearchFollowerSummariesRequested(
query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,allEmails: null == allEmails ? _self._allEmails : allEmails // ignore: cast_nullable_to_non_nullable
as List<String>,currentUserEmail: null == currentUserEmail ? _self.currentUserEmail : currentUserEmail // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _SearchFollowingSummariesRequested implements PublicProfileEvent {
  const _SearchFollowingSummariesRequested({required this.query, required final  List<String> allEmails, required this.currentUserEmail}): _allEmails = allEmails;
  

 final  String query;
 final  List<String> _allEmails;
 List<String> get allEmails {
  if (_allEmails is EqualUnmodifiableListView) return _allEmails;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_allEmails);
}

 final  String currentUserEmail;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SearchFollowingSummariesRequestedCopyWith<_SearchFollowingSummariesRequested> get copyWith => __$SearchFollowingSummariesRequestedCopyWithImpl<_SearchFollowingSummariesRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SearchFollowingSummariesRequested&&(identical(other.query, query) || other.query == query)&&const DeepCollectionEquality().equals(other._allEmails, _allEmails)&&(identical(other.currentUserEmail, currentUserEmail) || other.currentUserEmail == currentUserEmail));
}


@override
int get hashCode => Object.hash(runtimeType,query,const DeepCollectionEquality().hash(_allEmails),currentUserEmail);

@override
String toString() {
  return 'PublicProfileEvent.searchFollowingSummariesRequested(query: $query, allEmails: $allEmails, currentUserEmail: $currentUserEmail)';
}


}

/// @nodoc
abstract mixin class _$SearchFollowingSummariesRequestedCopyWith<$Res> implements $PublicProfileEventCopyWith<$Res> {
  factory _$SearchFollowingSummariesRequestedCopyWith(_SearchFollowingSummariesRequested value, $Res Function(_SearchFollowingSummariesRequested) _then) = __$SearchFollowingSummariesRequestedCopyWithImpl;
@useResult
$Res call({
 String query, List<String> allEmails, String currentUserEmail
});




}
/// @nodoc
class __$SearchFollowingSummariesRequestedCopyWithImpl<$Res>
    implements _$SearchFollowingSummariesRequestedCopyWith<$Res> {
  __$SearchFollowingSummariesRequestedCopyWithImpl(this._self, this._then);

  final _SearchFollowingSummariesRequested _self;
  final $Res Function(_SearchFollowingSummariesRequested) _then;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? query = null,Object? allEmails = null,Object? currentUserEmail = null,}) {
  return _then(_SearchFollowingSummariesRequested(
query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,allEmails: null == allEmails ? _self._allEmails : allEmails // ignore: cast_nullable_to_non_nullable
as List<String>,currentUserEmail: null == currentUserEmail ? _self.currentUserEmail : currentUserEmail // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _ClearFollowerSearch implements PublicProfileEvent {
  const _ClearFollowerSearch();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClearFollowerSearch);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PublicProfileEvent.clearFollowerSearch()';
}


}




/// @nodoc


class _ClearFollowingSearch implements PublicProfileEvent {
  const _ClearFollowingSearch();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClearFollowingSearch);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PublicProfileEvent.clearFollowingSearch()';
}


}




/// @nodoc


class _FollowFromListRequested implements PublicProfileEvent {
  const _FollowFromListRequested({required this.currentUserId, required this.currentUserEmail, required this.targetUserId, required this.targetUserEmail});
  

 final  String currentUserId;
 final  String currentUserEmail;
 final  String targetUserId;
 final  String targetUserEmail;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FollowFromListRequestedCopyWith<_FollowFromListRequested> get copyWith => __$FollowFromListRequestedCopyWithImpl<_FollowFromListRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FollowFromListRequested&&(identical(other.currentUserId, currentUserId) || other.currentUserId == currentUserId)&&(identical(other.currentUserEmail, currentUserEmail) || other.currentUserEmail == currentUserEmail)&&(identical(other.targetUserId, targetUserId) || other.targetUserId == targetUserId)&&(identical(other.targetUserEmail, targetUserEmail) || other.targetUserEmail == targetUserEmail));
}


@override
int get hashCode => Object.hash(runtimeType,currentUserId,currentUserEmail,targetUserId,targetUserEmail);

@override
String toString() {
  return 'PublicProfileEvent.followFromListRequested(currentUserId: $currentUserId, currentUserEmail: $currentUserEmail, targetUserId: $targetUserId, targetUserEmail: $targetUserEmail)';
}


}

/// @nodoc
abstract mixin class _$FollowFromListRequestedCopyWith<$Res> implements $PublicProfileEventCopyWith<$Res> {
  factory _$FollowFromListRequestedCopyWith(_FollowFromListRequested value, $Res Function(_FollowFromListRequested) _then) = __$FollowFromListRequestedCopyWithImpl;
@useResult
$Res call({
 String currentUserId, String currentUserEmail, String targetUserId, String targetUserEmail
});




}
/// @nodoc
class __$FollowFromListRequestedCopyWithImpl<$Res>
    implements _$FollowFromListRequestedCopyWith<$Res> {
  __$FollowFromListRequestedCopyWithImpl(this._self, this._then);

  final _FollowFromListRequested _self;
  final $Res Function(_FollowFromListRequested) _then;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? currentUserId = null,Object? currentUserEmail = null,Object? targetUserId = null,Object? targetUserEmail = null,}) {
  return _then(_FollowFromListRequested(
currentUserId: null == currentUserId ? _self.currentUserId : currentUserId // ignore: cast_nullable_to_non_nullable
as String,currentUserEmail: null == currentUserEmail ? _self.currentUserEmail : currentUserEmail // ignore: cast_nullable_to_non_nullable
as String,targetUserId: null == targetUserId ? _self.targetUserId : targetUserId // ignore: cast_nullable_to_non_nullable
as String,targetUserEmail: null == targetUserEmail ? _self.targetUserEmail : targetUserEmail // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _UnfollowFromListRequested implements PublicProfileEvent {
  const _UnfollowFromListRequested({required this.currentUserId, required this.currentUserEmail, required this.targetUserId, required this.targetUserEmail});
  

 final  String currentUserId;
 final  String currentUserEmail;
 final  String targetUserId;
 final  String targetUserEmail;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UnfollowFromListRequestedCopyWith<_UnfollowFromListRequested> get copyWith => __$UnfollowFromListRequestedCopyWithImpl<_UnfollowFromListRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UnfollowFromListRequested&&(identical(other.currentUserId, currentUserId) || other.currentUserId == currentUserId)&&(identical(other.currentUserEmail, currentUserEmail) || other.currentUserEmail == currentUserEmail)&&(identical(other.targetUserId, targetUserId) || other.targetUserId == targetUserId)&&(identical(other.targetUserEmail, targetUserEmail) || other.targetUserEmail == targetUserEmail));
}


@override
int get hashCode => Object.hash(runtimeType,currentUserId,currentUserEmail,targetUserId,targetUserEmail);

@override
String toString() {
  return 'PublicProfileEvent.unfollowFromListRequested(currentUserId: $currentUserId, currentUserEmail: $currentUserEmail, targetUserId: $targetUserId, targetUserEmail: $targetUserEmail)';
}


}

/// @nodoc
abstract mixin class _$UnfollowFromListRequestedCopyWith<$Res> implements $PublicProfileEventCopyWith<$Res> {
  factory _$UnfollowFromListRequestedCopyWith(_UnfollowFromListRequested value, $Res Function(_UnfollowFromListRequested) _then) = __$UnfollowFromListRequestedCopyWithImpl;
@useResult
$Res call({
 String currentUserId, String currentUserEmail, String targetUserId, String targetUserEmail
});




}
/// @nodoc
class __$UnfollowFromListRequestedCopyWithImpl<$Res>
    implements _$UnfollowFromListRequestedCopyWith<$Res> {
  __$UnfollowFromListRequestedCopyWithImpl(this._self, this._then);

  final _UnfollowFromListRequested _self;
  final $Res Function(_UnfollowFromListRequested) _then;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? currentUserId = null,Object? currentUserEmail = null,Object? targetUserId = null,Object? targetUserEmail = null,}) {
  return _then(_UnfollowFromListRequested(
currentUserId: null == currentUserId ? _self.currentUserId : currentUserId // ignore: cast_nullable_to_non_nullable
as String,currentUserEmail: null == currentUserEmail ? _self.currentUserEmail : currentUserEmail // ignore: cast_nullable_to_non_nullable
as String,targetUserId: null == targetUserId ? _self.targetUserId : targetUserId // ignore: cast_nullable_to_non_nullable
as String,targetUserEmail: null == targetUserEmail ? _self.targetUserEmail : targetUserEmail // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$PublicProfileState {

 LoadStatus get status; ActionStatus get actionStatus; String get email; PublicProfileEntity get profile; List<PublicProfileWallEntity> get walls; List<PublicProfileSetupEntity> get setups; bool get hasMoreWalls; bool get hasMoreSetups; String? get wallsCursor; String? get setupsCursor; bool get isFetchingMoreWalls; bool get isFetchingMoreSetups;/// Follower profiles loaded for the followers list screen (paginated).
 List<UserSummaryEntity> get followerSummaries;/// Following profiles loaded for the following list screen (paginated).
 List<UserSummaryEntity> get followingSummaries;/// Whether follower summaries are currently being loaded/searched.
 bool get isFetchingFollowers;/// Whether following summaries are currently being loaded/searched.
 bool get isFetchingFollowing;/// Current page loaded for followers (zero-indexed).
 int get followerPage;/// Current page loaded for following (zero-indexed).
 int get followingPage;/// Whether more follower pages are available.
 bool get hasMoreFollowers;/// Whether more following pages are available.
 bool get hasMoreFollowing;/// Active follower search results. `null` means no search is active.
 List<UserSummaryEntity>? get followerSearchResults;/// Active following search results. `null` means no search is active.
 List<UserSummaryEntity>? get followingSearchResults;/// Whether a follower search is in progress.
 bool get isSearchingFollowers;/// Whether a following search is in progress.
 bool get isSearchingFollowing; Failure? get failure;
/// Create a copy of PublicProfileState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicProfileStateCopyWith<PublicProfileState> get copyWith => _$PublicProfileStateCopyWithImpl<PublicProfileState>(this as PublicProfileState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicProfileState&&(identical(other.status, status) || other.status == status)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&(identical(other.email, email) || other.email == email)&&(identical(other.profile, profile) || other.profile == profile)&&const DeepCollectionEquality().equals(other.walls, walls)&&const DeepCollectionEquality().equals(other.setups, setups)&&(identical(other.hasMoreWalls, hasMoreWalls) || other.hasMoreWalls == hasMoreWalls)&&(identical(other.hasMoreSetups, hasMoreSetups) || other.hasMoreSetups == hasMoreSetups)&&(identical(other.wallsCursor, wallsCursor) || other.wallsCursor == wallsCursor)&&(identical(other.setupsCursor, setupsCursor) || other.setupsCursor == setupsCursor)&&(identical(other.isFetchingMoreWalls, isFetchingMoreWalls) || other.isFetchingMoreWalls == isFetchingMoreWalls)&&(identical(other.isFetchingMoreSetups, isFetchingMoreSetups) || other.isFetchingMoreSetups == isFetchingMoreSetups)&&const DeepCollectionEquality().equals(other.followerSummaries, followerSummaries)&&const DeepCollectionEquality().equals(other.followingSummaries, followingSummaries)&&(identical(other.isFetchingFollowers, isFetchingFollowers) || other.isFetchingFollowers == isFetchingFollowers)&&(identical(other.isFetchingFollowing, isFetchingFollowing) || other.isFetchingFollowing == isFetchingFollowing)&&(identical(other.followerPage, followerPage) || other.followerPage == followerPage)&&(identical(other.followingPage, followingPage) || other.followingPage == followingPage)&&(identical(other.hasMoreFollowers, hasMoreFollowers) || other.hasMoreFollowers == hasMoreFollowers)&&(identical(other.hasMoreFollowing, hasMoreFollowing) || other.hasMoreFollowing == hasMoreFollowing)&&const DeepCollectionEquality().equals(other.followerSearchResults, followerSearchResults)&&const DeepCollectionEquality().equals(other.followingSearchResults, followingSearchResults)&&(identical(other.isSearchingFollowers, isSearchingFollowers) || other.isSearchingFollowers == isSearchingFollowers)&&(identical(other.isSearchingFollowing, isSearchingFollowing) || other.isSearchingFollowing == isSearchingFollowing)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hashAll([runtimeType,status,actionStatus,email,profile,const DeepCollectionEquality().hash(walls),const DeepCollectionEquality().hash(setups),hasMoreWalls,hasMoreSetups,wallsCursor,setupsCursor,isFetchingMoreWalls,isFetchingMoreSetups,const DeepCollectionEquality().hash(followerSummaries),const DeepCollectionEquality().hash(followingSummaries),isFetchingFollowers,isFetchingFollowing,followerPage,followingPage,hasMoreFollowers,hasMoreFollowing,const DeepCollectionEquality().hash(followerSearchResults),const DeepCollectionEquality().hash(followingSearchResults),isSearchingFollowers,isSearchingFollowing,failure]);

@override
String toString() {
  return 'PublicProfileState(status: $status, actionStatus: $actionStatus, email: $email, profile: $profile, walls: $walls, setups: $setups, hasMoreWalls: $hasMoreWalls, hasMoreSetups: $hasMoreSetups, wallsCursor: $wallsCursor, setupsCursor: $setupsCursor, isFetchingMoreWalls: $isFetchingMoreWalls, isFetchingMoreSetups: $isFetchingMoreSetups, followerSummaries: $followerSummaries, followingSummaries: $followingSummaries, isFetchingFollowers: $isFetchingFollowers, isFetchingFollowing: $isFetchingFollowing, followerPage: $followerPage, followingPage: $followingPage, hasMoreFollowers: $hasMoreFollowers, hasMoreFollowing: $hasMoreFollowing, followerSearchResults: $followerSearchResults, followingSearchResults: $followingSearchResults, isSearchingFollowers: $isSearchingFollowers, isSearchingFollowing: $isSearchingFollowing, failure: $failure)';
}


}

/// @nodoc
abstract mixin class $PublicProfileStateCopyWith<$Res>  {
  factory $PublicProfileStateCopyWith(PublicProfileState value, $Res Function(PublicProfileState) _then) = _$PublicProfileStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, ActionStatus actionStatus, String email, PublicProfileEntity profile, List<PublicProfileWallEntity> walls, List<PublicProfileSetupEntity> setups, bool hasMoreWalls, bool hasMoreSetups, String? wallsCursor, String? setupsCursor, bool isFetchingMoreWalls, bool isFetchingMoreSetups, List<UserSummaryEntity> followerSummaries, List<UserSummaryEntity> followingSummaries, bool isFetchingFollowers, bool isFetchingFollowing, int followerPage, int followingPage, bool hasMoreFollowers, bool hasMoreFollowing, List<UserSummaryEntity>? followerSearchResults, List<UserSummaryEntity>? followingSearchResults, bool isSearchingFollowers, bool isSearchingFollowing, Failure? failure
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
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? actionStatus = null,Object? email = null,Object? profile = null,Object? walls = null,Object? setups = null,Object? hasMoreWalls = null,Object? hasMoreSetups = null,Object? wallsCursor = freezed,Object? setupsCursor = freezed,Object? isFetchingMoreWalls = null,Object? isFetchingMoreSetups = null,Object? followerSummaries = null,Object? followingSummaries = null,Object? isFetchingFollowers = null,Object? isFetchingFollowing = null,Object? followerPage = null,Object? followingPage = null,Object? hasMoreFollowers = null,Object? hasMoreFollowing = null,Object? followerSearchResults = freezed,Object? followingSearchResults = freezed,Object? isSearchingFollowers = null,Object? isSearchingFollowing = null,Object? failure = freezed,}) {
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
as bool,followerSummaries: null == followerSummaries ? _self.followerSummaries : followerSummaries // ignore: cast_nullable_to_non_nullable
as List<UserSummaryEntity>,followingSummaries: null == followingSummaries ? _self.followingSummaries : followingSummaries // ignore: cast_nullable_to_non_nullable
as List<UserSummaryEntity>,isFetchingFollowers: null == isFetchingFollowers ? _self.isFetchingFollowers : isFetchingFollowers // ignore: cast_nullable_to_non_nullable
as bool,isFetchingFollowing: null == isFetchingFollowing ? _self.isFetchingFollowing : isFetchingFollowing // ignore: cast_nullable_to_non_nullable
as bool,followerPage: null == followerPage ? _self.followerPage : followerPage // ignore: cast_nullable_to_non_nullable
as int,followingPage: null == followingPage ? _self.followingPage : followingPage // ignore: cast_nullable_to_non_nullable
as int,hasMoreFollowers: null == hasMoreFollowers ? _self.hasMoreFollowers : hasMoreFollowers // ignore: cast_nullable_to_non_nullable
as bool,hasMoreFollowing: null == hasMoreFollowing ? _self.hasMoreFollowing : hasMoreFollowing // ignore: cast_nullable_to_non_nullable
as bool,followerSearchResults: freezed == followerSearchResults ? _self.followerSearchResults : followerSearchResults // ignore: cast_nullable_to_non_nullable
as List<UserSummaryEntity>?,followingSearchResults: freezed == followingSearchResults ? _self.followingSearchResults : followingSearchResults // ignore: cast_nullable_to_non_nullable
as List<UserSummaryEntity>?,isSearchingFollowers: null == isSearchingFollowers ? _self.isSearchingFollowers : isSearchingFollowers // ignore: cast_nullable_to_non_nullable
as bool,isSearchingFollowing: null == isSearchingFollowing ? _self.isSearchingFollowing : isSearchingFollowing // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  ActionStatus actionStatus,  String email,  PublicProfileEntity profile,  List<PublicProfileWallEntity> walls,  List<PublicProfileSetupEntity> setups,  bool hasMoreWalls,  bool hasMoreSetups,  String? wallsCursor,  String? setupsCursor,  bool isFetchingMoreWalls,  bool isFetchingMoreSetups,  List<UserSummaryEntity> followerSummaries,  List<UserSummaryEntity> followingSummaries,  bool isFetchingFollowers,  bool isFetchingFollowing,  int followerPage,  int followingPage,  bool hasMoreFollowers,  bool hasMoreFollowing,  List<UserSummaryEntity>? followerSearchResults,  List<UserSummaryEntity>? followingSearchResults,  bool isSearchingFollowers,  bool isSearchingFollowing,  Failure? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublicProfileState() when $default != null:
return $default(_that.status,_that.actionStatus,_that.email,_that.profile,_that.walls,_that.setups,_that.hasMoreWalls,_that.hasMoreSetups,_that.wallsCursor,_that.setupsCursor,_that.isFetchingMoreWalls,_that.isFetchingMoreSetups,_that.followerSummaries,_that.followingSummaries,_that.isFetchingFollowers,_that.isFetchingFollowing,_that.followerPage,_that.followingPage,_that.hasMoreFollowers,_that.hasMoreFollowing,_that.followerSearchResults,_that.followingSearchResults,_that.isSearchingFollowers,_that.isSearchingFollowing,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  ActionStatus actionStatus,  String email,  PublicProfileEntity profile,  List<PublicProfileWallEntity> walls,  List<PublicProfileSetupEntity> setups,  bool hasMoreWalls,  bool hasMoreSetups,  String? wallsCursor,  String? setupsCursor,  bool isFetchingMoreWalls,  bool isFetchingMoreSetups,  List<UserSummaryEntity> followerSummaries,  List<UserSummaryEntity> followingSummaries,  bool isFetchingFollowers,  bool isFetchingFollowing,  int followerPage,  int followingPage,  bool hasMoreFollowers,  bool hasMoreFollowing,  List<UserSummaryEntity>? followerSearchResults,  List<UserSummaryEntity>? followingSearchResults,  bool isSearchingFollowers,  bool isSearchingFollowing,  Failure? failure)  $default,) {final _that = this;
switch (_that) {
case _PublicProfileState():
return $default(_that.status,_that.actionStatus,_that.email,_that.profile,_that.walls,_that.setups,_that.hasMoreWalls,_that.hasMoreSetups,_that.wallsCursor,_that.setupsCursor,_that.isFetchingMoreWalls,_that.isFetchingMoreSetups,_that.followerSummaries,_that.followingSummaries,_that.isFetchingFollowers,_that.isFetchingFollowing,_that.followerPage,_that.followingPage,_that.hasMoreFollowers,_that.hasMoreFollowing,_that.followerSearchResults,_that.followingSearchResults,_that.isSearchingFollowers,_that.isSearchingFollowing,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  ActionStatus actionStatus,  String email,  PublicProfileEntity profile,  List<PublicProfileWallEntity> walls,  List<PublicProfileSetupEntity> setups,  bool hasMoreWalls,  bool hasMoreSetups,  String? wallsCursor,  String? setupsCursor,  bool isFetchingMoreWalls,  bool isFetchingMoreSetups,  List<UserSummaryEntity> followerSummaries,  List<UserSummaryEntity> followingSummaries,  bool isFetchingFollowers,  bool isFetchingFollowing,  int followerPage,  int followingPage,  bool hasMoreFollowers,  bool hasMoreFollowing,  List<UserSummaryEntity>? followerSearchResults,  List<UserSummaryEntity>? followingSearchResults,  bool isSearchingFollowers,  bool isSearchingFollowing,  Failure? failure)?  $default,) {final _that = this;
switch (_that) {
case _PublicProfileState() when $default != null:
return $default(_that.status,_that.actionStatus,_that.email,_that.profile,_that.walls,_that.setups,_that.hasMoreWalls,_that.hasMoreSetups,_that.wallsCursor,_that.setupsCursor,_that.isFetchingMoreWalls,_that.isFetchingMoreSetups,_that.followerSummaries,_that.followingSummaries,_that.isFetchingFollowers,_that.isFetchingFollowing,_that.followerPage,_that.followingPage,_that.hasMoreFollowers,_that.hasMoreFollowing,_that.followerSearchResults,_that.followingSearchResults,_that.isSearchingFollowers,_that.isSearchingFollowing,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _PublicProfileState implements PublicProfileState {
  const _PublicProfileState({required this.status, required this.actionStatus, required this.email, required this.profile, required final  List<PublicProfileWallEntity> walls, required final  List<PublicProfileSetupEntity> setups, required this.hasMoreWalls, required this.hasMoreSetups, required this.wallsCursor, required this.setupsCursor, required this.isFetchingMoreWalls, required this.isFetchingMoreSetups, required final  List<UserSummaryEntity> followerSummaries, required final  List<UserSummaryEntity> followingSummaries, required this.isFetchingFollowers, required this.isFetchingFollowing, required this.followerPage, required this.followingPage, required this.hasMoreFollowers, required this.hasMoreFollowing, final  List<UserSummaryEntity>? followerSearchResults, final  List<UserSummaryEntity>? followingSearchResults, required this.isSearchingFollowers, required this.isSearchingFollowing, this.failure}): _walls = walls,_setups = setups,_followerSummaries = followerSummaries,_followingSummaries = followingSummaries,_followerSearchResults = followerSearchResults,_followingSearchResults = followingSearchResults;
  

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
/// Follower profiles loaded for the followers list screen (paginated).
 final  List<UserSummaryEntity> _followerSummaries;
/// Follower profiles loaded for the followers list screen (paginated).
@override List<UserSummaryEntity> get followerSummaries {
  if (_followerSummaries is EqualUnmodifiableListView) return _followerSummaries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_followerSummaries);
}

/// Following profiles loaded for the following list screen (paginated).
 final  List<UserSummaryEntity> _followingSummaries;
/// Following profiles loaded for the following list screen (paginated).
@override List<UserSummaryEntity> get followingSummaries {
  if (_followingSummaries is EqualUnmodifiableListView) return _followingSummaries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_followingSummaries);
}

/// Whether follower summaries are currently being loaded/searched.
@override final  bool isFetchingFollowers;
/// Whether following summaries are currently being loaded/searched.
@override final  bool isFetchingFollowing;
/// Current page loaded for followers (zero-indexed).
@override final  int followerPage;
/// Current page loaded for following (zero-indexed).
@override final  int followingPage;
/// Whether more follower pages are available.
@override final  bool hasMoreFollowers;
/// Whether more following pages are available.
@override final  bool hasMoreFollowing;
/// Active follower search results. `null` means no search is active.
 final  List<UserSummaryEntity>? _followerSearchResults;
/// Active follower search results. `null` means no search is active.
@override List<UserSummaryEntity>? get followerSearchResults {
  final value = _followerSearchResults;
  if (value == null) return null;
  if (_followerSearchResults is EqualUnmodifiableListView) return _followerSearchResults;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// Active following search results. `null` means no search is active.
 final  List<UserSummaryEntity>? _followingSearchResults;
/// Active following search results. `null` means no search is active.
@override List<UserSummaryEntity>? get followingSearchResults {
  final value = _followingSearchResults;
  if (value == null) return null;
  if (_followingSearchResults is EqualUnmodifiableListView) return _followingSearchResults;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

/// Whether a follower search is in progress.
@override final  bool isSearchingFollowers;
/// Whether a following search is in progress.
@override final  bool isSearchingFollowing;
@override final  Failure? failure;

/// Create a copy of PublicProfileState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PublicProfileStateCopyWith<_PublicProfileState> get copyWith => __$PublicProfileStateCopyWithImpl<_PublicProfileState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublicProfileState&&(identical(other.status, status) || other.status == status)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&(identical(other.email, email) || other.email == email)&&(identical(other.profile, profile) || other.profile == profile)&&const DeepCollectionEquality().equals(other._walls, _walls)&&const DeepCollectionEquality().equals(other._setups, _setups)&&(identical(other.hasMoreWalls, hasMoreWalls) || other.hasMoreWalls == hasMoreWalls)&&(identical(other.hasMoreSetups, hasMoreSetups) || other.hasMoreSetups == hasMoreSetups)&&(identical(other.wallsCursor, wallsCursor) || other.wallsCursor == wallsCursor)&&(identical(other.setupsCursor, setupsCursor) || other.setupsCursor == setupsCursor)&&(identical(other.isFetchingMoreWalls, isFetchingMoreWalls) || other.isFetchingMoreWalls == isFetchingMoreWalls)&&(identical(other.isFetchingMoreSetups, isFetchingMoreSetups) || other.isFetchingMoreSetups == isFetchingMoreSetups)&&const DeepCollectionEquality().equals(other._followerSummaries, _followerSummaries)&&const DeepCollectionEquality().equals(other._followingSummaries, _followingSummaries)&&(identical(other.isFetchingFollowers, isFetchingFollowers) || other.isFetchingFollowers == isFetchingFollowers)&&(identical(other.isFetchingFollowing, isFetchingFollowing) || other.isFetchingFollowing == isFetchingFollowing)&&(identical(other.followerPage, followerPage) || other.followerPage == followerPage)&&(identical(other.followingPage, followingPage) || other.followingPage == followingPage)&&(identical(other.hasMoreFollowers, hasMoreFollowers) || other.hasMoreFollowers == hasMoreFollowers)&&(identical(other.hasMoreFollowing, hasMoreFollowing) || other.hasMoreFollowing == hasMoreFollowing)&&const DeepCollectionEquality().equals(other._followerSearchResults, _followerSearchResults)&&const DeepCollectionEquality().equals(other._followingSearchResults, _followingSearchResults)&&(identical(other.isSearchingFollowers, isSearchingFollowers) || other.isSearchingFollowers == isSearchingFollowers)&&(identical(other.isSearchingFollowing, isSearchingFollowing) || other.isSearchingFollowing == isSearchingFollowing)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hashAll([runtimeType,status,actionStatus,email,profile,const DeepCollectionEquality().hash(_walls),const DeepCollectionEquality().hash(_setups),hasMoreWalls,hasMoreSetups,wallsCursor,setupsCursor,isFetchingMoreWalls,isFetchingMoreSetups,const DeepCollectionEquality().hash(_followerSummaries),const DeepCollectionEquality().hash(_followingSummaries),isFetchingFollowers,isFetchingFollowing,followerPage,followingPage,hasMoreFollowers,hasMoreFollowing,const DeepCollectionEquality().hash(_followerSearchResults),const DeepCollectionEquality().hash(_followingSearchResults),isSearchingFollowers,isSearchingFollowing,failure]);

@override
String toString() {
  return 'PublicProfileState(status: $status, actionStatus: $actionStatus, email: $email, profile: $profile, walls: $walls, setups: $setups, hasMoreWalls: $hasMoreWalls, hasMoreSetups: $hasMoreSetups, wallsCursor: $wallsCursor, setupsCursor: $setupsCursor, isFetchingMoreWalls: $isFetchingMoreWalls, isFetchingMoreSetups: $isFetchingMoreSetups, followerSummaries: $followerSummaries, followingSummaries: $followingSummaries, isFetchingFollowers: $isFetchingFollowers, isFetchingFollowing: $isFetchingFollowing, followerPage: $followerPage, followingPage: $followingPage, hasMoreFollowers: $hasMoreFollowers, hasMoreFollowing: $hasMoreFollowing, followerSearchResults: $followerSearchResults, followingSearchResults: $followingSearchResults, isSearchingFollowers: $isSearchingFollowers, isSearchingFollowing: $isSearchingFollowing, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$PublicProfileStateCopyWith<$Res> implements $PublicProfileStateCopyWith<$Res> {
  factory _$PublicProfileStateCopyWith(_PublicProfileState value, $Res Function(_PublicProfileState) _then) = __$PublicProfileStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, ActionStatus actionStatus, String email, PublicProfileEntity profile, List<PublicProfileWallEntity> walls, List<PublicProfileSetupEntity> setups, bool hasMoreWalls, bool hasMoreSetups, String? wallsCursor, String? setupsCursor, bool isFetchingMoreWalls, bool isFetchingMoreSetups, List<UserSummaryEntity> followerSummaries, List<UserSummaryEntity> followingSummaries, bool isFetchingFollowers, bool isFetchingFollowing, int followerPage, int followingPage, bool hasMoreFollowers, bool hasMoreFollowing, List<UserSummaryEntity>? followerSearchResults, List<UserSummaryEntity>? followingSearchResults, bool isSearchingFollowers, bool isSearchingFollowing, Failure? failure
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
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? actionStatus = null,Object? email = null,Object? profile = null,Object? walls = null,Object? setups = null,Object? hasMoreWalls = null,Object? hasMoreSetups = null,Object? wallsCursor = freezed,Object? setupsCursor = freezed,Object? isFetchingMoreWalls = null,Object? isFetchingMoreSetups = null,Object? followerSummaries = null,Object? followingSummaries = null,Object? isFetchingFollowers = null,Object? isFetchingFollowing = null,Object? followerPage = null,Object? followingPage = null,Object? hasMoreFollowers = null,Object? hasMoreFollowing = null,Object? followerSearchResults = freezed,Object? followingSearchResults = freezed,Object? isSearchingFollowers = null,Object? isSearchingFollowing = null,Object? failure = freezed,}) {
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
as bool,followerSummaries: null == followerSummaries ? _self._followerSummaries : followerSummaries // ignore: cast_nullable_to_non_nullable
as List<UserSummaryEntity>,followingSummaries: null == followingSummaries ? _self._followingSummaries : followingSummaries // ignore: cast_nullable_to_non_nullable
as List<UserSummaryEntity>,isFetchingFollowers: null == isFetchingFollowers ? _self.isFetchingFollowers : isFetchingFollowers // ignore: cast_nullable_to_non_nullable
as bool,isFetchingFollowing: null == isFetchingFollowing ? _self.isFetchingFollowing : isFetchingFollowing // ignore: cast_nullable_to_non_nullable
as bool,followerPage: null == followerPage ? _self.followerPage : followerPage // ignore: cast_nullable_to_non_nullable
as int,followingPage: null == followingPage ? _self.followingPage : followingPage // ignore: cast_nullable_to_non_nullable
as int,hasMoreFollowers: null == hasMoreFollowers ? _self.hasMoreFollowers : hasMoreFollowers // ignore: cast_nullable_to_non_nullable
as bool,hasMoreFollowing: null == hasMoreFollowing ? _self.hasMoreFollowing : hasMoreFollowing // ignore: cast_nullable_to_non_nullable
as bool,followerSearchResults: freezed == followerSearchResults ? _self._followerSearchResults : followerSearchResults // ignore: cast_nullable_to_non_nullable
as List<UserSummaryEntity>?,followingSearchResults: freezed == followingSearchResults ? _self._followingSearchResults : followingSearchResults // ignore: cast_nullable_to_non_nullable
as List<UserSummaryEntity>?,isSearchingFollowers: null == isSearchingFollowers ? _self.isSearchingFollowers : isSearchingFollowers // ignore: cast_nullable_to_non_nullable
as bool,isSearchingFollowing: null == isSearchingFollowing ? _self.isSearchingFollowing : isSearchingFollowing // ignore: cast_nullable_to_non_nullable
as bool,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}


}

// dart format on
