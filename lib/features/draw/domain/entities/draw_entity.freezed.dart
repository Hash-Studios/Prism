// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'draw_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DrawEntity {

 String get weekKey; String get status; DateTime get closesAt; int get tickets; int get participants; int get prizeProMonths; String get prizeItemId; String? get winnerName;
/// Create a copy of DrawEntity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DrawEntityCopyWith<DrawEntity> get copyWith => _$DrawEntityCopyWithImpl<DrawEntity>(this as DrawEntity, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DrawEntity&&(identical(other.weekKey, weekKey) || other.weekKey == weekKey)&&(identical(other.status, status) || other.status == status)&&(identical(other.closesAt, closesAt) || other.closesAt == closesAt)&&(identical(other.tickets, tickets) || other.tickets == tickets)&&(identical(other.participants, participants) || other.participants == participants)&&(identical(other.prizeProMonths, prizeProMonths) || other.prizeProMonths == prizeProMonths)&&(identical(other.prizeItemId, prizeItemId) || other.prizeItemId == prizeItemId)&&(identical(other.winnerName, winnerName) || other.winnerName == winnerName));
}


@override
int get hashCode => Object.hash(runtimeType,weekKey,status,closesAt,tickets,participants,prizeProMonths,prizeItemId,winnerName);

@override
String toString() {
  return 'DrawEntity(weekKey: $weekKey, status: $status, closesAt: $closesAt, tickets: $tickets, participants: $participants, prizeProMonths: $prizeProMonths, prizeItemId: $prizeItemId, winnerName: $winnerName)';
}


}

/// @nodoc
abstract mixin class $DrawEntityCopyWith<$Res>  {
  factory $DrawEntityCopyWith(DrawEntity value, $Res Function(DrawEntity) _then) = _$DrawEntityCopyWithImpl;
@useResult
$Res call({
 String weekKey, String status, DateTime closesAt, int tickets, int participants, int prizeProMonths, String prizeItemId, String? winnerName
});




}
/// @nodoc
class _$DrawEntityCopyWithImpl<$Res>
    implements $DrawEntityCopyWith<$Res> {
  _$DrawEntityCopyWithImpl(this._self, this._then);

  final DrawEntity _self;
  final $Res Function(DrawEntity) _then;

/// Create a copy of DrawEntity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? weekKey = null,Object? status = null,Object? closesAt = null,Object? tickets = null,Object? participants = null,Object? prizeProMonths = null,Object? prizeItemId = null,Object? winnerName = freezed,}) {
  return _then(_self.copyWith(
weekKey: null == weekKey ? _self.weekKey : weekKey // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,closesAt: null == closesAt ? _self.closesAt : closesAt // ignore: cast_nullable_to_non_nullable
as DateTime,tickets: null == tickets ? _self.tickets : tickets // ignore: cast_nullable_to_non_nullable
as int,participants: null == participants ? _self.participants : participants // ignore: cast_nullable_to_non_nullable
as int,prizeProMonths: null == prizeProMonths ? _self.prizeProMonths : prizeProMonths // ignore: cast_nullable_to_non_nullable
as int,prizeItemId: null == prizeItemId ? _self.prizeItemId : prizeItemId // ignore: cast_nullable_to_non_nullable
as String,winnerName: freezed == winnerName ? _self.winnerName : winnerName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DrawEntity].
extension DrawEntityPatterns on DrawEntity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DrawEntity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DrawEntity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DrawEntity value)  $default,){
final _that = this;
switch (_that) {
case _DrawEntity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DrawEntity value)?  $default,){
final _that = this;
switch (_that) {
case _DrawEntity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String weekKey,  String status,  DateTime closesAt,  int tickets,  int participants,  int prizeProMonths,  String prizeItemId,  String? winnerName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DrawEntity() when $default != null:
return $default(_that.weekKey,_that.status,_that.closesAt,_that.tickets,_that.participants,_that.prizeProMonths,_that.prizeItemId,_that.winnerName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String weekKey,  String status,  DateTime closesAt,  int tickets,  int participants,  int prizeProMonths,  String prizeItemId,  String? winnerName)  $default,) {final _that = this;
switch (_that) {
case _DrawEntity():
return $default(_that.weekKey,_that.status,_that.closesAt,_that.tickets,_that.participants,_that.prizeProMonths,_that.prizeItemId,_that.winnerName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String weekKey,  String status,  DateTime closesAt,  int tickets,  int participants,  int prizeProMonths,  String prizeItemId,  String? winnerName)?  $default,) {final _that = this;
switch (_that) {
case _DrawEntity() when $default != null:
return $default(_that.weekKey,_that.status,_that.closesAt,_that.tickets,_that.participants,_that.prizeProMonths,_that.prizeItemId,_that.winnerName);case _:
  return null;

}
}

}

/// @nodoc


class _DrawEntity implements DrawEntity {
  const _DrawEntity({required this.weekKey, required this.status, required this.closesAt, required this.tickets, required this.participants, required this.prizeProMonths, required this.prizeItemId, this.winnerName});
  

@override final  String weekKey;
@override final  String status;
@override final  DateTime closesAt;
@override final  int tickets;
@override final  int participants;
@override final  int prizeProMonths;
@override final  String prizeItemId;
@override final  String? winnerName;

/// Create a copy of DrawEntity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DrawEntityCopyWith<_DrawEntity> get copyWith => __$DrawEntityCopyWithImpl<_DrawEntity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DrawEntity&&(identical(other.weekKey, weekKey) || other.weekKey == weekKey)&&(identical(other.status, status) || other.status == status)&&(identical(other.closesAt, closesAt) || other.closesAt == closesAt)&&(identical(other.tickets, tickets) || other.tickets == tickets)&&(identical(other.participants, participants) || other.participants == participants)&&(identical(other.prizeProMonths, prizeProMonths) || other.prizeProMonths == prizeProMonths)&&(identical(other.prizeItemId, prizeItemId) || other.prizeItemId == prizeItemId)&&(identical(other.winnerName, winnerName) || other.winnerName == winnerName));
}


@override
int get hashCode => Object.hash(runtimeType,weekKey,status,closesAt,tickets,participants,prizeProMonths,prizeItemId,winnerName);

@override
String toString() {
  return 'DrawEntity(weekKey: $weekKey, status: $status, closesAt: $closesAt, tickets: $tickets, participants: $participants, prizeProMonths: $prizeProMonths, prizeItemId: $prizeItemId, winnerName: $winnerName)';
}


}

