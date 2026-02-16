// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'connectivity_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ConnectivityEvent {
  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType && other is ConnectivityEvent);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'ConnectivityEvent()';
  }
}

/// @nodoc
class $ConnectivityEventCopyWith<$Res> {
  $ConnectivityEventCopyWith(ConnectivityEvent _, $Res Function(ConnectivityEvent) __);
}

/// Adds pattern-matching-related methods to [ConnectivityEvent].
extension ConnectivityEventPatterns on ConnectivityEvent {
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
    TResult Function(_StatusChanged value)? statusChanged,
    TResult Function(_RecheckRequested value)? recheckRequested,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _StatusChanged() when statusChanged != null:
        return statusChanged(_that);
      case _RecheckRequested() when recheckRequested != null:
        return recheckRequested(_that);
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
    required TResult Function(_StatusChanged value) statusChanged,
    required TResult Function(_RecheckRequested value) recheckRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started(_that);
      case _StatusChanged():
        return statusChanged(_that);
      case _RecheckRequested():
        return recheckRequested(_that);
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
    TResult? Function(_StatusChanged value)? statusChanged,
    TResult? Function(_RecheckRequested value)? recheckRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _StatusChanged() when statusChanged != null:
        return statusChanged(_that);
      case _RecheckRequested() when recheckRequested != null:
        return recheckRequested(_that);
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
    TResult Function(ConnectivityEntity connectivity)? statusChanged,
    TResult Function()? recheckRequested,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started();
      case _StatusChanged() when statusChanged != null:
        return statusChanged(_that.connectivity);
      case _RecheckRequested() when recheckRequested != null:
        return recheckRequested();
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
    required TResult Function(ConnectivityEntity connectivity) statusChanged,
    required TResult Function() recheckRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started();
      case _StatusChanged():
        return statusChanged(_that.connectivity);
      case _RecheckRequested():
        return recheckRequested();
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
    TResult? Function(ConnectivityEntity connectivity)? statusChanged,
    TResult? Function()? recheckRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started();
      case _StatusChanged() when statusChanged != null:
        return statusChanged(_that.connectivity);
      case _RecheckRequested() when recheckRequested != null:
        return recheckRequested();
      case _:
        return null;
    }
  }
}

/// @nodoc

class _Started implements ConnectivityEvent {
  const _Started();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType && other is _Started);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'ConnectivityEvent.started()';
  }
}

/// @nodoc

class _StatusChanged implements ConnectivityEvent {
  const _StatusChanged(this.connectivity);

  final ConnectivityEntity connectivity;

  /// Create a copy of ConnectivityEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$StatusChangedCopyWith<_StatusChanged> get copyWith =>
      __$StatusChangedCopyWithImpl<_StatusChanged>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _StatusChanged &&
            (identical(other.connectivity, connectivity) || other.connectivity == connectivity));
  }

  @override
  int get hashCode => Object.hash(runtimeType, connectivity);

  @override
  String toString() {
    return 'ConnectivityEvent.statusChanged(connectivity: $connectivity)';
  }
}

/// @nodoc
abstract mixin class _$StatusChangedCopyWith<$Res> implements $ConnectivityEventCopyWith<$Res> {
  factory _$StatusChangedCopyWith(_StatusChanged value, $Res Function(_StatusChanged) _then) =
      __$StatusChangedCopyWithImpl;
  @useResult
  $Res call({ConnectivityEntity connectivity});
}

/// @nodoc
class __$StatusChangedCopyWithImpl<$Res> implements _$StatusChangedCopyWith<$Res> {
  __$StatusChangedCopyWithImpl(this._self, this._then);

  final _StatusChanged _self;
  final $Res Function(_StatusChanged) _then;

  /// Create a copy of ConnectivityEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? connectivity = null,
  }) {
    return _then(_StatusChanged(
      null == connectivity
          ? _self.connectivity
          : connectivity // ignore: cast_nullable_to_non_nullable
              as ConnectivityEntity,
    ));
  }
}

/// @nodoc

class _RecheckRequested implements ConnectivityEvent {
  const _RecheckRequested();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType && other is _RecheckRequested);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'ConnectivityEvent.recheckRequested()';
  }
}

