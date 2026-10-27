// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'folders_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FoldersEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FoldersEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FoldersEvent()';
}


}

/// @nodoc
class $FoldersEventCopyWith<$Res>  {
$FoldersEventCopyWith(FoldersEvent _, $Res Function(FoldersEvent) __);
}


/// Adds pattern-matching-related methods to [FoldersEvent].
extension FoldersEventPatterns on FoldersEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _Cleared value)?  cleared,TResult Function( _WriteFailed value)?  writeFailed,TResult Function( _FolderOpened value)?  folderOpened,TResult Function( _MembershipRequested value)?  membershipRequested,TResult Function( _CreateRequested value)?  createRequested,TResult Function( _RenameRequested value)?  renameRequested,TResult Function( _DeleteRequested value)?  deleteRequested,TResult Function( _SaveRequested value)?  saveRequested,TResult Function( _ItemRemoved value)?  itemRemoved,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _Cleared() when cleared != null:
return cleared(_that);case _WriteFailed() when writeFailed != null:
return writeFailed(_that);case _FolderOpened() when folderOpened != null:
return folderOpened(_that);case _MembershipRequested() when membershipRequested != null:
return membershipRequested(_that);case _CreateRequested() when createRequested != null:
return createRequested(_that);case _RenameRequested() when renameRequested != null:
return renameRequested(_that);case _DeleteRequested() when deleteRequested != null:
return deleteRequested(_that);case _SaveRequested() when saveRequested != null:
return saveRequested(_that);case _ItemRemoved() when itemRemoved != null:
return itemRemoved(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _Cleared value)  cleared,required TResult Function( _WriteFailed value)  writeFailed,required TResult Function( _FolderOpened value)  folderOpened,required TResult Function( _MembershipRequested value)  membershipRequested,required TResult Function( _CreateRequested value)  createRequested,required TResult Function( _RenameRequested value)  renameRequested,required TResult Function( _DeleteRequested value)  deleteRequested,required TResult Function( _SaveRequested value)  saveRequested,required TResult Function( _ItemRemoved value)  itemRemoved,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _Cleared():
return cleared(_that);case _WriteFailed():
return writeFailed(_that);case _FolderOpened():
return folderOpened(_that);case _MembershipRequested():
return membershipRequested(_that);case _CreateRequested():
return createRequested(_that);case _RenameRequested():
return renameRequested(_that);case _DeleteRequested():
return deleteRequested(_that);case _SaveRequested():
return saveRequested(_that);case _ItemRemoved():
return itemRemoved(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _Cleared value)?  cleared,TResult? Function( _WriteFailed value)?  writeFailed,TResult? Function( _FolderOpened value)?  folderOpened,TResult? Function( _MembershipRequested value)?  membershipRequested,TResult? Function( _CreateRequested value)?  createRequested,TResult? Function( _RenameRequested value)?  renameRequested,TResult? Function( _DeleteRequested value)?  deleteRequested,TResult? Function( _SaveRequested value)?  saveRequested,TResult? Function( _ItemRemoved value)?  itemRemoved,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _Cleared() when cleared != null:
return cleared(_that);case _WriteFailed() when writeFailed != null:
return writeFailed(_that);case _FolderOpened() when folderOpened != null:
return folderOpened(_that);case _MembershipRequested() when membershipRequested != null:
return membershipRequested(_that);case _CreateRequested() when createRequested != null:
return createRequested(_that);case _RenameRequested() when renameRequested != null:
return renameRequested(_that);case _DeleteRequested() when deleteRequested != null:
return deleteRequested(_that);case _SaveRequested() when saveRequested != null:
return saveRequested(_that);case _ItemRemoved() when itemRemoved != null:
return itemRemoved(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String userId,  int operationId)?  started,TResult Function()?  cleared,TResult Function( String userId,  Failure failure)?  writeFailed,TResult Function( String folderId,  int operationId)?  folderOpened,TResult Function( FavouriteWallEntity wall,  int operationId)?  membershipRequested,TResult Function( String name,  FavouriteWallEntity? wall,  int operationId)?  createRequested,TResult Function( String folderId,  String name,  int operationId)?  renameRequested,TResult Function( String folderId,  int operationId)?  deleteRequested,TResult Function( FavouriteWallEntity wall,  Set<String> folderIds,  List<String> newNames,  int operationId)?  saveRequested,TResult Function( String folderId,  FavouriteWallEntity wall,  int operationId)?  itemRemoved,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.userId,_that.operationId);case _Cleared() when cleared != null:
return cleared();case _WriteFailed() when writeFailed != null:
return writeFailed(_that.userId,_that.failure);case _FolderOpened() when folderOpened != null:
return folderOpened(_that.folderId,_that.operationId);case _MembershipRequested() when membershipRequested != null:
return membershipRequested(_that.wall,_that.operationId);case _CreateRequested() when createRequested != null:
return createRequested(_that.name,_that.wall,_that.operationId);case _RenameRequested() when renameRequested != null:
return renameRequested(_that.folderId,_that.name,_that.operationId);case _DeleteRequested() when deleteRequested != null:
return deleteRequested(_that.folderId,_that.operationId);case _SaveRequested() when saveRequested != null:
return saveRequested(_that.wall,_that.folderIds,_that.newNames,_that.operationId);case _ItemRemoved() when itemRemoved != null:
return itemRemoved(_that.folderId,_that.wall,_that.operationId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String userId,  int operationId)  started,required TResult Function()  cleared,required TResult Function( String userId,  Failure failure)  writeFailed,required TResult Function( String folderId,  int operationId)  folderOpened,required TResult Function( FavouriteWallEntity wall,  int operationId)  membershipRequested,required TResult Function( String name,  FavouriteWallEntity? wall,  int operationId)  createRequested,required TResult Function( String folderId,  String name,  int operationId)  renameRequested,required TResult Function( String folderId,  int operationId)  deleteRequested,required TResult Function( FavouriteWallEntity wall,  Set<String> folderIds,  List<String> newNames,  int operationId)  saveRequested,required TResult Function( String folderId,  FavouriteWallEntity wall,  int operationId)  itemRemoved,}) {final _that = this;
switch (_that) {
case _Started():
return started(_that.userId,_that.operationId);case _Cleared():
return cleared();case _WriteFailed():
return writeFailed(_that.userId,_that.failure);case _FolderOpened():
return folderOpened(_that.folderId,_that.operationId);case _MembershipRequested():
return membershipRequested(_that.wall,_that.operationId);case _CreateRequested():
return createRequested(_that.name,_that.wall,_that.operationId);case _RenameRequested():
return renameRequested(_that.folderId,_that.name,_that.operationId);case _DeleteRequested():
return deleteRequested(_that.folderId,_that.operationId);case _SaveRequested():
return saveRequested(_that.wall,_that.folderIds,_that.newNames,_that.operationId);case _ItemRemoved():
return itemRemoved(_that.folderId,_that.wall,_that.operationId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String userId,  int operationId)?  started,TResult? Function()?  cleared,TResult? Function( String userId,  Failure failure)?  writeFailed,TResult? Function( String folderId,  int operationId)?  folderOpened,TResult? Function( FavouriteWallEntity wall,  int operationId)?  membershipRequested,TResult? Function( String name,  FavouriteWallEntity? wall,  int operationId)?  createRequested,TResult? Function( String folderId,  String name,  int operationId)?  renameRequested,TResult? Function( String folderId,  int operationId)?  deleteRequested,TResult? Function( FavouriteWallEntity wall,  Set<String> folderIds,  List<String> newNames,  int operationId)?  saveRequested,TResult? Function( String folderId,  FavouriteWallEntity wall,  int operationId)?  itemRemoved,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.userId,_that.operationId);case _Cleared() when cleared != null:
return cleared();case _WriteFailed() when writeFailed != null:
return writeFailed(_that.userId,_that.failure);case _FolderOpened() when folderOpened != null:
return folderOpened(_that.folderId,_that.operationId);case _MembershipRequested() when membershipRequested != null:
return membershipRequested(_that.wall,_that.operationId);case _CreateRequested() when createRequested != null:
return createRequested(_that.name,_that.wall,_that.operationId);case _RenameRequested() when renameRequested != null:
return renameRequested(_that.folderId,_that.name,_that.operationId);case _DeleteRequested() when deleteRequested != null:
return deleteRequested(_that.folderId,_that.operationId);case _SaveRequested() when saveRequested != null:
return saveRequested(_that.wall,_that.folderIds,_that.newNames,_that.operationId);case _ItemRemoved() when itemRemoved != null:
return itemRemoved(_that.folderId,_that.wall,_that.operationId);case _:
  return null;

}
}

}

