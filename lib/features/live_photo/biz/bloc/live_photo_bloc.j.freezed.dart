// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_photo_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LivePhotoEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LivePhotoEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LivePhotoEvent()';
}


}

/// @nodoc
class $LivePhotoEventCopyWith<$Res>  {
$LivePhotoEventCopyWith(LivePhotoEvent _, $Res Function(LivePhotoEvent) __);
}


/// Adds pattern-matching-related methods to [LivePhotoEvent].
extension LivePhotoEventPatterns on LivePhotoEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _StyleSelected value)?  styleSelected,TResult Function( _AccessChanged value)?  accessChanged,TResult Function( _ExportRequested value)?  exportRequested,TResult Function( _Progressed value)?  progressed,TResult Function( _CancelRequested value)?  cancelRequested,TResult Function( _Reset value)?  reset,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StyleSelected() when styleSelected != null:
return styleSelected(_that);case _AccessChanged() when accessChanged != null:
return accessChanged(_that);case _ExportRequested() when exportRequested != null:
return exportRequested(_that);case _Progressed() when progressed != null:
return progressed(_that);case _CancelRequested() when cancelRequested != null:
return cancelRequested(_that);case _Reset() when reset != null:
return reset(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _StyleSelected value)  styleSelected,required TResult Function( _AccessChanged value)  accessChanged,required TResult Function( _ExportRequested value)  exportRequested,required TResult Function( _Progressed value)  progressed,required TResult Function( _CancelRequested value)  cancelRequested,required TResult Function( _Reset value)  reset,}){
final _that = this;
switch (_that) {
case _StyleSelected():
return styleSelected(_that);case _AccessChanged():
return accessChanged(_that);case _ExportRequested():
return exportRequested(_that);case _Progressed():
return progressed(_that);case _CancelRequested():
return cancelRequested(_that);case _Reset():
return reset(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _StyleSelected value)?  styleSelected,TResult? Function( _AccessChanged value)?  accessChanged,TResult? Function( _ExportRequested value)?  exportRequested,TResult? Function( _Progressed value)?  progressed,TResult? Function( _CancelRequested value)?  cancelRequested,TResult? Function( _Reset value)?  reset,}){
final _that = this;
switch (_that) {
case _StyleSelected() when styleSelected != null:
return styleSelected(_that);case _AccessChanged() when accessChanged != null:
return accessChanged(_that);case _ExportRequested() when exportRequested != null:
return exportRequested(_that);case _Progressed() when progressed != null:
return progressed(_that);case _CancelRequested() when cancelRequested != null:
return cancelRequested(_that);case _Reset() when reset != null:
return reset(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( MotionStyle style)?  styleSelected,TResult Function( bool isPro,  Map<String, DateTime> unlockedStyles)?  accessChanged,TResult Function( Size sizePx,  Color tint)?  exportRequested,TResult Function( double fraction)?  progressed,TResult Function()?  cancelRequested,TResult Function()?  reset,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StyleSelected() when styleSelected != null:
return styleSelected(_that.style);case _AccessChanged() when accessChanged != null:
return accessChanged(_that.isPro,_that.unlockedStyles);case _ExportRequested() when exportRequested != null:
return exportRequested(_that.sizePx,_that.tint);case _Progressed() when progressed != null:
return progressed(_that.fraction);case _CancelRequested() when cancelRequested != null:
return cancelRequested();case _Reset() when reset != null:
return reset();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( MotionStyle style)  styleSelected,required TResult Function( bool isPro,  Map<String, DateTime> unlockedStyles)  accessChanged,required TResult Function( Size sizePx,  Color tint)  exportRequested,required TResult Function( double fraction)  progressed,required TResult Function()  cancelRequested,required TResult Function()  reset,}) {final _that = this;
switch (_that) {
case _StyleSelected():
return styleSelected(_that.style);case _AccessChanged():
return accessChanged(_that.isPro,_that.unlockedStyles);case _ExportRequested():
return exportRequested(_that.sizePx,_that.tint);case _Progressed():
return progressed(_that.fraction);case _CancelRequested():
return cancelRequested();case _Reset():
return reset();case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( MotionStyle style)?  styleSelected,TResult? Function( bool isPro,  Map<String, DateTime> unlockedStyles)?  accessChanged,TResult? Function( Size sizePx,  Color tint)?  exportRequested,TResult? Function( double fraction)?  progressed,TResult? Function()?  cancelRequested,TResult? Function()?  reset,}) {final _that = this;
switch (_that) {
case _StyleSelected() when styleSelected != null:
return styleSelected(_that.style);case _AccessChanged() when accessChanged != null:
return accessChanged(_that.isPro,_that.unlockedStyles);case _ExportRequested() when exportRequested != null:
return exportRequested(_that.sizePx,_that.tint);case _Progressed() when progressed != null:
return progressed(_that.fraction);case _CancelRequested() when cancelRequested != null:
return cancelRequested();case _Reset() when reset != null:
return reset();case _:
  return null;

}
}

}

