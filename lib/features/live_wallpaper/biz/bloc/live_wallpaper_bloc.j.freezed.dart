// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_wallpaper_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LiveWallpaperEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveWallpaperEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LiveWallpaperEvent()';
}


}

/// @nodoc
class $LiveWallpaperEventCopyWith<$Res>  {
$LiveWallpaperEventCopyWith(LiveWallpaperEvent _, $Res Function(LiveWallpaperEvent) __);
}


/// Adds pattern-matching-related methods to [LiveWallpaperEvent].
extension LiveWallpaperEventPatterns on LiveWallpaperEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _Started value)?  started,TResult Function( _ProChanged value)?  proChanged,TResult Function( _MotionSelected value)?  motionSelected,TResult Function( _GradientSelected value)?  gradientSelected,TResult Function( _BatterySaverChanged value)?  batterySaverChanged,TResult Function( _MotionApplied value)?  motionApplied,TResult Function( _GradientApplied value)?  gradientApplied,TResult Function( _VideoPicked value)?  videoPicked,TResult Function( _VideoApplied value)?  videoApplied,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _ProChanged() when proChanged != null:
return proChanged(_that);case _MotionSelected() when motionSelected != null:
return motionSelected(_that);case _GradientSelected() when gradientSelected != null:
return gradientSelected(_that);case _BatterySaverChanged() when batterySaverChanged != null:
return batterySaverChanged(_that);case _MotionApplied() when motionApplied != null:
return motionApplied(_that);case _GradientApplied() when gradientApplied != null:
return gradientApplied(_that);case _VideoPicked() when videoPicked != null:
return videoPicked(_that);case _VideoApplied() when videoApplied != null:
return videoApplied(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _Started value)  started,required TResult Function( _ProChanged value)  proChanged,required TResult Function( _MotionSelected value)  motionSelected,required TResult Function( _GradientSelected value)  gradientSelected,required TResult Function( _BatterySaverChanged value)  batterySaverChanged,required TResult Function( _MotionApplied value)  motionApplied,required TResult Function( _GradientApplied value)  gradientApplied,required TResult Function( _VideoPicked value)  videoPicked,required TResult Function( _VideoApplied value)  videoApplied,}){
final _that = this;
switch (_that) {
case _Started():
return started(_that);case _ProChanged():
return proChanged(_that);case _MotionSelected():
return motionSelected(_that);case _GradientSelected():
return gradientSelected(_that);case _BatterySaverChanged():
return batterySaverChanged(_that);case _MotionApplied():
return motionApplied(_that);case _GradientApplied():
return gradientApplied(_that);case _VideoPicked():
return videoPicked(_that);case _VideoApplied():
return videoApplied(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _Started value)?  started,TResult? Function( _ProChanged value)?  proChanged,TResult? Function( _MotionSelected value)?  motionSelected,TResult? Function( _GradientSelected value)?  gradientSelected,TResult? Function( _BatterySaverChanged value)?  batterySaverChanged,TResult? Function( _MotionApplied value)?  motionApplied,TResult? Function( _GradientApplied value)?  gradientApplied,TResult? Function( _VideoPicked value)?  videoPicked,TResult? Function( _VideoApplied value)?  videoApplied,}){
final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that);case _ProChanged() when proChanged != null:
return proChanged(_that);case _MotionSelected() when motionSelected != null:
return motionSelected(_that);case _GradientSelected() when gradientSelected != null:
return gradientSelected(_that);case _BatterySaverChanged() when batterySaverChanged != null:
return batterySaverChanged(_that);case _MotionApplied() when motionApplied != null:
return motionApplied(_that);case _GradientApplied() when gradientApplied != null:
return gradientApplied(_that);case _VideoPicked() when videoPicked != null:
return videoPicked(_that);case _VideoApplied() when videoApplied != null:
return videoApplied(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( bool isPro)?  started,TResult Function( bool isPro)?  proChanged,TResult Function( MotionStyle style)?  motionSelected,TResult Function( GradientStyle style)?  gradientSelected,TResult Function( bool enabled)?  batterySaverChanged,TResult Function( LivePalette palette,  double screenAspectRatio)?  motionApplied,TResult Function( LivePalette palette)?  gradientApplied,TResult Function( String path)?  videoPicked,TResult Function()?  videoApplied,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.isPro);case _ProChanged() when proChanged != null:
return proChanged(_that.isPro);case _MotionSelected() when motionSelected != null:
return motionSelected(_that.style);case _GradientSelected() when gradientSelected != null:
return gradientSelected(_that.style);case _BatterySaverChanged() when batterySaverChanged != null:
return batterySaverChanged(_that.enabled);case _MotionApplied() when motionApplied != null:
return motionApplied(_that.palette,_that.screenAspectRatio);case _GradientApplied() when gradientApplied != null:
return gradientApplied(_that.palette);case _VideoPicked() when videoPicked != null:
return videoPicked(_that.path);case _VideoApplied() when videoApplied != null:
return videoApplied();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( bool isPro)  started,required TResult Function( bool isPro)  proChanged,required TResult Function( MotionStyle style)  motionSelected,required TResult Function( GradientStyle style)  gradientSelected,required TResult Function( bool enabled)  batterySaverChanged,required TResult Function( LivePalette palette,  double screenAspectRatio)  motionApplied,required TResult Function( LivePalette palette)  gradientApplied,required TResult Function( String path)  videoPicked,required TResult Function()  videoApplied,}) {final _that = this;
switch (_that) {
case _Started():
return started(_that.isPro);case _ProChanged():
return proChanged(_that.isPro);case _MotionSelected():
return motionSelected(_that.style);case _GradientSelected():
return gradientSelected(_that.style);case _BatterySaverChanged():
return batterySaverChanged(_that.enabled);case _MotionApplied():
return motionApplied(_that.palette,_that.screenAspectRatio);case _GradientApplied():
return gradientApplied(_that.palette);case _VideoPicked():
return videoPicked(_that.path);case _VideoApplied():
return videoApplied();case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( bool isPro)?  started,TResult? Function( bool isPro)?  proChanged,TResult? Function( MotionStyle style)?  motionSelected,TResult? Function( GradientStyle style)?  gradientSelected,TResult? Function( bool enabled)?  batterySaverChanged,TResult? Function( LivePalette palette,  double screenAspectRatio)?  motionApplied,TResult? Function( LivePalette palette)?  gradientApplied,TResult? Function( String path)?  videoPicked,TResult? Function()?  videoApplied,}) {final _that = this;
switch (_that) {
case _Started() when started != null:
return started(_that.isPro);case _ProChanged() when proChanged != null:
return proChanged(_that.isPro);case _MotionSelected() when motionSelected != null:
return motionSelected(_that.style);case _GradientSelected() when gradientSelected != null:
return gradientSelected(_that.style);case _BatterySaverChanged() when batterySaverChanged != null:
return batterySaverChanged(_that.enabled);case _MotionApplied() when motionApplied != null:
return motionApplied(_that.palette,_that.screenAspectRatio);case _GradientApplied() when gradientApplied != null:
return gradientApplied(_that.palette);case _VideoPicked() when videoPicked != null:
return videoPicked(_that.path);case _VideoApplied() when videoApplied != null:
return videoApplied();case _:
  return null;

}
}

}

