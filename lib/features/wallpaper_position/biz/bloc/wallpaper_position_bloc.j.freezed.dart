// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wallpaper_position_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WallpaperPositionEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WallpaperPositionEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'WallpaperPositionEvent()';
}


}

/// @nodoc
class $WallpaperPositionEventCopyWith<$Res>  {
$WallpaperPositionEventCopyWith(WallpaperPositionEvent _, $Res Function(WallpaperPositionEvent) __);
}


/// Adds pattern-matching-related methods to [WallpaperPositionEvent].
extension WallpaperPositionEventPatterns on WallpaperPositionEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _FitChanged value)?  fitChanged,TResult Function( _Moved value)?  moved,TResult Function( _DimChanged value)?  dimChanged,TResult Function( _PreviewModeChanged value)?  previewModeChanged,TResult Function( _ResetRequested value)?  resetRequested,TResult Function( _ApplyRequested value)?  applyRequested,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _FitChanged() when fitChanged != null:
return fitChanged(_that);case _Moved() when moved != null:
return moved(_that);case _DimChanged() when dimChanged != null:
return dimChanged(_that);case _PreviewModeChanged() when previewModeChanged != null:
return previewModeChanged(_that);case _ResetRequested() when resetRequested != null:
return resetRequested(_that);case _ApplyRequested() when applyRequested != null:
return applyRequested(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _FitChanged value)  fitChanged,required TResult Function( _Moved value)  moved,required TResult Function( _DimChanged value)  dimChanged,required TResult Function( _PreviewModeChanged value)  previewModeChanged,required TResult Function( _ResetRequested value)  resetRequested,required TResult Function( _ApplyRequested value)  applyRequested,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _FitChanged():
return fitChanged(_that);case _Moved():
return moved(_that);case _DimChanged():
return dimChanged(_that);case _PreviewModeChanged():
return previewModeChanged(_that);case _ResetRequested():
return resetRequested(_that);case _ApplyRequested():
return applyRequested(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _FitChanged value)?  fitChanged,TResult? Function( _Moved value)?  moved,TResult? Function( _DimChanged value)?  dimChanged,TResult? Function( _PreviewModeChanged value)?  previewModeChanged,TResult? Function( _ResetRequested value)?  resetRequested,TResult? Function( _ApplyRequested value)?  applyRequested,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _FitChanged() when fitChanged != null:
return fitChanged(_that);case _Moved() when moved != null:
return moved(_that);case _DimChanged() when dimChanged != null:
return dimChanged(_that);case _PreviewModeChanged() when previewModeChanged != null:
return previewModeChanged(_that);case _ResetRequested() when resetRequested != null:
return resetRequested(_that);case _ApplyRequested() when applyRequested != null:
return applyRequested(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String imageUrl,  String? thumbnailUrl,  String? entryPoint)?  started,TResult Function( PlacementFit fit)?  fitChanged,TResult Function( double dx,  double dy,  double zoom)?  moved,TResult Function( double dim)?  dimChanged,TResult Function( PlacementPreviewMode mode)?  previewModeChanged,TResult Function()?  resetRequested,TResult Function( WallpaperTarget target,  Size outputSize)?  applyRequested,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.imageUrl,_that.thumbnailUrl,_that.entryPoint);case _FitChanged() when fitChanged != null:
return fitChanged(_that.fit);case _Moved() when moved != null:
return moved(_that.dx,_that.dy,_that.zoom);case _DimChanged() when dimChanged != null:
return dimChanged(_that.dim);case _PreviewModeChanged() when previewModeChanged != null:
return previewModeChanged(_that.mode);case _ResetRequested() when resetRequested != null:
return resetRequested();case _ApplyRequested() when applyRequested != null:
return applyRequested(_that.target,_that.outputSize);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String imageUrl,  String? thumbnailUrl,  String? entryPoint)  started,required TResult Function( PlacementFit fit)  fitChanged,required TResult Function( double dx,  double dy,  double zoom)  moved,required TResult Function( double dim)  dimChanged,required TResult Function( PlacementPreviewMode mode)  previewModeChanged,required TResult Function()  resetRequested,required TResult Function( WallpaperTarget target,  Size outputSize)  applyRequested,}) {final _that = this;
switch (_that) {
case _Started():
return started(_that.imageUrl,_that.thumbnailUrl,_that.entryPoint);case _FitChanged():
return fitChanged(_that.fit);case _Moved():
return moved(_that.dx,_that.dy,_that.zoom);case _DimChanged():
return dimChanged(_that.dim);case _PreviewModeChanged():
return previewModeChanged(_that.mode);case _ResetRequested():
return resetRequested();case _ApplyRequested():
return applyRequested(_that.target,_that.outputSize);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String imageUrl,  String? thumbnailUrl,  String? entryPoint)?  started,TResult? Function( PlacementFit fit)?  fitChanged,TResult? Function( double dx,  double dy,  double zoom)?  moved,TResult? Function( double dim)?  dimChanged,TResult? Function( PlacementPreviewMode mode)?  previewModeChanged,TResult? Function()?  resetRequested,TResult? Function( WallpaperTarget target,  Size outputSize)?  applyRequested,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.imageUrl,_that.thumbnailUrl,_that.entryPoint);case _FitChanged() when fitChanged != null:
return fitChanged(_that.fit);case _Moved() when moved != null:
return moved(_that.dx,_that.dy,_that.zoom);case _DimChanged() when dimChanged != null:
return dimChanged(_that.dim);case _PreviewModeChanged() when previewModeChanged != null:
return previewModeChanged(_that.mode);case _ResetRequested() when resetRequested != null:
return resetRequested();case _ApplyRequested() when applyRequested != null:
return applyRequested(_that.target,_that.outputSize);case _:
  return null;

}
}

}

