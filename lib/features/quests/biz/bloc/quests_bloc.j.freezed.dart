// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'quests_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$QuestsEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuestsEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'QuestsEvent()';
}


}

/// @nodoc
class $QuestsEventCopyWith<$Res>  {
$QuestsEventCopyWith(QuestsEvent _, $Res Function(QuestsEvent) __);
}


/// Adds pattern-matching-related methods to [QuestsEvent].
extension QuestsEventPatterns on QuestsEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _Refreshed value)?  refreshed,TResult Function( _ChestOpened value)?  chestOpened,TResult Function( _AwardsShown value)?  awardsShown,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _Refreshed() when refreshed != null:
return refreshed(_that);case _ChestOpened() when chestOpened != null:
return chestOpened(_that);case _AwardsShown() when awardsShown != null:
return awardsShown(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _Refreshed value)  refreshed,required TResult Function( _ChestOpened value)  chestOpened,required TResult Function( _AwardsShown value)  awardsShown,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _Refreshed():
return refreshed(_that);case _ChestOpened():
return chestOpened(_that);case _AwardsShown():
return awardsShown(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _Refreshed value)?  refreshed,TResult? Function( _ChestOpened value)?  chestOpened,TResult? Function( _AwardsShown value)?  awardsShown,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _Refreshed() when refreshed != null:
return refreshed(_that);case _ChestOpened() when chestOpened != null:
return chestOpened(_that);case _AwardsShown() when awardsShown != null:
return awardsShown(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  started,TResult Function()?  refreshed,TResult Function()?  chestOpened,TResult Function()?  awardsShown,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _Refreshed() when refreshed != null:
return refreshed();case _ChestOpened() when chestOpened != null:
return chestOpened();case _AwardsShown() when awardsShown != null:
return awardsShown();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  started,required TResult Function()  refreshed,required TResult Function()  chestOpened,required TResult Function()  awardsShown,}) {final _that = this;
switch (_that) {
case _Started():
return started();case _Refreshed():
return refreshed();case _ChestOpened():
return chestOpened();case _AwardsShown():
return awardsShown();case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  started,TResult? Function()?  refreshed,TResult? Function()?  chestOpened,TResult? Function()?  awardsShown,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _Refreshed() when refreshed != null:
return refreshed();case _ChestOpened() when chestOpened != null:
return chestOpened();case _AwardsShown() when awardsShown != null:
return awardsShown();case _:
  return null;

}
}

}

/// @nodoc


class _Started implements QuestsEvent {
  const _Started();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'QuestsEvent.started()';
}


}




/// @nodoc


class _Refreshed implements QuestsEvent {
  const _Refreshed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Refreshed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'QuestsEvent.refreshed()';
}


}




/// @nodoc


class _ChestOpened implements QuestsEvent {
  const _ChestOpened();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChestOpened);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'QuestsEvent.chestOpened()';
}


}




/// @nodoc


class _AwardsShown implements QuestsEvent {
  const _AwardsShown();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AwardsShown);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'QuestsEvent.awardsShown()';
}


}




/// @nodoc
mixin _$QuestsState {

 QuestState? get quests; List<QuestAward> get awards; bool get opening;/// The last chest result. The view shows the chest sheet when it changes.
 ChestResult? get chest;
/// Create a copy of QuestsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuestsStateCopyWith<QuestsState> get copyWith => _$QuestsStateCopyWithImpl<QuestsState>(this as QuestsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QuestsState&&(identical(other.quests, quests) || other.quests == quests)&&const DeepCollectionEquality().equals(other.awards, awards)&&(identical(other.opening, opening) || other.opening == opening)&&(identical(other.chest, chest) || other.chest == chest));
}


@override
int get hashCode => Object.hash(runtimeType,quests,const DeepCollectionEquality().hash(awards),opening,chest);

@override
String toString() {
  return 'QuestsState(quests: $quests, awards: $awards, opening: $opening, chest: $chest)';
}


}

