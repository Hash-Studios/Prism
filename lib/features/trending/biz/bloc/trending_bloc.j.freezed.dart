// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trending_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TrendingEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrendingEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TrendingEvent()';
}


}

/// @nodoc
class $TrendingEventCopyWith<$Res>  {
$TrendingEventCopyWith(TrendingEvent _, $Res Function(TrendingEvent) __);
}


/// Adds pattern-matching-related methods to [TrendingEvent].
extension TrendingEventPatterns on TrendingEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _RangeSelected value)?  rangeSelected,TResult Function( _RefreshRequested value)?  refreshRequested,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _RangeSelected() when rangeSelected != null:
return rangeSelected(_that);case _RefreshRequested() when refreshRequested != null:
return refreshRequested(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _RangeSelected value)  rangeSelected,required TResult Function( _RefreshRequested value)  refreshRequested,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _RangeSelected():
return rangeSelected(_that);case _RefreshRequested():
return refreshRequested(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _RangeSelected value)?  rangeSelected,TResult? Function( _RefreshRequested value)?  refreshRequested,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _RangeSelected() when rangeSelected != null:
return rangeSelected(_that);case _RefreshRequested() when refreshRequested != null:
return refreshRequested(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  started,TResult Function( TrendingRange range)?  rangeSelected,TResult Function()?  refreshRequested,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _RangeSelected() when rangeSelected != null:
return rangeSelected(_that.range);case _RefreshRequested() when refreshRequested != null:
return refreshRequested();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  started,required TResult Function( TrendingRange range)  rangeSelected,required TResult Function()  refreshRequested,}) {final _that = this;
switch (_that) {
case _Started():
return started();case _RangeSelected():
return rangeSelected(_that.range);case _RefreshRequested():
return refreshRequested();case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  started,TResult? Function( TrendingRange range)?  rangeSelected,TResult? Function()?  refreshRequested,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _RangeSelected() when rangeSelected != null:
return rangeSelected(_that.range);case _RefreshRequested() when refreshRequested != null:
return refreshRequested();case _:
  return null;

}
}

}

/// @nodoc


class _Started implements TrendingEvent {
  const _Started();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TrendingEvent.started()';
}


}




/// @nodoc


class _RangeSelected implements TrendingEvent {
  const _RangeSelected(this.range);
  

 final  TrendingRange range;

/// Create a copy of TrendingEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RangeSelectedCopyWith<_RangeSelected> get copyWith => __$RangeSelectedCopyWithImpl<_RangeSelected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RangeSelected&&(identical(other.range, range) || other.range == range));
}


@override
int get hashCode => Object.hash(runtimeType,range);

@override
String toString() {
  return 'TrendingEvent.rangeSelected(range: $range)';
}


}

/// @nodoc
abstract mixin class _$RangeSelectedCopyWith<$Res> implements $TrendingEventCopyWith<$Res> {
  factory _$RangeSelectedCopyWith(_RangeSelected value, $Res Function(_RangeSelected) _then) = __$RangeSelectedCopyWithImpl;
@useResult
$Res call({
 TrendingRange range
});




}
/// @nodoc
class __$RangeSelectedCopyWithImpl<$Res>
    implements _$RangeSelectedCopyWith<$Res> {
  __$RangeSelectedCopyWithImpl(this._self, this._then);

  final _RangeSelected _self;
  final $Res Function(_RangeSelected) _then;

/// Create a copy of TrendingEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? range = null,}) {
  return _then(_RangeSelected(
null == range ? _self.range : range // ignore: cast_nullable_to_non_nullable
as TrendingRange,
  ));
}


}

/// @nodoc


class _RefreshRequested implements TrendingEvent {
  const _RefreshRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RefreshRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'TrendingEvent.refreshRequested()';
}


}




/// @nodoc
mixin _$TrendingSection {

 LoadStatus get status; List<PrismWallpaper> get walls; Failure? get failure;
/// Create a copy of TrendingSection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrendingSectionCopyWith<TrendingSection> get copyWith => _$TrendingSectionCopyWithImpl<TrendingSection>(this as TrendingSection, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrendingSection&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.walls, walls)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(walls),failure);

@override
String toString() {
  return 'TrendingSection(status: $status, walls: $walls, failure: $failure)';
}


}

