// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'quick_actions_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$QuickActionsEvent {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is QuickActionsEvent);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'QuickActionsEvent()';
  }
}

/// @nodoc
class $QuickActionsEventCopyWith<$Res> {
  $QuickActionsEventCopyWith(
      QuickActionsEvent _, $Res Function(QuickActionsEvent) __);
}

/// Adds pattern-matching-related methods to [QuickActionsEvent].
extension QuickActionsEventPatterns on QuickActionsEvent {
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
    TResult Function(_ShortcutsSetupRequested value)? shortcutsSetupRequested,
    TResult Function(_ActionReceived value)? actionReceived,
    TResult Function(_HistoryCleared value)? historyCleared,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _ShortcutsSetupRequested() when shortcutsSetupRequested != null:
        return shortcutsSetupRequested(_that);
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
    required TResult Function(_ShortcutsSetupRequested value)
        shortcutsSetupRequested,
    required TResult Function(_ActionReceived value) actionReceived,
    required TResult Function(_HistoryCleared value) historyCleared,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started(_that);
      case _ShortcutsSetupRequested():
        return shortcutsSetupRequested(_that);
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
    TResult? Function(_ShortcutsSetupRequested value)? shortcutsSetupRequested,
    TResult? Function(_ActionReceived value)? actionReceived,
    TResult? Function(_HistoryCleared value)? historyCleared,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _ShortcutsSetupRequested() when shortcutsSetupRequested != null:
        return shortcutsSetupRequested(_that);
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
    TResult Function(bool setupShortcuts)? started,
    TResult Function()? shortcutsSetupRequested,
    TResult Function(QuickActionEntity action)? actionReceived,
    TResult Function()? historyCleared,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that.setupShortcuts);
      case _ShortcutsSetupRequested() when shortcutsSetupRequested != null:
        return shortcutsSetupRequested();
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
    required TResult Function(bool setupShortcuts) started,
    required TResult Function() shortcutsSetupRequested,
    required TResult Function(QuickActionEntity action) actionReceived,
    required TResult Function() historyCleared,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started(_that.setupShortcuts);
      case _ShortcutsSetupRequested():
        return shortcutsSetupRequested();
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
    TResult? Function(bool setupShortcuts)? started,
    TResult? Function()? shortcutsSetupRequested,
    TResult? Function(QuickActionEntity action)? actionReceived,
    TResult? Function()? historyCleared,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that.setupShortcuts);
      case _ShortcutsSetupRequested() when shortcutsSetupRequested != null:
        return shortcutsSetupRequested();
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

class _Started implements QuickActionsEvent {
  const _Started({this.setupShortcuts = true});

  @JsonKey()
  final bool setupShortcuts;

  /// Create a copy of QuickActionsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$StartedCopyWith<_Started> get copyWith =>
      __$StartedCopyWithImpl<_Started>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Started &&
            (identical(other.setupShortcuts, setupShortcuts) ||
                other.setupShortcuts == setupShortcuts));
  }

  @override
  int get hashCode => Object.hash(runtimeType, setupShortcuts);

  @override
  String toString() {
    return 'QuickActionsEvent.started(setupShortcuts: $setupShortcuts)';
  }
}

/// @nodoc
abstract mixin class _$StartedCopyWith<$Res>
    implements $QuickActionsEventCopyWith<$Res> {
  factory _$StartedCopyWith(_Started value, $Res Function(_Started) _then) =
      __$StartedCopyWithImpl;
  @useResult
  $Res call({bool setupShortcuts});
}

/// @nodoc
class __$StartedCopyWithImpl<$Res> implements _$StartedCopyWith<$Res> {
  __$StartedCopyWithImpl(this._self, this._then);

  final _Started _self;
  final $Res Function(_Started) _then;

  /// Create a copy of QuickActionsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? setupShortcuts = null,
  }) {
    return _then(_Started(
      setupShortcuts: null == setupShortcuts
          ? _self.setupShortcuts
          : setupShortcuts // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _ShortcutsSetupRequested implements QuickActionsEvent {
  const _ShortcutsSetupRequested();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _ShortcutsSetupRequested);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'QuickActionsEvent.shortcutsSetupRequested()';
  }
}

/// @nodoc

class _ActionReceived implements QuickActionsEvent {
  const _ActionReceived(this.action);

  final QuickActionEntity action;

  /// Create a copy of QuickActionsEvent
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
    return 'QuickActionsEvent.actionReceived(action: $action)';
  }
}

/// @nodoc
abstract mixin class _$ActionReceivedCopyWith<$Res>
    implements $QuickActionsEventCopyWith<$Res> {
  factory _$ActionReceivedCopyWith(
          _ActionReceived value, $Res Function(_ActionReceived) _then) =
      __$ActionReceivedCopyWithImpl;
  @useResult
  $Res call({QuickActionEntity action});
}

/// @nodoc
class __$ActionReceivedCopyWithImpl<$Res>
    implements _$ActionReceivedCopyWith<$Res> {
  __$ActionReceivedCopyWithImpl(this._self, this._then);

  final _ActionReceived _self;
  final $Res Function(_ActionReceived) _then;

  /// Create a copy of QuickActionsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? action = null,
  }) {
    return _then(_ActionReceived(
      null == action
          ? _self.action
          : action // ignore: cast_nullable_to_non_nullable
              as QuickActionEntity,
    ));
  }
}

/// @nodoc

class _HistoryCleared implements QuickActionsEvent {
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
    return 'QuickActionsEvent.historyCleared()';
  }
}

