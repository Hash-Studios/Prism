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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _RefreshRequested value)?  refreshRequested,TResult Function( _FetchMoreWallsRequested value)?  fetchMoreWallsRequested,TResult Function( _RelationPageRequested value)?  relationPageRequested,TResult Function( _RelationSearchRequested value)?  relationSearchRequested,TResult Function( _RelationSearchCleared value)?  relationSearchCleared,TResult Function( _FollowChangeRequested value)?  followChangeRequested,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _RefreshRequested() when refreshRequested != null:
return refreshRequested(_that);case _FetchMoreWallsRequested() when fetchMoreWallsRequested != null:
return fetchMoreWallsRequested(_that);case _RelationPageRequested() when relationPageRequested != null:
return relationPageRequested(_that);case _RelationSearchRequested() when relationSearchRequested != null:
return relationSearchRequested(_that);case _RelationSearchCleared() when relationSearchCleared != null:
return relationSearchCleared(_that);case _FollowChangeRequested() when followChangeRequested != null:
return followChangeRequested(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _RefreshRequested value)  refreshRequested,required TResult Function( _FetchMoreWallsRequested value)  fetchMoreWallsRequested,required TResult Function( _RelationPageRequested value)  relationPageRequested,required TResult Function( _RelationSearchRequested value)  relationSearchRequested,required TResult Function( _RelationSearchCleared value)  relationSearchCleared,required TResult Function( _FollowChangeRequested value)  followChangeRequested,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _RefreshRequested():
return refreshRequested(_that);case _FetchMoreWallsRequested():
return fetchMoreWallsRequested(_that);case _RelationPageRequested():
return relationPageRequested(_that);case _RelationSearchRequested():
return relationSearchRequested(_that);case _RelationSearchCleared():
return relationSearchCleared(_that);case _FollowChangeRequested():
return followChangeRequested(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _RefreshRequested value)?  refreshRequested,TResult? Function( _FetchMoreWallsRequested value)?  fetchMoreWallsRequested,TResult? Function( _RelationPageRequested value)?  relationPageRequested,TResult? Function( _RelationSearchRequested value)?  relationSearchRequested,TResult? Function( _RelationSearchCleared value)?  relationSearchCleared,TResult? Function( _FollowChangeRequested value)?  followChangeRequested,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _RefreshRequested() when refreshRequested != null:
return refreshRequested(_that);case _FetchMoreWallsRequested() when fetchMoreWallsRequested != null:
return fetchMoreWallsRequested(_that);case _RelationPageRequested() when relationPageRequested != null:
return relationPageRequested(_that);case _RelationSearchRequested() when relationSearchRequested != null:
return relationSearchRequested(_that);case _RelationSearchCleared() when relationSearchCleared != null:
return relationSearchCleared(_that);case _FollowChangeRequested() when followChangeRequested != null:
return followChangeRequested(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String email)?  started,TResult Function()?  refreshRequested,TResult Function()?  fetchMoreWallsRequested,TResult Function( UserRelationKind kind,  List<String> allEmails,  int page)?  relationPageRequested,TResult Function( UserRelationKind kind,  String query,  List<String> allEmails)?  relationSearchRequested,TResult Function( UserRelationKind kind)?  relationSearchCleared,TResult Function( bool follow,  String currentUserId,  String currentUserEmail,  String targetUserId,  String targetUserEmail,  String targetName)?  followChangeRequested,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.email);case _RefreshRequested() when refreshRequested != null:
return refreshRequested();case _FetchMoreWallsRequested() when fetchMoreWallsRequested != null:
return fetchMoreWallsRequested();case _RelationPageRequested() when relationPageRequested != null:
return relationPageRequested(_that.kind,_that.allEmails,_that.page);case _RelationSearchRequested() when relationSearchRequested != null:
return relationSearchRequested(_that.kind,_that.query,_that.allEmails);case _RelationSearchCleared() when relationSearchCleared != null:
return relationSearchCleared(_that.kind);case _FollowChangeRequested() when followChangeRequested != null:
return followChangeRequested(_that.follow,_that.currentUserId,_that.currentUserEmail,_that.targetUserId,_that.targetUserEmail,_that.targetName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String email)  started,required TResult Function()  refreshRequested,required TResult Function()  fetchMoreWallsRequested,required TResult Function( UserRelationKind kind,  List<String> allEmails,  int page)  relationPageRequested,required TResult Function( UserRelationKind kind,  String query,  List<String> allEmails)  relationSearchRequested,required TResult Function( UserRelationKind kind)  relationSearchCleared,required TResult Function( bool follow,  String currentUserId,  String currentUserEmail,  String targetUserId,  String targetUserEmail,  String targetName)  followChangeRequested,}) {final _that = this;
switch (_that) {
case _Started():
return started(_that.email);case _RefreshRequested():
return refreshRequested();case _FetchMoreWallsRequested():
return fetchMoreWallsRequested();case _RelationPageRequested():
return relationPageRequested(_that.kind,_that.allEmails,_that.page);case _RelationSearchRequested():
return relationSearchRequested(_that.kind,_that.query,_that.allEmails);case _RelationSearchCleared():
return relationSearchCleared(_that.kind);case _FollowChangeRequested():
return followChangeRequested(_that.follow,_that.currentUserId,_that.currentUserEmail,_that.targetUserId,_that.targetUserEmail,_that.targetName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String email)?  started,TResult? Function()?  refreshRequested,TResult? Function()?  fetchMoreWallsRequested,TResult? Function( UserRelationKind kind,  List<String> allEmails,  int page)?  relationPageRequested,TResult? Function( UserRelationKind kind,  String query,  List<String> allEmails)?  relationSearchRequested,TResult? Function( UserRelationKind kind)?  relationSearchCleared,TResult? Function( bool follow,  String currentUserId,  String currentUserEmail,  String targetUserId,  String targetUserEmail,  String targetName)?  followChangeRequested,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.email);case _RefreshRequested() when refreshRequested != null:
return refreshRequested();case _FetchMoreWallsRequested() when fetchMoreWallsRequested != null:
return fetchMoreWallsRequested();case _RelationPageRequested() when relationPageRequested != null:
return relationPageRequested(_that.kind,_that.allEmails,_that.page);case _RelationSearchRequested() when relationSearchRequested != null:
return relationSearchRequested(_that.kind,_that.query,_that.allEmails);case _RelationSearchCleared() when relationSearchCleared != null:
return relationSearchCleared(_that.kind);case _FollowChangeRequested() when followChangeRequested != null:
return followChangeRequested(_that.follow,_that.currentUserId,_that.currentUserEmail,_that.targetUserId,_that.targetUserEmail,_that.targetName);case _:
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


class _RelationPageRequested implements PublicProfileEvent {
  const _RelationPageRequested({required this.kind, required final  List<String> allEmails, required this.page}): _allEmails = allEmails;
  

 final  UserRelationKind kind;
 final  List<String> _allEmails;
 List<String> get allEmails {
  if (_allEmails is EqualUnmodifiableListView) return _allEmails;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_allEmails);
}

 final  int page;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RelationPageRequestedCopyWith<_RelationPageRequested> get copyWith => __$RelationPageRequestedCopyWithImpl<_RelationPageRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RelationPageRequested&&(identical(other.kind, kind) || other.kind == kind)&&const DeepCollectionEquality().equals(other._allEmails, _allEmails)&&(identical(other.page, page) || other.page == page));
}


