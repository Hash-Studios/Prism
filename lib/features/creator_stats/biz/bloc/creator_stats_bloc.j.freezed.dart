// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'creator_stats_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CreatorStatsState {

 bool get loading; bool get failed; CreatorStats? get data; StatsMetric get metric;
/// Create a copy of CreatorStatsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CreatorStatsStateCopyWith<CreatorStatsState> get copyWith => _$CreatorStatsStateCopyWithImpl<CreatorStatsState>(this as CreatorStatsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CreatorStatsState&&(identical(other.loading, loading) || other.loading == loading)&&(identical(other.failed, failed) || other.failed == failed)&&(identical(other.data, data) || other.data == data)&&(identical(other.metric, metric) || other.metric == metric));
}


@override
int get hashCode => Object.hash(runtimeType,loading,failed,data,metric);

@override
String toString() {
  return 'CreatorStatsState(loading: $loading, failed: $failed, data: $data, metric: $metric)';
}


}

/// @nodoc
abstract mixin class $CreatorStatsStateCopyWith<$Res>  {
  factory $CreatorStatsStateCopyWith(CreatorStatsState value, $Res Function(CreatorStatsState) _then) = _$CreatorStatsStateCopyWithImpl;
@useResult
$Res call({
 bool loading, bool failed, CreatorStats? data, StatsMetric metric
});




}
/// @nodoc
class _$CreatorStatsStateCopyWithImpl<$Res>
    implements $CreatorStatsStateCopyWith<$Res> {
  _$CreatorStatsStateCopyWithImpl(this._self, this._then);

  final CreatorStatsState _self;
  final $Res Function(CreatorStatsState) _then;

/// Create a copy of CreatorStatsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? loading = null,Object? failed = null,Object? data = freezed,Object? metric = null,}) {
  return _then(_self.copyWith(
loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,failed: null == failed ? _self.failed : failed // ignore: cast_nullable_to_non_nullable
as bool,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as CreatorStats?,metric: null == metric ? _self.metric : metric // ignore: cast_nullable_to_non_nullable
as StatsMetric,
  ));
}

}


/// Adds pattern-matching-related methods to [CreatorStatsState].
extension CreatorStatsStatePatterns on CreatorStatsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CreatorStatsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CreatorStatsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CreatorStatsState value)  $default,){
final _that = this;
switch (_that) {
case _CreatorStatsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CreatorStatsState value)?  $default,){
final _that = this;
switch (_that) {
case _CreatorStatsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool loading,  bool failed,  CreatorStats? data,  StatsMetric metric)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CreatorStatsState() when $default != null:
return $default(_that.loading,_that.failed,_that.data,_that.metric);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool loading,  bool failed,  CreatorStats? data,  StatsMetric metric)  $default,) {final _that = this;
switch (_that) {
case _CreatorStatsState():
return $default(_that.loading,_that.failed,_that.data,_that.metric);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool loading,  bool failed,  CreatorStats? data,  StatsMetric metric)?  $default,) {final _that = this;
switch (_that) {
case _CreatorStatsState() when $default != null:
return $default(_that.loading,_that.failed,_that.data,_that.metric);case _:
  return null;

}
}

}

/// @nodoc


class _CreatorStatsState implements CreatorStatsState {
  const _CreatorStatsState({this.loading = false, this.failed = false, this.data, this.metric = StatsMetric.views});


@override@JsonKey() final  bool loading;
@override@JsonKey() final  bool failed;
@override final  CreatorStats? data;
@override@JsonKey() final  StatsMetric metric;

/// Create a copy of CreatorStatsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CreatorStatsStateCopyWith<_CreatorStatsState> get copyWith => __$CreatorStatsStateCopyWithImpl<_CreatorStatsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CreatorStatsState&&(identical(other.loading, loading) || other.loading == loading)&&(identical(other.failed, failed) || other.failed == failed)&&(identical(other.data, data) || other.data == data)&&(identical(other.metric, metric) || other.metric == metric));
}


@override
int get hashCode => Object.hash(runtimeType,loading,failed,data,metric);

@override
String toString() {
  return 'CreatorStatsState(loading: $loading, failed: $failed, data: $data, metric: $metric)';
}


}