/// @nodoc


class _Started implements LiveWallpaperEvent {
  const _Started({required this.isPro});
  

 final  bool isPro;

/// Create a copy of LiveWallpaperEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StartedCopyWith<_Started> get copyWith => __$StartedCopyWithImpl<_Started>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Started&&(identical(other.isPro, isPro) || other.isPro == isPro));
}


@override
int get hashCode => Object.hash(runtimeType,isPro);

@override
String toString() {
  return 'LiveWallpaperEvent.started(isPro: $isPro)';
}


}

/// @nodoc
abstract mixin class _$StartedCopyWith<$Res> implements $LiveWallpaperEventCopyWith<$Res> {
  factory _$StartedCopyWith(_Started value, $Res Function(_Started) _then) = __$StartedCopyWithImpl;
@useResult
$Res call({
 bool isPro
});




}
/// @nodoc
class __$StartedCopyWithImpl<$Res>
    implements _$StartedCopyWith<$Res> {
  __$StartedCopyWithImpl(this._self, this._then);

  final _Started _self;
  final $Res Function(_Started) _then;

/// Create a copy of LiveWallpaperEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? isPro = null,}) {
  return _then(_Started(
isPro: null == isPro ? _self.isPro : isPro // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class _ProChanged implements LiveWallpaperEvent {
  const _ProChanged(this.isPro);
  

 final  bool isPro;

/// Create a copy of LiveWallpaperEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProChangedCopyWith<_ProChanged> get copyWith => __$ProChangedCopyWithImpl<_ProChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProChanged&&(identical(other.isPro, isPro) || other.isPro == isPro));
}


@override
int get hashCode => Object.hash(runtimeType,isPro);

@override
String toString() {
  return 'LiveWallpaperEvent.proChanged(isPro: $isPro)';
}


}

/// @nodoc
abstract mixin class _$ProChangedCopyWith<$Res> implements $LiveWallpaperEventCopyWith<$Res> {
  factory _$ProChangedCopyWith(_ProChanged value, $Res Function(_ProChanged) _then) = __$ProChangedCopyWithImpl;
@useResult
$Res call({
 bool isPro
});




}
/// @nodoc
class __$ProChangedCopyWithImpl<$Res>
    implements _$ProChangedCopyWith<$Res> {
  __$ProChangedCopyWithImpl(this._self, this._then);

  final _ProChanged _self;
  final $Res Function(_ProChanged) _then;

/// Create a copy of LiveWallpaperEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? isPro = null,}) {
  return _then(_ProChanged(
null == isPro ? _self.isPro : isPro // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class _MotionSelected implements LiveWallpaperEvent {
  const _MotionSelected(this.style);
  

 final  MotionStyle style;

/// Create a copy of LiveWallpaperEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MotionSelectedCopyWith<_MotionSelected> get copyWith => __$MotionSelectedCopyWithImpl<_MotionSelected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MotionSelected&&(identical(other.style, style) || other.style == style));
}


@override
int get hashCode => Object.hash(runtimeType,style);

@override
String toString() {
  return 'LiveWallpaperEvent.motionSelected(style: $style)';
}


}

/// @nodoc
abstract mixin class _$MotionSelectedCopyWith<$Res> implements $LiveWallpaperEventCopyWith<$Res> {
  factory _$MotionSelectedCopyWith(_MotionSelected value, $Res Function(_MotionSelected) _then) = __$MotionSelectedCopyWithImpl;
@useResult
$Res call({
 MotionStyle style
});




}
/// @nodoc
class __$MotionSelectedCopyWithImpl<$Res>
    implements _$MotionSelectedCopyWith<$Res> {
  __$MotionSelectedCopyWithImpl(this._self, this._then);

  final _MotionSelected _self;
  final $Res Function(_MotionSelected) _then;

/// Create a copy of LiveWallpaperEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? style = null,}) {
  return _then(_MotionSelected(
null == style ? _self.style : style // ignore: cast_nullable_to_non_nullable
as MotionStyle,
  ));
}


}

/// @nodoc


class _GradientSelected implements LiveWallpaperEvent {
  const _GradientSelected(this.style);
  

 final  GradientStyle style;

/// Create a copy of LiveWallpaperEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GradientSelectedCopyWith<_GradientSelected> get copyWith => __$GradientSelectedCopyWithImpl<_GradientSelected>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GradientSelected&&(identical(other.style, style) || other.style == style));
}


@override
int get hashCode => Object.hash(runtimeType,style);

@override
String toString() {
  return 'LiveWallpaperEvent.gradientSelected(style: $style)';
}


}

