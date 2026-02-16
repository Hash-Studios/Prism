// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'theme_mode_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ThemeModeEvent {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is ThemeModeEvent);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'ThemeModeEvent()';
  }
}

/// @nodoc
class $ThemeModeEventCopyWith<$Res> {
  $ThemeModeEventCopyWith(ThemeModeEvent _, $Res Function(ThemeModeEvent) __);
}

/// Adds pattern-matching-related methods to [ThemeModeEvent].
extension ThemeModeEventPatterns on ThemeModeEvent {
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
    TResult Function(_Started value)? started,
    TResult Function(_ModeChanged value)? modeChanged,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _ModeChanged() when modeChanged != null:
        return modeChanged(_that);
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
    required TResult Function(_Started value) started,
    required TResult Function(_ModeChanged value) modeChanged,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started(_that);
      case _ModeChanged():
        return modeChanged(_that);
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
    TResult? Function(_Started value)? started,
    TResult? Function(_ModeChanged value)? modeChanged,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _ModeChanged() when modeChanged != null:
        return modeChanged(_that);
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
    TResult Function()? started,
    TResult Function(String mode)? modeChanged,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started();
      case _ModeChanged() when modeChanged != null:
        return modeChanged(_that.mode);
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
    required TResult Function() started,
    required TResult Function(String mode) modeChanged,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started();
      case _ModeChanged():
        return modeChanged(_that.mode);
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
    TResult? Function()? started,
    TResult? Function(String mode)? modeChanged,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started();
      case _ModeChanged() when modeChanged != null:
        return modeChanged(_that.mode);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _Started implements ThemeModeEvent {
  const _Started();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _Started);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'ThemeModeEvent.started()';
  }
}

/// @nodoc

class _ModeChanged implements ThemeModeEvent {
  const _ModeChanged({required this.mode});

  final String mode;

  /// Create a copy of ThemeModeEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ModeChangedCopyWith<_ModeChanged> get copyWith =>
      __$ModeChangedCopyWithImpl<_ModeChanged>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ModeChanged &&
            (identical(other.mode, mode) || other.mode == mode));
  }

  @override
  int get hashCode => Object.hash(runtimeType, mode);

  @override
  String toString() {
    return 'ThemeModeEvent.modeChanged(mode: $mode)';
  }
}

/// @nodoc
abstract mixin class _$ModeChangedCopyWith<$Res>
    implements $ThemeModeEventCopyWith<$Res> {
  factory _$ModeChangedCopyWith(
          _ModeChanged value, $Res Function(_ModeChanged) _then) =
      __$ModeChangedCopyWithImpl;
  @useResult
  $Res call({String mode});
}

/// @nodoc
class __$ModeChangedCopyWithImpl<$Res> implements _$ModeChangedCopyWith<$Res> {
  __$ModeChangedCopyWithImpl(this._self, this._then);

  final _ModeChanged _self;
  final $Res Function(_ModeChanged) _then;