/// @nodoc


class _Started implements FoldersEvent {
  const _Started({required this.userId, this.operationId = 0});
  

 final  String userId;
@JsonKey() final  int operationId;

/// Create a copy of FoldersEvent
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
  return 'FoldersEvent.started(userId: $userId, operationId: $operationId)';
}


}

/// @nodoc
abstract mixin class _$StartedCopyWith<$Res> implements $FoldersEventCopyWith<$Res> {
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

/// Create a copy of FoldersEvent
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


class _Cleared implements FoldersEvent {
  const _Cleared();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Cleared);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FoldersEvent.cleared()';
}


}




/// @nodoc


class _WriteFailed implements FoldersEvent {
  const _WriteFailed({required this.userId, required this.failure});


 final  String userId;
 final  Failure failure;

/// Create a copy of FoldersEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WriteFailedCopyWith<_WriteFailed> get copyWith => __$WriteFailedCopyWithImpl<_WriteFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WriteFailed&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,userId,failure);

@override
String toString() {
  return 'FoldersEvent.writeFailed(userId: $userId, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$WriteFailedCopyWith<$Res> implements $FoldersEventCopyWith<$Res> {
  factory _$WriteFailedCopyWith(_WriteFailed value, $Res Function(_WriteFailed) _then) = __$WriteFailedCopyWithImpl;
@useResult
$Res call({
 String userId, Failure failure
});




}
/// @nodoc
class __$WriteFailedCopyWithImpl<$Res>
    implements _$WriteFailedCopyWith<$Res> {
  __$WriteFailedCopyWithImpl(this._self, this._then);

  final _WriteFailed _self;
  final $Res Function(_WriteFailed) _then;

/// Create a copy of FoldersEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? failure = null,}) {
  return _then(_WriteFailed(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,failure: null == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure,
  ));
}


}

