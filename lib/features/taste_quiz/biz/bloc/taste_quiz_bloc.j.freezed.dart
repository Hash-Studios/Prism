// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'taste_quiz_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TasteQuizEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TasteQuizEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TasteQuizEvent()';
}


}

/// @nodoc
class $TasteQuizEventCopyWith<$Res>  {
$TasteQuizEventCopyWith(TasteQuizEvent _, $Res Function(TasteQuizEvent) __);
}


/// Adds pattern-matching-related methods to [TasteQuizEvent].
extension TasteQuizEventPatterns on TasteQuizEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Picked value)?  picked,TResult Function( _Skipped value)?  skipped,TResult Function( _Looked value)?  looked,TResult Function( _TuningShown value)?  tuningShown,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Picked() when picked != null:
return picked(_that);case _Skipped() when skipped != null:
return skipped(_that);case _Looked() when looked != null:
return looked(_that);case _TuningShown() when tuningShown != null:
return tuningShown(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Picked value)  picked,required TResult Function( _Skipped value)  skipped,required TResult Function( _Looked value)  looked,required TResult Function( _TuningShown value)  tuningShown,}){
final _that = this;
switch (_that) {
case _Picked():
return picked(_that);case _Skipped():
return skipped(_that);case _Looked():
return looked(_that);case _TuningShown():
return tuningShown(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Picked value)?  picked,TResult? Function( _Skipped value)?  skipped,TResult? Function( _Looked value)?  looked,TResult? Function( _TuningShown value)?  tuningShown,}){
final _that = this;
switch (_that) {
case _Picked() when picked != null:
return picked(_that);case _Skipped() when skipped != null:
return skipped(_that);case _Looked() when looked != null:
return looked(_that);case _TuningShown() when tuningShown != null:
return tuningShown(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int round,  QuizSide side)?  picked,TResult Function()?  skipped,TResult Function( String key,  WallLook look)?  looked,TResult Function()?  tuningShown,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Picked() when picked != null:
return picked(_that.round,_that.side);case _Skipped() when skipped != null:
return skipped();case _Looked() when looked != null:
return looked(_that.key,_that.look);case _TuningShown() when tuningShown != null:
return tuningShown();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int round,  QuizSide side)  picked,required TResult Function()  skipped,required TResult Function( String key,  WallLook look)  looked,required TResult Function()  tuningShown,}) {final _that = this;
switch (_that) {
case _Picked():
return picked(_that.round,_that.side);case _Skipped():
return skipped();case _Looked():
return looked(_that.key,_that.look);case _TuningShown():
return tuningShown();case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int round,  QuizSide side)?  picked,TResult? Function()?  skipped,TResult? Function( String key,  WallLook look)?  looked,TResult? Function()?  tuningShown,}) {final _that = this;
switch (_that) {
case _Picked() when picked != null:
return picked(_that.round,_that.side);case _Skipped() when skipped != null:
return skipped();case _Looked() when looked != null:
return looked(_that.key,_that.look);case _TuningShown() when tuningShown != null:
return tuningShown();case _:
  return null;

}
}

}

/// @nodoc


class _Picked implements TasteQuizEvent {
  const _Picked({required this.round, required this.side});
  

 final  int round;
 final  QuizSide side;

/// Create a copy of TasteQuizEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PickedCopyWith<_Picked> get copyWith => __$PickedCopyWithImpl<_Picked>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Picked&&(identical(other.round, round) || other.round == round)&&(identical(other.side, side) || other.side == side));
}


@override
int get hashCode => Object.hash(runtimeType,round,side);

@override
String toString() {
  return 'TasteQuizEvent.picked(round: $round, side: $side)';
}


}

/// @nodoc
abstract mixin class _$PickedCopyWith<$Res> implements $TasteQuizEventCopyWith<$Res> {
  factory _$PickedCopyWith(_Picked value, $Res Function(_Picked) _then) = __$PickedCopyWithImpl;
@useResult
$Res call({
 int round, QuizSide side
});




}
/// @nodoc
class __$PickedCopyWithImpl<$Res>
    implements _$PickedCopyWith<$Res> {
  __$PickedCopyWithImpl(this._self, this._then);

  final _Picked _self;
  final $Res Function(_Picked) _then;

/// Create a copy of TasteQuizEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? round = null,Object? side = null,}) {
  return _then(_Picked(
round: null == round ? _self.round : round // ignore: cast_nullable_to_non_nullable
as int,side: null == side ? _self.side : side // ignore: cast_nullable_to_non_nullable
as QuizSide,
  ));
}


}

/// @nodoc


class _Skipped implements TasteQuizEvent {
  const _Skipped();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Skipped);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TasteQuizEvent.skipped()';
}


}




/// @nodoc


class _Looked implements TasteQuizEvent {
  const _Looked({required this.key, required this.look});
  