/// @nodoc
abstract mixin class _$GradientSelectedCopyWith<$Res> implements $LiveWallpaperEventCopyWith<$Res> {
  factory _$GradientSelectedCopyWith(_GradientSelected value, $Res Function(_GradientSelected) _then) = __$GradientSelectedCopyWithImpl;
@useResult
$Res call({
 GradientStyle style
});




}
/// @nodoc
class __$GradientSelectedCopyWithImpl<$Res>
    implements _$GradientSelectedCopyWith<$Res> {
  __$GradientSelectedCopyWithImpl(this._self, this._then);

  final _GradientSelected _self;
  final $Res Function(_GradientSelected) _then;

/// Create a copy of LiveWallpaperEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? style = null,}) {
  return _then(_GradientSelected(
null == style ? _self.style : style // ignore: cast_nullable_to_non_nullable
as GradientStyle,
  ));
}


}

/// @nodoc


class _BatterySaverChanged implements LiveWallpaperEvent {
  const _BatterySaverChanged(this.enabled);
  

 final  bool enabled;

/// Create a copy of LiveWallpaperEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BatterySaverChangedCopyWith<_BatterySaverChanged> get copyWith => __$BatterySaverChangedCopyWithImpl<_BatterySaverChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BatterySaverChanged&&(identical(other.enabled, enabled) || other.enabled == enabled));
}


