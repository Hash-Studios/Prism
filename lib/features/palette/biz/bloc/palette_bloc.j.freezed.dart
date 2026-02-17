// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'palette_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PaletteEvent {
  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType && other is PaletteEvent);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'PaletteEvent()';
  }
}

/// @nodoc
class $PaletteEventCopyWith<$Res> {
  $PaletteEventCopyWith(PaletteEvent _, $Res Function(PaletteEvent) __);
}

/// Adds pattern-matching-related methods to [PaletteEvent].
extension PaletteEventPatterns on PaletteEvent {
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

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_PaletteRequested value)? paletteRequested,
    TResult Function(_PaletteCleared value)? paletteCleared,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PaletteRequested() when paletteRequested != null:
        return paletteRequested(_that);
      case _PaletteCleared() when paletteCleared != null:
        return paletteCleared(_that);
      case _:
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

  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_PaletteRequested value) paletteRequested,
    required TResult Function(_PaletteCleared value) paletteCleared,
  }) {
    final _that = this;
    switch (_that) {
      case _PaletteRequested():
        return paletteRequested(_that);
      case _PaletteCleared():
        return paletteCleared(_that);
      case _:
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

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_PaletteRequested value)? paletteRequested,
    TResult? Function(_PaletteCleared value)? paletteCleared,
  }) {
    final _that = this;
    switch (_that) {
      case _PaletteRequested() when paletteRequested != null:
        return paletteRequested(_that);
      case _PaletteCleared() when paletteCleared != null:
        return paletteCleared(_that);
      case _:
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

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String imageUrl)? paletteRequested,
    TResult Function()? paletteCleared,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PaletteRequested() when paletteRequested != null:
        return paletteRequested(_that.imageUrl);
      case _PaletteCleared() when paletteCleared != null:
        return paletteCleared();
      case _:
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

  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String imageUrl) paletteRequested,
    required TResult Function() paletteCleared,
  }) {
    final _that = this;
    switch (_that) {
      case _PaletteRequested():
        return paletteRequested(_that.imageUrl);
      case _PaletteCleared():
        return paletteCleared();
      case _:
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

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String imageUrl)? paletteRequested,
    TResult? Function()? paletteCleared,
  }) {
    final _that = this;
    switch (_that) {
      case _PaletteRequested() when paletteRequested != null:
        return paletteRequested(_that.imageUrl);
      case _PaletteCleared() when paletteCleared != null:
        return paletteCleared();
      case _:
        return null;
    }
  }
}

/// @nodoc

class _PaletteRequested implements PaletteEvent {
  const _PaletteRequested({required this.imageUrl});

  final String imageUrl;

  /// Create a copy of PaletteEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PaletteRequestedCopyWith<_PaletteRequested> get copyWith =>
      __$PaletteRequestedCopyWithImpl<_PaletteRequested>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PaletteRequested &&
            (identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl));
  }

  @override
  int get hashCode => Object.hash(runtimeType, imageUrl);

  @override
  String toString() {
    return 'PaletteEvent.paletteRequested(imageUrl: $imageUrl)';
  }
}

/// @nodoc
abstract mixin class _$PaletteRequestedCopyWith<$Res> implements $PaletteEventCopyWith<$Res> {
  factory _$PaletteRequestedCopyWith(_PaletteRequested value, $Res Function(_PaletteRequested) _then) =
      __$PaletteRequestedCopyWithImpl;
  @useResult
  $Res call({String imageUrl});
}

/// @nodoc
class __$PaletteRequestedCopyWithImpl<$Res> implements _$PaletteRequestedCopyWith<$Res> {
  __$PaletteRequestedCopyWithImpl(this._self, this._then);

  final _PaletteRequested _self;
  final $Res Function(_PaletteRequested) _then;