/// @nodoc


class _Started implements WallpaperPositionEvent {
  const _Started({required this.imageUrl, this.thumbnailUrl, this.entryPoint});
  

 final  String imageUrl;
 final  String? thumbnailUrl;
 final  String? entryPoint;

/// Create a copy of WallpaperPositionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StartedCopyWith<_Started> get copyWith => __$StartedCopyWithImpl<_Started>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.entryPoint, entryPoint) || other.entryPoint == entryPoint));
}


@override
int get hashCode => Object.hash(runtimeType,imageUrl,thumbnailUrl,entryPoint);

@override
String toString() {
  return 'WallpaperPositionEvent.started(imageUrl: $imageUrl, thumbnailUrl: $thumbnailUrl, entryPoint: $entryPoint)';
}


}

/// @nodoc
abstract mixin class _$StartedCopyWith<$Res> implements $WallpaperPositionEventCopyWith<$Res> {
  factory _$StartedCopyWith(_Started value, $Res Function(_Started) _then) = __$StartedCopyWithImpl;
@useResult
$Res call({
 String imageUrl, String? thumbnailUrl, String? entryPoint
});




}
/// @nodoc
class __$StartedCopyWithImpl<$Res>
    implements _$StartedCopyWith<$Res> {
  __$StartedCopyWithImpl(this._self, this._then);

  final _Started _self;
  final $Res Function(_Started) _then;

/// Create a copy of WallpaperPositionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? imageUrl = null,Object? thumbnailUrl = freezed,Object? entryPoint = freezed,}) {
  return _then(_Started(
imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,entryPoint: freezed == entryPoint ? _self.entryPoint : entryPoint // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class _FitChanged implements WallpaperPositionEvent {
  const _FitChanged(this.fit);
  

 final  PlacementFit fit;

/// Create a copy of WallpaperPositionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FitChangedCopyWith<_FitChanged> get copyWith => __$FitChangedCopyWithImpl<_FitChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FitChanged&&(identical(other.fit, fit) || other.fit == fit));
}


@override
int get hashCode => Object.hash(runtimeType,fit);

@override
String toString() {
  return 'WallpaperPositionEvent.fitChanged(fit: $fit)';
}


}

/// @nodoc
abstract mixin class _$FitChangedCopyWith<$Res> implements $WallpaperPositionEventCopyWith<$Res> {
  factory _$FitChangedCopyWith(_FitChanged value, $Res Function(_FitChanged) _then) = __$FitChangedCopyWithImpl;
@useResult
$Res call({
 PlacementFit fit
});




}
/// @nodoc
class __$FitChangedCopyWithImpl<$Res>
    implements _$FitChangedCopyWith<$Res> {
  __$FitChangedCopyWithImpl(this._self, this._then);

  final _FitChanged _self;
  final $Res Function(_FitChanged) _then;

/// Create a copy of WallpaperPositionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? fit = null,}) {
  return _then(_FitChanged(
null == fit ? _self.fit : fit // ignore: cast_nullable_to_non_nullable
as PlacementFit,
  ));
}


}

/// @nodoc


class _Moved implements WallpaperPositionEvent {
  const _Moved({required this.dx, required this.dy, required this.zoom});
  

