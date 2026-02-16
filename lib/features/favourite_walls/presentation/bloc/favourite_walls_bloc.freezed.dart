// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'favourite_walls_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FavouriteWallsEvent {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is FavouriteWallsEvent);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'FavouriteWallsEvent()';
  }
}

/// @nodoc
class $FavouriteWallsEventCopyWith<$Res> {
  $FavouriteWallsEventCopyWith(
      FavouriteWallsEvent _, $Res Function(FavouriteWallsEvent) __);
}

/// Adds pattern-matching-related methods to [FavouriteWallsEvent].
extension FavouriteWallsEventPatterns on FavouriteWallsEvent {
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
    TResult Function(_RefreshRequested value)? refreshRequested,
    TResult Function(_ToggleRequested value)? toggleRequested,
    TResult Function(_RemoveRequested value)? removeRequested,
    TResult Function(_ClearRequested value)? clearRequested,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _RefreshRequested() when refreshRequested != null:
        return refreshRequested(_that);
      case _ToggleRequested() when toggleRequested != null:
        return toggleRequested(_that);
      case _RemoveRequested() when removeRequested != null:
        return removeRequested(_that);
      case _ClearRequested() when clearRequested != null:
        return clearRequested(_that);
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
    required TResult Function(_RefreshRequested value) refreshRequested,
    required TResult Function(_ToggleRequested value) toggleRequested,
    required TResult Function(_RemoveRequested value) removeRequested,
    required TResult Function(_ClearRequested value) clearRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started(_that);
      case _RefreshRequested():
        return refreshRequested(_that);
      case _ToggleRequested():
        return toggleRequested(_that);
      case _RemoveRequested():
        return removeRequested(_that);
      case _ClearRequested():
        return clearRequested(_that);
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
    TResult? Function(_RefreshRequested value)? refreshRequested,
    TResult? Function(_ToggleRequested value)? toggleRequested,
    TResult? Function(_RemoveRequested value)? removeRequested,
    TResult? Function(_ClearRequested value)? clearRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _RefreshRequested() when refreshRequested != null:
        return refreshRequested(_that);
      case _ToggleRequested() when toggleRequested != null:
        return toggleRequested(_that);
      case _RemoveRequested() when removeRequested != null:
        return removeRequested(_that);
      case _ClearRequested() when clearRequested != null:
        return clearRequested(_that);
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
    TResult Function(String userId)? started,
    TResult Function()? refreshRequested,
    TResult Function(FavouriteWallEntity wall)? toggleRequested,
    TResult Function(String wallId)? removeRequested,
    TResult Function()? clearRequested,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that.userId);
      case _RefreshRequested() when refreshRequested != null:
        return refreshRequested();
      case _ToggleRequested() when toggleRequested != null:
        return toggleRequested(_that.wall);
      case _RemoveRequested() when removeRequested != null:
        return removeRequested(_that.wallId);
      case _ClearRequested() when clearRequested != null:
        return clearRequested();
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
    required TResult Function(String userId) started,
    required TResult Function() refreshRequested,
    required TResult Function(FavouriteWallEntity wall) toggleRequested,
    required TResult Function(String wallId) removeRequested,
    required TResult Function() clearRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started(_that.userId);
      case _RefreshRequested():
        return refreshRequested();
      case _ToggleRequested():
        return toggleRequested(_that.wall);
      case _RemoveRequested():
        return removeRequested(_that.wallId);
      case _ClearRequested():
        return clearRequested();
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
    TResult? Function(String userId)? started,
    TResult? Function()? refreshRequested,
    TResult? Function(FavouriteWallEntity wall)? toggleRequested,
    TResult? Function(String wallId)? removeRequested,
    TResult? Function()? clearRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that.userId);
      case _RefreshRequested() when refreshRequested != null:
        return refreshRequested();
      case _ToggleRequested() when toggleRequested != null:
        return toggleRequested(_that.wall);
      case _RemoveRequested() when removeRequested != null:
        return removeRequested(_that.wallId);
      case _ClearRequested() when clearRequested != null:
        return clearRequested();
      case _:
        return null;
    }
  }
}

/// @nodoc

class _Started implements FavouriteWallsEvent {
  const _Started({required this.userId});

  final String userId;

  /// Create a copy of FavouriteWallsEvent
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
            (identical(other.userId, userId) || other.userId == userId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, userId);

  @override
  String toString() {
    return 'FavouriteWallsEvent.started(userId: $userId)';
  }
}

