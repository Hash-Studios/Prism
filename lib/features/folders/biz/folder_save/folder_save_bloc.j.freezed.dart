// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'folder_save_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FolderSaveEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FolderSaveEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FolderSaveEvent()';
}


}

/// @nodoc
class $FolderSaveEventCopyWith<$Res>  {
$FolderSaveEventCopyWith(FolderSaveEvent _, $Res Function(FolderSaveEvent) __);
}


/// Adds pattern-matching-related methods to [FolderSaveEvent].
extension FolderSaveEventPatterns on FolderSaveEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _PlanRequested value)?  planRequested,TResult Function( _Started value)?  started,TResult Function( _CancelRequested value)?  cancelRequested,TResult Function( _RetryRequested value)?  retryRequested,TResult Function( _Dismissed value)?  dismissed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlanRequested() when planRequested != null:
return planRequested(_that);case _Started() when started != null:
return started(_that);case _CancelRequested() when cancelRequested != null:
return cancelRequested(_that);case _RetryRequested() when retryRequested != null:
return retryRequested(_that);case _Dismissed() when dismissed != null:
return dismissed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _PlanRequested value)  planRequested,required TResult Function( _Started value)  started,required TResult Function( _CancelRequested value)  cancelRequested,required TResult Function( _RetryRequested value)  retryRequested,required TResult Function( _Dismissed value)  dismissed,}){
final _that = this;
switch (_that) {
case _PlanRequested():
return planRequested(_that);case _Started():
return started(_that);case _CancelRequested():
return cancelRequested(_that);case _RetryRequested():
return retryRequested(_that);case _Dismissed():
return dismissed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _PlanRequested value)?  planRequested,TResult? Function( _Started value)?  started,TResult? Function( _CancelRequested value)?  cancelRequested,TResult? Function( _RetryRequested value)?  retryRequested,TResult? Function( _Dismissed value)?  dismissed,}){
final _that = this;
switch (_that) {
case _PlanRequested() when planRequested != null:
return planRequested(_that);case _Started() when started != null:
return started(_that);case _CancelRequested() when cancelRequested != null:
return cancelRequested(_that);case _RetryRequested() when retryRequested != null:
return retryRequested(_that);case _Dismissed() when dismissed != null:
return dismissed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( FolderSaveTarget target,  List<FolderSaveWall> walls)?  planRequested,TResult Function( FolderSaveChoice choice,  FolderSaveAnnouncer? announce)?  started,TResult Function()?  cancelRequested,TResult Function( FolderSaveAnnouncer? announce)?  retryRequested,TResult Function()?  dismissed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlanRequested() when planRequested != null:
return planRequested(_that.target,_that.walls);case _Started() when started != null:
return started(_that.choice,_that.announce);case _CancelRequested() when cancelRequested != null:
return cancelRequested();case _RetryRequested() when retryRequested != null:
return retryRequested(_that.announce);case _Dismissed() when dismissed != null:
return dismissed();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( FolderSaveTarget target,  List<FolderSaveWall> walls)  planRequested,required TResult Function( FolderSaveChoice choice,  FolderSaveAnnouncer? announce)  started,required TResult Function()  cancelRequested,required TResult Function( FolderSaveAnnouncer? announce)  retryRequested,required TResult Function()  dismissed,}) {final _that = this;
switch (_that) {
case _PlanRequested():
return planRequested(_that.target,_that.walls);case _Started():
return started(_that.choice,_that.announce);case _CancelRequested():
return cancelRequested();case _RetryRequested():
return retryRequested(_that.announce);case _Dismissed():
return dismissed();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( FolderSaveTarget target,  List<FolderSaveWall> walls)?  planRequested,TResult? Function( FolderSaveChoice choice,  FolderSaveAnnouncer? announce)?  started,TResult? Function()?  cancelRequested,TResult? Function( FolderSaveAnnouncer? announce)?  retryRequested,TResult? Function()?  dismissed,}) {final _that = this;
switch (_that) {
case _PlanRequested() when planRequested != null:
return planRequested(_that.target,_that.walls);case _Started() when started != null:
return started(_that.choice,_that.announce);case _CancelRequested() when cancelRequested != null:
return cancelRequested();case _RetryRequested() when retryRequested != null:
return retryRequested(_that.announce);case _Dismissed() when dismissed != null:
return dismissed();case _:
  return null;

}
}

}

/// @nodoc