/// @nodoc
abstract mixin class $TrendingSectionCopyWith<$Res>  {
  factory $TrendingSectionCopyWith(TrendingSection value, $Res Function(TrendingSection) _then) = _$TrendingSectionCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, List<PrismWallpaper> walls, Failure? failure
});




}
/// @nodoc
class _$TrendingSectionCopyWithImpl<$Res>
    implements $TrendingSectionCopyWith<$Res> {
  _$TrendingSectionCopyWithImpl(this._self, this._then);

  final TrendingSection _self;
  final $Res Function(TrendingSection) _then;

/// Create a copy of TrendingSection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? walls = null,Object? failure = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,walls: null == walls ? _self.walls : walls // ignore: cast_nullable_to_non_nullable
as List<PrismWallpaper>,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}

}


/// Adds pattern-matching-related methods to [TrendingSection].
extension TrendingSectionPatterns on TrendingSection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrendingSection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrendingSection() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrendingSection value)  $default,){
final _that = this;
switch (_that) {
case _TrendingSection():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrendingSection value)?  $default,){
final _that = this;
switch (_that) {
case _TrendingSection() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  List<PrismWallpaper> walls,  Failure? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrendingSection() when $default != null:
return $default(_that.status,_that.walls,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  List<PrismWallpaper> walls,  Failure? failure)  $default,) {final _that = this;
switch (_that) {
case _TrendingSection():
return $default(_that.status,_that.walls,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  List<PrismWallpaper> walls,  Failure? failure)?  $default,) {final _that = this;
switch (_that) {
case _TrendingSection() when $default != null:
return $default(_that.status,_that.walls,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _TrendingSection implements TrendingSection {
  const _TrendingSection({required this.status, required final  List<PrismWallpaper> walls, this.failure}): _walls = walls;
  

@override final  LoadStatus status;
 final  List<PrismWallpaper> _walls;
@override List<PrismWallpaper> get walls {
  if (_walls is EqualUnmodifiableListView) return _walls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_walls);
}

@override final  Failure? failure;

/// Create a copy of TrendingSection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrendingSectionCopyWith<_TrendingSection> get copyWith => __$TrendingSectionCopyWithImpl<_TrendingSection>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrendingSection&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._walls, _walls)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_walls),failure);

@override
String toString() {
  return 'TrendingSection(status: $status, walls: $walls, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$TrendingSectionCopyWith<$Res> implements $TrendingSectionCopyWith<$Res> {
  factory _$TrendingSectionCopyWith(_TrendingSection value, $Res Function(_TrendingSection) _then) = __$TrendingSectionCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, List<PrismWallpaper> walls, Failure? failure
});




}
/// @nodoc
class __$TrendingSectionCopyWithImpl<$Res>
    implements _$TrendingSectionCopyWith<$Res> {
  __$TrendingSectionCopyWithImpl(this._self, this._then);

  final _TrendingSection _self;
  final $Res Function(_TrendingSection) _then;

/// Create a copy of TrendingSection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? walls = null,Object? failure = freezed,}) {
  return _then(_TrendingSection(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,walls: null == walls ? _self._walls : walls // ignore: cast_nullable_to_non_nullable
as List<PrismWallpaper>,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure?,
  ));
}


}

/// @nodoc
mixin _$TrendingState {

 TrendingRange get range; TrendingSection get week; TrendingSection get allTime;
/// Create a copy of TrendingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrendingStateCopyWith<TrendingState> get copyWith => _$TrendingStateCopyWithImpl<TrendingState>(this as TrendingState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrendingState&&(identical(other.range, range) || other.range == range)&&(identical(other.week, week) || other.week == week)&&(identical(other.allTime, allTime) || other.allTime == allTime));
}


@override
int get hashCode => Object.hash(runtimeType,range,week,allTime);

@override
String toString() {
  return 'TrendingState(range: $range, week: $week, allTime: $allTime)';
}


}

/// @nodoc
abstract mixin class $TrendingStateCopyWith<$Res>  {
  factory $TrendingStateCopyWith(TrendingState value, $Res Function(TrendingState) _then) = _$TrendingStateCopyWithImpl;
@useResult
$Res call({
 TrendingRange range, TrendingSection week, TrendingSection allTime
});


$TrendingSectionCopyWith<$Res> get week;$TrendingSectionCopyWith<$Res> get allTime;

}
/// @nodoc
class _$TrendingStateCopyWithImpl<$Res>
    implements $TrendingStateCopyWith<$Res> {
  _$TrendingStateCopyWithImpl(this._self, this._then);

  final TrendingState _self;
  final $Res Function(TrendingState) _then;

/// Create a copy of TrendingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? range = null,Object? week = null,Object? allTime = null,}) {
  return _then(_self.copyWith(
range: null == range ? _self.range : range // ignore: cast_nullable_to_non_nullable
as TrendingRange,week: null == week ? _self.week : week // ignore: cast_nullable_to_non_nullable
as TrendingSection,allTime: null == allTime ? _self.allTime : allTime // ignore: cast_nullable_to_non_nullable
as TrendingSection,
  ));
}
/// Create a copy of TrendingState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TrendingSectionCopyWith<$Res> get week {
  
  return $TrendingSectionCopyWith<$Res>(_self.week, (value) {
    return _then(_self.copyWith(week: value));
  });
}/// Create a copy of TrendingState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TrendingSectionCopyWith<$Res> get allTime {
  
  return $TrendingSectionCopyWith<$Res>(_self.allTime, (value) {
    return _then(_self.copyWith(allTime: value));
  });
}
}