  /// Create a copy of PaletteEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? imageUrl = null,
  }) {
    return _then(_PaletteRequested(
      imageUrl: null == imageUrl
          ? _self.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _PaletteCleared implements PaletteEvent {
  const _PaletteCleared();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType && other is _PaletteCleared);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'PaletteEvent.paletteCleared()';
  }
}

/// @nodoc
mixin _$PaletteState {
  LoadStatus get status;
  PaletteEntity get palette;
  Failure? get failure;

  /// Create a copy of PaletteState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PaletteStateCopyWith<PaletteState> get copyWith =>
      _$PaletteStateCopyWithImpl<PaletteState>(this as PaletteState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PaletteState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.palette, palette) || other.palette == palette) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, palette, failure);

  @override
  String toString() {
    return 'PaletteState(status: $status, palette: $palette, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class $PaletteStateCopyWith<$Res> {
  factory $PaletteStateCopyWith(PaletteState value, $Res Function(PaletteState) _then) = _$PaletteStateCopyWithImpl;
  @useResult
  $Res call({LoadStatus status, PaletteEntity palette, Failure? failure});
}

/// @nodoc
class _$PaletteStateCopyWithImpl<$Res> implements $PaletteStateCopyWith<$Res> {
  _$PaletteStateCopyWithImpl(this._self, this._then);

  final PaletteState _self;
  final $Res Function(PaletteState) _then;

  /// Create a copy of PaletteState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? palette = null,
    Object? failure = freezed,
  }) {
    return _then(_self.copyWith(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as LoadStatus,
      palette: null == palette
          ? _self.palette
          : palette // ignore: cast_nullable_to_non_nullable
              as PaletteEntity,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

/// Adds pattern-matching-related methods to [PaletteState].
extension PaletteStatePatterns on PaletteState {
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

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_PaletteState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PaletteState() when $default != null:
        return $default(_that);
      case _:
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

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_PaletteState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaletteState():
        return $default(_that);
      case _:
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

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_PaletteState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaletteState() when $default != null:
        return $default(_that);
      case _:
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

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(LoadStatus status, PaletteEntity palette, Failure? failure)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PaletteState() when $default != null:
        return $default(_that.status, _that.palette, _that.failure);
      case _:
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

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(LoadStatus status, PaletteEntity palette, Failure? failure) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaletteState():
        return $default(_that.status, _that.palette, _that.failure);
      case _:
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

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(LoadStatus status, PaletteEntity palette, Failure? failure)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaletteState() when $default != null:
        return $default(_that.status, _that.palette, _that.failure);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _PaletteState implements PaletteState {
  const _PaletteState({required this.status, required this.palette, this.failure});

  @override
  final LoadStatus status;
  @override
  final PaletteEntity palette;
  @override
  final Failure? failure;

  /// Create a copy of PaletteState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PaletteStateCopyWith<_PaletteState> get copyWith => __$PaletteStateCopyWithImpl<_PaletteState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PaletteState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.palette, palette) || other.palette == palette) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, palette, failure);

  @override
  String toString() {
    return 'PaletteState(status: $status, palette: $palette, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class _$PaletteStateCopyWith<$Res> implements $PaletteStateCopyWith<$Res> {
  factory _$PaletteStateCopyWith(_PaletteState value, $Res Function(_PaletteState) _then) = __$PaletteStateCopyWithImpl;
  @override
  @useResult
  $Res call({LoadStatus status, PaletteEntity palette, Failure? failure});
}

/// @nodoc
class __$PaletteStateCopyWithImpl<$Res> implements _$PaletteStateCopyWith<$Res> {
  __$PaletteStateCopyWithImpl(this._self, this._then);

  final _PaletteState _self;
  final $Res Function(_PaletteState) _then;

  /// Create a copy of PaletteState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? palette = null,
    Object? failure = freezed,
  }) {
    return _then(_PaletteState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as LoadStatus,
      palette: null == palette
          ? _self.palette
          : palette // ignore: cast_nullable_to_non_nullable
              as PaletteEntity,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

// dart format on
