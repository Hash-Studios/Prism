// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wrapped_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WrappedState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WrappedState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'WrappedState()';
}


}

/// @nodoc
class $WrappedStateCopyWith<$Res>  {
$WrappedStateCopyWith(WrappedState _, $Res Function(WrappedState) __);
}


/// Adds pattern-matching-related methods to [WrappedState].
extension WrappedStatePatterns on WrappedState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( WrappedIdle value)?  idle,TResult Function( WrappedLoading value)?  loading,TResult Function( WrappedReady value)?  ready,TResult Function( WrappedNotEligible value)?  notEligible,TResult Function( WrappedFailed value)?  failed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case WrappedIdle() when idle != null:
return idle(_that);case WrappedLoading() when loading != null:
return loading(_that);case WrappedReady() when ready != null:
return ready(_that);case WrappedNotEligible() when notEligible != null:
return notEligible(_that);case WrappedFailed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( WrappedIdle value)  idle,required TResult Function( WrappedLoading value)  loading,required TResult Function( WrappedReady value)  ready,required TResult Function( WrappedNotEligible value)  notEligible,required TResult Function( WrappedFailed value)  failed,}){
final _that = this;
switch (_that) {
case WrappedIdle():
return idle(_that);case WrappedLoading():
return loading(_that);case WrappedReady():
return ready(_that);case WrappedNotEligible():
return notEligible(_that);case WrappedFailed():
return failed(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( WrappedIdle value)?  idle,TResult? Function( WrappedLoading value)?  loading,TResult? Function( WrappedReady value)?  ready,TResult? Function( WrappedNotEligible value)?  notEligible,TResult? Function( WrappedFailed value)?  failed,}){
final _that = this;
switch (_that) {
case WrappedIdle() when idle != null:
return idle(_that);case WrappedLoading() when loading != null:
return loading(_that);case WrappedReady() when ready != null:
return ready(_that);case WrappedNotEligible() when notEligible != null:
return notEligible(_that);case WrappedFailed() when failed != null:
return failed(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function( String uid)?  loading,TResult Function( String uid,  WrappedYear year)?  ready,TResult Function( String uid)?  notEligible,TResult Function( String uid)?  failed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case WrappedIdle() when idle != null:
return idle();case WrappedLoading() when loading != null:
return loading(_that.uid);case WrappedReady() when ready != null:
return ready(_that.uid,_that.year);case WrappedNotEligible() when notEligible != null:
return notEligible(_that.uid);case WrappedFailed() when failed != null:
return failed(_that.uid);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function( String uid)  loading,required TResult Function( String uid,  WrappedYear year)  ready,required TResult Function( String uid)  notEligible,required TResult Function( String uid)  failed,}) {final _that = this;
switch (_that) {
case WrappedIdle():
return idle();case WrappedLoading():
return loading(_that.uid);case WrappedReady():
return ready(_that.uid,_that.year);case WrappedNotEligible():
return notEligible(_that.uid);case WrappedFailed():
return failed(_that.uid);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function( String uid)?  loading,TResult? Function( String uid,  WrappedYear year)?  ready,TResult? Function( String uid)?  notEligible,TResult? Function( String uid)?  failed,}) {final _that = this;
switch (_that) {
case WrappedIdle() when idle != null:
return idle();case WrappedLoading() when loading != null:
return loading(_that.uid);case WrappedReady() when ready != null:
return ready(_that.uid,_that.year);case WrappedNotEligible() when notEligible != null:
return notEligible(_that.uid);case WrappedFailed() when failed != null:
return failed(_that.uid);case _:
  return null;

}
}

}

/// @nodoc


class WrappedIdle implements WrappedState {
  const WrappedIdle();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WrappedIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'WrappedState.idle()';
}


}




/// @nodoc


class WrappedLoading implements WrappedState {
  const WrappedLoading(this.uid);
  

 final  String uid;

/// Create a copy of WrappedState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WrappedLoadingCopyWith<WrappedLoading> get copyWith => _$WrappedLoadingCopyWithImpl<WrappedLoading>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WrappedLoading&&(identical(other.uid, uid) || other.uid == uid));
}


