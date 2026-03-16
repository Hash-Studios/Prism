// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auto_rotate_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AutoRotateEvent {




@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutoRotateEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AutoRotateEvent()';
}


}

/// @nodoc
class $AutoRotateEventCopyWith<$Res>  {
$AutoRotateEventCopyWith(AutoRotateEvent _, $Res Function(AutoRotateEvent) __);
}


/// Adds pattern-matching-related methods to [AutoRotateEvent].
extension AutoRotateEventPatterns on AutoRotateEvent {
@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _SourceTypeChanged value)?  sourceTypeChanged,TResult Function( _TargetChanged value)?  targetChanged,TResult Function( _IntervalChanged value)?  intervalChanged,TResult Function( _ChargingTriggerToggled value)?  chargingTriggerToggled,TResult Function( _OrderChanged value)?  orderChanged,TResult Function( _StartRequested value)?  startRequested,TResult Function( _StopRequested value)?  stopRequested,TResult Function( _StatusRefreshRequested value)?  statusRefreshRequested,TResult Function( _RotateNowRequested value)?  rotateNowRequested,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _SourceTypeChanged() when sourceTypeChanged != null:
return sourceTypeChanged(_that);case _TargetChanged() when targetChanged != null:
return targetChanged(_that);case _IntervalChanged() when intervalChanged != null:
return intervalChanged(_that);case _ChargingTriggerToggled() when chargingTriggerToggled != null:
return chargingTriggerToggled(_that);case _OrderChanged() when orderChanged != null:
return orderChanged(_that);case _StartRequested() when startRequested != null:
return startRequested(_that);case _StopRequested() when stopRequested != null:
return stopRequested(_that);case _StatusRefreshRequested() when statusRefreshRequested != null:
return statusRefreshRequested(_that);case _RotateNowRequested() when rotateNowRequested != null:
return rotateNowRequested(_that);case _:
  return orElse();

}
}

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _SourceTypeChanged value)  sourceTypeChanged,required TResult Function( _TargetChanged value)  targetChanged,required TResult Function( _IntervalChanged value)  intervalChanged,required TResult Function( _ChargingTriggerToggled value)  chargingTriggerToggled,required TResult Function( _OrderChanged value)  orderChanged,required TResult Function( _StartRequested value)  startRequested,required TResult Function( _StopRequested value)  stopRequested,required TResult Function( _StatusRefreshRequested value)  statusRefreshRequested,required TResult Function( _RotateNowRequested value)  rotateNowRequested,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _SourceTypeChanged():
return sourceTypeChanged(_that);case _TargetChanged():
return targetChanged(_that);case _IntervalChanged():
return intervalChanged(_that);case _ChargingTriggerToggled():
return chargingTriggerToggled(_that);case _OrderChanged():
return orderChanged(_that);case _StartRequested():
return startRequested(_that);case _StopRequested():
return stopRequested(_that);case _StatusRefreshRequested():
return statusRefreshRequested(_that);case _RotateNowRequested():
return rotateNowRequested(_that);case _:
  throw StateError('Unexpected subclass');

}
}

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _SourceTypeChanged value)?  sourceTypeChanged,TResult? Function( _TargetChanged value)?  targetChanged,TResult? Function( _IntervalChanged value)?  intervalChanged,TResult? Function( _ChargingTriggerToggled value)?  chargingTriggerToggled,TResult? Function( _OrderChanged value)?  orderChanged,TResult? Function( _StartRequested value)?  startRequested,TResult? Function( _StopRequested value)?  stopRequested,TResult? Function( _StatusRefreshRequested value)?  statusRefreshRequested,TResult? Function( _RotateNowRequested value)?  rotateNowRequested,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _SourceTypeChanged() when sourceTypeChanged != null:
return sourceTypeChanged(_that);case _TargetChanged() when targetChanged != null:
return targetChanged(_that);case _IntervalChanged() when intervalChanged != null:
return intervalChanged(_that);case _ChargingTriggerToggled() when chargingTriggerToggled != null:
return chargingTriggerToggled(_that);case _OrderChanged() when orderChanged != null:
return orderChanged(_that);case _StartRequested() when startRequested != null:
return startRequested(_that);case _StopRequested() when stopRequested != null:
return stopRequested(_that);case _StatusRefreshRequested() when statusRefreshRequested != null:
return statusRefreshRequested(_that);case _RotateNowRequested() when rotateNowRequested != null:
return rotateNowRequested(_that);case _:
  return null;

}
}

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  started,TResult Function( AutoRotateSourceType sourceType,  String? name)?  sourceTypeChanged,TResult Function( aw.WallpaperTarget target)?  targetChanged,TResult Function( int minutes)?  intervalChanged,TResult Function()?  chargingTriggerToggled,TResult Function( AutoRotateOrder order)?  orderChanged,TResult Function()?  startRequested,TResult Function()?  stopRequested,TResult Function()?  statusRefreshRequested,TResult Function()?  rotateNowRequested,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _SourceTypeChanged() when sourceTypeChanged != null:
return sourceTypeChanged(_that.sourceType,_that.name);case _TargetChanged() when targetChanged != null:
return targetChanged(_that.target);case _IntervalChanged() when intervalChanged != null:
return intervalChanged(_that.minutes);case _ChargingTriggerToggled() when chargingTriggerToggled != null:
return chargingTriggerToggled();case _OrderChanged() when orderChanged != null:
return orderChanged(_that.order);case _StartRequested() when startRequested != null:
return startRequested();case _StopRequested() when stopRequested != null:
return stopRequested();case _StatusRefreshRequested() when statusRefreshRequested != null:
return statusRefreshRequested();case _RotateNowRequested() when rotateNowRequested != null:
return rotateNowRequested();case _:
  return orElse();

}
}

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  started,required TResult Function( AutoRotateSourceType sourceType,  String? name)  sourceTypeChanged,required TResult Function( aw.WallpaperTarget target)  targetChanged,required TResult Function( int minutes)  intervalChanged,required TResult Function()  chargingTriggerToggled,required TResult Function( AutoRotateOrder order)  orderChanged,required TResult Function()  startRequested,required TResult Function()  stopRequested,required TResult Function()  statusRefreshRequested,required TResult Function()  rotateNowRequested,}) {final _that = this;
switch (_that) {
case _Started():
return started();case _SourceTypeChanged():
return sourceTypeChanged(_that.sourceType,_that.name);case _TargetChanged():
return targetChanged(_that.target);case _IntervalChanged():
return intervalChanged(_that.minutes);case _ChargingTriggerToggled():
return chargingTriggerToggled();case _OrderChanged():
return orderChanged(_that.order);case _StartRequested():
return startRequested();case _StopRequested():
return stopRequested();case _StatusRefreshRequested():
return statusRefreshRequested();case _RotateNowRequested():
return rotateNowRequested();case _:
  throw StateError('Unexpected subclass');

}
}

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  started,TResult? Function( AutoRotateSourceType sourceType,  String? name)?  sourceTypeChanged,TResult? Function( aw.WallpaperTarget target)?  targetChanged,TResult? Function( int minutes)?  intervalChanged,TResult? Function()?  chargingTriggerToggled,TResult? Function( AutoRotateOrder order)?  orderChanged,TResult? Function()?  startRequested,TResult? Function()?  stopRequested,TResult? Function()?  statusRefreshRequested,TResult? Function()?  rotateNowRequested,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _SourceTypeChanged() when sourceTypeChanged != null:
return sourceTypeChanged(_that.sourceType,_that.name);case _TargetChanged() when targetChanged != null:
return targetChanged(_that.target);case _IntervalChanged() when intervalChanged != null:
return intervalChanged(_that.minutes);case _ChargingTriggerToggled() when chargingTriggerToggled != null:
return chargingTriggerToggled();case _OrderChanged() when orderChanged != null:
return orderChanged(_that.order);case _StartRequested() when startRequested != null:
return startRequested();case _StopRequested() when stopRequested != null:
return stopRequested();case _StatusRefreshRequested() when statusRefreshRequested != null:
return statusRefreshRequested();case _RotateNowRequested() when rotateNowRequested != null:
return rotateNowRequested();case _:
  return null;

}
}

}