@override
int get hashCode => Object.hash(runtimeType,kind,const DeepCollectionEquality().hash(_allEmails),page);

@override
String toString() {
  return 'PublicProfileEvent.relationPageRequested(kind: $kind, allEmails: $allEmails, page: $page)';
}


}

/// @nodoc
abstract mixin class _$RelationPageRequestedCopyWith<$Res> implements $PublicProfileEventCopyWith<$Res> {
  factory _$RelationPageRequestedCopyWith(_RelationPageRequested value, $Res Function(_RelationPageRequested) _then) = __$RelationPageRequestedCopyWithImpl;
@useResult
$Res call({
 UserRelationKind kind, List<String> allEmails, int page
});




}
/// @nodoc
class __$RelationPageRequestedCopyWithImpl<$Res>
    implements _$RelationPageRequestedCopyWith<$Res> {
  __$RelationPageRequestedCopyWithImpl(this._self, this._then);

  final _RelationPageRequested _self;
  final $Res Function(_RelationPageRequested) _then;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? allEmails = null,Object? page = null,}) {
  return _then(_RelationPageRequested(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as UserRelationKind,allEmails: null == allEmails ? _self._allEmails : allEmails // ignore: cast_nullable_to_non_nullable
as List<String>,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _RelationSearchRequested implements PublicProfileEvent {
  const _RelationSearchRequested({required this.kind, required this.query, required final  List<String> allEmails}): _allEmails = allEmails;
  

 final  UserRelationKind kind;
 final  String query;
 final  List<String> _allEmails;
 List<String> get allEmails {
  if (_allEmails is EqualUnmodifiableListView) return _allEmails;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_allEmails);
}


/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RelationSearchRequestedCopyWith<_RelationSearchRequested> get copyWith => __$RelationSearchRequestedCopyWithImpl<_RelationSearchRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RelationSearchRequested&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.query, query) || other.query == query)&&const DeepCollectionEquality().equals(other._allEmails, _allEmails));
}


@override
int get hashCode => Object.hash(runtimeType,kind,query,const DeepCollectionEquality().hash(_allEmails));

@override
String toString() {
  return 'PublicProfileEvent.relationSearchRequested(kind: $kind, query: $query, allEmails: $allEmails)';
}


}