@override
int get hashCode => Object.hash(runtimeType,enabled);

@override
String toString() {
  return 'LiveWallpaperEvent.batterySaverChanged(enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class _$BatterySaverChangedCopyWith<$Res> implements $LiveWallpaperEventCopyWith<$Res> {
  factory _$BatterySaverChangedCopyWith(_BatterySaverChanged value, $Res Function(_BatterySaverChanged) _then) = __$BatterySaverChangedCopyWithImpl;
@useResult
$Res call({
 bool enabled
});




}
/// @nodoc
class __$BatterySaverChangedCopyWithImpl<$Res>
    implements _$BatterySaverChangedCopyWith<$Res> {
  __$BatterySaverChangedCopyWithImpl(this._self, this._then);

  final _BatterySaverChanged _self;
  final $Res Function(_BatterySaverChanged) _then;

/// Create a copy of LiveWallpaperEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? enabled = null,}) {
  return _then(_BatterySaverChanged(
null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class _MotionApplied implements LiveWallpaperEvent {
  const _MotionApplied({required this.palette, required this.screenAspectRatio});
  

 final  LivePalette palette;
 final  double screenAspectRatio;

/// Create a copy of LiveWallpaperEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MotionAppliedCopyWith<_MotionApplied> get copyWith => __$MotionAppliedCopyWithImpl<_MotionApplied>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MotionApplied&&(identical(other.palette, palette) || other.palette == palette)&&(identical(other.screenAspectRatio, screenAspectRatio) || other.screenAspectRatio == screenAspectRatio));
}


@override
int get hashCode => Object.hash(runtimeType,palette,screenAspectRatio);

@override
String toString() {
  return 'LiveWallpaperEvent.motionApplied(palette: $palette, screenAspectRatio: $screenAspectRatio)';
}


}

/// @nodoc
abstract mixin class _$MotionAppliedCopyWith<$Res> implements $LiveWallpaperEventCopyWith<$Res> {
  factory _$MotionAppliedCopyWith(_MotionApplied value, $Res Function(_MotionApplied) _then) = __$MotionAppliedCopyWithImpl;
@useResult
$Res call({
 LivePalette palette, double screenAspectRatio
});




}
/// @nodoc
class __$MotionAppliedCopyWithImpl<$Res>
    implements _$MotionAppliedCopyWith<$Res> {
  __$MotionAppliedCopyWithImpl(this._self, this._then);

  final _MotionApplied _self;
  final $Res Function(_MotionApplied) _then;

/// Create a copy of LiveWallpaperEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? palette = null,Object? screenAspectRatio = null,}) {
  return _then(_MotionApplied(
palette: null == palette ? _self.palette : palette // ignore: cast_nullable_to_non_nullable
as LivePalette,screenAspectRatio: null == screenAspectRatio ? _self.screenAspectRatio : screenAspectRatio // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class _GradientApplied implements LiveWallpaperEvent {
  const _GradientApplied({required this.palette});
  

 final  LivePalette palette;

/// Create a copy of LiveWallpaperEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GradientAppliedCopyWith<_GradientApplied> get copyWith => __$GradientAppliedCopyWithImpl<_GradientApplied>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GradientApplied&&(identical(other.palette, palette) || other.palette == palette));
}


@override
int get hashCode => Object.hash(runtimeType,palette);

@override
String toString() {
  return 'LiveWallpaperEvent.gradientApplied(palette: $palette)';
}


}

/// @nodoc
abstract mixin class _$GradientAppliedCopyWith<$Res> implements $LiveWallpaperEventCopyWith<$Res> {
  factory _$GradientAppliedCopyWith(_GradientApplied value, $Res Function(_GradientApplied) _then) = __$GradientAppliedCopyWithImpl;
@useResult
$Res call({
 LivePalette palette
});




}
/// @nodoc
class __$GradientAppliedCopyWithImpl<$Res>
    implements _$GradientAppliedCopyWith<$Res> {
  __$GradientAppliedCopyWithImpl(this._self, this._then);

  final _GradientApplied _self;
  final $Res Function(_GradientApplied) _then;

/// Create a copy of LiveWallpaperEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? palette = null,}) {
  return _then(_GradientApplied(
palette: null == palette ? _self.palette : palette // ignore: cast_nullable_to_non_nullable
as LivePalette,
  ));
}


}

/// @nodoc


class _VideoPicked implements LiveWallpaperEvent {
  const _VideoPicked(this.path);
  

 final  String path;

/// Create a copy of LiveWallpaperEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoPickedCopyWith<_VideoPicked> get copyWith => __$VideoPickedCopyWithImpl<_VideoPicked>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoPicked&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode => Object.hash(runtimeType,path);

@override
String toString() {
  return 'LiveWallpaperEvent.videoPicked(path: $path)';
}


}

/// @nodoc
abstract mixin class _$VideoPickedCopyWith<$Res> implements $LiveWallpaperEventCopyWith<$Res> {
  factory _$VideoPickedCopyWith(_VideoPicked value, $Res Function(_VideoPicked) _then) = __$VideoPickedCopyWithImpl;
@useResult
$Res call({
 String path
});




}
/// @nodoc
class __$VideoPickedCopyWithImpl<$Res>
    implements _$VideoPickedCopyWith<$Res> {
  __$VideoPickedCopyWithImpl(this._self, this._then);

  final _VideoPicked _self;
  final $Res Function(_VideoPicked) _then;

/// Create a copy of LiveWallpaperEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,}) {
  return _then(_VideoPicked(
null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _VideoApplied implements LiveWallpaperEvent {
  const _VideoApplied();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoApplied);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LiveWallpaperEvent.videoApplied()';
}


}




/// @nodoc
mixin _$LiveWallpaperState {

 LiveWallpaperStatus get status; LiveCapabilities get capabilities; bool get isPro; MotionStyle get motionStyle; GradientStyle get gradientStyle; bool get batterySaver; bool get applying; String? get videoPath; LiveApplyOutcome? get outcome;
/// Create a copy of LiveWallpaperState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveWallpaperStateCopyWith<LiveWallpaperState> get copyWith => _$LiveWallpaperStateCopyWithImpl<LiveWallpaperState>(this as LiveWallpaperState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveWallpaperState&&(identical(other.status, status) || other.status == status)&&(identical(other.capabilities, capabilities) || other.capabilities == capabilities)&&(identical(other.isPro, isPro) || other.isPro == isPro)&&(identical(other.motionStyle, motionStyle) || other.motionStyle == motionStyle)&&(identical(other.gradientStyle, gradientStyle) || other.gradientStyle == gradientStyle)&&(identical(other.batterySaver, batterySaver) || other.batterySaver == batterySaver)&&(identical(other.applying, applying) || other.applying == applying)&&(identical(other.videoPath, videoPath) || other.videoPath == videoPath)&&(identical(other.outcome, outcome) || other.outcome == outcome));
}


@override
int get hashCode => Object.hash(runtimeType,status,capabilities,isPro,motionStyle,gradientStyle,batterySaver,applying,videoPath,outcome);

@override
String toString() {
  return 'LiveWallpaperState(status: $status, capabilities: $capabilities, isPro: $isPro, motionStyle: $motionStyle, gradientStyle: $gradientStyle, batterySaver: $batterySaver, applying: $applying, videoPath: $videoPath, outcome: $outcome)';
}


}

/// @nodoc
abstract mixin class $LiveWallpaperStateCopyWith<$Res>  {
  factory $LiveWallpaperStateCopyWith(LiveWallpaperState value, $Res Function(LiveWallpaperState) _then) = _$LiveWallpaperStateCopyWithImpl;
@useResult
$Res call({
 LiveWallpaperStatus status, LiveCapabilities capabilities, bool isPro, MotionStyle motionStyle, GradientStyle gradientStyle, bool batterySaver, bool applying, String? videoPath, LiveApplyOutcome? outcome
});




}
/// @nodoc
class _$LiveWallpaperStateCopyWithImpl<$Res>
    implements $LiveWallpaperStateCopyWith<$Res> {
  _$LiveWallpaperStateCopyWithImpl(this._self, this._then);

  final LiveWallpaperState _self;
  final $Res Function(LiveWallpaperState) _then;

/// Create a copy of LiveWallpaperState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? capabilities = null,Object? isPro = null,Object? motionStyle = null,Object? gradientStyle = null,Object? batterySaver = null,Object? applying = null,Object? videoPath = freezed,Object? outcome = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LiveWallpaperStatus,capabilities: null == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as LiveCapabilities,isPro: null == isPro ? _self.isPro : isPro // ignore: cast_nullable_to_non_nullable
as bool,motionStyle: null == motionStyle ? _self.motionStyle : motionStyle // ignore: cast_nullable_to_non_nullable
as MotionStyle,gradientStyle: null == gradientStyle ? _self.gradientStyle : gradientStyle // ignore: cast_nullable_to_non_nullable
as GradientStyle,batterySaver: null == batterySaver ? _self.batterySaver : batterySaver // ignore: cast_nullable_to_non_nullable
as bool,applying: null == applying ? _self.applying : applying // ignore: cast_nullable_to_non_nullable
as bool,videoPath: freezed == videoPath ? _self.videoPath : videoPath // ignore: cast_nullable_to_non_nullable
as String?,outcome: freezed == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as LiveApplyOutcome?,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveWallpaperState].
extension LiveWallpaperStatePatterns on LiveWallpaperState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveWallpaperState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveWallpaperState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveWallpaperState value)  $default,){
final _that = this;
switch (_that) {
case _LiveWallpaperState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveWallpaperState value)?  $default,){
final _that = this;
switch (_that) {
case _LiveWallpaperState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LiveWallpaperStatus status,  LiveCapabilities capabilities,  bool isPro,  MotionStyle motionStyle,  GradientStyle gradientStyle,  bool batterySaver,  bool applying,  String? videoPath,  LiveApplyOutcome? outcome)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveWallpaperState() when $default != null:
return $default(_that.status,_that.capabilities,_that.isPro,_that.motionStyle,_that.gradientStyle,_that.batterySaver,_that.applying,_that.videoPath,_that.outcome);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LiveWallpaperStatus status,  LiveCapabilities capabilities,  bool isPro,  MotionStyle motionStyle,  GradientStyle gradientStyle,  bool batterySaver,  bool applying,  String? videoPath,  LiveApplyOutcome? outcome)  $default,) {final _that = this;
switch (_that) {
case _LiveWallpaperState():
return $default(_that.status,_that.capabilities,_that.isPro,_that.motionStyle,_that.gradientStyle,_that.batterySaver,_that.applying,_that.videoPath,_that.outcome);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LiveWallpaperStatus status,  LiveCapabilities capabilities,  bool isPro,  MotionStyle motionStyle,  GradientStyle gradientStyle,  bool batterySaver,  bool applying,  String? videoPath,  LiveApplyOutcome? outcome)?  $default,) {final _that = this;
switch (_that) {
case _LiveWallpaperState() when $default != null:
return $default(_that.status,_that.capabilities,_that.isPro,_that.motionStyle,_that.gradientStyle,_that.batterySaver,_that.applying,_that.videoPath,_that.outcome);case _:
  return null;

}
}

}

