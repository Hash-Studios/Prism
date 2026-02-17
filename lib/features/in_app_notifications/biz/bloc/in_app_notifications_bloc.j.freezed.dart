// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'in_app_notifications_bloc.j.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InAppNotificationsEvent {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is InAppNotificationsEvent);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'InAppNotificationsEvent()';
  }
}

/// @nodoc
class $InAppNotificationsEventCopyWith<$Res> {
  $InAppNotificationsEventCopyWith(
      InAppNotificationsEvent _, $Res Function(InAppNotificationsEvent) __);
}

/// Adds pattern-matching-related methods to [InAppNotificationsEvent].
extension InAppNotificationsEventPatterns on InAppNotificationsEvent {
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
    TResult Function(_MarkReadRequested value)? markReadRequested,
    TResult Function(_DeleteRequested value)? deleteRequested,
    TResult Function(_ClearRequested value)? clearRequested,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _RefreshRequested() when refreshRequested != null:
        return refreshRequested(_that);
      case _MarkReadRequested() when markReadRequested != null:
        return markReadRequested(_that);
      case _DeleteRequested() when deleteRequested != null:
        return deleteRequested(_that);
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
    required TResult Function(_MarkReadRequested value) markReadRequested,
    required TResult Function(_DeleteRequested value) deleteRequested,
    required TResult Function(_ClearRequested value) clearRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started(_that);
      case _RefreshRequested():
        return refreshRequested(_that);
      case _MarkReadRequested():
        return markReadRequested(_that);
      case _DeleteRequested():
        return deleteRequested(_that);
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
    TResult? Function(_MarkReadRequested value)? markReadRequested,
    TResult? Function(_DeleteRequested value)? deleteRequested,
    TResult? Function(_ClearRequested value)? clearRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _RefreshRequested() when refreshRequested != null:
        return refreshRequested(_that);
      case _MarkReadRequested() when markReadRequested != null:
        return markReadRequested(_that);
      case _DeleteRequested() when deleteRequested != null:
        return deleteRequested(_that);
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
    TResult Function(bool syncRemote)? started,
    TResult Function()? refreshRequested,
    TResult Function(int index)? markReadRequested,
    TResult Function(int index)? deleteRequested,
    TResult Function()? clearRequested,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that.syncRemote);
      case _RefreshRequested() when refreshRequested != null:
        return refreshRequested();
      case _MarkReadRequested() when markReadRequested != null:
        return markReadRequested(_that.index);
      case _DeleteRequested() when deleteRequested != null:
        return deleteRequested(_that.index);
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
    required TResult Function(bool syncRemote) started,
    required TResult Function() refreshRequested,
    required TResult Function(int index) markReadRequested,
    required TResult Function(int index) deleteRequested,
    required TResult Function() clearRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started(_that.syncRemote);
      case _RefreshRequested():
        return refreshRequested();
      case _MarkReadRequested():
        return markReadRequested(_that.index);
      case _DeleteRequested():
        return deleteRequested(_that.index);
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
    TResult? Function(bool syncRemote)? started,
    TResult? Function()? refreshRequested,
    TResult? Function(int index)? markReadRequested,
    TResult? Function(int index)? deleteRequested,
    TResult? Function()? clearRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that.syncRemote);
      case _RefreshRequested() when refreshRequested != null:
        return refreshRequested();
      case _MarkReadRequested() when markReadRequested != null:
        return markReadRequested(_that.index);
      case _DeleteRequested() when deleteRequested != null:
        return deleteRequested(_that.index);
      case _ClearRequested() when clearRequested != null:
        return clearRequested();
      case _:
        return null;
    }
  }
}

/// @nodoc

class _Started implements InAppNotificationsEvent {
  const _Started({this.syncRemote = false});

  @JsonKey()
  final bool syncRemote;

  /// Create a copy of InAppNotificationsEvent
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
            (identical(other.syncRemote, syncRemote) ||
                other.syncRemote == syncRemote));
  }

  @override
  int get hashCode => Object.hash(runtimeType, syncRemote);

  @override
  String toString() {
    return 'InAppNotificationsEvent.started(syncRemote: $syncRemote)';
  }
}

/// @nodoc
abstract mixin class _$StartedCopyWith<$Res>
    implements $InAppNotificationsEventCopyWith<$Res> {
  factory _$StartedCopyWith(_Started value, $Res Function(_Started) _then) =
      __$StartedCopyWithImpl;
  @useResult
  $Res call({bool syncRemote});
}