 final  String key;
 final  WallLook look;

/// Create a copy of TasteQuizEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LookedCopyWith<_Looked> get copyWith => __$LookedCopyWithImpl<_Looked>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Looked&&(identical(other.key, key) || other.key == key)&&(identical(other.look, look) || other.look == look));
}


@override
int get hashCode => Object.hash(runtimeType,key,look);

@override
String toString() {
  return 'TasteQuizEvent.looked(key: $key, look: $look)';
}


}

/// @nodoc
abstract mixin class _$LookedCopyWith<$Res> implements $TasteQuizEventCopyWith<$Res> {
  factory _$LookedCopyWith(_Looked value, $Res Function(_Looked) _then) = __$LookedCopyWithImpl;
@useResult
$Res call({
 String key, WallLook look
});




}
/// @nodoc
class __$LookedCopyWithImpl<$Res>
    implements _$LookedCopyWith<$Res> {
  __$LookedCopyWithImpl(this._self, this._then);

  final _Looked _self;
  final $Res Function(_Looked) _then;

/// Create a copy of TasteQuizEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? key = null,Object? look = null,}) {
  return _then(_Looked(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,look: null == look ? _self.look : look // ignore: cast_nullable_to_non_nullable
as WallLook,
  ));
}


}

/// @nodoc


class _TuningShown implements TasteQuizEvent {
  const _TuningShown();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TuningShown);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TasteQuizEvent.tuningShown()';
}


}




/// @nodoc
mixin _$TasteQuizState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TasteQuizState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TasteQuizState()';
}


}

/// @nodoc
class $TasteQuizStateCopyWith<$Res>  {
$TasteQuizStateCopyWith(TasteQuizState _, $Res Function(TasteQuizState) __);
}


/// Adds pattern-matching-related methods to [TasteQuizState].
extension TasteQuizStatePatterns on TasteQuizState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TasteQuizPlaying value)?  playing,TResult Function( TasteQuizTuning value)?  tuning,TResult Function( TasteQuizFinished value)?  finished,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TasteQuizPlaying() when playing != null:
return playing(_that);case TasteQuizTuning() when tuning != null:
return tuning(_that);case TasteQuizFinished() when finished != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TasteQuizPlaying value)  playing,required TResult Function( TasteQuizTuning value)  tuning,required TResult Function( TasteQuizFinished value)  finished,}){
final _that = this;
switch (_that) {
case TasteQuizPlaying():
return playing(_that);case TasteQuizTuning():
return tuning(_that);case TasteQuizFinished():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TasteQuizPlaying value)?  playing,TResult? Function( TasteQuizTuning value)?  tuning,TResult? Function( TasteQuizFinished value)?  finished,}){
final _that = this;
switch (_that) {
case TasteQuizPlaying() when playing != null:
return playing(_that);case TasteQuizTuning() when tuning != null:
return tuning(_that);case TasteQuizFinished() when finished != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( TasteQuizPlan plan,  List<QuizPick> picks)?  playing,TResult Function( TasteSummary summary,  List<FeedItemEntity>? walls)?  tuning,TResult Function( bool completed)?  finished,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TasteQuizPlaying() when playing != null:
return playing(_that.plan,_that.picks);case TasteQuizTuning() when tuning != null:
return tuning(_that.summary,_that.walls);case TasteQuizFinished() when finished != null:
return finished(_that.completed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( TasteQuizPlan plan,  List<QuizPick> picks)  playing,required TResult Function( TasteSummary summary,  List<FeedItemEntity>? walls)  tuning,required TResult Function( bool completed)  finished,}) {final _that = this;
switch (_that) {
case TasteQuizPlaying():
return playing(_that.plan,_that.picks);case TasteQuizTuning():
return tuning(_that.summary,_that.walls);case TasteQuizFinished():
return finished(_that.completed);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( TasteQuizPlan plan,  List<QuizPick> picks)?  playing,TResult? Function( TasteSummary summary,  List<FeedItemEntity>? walls)?  tuning,TResult? Function( bool completed)?  finished,}) {final _that = this;
switch (_that) {
case TasteQuizPlaying() when playing != null:
return playing(_that.plan,_that.picks);case TasteQuizTuning() when tuning != null:
return tuning(_that.summary,_that.walls);case TasteQuizFinished() when finished != null:
return finished(_that.completed);case _:
  return null;

}
}

}

/// @nodoc


class TasteQuizPlaying implements TasteQuizState {
  const TasteQuizPlaying({required this.plan, required final  List<QuizPick> picks}): _picks = picks;
  

 final  TasteQuizPlan plan;
 final  List<QuizPick> _picks;
 List<QuizPick> get picks {
  if (_picks is EqualUnmodifiableListView) return _picks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_picks);
}


/// Create a copy of TasteQuizState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TasteQuizPlayingCopyWith<TasteQuizPlaying> get copyWith => _$TasteQuizPlayingCopyWithImpl<TasteQuizPlaying>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TasteQuizPlaying&&(identical(other.plan, plan) || other.plan == plan)&&const DeepCollectionEquality().equals(other._picks, _picks));
}