/// @nodoc
mixin _$ConnectivityState {
  LoadStatus get status;
  ActionStatus get actionStatus;
  ConnectivityEntity get connectivity;
  Failure? get failure;

  /// Create a copy of ConnectivityState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ConnectivityStateCopyWith<ConnectivityState> get copyWith =>
      _$ConnectivityStateCopyWithImpl<ConnectivityState>(this as ConnectivityState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ConnectivityState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus) &&
            (identical(other.connectivity, connectivity) || other.connectivity == connectivity) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, actionStatus, connectivity, failure);

  @override
  String toString() {
    return 'ConnectivityState(status: $status, actionStatus: $actionStatus, connectivity: $connectivity, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class $ConnectivityStateCopyWith<$Res> {
  factory $ConnectivityStateCopyWith(ConnectivityState value, $Res Function(ConnectivityState) _then) =
      _$ConnectivityStateCopyWithImpl;
  @useResult
  $Res call({LoadStatus status, ActionStatus actionStatus, ConnectivityEntity connectivity, Failure? failure});
}

/// @nodoc
class _$ConnectivityStateCopyWithImpl<$Res> implements $ConnectivityStateCopyWith<$Res> {
  _$ConnectivityStateCopyWithImpl(this._self, this._then);

  final ConnectivityState _self;
  final $Res Function(ConnectivityState) _then;

  /// Create a copy of ConnectivityState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
    Object? connectivity = null,
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
      connectivity: null == connectivity
          ? _self.connectivity
          : connectivity // ignore: cast_nullable_to_non_nullable
              as ConnectivityEntity,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ConnectivityState].
extension ConnectivityStatePatterns on ConnectivityState {
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
    TResult Function(_ConnectivityState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ConnectivityState() when $default != null:
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
    TResult Function(_ConnectivityState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ConnectivityState():
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
    TResult? Function(_ConnectivityState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ConnectivityState() when $default != null:
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
    TResult Function(LoadStatus status, ActionStatus actionStatus, ConnectivityEntity connectivity, Failure? failure)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ConnectivityState() when $default != null:
        return $default(_that.status, _that.actionStatus, _that.connectivity, _that.failure);
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
    TResult Function(LoadStatus status, ActionStatus actionStatus, ConnectivityEntity connectivity, Failure? failure)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ConnectivityState():
        return $default(_that.status, _that.actionStatus, _that.connectivity, _that.failure);
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
    TResult? Function(LoadStatus status, ActionStatus actionStatus, ConnectivityEntity connectivity, Failure? failure)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ConnectivityState() when $default != null:
        return $default(_that.status, _that.actionStatus, _that.connectivity, _that.failure);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ConnectivityState implements ConnectivityState {
  const _ConnectivityState(
      {required this.status, required this.actionStatus, required this.connectivity, this.failure});

  @override
  final LoadStatus status;
  @override
  final ActionStatus actionStatus;
  @override
  final ConnectivityEntity connectivity;
  @override
  final Failure? failure;

  /// Create a copy of ConnectivityState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ConnectivityStateCopyWith<_ConnectivityState> get copyWith =>
      __$ConnectivityStateCopyWithImpl<_ConnectivityState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ConnectivityState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus) &&
            (identical(other.connectivity, connectivity) || other.connectivity == connectivity) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, actionStatus, connectivity, failure);

  @override
  String toString() {
    return 'ConnectivityState(status: $status, actionStatus: $actionStatus, connectivity: $connectivity, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class _$ConnectivityStateCopyWith<$Res> implements $ConnectivityStateCopyWith<$Res> {
  factory _$ConnectivityStateCopyWith(_ConnectivityState value, $Res Function(_ConnectivityState) _then) =
      __$ConnectivityStateCopyWithImpl;
  @override
  @useResult
  $Res call({LoadStatus status, ActionStatus actionStatus, ConnectivityEntity connectivity, Failure? failure});
}

/// @nodoc
class __$ConnectivityStateCopyWithImpl<$Res> implements _$ConnectivityStateCopyWith<$Res> {
  __$ConnectivityStateCopyWithImpl(this._self, this._then);

  final _ConnectivityState _self;
  final $Res Function(_ConnectivityState) _then;

  /// Create a copy of ConnectivityState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
    Object? connectivity = null,
    Object? failure = freezed,
  }) {
    return _then(_ConnectivityState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as LoadStatus,
      actionStatus: null == actionStatus
          ? _self.actionStatus
          : actionStatus // ignore: cast_nullable_to_non_nullable
              as ActionStatus,
      connectivity: null == connectivity
          ? _self.connectivity
          : connectivity // ignore: cast_nullable_to_non_nullable
              as ConnectivityEntity,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

// dart format on