/// @nodoc
class __$StartedCopyWithImpl<$Res> implements _$StartedCopyWith<$Res> {
  __$StartedCopyWithImpl(this._self, this._then);

  final _Started _self;
  final $Res Function(_Started) _then;

  /// Create a copy of InAppNotificationsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? syncRemote = null,
  }) {
    return _then(_Started(
      syncRemote: null == syncRemote
          ? _self.syncRemote
          : syncRemote // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _RefreshRequested implements InAppNotificationsEvent {
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
    return 'InAppNotificationsEvent.refreshRequested()';
  }
}

/// @nodoc

class _MarkReadRequested implements InAppNotificationsEvent {
  const _MarkReadRequested({required this.index});

  final int index;

  /// Create a copy of InAppNotificationsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MarkReadRequestedCopyWith<_MarkReadRequested> get copyWith =>
      __$MarkReadRequestedCopyWithImpl<_MarkReadRequested>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MarkReadRequested &&
            (identical(other.index, index) || other.index == index));
  }

  @override
  int get hashCode => Object.hash(runtimeType, index);

  @override
  String toString() {
    return 'InAppNotificationsEvent.markReadRequested(index: $index)';
  }
}

/// @nodoc
abstract mixin class _$MarkReadRequestedCopyWith<$Res>
    implements $InAppNotificationsEventCopyWith<$Res> {
  factory _$MarkReadRequestedCopyWith(
          _MarkReadRequested value, $Res Function(_MarkReadRequested) _then) =
      __$MarkReadRequestedCopyWithImpl;
  @useResult
  $Res call({int index});
}