/// @nodoc
abstract mixin class _$RelationSearchRequestedCopyWith<$Res> implements $PublicProfileEventCopyWith<$Res> {
  factory _$RelationSearchRequestedCopyWith(_RelationSearchRequested value, $Res Function(_RelationSearchRequested) _then) = __$RelationSearchRequestedCopyWithImpl;
@useResult
$Res call({
 UserRelationKind kind, String query, List<String> allEmails
});




}
/// @nodoc
class __$RelationSearchRequestedCopyWithImpl<$Res>
    implements _$RelationSearchRequestedCopyWith<$Res> {
  __$RelationSearchRequestedCopyWithImpl(this._self, this._then);

  final _RelationSearchRequested _self;
  final $Res Function(_RelationSearchRequested) _then;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? query = null,Object? allEmails = null,}) {
  return _then(_RelationSearchRequested(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as UserRelationKind,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,allEmails: null == allEmails ? _self._allEmails : allEmails // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc


class _RelationSearchCleared implements PublicProfileEvent {
  const _RelationSearchCleared({required this.kind});
  

 final  UserRelationKind kind;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RelationSearchClearedCopyWith<_RelationSearchCleared> get copyWith => __$RelationSearchClearedCopyWithImpl<_RelationSearchCleared>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RelationSearchCleared&&(identical(other.kind, kind) || other.kind == kind));
}


@override
int get hashCode => Object.hash(runtimeType,kind);

@override
String toString() {
  return 'PublicProfileEvent.relationSearchCleared(kind: $kind)';
}


}

/// @nodoc
abstract mixin class _$RelationSearchClearedCopyWith<$Res> implements $PublicProfileEventCopyWith<$Res> {
  factory _$RelationSearchClearedCopyWith(_RelationSearchCleared value, $Res Function(_RelationSearchCleared) _then) = __$RelationSearchClearedCopyWithImpl;
@useResult
$Res call({
 UserRelationKind kind
});




}
/// @nodoc
class __$RelationSearchClearedCopyWithImpl<$Res>
    implements _$RelationSearchClearedCopyWith<$Res> {
  __$RelationSearchClearedCopyWithImpl(this._self, this._then);

  final _RelationSearchCleared _self;
  final $Res Function(_RelationSearchCleared) _then;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? kind = null,}) {
  return _then(_RelationSearchCleared(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as UserRelationKind,
  ));
}


}

/// @nodoc


class _FollowChangeRequested implements PublicProfileEvent {
  const _FollowChangeRequested({required this.follow, required this.currentUserId, required this.currentUserEmail, required this.targetUserId, required this.targetUserEmail, this.targetName = ''});
  

 final  bool follow;
 final  String currentUserId;
 final  String currentUserEmail;
 final  String targetUserId;
 final  String targetUserEmail;
@JsonKey() final  String targetName;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FollowChangeRequestedCopyWith<_FollowChangeRequested> get copyWith => __$FollowChangeRequestedCopyWithImpl<_FollowChangeRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FollowChangeRequested&&(identical(other.follow, follow) || other.follow == follow)&&(identical(other.currentUserId, currentUserId) || other.currentUserId == currentUserId)&&(identical(other.currentUserEmail, currentUserEmail) || other.currentUserEmail == currentUserEmail)&&(identical(other.targetUserId, targetUserId) || other.targetUserId == targetUserId)&&(identical(other.targetUserEmail, targetUserEmail) || other.targetUserEmail == targetUserEmail)&&(identical(other.targetName, targetName) || other.targetName == targetName));
}


@override
int get hashCode => Object.hash(runtimeType,follow,currentUserId,currentUserEmail,targetUserId,targetUserEmail,targetName);

@override
String toString() {
  return 'PublicProfileEvent.followChangeRequested(follow: $follow, currentUserId: $currentUserId, currentUserEmail: $currentUserEmail, targetUserId: $targetUserId, targetUserEmail: $targetUserEmail, targetName: $targetName)';
}


}

