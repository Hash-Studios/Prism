// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'navigation_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NavigationEvent {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is NavigationEvent);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'NavigationEvent()';
  }
}

/// @nodoc
class $NavigationEventCopyWith<$Res> {
  $NavigationEventCopyWith(
      NavigationEvent _, $Res Function(NavigationEvent) __);
}

/// Adds pattern-matching-related methods to [NavigationEvent].
extension NavigationEventPatterns on NavigationEvent {
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
    TResult Function(_RoutePushed value)? routePushed,
    TResult Function(_RoutePopped value)? routePopped,
    TResult Function(_ResetRequested value)? resetRequested,
    TResult Function(_StackReplaced value)? stackReplaced,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _RoutePushed() when routePushed != null:
        return routePushed(_that);
      case _RoutePopped() when routePopped != null:
        return routePopped(_that);
      case _ResetRequested() when resetRequested != null:
        return resetRequested(_that);
      case _StackReplaced() when stackReplaced != null:
        return stackReplaced(_that);
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
    required TResult Function(_RoutePushed value) routePushed,
    required TResult Function(_RoutePopped value) routePopped,
    required TResult Function(_ResetRequested value) resetRequested,
    required TResult Function(_StackReplaced value) stackReplaced,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started(_that);
      case _RoutePushed():
        return routePushed(_that);
      case _RoutePopped():
        return routePopped(_that);
      case _ResetRequested():
        return resetRequested(_that);
      case _StackReplaced():
        return stackReplaced(_that);
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
    TResult? Function(_RoutePushed value)? routePushed,
    TResult? Function(_RoutePopped value)? routePopped,
    TResult? Function(_ResetRequested value)? resetRequested,
    TResult? Function(_StackReplaced value)? stackReplaced,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _RoutePushed() when routePushed != null:
        return routePushed(_that);
      case _RoutePopped() when routePopped != null:
        return routePopped(_that);
      case _ResetRequested() when resetRequested != null:
        return resetRequested(_that);
      case _StackReplaced() when stackReplaced != null:
        return stackReplaced(_that);
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
    TResult Function(String routeName)? routePushed,
    TResult Function()? routePopped,
    TResult Function(String initialRoute)? resetRequested,
    TResult Function(List<String> stack)? stackReplaced,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started();
      case _RoutePushed() when routePushed != null:
        return routePushed(_that.routeName);
      case _RoutePopped() when routePopped != null:
        return routePopped();
      case _ResetRequested() when resetRequested != null:
        return resetRequested(_that.initialRoute);
      case _StackReplaced() when stackReplaced != null:
        return stackReplaced(_that.stack);
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
    required TResult Function(String routeName) routePushed,
    required TResult Function() routePopped,
    required TResult Function(String initialRoute) resetRequested,
    required TResult Function(List<String> stack) stackReplaced,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started();
      case _RoutePushed():
        return routePushed(_that.routeName);
      case _RoutePopped():
        return routePopped();
      case _ResetRequested():
        return resetRequested(_that.initialRoute);
      case _StackReplaced():
        return stackReplaced(_that.stack);
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
    TResult? Function(String routeName)? routePushed,
    TResult? Function()? routePopped,
    TResult? Function(String initialRoute)? resetRequested,
    TResult? Function(List<String> stack)? stackReplaced,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started();
      case _RoutePushed() when routePushed != null:
        return routePushed(_that.routeName);
      case _RoutePopped() when routePopped != null:
        return routePopped();
      case _ResetRequested() when resetRequested != null:
        return resetRequested(_that.initialRoute);
      case _StackReplaced() when stackReplaced != null:
        return stackReplaced(_that.stack);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _Started implements NavigationEvent {
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
    return 'NavigationEvent.started()';
  }
}

/// @nodoc

class _RoutePushed implements NavigationEvent {
  const _RoutePushed({required this.routeName});

  final String routeName;

  /// Create a copy of NavigationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RoutePushedCopyWith<_RoutePushed> get copyWith =>
      __$RoutePushedCopyWithImpl<_RoutePushed>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RoutePushed &&
            (identical(other.routeName, routeName) ||
                other.routeName == routeName));
  }

  @override
  int get hashCode => Object.hash(runtimeType, routeName);

  @override
  String toString() {
    return 'NavigationEvent.routePushed(routeName: $routeName)';
  }
}

/// @nodoc
abstract mixin class _$RoutePushedCopyWith<$Res>
    implements $NavigationEventCopyWith<$Res> {
  factory _$RoutePushedCopyWith(
          _RoutePushed value, $Res Function(_RoutePushed) _then) =
      __$RoutePushedCopyWithImpl;
  @useResult
  $Res call({String routeName});
}

/// @nodoc
class __$RoutePushedCopyWithImpl<$Res> implements _$RoutePushedCopyWith<$Res> {
  __$RoutePushedCopyWithImpl(this._self, this._then);