 final  double dx;
 final  double dy;
 final  double zoom;

/// Create a copy of WallpaperPositionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MovedCopyWith<_Moved> get copyWith => __$MovedCopyWithImpl<_Moved>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Moved&&(identical(other.dx, dx) || other.dx == dx)&&(identical(other.dy, dy) || other.dy == dy)&&(identical(other.zoom, zoom) || other.zoom == zoom));
}


@override
int get hashCode => Object.hash(runtimeType,dx,dy,zoom);

@override
String toString() {
  return 'WallpaperPositionEvent.moved(dx: $dx, dy: $dy, zoom: $zoom)';
}


}

/// @nodoc
abstract mixin class _$MovedCopyWith<$Res> implements $WallpaperPositionEventCopyWith<$Res> {
  factory _$MovedCopyWith(_Moved value, $Res Function(_Moved) _then) = __$MovedCopyWithImpl;
@useResult
$Res call({
 double dx, double dy, double zoom
});




}
/// @nodoc
class __$MovedCopyWithImpl<$Res>
    implements _$MovedCopyWith<$Res> {
  __$MovedCopyWithImpl(this._self, this._then);

  final _Moved _self;
  final $Res Function(_Moved) _then;

/// Create a copy of WallpaperPositionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? dx = null,Object? dy = null,Object? zoom = null,}) {
  return _then(_Moved(
dx: null == dx ? _self.dx : dx // ignore: cast_nullable_to_non_nullable
as double,dy: null == dy ? _self.dy : dy // ignore: cast_nullable_to_non_nullable
as double,zoom: null == zoom ? _self.zoom : zoom // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class _DimChanged implements WallpaperPositionEvent {
  const _DimChanged(this.dim);
  

 final  double dim;

/// Create a copy of WallpaperPositionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DimChangedCopyWith<_DimChanged> get copyWith => __$DimChangedCopyWithImpl<_DimChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DimChanged&&(identical(other.dim, dim) || other.dim == dim));
}


@override
int get hashCode => Object.hash(runtimeType,dim);

@override
String toString() {
  return 'WallpaperPositionEvent.dimChanged(dim: $dim)';
}


}

/// @nodoc
abstract mixin class _$DimChangedCopyWith<$Res> implements $WallpaperPositionEventCopyWith<$Res> {
  factory _$DimChangedCopyWith(_DimChanged value, $Res Function(_DimChanged) _then) = __$DimChangedCopyWithImpl;
@useResult
$Res call({
 double dim
});




}
/// @nodoc
class __$DimChangedCopyWithImpl<$Res>
    implements _$DimChangedCopyWith<$Res> {
  __$DimChangedCopyWithImpl(this._self, this._then);

  final _DimChanged _self;
  final $Res Function(_DimChanged) _then;

/// Create a copy of WallpaperPositionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? dim = null,}) {
  return _then(_DimChanged(
null == dim ? _self.dim : dim // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class _PreviewModeChanged implements WallpaperPositionEvent {
  const _PreviewModeChanged(this.mode);
  

 final  PlacementPreviewMode mode;

/// Create a copy of WallpaperPositionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PreviewModeChangedCopyWith<_PreviewModeChanged> get copyWith => __$PreviewModeChangedCopyWithImpl<_PreviewModeChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PreviewModeChanged&&(identical(other.mode, mode) || other.mode == mode));
}


@override
int get hashCode => Object.hash(runtimeType,mode);

@override
String toString() {
  return 'WallpaperPositionEvent.previewModeChanged(mode: $mode)';
}


}

/// @nodoc
abstract mixin class _$PreviewModeChangedCopyWith<$Res> implements $WallpaperPositionEventCopyWith<$Res> {
  factory _$PreviewModeChangedCopyWith(_PreviewModeChanged value, $Res Function(_PreviewModeChanged) _then) = __$PreviewModeChangedCopyWithImpl;
@useResult
$Res call({
 PlacementPreviewMode mode
});




}
/// @nodoc
class __$PreviewModeChangedCopyWithImpl<$Res>
    implements _$PreviewModeChangedCopyWith<$Res> {
  __$PreviewModeChangedCopyWithImpl(this._self, this._then);

  final _PreviewModeChanged _self;
  final $Res Function(_PreviewModeChanged) _then;

/// Create a copy of WallpaperPositionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? mode = null,}) {
  return _then(_PreviewModeChanged(
null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as PlacementPreviewMode,
  ));
}


}

/// @nodoc


class _ResetRequested implements WallpaperPositionEvent {
  const _ResetRequested();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ResetRequested);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'WallpaperPositionEvent.resetRequested()';
}


}