/// @nodoc


class _LiveWallpaperState implements LiveWallpaperState {
  const _LiveWallpaperState({required this.status, required this.capabilities, required this.isPro, required this.motionStyle, required this.gradientStyle, required this.batterySaver, required this.applying, this.videoPath, this.outcome});
  

@override final  LiveWallpaperStatus status;
@override final  LiveCapabilities capabilities;
@override final  bool isPro;
@override final  MotionStyle motionStyle;
@override final  GradientStyle gradientStyle;
@override final  bool batterySaver;
@override final  bool applying;
@override final  String? videoPath;
@override final  LiveApplyOutcome? outcome;

/// Create a copy of LiveWallpaperState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveWallpaperStateCopyWith<_LiveWallpaperState> get copyWith => __$LiveWallpaperStateCopyWithImpl<_LiveWallpaperState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveWallpaperState&&(identical(other.status, status) || other.status == status)&&(identical(other.capabilities, capabilities) || other.capabilities == capabilities)&&(identical(other.isPro, isPro) || other.isPro == isPro)&&(identical(other.motionStyle, motionStyle) || other.motionStyle == motionStyle)&&(identical(other.gradientStyle, gradientStyle) || other.gradientStyle == gradientStyle)&&(identical(other.batterySaver, batterySaver) || other.batterySaver == batterySaver)&&(identical(other.applying, applying) || other.applying == applying)&&(identical(other.videoPath, videoPath) || other.videoPath == videoPath)&&(identical(other.outcome, outcome) || other.outcome == outcome));
}