/// @nodoc
abstract mixin class _$DrawEntityCopyWith<$Res> implements $DrawEntityCopyWith<$Res> {
  factory _$DrawEntityCopyWith(_DrawEntity value, $Res Function(_DrawEntity) _then) = __$DrawEntityCopyWithImpl;
@override @useResult
$Res call({
 String weekKey, String status, DateTime closesAt, int tickets, int participants, int prizeProMonths, String prizeItemId, String? winnerName
});




}
/// @nodoc
class __$DrawEntityCopyWithImpl<$Res>
    implements _$DrawEntityCopyWith<$Res> {
  __$DrawEntityCopyWithImpl(this._self, this._then);

  final _DrawEntity _self;
  final $Res Function(_DrawEntity) _then;

/// Create a copy of DrawEntity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? weekKey = null,Object? status = null,Object? closesAt = null,Object? tickets = null,Object? participants = null,Object? prizeProMonths = null,Object? prizeItemId = null,Object? winnerName = freezed,}) {
  return _then(_DrawEntity(
weekKey: null == weekKey ? _self.weekKey : weekKey // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,closesAt: null == closesAt ? _self.closesAt : closesAt // ignore: cast_nullable_to_non_nullable
as DateTime,tickets: null == tickets ? _self.tickets : tickets // ignore: cast_nullable_to_non_nullable
as int,participants: null == participants ? _self.participants : participants // ignore: cast_nullable_to_non_nullable
as int,prizeProMonths: null == prizeProMonths ? _self.prizeProMonths : prizeProMonths // ignore: cast_nullable_to_non_nullable
as int,prizeItemId: null == prizeItemId ? _self.prizeItemId : prizeItemId // ignore: cast_nullable_to_non_nullable
as String,winnerName: freezed == winnerName ? _self.winnerName : winnerName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