class _PlanRequested implements FolderSaveEvent {
  const _PlanRequested({required this.target, required final  List<FolderSaveWall> walls}): _walls = walls;
  

 final  FolderSaveTarget target;
 final  List<FolderSaveWall> _walls;
 List<FolderSaveWall> get walls {
  if (_walls is EqualUnmodifiableListView) return _walls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_walls);
}


/// Create a copy of FolderSaveEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlanRequestedCopyWith<_PlanRequested> get copyWith => __$PlanRequestedCopyWithImpl<_PlanRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlanRequested&&(identical(other.target, target) || other.target == target)&&const DeepCollectionEquality().equals(other._walls, _walls));
}


@override
int get hashCode => Object.hash(runtimeType,target,const DeepCollectionEquality().hash(_walls));

@override
String toString() {
  return 'FolderSaveEvent.planRequested(target: $target, walls: $walls)';
}


}

/// @nodoc
abstract mixin class _$PlanRequestedCopyWith<$Res> implements $FolderSaveEventCopyWith<$Res> {
  factory _$PlanRequestedCopyWith(_PlanRequested value, $Res Function(_PlanRequested) _then) = __$PlanRequestedCopyWithImpl;
@useResult
$Res call({
 FolderSaveTarget target, List<FolderSaveWall> walls
});




}
/// @nodoc
class __$PlanRequestedCopyWithImpl<$Res>
    implements _$PlanRequestedCopyWith<$Res> {
  __$PlanRequestedCopyWithImpl(this._self, this._then);

  final _PlanRequested _self;
  final $Res Function(_PlanRequested) _then;

/// Create a copy of FolderSaveEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? target = null,Object? walls = null,}) {
  return _then(_PlanRequested(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as FolderSaveTarget,walls: null == walls ? _self._walls : walls // ignore: cast_nullable_to_non_nullable
as List<FolderSaveWall>,
  ));
}


}

/// @nodoc


class _Started implements FolderSaveEvent {
  const _Started({required this.choice, this.announce});
  

 final  FolderSaveChoice choice;
 final  FolderSaveAnnouncer? announce;

/// Create a copy of FolderSaveEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StartedCopyWith<_Started> get copyWith => __$StartedCopyWithImpl<_Started>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started&&(identical(other.choice, choice) || other.choice == choice)&&(identical(other.announce, announce) || other.announce == announce));
}


@override
int get hashCode => Object.hash(runtimeType,choice,announce);

@override
String toString() {
  return 'FolderSaveEvent.started(choice: $choice, announce: $announce)';
}


}

/// @nodoc
abstract mixin class _$StartedCopyWith<$Res> implements $FolderSaveEventCopyWith<$Res> {
  factory _$StartedCopyWith(_Started value, $Res Function(_Started) _then) = __$StartedCopyWithImpl;
@useResult
$Res call({
 FolderSaveChoice choice, FolderSaveAnnouncer? announce
});




}
/// @nodoc
class __$StartedCopyWithImpl<$Res>
    implements _$StartedCopyWith<$Res> {
  __$StartedCopyWithImpl(this._self, this._then);

  final _Started _self;
  final $Res Function(_Started) _then;

/// Create a copy of FolderSaveEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? choice = null,Object? announce = freezed,}) {
  return _then(_Started(
choice: null == choice ? _self.choice : choice // ignore: cast_nullable_to_non_nullable
as FolderSaveChoice,announce: freezed == announce ? _self.announce : announce // ignore: cast_nullable_to_non_nullable
as FolderSaveAnnouncer?,
  ));
}


}

/// @nodoc


class _CancelRequested implements FolderSaveEvent {
  const _CancelRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CancelRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FolderSaveEvent.cancelRequested()';
}


}




/// @nodoc


class _RetryRequested implements FolderSaveEvent {
  const _RetryRequested({this.announce});
  

 final  FolderSaveAnnouncer? announce;

/// Create a copy of FolderSaveEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RetryRequestedCopyWith<_RetryRequested> get copyWith => __$RetryRequestedCopyWithImpl<_RetryRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RetryRequested&&(identical(other.announce, announce) || other.announce == announce));
}


@override
int get hashCode => Object.hash(runtimeType,announce);

@override
String toString() {
  return 'FolderSaveEvent.retryRequested(announce: $announce)';
}


}