/// @nodoc
abstract mixin class _$FollowChangeRequestedCopyWith<$Res> implements $PublicProfileEventCopyWith<$Res> {
  factory _$FollowChangeRequestedCopyWith(_FollowChangeRequested value, $Res Function(_FollowChangeRequested) _then) = __$FollowChangeRequestedCopyWithImpl;
@useResult
$Res call({
 bool follow, String currentUserId, String currentUserEmail, String targetUserId, String targetUserEmail, String targetName
});




}
/// @nodoc
class __$FollowChangeRequestedCopyWithImpl<$Res>
    implements _$FollowChangeRequestedCopyWith<$Res> {
  __$FollowChangeRequestedCopyWithImpl(this._self, this._then);

  final _FollowChangeRequested _self;
  final $Res Function(_FollowChangeRequested) _then;

/// Create a copy of PublicProfileEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? follow = null,Object? currentUserId = null,Object? currentUserEmail = null,Object? targetUserId = null,Object? targetUserEmail = null,Object? targetName = null,}) {
  return _then(_FollowChangeRequested(
follow: null == follow ? _self.follow : follow // ignore: cast_nullable_to_non_nullable
as bool,currentUserId: null == currentUserId ? _self.currentUserId : currentUserId // ignore: cast_nullable_to_non_nullable
as String,currentUserEmail: null == currentUserEmail ? _self.currentUserEmail : currentUserEmail // ignore: cast_nullable_to_non_nullable
as String,targetUserId: null == targetUserId ? _self.targetUserId : targetUserId // ignore: cast_nullable_to_non_nullable
as String,targetUserEmail: null == targetUserEmail ? _self.targetUserEmail : targetUserEmail // ignore: cast_nullable_to_non_nullable
as String,targetName: null == targetName ? _self.targetName : targetName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$PublicProfileState {

 LoadStatus get status; String get email; List<PublicProfileWallEntity> get walls; bool get hasMoreWalls; bool get isFetchingMoreWalls; RelationList get followers; RelationList get following;/// Follow state the user asked for, keyed by lowercase email. It wins over the profile stream until the
/// request fails, so the button flips at once.
 Map<String, bool> get followOverrides;/// Result of the latest follow request. The UI shows a toast once per [FollowOutcome.id].
 FollowOutcome? get followOutcome;
/// Create a copy of PublicProfileState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PublicProfileStateCopyWith<PublicProfileState> get copyWith => _$PublicProfileStateCopyWithImpl<PublicProfileState>(this as PublicProfileState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PublicProfileState&&(identical(other.status, status) || other.status == status)&&(identical(other.email, email) || other.email == email)&&const DeepCollectionEquality().equals(other.walls, walls)&&(identical(other.hasMoreWalls, hasMoreWalls) || other.hasMoreWalls == hasMoreWalls)&&(identical(other.isFetchingMoreWalls, isFetchingMoreWalls) || other.isFetchingMoreWalls == isFetchingMoreWalls)&&(identical(other.followers, followers) || other.followers == followers)&&(identical(other.following, following) || other.following == following)&&const DeepCollectionEquality().equals(other.followOverrides, followOverrides)&&(identical(other.followOutcome, followOutcome) || other.followOutcome == followOutcome));
}


@override
int get hashCode => Object.hash(runtimeType,status,email,const DeepCollectionEquality().hash(walls),hasMoreWalls,isFetchingMoreWalls,followers,following,const DeepCollectionEquality().hash(followOverrides),followOutcome);

@override
String toString() {
  return 'PublicProfileState(status: $status, email: $email, walls: $walls, hasMoreWalls: $hasMoreWalls, isFetchingMoreWalls: $isFetchingMoreWalls, followers: $followers, following: $following, followOverrides: $followOverrides, followOutcome: $followOutcome)';
}


}

/// @nodoc
abstract mixin class $PublicProfileStateCopyWith<$Res>  {
  factory $PublicProfileStateCopyWith(PublicProfileState value, $Res Function(PublicProfileState) _then) = _$PublicProfileStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, String email, List<PublicProfileWallEntity> walls, bool hasMoreWalls, bool isFetchingMoreWalls, RelationList followers, RelationList following, Map<String, bool> followOverrides, FollowOutcome? followOutcome
});


$RelationListCopyWith<$Res> get followers;$RelationListCopyWith<$Res> get following;$FollowOutcomeCopyWith<$Res>? get followOutcome;

}
/// @nodoc
class _$PublicProfileStateCopyWithImpl<$Res>
    implements $PublicProfileStateCopyWith<$Res> {
  _$PublicProfileStateCopyWithImpl(this._self, this._then);

  final PublicProfileState _self;
  final $Res Function(PublicProfileState) _then;

/// Create a copy of PublicProfileState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? email = null,Object? walls = null,Object? hasMoreWalls = null,Object? isFetchingMoreWalls = null,Object? followers = null,Object? following = null,Object? followOverrides = null,Object? followOutcome = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,walls: null == walls ? _self.walls : walls // ignore: cast_nullable_to_non_nullable
as List<PublicProfileWallEntity>,hasMoreWalls: null == hasMoreWalls ? _self.hasMoreWalls : hasMoreWalls // ignore: cast_nullable_to_non_nullable
as bool,isFetchingMoreWalls: null == isFetchingMoreWalls ? _self.isFetchingMoreWalls : isFetchingMoreWalls // ignore: cast_nullable_to_non_nullable
as bool,followers: null == followers ? _self.followers : followers // ignore: cast_nullable_to_non_nullable
as RelationList,following: null == following ? _self.following : following // ignore: cast_nullable_to_non_nullable
as RelationList,followOverrides: null == followOverrides ? _self.followOverrides : followOverrides // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,followOutcome: freezed == followOutcome ? _self.followOutcome : followOutcome // ignore: cast_nullable_to_non_nullable
as FollowOutcome?,
  ));
}
/// Create a copy of PublicProfileState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RelationListCopyWith<$Res> get followers {
  
  return $RelationListCopyWith<$Res>(_self.followers, (value) {
    return _then(_self.copyWith(followers: value));
  });
}/// Create a copy of PublicProfileState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RelationListCopyWith<$Res> get following {
  
  return $RelationListCopyWith<$Res>(_self.following, (value) {
    return _then(_self.copyWith(following: value));
  });
}/// Create a copy of PublicProfileState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FollowOutcomeCopyWith<$Res>? get followOutcome {
    if (_self.followOutcome == null) {
    return null;
  }

  return $FollowOutcomeCopyWith<$Res>(_self.followOutcome!, (value) {
    return _then(_self.copyWith(followOutcome: value));
  });
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  String email,  List<PublicProfileWallEntity> walls,  bool hasMoreWalls,  bool isFetchingMoreWalls,  RelationList followers,  RelationList following,  Map<String, bool> followOverrides,  FollowOutcome? followOutcome)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PublicProfileState() when $default != null:
return $default(_that.status,_that.email,_that.walls,_that.hasMoreWalls,_that.isFetchingMoreWalls,_that.followers,_that.following,_that.followOverrides,_that.followOutcome);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  String email,  List<PublicProfileWallEntity> walls,  bool hasMoreWalls,  bool isFetchingMoreWalls,  RelationList followers,  RelationList following,  Map<String, bool> followOverrides,  FollowOutcome? followOutcome)  $default,) {final _that = this;
switch (_that) {
case _PublicProfileState():
return $default(_that.status,_that.email,_that.walls,_that.hasMoreWalls,_that.isFetchingMoreWalls,_that.followers,_that.following,_that.followOverrides,_that.followOutcome);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  String email,  List<PublicProfileWallEntity> walls,  bool hasMoreWalls,  bool isFetchingMoreWalls,  RelationList followers,  RelationList following,  Map<String, bool> followOverrides,  FollowOutcome? followOutcome)?  $default,) {final _that = this;
switch (_that) {
case _PublicProfileState() when $default != null:
return $default(_that.status,_that.email,_that.walls,_that.hasMoreWalls,_that.isFetchingMoreWalls,_that.followers,_that.following,_that.followOverrides,_that.followOutcome);case _:
  return null;

}
}

}