/// @nodoc
abstract mixin class _$StartedCopyWith<$Res>
    implements $FavouriteWallsEventCopyWith<$Res> {
  factory _$StartedCopyWith(_Started value, $Res Function(_Started) _then) =
      __$StartedCopyWithImpl;
  @useResult
  $Res call({String userId});
}

/// @nodoc
class __$StartedCopyWithImpl<$Res> implements _$StartedCopyWith<$Res> {
  __$StartedCopyWithImpl(this._self, this._then);

  final _Started _self;
  final $Res Function(_Started) _then;

  /// Create a copy of FavouriteWallsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? userId = null,
  }) {
    return _then(_Started(
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _RefreshRequested implements FavouriteWallsEvent {
  const _RefreshRequested();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _RefreshRequested);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'FavouriteWallsEvent.refreshRequested()';
  }
}

/// @nodoc

class _ToggleRequested implements FavouriteWallsEvent {
  const _ToggleRequested({required this.wall});

  final FavouriteWallEntity wall;

  /// Create a copy of FavouriteWallsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ToggleRequestedCopyWith<_ToggleRequested> get copyWith =>
      __$ToggleRequestedCopyWithImpl<_ToggleRequested>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ToggleRequested &&
            (identical(other.wall, wall) || other.wall == wall));
  }

  @override
  int get hashCode => Object.hash(runtimeType, wall);

  @override
  String toString() {
    return 'FavouriteWallsEvent.toggleRequested(wall: $wall)';
  }
}

/// @nodoc
abstract mixin class _$ToggleRequestedCopyWith<$Res>
    implements $FavouriteWallsEventCopyWith<$Res> {
  factory _$ToggleRequestedCopyWith(
          _ToggleRequested value, $Res Function(_ToggleRequested) _then) =
      __$ToggleRequestedCopyWithImpl;
  @useResult
  $Res call({FavouriteWallEntity wall});
}

/// @nodoc
class __$ToggleRequestedCopyWithImpl<$Res>
    implements _$ToggleRequestedCopyWith<$Res> {
  __$ToggleRequestedCopyWithImpl(this._self, this._then);

  final _ToggleRequested _self;
  final $Res Function(_ToggleRequested) _then;

  /// Create a copy of FavouriteWallsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? wall = null,
  }) {
    return _then(_ToggleRequested(
      wall: null == wall
          ? _self.wall
          : wall // ignore: cast_nullable_to_non_nullable
              as FavouriteWallEntity,
    ));
  }
}

/// @nodoc

class _RemoveRequested implements FavouriteWallsEvent {
  const _RemoveRequested({required this.wallId});

  final String wallId;

  /// Create a copy of FavouriteWallsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RemoveRequestedCopyWith<_RemoveRequested> get copyWith =>
      __$RemoveRequestedCopyWithImpl<_RemoveRequested>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RemoveRequested &&
            (identical(other.wallId, wallId) || other.wallId == wallId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, wallId);

  @override
  String toString() {
    return 'FavouriteWallsEvent.removeRequested(wallId: $wallId)';
  }
}

/// @nodoc
abstract mixin class _$RemoveRequestedCopyWith<$Res>
    implements $FavouriteWallsEventCopyWith<$Res> {
  factory _$RemoveRequestedCopyWith(
          _RemoveRequested value, $Res Function(_RemoveRequested) _then) =
      __$RemoveRequestedCopyWithImpl;
  @useResult
  $Res call({String wallId});
}

/// @nodoc
class __$RemoveRequestedCopyWithImpl<$Res>
    implements _$RemoveRequestedCopyWith<$Res> {
  __$RemoveRequestedCopyWithImpl(this._self, this._then);

  final _RemoveRequested _self;
  final $Res Function(_RemoveRequested) _then;

  /// Create a copy of FavouriteWallsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? wallId = null,
  }) {
    return _then(_RemoveRequested(
      wallId: null == wallId
          ? _self.wallId
          : wallId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _ClearRequested implements FavouriteWallsEvent {
  const _ClearRequested();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _ClearRequested);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'FavouriteWallsEvent.clearRequested()';
  }
}

/// @nodoc
mixin _$FavouriteWallsState {
  LoadStatus get status;
  ActionStatus get actionStatus;
  String get userId;
  List<FavouriteWallEntity> get items;
  Failure? get failure;

  /// Create a copy of FavouriteWallsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FavouriteWallsStateCopyWith<FavouriteWallsState> get copyWith =>
      _$FavouriteWallsStateCopyWithImpl<FavouriteWallsState>(
          this as FavouriteWallsState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FavouriteWallsState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) ||
                other.actionStatus == actionStatus) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            const DeepCollectionEquality().equals(other.items, items) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, actionStatus, userId,
      const DeepCollectionEquality().hash(items), failure);

  @override
  String toString() {
    return 'FavouriteWallsState(status: $status, actionStatus: $actionStatus, userId: $userId, items: $items, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class $FavouriteWallsStateCopyWith<$Res> {
  factory $FavouriteWallsStateCopyWith(
          FavouriteWallsState value, $Res Function(FavouriteWallsState) _then) =
      _$FavouriteWallsStateCopyWithImpl;
  @useResult
  $Res call(
      {LoadStatus status,
      ActionStatus actionStatus,
      String userId,
      List<FavouriteWallEntity> items,
      Failure? failure});
}