/// @nodoc
mixin _$QuickActionsState {
  LoadStatus get status;
  ActionStatus get actionStatus;
  QuickActionEntity? get latestAction;
  List<QuickActionEntity> get history;
  Failure? get failure;

  /// Create a copy of QuickActionsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $QuickActionsStateCopyWith<QuickActionsState> get copyWith =>
      _$QuickActionsStateCopyWithImpl<QuickActionsState>(
          this as QuickActionsState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is QuickActionsState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) ||
                other.actionStatus == actionStatus) &&
            (identical(other.latestAction, latestAction) ||
                other.latestAction == latestAction) &&
            const DeepCollectionEquality().equals(other.history, history) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, actionStatus,
      latestAction, const DeepCollectionEquality().hash(history), failure);

  @override
  String toString() {
    return 'QuickActionsState(status: $status, actionStatus: $actionStatus, latestAction: $latestAction, history: $history, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class $QuickActionsStateCopyWith<$Res> {
  factory $QuickActionsStateCopyWith(
          QuickActionsState value, $Res Function(QuickActionsState) _then) =
      _$QuickActionsStateCopyWithImpl;
  @useResult
  $Res call(
      {LoadStatus status,
      ActionStatus actionStatus,
      QuickActionEntity? latestAction,
      List<QuickActionEntity> history,
      Failure? failure});
}

/// @nodoc
class _$QuickActionsStateCopyWithImpl<$Res>
    implements $QuickActionsStateCopyWith<$Res> {
  _$QuickActionsStateCopyWithImpl(this._self, this._then);

  final QuickActionsState _self;
  final $Res Function(QuickActionsState) _then;

  /// Create a copy of QuickActionsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
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
      latestAction: freezed == latestAction
          ? _self.latestAction
          : latestAction // ignore: cast_nullable_to_non_nullable
              as QuickActionEntity?,
      history: null == history
          ? _self.history
          : history // ignore: cast_nullable_to_non_nullable
              as List<QuickActionEntity>,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

/// Adds pattern-matching-related methods to [QuickActionsState].
extension QuickActionsStatePatterns on QuickActionsState {
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
    TResult Function(_QuickActionsState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _QuickActionsState() when $default != null:
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
    TResult Function(_QuickActionsState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _QuickActionsState():
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
    TResult? Function(_QuickActionsState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _QuickActionsState() when $default != null:
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
            QuickActionEntity? latestAction,
            List<QuickActionEntity> history,
            Failure? failure)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _QuickActionsState() when $default != null:
        return $default(_that.status, _that.actionStatus, _that.latestAction,
            _that.history, _that.failure);
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
            QuickActionEntity? latestAction,
            List<QuickActionEntity> history,
            Failure? failure)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _QuickActionsState():
        return $default(_that.status, _that.actionStatus, _that.latestAction,
            _that.history, _that.failure);
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
            QuickActionEntity? latestAction,
            List<QuickActionEntity> history,
            Failure? failure)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _QuickActionsState() when $default != null:
        return $default(_that.status, _that.actionStatus, _that.latestAction,
            _that.history, _that.failure);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _QuickActionsState implements QuickActionsState {
  const _QuickActionsState(
      {required this.status,
      required this.actionStatus,
      required this.latestAction,
      required final List<QuickActionEntity> history,
      this.failure})
      : _history = history;

  @override
  final LoadStatus status;
  @override
  final ActionStatus actionStatus;
  @override
  final QuickActionEntity? latestAction;
  final List<QuickActionEntity> _history;
  @override
  List<QuickActionEntity> get history {
    if (_history is EqualUnmodifiableListView) return _history;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_history);
  }

  @override
  final Failure? failure;

  /// Create a copy of QuickActionsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$QuickActionsStateCopyWith<_QuickActionsState> get copyWith =>
      __$QuickActionsStateCopyWithImpl<_QuickActionsState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _QuickActionsState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) ||
                other.actionStatus == actionStatus) &&
            (identical(other.latestAction, latestAction) ||
                other.latestAction == latestAction) &&
            const DeepCollectionEquality().equals(other._history, _history) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, actionStatus,
      latestAction, const DeepCollectionEquality().hash(_history), failure);

  @override
  String toString() {
    return 'QuickActionsState(status: $status, actionStatus: $actionStatus, latestAction: $latestAction, history: $history, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class _$QuickActionsStateCopyWith<$Res>
    implements $QuickActionsStateCopyWith<$Res> {
  factory _$QuickActionsStateCopyWith(
          _QuickActionsState value, $Res Function(_QuickActionsState) _then) =
      __$QuickActionsStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {LoadStatus status,
      ActionStatus actionStatus,
      QuickActionEntity? latestAction,
      List<QuickActionEntity> history,
      Failure? failure});
}

/// @nodoc
class __$QuickActionsStateCopyWithImpl<$Res>
    implements _$QuickActionsStateCopyWith<$Res> {
  __$QuickActionsStateCopyWithImpl(this._self, this._then);

  final _QuickActionsState _self;
  final $Res Function(_QuickActionsState) _then;

  /// Create a copy of QuickActionsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
    Object? latestAction = freezed,
    Object? history = null,
    Object? failure = freezed,
  }) {
    return _then(_QuickActionsState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as LoadStatus,
      actionStatus: null == actionStatus
          ? _self.actionStatus
          : actionStatus // ignore: cast_nullable_to_non_nullable
              as ActionStatus,
      latestAction: freezed == latestAction
          ? _self.latestAction
          : latestAction // ignore: cast_nullable_to_non_nullable
              as QuickActionEntity?,
      history: null == history
          ? _self._history
          : history // ignore: cast_nullable_to_non_nullable
              as List<QuickActionEntity>,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

// dart format on
