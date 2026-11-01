// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'daily_moment_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DailyMomentState {

 DailyMomentStep? get step; bool get busy; bool get done; bool get unavailable; bool get error; StreakClaimResult? get receipt; int? get coins; String? get itemId; int get chestCost; int get balance;
/// Create a copy of DailyMomentState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DailyMomentStateCopyWith<DailyMomentState> get copyWith => _$DailyMomentStateCopyWithImpl<DailyMomentState>(this as DailyMomentState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DailyMomentState&&(identical(other.step, step) || other.step == step)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.done, done) || other.done == done)&&(identical(other.unavailable, unavailable) || other.unavailable == unavailable)&&(identical(other.error, error) || other.error == error)&&(identical(other.receipt, receipt) || other.receipt == receipt)&&(identical(other.coins, coins) || other.coins == coins)&&(identical(other.itemId, itemId) || other.itemId == itemId)&&(identical(other.chestCost, chestCost) || other.chestCost == chestCost)&&(identical(other.balance, balance) || other.balance == balance));
}


@override
int get hashCode => Object.hash(runtimeType,step,busy,done,unavailable,error,receipt,coins,itemId,chestCost,balance);

@override
String toString() {
  return 'DailyMomentState(step: $step, busy: $busy, done: $done, unavailable: $unavailable, error: $error, receipt: $receipt, coins: $coins, itemId: $itemId, chestCost: $chestCost, balance: $balance)';
}


}

/// @nodoc
abstract mixin class $DailyMomentStateCopyWith<$Res>  {
  factory $DailyMomentStateCopyWith(DailyMomentState value, $Res Function(DailyMomentState) _then) = _$DailyMomentStateCopyWithImpl;
@useResult
$Res call({
 DailyMomentStep? step, bool busy, bool done, bool unavailable, bool error, StreakClaimResult? receipt, int? coins, String? itemId, int chestCost, int balance
});




}
/// @nodoc
class _$DailyMomentStateCopyWithImpl<$Res>
    implements $DailyMomentStateCopyWith<$Res> {
  _$DailyMomentStateCopyWithImpl(this._self, this._then);

  final DailyMomentState _self;
  final $Res Function(DailyMomentState) _then;

/// Create a copy of DailyMomentState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? step = freezed,Object? busy = null,Object? done = null,Object? unavailable = null,Object? error = null,Object? receipt = freezed,Object? coins = freezed,Object? itemId = freezed,Object? chestCost = null,Object? balance = null,}) {
  return _then(_self.copyWith(
step: freezed == step ? _self.step : step // ignore: cast_nullable_to_non_nullable
as DailyMomentStep?,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,unavailable: null == unavailable ? _self.unavailable : unavailable // ignore: cast_nullable_to_non_nullable
as bool,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as bool,receipt: freezed == receipt ? _self.receipt : receipt // ignore: cast_nullable_to_non_nullable
as StreakClaimResult?,coins: freezed == coins ? _self.coins : coins // ignore: cast_nullable_to_non_nullable
as int?,itemId: freezed == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as String?,chestCost: null == chestCost ? _self.chestCost : chestCost // ignore: cast_nullable_to_non_nullable
as int,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DailyMomentState].
extension DailyMomentStatePatterns on DailyMomentState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DailyMomentState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DailyMomentState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DailyMomentState value)  $default,){
final _that = this;
switch (_that) {
case _DailyMomentState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DailyMomentState value)?  $default,){
final _that = this;
switch (_that) {
case _DailyMomentState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DailyMomentStep? step,  bool busy,  bool done,  bool unavailable,  bool error,  StreakClaimResult? receipt,  int? coins,  String? itemId,  int chestCost,  int balance)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DailyMomentState() when $default != null:
return $default(_that.step,_that.busy,_that.done,_that.unavailable,_that.error,_that.receipt,_that.coins,_that.itemId,_that.chestCost,_that.balance);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DailyMomentStep? step,  bool busy,  bool done,  bool unavailable,  bool error,  StreakClaimResult? receipt,  int? coins,  String? itemId,  int chestCost,  int balance)  $default,) {final _that = this;
switch (_that) {
case _DailyMomentState():
return $default(_that.step,_that.busy,_that.done,_that.unavailable,_that.error,_that.receipt,_that.coins,_that.itemId,_that.chestCost,_that.balance);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DailyMomentStep? step,  bool busy,  bool done,  bool unavailable,  bool error,  StreakClaimResult? receipt,  int? coins,  String? itemId,  int chestCost,  int balance)?  $default,) {final _that = this;
switch (_that) {
case _DailyMomentState() when $default != null:
return $default(_that.step,_that.busy,_that.done,_that.unavailable,_that.error,_that.receipt,_that.coins,_that.itemId,_that.chestCost,_that.balance);case _:
  return null;

}
}

}