/// @nodoc


class _Started implements AutoRotateEvent {
  const _Started();




@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AutoRotateEvent.started()';
}


}




/// @nodoc


class _SourceTypeChanged implements AutoRotateEvent {
  const _SourceTypeChanged({required this.sourceType, this.name});


@override final  AutoRotateSourceType sourceType;
@override final  String? name;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SourceTypeChanged&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,sourceType,name);

@override
String toString() {
  return 'AutoRotateEvent.sourceTypeChanged(sourceType: $sourceType, name: $name)';
}


}




/// @nodoc


class _TargetChanged implements AutoRotateEvent {
  const _TargetChanged({required this.target});


@override final  aw.WallpaperTarget target;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TargetChanged&&(identical(other.target, target) || other.target == target));
}


@override
int get hashCode => Object.hash(runtimeType,target);

@override
String toString() {
  return 'AutoRotateEvent.targetChanged(target: $target)';
}


}




/// @nodoc


class _IntervalChanged implements AutoRotateEvent {
  const _IntervalChanged({required this.minutes});


@override final  int minutes;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _IntervalChanged&&(identical(other.minutes, minutes) || other.minutes == minutes));
}


@override
int get hashCode => Object.hash(runtimeType,minutes);

@override
String toString() {
  return 'AutoRotateEvent.intervalChanged(minutes: $minutes)';
}


}