/// @nodoc


class _StyleSelected implements LivePhotoEvent {
  const _StyleSelected(this.style);
  

 final  MotionStyle style;

/// Create a copy of LivePhotoEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StyleSelectedCopyWith<_StyleSelected> get copyWith => __$StyleSelectedCopyWithImpl<_StyleSelected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StyleSelected&&(identical(other.style, style) || other.style == style));
}


@override
int get hashCode => Object.hash(runtimeType,style);

@override
String toString() {
  return 'LivePhotoEvent.styleSelected(style: $style)';
}


}

/// @nodoc
abstract mixin class _$StyleSelectedCopyWith<$Res> implements $LivePhotoEventCopyWith<$Res> {
  factory _$StyleSelectedCopyWith(_StyleSelected value, $Res Function(_StyleSelected) _then) = __$StyleSelectedCopyWithImpl;
@useResult
$Res call({
 MotionStyle style
});




}
/// @nodoc
class __$StyleSelectedCopyWithImpl<$Res>
    implements _$StyleSelectedCopyWith<$Res> {
  __$StyleSelectedCopyWithImpl(this._self, this._then);

  final _StyleSelected _self;
  final $Res Function(_StyleSelected) _then;

/// Create a copy of LivePhotoEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? style = null,}) {
  return _then(_StyleSelected(
null == style ? _self.style : style // ignore: cast_nullable_to_non_nullable
as MotionStyle,
  ));
}


}

/// @nodoc


class _AccessChanged implements LivePhotoEvent {
  const _AccessChanged({required this.isPro, required final  Map<String, DateTime> unlockedStyles}): _unlockedStyles = unlockedStyles;
  

 final  bool isPro;
 final  Map<String, DateTime> _unlockedStyles;
 Map<String, DateTime> get unlockedStyles {
  if (_unlockedStyles is EqualUnmodifiableMapView) return _unlockedStyles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_unlockedStyles);
}


/// Create a copy of LivePhotoEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccessChangedCopyWith<_AccessChanged> get copyWith => __$AccessChangedCopyWithImpl<_AccessChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccessChanged&&(identical(other.isPro, isPro) || other.isPro == isPro)&&const DeepCollectionEquality().equals(other._unlockedStyles, _unlockedStyles));
}


@override
int get hashCode => Object.hash(runtimeType,isPro,const DeepCollectionEquality().hash(_unlockedStyles));

@override
String toString() {
  return 'LivePhotoEvent.accessChanged(isPro: $isPro, unlockedStyles: $unlockedStyles)';
}


}

/// @nodoc
abstract mixin class _$AccessChangedCopyWith<$Res> implements $LivePhotoEventCopyWith<$Res> {
  factory _$AccessChangedCopyWith(_AccessChanged value, $Res Function(_AccessChanged) _then) = __$AccessChangedCopyWithImpl;
@useResult
$Res call({
 bool isPro, Map<String, DateTime> unlockedStyles
});




}
/// @nodoc
class __$AccessChangedCopyWithImpl<$Res>
    implements _$AccessChangedCopyWith<$Res> {
  __$AccessChangedCopyWithImpl(this._self, this._then);

  final _AccessChanged _self;
  final $Res Function(_AccessChanged) _then;

/// Create a copy of LivePhotoEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? isPro = null,Object? unlockedStyles = null,}) {
  return _then(_AccessChanged(
isPro: null == isPro ? _self.isPro : isPro // ignore: cast_nullable_to_non_nullable
as bool,unlockedStyles: null == unlockedStyles ? _self._unlockedStyles : unlockedStyles // ignore: cast_nullable_to_non_nullable
as Map<String, DateTime>,
  ));
}


}