@override
int get hashCode => Object.hash(runtimeType,plan,const DeepCollectionEquality().hash(_picks));

@override
String toString() {
  return 'TasteQuizState.playing(plan: $plan, picks: $picks)';
}


}

/// @nodoc
abstract mixin class $TasteQuizPlayingCopyWith<$Res> implements $TasteQuizStateCopyWith<$Res> {
  factory $TasteQuizPlayingCopyWith(TasteQuizPlaying value, $Res Function(TasteQuizPlaying) _then) = _$TasteQuizPlayingCopyWithImpl;
@useResult
$Res call({
 TasteQuizPlan plan, List<QuizPick> picks
});




}
/// @nodoc
class _$TasteQuizPlayingCopyWithImpl<$Res>
    implements $TasteQuizPlayingCopyWith<$Res> {
  _$TasteQuizPlayingCopyWithImpl(this._self, this._then);

  final TasteQuizPlaying _self;
  final $Res Function(TasteQuizPlaying) _then;

/// Create a copy of TasteQuizState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? plan = null,Object? picks = null,}) {
  return _then(TasteQuizPlaying(
plan: null == plan ? _self.plan : plan // ignore: cast_nullable_to_non_nullable
as TasteQuizPlan,picks: null == picks ? _self._picks : picks // ignore: cast_nullable_to_non_nullable
as List<QuizPick>,
  ));
}


}

/// @nodoc


class TasteQuizTuning implements TasteQuizState {
  const TasteQuizTuning({required this.summary, final  List<FeedItemEntity>? walls}): _walls = walls;
  

 final  TasteSummary summary;
 final  List<FeedItemEntity>? _walls;
 List<FeedItemEntity>? get walls {
  final value = _walls;
  if (value == null) return null;
  if (_walls is EqualUnmodifiableListView) return _walls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of TasteQuizState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TasteQuizTuningCopyWith<TasteQuizTuning> get copyWith => _$TasteQuizTuningCopyWithImpl<TasteQuizTuning>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TasteQuizTuning&&(identical(other.summary, summary) || other.summary == summary)&&const DeepCollectionEquality().equals(other._walls, _walls));
}


@override
int get hashCode => Object.hash(runtimeType,summary,const DeepCollectionEquality().hash(_walls));

@override
String toString() {
  return 'TasteQuizState.tuning(summary: $summary, walls: $walls)';
}


}

/// @nodoc
abstract mixin class $TasteQuizTuningCopyWith<$Res> implements $TasteQuizStateCopyWith<$Res> {
  factory $TasteQuizTuningCopyWith(TasteQuizTuning value, $Res Function(TasteQuizTuning) _then) = _$TasteQuizTuningCopyWithImpl;
@useResult
$Res call({
 TasteSummary summary, List<FeedItemEntity>? walls
});




}
/// @nodoc
class _$TasteQuizTuningCopyWithImpl<$Res>
    implements $TasteQuizTuningCopyWith<$Res> {
  _$TasteQuizTuningCopyWithImpl(this._self, this._then);

  final TasteQuizTuning _self;
  final $Res Function(TasteQuizTuning) _then;

/// Create a copy of TasteQuizState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? summary = null,Object? walls = freezed,}) {
  return _then(TasteQuizTuning(
summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as TasteSummary,walls: freezed == walls ? _self._walls : walls // ignore: cast_nullable_to_non_nullable
as List<FeedItemEntity>?,
  ));
}


}

/// @nodoc


class TasteQuizFinished implements TasteQuizState {
  const TasteQuizFinished({required this.completed});
  

 final  bool completed;

/// Create a copy of TasteQuizState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TasteQuizFinishedCopyWith<TasteQuizFinished> get copyWith => _$TasteQuizFinishedCopyWithImpl<TasteQuizFinished>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TasteQuizFinished&&(identical(other.completed, completed) || other.completed == completed));
}


@override
int get hashCode => Object.hash(runtimeType,completed);

@override
String toString() {
  return 'TasteQuizState.finished(completed: $completed)';
}


}

/// @nodoc
abstract mixin class $TasteQuizFinishedCopyWith<$Res> implements $TasteQuizStateCopyWith<$Res> {
  factory $TasteQuizFinishedCopyWith(TasteQuizFinished value, $Res Function(TasteQuizFinished) _then) = _$TasteQuizFinishedCopyWithImpl;
@useResult
$Res call({
 bool completed
});




}
/// @nodoc
class _$TasteQuizFinishedCopyWithImpl<$Res>
    implements $TasteQuizFinishedCopyWith<$Res> {
  _$TasteQuizFinishedCopyWithImpl(this._self, this._then);

  final TasteQuizFinished _self;
  final $Res Function(TasteQuizFinished) _then;

/// Create a copy of TasteQuizState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? completed = null,}) {
  return _then(TasteQuizFinished(
completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