/// Adds pattern-matching-related methods to [TrendingState].
extension TrendingStatePatterns on TrendingState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrendingState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrendingState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrendingState value)  $default,){
final _that = this;
switch (_that) {
case _TrendingState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrendingState value)?  $default,){
final _that = this;
switch (_that) {
case _TrendingState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TrendingRange range,  TrendingSection week,  TrendingSection allTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrendingState() when $default != null:
return $default(_that.range,_that.week,_that.allTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TrendingRange range,  TrendingSection week,  TrendingSection allTime)  $default,) {final _that = this;
switch (_that) {
case _TrendingState():
return $default(_that.range,_that.week,_that.allTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TrendingRange range,  TrendingSection week,  TrendingSection allTime)?  $default,) {final _that = this;
switch (_that) {
case _TrendingState() when $default != null:
return $default(_that.range,_that.week,_that.allTime);case _:
  return null;

}
}

}

/// @nodoc


class _TrendingState extends TrendingState {
  const _TrendingState({required this.range, required this.week, required this.allTime}): super._();
  

@override final  TrendingRange range;
@override final  TrendingSection week;
@override final  TrendingSection allTime;

/// Create a copy of TrendingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrendingStateCopyWith<_TrendingState> get copyWith => __$TrendingStateCopyWithImpl<_TrendingState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrendingState&&(identical(other.range, range) || other.range == range)&&(identical(other.week, week) || other.week == week)&&(identical(other.allTime, allTime) || other.allTime == allTime));
}


@override
int get hashCode => Object.hash(runtimeType,range,week,allTime);

@override
String toString() {
  return 'TrendingState(range: $range, week: $week, allTime: $allTime)';
}


}

/// @nodoc
abstract mixin class _$TrendingStateCopyWith<$Res> implements $TrendingStateCopyWith<$Res> {
  factory _$TrendingStateCopyWith(_TrendingState value, $Res Function(_TrendingState) _then) = __$TrendingStateCopyWithImpl;
@override @useResult
$Res call({
 TrendingRange range, TrendingSection week, TrendingSection allTime
});


@override $TrendingSectionCopyWith<$Res> get week;@override $TrendingSectionCopyWith<$Res> get allTime;

}
/// @nodoc
class __$TrendingStateCopyWithImpl<$Res>
    implements _$TrendingStateCopyWith<$Res> {
  __$TrendingStateCopyWithImpl(this._self, this._then);

  final _TrendingState _self;
  final $Res Function(_TrendingState) _then;

/// Create a copy of TrendingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? range = null,Object? week = null,Object? allTime = null,}) {
  return _then(_TrendingState(
range: null == range ? _self.range : range // ignore: cast_nullable_to_non_nullable
as TrendingRange,week: null == week ? _self.week : week // ignore: cast_nullable_to_non_nullable
as TrendingSection,allTime: null == allTime ? _self.allTime : allTime // ignore: cast_nullable_to_non_nullable
as TrendingSection,
  ));
}

/// Create a copy of TrendingState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TrendingSectionCopyWith<$Res> get week {
  
  return $TrendingSectionCopyWith<$Res>(_self.week, (value) {
    return _then(_self.copyWith(week: value));
  });
}/// Create a copy of TrendingState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TrendingSectionCopyWith<$Res> get allTime {
  
  return $TrendingSectionCopyWith<$Res>(_self.allTime, (value) {
    return _then(_self.copyWith(allTime: value));
  });
}
}

// dart format on