@override
int get hashCode => Object.hash(runtimeType,status,capabilities,isPro,motionStyle,gradientStyle,batterySaver,applying,videoPath,outcome);

@override
String toString() {
  return 'LiveWallpaperState(status: $status, capabilities: $capabilities, isPro: $isPro, motionStyle: $motionStyle, gradientStyle: $gradientStyle, batterySaver: $batterySaver, applying: $applying, videoPath: $videoPath, outcome: $outcome)';
}


}

/// @nodoc
abstract mixin class _$LiveWallpaperStateCopyWith<$Res> implements $LiveWallpaperStateCopyWith<$Res> {
  factory _$LiveWallpaperStateCopyWith(_LiveWallpaperState value, $Res Function(_LiveWallpaperState) _then) = __$LiveWallpaperStateCopyWithImpl;
@override @useResult
$Res call({
 LiveWallpaperStatus status, LiveCapabilities capabilities, bool isPro, MotionStyle motionStyle, GradientStyle gradientStyle, bool batterySaver, bool applying, String? videoPath, LiveApplyOutcome? outcome
});




}
/// @nodoc
class __$LiveWallpaperStateCopyWithImpl<$Res>
    implements _$LiveWallpaperStateCopyWith<$Res> {
  __$LiveWallpaperStateCopyWithImpl(this._self, this._then);

  final _LiveWallpaperState _self;
  final $Res Function(_LiveWallpaperState) _then;

/// Create a copy of LiveWallpaperState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? capabilities = null,Object? isPro = null,Object? motionStyle = null,Object? gradientStyle = null,Object? batterySaver = null,Object? applying = null,Object? videoPath = freezed,Object? outcome = freezed,}) {
  return _then(_LiveWallpaperState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LiveWallpaperStatus,capabilities: null == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as LiveCapabilities,isPro: null == isPro ? _self.isPro : isPro // ignore: cast_nullable_to_non_nullable
as bool,motionStyle: null == motionStyle ? _self.motionStyle : motionStyle // ignore: cast_nullable_to_non_nullable
as MotionStyle,gradientStyle: null == gradientStyle ? _self.gradientStyle : gradientStyle // ignore: cast_nullable_to_non_nullable
as GradientStyle,batterySaver: null == batterySaver ? _self.batterySaver : batterySaver // ignore: cast_nullable_to_non_nullable
as bool,applying: null == applying ? _self.applying : applying // ignore: cast_nullable_to_non_nullable
as bool,videoPath: freezed == videoPath ? _self.videoPath : videoPath // ignore: cast_nullable_to_non_nullable
as String?,outcome: freezed == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as LiveApplyOutcome?,
  ));
}


}

// dart format on