/// @nodoc
class __$MarkReadRequestedCopyWithImpl<$Res>
    implements _$MarkReadRequestedCopyWith<$Res> {
  __$MarkReadRequestedCopyWithImpl(this._self, this._then);

  final _MarkReadRequested _self;
  final $Res Function(_MarkReadRequested) _then;

  /// Create a copy of InAppNotificationsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? index = null,
  }) {
    return _then(_MarkReadRequested(
      index: null == index
          ? _self.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _DeleteRequested implements InAppNotificationsEvent {
  const _DeleteRequested({required this.index});

  final int index;

  /// Create a copy of InAppNotificationsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DeleteRequestedCopyWith<_DeleteRequested> get copyWith =>
      __$DeleteRequestedCopyWithImpl<_DeleteRequested>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DeleteRequested &&
            (identical(other.index, index) || other.index == index));
  }

  @override
  int get hashCode => Object.hash(runtimeType, index);

  @override
  String toString() {
    return 'InAppNotificationsEvent.deleteRequested(index: $index)';
  }
}

/// @nodoc
abstract mixin class _$DeleteRequestedCopyWith<$Res>
    implements $InAppNotificationsEventCopyWith<$Res> {
  factory _$DeleteRequestedCopyWith(
          _DeleteRequested value, $Res Function(_DeleteRequested) _then) =
      __$DeleteRequestedCopyWithImpl;
  @useResult
  $Res call({int index});
}

/// @nodoc
class __$DeleteRequestedCopyWithImpl<$Res>
    implements _$DeleteRequestedCopyWith<$Res> {
  __$DeleteRequestedCopyWithImpl(this._self, this._then);

  final _DeleteRequested _self;
  final $Res Function(_DeleteRequested) _then;

  /// Create a copy of InAppNotificationsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? index = null,
  }) {
    return _then(_DeleteRequested(
      index: null == index
          ? _self.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _ClearRequested implements InAppNotificationsEvent {
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
    return 'InAppNotificationsEvent.clearRequested()';
  }
}

/// @nodoc
mixin _$InAppNotificationsState {
  LoadStatus get status;
  ActionStatus get actionStatus;
  List<InAppNotificationEntity> get items;
  int get unreadCount;
  Failure? get failure;

  /// Create a copy of InAppNotificationsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $InAppNotificationsStateCopyWith<InAppNotificationsState> get copyWith =>
      _$InAppNotificationsStateCopyWithImpl<InAppNotificationsState>(
          this as InAppNotificationsState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is InAppNotificationsState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) ||
                other.actionStatus == actionStatus) &&
            const DeepCollectionEquality().equals(other.items, items) &&
            (identical(other.unreadCount, unreadCount) ||
                other.unreadCount == unreadCount) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, actionStatus,
      const DeepCollectionEquality().hash(items), unreadCount, failure);

  @override
  String toString() {
    return 'InAppNotificationsState(status: $status, actionStatus: $actionStatus, items: $items, unreadCount: $unreadCount, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class $InAppNotificationsStateCopyWith<$Res> {
  factory $InAppNotificationsStateCopyWith(InAppNotificationsState value,
          $Res Function(InAppNotificationsState) _then) =
      _$InAppNotificationsStateCopyWithImpl;
  @useResult
  $Res call(
      {LoadStatus status,
      ActionStatus actionStatus,
      List<InAppNotificationEntity> items,
      int unreadCount,
      Failure? failure});
}

/// @nodoc
class _$InAppNotificationsStateCopyWithImpl<$Res>
    implements $InAppNotificationsStateCopyWith<$Res> {
  _$InAppNotificationsStateCopyWithImpl(this._self, this._then);

  final InAppNotificationsState _self;
  final $Res Function(InAppNotificationsState) _then;

  /// Create a copy of InAppNotificationsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
    Object? items = null,
    Object? unreadCount = null,
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
              as List<InAppNotificationEntity>,
      unreadCount: null == unreadCount
          ? _self.unreadCount
          : unreadCount // ignore: cast_nullable_to_non_nullable
              as int,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

/// Adds pattern-matching-related methods to [InAppNotificationsState].
extension InAppNotificationsStatePatterns on InAppNotificationsState {
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
    TResult Function(_InAppNotificationsState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _InAppNotificationsState() when $default != null:
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
    TResult Function(_InAppNotificationsState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _InAppNotificationsState():
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
    TResult? Function(_InAppNotificationsState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _InAppNotificationsState() when $default != null:
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
            List<InAppNotificationEntity> items,
            int unreadCount,
            Failure? failure)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _InAppNotificationsState() when $default != null:
        return $default(_that.status, _that.actionStatus, _that.items,
            _that.unreadCount, _that.failure);
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
            List<InAppNotificationEntity> items,
            int unreadCount,
            Failure? failure)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _InAppNotificationsState():
        return $default(_that.status, _that.actionStatus, _that.items,
            _that.unreadCount, _that.failure);
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
            List<InAppNotificationEntity> items,
            int unreadCount,
            Failure? failure)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _InAppNotificationsState() when $default != null:
        return $default(_that.status, _that.actionStatus, _that.items,
            _that.unreadCount, _that.failure);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _InAppNotificationsState implements InAppNotificationsState {
  const _InAppNotificationsState(
      {required this.status,
      required this.actionStatus,
      required final List<InAppNotificationEntity> items,
      required this.unreadCount,
      this.failure})
      : _items = items;

  @override
  final LoadStatus status;
  @override
  final ActionStatus actionStatus;
  final List<InAppNotificationEntity> _items;
  @override
  List<InAppNotificationEntity> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final int unreadCount;
  @override
  final Failure? failure;

  /// Create a copy of InAppNotificationsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$InAppNotificationsStateCopyWith<_InAppNotificationsState> get copyWith =>
      __$InAppNotificationsStateCopyWithImpl<_InAppNotificationsState>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _InAppNotificationsState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) ||
                other.actionStatus == actionStatus) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.unreadCount, unreadCount) ||
                other.unreadCount == unreadCount) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, actionStatus,
      const DeepCollectionEquality().hash(_items), unreadCount, failure);

  @override
  String toString() {
    return 'InAppNotificationsState(status: $status, actionStatus: $actionStatus, items: $items, unreadCount: $unreadCount, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class _$InAppNotificationsStateCopyWith<$Res>
    implements $InAppNotificationsStateCopyWith<$Res> {
  factory _$InAppNotificationsStateCopyWith(_InAppNotificationsState value,
          $Res Function(_InAppNotificationsState) _then) =
      __$InAppNotificationsStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {LoadStatus status,
      ActionStatus actionStatus,
      List<InAppNotificationEntity> items,
      int unreadCount,
      Failure? failure});
}

/// @nodoc
class __$InAppNotificationsStateCopyWithImpl<$Res>
    implements _$InAppNotificationsStateCopyWith<$Res> {
  __$InAppNotificationsStateCopyWithImpl(this._self, this._then);

  final _InAppNotificationsState _self;
  final $Res Function(_InAppNotificationsState) _then;

  /// Create a copy of InAppNotificationsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
    Object? items = null,
    Object? unreadCount = null,
    Object? failure = freezed,
  }) {
    return _then(_InAppNotificationsState(
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
              as List<InAppNotificationEntity>,
      unreadCount: null == unreadCount
          ? _self.unreadCount
          : unreadCount // ignore: cast_nullable_to_non_nullable
              as int,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

// dart format on