@override
int get hashCode => Object.hash(runtimeType,uid);

@override
String toString() {
  return 'WrappedState.loading(uid: $uid)';
}


}

/// @nodoc
abstract mixin class $WrappedLoadingCopyWith<$Res> implements $WrappedStateCopyWith<$Res> {
  factory $WrappedLoadingCopyWith(WrappedLoading value, $Res Function(WrappedLoading) _then) = _$WrappedLoadingCopyWithImpl;
@useResult
$Res call({
 String uid
});




}
/// @nodoc
class _$WrappedLoadingCopyWithImpl<$Res>
    implements $WrappedLoadingCopyWith<$Res> {
  _$WrappedLoadingCopyWithImpl(this._self, this._then);

  final WrappedLoading _self;
  final $Res Function(WrappedLoading) _then;

/// Create a copy of WrappedState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? uid = null,}) {
  return _then(WrappedLoading(
null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class WrappedReady implements WrappedState {
  const WrappedReady(this.uid, this.year);
  

 final  String uid;
 final  WrappedYear year;

/// Create a copy of WrappedState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WrappedReadyCopyWith<WrappedReady> get copyWith => _$WrappedReadyCopyWithImpl<WrappedReady>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WrappedReady&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.year, year) || other.year == year));
}


@override
int get hashCode => Object.hash(runtimeType,uid,year);

@override
String toString() {
  return 'WrappedState.ready(uid: $uid, year: $year)';
}


}

/// @nodoc
abstract mixin class $WrappedReadyCopyWith<$Res> implements $WrappedStateCopyWith<$Res> {
  factory $WrappedReadyCopyWith(WrappedReady value, $Res Function(WrappedReady) _then) = _$WrappedReadyCopyWithImpl;
@useResult
$Res call({
 String uid, WrappedYear year
});




}
/// @nodoc
class _$WrappedReadyCopyWithImpl<$Res>
    implements $WrappedReadyCopyWith<$Res> {
  _$WrappedReadyCopyWithImpl(this._self, this._then);

  final WrappedReady _self;
  final $Res Function(WrappedReady) _then;

/// Create a copy of WrappedState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? uid = null,Object? year = null,}) {
  return _then(WrappedReady(
null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,null == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as WrappedYear,
  ));
}


}

/// @nodoc


class WrappedNotEligible implements WrappedState {
  const WrappedNotEligible(this.uid);
  

 final  String uid;

/// Create a copy of WrappedState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WrappedNotEligibleCopyWith<WrappedNotEligible> get copyWith => _$WrappedNotEligibleCopyWithImpl<WrappedNotEligible>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WrappedNotEligible&&(identical(other.uid, uid) || other.uid == uid));
}


@override
int get hashCode => Object.hash(runtimeType,uid);

@override
String toString() {
  return 'WrappedState.notEligible(uid: $uid)';
}


}