/// @nodoc
abstract mixin class _$RetryRequestedCopyWith<$Res> implements $FolderSaveEventCopyWith<$Res> {
  factory _$RetryRequestedCopyWith(_RetryRequested value, $Res Function(_RetryRequested) _then) = __$RetryRequestedCopyWithImpl;
@useResult
$Res call({
 FolderSaveAnnouncer? announce
});




}
/// @nodoc
class __$RetryRequestedCopyWithImpl<$Res>
    implements _$RetryRequestedCopyWith<$Res> {
  __$RetryRequestedCopyWithImpl(this._self, this._then);

  final _RetryRequested _self;
  final $Res Function(_RetryRequested) _then;

/// Create a copy of FolderSaveEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? announce = freezed,}) {
  return _then(_RetryRequested(
announce: freezed == announce ? _self.announce : announce // ignore: cast_nullable_to_non_nullable
as FolderSaveAnnouncer?,
  ));
}


}

/// @nodoc


class _Dismissed implements FolderSaveEvent {
  const _Dismissed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Dismissed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FolderSaveEvent.dismissed()';
}


}




/// @nodoc
mixin _$FolderSaveState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FolderSaveState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FolderSaveState()';
}


}

/// @nodoc
class $FolderSaveStateCopyWith<$Res>  {
$FolderSaveStateCopyWith(FolderSaveState _, $Res Function(FolderSaveState) __);
}