/// @nodoc


class _ExportRequested implements LivePhotoEvent {
  const _ExportRequested({required this.sizePx, required this.tint});
  

 final  Size sizePx;
 final  Color tint;

/// Create a copy of LivePhotoEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExportRequestedCopyWith<_ExportRequested> get copyWith => __$ExportRequestedCopyWithImpl<_ExportRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExportRequested&&(identical(other.sizePx, sizePx) || other.sizePx == sizePx)&&(identical(other.tint, tint) || other.tint == tint));
}


@override
int get hashCode => Object.hash(runtimeType,sizePx,tint);

@override
String toString() {
  return 'LivePhotoEvent.exportRequested(sizePx: $sizePx, tint: $tint)';
}


}

/// @nodoc
abstract mixin class _$ExportRequestedCopyWith<$Res> implements $LivePhotoEventCopyWith<$Res> {
  factory _$ExportRequestedCopyWith(_ExportRequested value, $Res Function(_ExportRequested) _then) = __$ExportRequestedCopyWithImpl;
@useResult
$Res call({
 Size sizePx, Color tint
});




}
/// @nodoc
class __$ExportRequestedCopyWithImpl<$Res>
    implements _$ExportRequestedCopyWith<$Res> {
  __$ExportRequestedCopyWithImpl(this._self, this._then);

  final _ExportRequested _self;
  final $Res Function(_ExportRequested) _then;

/// Create a copy of LivePhotoEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sizePx = null,Object? tint = null,}) {
  return _then(_ExportRequested(
sizePx: null == sizePx ? _self.sizePx : sizePx // ignore: cast_nullable_to_non_nullable
as Size,tint: null == tint ? _self.tint : tint // ignore: cast_nullable_to_non_nullable
as Color,
  ));
}


}

/// @nodoc


class _Progressed implements LivePhotoEvent {
  const _Progressed(this.fraction);
  

 final  double fraction;

/// Create a copy of LivePhotoEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProgressedCopyWith<_Progressed> get copyWith => __$ProgressedCopyWithImpl<_Progressed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Progressed&&(identical(other.fraction, fraction) || other.fraction == fraction));
}


@override
int get hashCode => Object.hash(runtimeType,fraction);

@override
String toString() {
  return 'LivePhotoEvent.progressed(fraction: $fraction)';
}


}

/// @nodoc
abstract mixin class _$ProgressedCopyWith<$Res> implements $LivePhotoEventCopyWith<$Res> {
  factory _$ProgressedCopyWith(_Progressed value, $Res Function(_Progressed) _then) = __$ProgressedCopyWithImpl;
@useResult
$Res call({
 double fraction
});




}
/// @nodoc
class __$ProgressedCopyWithImpl<$Res>
    implements _$ProgressedCopyWith<$Res> {
  __$ProgressedCopyWithImpl(this._self, this._then);

  final _Progressed _self;
  final $Res Function(_Progressed) _then;

/// Create a copy of LivePhotoEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? fraction = null,}) {
  return _then(_Progressed(
null == fraction ? _self.fraction : fraction // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class _CancelRequested implements LivePhotoEvent {
  const _CancelRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CancelRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LivePhotoEvent.cancelRequested()';
}


}




/// @nodoc


class _Reset implements LivePhotoEvent {
  const _Reset();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Reset);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LivePhotoEvent.reset()';
}


}




/// @nodoc
mixin _$LivePhotoState {

 LivePhotoPhase get phase; List<MotionStyle> get styles; MotionStyle get style; bool get isPro;/// Paid style id to the end of its coin unlock, as the server stored it.
 Map<String, DateTime> get unlockedStyles; double get progress; bool get cancelling; LiveExportOutcome? get outcome;
/// Create a copy of LivePhotoState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LivePhotoStateCopyWith<LivePhotoState> get copyWith => _$LivePhotoStateCopyWithImpl<LivePhotoState>(this as LivePhotoState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LivePhotoState&&(identical(other.phase, phase) || other.phase == phase)&&const DeepCollectionEquality().equals(other.styles, styles)&&(identical(other.style, style) || other.style == style)&&(identical(other.isPro, isPro) || other.isPro == isPro)&&const DeepCollectionEquality().equals(other.unlockedStyles, unlockedStyles)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.cancelling, cancelling) || other.cancelling == cancelling)&&(identical(other.outcome, outcome) || other.outcome == outcome));
}