/// @nodoc


class _DailyMomentState extends DailyMomentState {
  const _DailyMomentState({this.step, this.busy = false, this.done = false, this.unavailable = false, this.error = false, this.receipt, this.coins, this.itemId, this.chestCost = 0, this.balance = 0}): super._();
  

@override final  DailyMomentStep? step;
@override@JsonKey() final  bool busy;
@override@JsonKey() final  bool done;
@override@JsonKey() final  bool unavailable;
@override@JsonKey() final  bool error;
@override final  StreakClaimResult? receipt;
@override final  int? coins;
@override final  String? itemId;
@override@JsonKey() final  int chestCost;
@override@JsonKey() final  int balance;

/// Create a copy of DailyMomentState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DailyMomentStateCopyWith<_DailyMomentState> get copyWith => __$DailyMomentStateCopyWithImpl<_DailyMomentState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DailyMomentState&&(identical(other.step, step) || other.step == step)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.done, done) || other.done == done)&&(identical(other.unavailable, unavailable) || other.unavailable == unavailable)&&(identical(other.error, error) || other.error == error)&&(identical(other.receipt, receipt) || other.receipt == receipt)&&(identical(other.coins, coins) || other.coins == coins)&&(identical(other.itemId, itemId) || other.itemId == itemId)&&(identical(other.chestCost, chestCost) || other.chestCost == chestCost)&&(identical(other.balance, balance) || other.balance == balance));
}


@override
int get hashCode => Object.hash(runtimeType,step,busy,done,unavailable,error,receipt,coins,itemId,chestCost,balance);

@override
String toString() {
  return 'DailyMomentState(step: $step, busy: $busy, done: $done, unavailable: $unavailable, error: $error, receipt: $receipt, coins: $coins, itemId: $itemId, chestCost: $chestCost, balance: $balance)';
}


}

/// @nodoc
abstract mixin class _$DailyMomentStateCopyWith<$Res> implements $DailyMomentStateCopyWith<$Res> {
  factory _$DailyMomentStateCopyWith(_DailyMomentState value, $Res Function(_DailyMomentState) _then) = __$DailyMomentStateCopyWithImpl;
@override @useResult
$Res call({
 DailyMomentStep? step, bool busy, bool done, bool unavailable, bool error, StreakClaimResult? receipt, int? coins, String? itemId, int chestCost, int balance
});




}
/// @nodoc
class __$DailyMomentStateCopyWithImpl<$Res>
    implements _$DailyMomentStateCopyWith<$Res> {
  __$DailyMomentStateCopyWithImpl(this._self, this._then);

  final _DailyMomentState _self;
  final $Res Function(_DailyMomentState) _then;

/// Create a copy of DailyMomentState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? step = freezed,Object? busy = null,Object? done = null,Object? unavailable = null,Object? error = null,Object? receipt = freezed,Object? coins = freezed,Object? itemId = freezed,Object? chestCost = null,Object? balance = null,}) {
  return _then(_DailyMomentState(
step: freezed == step ? _self.step : step // ignore: cast_nullable_to_non_nullable
as DailyMomentStep?,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,unavailable: null == unavailable ? _self.unavailable : unavailable // ignore: cast_nullable_to_non_nullable
as bool,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as bool,receipt: freezed == receipt ? _self.receipt : receipt // ignore: cast_nullable_to_non_nullable
as StreakClaimResult?,coins: freezed == coins ? _self.coins : coins // ignore: cast_nullable_to_non_nullable
as int?,itemId: freezed == itemId ? _self.itemId : itemId // ignore: cast_nullable_to_non_nullable
as String?,chestCost: null == chestCost ? _self.chestCost : chestCost // ignore: cast_nullable_to_non_nullable
as int,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
