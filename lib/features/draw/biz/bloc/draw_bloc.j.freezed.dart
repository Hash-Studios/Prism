// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'draw_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DrawEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DrawEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DrawEvent()';
}


}

/// @nodoc
class $DrawEventCopyWith<$Res>  {
$DrawEventCopyWith(DrawEvent _, $Res Function(DrawEvent) __);
}


/// Adds pattern-matching-related methods to [DrawEvent].
extension DrawEventPatterns on DrawEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _Refreshed value)?  refreshed,TResult Function( _TicketRequested value)?  ticketRequested,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _Refreshed() when refreshed != null:
return refreshed(_that);case _TicketRequested() when ticketRequested != null:
return ticketRequested(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _Refreshed value)  refreshed,required TResult Function( _TicketRequested value)  ticketRequested,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _Refreshed():
return refreshed(_that);case _TicketRequested():
return ticketRequested(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _Refreshed value)?  refreshed,TResult? Function( _TicketRequested value)?  ticketRequested,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _Refreshed() when refreshed != null:
return refreshed(_that);case _TicketRequested() when ticketRequested != null:
return ticketRequested(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  started,TResult Function()?  refreshed,TResult Function()?  ticketRequested,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _Refreshed() when refreshed != null:
return refreshed();case _TicketRequested() when ticketRequested != null:
return ticketRequested();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  started,required TResult Function()  refreshed,required TResult Function()  ticketRequested,}) {final _that = this;
switch (_that) {
case _Started():
return started();case _Refreshed():
return refreshed();case _TicketRequested():
return ticketRequested();case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  started,TResult? Function()?  refreshed,TResult? Function()?  ticketRequested,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started();case _Refreshed() when refreshed != null:
return refreshed();case _TicketRequested() when ticketRequested != null:
return ticketRequested();case _:
  return null;

}
}

}

/// @nodoc


class _Started implements DrawEvent {
  const _Started();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DrawEvent.started()';
}


}




/// @nodoc


class _Refreshed implements DrawEvent {
  const _Refreshed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Refreshed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DrawEvent.refreshed()';
}


}




/// @nodoc


class _TicketRequested implements DrawEvent {
  const _TicketRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TicketRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'DrawEvent.ticketRequested()';
}


}




/// @nodoc
mixin _$DrawState {

 LoadStatus get status; int get myTickets; bool get busy; DrawEntity? get draw; DrawEntity? get lastWinner;/// Set by each ticket purchase so the page can show one toast per outcome.
 DrawTicketResult? get purchase;
/// Create a copy of DrawState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DrawStateCopyWith<DrawState> get copyWith => _$DrawStateCopyWithImpl<DrawState>(this as DrawState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DrawState&&(identical(other.status, status) || other.status == status)&&(identical(other.myTickets, myTickets) || other.myTickets == myTickets)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.draw, draw) || other.draw == draw)&&(identical(other.lastWinner, lastWinner) || other.lastWinner == lastWinner)&&(identical(other.purchase, purchase) || other.purchase == purchase));
}


@override
int get hashCode => Object.hash(runtimeType,status,myTickets,busy,draw,lastWinner,purchase);

@override
String toString() {
  return 'DrawState(status: $status, myTickets: $myTickets, busy: $busy, draw: $draw, lastWinner: $lastWinner, purchase: $purchase)';
}


}

/// @nodoc
abstract mixin class $DrawStateCopyWith<$Res>  {
  factory $DrawStateCopyWith(DrawState value, $Res Function(DrawState) _then) = _$DrawStateCopyWithImpl;
@useResult
$Res call({
 LoadStatus status, int myTickets, bool busy, DrawEntity? draw, DrawEntity? lastWinner, DrawTicketResult? purchase
});


$DrawEntityCopyWith<$Res>? get draw;$DrawEntityCopyWith<$Res>? get lastWinner;

}
/// @nodoc
class _$DrawStateCopyWithImpl<$Res>
    implements $DrawStateCopyWith<$Res> {
  _$DrawStateCopyWithImpl(this._self, this._then);

  final DrawState _self;
  final $Res Function(DrawState) _then;

/// Create a copy of DrawState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? myTickets = null,Object? busy = null,Object? draw = freezed,Object? lastWinner = freezed,Object? purchase = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,myTickets: null == myTickets ? _self.myTickets : myTickets // ignore: cast_nullable_to_non_nullable
as int,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,draw: freezed == draw ? _self.draw : draw // ignore: cast_nullable_to_non_nullable
as DrawEntity?,lastWinner: freezed == lastWinner ? _self.lastWinner : lastWinner // ignore: cast_nullable_to_non_nullable
as DrawEntity?,purchase: freezed == purchase ? _self.purchase : purchase // ignore: cast_nullable_to_non_nullable
as DrawTicketResult?,
  ));
}
/// Create a copy of DrawState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DrawEntityCopyWith<$Res>? get draw {
    if (_self.draw == null) {
    return null;
  }

  return $DrawEntityCopyWith<$Res>(_self.draw!, (value) {
    return _then(_self.copyWith(draw: value));
  });
}/// Create a copy of DrawState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DrawEntityCopyWith<$Res>? get lastWinner {
    if (_self.lastWinner == null) {
    return null;
  }

  return $DrawEntityCopyWith<$Res>(_self.lastWinner!, (value) {
    return _then(_self.copyWith(lastWinner: value));
  });
}
}