/// @nodoc
class _$FavouriteWallsStateCopyWithImpl<$Res>
    implements $FavouriteWallsStateCopyWith<$Res> {
  _$FavouriteWallsStateCopyWithImpl(this._self, this._then);

  final FavouriteWallsState _self;
  final $Res Function(FavouriteWallsState) _then;

  /// Create a copy of FavouriteWallsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
    Object? userId = null,
    Object? items = null,
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
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      items: null == items
          ? _self.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<FavouriteWallEntity>,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

/// Adds pattern-matching-related methods to [FavouriteWallsState].
extension FavouriteWallsStatePatterns on FavouriteWallsState {
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
    TResult Function(_FavouriteWallsState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FavouriteWallsState() when $default != null:
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
    TResult Function(_FavouriteWallsState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FavouriteWallsState():
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
    TResult? Function(_FavouriteWallsState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FavouriteWallsState() when $default != null:
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
            String userId, List<FavouriteWallEntity> items, Failure? failure)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FavouriteWallsState() when $default != null:
        return $default(_that.status, _that.actionStatus, _that.userId,
            _that.items, _that.failure);
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
            String userId, List<FavouriteWallEntity> items, Failure? failure)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FavouriteWallsState():
        return $default(_that.status, _that.actionStatus, _that.userId,
            _that.items, _that.failure);
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
            String userId, List<FavouriteWallEntity> items, Failure? failure)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FavouriteWallsState() when $default != null:
        return $default(_that.status, _that.actionStatus, _that.userId,
            _that.items, _that.failure);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _FavouriteWallsState implements FavouriteWallsState {
  const _FavouriteWallsState(
      {required this.status,
      required this.actionStatus,
      required this.userId,
      required final List<FavouriteWallEntity> items,
      this.failure})
      : _items = items;

  @override
  final LoadStatus status;
  @override
  final ActionStatus actionStatus;
  @override
  final String userId;
  final List<FavouriteWallEntity> _items;
  @override
  List<FavouriteWallEntity> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final Failure? failure;

  /// Create a copy of FavouriteWallsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FavouriteWallsStateCopyWith<_FavouriteWallsState> get copyWith =>
      __$FavouriteWallsStateCopyWithImpl<_FavouriteWallsState>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FavouriteWallsState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) ||
                other.actionStatus == actionStatus) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, actionStatus, userId,
      const DeepCollectionEquality().hash(_items), failure);

  @override
  String toString() {
    return 'FavouriteWallsState(status: $status, actionStatus: $actionStatus, userId: $userId, items: $items, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class _$FavouriteWallsStateCopyWith<$Res>
    implements $FavouriteWallsStateCopyWith<$Res> {
  factory _$FavouriteWallsStateCopyWith(_FavouriteWallsState value,
          $Res Function(_FavouriteWallsState) _then) =
      __$FavouriteWallsStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {LoadStatus status,
      ActionStatus actionStatus,
      String userId,
      List<FavouriteWallEntity> items,
      Failure? failure});
}

/// @nodoc
class __$FavouriteWallsStateCopyWithImpl<$Res>
    implements _$FavouriteWallsStateCopyWith<$Res> {
  __$FavouriteWallsStateCopyWithImpl(this._self, this._then);

  final _FavouriteWallsState _self;
  final $Res Function(_FavouriteWallsState) _then;

  /// Create a copy of FavouriteWallsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
    Object? userId = null,
    Object? items = null,
    Object? failure = freezed,
  }) {
    return _then(_FavouriteWallsState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as LoadStatus,
      actionStatus: null == actionStatus
          ? _self.actionStatus
          : actionStatus // ignore: cast_nullable_to_non_nullable
              as ActionStatus,
      userId: null == userId
          ? _self.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<FavouriteWallEntity>,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

// dart format on