/// @nodoc


class _PublicProfileState extends PublicProfileState {
  const _PublicProfileState({required this.status, required this.email, required final  List<PublicProfileWallEntity> walls, required this.hasMoreWalls, required this.isFetchingMoreWalls, required this.followers, required this.following, final  Map<String, bool> followOverrides = const <String, bool>{}, this.followOutcome}): _walls = walls,_followOverrides = followOverrides,super._();
  

@override final  LoadStatus status;
@override final  String email;
 final  List<PublicProfileWallEntity> _walls;
@override List<PublicProfileWallEntity> get walls {
  if (_walls is EqualUnmodifiableListView) return _walls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_walls);
}

@override final  bool hasMoreWalls;
@override final  bool isFetchingMoreWalls;
@override final  RelationList followers;
@override final  RelationList following;
/// Follow state the user asked for, keyed by lowercase email. It wins over the profile stream until the
/// request fails, so the button flips at once.
 final  Map<String, bool> _followOverrides;
/// Follow state the user asked for, keyed by lowercase email. It wins over the profile stream until the
/// request fails, so the button flips at once.
@override@JsonKey() Map<String, bool> get followOverrides {
  if (_followOverrides is EqualUnmodifiableMapView) return _followOverrides;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_followOverrides);
}

/// Result of the latest follow request. The UI shows a toast once per [FollowOutcome.id].
@override final  FollowOutcome? followOutcome;

/// Create a copy of PublicProfileState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PublicProfileStateCopyWith<_PublicProfileState> get copyWith => __$PublicProfileStateCopyWithImpl<_PublicProfileState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PublicProfileState&&(identical(other.status, status) || other.status == status)&&(identical(other.email, email) || other.email == email)&&const DeepCollectionEquality().equals(other._walls, _walls)&&(identical(other.hasMoreWalls, hasMoreWalls) || other.hasMoreWalls == hasMoreWalls)&&(identical(other.isFetchingMoreWalls, isFetchingMoreWalls) || other.isFetchingMoreWalls == isFetchingMoreWalls)&&(identical(other.followers, followers) || other.followers == followers)&&(identical(other.following, following) || other.following == following)&&const DeepCollectionEquality().equals(other._followOverrides, _followOverrides)&&(identical(other.followOutcome, followOutcome) || other.followOutcome == followOutcome));
}


@override
int get hashCode => Object.hash(runtimeType,status,email,const DeepCollectionEquality().hash(_walls),hasMoreWalls,isFetchingMoreWalls,followers,following,const DeepCollectionEquality().hash(_followOverrides),followOutcome);

@override
String toString() {
  return 'PublicProfileState(status: $status, email: $email, walls: $walls, hasMoreWalls: $hasMoreWalls, isFetchingMoreWalls: $isFetchingMoreWalls, followers: $followers, following: $following, followOverrides: $followOverrides, followOutcome: $followOutcome)';
}


}