/// Adds pattern-matching-related methods to [DrawState].
extension DrawStatePatterns on DrawState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DrawState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DrawState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DrawState value)  $default,){
final _that = this;
switch (_that) {
case _DrawState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DrawState value)?  $default,){
final _that = this;
switch (_that) {
case _DrawState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LoadStatus status,  int myTickets,  bool busy,  DrawEntity? draw,  DrawEntity? lastWinner,  DrawTicketResult? purchase)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DrawState() when $default != null:
return $default(_that.status,_that.myTickets,_that.busy,_that.draw,_that.lastWinner,_that.purchase);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LoadStatus status,  int myTickets,  bool busy,  DrawEntity? draw,  DrawEntity? lastWinner,  DrawTicketResult? purchase)  $default,) {final _that = this;
switch (_that) {
case _DrawState():
return $default(_that.status,_that.myTickets,_that.busy,_that.draw,_that.lastWinner,_that.purchase);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LoadStatus status,  int myTickets,  bool busy,  DrawEntity? draw,  DrawEntity? lastWinner,  DrawTicketResult? purchase)?  $default,) {final _that = this;
switch (_that) {
case _DrawState() when $default != null:
return $default(_that.status,_that.myTickets,_that.busy,_that.draw,_that.lastWinner,_that.purchase);case _:
  return null;

}
}

}

/// @nodoc


class _DrawState implements DrawState {
  const _DrawState({required this.status, required this.myTickets, required this.busy, this.draw, this.lastWinner, this.purchase});
  

@override final  LoadStatus status;
@override final  int myTickets;
@override final  bool busy;
@override final  DrawEntity? draw;
@override final  DrawEntity? lastWinner;
/// Set by each ticket purchase so the page can show one toast per outcome.
@override final  DrawTicketResult? purchase;

/// Create a copy of DrawState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DrawStateCopyWith<_DrawState> get copyWith => __$DrawStateCopyWithImpl<_DrawState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DrawState&&(identical(other.status, status) || other.status == status)&&(identical(other.myTickets, myTickets) || other.myTickets == myTickets)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.draw, draw) || other.draw == draw)&&(identical(other.lastWinner, lastWinner) || other.lastWinner == lastWinner)&&(identical(other.purchase, purchase) || other.purchase == purchase));
}


@override
int get hashCode => Object.hash(runtimeType,status,myTickets,busy,draw,lastWinner,purchase);

@override
String toString() {
  return 'DrawState(status: $status, myTickets: $myTickets, busy: $busy, draw: $draw, lastWinner: $lastWinner, purchase: $purchase)';
}


}

/// @nodoc
abstract mixin class _$DrawStateCopyWith<$Res> implements $DrawStateCopyWith<$Res> {
  factory _$DrawStateCopyWith(_DrawState value, $Res Function(_DrawState) _then) = __$DrawStateCopyWithImpl;
@override @useResult
$Res call({
 LoadStatus status, int myTickets, bool busy, DrawEntity? draw, DrawEntity? lastWinner, DrawTicketResult? purchase
});


@override $DrawEntityCopyWith<$Res>? get draw;@override $DrawEntityCopyWith<$Res>? get lastWinner;

}
/// @nodoc
class __$DrawStateCopyWithImpl<$Res>
    implements _$DrawStateCopyWith<$Res> {
  __$DrawStateCopyWithImpl(this._self, this._then);

  final _DrawState _self;
  final $Res Function(_DrawState) _then;

/// Create a copy of DrawState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? myTickets = null,Object? busy = null,Object? draw = freezed,Object? lastWinner = freezed,Object? purchase = freezed,}) {
  return _then(_DrawState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LoadStatus,myTickets: null == myTickets ? _self.myTickets : myTickets // ignore: cast_nullable_to_non_nullable
as int,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,draw: freezed == draw ? _self.draw : draw // ignore: cast_nullable_to_non_nullable
as DrawEntity?,lastWinner: freezed == lastWinner ? _self.lastWinner : lastWinner // ignore: cast_nullable_to_non_nullable
as DrawEntity?,purchase: freezed == purchase ? _self.purchase : purchase // ignore: cast_nullable_to_non_nullable
as DrawTicketResult?,
  ));
}

/// Create a copy of DrawState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DrawEntityCopyWith<$Res>? get draw {
    if (_self.draw == null) {
    return null;
  }

  return $DrawEntityCopyWith<$Res>(_self.draw!, (value) {
    return _then(_self.copyWith(draw: value));
  });
}/// Create a copy of DrawState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DrawEntityCopyWith<$Res>? get lastWinner {
    if (_self.lastWinner == null) {
    return null;
  }

  return $DrawEntityCopyWith<$Res>(_self.lastWinner!, (value) {
    return _then(_self.copyWith(lastWinner: value));
  });
}
}

// dart format on