@override
int get hashCode => Object.hash(runtimeType,phase,const DeepCollectionEquality().hash(styles),style,isPro,const DeepCollectionEquality().hash(unlockedStyles),progress,cancelling,outcome);

@override
String toString() {
  return 'LivePhotoState(phase: $phase, styles: $styles, style: $style, isPro: $isPro, unlockedStyles: $unlockedStyles, progress: $progress, cancelling: $cancelling, outcome: $outcome)';
}


}

/// @nodoc
abstract mixin class $LivePhotoStateCopyWith<$Res>  {
  factory $LivePhotoStateCopyWith(LivePhotoState value, $Res Function(LivePhotoState) _then) = _$LivePhotoStateCopyWithImpl;
@useResult
$Res call({
 LivePhotoPhase phase, List<MotionStyle> styles, MotionStyle style, bool isPro, Map<String, DateTime> unlockedStyles, double progress, bool cancelling, LiveExportOutcome? outcome
});




}
/// @nodoc
class _$LivePhotoStateCopyWithImpl<$Res>
    implements $LivePhotoStateCopyWith<$Res> {
  _$LivePhotoStateCopyWithImpl(this._self, this._then);

  final LivePhotoState _self;
  final $Res Function(LivePhotoState) _then;

/// Create a copy of LivePhotoState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? phase = null,Object? styles = null,Object? style = null,Object? isPro = null,Object? unlockedStyles = null,Object? progress = null,Object? cancelling = null,Object? outcome = freezed,}) {
  return _then(_self.copyWith(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as LivePhotoPhase,styles: null == styles ? _self.styles : styles // ignore: cast_nullable_to_non_nullable
as List<MotionStyle>,style: null == style ? _self.style : style // ignore: cast_nullable_to_non_nullable
as MotionStyle,isPro: null == isPro ? _self.isPro : isPro // ignore: cast_nullable_to_non_nullable
as bool,unlockedStyles: null == unlockedStyles ? _self.unlockedStyles : unlockedStyles // ignore: cast_nullable_to_non_nullable
as Map<String, DateTime>,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,cancelling: null == cancelling ? _self.cancelling : cancelling // ignore: cast_nullable_to_non_nullable
as bool,outcome: freezed == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as LiveExportOutcome?,
  ));
}

}


/// Adds pattern-matching-related methods to [LivePhotoState].
extension LivePhotoStatePatterns on LivePhotoState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LivePhotoState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LivePhotoState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LivePhotoState value)  $default,){
final _that = this;
switch (_that) {
case _LivePhotoState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LivePhotoState value)?  $default,){
final _that = this;
switch (_that) {
case _LivePhotoState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LivePhotoPhase phase,  List<MotionStyle> styles,  MotionStyle style,  bool isPro,  Map<String, DateTime> unlockedStyles,  double progress,  bool cancelling,  LiveExportOutcome? outcome)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LivePhotoState() when $default != null:
return $default(_that.phase,_that.styles,_that.style,_that.isPro,_that.unlockedStyles,_that.progress,_that.cancelling,_that.outcome);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LivePhotoPhase phase,  List<MotionStyle> styles,  MotionStyle style,  bool isPro,  Map<String, DateTime> unlockedStyles,  double progress,  bool cancelling,  LiveExportOutcome? outcome)  $default,) {final _that = this;
switch (_that) {
case _LivePhotoState():
return $default(_that.phase,_that.styles,_that.style,_that.isPro,_that.unlockedStyles,_that.progress,_that.cancelling,_that.outcome);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LivePhotoPhase phase,  List<MotionStyle> styles,  MotionStyle style,  bool isPro,  Map<String, DateTime> unlockedStyles,  double progress,  bool cancelling,  LiveExportOutcome? outcome)?  $default,) {final _that = this;
switch (_that) {
case _LivePhotoState() when $default != null:
return $default(_that.phase,_that.styles,_that.style,_that.isPro,_that.unlockedStyles,_that.progress,_that.cancelling,_that.outcome);case _:
  return null;

}
}

}