/// Adds pattern-matching-related methods to [FolderSaveState].
extension FolderSaveStatePatterns on FolderSaveState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( FolderSaveIdle value)?  idle,TResult Function( FolderSavePlanning value)?  planning,TResult Function( FolderSavePlanned value)?  planned,TResult Function( FolderSavePlanFailed value)?  planFailed,TResult Function( FolderSaveAccessDenied value)?  accessDenied,TResult Function( FolderSaveRunning value)?  running,TResult Function( FolderSaveFinished value)?  finished,required TResult orElse(),}){
final _that = this;
switch (_that) {
case FolderSaveIdle() when idle != null:
return idle(_that);case FolderSavePlanning() when planning != null:
return planning(_that);case FolderSavePlanned() when planned != null:
return planned(_that);case FolderSavePlanFailed() when planFailed != null:
return planFailed(_that);case FolderSaveAccessDenied() when accessDenied != null:
return accessDenied(_that);case FolderSaveRunning() when running != null:
return running(_that);case FolderSaveFinished() when finished != null:
return finished(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( FolderSaveIdle value)  idle,required TResult Function( FolderSavePlanning value)  planning,required TResult Function( FolderSavePlanned value)  planned,required TResult Function( FolderSavePlanFailed value)  planFailed,required TResult Function( FolderSaveAccessDenied value)  accessDenied,required TResult Function( FolderSaveRunning value)  running,required TResult Function( FolderSaveFinished value)  finished,}){
final _that = this;
switch (_that) {
case FolderSaveIdle():
return idle(_that);case FolderSavePlanning():
return planning(_that);case FolderSavePlanned():
return planned(_that);case FolderSavePlanFailed():
return planFailed(_that);case FolderSaveAccessDenied():
return accessDenied(_that);case FolderSaveRunning():
return running(_that);case FolderSaveFinished():
return finished(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( FolderSaveIdle value)?  idle,TResult? Function( FolderSavePlanning value)?  planning,TResult? Function( FolderSavePlanned value)?  planned,TResult? Function( FolderSavePlanFailed value)?  planFailed,TResult? Function( FolderSaveAccessDenied value)?  accessDenied,TResult? Function( FolderSaveRunning value)?  running,TResult? Function( FolderSaveFinished value)?  finished,}){
final _that = this;
switch (_that) {
case FolderSaveIdle() when idle != null:
return idle(_that);case FolderSavePlanning() when planning != null:
return planning(_that);case FolderSavePlanned() when planned != null:
return planned(_that);case FolderSavePlanFailed() when planFailed != null:
return planFailed(_that);case FolderSaveAccessDenied() when accessDenied != null:
return accessDenied(_that);case FolderSaveRunning() when running != null:
return running(_that);case FolderSaveFinished() when finished != null:
return finished(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function( FolderSaveTarget target)?  planning,TResult Function( FolderSaveTarget target,  FolderSavePlan plan)?  planned,TResult Function( FolderSaveTarget target)?  planFailed,TResult Function( FolderSaveTarget target)?  accessDenied,TResult Function( FolderSaveTarget target,  FolderSaveRun run,  bool cancelling)?  running,TResult Function( FolderSaveTarget target,  FolderSaveRun run,  bool cancelled)?  finished,required TResult orElse(),}) {final _that = this;
switch (_that) {
case FolderSaveIdle() when idle != null:
return idle();case FolderSavePlanning() when planning != null:
return planning(_that.target);case FolderSavePlanned() when planned != null:
return planned(_that.target,_that.plan);case FolderSavePlanFailed() when planFailed != null:
return planFailed(_that.target);case FolderSaveAccessDenied() when accessDenied != null:
return accessDenied(_that.target);case FolderSaveRunning() when running != null:
return running(_that.target,_that.run,_that.cancelling);case FolderSaveFinished() when finished != null:
return finished(_that.target,_that.run,_that.cancelled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function( FolderSaveTarget target)  planning,required TResult Function( FolderSaveTarget target,  FolderSavePlan plan)  planned,required TResult Function( FolderSaveTarget target)  planFailed,required TResult Function( FolderSaveTarget target)  accessDenied,required TResult Function( FolderSaveTarget target,  FolderSaveRun run,  bool cancelling)  running,required TResult Function( FolderSaveTarget target,  FolderSaveRun run,  bool cancelled)  finished,}) {final _that = this;
switch (_that) {
case FolderSaveIdle():
return idle();case FolderSavePlanning():
return planning(_that.target);case FolderSavePlanned():
return planned(_that.target,_that.plan);case FolderSavePlanFailed():
return planFailed(_that.target);case FolderSaveAccessDenied():
return accessDenied(_that.target);case FolderSaveRunning():
return running(_that.target,_that.run,_that.cancelling);case FolderSaveFinished():
return finished(_that.target,_that.run,_that.cancelled);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function( FolderSaveTarget target)?  planning,TResult? Function( FolderSaveTarget target,  FolderSavePlan plan)?  planned,TResult? Function( FolderSaveTarget target)?  planFailed,TResult? Function( FolderSaveTarget target)?  accessDenied,TResult? Function( FolderSaveTarget target,  FolderSaveRun run,  bool cancelling)?  running,TResult? Function( FolderSaveTarget target,  FolderSaveRun run,  bool cancelled)?  finished,}) {final _that = this;
switch (_that) {
case FolderSaveIdle() when idle != null:
return idle();case FolderSavePlanning() when planning != null:
return planning(_that.target);case FolderSavePlanned() when planned != null:
return planned(_that.target,_that.plan);case FolderSavePlanFailed() when planFailed != null:
return planFailed(_that.target);case FolderSaveAccessDenied() when accessDenied != null:
return accessDenied(_that.target);case FolderSaveRunning() when running != null:
return running(_that.target,_that.run,_that.cancelling);case FolderSaveFinished() when finished != null:
return finished(_that.target,_that.run,_that.cancelled);case _:
  return null;

}
}

}

/// @nodoc


class FolderSaveIdle extends FolderSaveState {
  const FolderSaveIdle(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FolderSaveIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FolderSaveState.idle()';
}


}




/// @nodoc


class FolderSavePlanning extends FolderSaveState {
  const FolderSavePlanning({required this.target}): super._();
  

 final  FolderSaveTarget target;

/// Create a copy of FolderSaveState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FolderSavePlanningCopyWith<FolderSavePlanning> get copyWith => _$FolderSavePlanningCopyWithImpl<FolderSavePlanning>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FolderSavePlanning&&(identical(other.target, target) || other.target == target));
}


@override
int get hashCode => Object.hash(runtimeType,target);

@override
String toString() {
  return 'FolderSaveState.planning(target: $target)';
}


}

/// @nodoc
abstract mixin class $FolderSavePlanningCopyWith<$Res> implements $FolderSaveStateCopyWith<$Res> {
  factory $FolderSavePlanningCopyWith(FolderSavePlanning value, $Res Function(FolderSavePlanning) _then) = _$FolderSavePlanningCopyWithImpl;
@useResult
$Res call({
 FolderSaveTarget target
});




}
/// @nodoc
class _$FolderSavePlanningCopyWithImpl<$Res>
    implements $FolderSavePlanningCopyWith<$Res> {
  _$FolderSavePlanningCopyWithImpl(this._self, this._then);

  final FolderSavePlanning _self;
  final $Res Function(FolderSavePlanning) _then;

/// Create a copy of FolderSaveState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? target = null,}) {
  return _then(FolderSavePlanning(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as FolderSaveTarget,
  ));
}


}

/// @nodoc


class FolderSavePlanned extends FolderSaveState {
  const FolderSavePlanned({required this.target, required this.plan}): super._();
  