/// @nodoc


class _ApplyRequested implements WallpaperPositionEvent {
  const _ApplyRequested({required this.target, required this.outputSize});
  

 final  WallpaperTarget target;
 final  Size outputSize;

/// Create a copy of WallpaperPositionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApplyRequestedCopyWith<_ApplyRequested> get copyWith => __$ApplyRequestedCopyWithImpl<_ApplyRequested>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApplyRequested&&(identical(other.target, target) || other.target == target)&&(identical(other.outputSize, outputSize) || other.outputSize == outputSize));
}


@override
int get hashCode => Object.hash(runtimeType,target,outputSize);

@override
String toString() {
  return 'WallpaperPositionEvent.applyRequested(target: $target, outputSize: $outputSize)';
}


}

/// @nodoc
abstract mixin class _$ApplyRequestedCopyWith<$Res> implements $WallpaperPositionEventCopyWith<$Res> {
  factory _$ApplyRequestedCopyWith(_ApplyRequested value, $Res Function(_ApplyRequested) _then) = __$ApplyRequestedCopyWithImpl;
@useResult
$Res call({
 WallpaperTarget target, Size outputSize
});




}
/// @nodoc
class __$ApplyRequestedCopyWithImpl<$Res>
    implements _$ApplyRequestedCopyWith<$Res> {
  __$ApplyRequestedCopyWithImpl(this._self, this._then);

  final _ApplyRequested _self;
  final $Res Function(_ApplyRequested) _then;

/// Create a copy of WallpaperPositionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? target = null,Object? outputSize = null,}) {
  return _then(_ApplyRequested(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as WallpaperTarget,outputSize: null == outputSize ? _self.outputSize : outputSize // ignore: cast_nullable_to_non_nullable
as Size,
  ));
}


}

/// @nodoc
mixin _$WallpaperPositionState {

 WallpaperPositionStatus get status; WallpaperPlacement get placement; PlacementSource? get source;/// Counts resets and fit changes, so the preview moves its gesture state to the placement again.
 int get syncToken;/// What the last apply returned. Read it when [resultToken] changes.
 WallpaperSetResult? get result; int get resultToken;
/// Create a copy of WallpaperPositionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WallpaperPositionStateCopyWith<WallpaperPositionState> get copyWith => _$WallpaperPositionStateCopyWithImpl<WallpaperPositionState>(this as WallpaperPositionState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WallpaperPositionState&&(identical(other.status, status) || other.status == status)&&(identical(other.placement, placement) || other.placement == placement)&&(identical(other.source, source) || other.source == source)&&(identical(other.syncToken, syncToken) || other.syncToken == syncToken)&&(identical(other.result, result) || other.result == result)&&(identical(other.resultToken, resultToken) || other.resultToken == resultToken));
}


@override
int get hashCode => Object.hash(runtimeType,status,placement,source,syncToken,result,resultToken);

@override
String toString() {
  return 'WallpaperPositionState(status: $status, placement: $placement, source: $source, syncToken: $syncToken, result: $result, resultToken: $resultToken)';
}


}