/// @nodoc


class _LivePhotoState implements LivePhotoState {
  const _LivePhotoState({required this.phase, required final  List<MotionStyle> styles, required this.style, required this.isPro, final  Map<String, DateTime> unlockedStyles = const <String, DateTime>{}, this.progress = 0, this.cancelling = false, this.outcome}): _styles = styles,_unlockedStyles = unlockedStyles;
  

@override final  LivePhotoPhase phase;
 final  List<MotionStyle> _styles;
@override List<MotionStyle> get styles {
  if (_styles is EqualUnmodifiableListView) return _styles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_styles);
}

@override final  MotionStyle style;
@override final  bool isPro;
/// Paid style id to the end of its coin unlock, as the server stored it.
 final  Map<String, DateTime> _unlockedStyles;
/// Paid style id to the end of its coin unlock, as the server stored it.
@override@JsonKey() Map<String, DateTime> get unlockedStyles {
  if (_unlockedStyles is EqualUnmodifiableMapView) return _unlockedStyles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_unlockedStyles);
}

@override@JsonKey() final  double progress;
@override@JsonKey() final  bool cancelling;
@override final  LiveExportOutcome? outcome;

/// Create a copy of LivePhotoState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LivePhotoStateCopyWith<_LivePhotoState> get copyWith => __$LivePhotoStateCopyWithImpl<_LivePhotoState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LivePhotoState&&(identical(other.phase, phase) || other.phase == phase)&&const DeepCollectionEquality().equals(other._styles, _styles)&&(identical(other.style, style) || other.style == style)&&(identical(other.isPro, isPro) || other.isPro == isPro)&&const DeepCollectionEquality().equals(other._unlockedStyles, _unlockedStyles)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.cancelling, cancelling) || other.cancelling == cancelling)&&(identical(other.outcome, outcome) || other.outcome == outcome));
}


@override
int get hashCode => Object.hash(runtimeType,phase,const DeepCollectionEquality().hash(_styles),style,isPro,const DeepCollectionEquality().hash(_unlockedStyles),progress,cancelling,outcome);

@override
String toString() {
  return 'LivePhotoState(phase: $phase, styles: $styles, style: $style, isPro: $isPro, unlockedStyles: $unlockedStyles, progress: $progress, cancelling: $cancelling, outcome: $outcome)';
}


}

/// @nodoc
abstract mixin class _$LivePhotoStateCopyWith<$Res> implements $LivePhotoStateCopyWith<$Res> {
  factory _$LivePhotoStateCopyWith(_LivePhotoState value, $Res Function(_LivePhotoState) _then) = __$LivePhotoStateCopyWithImpl;
@override @useResult
$Res call({
 LivePhotoPhase phase, List<MotionStyle> styles, MotionStyle style, bool isPro, Map<String, DateTime> unlockedStyles, double progress, bool cancelling, LiveExportOutcome? outcome
});




}
/// @nodoc
class __$LivePhotoStateCopyWithImpl<$Res>
    implements _$LivePhotoStateCopyWith<$Res> {
  __$LivePhotoStateCopyWithImpl(this._self, this._then);

  final _LivePhotoState _self;
  final $Res Function(_LivePhotoState) _then;

/// Create a copy of LivePhotoState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? phase = null,Object? styles = null,Object? style = null,Object? isPro = null,Object? unlockedStyles = null,Object? progress = null,Object? cancelling = null,Object? outcome = freezed,}) {
  return _then(_LivePhotoState(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as LivePhotoPhase,styles: null == styles ? _self._styles : styles // ignore: cast_nullable_to_non_nullable
as List<MotionStyle>,style: null == style ? _self.style : style // ignore: cast_nullable_to_non_nullable
as MotionStyle,isPro: null == isPro ? _self.isPro : isPro // ignore: cast_nullable_to_non_nullable
as bool,unlockedStyles: null == unlockedStyles ? _self._unlockedStyles : unlockedStyles // ignore: cast_nullable_to_non_nullable
as Map<String, DateTime>,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,cancelling: null == cancelling ? _self.cancelling : cancelling // ignore: cast_nullable_to_non_nullable
as bool,outcome: freezed == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as LiveExportOutcome?,
  ));
}


}

// dart format on