/// @nodoc


class _FolderOpened implements FoldersEvent {
  const _FolderOpened({required this.folderId, this.operationId = 0});
  

 final  String folderId;
@JsonKey() final  int operationId;

/// Create a copy of FoldersEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FolderOpenedCopyWith<_FolderOpened> get copyWith => __$FolderOpenedCopyWithImpl<_FolderOpened>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FolderOpened&&(identical(other.folderId, folderId) || other.folderId == folderId)&&(identical(other.operationId, operationId) || other.operationId == operationId));
}


@override
int get hashCode => Object.hash(runtimeType,folderId,operationId);

@override
String toString() {
  return 'FoldersEvent.folderOpened(folderId: $folderId, operationId: $operationId)';
}


}

/// @nodoc
abstract mixin class _$FolderOpenedCopyWith<$Res> implements $FoldersEventCopyWith<$Res> {
  factory _$FolderOpenedCopyWith(_FolderOpened value, $Res Function(_FolderOpened) _then) = __$FolderOpenedCopyWithImpl;
@useResult
$Res call({
 String folderId, int operationId
});




}
/// @nodoc
class __$FolderOpenedCopyWithImpl<$Res>
    implements _$FolderOpenedCopyWith<$Res> {
  __$FolderOpenedCopyWithImpl(this._self, this._then);

  final _FolderOpened _self;
  final $Res Function(_FolderOpened) _then;

/// Create a copy of FoldersEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? folderId = null,Object? operationId = null,}) {
  return _then(_FolderOpened(
folderId: null == folderId ? _self.folderId : folderId // ignore: cast_nullable_to_non_nullable
as String,operationId: null == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _MembershipRequested implements FoldersEvent {
  const _MembershipRequested({required this.wall, this.operationId = 0});
  

 final  FavouriteWallEntity wall;
@JsonKey() final  int operationId;

/// Create a copy of FoldersEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MembershipRequestedCopyWith<_MembershipRequested> get copyWith => __$MembershipRequestedCopyWithImpl<_MembershipRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MembershipRequested&&(identical(other.wall, wall) || other.wall == wall)&&(identical(other.operationId, operationId) || other.operationId == operationId));
}


@override
int get hashCode => Object.hash(runtimeType,wall,operationId);

@override
String toString() {
  return 'FoldersEvent.membershipRequested(wall: $wall, operationId: $operationId)';
}


}

/// @nodoc
abstract mixin class _$MembershipRequestedCopyWith<$Res> implements $FoldersEventCopyWith<$Res> {
  factory _$MembershipRequestedCopyWith(_MembershipRequested value, $Res Function(_MembershipRequested) _then) = __$MembershipRequestedCopyWithImpl;
@useResult
$Res call({
 FavouriteWallEntity wall, int operationId
});




}
/// @nodoc
class __$MembershipRequestedCopyWithImpl<$Res>
    implements _$MembershipRequestedCopyWith<$Res> {
  __$MembershipRequestedCopyWithImpl(this._self, this._then);

  final _MembershipRequested _self;
  final $Res Function(_MembershipRequested) _then;

/// Create a copy of FoldersEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? wall = null,Object? operationId = null,}) {
  return _then(_MembershipRequested(
wall: null == wall ? _self.wall : wall // ignore: cast_nullable_to_non_nullable
as FavouriteWallEntity,operationId: null == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _CreateRequested implements FoldersEvent {
  const _CreateRequested({required this.name, this.wall, this.operationId = 0});
  

 final  String name;
 final  FavouriteWallEntity? wall;
@JsonKey() final  int operationId;

/// Create a copy of FoldersEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CreateRequestedCopyWith<_CreateRequested> get copyWith => __$CreateRequestedCopyWithImpl<_CreateRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CreateRequested&&(identical(other.name, name) || other.name == name)&&(identical(other.wall, wall) || other.wall == wall)&&(identical(other.operationId, operationId) || other.operationId == operationId));
}


@override
int get hashCode => Object.hash(runtimeType,name,wall,operationId);

@override
String toString() {
  return 'FoldersEvent.createRequested(name: $name, wall: $wall, operationId: $operationId)';
}


}

/// @nodoc
abstract mixin class _$CreateRequestedCopyWith<$Res> implements $FoldersEventCopyWith<$Res> {
  factory _$CreateRequestedCopyWith(_CreateRequested value, $Res Function(_CreateRequested) _then) = __$CreateRequestedCopyWithImpl;
@useResult
$Res call({
 String name, FavouriteWallEntity? wall, int operationId
});




}
/// @nodoc
class __$CreateRequestedCopyWithImpl<$Res>
    implements _$CreateRequestedCopyWith<$Res> {
  __$CreateRequestedCopyWithImpl(this._self, this._then);

  final _CreateRequested _self;
  final $Res Function(_CreateRequested) _then;

/// Create a copy of FoldersEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,Object? wall = freezed,Object? operationId = null,}) {
  return _then(_CreateRequested(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,wall: freezed == wall ? _self.wall : wall // ignore: cast_nullable_to_non_nullable
as FavouriteWallEntity?,operationId: null == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _RenameRequested implements FoldersEvent {
  const _RenameRequested({required this.folderId, required this.name, this.operationId = 0});
  

 final  String folderId;
 final  String name;
@JsonKey() final  int operationId;

/// Create a copy of FoldersEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RenameRequestedCopyWith<_RenameRequested> get copyWith => __$RenameRequestedCopyWithImpl<_RenameRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RenameRequested&&(identical(other.folderId, folderId) || other.folderId == folderId)&&(identical(other.name, name) || other.name == name)&&(identical(other.operationId, operationId) || other.operationId == operationId));
}


@override
int get hashCode => Object.hash(runtimeType,folderId,name,operationId);

@override
String toString() {
  return 'FoldersEvent.renameRequested(folderId: $folderId, name: $name, operationId: $operationId)';
}


}

/// @nodoc
abstract mixin class _$RenameRequestedCopyWith<$Res> implements $FoldersEventCopyWith<$Res> {
  factory _$RenameRequestedCopyWith(_RenameRequested value, $Res Function(_RenameRequested) _then) = __$RenameRequestedCopyWithImpl;
@useResult
$Res call({
 String folderId, String name, int operationId
});




}
/// @nodoc
class __$RenameRequestedCopyWithImpl<$Res>
    implements _$RenameRequestedCopyWith<$Res> {
  __$RenameRequestedCopyWithImpl(this._self, this._then);

  final _RenameRequested _self;
  final $Res Function(_RenameRequested) _then;

/// Create a copy of FoldersEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? folderId = null,Object? name = null,Object? operationId = null,}) {
  return _then(_RenameRequested(
folderId: null == folderId ? _self.folderId : folderId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,operationId: null == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _DeleteRequested implements FoldersEvent {
  const _DeleteRequested({required this.folderId, this.operationId = 0});
  

 final  String folderId;
@JsonKey() final  int operationId;

/// Create a copy of FoldersEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeleteRequestedCopyWith<_DeleteRequested> get copyWith => __$DeleteRequestedCopyWithImpl<_DeleteRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeleteRequested&&(identical(other.folderId, folderId) || other.folderId == folderId)&&(identical(other.operationId, operationId) || other.operationId == operationId));
}


@override
int get hashCode => Object.hash(runtimeType,folderId,operationId);

@override
String toString() {
  return 'FoldersEvent.deleteRequested(folderId: $folderId, operationId: $operationId)';
}


}

/// @nodoc
abstract mixin class _$DeleteRequestedCopyWith<$Res> implements $FoldersEventCopyWith<$Res> {
  factory _$DeleteRequestedCopyWith(_DeleteRequested value, $Res Function(_DeleteRequested) _then) = __$DeleteRequestedCopyWithImpl;
@useResult
$Res call({
 String folderId, int operationId
});




}
/// @nodoc
class __$DeleteRequestedCopyWithImpl<$Res>
    implements _$DeleteRequestedCopyWith<$Res> {
  __$DeleteRequestedCopyWithImpl(this._self, this._then);

  final _DeleteRequested _self;
  final $Res Function(_DeleteRequested) _then;

/// Create a copy of FoldersEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? folderId = null,Object? operationId = null,}) {
  return _then(_DeleteRequested(
folderId: null == folderId ? _self.folderId : folderId // ignore: cast_nullable_to_non_nullable
as String,operationId: null == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _SaveRequested implements FoldersEvent {
  const _SaveRequested({required this.wall, required final  Set<String> folderIds, final  List<String> newNames = const <String>[], this.operationId = 0}): _folderIds = folderIds,_newNames = newNames;
  

 final  FavouriteWallEntity wall;
 final  Set<String> _folderIds;
 Set<String> get folderIds {
  if (_folderIds is EqualUnmodifiableSetView) return _folderIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_folderIds);
}

 final  List<String> _newNames;
@JsonKey() List<String> get newNames {
  if (_newNames is EqualUnmodifiableListView) return _newNames;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_newNames);
}

@JsonKey() final  int operationId;

/// Create a copy of FoldersEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SaveRequestedCopyWith<_SaveRequested> get copyWith => __$SaveRequestedCopyWithImpl<_SaveRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SaveRequested&&(identical(other.wall, wall) || other.wall == wall)&&const DeepCollectionEquality().equals(other._folderIds, _folderIds)&&const DeepCollectionEquality().equals(other._newNames, _newNames)&&(identical(other.operationId, operationId) || other.operationId == operationId));
}


@override
int get hashCode => Object.hash(runtimeType,wall,const DeepCollectionEquality().hash(_folderIds),const DeepCollectionEquality().hash(_newNames),operationId);

@override
String toString() {
  return 'FoldersEvent.saveRequested(wall: $wall, folderIds: $folderIds, newNames: $newNames, operationId: $operationId)';
}


}

/// @nodoc
abstract mixin class _$SaveRequestedCopyWith<$Res> implements $FoldersEventCopyWith<$Res> {
  factory _$SaveRequestedCopyWith(_SaveRequested value, $Res Function(_SaveRequested) _then) = __$SaveRequestedCopyWithImpl;
@useResult
$Res call({
 FavouriteWallEntity wall, Set<String> folderIds, List<String> newNames, int operationId
});




}
/// @nodoc
class __$SaveRequestedCopyWithImpl<$Res>
    implements _$SaveRequestedCopyWith<$Res> {
  __$SaveRequestedCopyWithImpl(this._self, this._then);

  final _SaveRequested _self;
  final $Res Function(_SaveRequested) _then;

/// Create a copy of FoldersEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? wall = null,Object? folderIds = null,Object? newNames = null,Object? operationId = null,}) {
  return _then(_SaveRequested(
wall: null == wall ? _self.wall : wall // ignore: cast_nullable_to_non_nullable
as FavouriteWallEntity,folderIds: null == folderIds ? _self._folderIds : folderIds // ignore: cast_nullable_to_non_nullable
as Set<String>,newNames: null == newNames ? _self._newNames : newNames // ignore: cast_nullable_to_non_nullable
as List<String>,operationId: null == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class _ItemRemoved implements FoldersEvent {
  const _ItemRemoved({required this.folderId, required this.wall, this.operationId = 0});
  

 final  String folderId;
 final  FavouriteWallEntity wall;
@JsonKey() final  int operationId;

/// Create a copy of FoldersEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ItemRemovedCopyWith<_ItemRemoved> get copyWith => __$ItemRemovedCopyWithImpl<_ItemRemoved>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ItemRemoved&&(identical(other.folderId, folderId) || other.folderId == folderId)&&(identical(other.wall, wall) || other.wall == wall)&&(identical(other.operationId, operationId) || other.operationId == operationId));
}


@override
int get hashCode => Object.hash(runtimeType,folderId,wall,operationId);

@override
String toString() {
  return 'FoldersEvent.itemRemoved(folderId: $folderId, wall: $wall, operationId: $operationId)';
}


}

/// @nodoc
abstract mixin class _$ItemRemovedCopyWith<$Res> implements $FoldersEventCopyWith<$Res> {
  factory _$ItemRemovedCopyWith(_ItemRemoved value, $Res Function(_ItemRemoved) _then) = __$ItemRemovedCopyWithImpl;
@useResult
$Res call({
 String folderId, FavouriteWallEntity wall, int operationId
});




}
/// @nodoc
class __$ItemRemovedCopyWithImpl<$Res>
    implements _$ItemRemovedCopyWith<$Res> {
  __$ItemRemovedCopyWithImpl(this._self, this._then);

  final _ItemRemoved _self;
  final $Res Function(_ItemRemoved) _then;

/// Create a copy of FoldersEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? folderId = null,Object? wall = null,Object? operationId = null,}) {
  return _then(_ItemRemoved(
folderId: null == folderId ? _self.folderId : folderId // ignore: cast_nullable_to_non_nullable
as String,wall: null == wall ? _self.wall : wall // ignore: cast_nullable_to_non_nullable
as FavouriteWallEntity,operationId: null == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$FoldersState {

 LoadStatus get status; String get userId; List<FolderEntity> get folders;/// Loaded walls per folder id, newest first.
 Map<String, List<FavouriteWallEntity>> get items; Map<String, LoadStatus> get itemsStatus;/// Folder ids that hold each wall, keyed by [folderItemKey].
 Map<String, Set<String>> get membership; Map<String, LoadStatus> get membershipStatus; ActionStatus get actionStatus; int get completedOperationId; Failure? get failure; Failure? get queuedWriteFailure;
/// Create a copy of FoldersState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FoldersStateCopyWith<FoldersState> get copyWith => _$FoldersStateCopyWithImpl<FoldersState>(this as FoldersState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FoldersState&&(identical(other.status, status) || other.status == status)&&(identical(other.userId, userId) || other.userId == userId)&&const DeepCollectionEquality().equals(other.folders, folders)&&const DeepCollectionEquality().equals(other.items, items)&&const DeepCollectionEquality().equals(other.itemsStatus, itemsStatus)&&const DeepCollectionEquality().equals(other.membership, membership)&&const DeepCollectionEquality().equals(other.membershipStatus, membershipStatus)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&(identical(other.completedOperationId, completedOperationId) || other.completedOperationId == completedOperationId)&&(identical(other.failure, failure) || other.failure == failure)&&(identical(other.queuedWriteFailure, queuedWriteFailure) || other.queuedWriteFailure == queuedWriteFailure));
}


@override
int get hashCode => Object.hash(runtimeType,status,userId,const DeepCollectionEquality().hash(folders),const DeepCollectionEquality().hash(items),const DeepCollectionEquality().hash(itemsStatus),const DeepCollectionEquality().hash(membership),const DeepCollectionEquality().hash(membershipStatus),actionStatus,completedOperationId,failure,queuedWriteFailure);

@override
String toString() {
  return 'FoldersState(status: $status, userId: $userId, folders: $folders, items: $items, itemsStatus: $itemsStatus, membership: $membership, membershipStatus: $membershipStatus, actionStatus: $actionStatus, completedOperationId: $completedOperationId, failure: $failure, queuedWriteFailure: $queuedWriteFailure)';
}


}

/// @nodoc
abstract mixin class $FoldersStateCopyWith<$Res>  {
  factory $FoldersStateCopyWith(FoldersState value, $Res Function(FoldersState) _then) = _$FoldersStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, String userId, List<FolderEntity> folders, Map<String, List<FavouriteWallEntity>> items, Map<String, LoadStatus> itemsStatus, Map<String, Set<String>> membership, Map<String, LoadStatus> membershipStatus, ActionStatus actionStatus, int completedOperationId, Failure? failure, Failure? queuedWriteFailure
});




}
/// @nodoc
class _$FoldersStateCopyWithImpl<$Res>
    implements $FoldersStateCopyWith<$Res> {
  _$FoldersStateCopyWithImpl(this._self, this._then);

  final FoldersState _self;
  final $Res Function(FoldersState) _then;

/// Create a copy of FoldersState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? userId = null,Object? folders = null,Object? items = null,Object? itemsStatus = null,Object? membership = null,Object? membershipStatus = null,Object? actionStatus = null,Object? completedOperationId = null,Object? failure = freezed,Object? queuedWriteFailure = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,folders: null == folders ? _self.folders : folders // ignore: cast_nullable_to_non_nullable
as List<FolderEntity>,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as Map<String, List<FavouriteWallEntity>>,itemsStatus: null == itemsStatus ? _self.itemsStatus : itemsStatus // ignore: cast_nullable_to_non_nullable
as Map<String, LoadStatus>,membership: null == membership ? _self.membership : membership // ignore: cast_nullable_to_non_nullable
as Map<String, Set<String>>,membershipStatus: null == membershipStatus ? _self.membershipStatus : membershipStatus // ignore: cast_nullable_to_non_nullable
as Map<String, LoadStatus>,actionStatus: null == actionStatus ? _self.actionStatus : actionStatus // ignore: cast_nullable_to_non_nullable
as ActionStatus,completedOperationId: null == completedOperationId ? _self.completedOperationId : completedOperationId // ignore: cast_nullable_to_non_nullable
as int,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,queuedWriteFailure: freezed == queuedWriteFailure ? _self.queuedWriteFailure : queuedWriteFailure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}

}


/// Adds pattern-matching-related methods to [FoldersState].
extension FoldersStatePatterns on FoldersState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FoldersState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FoldersState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FoldersState value)  $default,){
final _that = this;
switch (_that) {
case _FoldersState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FoldersState value)?  $default,){
final _that = this;
switch (_that) {
case _FoldersState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  String userId,  List<FolderEntity> folders,  Map<String, List<FavouriteWallEntity>> items,  Map<String, LoadStatus> itemsStatus,  Map<String, Set<String>> membership,  Map<String, LoadStatus> membershipStatus,  ActionStatus actionStatus,  int completedOperationId,  Failure? failure,  Failure? queuedWriteFailure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FoldersState() when $default != null:
return $default(_that.status,_that.userId,_that.folders,_that.items,_that.itemsStatus,_that.membership,_that.membershipStatus,_that.actionStatus,_that.completedOperationId,_that.failure,_that.queuedWriteFailure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  String userId,  List<FolderEntity> folders,  Map<String, List<FavouriteWallEntity>> items,  Map<String, LoadStatus> itemsStatus,  Map<String, Set<String>> membership,  Map<String, LoadStatus> membershipStatus,  ActionStatus actionStatus,  int completedOperationId,  Failure? failure,  Failure? queuedWriteFailure)  $default,) {final _that = this;
switch (_that) {
case _FoldersState():
return $default(_that.status,_that.userId,_that.folders,_that.items,_that.itemsStatus,_that.membership,_that.membershipStatus,_that.actionStatus,_that.completedOperationId,_that.failure,_that.queuedWriteFailure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  String userId,  List<FolderEntity> folders,  Map<String, List<FavouriteWallEntity>> items,  Map<String, LoadStatus> itemsStatus,  Map<String, Set<String>> membership,  Map<String, LoadStatus> membershipStatus,  ActionStatus actionStatus,  int completedOperationId,  Failure? failure,  Failure? queuedWriteFailure)?  $default,) {final _that = this;
switch (_that) {
case _FoldersState() when $default != null:
return $default(_that.status,_that.userId,_that.folders,_that.items,_that.itemsStatus,_that.membership,_that.membershipStatus,_that.actionStatus,_that.completedOperationId,_that.failure,_that.queuedWriteFailure);case _:
  return null;

}
}

}

/// @nodoc


class _FoldersState extends FoldersState {
  const _FoldersState({required this.status, required this.userId, required final  List<FolderEntity> folders, final  Map<String, List<FavouriteWallEntity>> items = const <String, List<FavouriteWallEntity>>{}, final  Map<String, LoadStatus> itemsStatus = const <String, LoadStatus>{}, final  Map<String, Set<String>> membership = const <String, Set<String>>{}, final  Map<String, LoadStatus> membershipStatus = const <String, LoadStatus>{}, this.actionStatus = ActionStatus.idle, this.completedOperationId = 0, this.failure, this.queuedWriteFailure}): _folders = folders,_items = items,_itemsStatus = itemsStatus,_membership = membership,_membershipStatus = membershipStatus,super._();
  

@override final  LoadStatus status;
@override final  String userId;
 final  List<FolderEntity> _folders;
@override List<FolderEntity> get folders {
  if (_folders is EqualUnmodifiableListView) return _folders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_folders);
}

/// Loaded walls per folder id, newest first.
 final  Map<String, List<FavouriteWallEntity>> _items;
/// Loaded walls per folder id, newest first.
@override@JsonKey() Map<String, List<FavouriteWallEntity>> get items {
  if (_items is EqualUnmodifiableMapView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_items);
}

 final  Map<String, LoadStatus> _itemsStatus;
@override@JsonKey() Map<String, LoadStatus> get itemsStatus {
  if (_itemsStatus is EqualUnmodifiableMapView) return _itemsStatus;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_itemsStatus);
}

/// Folder ids that hold each wall, keyed by [folderItemKey].
 final  Map<String, Set<String>> _membership;
/// Folder ids that hold each wall, keyed by [folderItemKey].
@override@JsonKey() Map<String, Set<String>> get membership {
  if (_membership is EqualUnmodifiableMapView) return _membership;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_membership);
}

 final  Map<String, LoadStatus> _membershipStatus;
@override@JsonKey() Map<String, LoadStatus> get membershipStatus {
  if (_membershipStatus is EqualUnmodifiableMapView) return _membershipStatus;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_membershipStatus);
}

@override@JsonKey() final  ActionStatus actionStatus;
@override@JsonKey() final  int completedOperationId;
@override final  Failure? failure;
@override final  Failure? queuedWriteFailure;

/// Create a copy of FoldersState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FoldersStateCopyWith<_FoldersState> get copyWith => __$FoldersStateCopyWithImpl<_FoldersState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FoldersState&&(identical(other.status, status) || other.status == status)&&(identical(other.userId, userId) || other.userId == userId)&&const DeepCollectionEquality().equals(other._folders, _folders)&&const DeepCollectionEquality().equals(other._items, _items)&&const DeepCollectionEquality().equals(other._itemsStatus, _itemsStatus)&&const DeepCollectionEquality().equals(other._membership, _membership)&&const DeepCollectionEquality().equals(other._membershipStatus, _membershipStatus)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&(identical(other.completedOperationId, completedOperationId) || other.completedOperationId == completedOperationId)&&(identical(other.failure, failure) || other.failure == failure)&&(identical(other.queuedWriteFailure, queuedWriteFailure) || other.queuedWriteFailure == queuedWriteFailure));
}


@override
int get hashCode => Object.hash(runtimeType,status,userId,const DeepCollectionEquality().hash(_folders),const DeepCollectionEquality().hash(_items),const DeepCollectionEquality().hash(_itemsStatus),const DeepCollectionEquality().hash(_membership),const DeepCollectionEquality().hash(_membershipStatus),actionStatus,completedOperationId,failure,queuedWriteFailure);

@override
String toString() {
  return 'FoldersState(status: $status, userId: $userId, folders: $folders, items: $items, itemsStatus: $itemsStatus, membership: $membership, membershipStatus: $membershipStatus, actionStatus: $actionStatus, completedOperationId: $completedOperationId, failure: $failure, queuedWriteFailure: $queuedWriteFailure)';
}


}

/// @nodoc
abstract mixin class _$FoldersStateCopyWith<$Res> implements $FoldersStateCopyWith<$Res> {
  factory _$FoldersStateCopyWith(_FoldersState value, $Res Function(_FoldersState) _then) = __$FoldersStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, String userId, List<FolderEntity> folders, Map<String, List<FavouriteWallEntity>> items, Map<String, LoadStatus> itemsStatus, Map<String, Set<String>> membership, Map<String, LoadStatus> membershipStatus, ActionStatus actionStatus, int completedOperationId, Failure? failure, Failure? queuedWriteFailure
});




}
/// @nodoc
class __$FoldersStateCopyWithImpl<$Res>
    implements _$FoldersStateCopyWith<$Res> {
  __$FoldersStateCopyWithImpl(this._self, this._then);

  final _FoldersState _self;
  final $Res Function(_FoldersState) _then;

/// Create a copy of FoldersState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? userId = null,Object? folders = null,Object? items = null,Object? itemsStatus = null,Object? membership = null,Object? membershipStatus = null,Object? actionStatus = null,Object? completedOperationId = null,Object? failure = freezed,Object? queuedWriteFailure = freezed,}) {
  return _then(_FoldersState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,folders: null == folders ? _self._folders : folders // ignore: cast_nullable_to_non_nullable
as List<FolderEntity>,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as Map<String, List<FavouriteWallEntity>>,itemsStatus: null == itemsStatus ? _self._itemsStatus : itemsStatus // ignore: cast_nullable_to_non_nullable
as Map<String, LoadStatus>,membership: null == membership ? _self._membership : membership // ignore: cast_nullable_to_non_nullable
as Map<String, Set<String>>,membershipStatus: null == membershipStatus ? _self._membershipStatus : membershipStatus // ignore: cast_nullable_to_non_nullable
as Map<String, LoadStatus>,actionStatus: null == actionStatus ? _self.actionStatus : actionStatus // ignore: cast_nullable_to_non_nullable
as ActionStatus,completedOperationId: null == completedOperationId ? _self.completedOperationId : completedOperationId // ignore: cast_nullable_to_non_nullable
as int,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,queuedWriteFailure: freezed == queuedWriteFailure ? _self.queuedWriteFailure : queuedWriteFailure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}


}

// dart format on