/// @nodoc
abstract mixin class $QuestsStateCopyWith<$Res>  {
  factory $QuestsStateCopyWith(QuestsState value, $Res Function(QuestsState) _then) = _$QuestsStateCopyWithImpl;
@useResult
$Res call({
 QuestState? quests, List<QuestAward> awards, bool opening, ChestResult? chest
});




}
/// @nodoc
class _$QuestsStateCopyWithImpl<$Res>
    implements $QuestsStateCopyWith<$Res> {
  _$QuestsStateCopyWithImpl(this._self, this._then);

  final QuestsState _self;
  final $Res Function(QuestsState) _then;

/// Create a copy of QuestsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? quests = freezed,Object? awards = null,Object? opening = null,Object? chest = freezed,}) {
  return _then(_self.copyWith(
quests: freezed == quests ? _self.quests : quests // ignore: cast_nullable_to_non_nullable
as QuestState?,awards: null == awards ? _self.awards : awards // ignore: cast_nullable_to_non_nullable
as List<QuestAward>,opening: null == opening ? _self.opening : opening // ignore: cast_nullable_to_non_nullable
as bool,chest: freezed == chest ? _self.chest : chest // ignore: cast_nullable_to_non_nullable
as ChestResult?,
  ));
}

}


/// Adds pattern-matching-related methods to [QuestsState].
extension QuestsStatePatterns on QuestsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QuestsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QuestsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QuestsState value)  $default,){
final _that = this;
switch (_that) {
case _QuestsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QuestsState value)?  $default,){
final _that = this;
switch (_that) {
case _QuestsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( QuestState? quests,  List<QuestAward> awards,  bool opening,  ChestResult? chest)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QuestsState() when $default != null:
return $default(_that.quests,_that.awards,_that.opening,_that.chest);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( QuestState? quests,  List<QuestAward> awards,  bool opening,  ChestResult? chest)  $default,) {final _that = this;
switch (_that) {
case _QuestsState():
return $default(_that.quests,_that.awards,_that.opening,_that.chest);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( QuestState? quests,  List<QuestAward> awards,  bool opening,  ChestResult? chest)?  $default,) {final _that = this;
switch (_that) {
case _QuestsState() when $default != null:
return $default(_that.quests,_that.awards,_that.opening,_that.chest);case _:
  return null;

}
}

}

/// @nodoc


class _QuestsState implements QuestsState {
  const _QuestsState({this.quests, final  List<QuestAward> awards = const <QuestAward>[], this.opening = false, this.chest}): _awards = awards;
  

@override final  QuestState? quests;
 final  List<QuestAward> _awards;
@override@JsonKey() List<QuestAward> get awards {
  if (_awards is EqualUnmodifiableListView) return _awards;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_awards);
}

@override@JsonKey() final  bool opening;
/// The last chest result. The view shows the chest sheet when it changes.
@override final  ChestResult? chest;

/// Create a copy of QuestsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuestsStateCopyWith<_QuestsState> get copyWith => __$QuestsStateCopyWithImpl<_QuestsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QuestsState&&(identical(other.quests, quests) || other.quests == quests)&&const DeepCollectionEquality().equals(other._awards, _awards)&&(identical(other.opening, opening) || other.opening == opening)&&(identical(other.chest, chest) || other.chest == chest));
}


@override
int get hashCode => Object.hash(runtimeType,quests,const DeepCollectionEquality().hash(_awards),opening,chest);

@override
String toString() {
  return 'QuestsState(quests: $quests, awards: $awards, opening: $opening, chest: $chest)';
}


}

/// @nodoc
abstract mixin class _$QuestsStateCopyWith<$Res> implements $QuestsStateCopyWith<$Res> {
  factory _$QuestsStateCopyWith(_QuestsState value, $Res Function(_QuestsState) _then) = __$QuestsStateCopyWithImpl;
@override @useResult
$Res call({
 QuestState? quests, List<QuestAward> awards, bool opening, ChestResult? chest
});




}
/// @nodoc
class __$QuestsStateCopyWithImpl<$Res>
    implements _$QuestsStateCopyWith<$Res> {
  __$QuestsStateCopyWithImpl(this._self, this._then);

  final _QuestsState _self;
  final $Res Function(_QuestsState) _then;

/// Create a copy of QuestsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? quests = freezed,Object? awards = null,Object? opening = null,Object? chest = freezed,}) {
  return _then(_QuestsState(
quests: freezed == quests ? _self.quests : quests // ignore: cast_nullable_to_non_nullable
as QuestState?,awards: null == awards ? _self._awards : awards // ignore: cast_nullable_to_non_nullable
as List<QuestAward>,opening: null == opening ? _self.opening : opening // ignore: cast_nullable_to_non_nullable
as bool,chest: freezed == chest ? _self.chest : chest // ignore: cast_nullable_to_non_nullable
as ChestResult?,
  ));
}


}

// dart format on