/// @nodoc
abstract mixin class _$PublicProfileStateCopyWith<$Res> implements $PublicProfileStateCopyWith<$Res> {
  factory _$PublicProfileStateCopyWith(_PublicProfileState value, $Res Function(_PublicProfileState) _then) = __$PublicProfileStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, String email, List<PublicProfileWallEntity> walls, bool hasMoreWalls, bool isFetchingMoreWalls, RelationList followers, RelationList following, Map<String, bool> followOverrides, FollowOutcome? followOutcome
});


@override $RelationListCopyWith<$Res> get followers;@override $RelationListCopyWith<$Res> get following;@override $FollowOutcomeCopyWith<$Res>? get followOutcome;

}
/// @nodoc
class __$PublicProfileStateCopyWithImpl<$Res>
    implements _$PublicProfileStateCopyWith<$Res> {
  __$PublicProfileStateCopyWithImpl(this._self, this._then);

  final _PublicProfileState _self;
  final $Res Function(_PublicProfileState) _then;

/// Create a copy of PublicProfileState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? email = null,Object? walls = null,Object? hasMoreWalls = null,Object? isFetchingMoreWalls = null,Object? followers = null,Object? following = null,Object? followOverrides = null,Object? followOutcome = freezed,}) {
  return _then(_PublicProfileState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,walls: null == walls ? _self._walls : walls // ignore: cast_nullable_to_non_nullable
as List<PublicProfileWallEntity>,hasMoreWalls: null == hasMoreWalls ? _self.hasMoreWalls : hasMoreWalls // ignore: cast_nullable_to_non_nullable
as bool,isFetchingMoreWalls: null == isFetchingMoreWalls ? _self.isFetchingMoreWalls : isFetchingMoreWalls // ignore: cast_nullable_to_non_nullable
as bool,followers: null == followers ? _self.followers : followers // ignore: cast_nullable_to_non_nullable
as RelationList,following: null == following ? _self.following : following // ignore: cast_nullable_to_non_nullable
as RelationList,followOverrides: null == followOverrides ? _self._followOverrides : followOverrides // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,followOutcome: freezed == followOutcome ? _self.followOutcome : followOutcome // ignore: cast_nullable_to_non_nullable
as FollowOutcome?,
  ));
}

/// Create a copy of PublicProfileState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RelationListCopyWith<$Res> get followers {
  
  return $RelationListCopyWith<$Res>(_self.followers, (value) {
    return _then(_self.copyWith(followers: value));
  });
}/// Create a copy of PublicProfileState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RelationListCopyWith<$Res> get following {
  
  return $RelationListCopyWith<$Res>(_self.following, (value) {
    return _then(_self.copyWith(following: value));
  });
}/// Create a copy of PublicProfileState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FollowOutcomeCopyWith<$Res>? get followOutcome {
    if (_self.followOutcome == null) {
    return null;
  }

  return $FollowOutcomeCopyWith<$Res>(_self.followOutcome!, (value) {
    return _then(_self.copyWith(followOutcome: value));
  });
}
}

/// @nodoc
mixin _$RelationList {

 List<UserSummaryEntity> get summaries; bool get isFetching; int get page; bool get hasMore;/// Active search results. `null` means no search is active.
 List<UserSummaryEntity>? get searchResults; bool get isSearching;
/// Create a copy of RelationList
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RelationListCopyWith<RelationList> get copyWith => _$RelationListCopyWithImpl<RelationList>(this as RelationList, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RelationList&&const DeepCollectionEquality().equals(other.summaries, summaries)&&(identical(other.isFetching, isFetching) || other.isFetching == isFetching)&&(identical(other.page, page) || other.page == page)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&const DeepCollectionEquality().equals(other.searchResults, searchResults)&&(identical(other.isSearching, isSearching) || other.isSearching == isSearching));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(summaries),isFetching,page,hasMore,const DeepCollectionEquality().hash(searchResults),isSearching);

@override
String toString() {
  return 'RelationList(summaries: $summaries, isFetching: $isFetching, page: $page, hasMore: $hasMore, searchResults: $searchResults, isSearching: $isSearching)';
}


}

