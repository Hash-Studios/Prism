// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'setups_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SetupsEvent {
  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType && other is SetupsEvent);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'SetupsEvent()';
  }
}

/// @nodoc
class $SetupsEventCopyWith<$Res> {
  $SetupsEventCopyWith(SetupsEvent _, $Res Function(SetupsEvent) __);
}

/// Adds pattern-matching-related methods to [SetupsEvent].
extension SetupsEventPatterns on SetupsEvent {
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
    TResult Function(_FetchMoreRequested value)? fetchMoreRequested,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _RefreshRequested() when refreshRequested != null:
        return refreshRequested(_that);
      case _FetchMoreRequested() when fetchMoreRequested != null:
        return fetchMoreRequested(_that);
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
    required TResult Function(_FetchMoreRequested value) fetchMoreRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started(_that);
      case _RefreshRequested():
        return refreshRequested(_that);
      case _FetchMoreRequested():
        return fetchMoreRequested(_that);
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
    TResult? Function(_FetchMoreRequested value)? fetchMoreRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _RefreshRequested() when refreshRequested != null:
        return refreshRequested(_that);
      case _FetchMoreRequested() when fetchMoreRequested != null:
        return fetchMoreRequested(_that);
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
    TResult Function()? refreshRequested,
    TResult Function()? fetchMoreRequested,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started();
      case _RefreshRequested() when refreshRequested != null:
        return refreshRequested();
      case _FetchMoreRequested() when fetchMoreRequested != null:
        return fetchMoreRequested();
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
    required TResult Function() refreshRequested,
    required TResult Function() fetchMoreRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started();
      case _RefreshRequested():
        return refreshRequested();
      case _FetchMoreRequested():
        return fetchMoreRequested();
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
    TResult? Function()? refreshRequested,
    TResult? Function()? fetchMoreRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started();
      case _RefreshRequested() when refreshRequested != null:
        return refreshRequested();
      case _FetchMoreRequested() when fetchMoreRequested != null:
        return fetchMoreRequested();
      case _:
        return null;
    }
  }
}

/// @nodoc

class _Started implements SetupsEvent {
  const _Started();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType && other is _Started);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'SetupsEvent.started()';
  }
}

/// @nodoc

class _RefreshRequested implements SetupsEvent {
  const _RefreshRequested();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType && other is _RefreshRequested);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'SetupsEvent.refreshRequested()';
  }
}

/// @nodoc

class _FetchMoreRequested implements SetupsEvent {
  const _FetchMoreRequested();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType && other is _FetchMoreRequested);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'SetupsEvent.fetchMoreRequested()';
  }
}

/// @nodoc
mixin _$SetupsState {
  LoadStatus get status;
  ActionStatus get actionStatus;
  List<SetupEntity> get items;
  bool get hasMore;
  String? get nextCursor;
  bool get isFetchingMore;
  Failure? get failure;

  /// Create a copy of SetupsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SetupsStateCopyWith<SetupsState> get copyWith =>
      _$SetupsStateCopyWithImpl<SetupsState>(this as SetupsState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SetupsState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus) &&
            const DeepCollectionEquality().equals(other.items, items) &&
            (identical(other.hasMore, hasMore) || other.hasMore == hasMore) &&
            (identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor) &&
            (identical(other.isFetchingMore, isFetchingMore) || other.isFetchingMore == isFetchingMore) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, actionStatus, const DeepCollectionEquality().hash(items),
      hasMore, nextCursor, isFetchingMore, failure);

  @override
  String toString() {
    return 'SetupsState(status: $status, actionStatus: $actionStatus, items: $items, hasMore: $hasMore, nextCursor: $nextCursor, isFetchingMore: $isFetchingMore, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class $SetupsStateCopyWith<$Res> {
  factory $SetupsStateCopyWith(SetupsState value, $Res Function(SetupsState) _then) = _$SetupsStateCopyWithImpl;
  @useResult
  $Res call(
      {LoadStatus status,
      ActionStatus actionStatus,
      List<SetupEntity> items,
      bool hasMore,
      String? nextCursor,
      bool isFetchingMore,
      Failure? failure});
}

/// @nodoc
class _$SetupsStateCopyWithImpl<$Res> implements $SetupsStateCopyWith<$Res> {
  _$SetupsStateCopyWithImpl(this._self, this._then);

  final SetupsState _self;
  final $Res Function(SetupsState) _then;