  final _RoutePushed _self;
  final $Res Function(_RoutePushed) _then;

  /// Create a copy of NavigationEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? routeName = null,
  }) {
    return _then(_RoutePushed(
      routeName: null == routeName
          ? _self.routeName
          : routeName // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _RoutePopped implements NavigationEvent {
  const _RoutePopped();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _RoutePopped);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'NavigationEvent.routePopped()';
  }
}

/// @nodoc

class _ResetRequested implements NavigationEvent {
  const _ResetRequested({this.initialRoute = 'Home'});

  @JsonKey()
  final String initialRoute;

  /// Create a copy of NavigationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ResetRequestedCopyWith<_ResetRequested> get copyWith =>
      __$ResetRequestedCopyWithImpl<_ResetRequested>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ResetRequested &&
            (identical(other.initialRoute, initialRoute) ||
                other.initialRoute == initialRoute));
  }

  @override
  int get hashCode => Object.hash(runtimeType, initialRoute);

  @override
  String toString() {
    return 'NavigationEvent.resetRequested(initialRoute: $initialRoute)';
  }
}

/// @nodoc
abstract mixin class _$ResetRequestedCopyWith<$Res>
    implements $NavigationEventCopyWith<$Res> {
  factory _$ResetRequestedCopyWith(
          _ResetRequested value, $Res Function(_ResetRequested) _then) =
      __$ResetRequestedCopyWithImpl;
  @useResult
  $Res call({String initialRoute});
}

/// @nodoc
class __$ResetRequestedCopyWithImpl<$Res>
    implements _$ResetRequestedCopyWith<$Res> {
  __$ResetRequestedCopyWithImpl(this._self, this._then);

  final _ResetRequested _self;
  final $Res Function(_ResetRequested) _then;

  /// Create a copy of NavigationEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? initialRoute = null,
  }) {
    return _then(_ResetRequested(
      initialRoute: null == initialRoute
          ? _self.initialRoute
          : initialRoute // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _StackReplaced implements NavigationEvent {
  const _StackReplaced({required final List<String> stack}) : _stack = stack;

  final List<String> _stack;
  List<String> get stack {
    if (_stack is EqualUnmodifiableListView) return _stack;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_stack);
  }

  /// Create a copy of NavigationEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$StackReplacedCopyWith<_StackReplaced> get copyWith =>
      __$StackReplacedCopyWithImpl<_StackReplaced>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _StackReplaced &&
            const DeepCollectionEquality().equals(other._stack, _stack));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_stack));

  @override
  String toString() {
    return 'NavigationEvent.stackReplaced(stack: $stack)';
  }
}

/// @nodoc
abstract mixin class _$StackReplacedCopyWith<$Res>
    implements $NavigationEventCopyWith<$Res> {
  factory _$StackReplacedCopyWith(
          _StackReplaced value, $Res Function(_StackReplaced) _then) =
      __$StackReplacedCopyWithImpl;
  @useResult
  $Res call({List<String> stack});
}