/// @nodoc
abstract mixin class _$CreatorStatsStateCopyWith<$Res> implements $CreatorStatsStateCopyWith<$Res> {
  factory _$CreatorStatsStateCopyWith(_CreatorStatsState value, $Res Function(_CreatorStatsState) _then) = __$CreatorStatsStateCopyWithImpl;
@override @useResult
$Res call({
 bool loading, bool failed, CreatorStats? data, StatsMetric metric
});




}
/// @nodoc
class __$CreatorStatsStateCopyWithImpl<$Res>
    implements _$CreatorStatsStateCopyWith<$Res> {
  __$CreatorStatsStateCopyWithImpl(this._self, this._then);

  final _CreatorStatsState _self;
  final $Res Function(_CreatorStatsState) _then;

/// Create a copy of CreatorStatsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? loading = null,Object? failed = null,Object? data = freezed,Object? metric = null,}) {
  return _then(_CreatorStatsState(
loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,failed: null == failed ? _self.failed : failed // ignore: cast_nullable_to_non_nullable
as bool,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as CreatorStats?,metric: null == metric ? _self.metric : metric // ignore: cast_nullable_to_non_nullable
as StatsMetric,
  ));
}


}

/// @nodoc
mixin _$CreatorStatsEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CreatorStatsEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CreatorStatsEvent()';
}


}

/// @nodoc
class $CreatorStatsEventCopyWith<$Res>  {
$CreatorStatsEventCopyWith(CreatorStatsEvent _, $Res Function(CreatorStatsEvent) __);
}


/// Adds pattern-matching-related methods to [CreatorStatsEvent].
extension CreatorStatsEventPatterns on CreatorStatsEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( LoadCreatorStats value)?  load,TResult Function( SelectStatsMetric value)?  select,required TResult orElse(),}){
final _that = this;
switch (_that) {
case LoadCreatorStats() when load != null:
return load(_that);case SelectStatsMetric() when select != null:
return select(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( LoadCreatorStats value)  load,required TResult Function( SelectStatsMetric value)  select,}){
final _that = this;
switch (_that) {
case LoadCreatorStats():
return load(_that);case SelectStatsMetric():
return select(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( LoadCreatorStats value)?  load,TResult? Function( SelectStatsMetric value)?  select,}){
final _that = this;
switch (_that) {
case LoadCreatorStats() when load != null:
return load(_that);case SelectStatsMetric() when select != null:
return select(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  load,TResult Function( StatsMetric metric)?  select,required TResult orElse(),}) {final _that = this;
switch (_that) {
case LoadCreatorStats() when load != null:
return load();case SelectStatsMetric() when select != null:
return select(_that.metric);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  load,required TResult Function( StatsMetric metric)  select,}) {final _that = this;
switch (_that) {
case LoadCreatorStats():
return load();case SelectStatsMetric():
return select(_that.metric);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  load,TResult? Function( StatsMetric metric)?  select,}) {final _that = this;
switch (_that) {
case LoadCreatorStats() when load != null:
return load();case SelectStatsMetric() when select != null:
return select(_that.metric);case _:
  return null;

}
}

}

/// @nodoc


class LoadCreatorStats implements CreatorStatsEvent {
  const LoadCreatorStats();







@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoadCreatorStats);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'CreatorStatsEvent.load()';
}


}




/// @nodoc


class SelectStatsMetric implements CreatorStatsEvent {
  const SelectStatsMetric(this.metric);


 final  StatsMetric metric;

/// Create a copy of CreatorStatsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SelectStatsMetricCopyWith<SelectStatsMetric> get copyWith => _$SelectStatsMetricCopyWithImpl<SelectStatsMetric>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SelectStatsMetric&&(identical(other.metric, metric) || other.metric == metric));
}


@override
int get hashCode => Object.hash(runtimeType,metric);

@override
String toString() {
  return 'CreatorStatsEvent.select(metric: $metric)';
}


}

/// @nodoc
abstract mixin class $SelectStatsMetricCopyWith<$Res> implements $CreatorStatsEventCopyWith<$Res> {
  factory $SelectStatsMetricCopyWith(SelectStatsMetric value, $Res Function(SelectStatsMetric) _then) = _$SelectStatsMetricCopyWithImpl;
@useResult
$Res call({
 StatsMetric metric
});




}
/// @nodoc
class _$SelectStatsMetricCopyWithImpl<$Res>
    implements $SelectStatsMetricCopyWith<$Res> {
  _$SelectStatsMetricCopyWithImpl(this._self, this._then);

  final SelectStatsMetric _self;
  final $Res Function(SelectStatsMetric) _then;

/// Create a copy of CreatorStatsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? metric = null,}) {
  return _then(SelectStatsMetric(
null == metric ? _self.metric : metric // ignore: cast_nullable_to_non_nullable
as StatsMetric,
  ));
}


}

// dart format on
