// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'deep_link_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeepLinkEvent {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is DeepLinkEvent);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'DeepLinkEvent()';
  }
}

/// @nodoc
class $DeepLinkEventCopyWith<$Res> {
  $DeepLinkEventCopyWith(DeepLinkEvent _, $Res Function(DeepLinkEvent) __);
}

/// Adds pattern-matching-related methods to [DeepLinkEvent].
extension DeepLinkEventPatterns on DeepLinkEvent {
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
    TResult Function(_ActionReceived value)? actionReceived,
    TResult Function(_HistoryCleared value)? historyCleared,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _ActionReceived() when actionReceived != null:
        return actionReceived(_that);
      case _HistoryCleared() when historyCleared != null:
        return historyCleared(_that);
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
    required TResult Function(_ActionReceived value) actionReceived,
    required TResult Function(_HistoryCleared value) historyCleared,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started(_that);
      case _ActionReceived():
        return actionReceived(_that);
      case _HistoryCleared():
        return historyCleared(_that);
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
    TResult? Function(_ActionReceived value)? actionReceived,
    TResult? Function(_HistoryCleared value)? historyCleared,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _ActionReceived() when actionReceived != null:
        return actionReceived(_that);
      case _HistoryCleared() when historyCleared != null:
        return historyCleared(_that);
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
    TResult Function(DeepLinkActionEntity action)? actionReceived,
    TResult Function()? historyCleared,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started();
      case _ActionReceived() when actionReceived != null:
        return actionReceived(_that.action);
      case _HistoryCleared() when historyCleared != null:
        return historyCleared();
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
    required TResult Function(DeepLinkActionEntity action) actionReceived,
    required TResult Function() historyCleared,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started();
      case _ActionReceived():
        return actionReceived(_that.action);
      case _HistoryCleared():
        return historyCleared();
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
    TResult? Function(DeepLinkActionEntity action)? actionReceived,
    TResult? Function()? historyCleared,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started();
      case _ActionReceived() when actionReceived != null:
        return actionReceived(_that.action);
      case _HistoryCleared() when historyCleared != null:
        return historyCleared();
      case _:
        return null;
    }
  }
}

/// @nodoc

class _Started implements DeepLinkEvent {
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
    return 'DeepLinkEvent.started()';
  }
}

/// @nodoc

class _ActionReceived implements DeepLinkEvent {
  const _ActionReceived(this.action);

  final DeepLinkActionEntity action;

  /// Create a copy of DeepLinkEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ActionReceivedCopyWith<_ActionReceived> get copyWith =>
      __$ActionReceivedCopyWithImpl<_ActionReceived>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ActionReceived &&
            (identical(other.action, action) || other.action == action));
  }

  @override
  int get hashCode => Object.hash(runtimeType, action);

  @override
  String toString() {
    return 'DeepLinkEvent.actionReceived(action: $action)';
  }
}

/// @nodoc
abstract mixin class _$ActionReceivedCopyWith<$Res>
    implements $DeepLinkEventCopyWith<$Res> {
  factory _$ActionReceivedCopyWith(
          _ActionReceived value, $Res Function(_ActionReceived) _then) =
      __$ActionReceivedCopyWithImpl;
  @useResult
  $Res call({DeepLinkActionEntity action});
}

/// @nodoc
class __$ActionReceivedCopyWithImpl<$Res>
    implements _$ActionReceivedCopyWith<$Res> {
  __$ActionReceivedCopyWithImpl(this._self, this._then);

  final _ActionReceived _self;
  final $Res Function(_ActionReceived) _then;

  /// Create a copy of DeepLinkEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? action = null,
  }) {
    return _then(_ActionReceived(
      null == action
          ? _self.action
          : action // ignore: cast_nullable_to_non_nullable
              as DeepLinkActionEntity,
    ));
  }
}

/// @nodoc

class _HistoryCleared implements DeepLinkEvent {
  const _HistoryCleared();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _HistoryCleared);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'DeepLinkEvent.historyCleared()';
  }
}

/// @nodoc
mixin _$DeepLinkState {
  LoadStatus get status;
  ActionStatus get actionStatus;
  DeepLinkActionEntity? get initialAction;
  DeepLinkActionEntity? get latestAction;
  List<DeepLinkActionEntity> get history;
  Failure? get failure;

  /// Create a copy of DeepLinkState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DeepLinkStateCopyWith<DeepLinkState> get copyWith =>
      _$DeepLinkStateCopyWithImpl<DeepLinkState>(
          this as DeepLinkState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DeepLinkState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) ||
                other.actionStatus == actionStatus) &&
            (identical(other.initialAction, initialAction) ||
                other.initialAction == initialAction) &&
            (identical(other.latestAction, latestAction) ||
                other.latestAction == latestAction) &&
            const DeepCollectionEquality().equals(other.history, history) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      actionStatus,
      initialAction,
      latestAction,
      const DeepCollectionEquality().hash(history),
      failure);

  @override
  String toString() {
    return 'DeepLinkState(status: $status, actionStatus: $actionStatus, initialAction: $initialAction, latestAction: $latestAction, history: $history, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class $DeepLinkStateCopyWith<$Res> {
  factory $DeepLinkStateCopyWith(
          DeepLinkState value, $Res Function(DeepLinkState) _then) =
      _$DeepLinkStateCopyWithImpl;
  @useResult
  $Res call(
      {LoadStatus status,
      ActionStatus actionStatus,
      DeepLinkActionEntity? initialAction,
      DeepLinkActionEntity? latestAction,
      List<DeepLinkActionEntity> history,
      Failure? failure});
}

