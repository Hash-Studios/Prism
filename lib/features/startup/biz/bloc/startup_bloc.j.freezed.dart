// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'startup_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StartupEvent {
  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType && other is StartupEvent);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'StartupEvent()';
  }
}

/// @nodoc
class $StartupEventCopyWith<$Res> {
  $StartupEventCopyWith(StartupEvent _, $Res Function(StartupEvent) __);
}

/// Adds pattern-matching-related methods to [StartupEvent].
extension StartupEventPatterns on StartupEvent {
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
    TResult Function(_RetryRequested value)? retryRequested,
    TResult Function(_NotchMeasured value)? notchMeasured,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _RetryRequested() when retryRequested != null:
        return retryRequested(_that);
      case _NotchMeasured() when notchMeasured != null:
        return notchMeasured(_that);
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
    required TResult Function(_RetryRequested value) retryRequested,
    required TResult Function(_NotchMeasured value) notchMeasured,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started(_that);
      case _RetryRequested():
        return retryRequested(_that);
      case _NotchMeasured():
        return notchMeasured(_that);
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
    TResult? Function(_RetryRequested value)? retryRequested,
    TResult? Function(_NotchMeasured value)? notchMeasured,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _RetryRequested() when retryRequested != null:
        return retryRequested(_that);
      case _NotchMeasured() when notchMeasured != null:
        return notchMeasured(_that);
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
    TResult Function(String? currentVersion)? started,
    TResult Function(String? currentVersion)? retryRequested,
    TResult Function(double notchHeight)? notchMeasured,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that.currentVersion);
      case _RetryRequested() when retryRequested != null:
        return retryRequested(_that.currentVersion);
      case _NotchMeasured() when notchMeasured != null:
        return notchMeasured(_that.notchHeight);
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
    required TResult Function(String? currentVersion) started,
    required TResult Function(String? currentVersion) retryRequested,
    required TResult Function(double notchHeight) notchMeasured,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started(_that.currentVersion);
      case _RetryRequested():
        return retryRequested(_that.currentVersion);
      case _NotchMeasured():
        return notchMeasured(_that.notchHeight);
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
    TResult? Function(String? currentVersion)? started,
    TResult? Function(String? currentVersion)? retryRequested,
    TResult? Function(double notchHeight)? notchMeasured,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that.currentVersion);
      case _RetryRequested() when retryRequested != null:
        return retryRequested(_that.currentVersion);
      case _NotchMeasured() when notchMeasured != null:
        return notchMeasured(_that.notchHeight);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _Started implements StartupEvent {
  const _Started({this.currentVersion});

  final String? currentVersion;

  /// Create a copy of StartupEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$StartedCopyWith<_Started> get copyWith => __$StartedCopyWithImpl<_Started>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Started &&
            (identical(other.currentVersion, currentVersion) || other.currentVersion == currentVersion));
  }

  @override
  int get hashCode => Object.hash(runtimeType, currentVersion);

  @override
  String toString() {
    return 'StartupEvent.started(currentVersion: $currentVersion)';
  }
}

/// @nodoc
abstract mixin class _$StartedCopyWith<$Res> implements $StartupEventCopyWith<$Res> {
  factory _$StartedCopyWith(_Started value, $Res Function(_Started) _then) = __$StartedCopyWithImpl;
  @useResult
  $Res call({String? currentVersion});
}

/// @nodoc
class __$StartedCopyWithImpl<$Res> implements _$StartedCopyWith<$Res> {
  __$StartedCopyWithImpl(this._self, this._then);

  final _Started _self;
  final $Res Function(_Started) _then;

  /// Create a copy of StartupEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? currentVersion = freezed,
  }) {
    return _then(_Started(
      currentVersion: freezed == currentVersion
          ? _self.currentVersion
          : currentVersion // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _RetryRequested implements StartupEvent {
  const _RetryRequested({this.currentVersion});

  final String? currentVersion;

  /// Create a copy of StartupEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RetryRequestedCopyWith<_RetryRequested> get copyWith =>
      __$RetryRequestedCopyWithImpl<_RetryRequested>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RetryRequested &&
            (identical(other.currentVersion, currentVersion) || other.currentVersion == currentVersion));
  }

  @override
  int get hashCode => Object.hash(runtimeType, currentVersion);

  @override
  String toString() {
    return 'StartupEvent.retryRequested(currentVersion: $currentVersion)';
  }
}