  /// Create a copy of SetupsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
    Object? items = null,
    Object? hasMore = null,
    Object? nextCursor = freezed,
    Object? isFetchingMore = null,
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
      items: null == items
          ? _self.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<SetupEntity>,
      hasMore: null == hasMore
          ? _self.hasMore
          : hasMore // ignore: cast_nullable_to_non_nullable
              as bool,
      nextCursor: freezed == nextCursor
          ? _self.nextCursor
          : nextCursor // ignore: cast_nullable_to_non_nullable
              as String?,
      isFetchingMore: null == isFetchingMore
          ? _self.isFetchingMore
          : isFetchingMore // ignore: cast_nullable_to_non_nullable
              as bool,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

/// Adds pattern-matching-related methods to [SetupsState].
extension SetupsStatePatterns on SetupsState {
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
    TResult Function(_SetupsState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SetupsState() when $default != null:
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
    TResult Function(_SetupsState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SetupsState():
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
    TResult? Function(_SetupsState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SetupsState() when $default != null:
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
    TResult Function(LoadStatus status, ActionStatus actionStatus, List<SetupEntity> items, bool hasMore,
            String? nextCursor, bool isFetchingMore, Failure? failure)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SetupsState() when $default != null:
        return $default(_that.status, _that.actionStatus, _that.items, _that.hasMore, _that.nextCursor,
            _that.isFetchingMore, _that.failure);
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
    TResult Function(LoadStatus status, ActionStatus actionStatus, List<SetupEntity> items, bool hasMore,
            String? nextCursor, bool isFetchingMore, Failure? failure)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SetupsState():
        return $default(_that.status, _that.actionStatus, _that.items, _that.hasMore, _that.nextCursor,
            _that.isFetchingMore, _that.failure);
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
    TResult? Function(LoadStatus status, ActionStatus actionStatus, List<SetupEntity> items, bool hasMore,
            String? nextCursor, bool isFetchingMore, Failure? failure)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SetupsState() when $default != null:
        return $default(_that.status, _that.actionStatus, _that.items, _that.hasMore, _that.nextCursor,
            _that.isFetchingMore, _that.failure);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _SetupsState implements SetupsState {
  const _SetupsState(
      {required this.status,
      required this.actionStatus,
      required final List<SetupEntity> items,
      required this.hasMore,
      required this.nextCursor,
      required this.isFetchingMore,
      this.failure})
      : _items = items;

  @override
  final LoadStatus status;
  @override
  final ActionStatus actionStatus;
  final List<SetupEntity> _items;
  @override
  List<SetupEntity> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final bool hasMore;
  @override
  final String? nextCursor;
  @override
  final bool isFetchingMore;
  @override
  final Failure? failure;

  /// Create a copy of SetupsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SetupsStateCopyWith<_SetupsState> get copyWith => __$SetupsStateCopyWithImpl<_SetupsState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SetupsState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.hasMore, hasMore) || other.hasMore == hasMore) &&
            (identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor) &&
            (identical(other.isFetchingMore, isFetchingMore) || other.isFetchingMore == isFetchingMore) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, actionStatus, const DeepCollectionEquality().hash(_items),
      hasMore, nextCursor, isFetchingMore, failure);

  @override
  String toString() {
    return 'SetupsState(status: $status, actionStatus: $actionStatus, items: $items, hasMore: $hasMore, nextCursor: $nextCursor, isFetchingMore: $isFetchingMore, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class _$SetupsStateCopyWith<$Res> implements $SetupsStateCopyWith<$Res> {
  factory _$SetupsStateCopyWith(_SetupsState value, $Res Function(_SetupsState) _then) = __$SetupsStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {LoadStatus status,
      ActionStatus actionStatus,
      List<SetupEntity> items,
      bool hasMore,
      String? nextCursor,
      bool isFetchingMore,
      Failure? failure});
}

/// @nodoc
class __$SetupsStateCopyWithImpl<$Res> implements _$SetupsStateCopyWith<$Res> {
  __$SetupsStateCopyWithImpl(this._self, this._then);

  final _SetupsState _self;
  final $Res Function(_SetupsState) _then;

  /// Create a copy of SetupsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
    Object? items = null,
    Object? hasMore = null,
    Object? nextCursor = freezed,
    Object? isFetchingMore = null,
    Object? failure = freezed,
  }) {
    return _then(_SetupsState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as LoadStatus,
      actionStatus: null == actionStatus
          ? _self.actionStatus
          : actionStatus // ignore: cast_nullable_to_non_nullable
              as ActionStatus,
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<SetupEntity>,
      hasMore: null == hasMore
          ? _self.hasMore
          : hasMore // ignore: cast_nullable_to_non_nullable
              as bool,
      nextCursor: freezed == nextCursor
          ? _self.nextCursor
          : nextCursor // ignore: cast_nullable_to_non_nullable
              as String?,
      isFetchingMore: null == isFetchingMore
          ? _self.isFetchingMore
          : isFetchingMore // ignore: cast_nullable_to_non_nullable
              as bool,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

// dart format on