/// @nodoc
abstract mixin class $WallpaperPositionStateCopyWith<$Res>  {
  factory $WallpaperPositionStateCopyWith(WallpaperPositionState value, $Res Function(WallpaperPositionState) _then) = _$WallpaperPositionStateCopyWithImpl;
@useResult
$Res call({
 WallpaperPositionStatus status, WallpaperPlacement placement, PlacementSource? source, int syncToken, WallpaperSetResult? result, int resultToken
});




}
/// @nodoc
class _$WallpaperPositionStateCopyWithImpl<$Res>
    implements $WallpaperPositionStateCopyWith<$Res> {
  _$WallpaperPositionStateCopyWithImpl(this._self, this._then);

  final WallpaperPositionState _self;
  final $Res Function(WallpaperPositionState) _then;

/// Create a copy of WallpaperPositionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? placement = null,Object? source = freezed,Object? syncToken = null,Object? result = freezed,Object? resultToken = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as WallpaperPositionStatus,placement: null == placement ? _self.placement : placement // ignore: cast_nullable_to_non_nullable
as WallpaperPlacement,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as PlacementSource?,syncToken: null == syncToken ? _self.syncToken : syncToken // ignore: cast_nullable_to_non_nullable
as int,result: freezed == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as WallpaperSetResult?,resultToken: null == resultToken ? _self.resultToken : resultToken // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [WallpaperPositionState].
extension WallpaperPositionStatePatterns on WallpaperPositionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WallpaperPositionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WallpaperPositionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WallpaperPositionState value)  $default,){
final _that = this;
switch (_that) {
case _WallpaperPositionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WallpaperPositionState value)?  $default,){
final _that = this;
switch (_that) {
case _WallpaperPositionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WallpaperPositionStatus status,  WallpaperPlacement placement,  PlacementSource? source,  int syncToken,  WallpaperSetResult? result,  int resultToken)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WallpaperPositionState() when $default != null:
return $default(_that.status,_that.placement,_that.source,_that.syncToken,_that.result,_that.resultToken);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WallpaperPositionStatus status,  WallpaperPlacement placement,  PlacementSource? source,  int syncToken,  WallpaperSetResult? result,  int resultToken)  $default,) {final _that = this;
switch (_that) {
case _WallpaperPositionState():
return $default(_that.status,_that.placement,_that.source,_that.syncToken,_that.result,_that.resultToken);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WallpaperPositionStatus status,  WallpaperPlacement placement,  PlacementSource? source,  int syncToken,  WallpaperSetResult? result,  int resultToken)?  $default,) {final _that = this;
switch (_that) {
case _WallpaperPositionState() when $default != null:
return $default(_that.status,_that.placement,_that.source,_that.syncToken,_that.result,_that.resultToken);case _:
  return null;

}
}

}

/// @nodoc


class _WallpaperPositionState implements WallpaperPositionState {
  const _WallpaperPositionState({required this.status, required this.placement, this.source, this.syncToken = 0, this.result, this.resultToken = 0});
  

@override final  WallpaperPositionStatus status;
@override final  WallpaperPlacement placement;
@override final  PlacementSource? source;
/// Counts resets and fit changes, so the preview moves its gesture state to the placement again.
@override@JsonKey() final  int syncToken;
/// What the last apply returned. Read it when [resultToken] changes.
@override final  WallpaperSetResult? result;
@override@JsonKey() final  int resultToken;

/// Create a copy of WallpaperPositionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WallpaperPositionStateCopyWith<_WallpaperPositionState> get copyWith => __$WallpaperPositionStateCopyWithImpl<_WallpaperPositionState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WallpaperPositionState&&(identical(other.status, status) || other.status == status)&&(identical(other.placement, placement) || other.placement == placement)&&(identical(other.source, source) || other.source == source)&&(identical(other.syncToken, syncToken) || other.syncToken == syncToken)&&(identical(other.result, result) || other.result == result)&&(identical(other.resultToken, resultToken) || other.resultToken == resultToken));
}


@override
int get hashCode => Object.hash(runtimeType,status,placement,source,syncToken,result,resultToken);

@override
String toString() {
  return 'WallpaperPositionState(status: $status, placement: $placement, source: $source, syncToken: $syncToken, result: $result, resultToken: $resultToken)';
}


}

/// @nodoc
abstract mixin class _$WallpaperPositionStateCopyWith<$Res> implements $WallpaperPositionStateCopyWith<$Res> {
  factory _$WallpaperPositionStateCopyWith(_WallpaperPositionState value, $Res Function(_WallpaperPositionState) _then) = __$WallpaperPositionStateCopyWithImpl;
@override @useResult
$Res call({
 WallpaperPositionStatus status, WallpaperPlacement placement, PlacementSource? source, int syncToken, WallpaperSetResult? result, int resultToken
});




}
/// @nodoc
class __$WallpaperPositionStateCopyWithImpl<$Res>
    implements _$WallpaperPositionStateCopyWith<$Res> {
  __$WallpaperPositionStateCopyWithImpl(this._self, this._then);

  final _WallpaperPositionState _self;
  final $Res Function(_WallpaperPositionState) _then;

/// Create a copy of WallpaperPositionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? placement = null,Object? source = freezed,Object? syncToken = null,Object? result = freezed,Object? resultToken = null,}) {
  return _then(_WallpaperPositionState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as WallpaperPositionStatus,placement: null == placement ? _self.placement : placement // ignore: cast_nullable_to_non_nullable
as WallpaperPlacement,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as PlacementSource?,syncToken: null == syncToken ? _self.syncToken : syncToken // ignore: cast_nullable_to_non_nullable
as int,result: freezed == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as WallpaperSetResult?,resultToken: null == resultToken ? _self.resultToken : resultToken // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