/// @nodoc
abstract mixin class $WrappedNotEligibleCopyWith<$Res> implements $WrappedStateCopyWith<$Res> {
  factory $WrappedNotEligibleCopyWith(WrappedNotEligible value, $Res Function(WrappedNotEligible) _then) = _$WrappedNotEligibleCopyWithImpl;
@useResult
$Res call({
 String uid
});




}
/// @nodoc
class _$WrappedNotEligibleCopyWithImpl<$Res>
    implements $WrappedNotEligibleCopyWith<$Res> {
  _$WrappedNotEligibleCopyWithImpl(this._self, this._then);

  final WrappedNotEligible _self;
  final $Res Function(WrappedNotEligible) _then;

/// Create a copy of WrappedState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? uid = null,}) {
  return _then(WrappedNotEligible(
null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class WrappedFailed implements WrappedState {
  const WrappedFailed(this.uid);
  

 final  String uid;

/// Create a copy of WrappedState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WrappedFailedCopyWith<WrappedFailed> get copyWith => _$WrappedFailedCopyWithImpl<WrappedFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WrappedFailed&&(identical(other.uid, uid) || other.uid == uid));
}


@override
int get hashCode => Object.hash(runtimeType,uid);

@override
String toString() {
  return 'WrappedState.failed(uid: $uid)';
}


}

/// @nodoc
abstract mixin class $WrappedFailedCopyWith<$Res> implements $WrappedStateCopyWith<$Res> {
  factory $WrappedFailedCopyWith(WrappedFailed value, $Res Function(WrappedFailed) _then) = _$WrappedFailedCopyWithImpl;
@useResult
$Res call({
 String uid
});




}
/// @nodoc
class _$WrappedFailedCopyWithImpl<$Res>
    implements $WrappedFailedCopyWith<$Res> {
  _$WrappedFailedCopyWithImpl(this._self, this._then);

  final WrappedFailed _self;
  final $Res Function(WrappedFailed) _then;

/// Create a copy of WrappedState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? uid = null,}) {
  return _then(WrappedFailed(
null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$WrappedEvent {

 String get uid;
/// Create a copy of WrappedEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WrappedEventCopyWith<WrappedEvent> get copyWith => _$WrappedEventCopyWithImpl<WrappedEvent>(this as WrappedEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WrappedEvent&&(identical(other.uid, uid) || other.uid == uid));
}


@override
int get hashCode => Object.hash(runtimeType,uid);

@override
String toString() {
  return 'WrappedEvent(uid: $uid)';
}


}

/// @nodoc
abstract mixin class $WrappedEventCopyWith<$Res>  {
  factory $WrappedEventCopyWith(WrappedEvent value, $Res Function(WrappedEvent) _then) = _$WrappedEventCopyWithImpl;
@useResult
$Res call({
 String uid
});




}
/// @nodoc
class _$WrappedEventCopyWithImpl<$Res>
    implements $WrappedEventCopyWith<$Res> {
  _$WrappedEventCopyWithImpl(this._self, this._then);

  final WrappedEvent _self;
  final $Res Function(WrappedEvent) _then;

/// Create a copy of WrappedEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uid = null,}) {
  return _then(_self.copyWith(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [WrappedEvent].
extension WrappedEventPatterns on WrappedEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( LoadWrapped value)?  load,required TResult orElse(),}){
final _that = this;
switch (_that) {
case LoadWrapped() when load != null:
return load(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( LoadWrapped value)  load,}){
final _that = this;
switch (_that) {
case LoadWrapped():
return load(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( LoadWrapped value)?  load,}){
final _that = this;
switch (_that) {
case LoadWrapped() when load != null:
return load(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String uid)?  load,required TResult orElse(),}) {final _that = this;
switch (_that) {
case LoadWrapped() when load != null:
return load(_that.uid);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String uid)  load,}) {final _that = this;
switch (_that) {
case LoadWrapped():
return load(_that.uid);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String uid)?  load,}) {final _that = this;
switch (_that) {
case LoadWrapped() when load != null:
return load(_that.uid);case _:
  return null;

}
}

}

/// @nodoc


class LoadWrapped implements WrappedEvent {
  const LoadWrapped(this.uid);
  

@override final  String uid;

/// Create a copy of WrappedEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoadWrappedCopyWith<LoadWrapped> get copyWith => _$LoadWrappedCopyWithImpl<LoadWrapped>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoadWrapped&&(identical(other.uid, uid) || other.uid == uid));
}


@override
int get hashCode => Object.hash(runtimeType,uid);

@override
String toString() {
  return 'WrappedEvent.load(uid: $uid)';
}


}

/// @nodoc
abstract mixin class $LoadWrappedCopyWith<$Res> implements $WrappedEventCopyWith<$Res> {
  factory $LoadWrappedCopyWith(LoadWrapped value, $Res Function(LoadWrapped) _then) = _$LoadWrappedCopyWithImpl;
@override @useResult
$Res call({
 String uid
});




}
/// @nodoc
class _$LoadWrappedCopyWithImpl<$Res>
    implements $LoadWrappedCopyWith<$Res> {
  _$LoadWrappedCopyWithImpl(this._self, this._then);

  final LoadWrapped _self;
  final $Res Function(LoadWrapped) _then;

/// Create a copy of WrappedEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uid = null,}) {
  return _then(LoadWrapped(
null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