/// @nodoc


class _ChargingTriggerToggled implements AutoRotateEvent {
  const _ChargingTriggerToggled();




@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChargingTriggerToggled);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AutoRotateEvent.chargingTriggerToggled()';
}


}




/// @nodoc


class _OrderChanged implements AutoRotateEvent {
  const _OrderChanged({required this.order});


@override final  AutoRotateOrder order;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrderChanged&&(identical(other.order, order) || other.order == order));
}


@override
int get hashCode => Object.hash(runtimeType,order);

@override
String toString() {
  return 'AutoRotateEvent.orderChanged(order: $order)';
}


}




/// @nodoc


class _StartRequested implements AutoRotateEvent {
  const _StartRequested();




@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StartRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AutoRotateEvent.startRequested()';
}


}




/// @nodoc


class _StopRequested implements AutoRotateEvent {
  const _StopRequested();




@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StopRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AutoRotateEvent.stopRequested()';
}


}




/// @nodoc


class _StatusRefreshRequested implements AutoRotateEvent {
  const _StatusRefreshRequested();




@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StatusRefreshRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AutoRotateEvent.statusRefreshRequested()';
}


}




/// @nodoc


class _RotateNowRequested implements AutoRotateEvent {
  const _RotateNowRequested();




@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RotateNowRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AutoRotateEvent.rotateNowRequested()';
}


}




/// @nodoc
mixin _$AutoRotateState {

 AutoRotateConfigEntity get config; bool get isRunning; LoadStatus get status; ActionStatus get actionStatus; List<String> get availableCollections; List<CategoryDefinition> get availableCategories; Failure? get failure;
/// Create a copy of AutoRotateState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AutoRotateStateCopyWith<AutoRotateState> get copyWith => _$AutoRotateStateCopyWithImpl<AutoRotateState>(this as AutoRotateState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutoRotateState&&(identical(other.config, config) || other.config == config)&&(identical(other.isRunning, isRunning) || other.isRunning == isRunning)&&(identical(other.status, status) || other.status == status)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&const DeepCollectionEquality().equals(other.availableCollections, availableCollections)&&const DeepCollectionEquality().equals(other.availableCategories, availableCategories)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,config,isRunning,status,actionStatus,const DeepCollectionEquality().hash(availableCollections),const DeepCollectionEquality().hash(availableCategories),failure);

@override
String toString() {
  return 'AutoRotateState(config: $config, isRunning: $isRunning, status: $status, actionStatus: $actionStatus, availableCollections: $availableCollections, availableCategories: $availableCategories, failure: $failure)';
}


}