 final  FolderSaveTarget target;
 final  FolderSavePlan plan;

/// Create a copy of FolderSaveState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FolderSavePlannedCopyWith<FolderSavePlanned> get copyWith => _$FolderSavePlannedCopyWithImpl<FolderSavePlanned>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FolderSavePlanned&&(identical(other.target, target) || other.target == target)&&(identical(other.plan, plan) || other.plan == plan));
}


@override
int get hashCode => Object.hash(runtimeType,target,plan);

@override
String toString() {
  return 'FolderSaveState.planned(target: $target, plan: $plan)';
}


}

/// @nodoc
abstract mixin class $FolderSavePlannedCopyWith<$Res> implements $FolderSaveStateCopyWith<$Res> {
  factory $FolderSavePlannedCopyWith(FolderSavePlanned value, $Res Function(FolderSavePlanned) _then) = _$FolderSavePlannedCopyWithImpl;
@useResult
$Res call({
 FolderSaveTarget target, FolderSavePlan plan
});




}
/// @nodoc
class _$FolderSavePlannedCopyWithImpl<$Res>
    implements $FolderSavePlannedCopyWith<$Res> {
  _$FolderSavePlannedCopyWithImpl(this._self, this._then);

  final FolderSavePlanned _self;
  final $Res Function(FolderSavePlanned) _then;

/// Create a copy of FolderSaveState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? target = null,Object? plan = null,}) {
  return _then(FolderSavePlanned(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as FolderSaveTarget,plan: null == plan ? _self.plan : plan // ignore: cast_nullable_to_non_nullable
as FolderSavePlan,
  ));
}


}

/// @nodoc


class FolderSavePlanFailed extends FolderSaveState {
  const FolderSavePlanFailed({required this.target}): super._();
  

 final  FolderSaveTarget target;

/// Create a copy of FolderSaveState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FolderSavePlanFailedCopyWith<FolderSavePlanFailed> get copyWith => _$FolderSavePlanFailedCopyWithImpl<FolderSavePlanFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FolderSavePlanFailed&&(identical(other.target, target) || other.target == target));
}


@override
int get hashCode => Object.hash(runtimeType,target);

@override
String toString() {
  return 'FolderSaveState.planFailed(target: $target)';
}


}

/// @nodoc
abstract mixin class $FolderSavePlanFailedCopyWith<$Res> implements $FolderSaveStateCopyWith<$Res> {
  factory $FolderSavePlanFailedCopyWith(FolderSavePlanFailed value, $Res Function(FolderSavePlanFailed) _then) = _$FolderSavePlanFailedCopyWithImpl;
@useResult
$Res call({
 FolderSaveTarget target
});




}
/// @nodoc
class _$FolderSavePlanFailedCopyWithImpl<$Res>
    implements $FolderSavePlanFailedCopyWith<$Res> {
  _$FolderSavePlanFailedCopyWithImpl(this._self, this._then);

  final FolderSavePlanFailed _self;
  final $Res Function(FolderSavePlanFailed) _then;

/// Create a copy of FolderSaveState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? target = null,}) {
  return _then(FolderSavePlanFailed(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as FolderSaveTarget,
  ));
}


}

/// @nodoc


class FolderSaveAccessDenied extends FolderSaveState {
  const FolderSaveAccessDenied({required this.target}): super._();
  

 final  FolderSaveTarget target;

/// Create a copy of FolderSaveState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FolderSaveAccessDeniedCopyWith<FolderSaveAccessDenied> get copyWith => _$FolderSaveAccessDeniedCopyWithImpl<FolderSaveAccessDenied>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FolderSaveAccessDenied&&(identical(other.target, target) || other.target == target));
}


@override
int get hashCode => Object.hash(runtimeType,target);

@override
String toString() {
  return 'FolderSaveState.accessDenied(target: $target)';
}


}

/// @nodoc
abstract mixin class $FolderSaveAccessDeniedCopyWith<$Res> implements $FolderSaveStateCopyWith<$Res> {
  factory $FolderSaveAccessDeniedCopyWith(FolderSaveAccessDenied value, $Res Function(FolderSaveAccessDenied) _then) = _$FolderSaveAccessDeniedCopyWithImpl;
@useResult
$Res call({
 FolderSaveTarget target
});




}
/// @nodoc
class _$FolderSaveAccessDeniedCopyWithImpl<$Res>
    implements $FolderSaveAccessDeniedCopyWith<$Res> {
  _$FolderSaveAccessDeniedCopyWithImpl(this._self, this._then);

  final FolderSaveAccessDenied _self;
  final $Res Function(FolderSaveAccessDenied) _then;

/// Create a copy of FolderSaveState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? target = null,}) {
  return _then(FolderSaveAccessDenied(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as FolderSaveTarget,
  ));
}


}