/// @nodoc
class __$StackReplacedCopyWithImpl<$Res>
    implements _$StackReplacedCopyWith<$Res> {
  __$StackReplacedCopyWithImpl(this._self, this._then);

  final _StackReplaced _self;
  final $Res Function(_StackReplaced) _then;

  /// Create a copy of NavigationEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? stack = null,
  }) {
    return _then(_StackReplaced(
      stack: null == stack
          ? _self._stack
          : stack // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
mixin _$NavigationState {
  LoadStatus get status;
  ActionStatus get actionStatus;
  List<String> get stack;
  String get currentRoute;
  bool get canPop;
  Failure? get failure;

  /// Create a copy of NavigationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $NavigationStateCopyWith<NavigationState> get copyWith =>
      _$NavigationStateCopyWithImpl<NavigationState>(
          this as NavigationState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is NavigationState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) ||
                other.actionStatus == actionStatus) &&
            const DeepCollectionEquality().equals(other.stack, stack) &&
            (identical(other.currentRoute, currentRoute) ||
                other.currentRoute == currentRoute) &&
            (identical(other.canPop, canPop) || other.canPop == canPop) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      actionStatus,
      const DeepCollectionEquality().hash(stack),
      currentRoute,
      canPop,
      failure);

  @override
  String toString() {
    return 'NavigationState(status: $status, actionStatus: $actionStatus, stack: $stack, currentRoute: $currentRoute, canPop: $canPop, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class $NavigationStateCopyWith<$Res> {
  factory $NavigationStateCopyWith(
          NavigationState value, $Res Function(NavigationState) _then) =
      _$NavigationStateCopyWithImpl;
  @useResult
  $Res call(
      {LoadStatus status,
      ActionStatus actionStatus,
      List<String> stack,
      String currentRoute,
      bool canPop,
      Failure? failure});
}

/// @nodoc
class _$NavigationStateCopyWithImpl<$Res>
    implements $NavigationStateCopyWith<$Res> {
  _$NavigationStateCopyWithImpl(this._self, this._then);

  final NavigationState _self;
  final $Res Function(NavigationState) _then;

  /// Create a copy of NavigationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
    Object? stack = null,
    Object? currentRoute = null,
    Object? canPop = null,
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
      stack: null == stack
          ? _self.stack
          : stack // ignore: cast_nullable_to_non_nullable
              as List<String>,
      currentRoute: null == currentRoute
          ? _self.currentRoute
          : currentRoute // ignore: cast_nullable_to_non_nullable
              as String,
      canPop: null == canPop
          ? _self.canPop
          : canPop // ignore: cast_nullable_to_non_nullable
              as bool,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

/// Adds pattern-matching-related methods to [NavigationState].
extension NavigationStatePatterns on NavigationState {
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
    TResult Function(_NavigationState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NavigationState() when $default != null:
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
    TResult Function(_NavigationState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NavigationState():
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
    TResult? Function(_NavigationState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NavigationState() when $default != null:
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
            List<String> stack,
            String currentRoute,
            bool canPop,
            Failure? failure)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NavigationState() when $default != null:
        return $default(_that.status, _that.actionStatus, _that.stack,
            _that.currentRoute, _that.canPop, _that.failure);
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
            List<String> stack,
            String currentRoute,
            bool canPop,
            Failure? failure)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NavigationState():
        return $default(_that.status, _that.actionStatus, _that.stack,
            _that.currentRoute, _that.canPop, _that.failure);
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
            List<String> stack,
            String currentRoute,
            bool canPop,
            Failure? failure)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NavigationState() when $default != null:
        return $default(_that.status, _that.actionStatus, _that.stack,
            _that.currentRoute, _that.canPop, _that.failure);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _NavigationState implements NavigationState {
  const _NavigationState(
      {required this.status,
      required this.actionStatus,
      required final List<String> stack,
      required this.currentRoute,
      required this.canPop,
      this.failure})
      : _stack = stack;

  @override
  final LoadStatus status;
  @override
  final ActionStatus actionStatus;
  final List<String> _stack;
  @override
  List<String> get stack {
    if (_stack is EqualUnmodifiableListView) return _stack;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_stack);
  }

  @override
  final String currentRoute;
  @override
  final bool canPop;
  @override
  final Failure? failure;

  /// Create a copy of NavigationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$NavigationStateCopyWith<_NavigationState> get copyWith =>
      __$NavigationStateCopyWithImpl<_NavigationState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _NavigationState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) ||
                other.actionStatus == actionStatus) &&
            const DeepCollectionEquality().equals(other._stack, _stack) &&
            (identical(other.currentRoute, currentRoute) ||
                other.currentRoute == currentRoute) &&
            (identical(other.canPop, canPop) || other.canPop == canPop) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      status,
      actionStatus,
      const DeepCollectionEquality().hash(_stack),
      currentRoute,
      canPop,
      failure);

  @override
  String toString() {
    return 'NavigationState(status: $status, actionStatus: $actionStatus, stack: $stack, currentRoute: $currentRoute, canPop: $canPop, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class _$NavigationStateCopyWith<$Res>
    implements $NavigationStateCopyWith<$Res> {
  factory _$NavigationStateCopyWith(
          _NavigationState value, $Res Function(_NavigationState) _then) =
      __$NavigationStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {LoadStatus status,
      ActionStatus actionStatus,
      List<String> stack,
      String currentRoute,
      bool canPop,
      Failure? failure});
}

/// @nodoc
class __$NavigationStateCopyWithImpl<$Res>
    implements _$NavigationStateCopyWith<$Res> {
  __$NavigationStateCopyWithImpl(this._self, this._then);

  final _NavigationState _self;
  final $Res Function(_NavigationState) _then;

  /// Create a copy of NavigationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
    Object? stack = null,
    Object? currentRoute = null,
    Object? canPop = null,
    Object? failure = freezed,
  }) {
    return _then(_NavigationState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as LoadStatus,
      actionStatus: null == actionStatus
          ? _self.actionStatus
          : actionStatus // ignore: cast_nullable_to_non_nullable
              as ActionStatus,
      stack: null == stack
          ? _self._stack
          : stack // ignore: cast_nullable_to_non_nullable
              as List<String>,
      currentRoute: null == currentRoute
          ? _self.currentRoute
          : currentRoute // ignore: cast_nullable_to_non_nullable
              as String,
      canPop: null == canPop
          ? _self.canPop
          : canPop // ignore: cast_nullable_to_non_nullable
              as bool,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

// dart format on