/// @nodoc
abstract mixin class $RelationListCopyWith<$Res>  {
  factory $RelationListCopyWith(RelationList value, $Res Function(RelationList) _then) = _$RelationListCopyWithImpl;
@useResult
$Res call({
 List<UserSummaryEntity> summaries, bool isFetching, int page, bool hasMore, List<UserSummaryEntity>? searchResults, bool isSearching
});




}
/// @nodoc
class _$RelationListCopyWithImpl<$Res>
    implements $RelationListCopyWith<$Res> {
  _$RelationListCopyWithImpl(this._self, this._then);

  final RelationList _self;
  final $Res Function(RelationList) _then;

/// Create a copy of RelationList
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? summaries = null,Object? isFetching = null,Object? page = null,Object? hasMore = null,Object? searchResults = freezed,Object? isSearching = null,}) {
  return _then(_self.copyWith(
summaries: null == summaries ? _self.summaries : summaries // ignore: cast_nullable_to_non_nullable
as List<UserSummaryEntity>,isFetching: null == isFetching ? _self.isFetching : isFetching // ignore: cast_nullable_to_non_nullable
as bool,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,searchResults: freezed == searchResults ? _self.searchResults : searchResults // ignore: cast_nullable_to_non_nullable
as List<UserSummaryEntity>?,isSearching: null == isSearching ? _self.isSearching : isSearching // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [RelationList].
extension RelationListPatterns on RelationList {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RelationList value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RelationList() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RelationList value)  $default,){
final _that = this;
switch (_that) {
case _RelationList():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RelationList value)?  $default,){
final _that = this;
switch (_that) {
case _RelationList() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<UserSummaryEntity> summaries,  bool isFetching,  int page,  bool hasMore,  List<UserSummaryEntity>? searchResults,  bool isSearching)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RelationList() when $default != null:
return $default(_that.summaries,_that.isFetching,_that.page,_that.hasMore,_that.searchResults,_that.isSearching);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<UserSummaryEntity> summaries,  bool isFetching,  int page,  bool hasMore,  List<UserSummaryEntity>? searchResults,  bool isSearching)  $default,) {final _that = this;
switch (_that) {
case _RelationList():
return $default(_that.summaries,_that.isFetching,_that.page,_that.hasMore,_that.searchResults,_that.isSearching);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<UserSummaryEntity> summaries,  bool isFetching,  int page,  bool hasMore,  List<UserSummaryEntity>? searchResults,  bool isSearching)?  $default,) {final _that = this;
switch (_that) {
case _RelationList() when $default != null:
return $default(_that.summaries,_that.isFetching,_that.page,_that.hasMore,_that.searchResults,_that.isSearching);case _:
  return null;

}
}

}

/// @nodoc


class _RelationList extends RelationList {
  const _RelationList({final  List<UserSummaryEntity> summaries = const <UserSummaryEntity>[], this.isFetching = false, this.page = 0, this.hasMore = false, final  List<UserSummaryEntity>? searchResults, this.isSearching = false}): _summaries = summaries,_searchResults = searchResults,super._();
  

 final  List<UserSummaryEntity> _summaries;
@override@JsonKey() List<UserSummaryEntity> get summaries {
  if (_summaries is EqualUnmodifiableListView) return _summaries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_summaries);
}

@override@JsonKey() final  bool isFetching;
@override@JsonKey() final  int page;
@override@JsonKey() final  bool hasMore;
/// Active search results. `null` means no search is active.
 final  List<UserSummaryEntity>? _searchResults;
/// Active search results. `null` means no search is active.
@override List<UserSummaryEntity>? get searchResults {
  final value = _searchResults;
  if (value == null) return null;
  if (_searchResults is EqualUnmodifiableListView) return _searchResults;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey() final  bool isSearching;

/// Create a copy of RelationList
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RelationListCopyWith<_RelationList> get copyWith => __$RelationListCopyWithImpl<_RelationList>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RelationList&&const DeepCollectionEquality().equals(other._summaries, _summaries)&&(identical(other.isFetching, isFetching) || other.isFetching == isFetching)&&(identical(other.page, page) || other.page == page)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&const DeepCollectionEquality().equals(other._searchResults, _searchResults)&&(identical(other.isSearching, isSearching) || other.isSearching == isSearching));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_summaries),isFetching,page,hasMore,const DeepCollectionEquality().hash(_searchResults),isSearching);

@override
String toString() {
  return 'RelationList(summaries: $summaries, isFetching: $isFetching, page: $page, hasMore: $hasMore, searchResults: $searchResults, isSearching: $isSearching)';
}


}