/// @nodoc
abstract mixin class _$RetryRequestedCopyWith<$Res> implements $StartupEventCopyWith<$Res> {
  factory _$RetryRequestedCopyWith(_RetryRequested value, $Res Function(_RetryRequested) _then) =
      __$RetryRequestedCopyWithImpl;
  @useResult
  $Res call({String? currentVersion});
}

/// @nodoc
class __$RetryRequestedCopyWithImpl<$Res> implements _$RetryRequestedCopyWith<$Res> {
  __$RetryRequestedCopyWithImpl(this._self, this._then);

  final _RetryRequested _self;
  final $Res Function(_RetryRequested) _then;

  /// Create a copy of StartupEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? currentVersion = freezed,
  }) {
    return _then(_RetryRequested(
      currentVersion: freezed == currentVersion
          ? _self.currentVersion
          : currentVersion // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _NotchMeasured implements StartupEvent {
  const _NotchMeasured({required this.notchHeight});

  final double notchHeight;

  /// Create a copy of StartupEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$NotchMeasuredCopyWith<_NotchMeasured> get copyWith =>
      __$NotchMeasuredCopyWithImpl<_NotchMeasured>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _NotchMeasured &&
            (identical(other.notchHeight, notchHeight) || other.notchHeight == notchHeight));
  }

  @override
  int get hashCode => Object.hash(runtimeType, notchHeight);

  @override
  String toString() {
    return 'StartupEvent.notchMeasured(notchHeight: $notchHeight)';
  }
}

/// @nodoc
abstract mixin class _$NotchMeasuredCopyWith<$Res> implements $StartupEventCopyWith<$Res> {
  factory _$NotchMeasuredCopyWith(_NotchMeasured value, $Res Function(_NotchMeasured) _then) =
      __$NotchMeasuredCopyWithImpl;
  @useResult
  $Res call({double notchHeight});
}

/// @nodoc
class __$NotchMeasuredCopyWithImpl<$Res> implements _$NotchMeasuredCopyWith<$Res> {
  __$NotchMeasuredCopyWithImpl(this._self, this._then);

  final _NotchMeasured _self;
  final $Res Function(_NotchMeasured) _then;