/// @nodoc
abstract mixin class $AutoRotateStateCopyWith<$Res>  {
  factory $AutoRotateStateCopyWith(AutoRotateState value, $Res Function(AutoRotateState) _then) = _$AutoRotateStateCopyWithImpl;
@useResult
$Res call({
 AutoRotateConfigEntity config, bool isRunning, LoadStatus status, ActionStatus actionStatus, List<String> availableCollections, List<CategoryDefinition> availableCategories, Failure? failure
});




}
/// @nodoc
class _$AutoRotateStateCopyWithImpl<$Res>
    implements $AutoRotateStateCopyWith<$Res> {
  _$AutoRotateStateCopyWithImpl(this._self, this._then);

  final AutoRotateState _self;
  final $Res Function(AutoRotateState) _then;

/// Create a copy of AutoRotateState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? config = null,Object? isRunning = null,Object? status = null,Object? actionStatus = null,Object? availableCollections = null,Object? availableCategories = null,Object? failure = freezed,}) {
  return _then(_self.copyWith(
config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as AutoRotateConfigEntity,isRunning: null == isRunning ? _self.isRunning : isRunning // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,actionStatus: null == actionStatus ? _self.actionStatus : actionStatus // ignore: cast_nullable_to_non_nullable
as ActionStatus,availableCollections: null == availableCollections ? _self.availableCollections : availableCollections // ignore: cast_nullable_to_non_nullable
as List<String>,availableCategories: null == availableCategories ? _self.availableCategories : availableCategories // ignore: cast_nullable_to_non_nullable
as List<CategoryDefinition>,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}

}


/// Adds pattern-matching-related methods to [AutoRotateState].
extension AutoRotateStatePatterns on AutoRotateState {
@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AutoRotateState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AutoRotateState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AutoRotateState value)  $default,){
final _that = this;
switch (_that) {
case _AutoRotateState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AutoRotateState value)?  $default,){
final _that = this;
switch (_that) {
case _AutoRotateState() when $default != null:
return $default(_that);case _:
  return null;

}
}

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AutoRotateConfigEntity config,  bool isRunning,  LoadStatus status,  ActionStatus actionStatus,  List<String> availableCollections,  List<CategoryDefinition> availableCategories,  Failure? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AutoRotateState() when $default != null:
return $default(_that.config,_that.isRunning,_that.status,_that.actionStatus,_that.availableCollections,_that.availableCategories,_that.failure);case _:
  return orElse();

}
}

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AutoRotateConfigEntity config,  bool isRunning,  LoadStatus status,  ActionStatus actionStatus,  List<String> availableCollections,  List<CategoryDefinition> availableCategories,  Failure? failure)  $default,) {final _that = this;
switch (_that) {
case _AutoRotateState():
return $default(_that.config,_that.isRunning,_that.status,_that.actionStatus,_that.availableCollections,_that.availableCategories,_that.failure);case _:
  throw StateError('Unexpected subclass');

}
}

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AutoRotateConfigEntity config,  bool isRunning,  LoadStatus status,  ActionStatus actionStatus,  List<String> availableCollections,  List<CategoryDefinition> availableCategories,  Failure? failure)?  $default,) {final _that = this;
switch (_that) {
case _AutoRotateState() when $default != null:
return $default(_that.config,_that.isRunning,_that.status,_that.actionStatus,_that.availableCollections,_that.availableCategories,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _AutoRotateState implements AutoRotateState {
  const _AutoRotateState({required this.config, required this.isRunning, required this.status, required this.actionStatus, required final List<String> availableCollections, required final List<CategoryDefinition> availableCategories, this.failure}): _availableCollections = availableCollections,_availableCategories = availableCategories;


@override final  AutoRotateConfigEntity config;
@override final  bool isRunning;
@override final  LoadStatus status;
@override final  ActionStatus actionStatus;
 final  List<String> _availableCollections;
@override List<String> get availableCollections {
  if (_availableCollections is EqualUnmodifiableListView) return _availableCollections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableCollections);
}

 final  List<CategoryDefinition> _availableCategories;
@override List<CategoryDefinition> get availableCategories {
  if (_availableCategories is EqualUnmodifiableListView) return _availableCategories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableCategories);
}

@override final  Failure? failure;

/// Create a copy of AutoRotateState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AutoRotateStateCopyWith<_AutoRotateState> get copyWith => __$AutoRotateStateCopyWithImpl<_AutoRotateState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AutoRotateState&&(identical(other.config, config) || other.config == config)&&(identical(other.isRunning, isRunning) || other.isRunning == isRunning)&&(identical(other.status, status) || other.status == status)&&(identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus)&&const DeepCollectionEquality().equals(other._availableCollections, _availableCollections)&&const DeepCollectionEquality().equals(other._availableCategories, _availableCategories)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,config,isRunning,status,actionStatus,const DeepCollectionEquality().hash(_availableCollections),const DeepCollectionEquality().hash(_availableCategories),failure);

@override
String toString() {
  return 'AutoRotateState(config: $config, isRunning: $isRunning, status: $status, actionStatus: $actionStatus, availableCollections: $availableCollections, availableCategories: $availableCategories, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$AutoRotateStateCopyWith<$Res> implements $AutoRotateStateCopyWith<$Res> {
  factory _$AutoRotateStateCopyWith(_AutoRotateState value, $Res Function(_AutoRotateState) _then) = __$AutoRotateStateCopyWithImpl;
@override @useResult
$Res call({
 AutoRotateConfigEntity config, bool isRunning, LoadStatus status, ActionStatus actionStatus, List<String> availableCollections, List<CategoryDefinition> availableCategories, Failure? failure
});




}
/// @nodoc
class __$AutoRotateStateCopyWithImpl<$Res>
    implements _$AutoRotateStateCopyWith<$Res> {
  __$AutoRotateStateCopyWithImpl(this._self, this._then);

  final _AutoRotateState _self;
  final $Res Function(_AutoRotateState) _then;

/// Create a copy of AutoRotateState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? config = null,Object? isRunning = null,Object? status = null,Object? actionStatus = null,Object? availableCollections = null,Object? availableCategories = null,Object? failure = freezed,}) {
  return _then(_AutoRotateState(
config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as AutoRotateConfigEntity,isRunning: null == isRunning ? _self.isRunning : isRunning // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,actionStatus: null == actionStatus ? _self.actionStatus : actionStatus // ignore: cast_nullable_to_non_nullable
as ActionStatus,availableCollections: null == availableCollections ? _self._availableCollections : availableCollections // ignore: cast_nullable_to_non_nullable
as List<String>,availableCategories: null == availableCategories ? _self._availableCategories : availableCategories // ignore: cast_nullable_to_non_nullable
as List<CategoryDefinition>,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}


}

// dart format on