/// @nodoc


class FolderSaveRunning extends FolderSaveState {
  const FolderSaveRunning({required this.target, required this.run, this.cancelling = false}): super._();
  

 final  FolderSaveTarget target;
 final  FolderSaveRun run;
@JsonKey() final  bool cancelling;

/// Create a copy of FolderSaveState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FolderSaveRunningCopyWith<FolderSaveRunning> get copyWith => _$FolderSaveRunningCopyWithImpl<FolderSaveRunning>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FolderSaveRunning&&(identical(other.target, target) || other.target == target)&&(identical(other.run, run) || other.run == run)&&(identical(other.cancelling, cancelling) || other.cancelling == cancelling));
}


@override
int get hashCode => Object.hash(runtimeType,target,run,cancelling);

@override
String toString() {
  return 'FolderSaveState.running(target: $target, run: $run, cancelling: $cancelling)';
}


}

/// @nodoc
abstract mixin class $FolderSaveRunningCopyWith<$Res> implements $FolderSaveStateCopyWith<$Res> {
  factory $FolderSaveRunningCopyWith(FolderSaveRunning value, $Res Function(FolderSaveRunning) _then) = _$FolderSaveRunningCopyWithImpl;
@useResult
$Res call({
 FolderSaveTarget target, FolderSaveRun run, bool cancelling
});




}
/// @nodoc
class _$FolderSaveRunningCopyWithImpl<$Res>
    implements $FolderSaveRunningCopyWith<$Res> {
  _$FolderSaveRunningCopyWithImpl(this._self, this._then);

  final FolderSaveRunning _self;
  final $Res Function(FolderSaveRunning) _then;

/// Create a copy of FolderSaveState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? target = null,Object? run = null,Object? cancelling = null,}) {
  return _then(FolderSaveRunning(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as FolderSaveTarget,run: null == run ? _self.run : run // ignore: cast_nullable_to_non_nullable
as FolderSaveRun,cancelling: null == cancelling ? _self.cancelling : cancelling // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class FolderSaveFinished extends FolderSaveState {
  const FolderSaveFinished({required this.target, required this.run, this.cancelled = false}): super._();
  

 final  FolderSaveTarget target;
 final  FolderSaveRun run;
@JsonKey() final  bool cancelled;

/// Create a copy of FolderSaveState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FolderSaveFinishedCopyWith<FolderSaveFinished> get copyWith => _$FolderSaveFinishedCopyWithImpl<FolderSaveFinished>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FolderSaveFinished&&(identical(other.target, target) || other.target == target)&&(identical(other.run, run) || other.run == run)&&(identical(other.cancelled, cancelled) || other.cancelled == cancelled));
}


@override
int get hashCode => Object.hash(runtimeType,target,run,cancelled);

@override
String toString() {
  return 'FolderSaveState.finished(target: $target, run: $run, cancelled: $cancelled)';
}


}

/// @nodoc
abstract mixin class $FolderSaveFinishedCopyWith<$Res> implements $FolderSaveStateCopyWith<$Res> {
  factory $FolderSaveFinishedCopyWith(FolderSaveFinished value, $Res Function(FolderSaveFinished) _then) = _$FolderSaveFinishedCopyWithImpl;
@useResult
$Res call({
 FolderSaveTarget target, FolderSaveRun run, bool cancelled
});




}
/// @nodoc
class _$FolderSaveFinishedCopyWithImpl<$Res>
    implements $FolderSaveFinishedCopyWith<$Res> {
  _$FolderSaveFinishedCopyWithImpl(this._self, this._then);

  final FolderSaveFinished _self;
  final $Res Function(FolderSaveFinished) _then;

/// Create a copy of FolderSaveState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? target = null,Object? run = null,Object? cancelled = null,}) {
  return _then(FolderSaveFinished(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as FolderSaveTarget,run: null == run ? _self.run : run // ignore: cast_nullable_to_non_nullable
as FolderSaveRun,cancelled: null == cancelled ? _self.cancelled : cancelled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