  /// Create a copy of StartupEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? notchHeight = null,
  }) {
    return _then(_NotchMeasured(
      notchHeight: null == notchHeight
          ? _self.notchHeight
          : notchHeight // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
mixin _$StartupState {
  LoadStatus get status;
  ActionStatus get actionStatus;
  StartupConfigEntity? get config;
  bool get isObsoleteVersion;
  double get notchHeight;
  Failure? get failure;

  /// Create a copy of StartupState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $StartupStateCopyWith<StartupState> get copyWith =>
      _$StartupStateCopyWithImpl<StartupState>(this as StartupState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is StartupState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus) &&
            (identical(other.config, config) || other.config == config) &&
            (identical(other.isObsoleteVersion, isObsoleteVersion) || other.isObsoleteVersion == isObsoleteVersion) &&
            (identical(other.notchHeight, notchHeight) || other.notchHeight == notchHeight) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, actionStatus, config, isObsoleteVersion, notchHeight, failure);

  @override
  String toString() {
    return 'StartupState(status: $status, actionStatus: $actionStatus, config: $config, isObsoleteVersion: $isObsoleteVersion, notchHeight: $notchHeight, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class $StartupStateCopyWith<$Res> {
  factory $StartupStateCopyWith(StartupState value, $Res Function(StartupState) _then) = _$StartupStateCopyWithImpl;
  @useResult
  $Res call(
      {LoadStatus status,
      ActionStatus actionStatus,
      StartupConfigEntity? config,
      bool isObsoleteVersion,
      double notchHeight,
      Failure? failure});
}

/// @nodoc
class _$StartupStateCopyWithImpl<$Res> implements $StartupStateCopyWith<$Res> {
  _$StartupStateCopyWithImpl(this._self, this._then);

  final StartupState _self;
  final $Res Function(StartupState) _then;

  /// Create a copy of StartupState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
    Object? config = freezed,
    Object? isObsoleteVersion = null,
    Object? notchHeight = null,
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
      config: freezed == config
          ? _self.config
          : config // ignore: cast_nullable_to_non_nullable
              as StartupConfigEntity?,
      isObsoleteVersion: null == isObsoleteVersion
          ? _self.isObsoleteVersion
          : isObsoleteVersion // ignore: cast_nullable_to_non_nullable
              as bool,
      notchHeight: null == notchHeight
          ? _self.notchHeight
          : notchHeight // ignore: cast_nullable_to_non_nullable
              as double,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

/// Adds pattern-matching-related methods to [StartupState].
extension StartupStatePatterns on StartupState {
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
    TResult Function(_StartupState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _StartupState() when $default != null:
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
    TResult Function(_StartupState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _StartupState():
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
    TResult? Function(_StartupState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _StartupState() when $default != null:
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
    TResult Function(LoadStatus status, ActionStatus actionStatus, StartupConfigEntity? config, bool isObsoleteVersion,
            double notchHeight, Failure? failure)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _StartupState() when $default != null:
        return $default(
            _that.status, _that.actionStatus, _that.config, _that.isObsoleteVersion, _that.notchHeight, _that.failure);
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
    TResult Function(LoadStatus status, ActionStatus actionStatus, StartupConfigEntity? config, bool isObsoleteVersion,
            double notchHeight, Failure? failure)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _StartupState():
        return $default(
            _that.status, _that.actionStatus, _that.config, _that.isObsoleteVersion, _that.notchHeight, _that.failure);
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
    TResult? Function(LoadStatus status, ActionStatus actionStatus, StartupConfigEntity? config, bool isObsoleteVersion,
            double notchHeight, Failure? failure)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _StartupState() when $default != null:
        return $default(
            _that.status, _that.actionStatus, _that.config, _that.isObsoleteVersion, _that.notchHeight, _that.failure);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _StartupState implements StartupState {
  const _StartupState(
      {required this.status,
      required this.actionStatus,
      required this.config,
      required this.isObsoleteVersion,
      required this.notchHeight,
      this.failure});

  @override
  final LoadStatus status;
  @override
  final ActionStatus actionStatus;
  @override
  final StartupConfigEntity? config;
  @override
  final bool isObsoleteVersion;
  @override
  final double notchHeight;
  @override
  final Failure? failure;

  /// Create a copy of StartupState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$StartupStateCopyWith<_StartupState> get copyWith => __$StartupStateCopyWithImpl<_StartupState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _StartupState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus) &&
            (identical(other.config, config) || other.config == config) &&
            (identical(other.isObsoleteVersion, isObsoleteVersion) || other.isObsoleteVersion == isObsoleteVersion) &&
            (identical(other.notchHeight, notchHeight) || other.notchHeight == notchHeight) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, actionStatus, config, isObsoleteVersion, notchHeight, failure);

  @override
  String toString() {
    return 'StartupState(status: $status, actionStatus: $actionStatus, config: $config, isObsoleteVersion: $isObsoleteVersion, notchHeight: $notchHeight, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class _$StartupStateCopyWith<$Res> implements $StartupStateCopyWith<$Res> {
  factory _$StartupStateCopyWith(_StartupState value, $Res Function(_StartupState) _then) = __$StartupStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {LoadStatus status,
      ActionStatus actionStatus,
      StartupConfigEntity? config,
      bool isObsoleteVersion,
      double notchHeight,
      Failure? failure});
}

/// @nodoc
class __$StartupStateCopyWithImpl<$Res> implements _$StartupStateCopyWith<$Res> {
  __$StartupStateCopyWithImpl(this._self, this._then);

  final _StartupState _self;
  final $Res Function(_StartupState) _then;

  /// Create a copy of StartupState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
    Object? config = freezed,
    Object? isObsoleteVersion = null,
    Object? notchHeight = null,
    Object? failure = freezed,
  }) {
    return _then(_StartupState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as LoadStatus,
      actionStatus: null == actionStatus
          ? _self.actionStatus
          : actionStatus // ignore: cast_nullable_to_non_nullable
              as ActionStatus,
      config: freezed == config
          ? _self.config
          : config // ignore: cast_nullable_to_non_nullable
              as StartupConfigEntity?,
      isObsoleteVersion: null == isObsoleteVersion
          ? _self.isObsoleteVersion
          : isObsoleteVersion // ignore: cast_nullable_to_non_nullable
              as bool,
      notchHeight: null == notchHeight
          ? _self.notchHeight
          : notchHeight // ignore: cast_nullable_to_non_nullable
              as double,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

// dart format on