/// @nodoc
class _$DeepLinkStateCopyWithImpl<$Res>
    implements $DeepLinkStateCopyWith<$Res> {
  _$DeepLinkStateCopyWithImpl(this._self, this._then);

  final DeepLinkState _self;
  final $Res Function(DeepLinkState) _then;

  /// Create a copy of DeepLinkState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
    Object? initialAction = freezed,
    Object? latestAction = freezed,
    Object? history = null,
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
      initialAction: freezed == initialAction
          ? _self.initialAction
          : initialAction // ignore: cast_nullable_to_non_nullable
              as DeepLinkActionEntity?,
      latestAction: freezed == latestAction
          ? _self.latestAction
          : latestAction // ignore: cast_nullable_to_non_nullable
              as DeepLinkActionEntity?,
      history: null == history
          ? _self.history
          : history // ignore: cast_nullable_to_non_nullable
              as List<DeepLinkActionEntity>,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

/// Adds pattern-matching-related methods to [DeepLinkState].
extension DeepLinkStatePatterns on DeepLinkState {
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
    TResult Function(_DeepLinkState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DeepLinkState() when $default != null:
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
    TResult Function(_DeepLinkState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DeepLinkState():
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
    TResult? Function(_DeepLinkState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DeepLinkState() when $default != null:
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
    TResult Function(
            LoadStatus status,
            ActionStatus actionStatus,
            DeepLinkActionEntity? initialAction,
            DeepLinkActionEntity? latestAction,
            List<DeepLinkActionEntity> history,
            Failure? failure)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DeepLinkState() when $default != null:
        return $default(_that.status, _that.actionStatus, _that.initialAction,
            _that.latestAction, _that.history, _that.failure);
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
    TResult Function(
            LoadStatus status,
            ActionStatus actionStatus,
            DeepLinkActionEntity? initialAction,
            DeepLinkActionEntity? latestAction,
            List<DeepLinkActionEntity> history,
            Failure? failure)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DeepLinkState():
        return $default(_that.status, _that.actionStatus, _that.initialAction,
            _that.latestAction, _that.history, _that.failure);
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
    TResult? Function(
            LoadStatus status,
            ActionStatus actionStatus,
            DeepLinkActionEntity? initialAction,
            DeepLinkActionEntity? latestAction,
            List<DeepLinkActionEntity> history,
            Failure? failure)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DeepLinkState() when $default != null:
        return $default(_that.status, _that.actionStatus, _that.initialAction,
            _that.latestAction, _that.history, _that.failure);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _DeepLinkState implements DeepLinkState {
  const _DeepLinkState(
      {required this.status,
      required this.actionStatus,
      required this.initialAction,
      required this.latestAction,
      required final List<DeepLinkActionEntity> history,
      this.failure})
      : _history = history;

  @override
  final LoadStatus status;
  @override
  final ActionStatus actionStatus;
  @override
  final DeepLinkActionEntity? initialAction;
  @override
  final DeepLinkActionEntity? latestAction;
  final List<DeepLinkActionEntity> _history;
  @override
  List<DeepLinkActionEntity> get history {
    if (_history is EqualUnmodifiableListView) return _history;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_history);
  }

  @override
  final Failure? failure;

  /// Create a copy of DeepLinkState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DeepLinkStateCopyWith<_DeepLinkState> get copyWith =>
      __$DeepLinkStateCopyWithImpl<_DeepLinkState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DeepLinkState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) ||
                other.actionStatus == actionStatus) &&
            (identical(other.initialAction, initialAction) ||
                other.initialAction == initialAction) &&
            (identical(other.latestAction, latestAction) ||
                other.latestAction == latestAction) &&
            const DeepCollectionEquality().equals(other._history, _history) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      actionStatus,
      initialAction,
      latestAction,
      const DeepCollectionEquality().hash(_history),
      failure);

  @override
  String toString() {
    return 'DeepLinkState(status: $status, actionStatus: $actionStatus, initialAction: $initialAction, latestAction: $latestAction, history: $history, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class _$DeepLinkStateCopyWith<$Res>
    implements $DeepLinkStateCopyWith<$Res> {
  factory _$DeepLinkStateCopyWith(
          _DeepLinkState value, $Res Function(_DeepLinkState) _then) =
      __$DeepLinkStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {LoadStatus status,
      ActionStatus actionStatus,
      DeepLinkActionEntity? initialAction,
      DeepLinkActionEntity? latestAction,
      List<DeepLinkActionEntity> history,
      Failure? failure});
}

/// @nodoc
class __$DeepLinkStateCopyWithImpl<$Res>
    implements _$DeepLinkStateCopyWith<$Res> {
  __$DeepLinkStateCopyWithImpl(this._self, this._then);

  final _DeepLinkState _self;
  final $Res Function(_DeepLinkState) _then;

  /// Create a copy of DeepLinkState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
    Object? initialAction = freezed,
    Object? latestAction = freezed,
    Object? history = null,
    Object? failure = freezed,
  }) {
    return _then(_DeepLinkState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as LoadStatus,
      actionStatus: null == actionStatus
          ? _self.actionStatus
          : actionStatus // ignore: cast_nullable_to_non_nullable
              as ActionStatus,
      initialAction: freezed == initialAction
          ? _self.initialAction
          : initialAction // ignore: cast_nullable_to_non_nullable
              as DeepLinkActionEntity?,
      latestAction: freezed == latestAction
          ? _self.latestAction
          : latestAction // ignore: cast_nullable_to_non_nullable
              as DeepLinkActionEntity?,
      history: null == history
          ? _self._history
          : history // ignore: cast_nullable_to_non_nullable
              as List<DeepLinkActionEntity>,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

// dart format on