  /// Create a copy of ThemeModeEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? mode = null,
  }) {
    return _then(_ModeChanged(
      mode: null == mode
          ? _self.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$ThemeModeState {
  LoadStatus get status;
  ActionStatus get actionStatus;
  ThemeModeEntity get mode;
  Failure? get failure;

  /// Create a copy of ThemeModeState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ThemeModeStateCopyWith<ThemeModeState> get copyWith =>
      _$ThemeModeStateCopyWithImpl<ThemeModeState>(
          this as ThemeModeState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ThemeModeState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) ||
                other.actionStatus == actionStatus) &&
            (identical(other.mode, mode) || other.mode == mode) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, status, actionStatus, mode, failure);

  @override
  String toString() {
    return 'ThemeModeState(status: $status, actionStatus: $actionStatus, mode: $mode, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class $ThemeModeStateCopyWith<$Res> {
  factory $ThemeModeStateCopyWith(
          ThemeModeState value, $Res Function(ThemeModeState) _then) =
      _$ThemeModeStateCopyWithImpl;
  @useResult
  $Res call(
      {LoadStatus status,
      ActionStatus actionStatus,
      ThemeModeEntity mode,
      Failure? failure});
}

/// @nodoc
class _$ThemeModeStateCopyWithImpl<$Res>
    implements $ThemeModeStateCopyWith<$Res> {
  _$ThemeModeStateCopyWithImpl(this._self, this._then);

  final ThemeModeState _self;
  final $Res Function(ThemeModeState) _then;

  /// Create a copy of ThemeModeState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
    Object? mode = null,
    Object? failure = freezed,
  }) {
    return _then(_self.copyWith(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as LoadStatus,
      actionStatus: null == actionStatus
          ? _self.actionStatus
          : actionStatus // ignore: cast_nullable_to_non_nullable
              as ActionStatus,
      mode: null == mode
          ? _self.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as ThemeModeEntity,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ThemeModeState].
extension ThemeModeStatePatterns on ThemeModeState {
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
    TResult Function(_ThemeModeState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ThemeModeState() when $default != null:
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
    TResult Function(_ThemeModeState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ThemeModeState():
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
    TResult? Function(_ThemeModeState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ThemeModeState() when $default != null:
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
    TResult Function(LoadStatus status, ActionStatus actionStatus,
            ThemeModeEntity mode, Failure? failure)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ThemeModeState() when $default != null:
        return $default(
            _that.status, _that.actionStatus, _that.mode, _that.failure);
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
    TResult Function(LoadStatus status, ActionStatus actionStatus,
            ThemeModeEntity mode, Failure? failure)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ThemeModeState():
        return $default(
            _that.status, _that.actionStatus, _that.mode, _that.failure);
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
    TResult? Function(LoadStatus status, ActionStatus actionStatus,
            ThemeModeEntity mode, Failure? failure)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ThemeModeState() when $default != null:
        return $default(
            _that.status, _that.actionStatus, _that.mode, _that.failure);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ThemeModeState implements ThemeModeState {
  const _ThemeModeState(
      {required this.status,
      required this.actionStatus,
      required this.mode,
      this.failure});

  @override
  final LoadStatus status;
  @override
  final ActionStatus actionStatus;
  @override
  final ThemeModeEntity mode;
  @override
  final Failure? failure;

  /// Create a copy of ThemeModeState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ThemeModeStateCopyWith<_ThemeModeState> get copyWith =>
      __$ThemeModeStateCopyWithImpl<_ThemeModeState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ThemeModeState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) ||
                other.actionStatus == actionStatus) &&
            (identical(other.mode, mode) || other.mode == mode) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, status, actionStatus, mode, failure);

  @override
  String toString() {
    return 'ThemeModeState(status: $status, actionStatus: $actionStatus, mode: $mode, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class _$ThemeModeStateCopyWith<$Res>
    implements $ThemeModeStateCopyWith<$Res> {
  factory _$ThemeModeStateCopyWith(
          _ThemeModeState value, $Res Function(_ThemeModeState) _then) =
      __$ThemeModeStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {LoadStatus status,
      ActionStatus actionStatus,
      ThemeModeEntity mode,
      Failure? failure});
}

/// @nodoc
class __$ThemeModeStateCopyWithImpl<$Res>
    implements _$ThemeModeStateCopyWith<$Res> {
  __$ThemeModeStateCopyWithImpl(this._self, this._then);

  final _ThemeModeState _self;
  final $Res Function(_ThemeModeState) _then;

  /// Create a copy of ThemeModeState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
    Object? mode = null,
    Object? failure = freezed,
  }) {
    return _then(_ThemeModeState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as LoadStatus,
      actionStatus: null == actionStatus
          ? _self.actionStatus
          : actionStatus // ignore: cast_nullable_to_non_nullable
              as ActionStatus,
      mode: null == mode
          ? _self.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as ThemeModeEntity,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

// dart format on