/// @nodoc
abstract mixin class _$RelationListCopyWith<$Res> implements $RelationListCopyWith<$Res> {
  factory _$RelationListCopyWith(_RelationList value, $Res Function(_RelationList) _then) = __$RelationListCopyWithImpl;
@override @useResult
$Res call({
 List<UserSummaryEntity> summaries, bool isFetching, int page, bool hasMore, List<UserSummaryEntity>? searchResults, bool isSearching
});




}
/// @nodoc
class __$RelationListCopyWithImpl<$Res>
    implements _$RelationListCopyWith<$Res> {
  __$RelationListCopyWithImpl(this._self, this._then);

  final _RelationList _self;
  final $Res Function(_RelationList) _then;

/// Create a copy of RelationList
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? summaries = null,Object? isFetching = null,Object? page = null,Object? hasMore = null,Object? searchResults = freezed,Object? isSearching = null,}) {
  return _then(_RelationList(
summaries: null == summaries ? _self._summaries : summaries // ignore: cast_nullable_to_non_nullable
as List<UserSummaryEntity>,isFetching: null == isFetching ? _self.isFetching : isFetching // ignore: cast_nullable_to_non_nullable
as bool,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,searchResults: freezed == searchResults ? _self._searchResults : searchResults // ignore: cast_nullable_to_non_nullable
as List<UserSummaryEntity>?,isSearching: null == isSearching ? _self.isSearching : isSearching // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$FollowOutcome {

 int get id; bool get follow; bool get success; String get targetName;
/// Create a copy of FollowOutcome
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FollowOutcomeCopyWith<FollowOutcome> get copyWith => _$FollowOutcomeCopyWithImpl<FollowOutcome>(this as FollowOutcome, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FollowOutcome&&(identical(other.id, id) || other.id == id)&&(identical(other.follow, follow) || other.follow == follow)&&(identical(other.success, success) || other.success == success)&&(identical(other.targetName, targetName) || other.targetName == targetName));
}


@override
int get hashCode => Object.hash(runtimeType,id,follow,success,targetName);

@override
String toString() {
  return 'FollowOutcome(id: $id, follow: $follow, success: $success, targetName: $targetName)';
}


}

/// @nodoc
abstract mixin class $FollowOutcomeCopyWith<$Res>  {
  factory $FollowOutcomeCopyWith(FollowOutcome value, $Res Function(FollowOutcome) _then) = _$FollowOutcomeCopyWithImpl;
@useResult
$Res call({
 int id, bool follow, bool success, String targetName
});




}
/// @nodoc
class _$FollowOutcomeCopyWithImpl<$Res>
    implements $FollowOutcomeCopyWith<$Res> {
  _$FollowOutcomeCopyWithImpl(this._self, this._then);

  final FollowOutcome _self;
  final $Res Function(FollowOutcome) _then;

/// Create a copy of FollowOutcome
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? follow = null,Object? success = null,Object? targetName = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,follow: null == follow ? _self.follow : follow // ignore: cast_nullable_to_non_nullable
as bool,success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,targetName: null == targetName ? _self.targetName : targetName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [FollowOutcome].
extension FollowOutcomePatterns on FollowOutcome {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FollowOutcome value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FollowOutcome() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FollowOutcome value)  $default,){
final _that = this;
switch (_that) {
case _FollowOutcome():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FollowOutcome value)?  $default,){
final _that = this;
switch (_that) {
case _FollowOutcome() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  bool follow,  bool success,  String targetName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FollowOutcome() when $default != null:
return $default(_that.id,_that.follow,_that.success,_that.targetName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  bool follow,  bool success,  String targetName)  $default,) {final _that = this;
switch (_that) {
case _FollowOutcome():
return $default(_that.id,_that.follow,_that.success,_that.targetName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  bool follow,  bool success,  String targetName)?  $default,) {final _that = this;
switch (_that) {
case _FollowOutcome() when $default != null:
return $default(_that.id,_that.follow,_that.success,_that.targetName);case _:
  return null;

}
}

}

/// @nodoc


class _FollowOutcome implements FollowOutcome {
  const _FollowOutcome({required this.id, required this.follow, required this.success, this.targetName = ''});
  

@override final  int id;
@override final  bool follow;
@override final  bool success;
@override@JsonKey() final  String targetName;

/// Create a copy of FollowOutcome
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FollowOutcomeCopyWith<_FollowOutcome> get copyWith => __$FollowOutcomeCopyWithImpl<_FollowOutcome>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FollowOutcome&&(identical(other.id, id) || other.id == id)&&(identical(other.follow, follow) || other.follow == follow)&&(identical(other.success, success) || other.success == success)&&(identical(other.targetName, targetName) || other.targetName == targetName));
}


@override
int get hashCode => Object.hash(runtimeType,id,follow,success,targetName);

@override
String toString() {
  return 'FollowOutcome(id: $id, follow: $follow, success: $success, targetName: $targetName)';
}


}

/// @nodoc
abstract mixin class _$FollowOutcomeCopyWith<$Res> implements $FollowOutcomeCopyWith<$Res> {
  factory _$FollowOutcomeCopyWith(_FollowOutcome value, $Res Function(_FollowOutcome) _then) = __$FollowOutcomeCopyWithImpl;
@override @useResult
$Res call({
 int id, bool follow, bool success, String targetName
});




}
/// @nodoc
class __$FollowOutcomeCopyWithImpl<$Res>
    implements _$FollowOutcomeCopyWith<$Res> {
  __$FollowOutcomeCopyWithImpl(this._self, this._then);

  final _FollowOutcome _self;
  final $Res Function(_FollowOutcome) _then;

/// Create a copy of FollowOutcome
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? follow = null,Object? success = null,Object? targetName = null,}) {
  return _then(_FollowOutcome(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,follow: null == follow ? _self.follow : follow // ignore: cast_nullable_to_non_nullable
as bool,success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,targetName: null == targetName ? _self.targetName : targetName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
