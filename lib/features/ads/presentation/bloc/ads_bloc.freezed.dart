// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ads_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AdsEvent {
  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType && other is AdsEvent);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'AdsEvent()';
  }
}

/// @nodoc
class $AdsEventCopyWith<$Res> {
  $AdsEventCopyWith(AdsEvent _, $Res Function(AdsEvent) __);
}

/// Adds pattern-matching-related methods to [AdsEvent].
extension AdsEventPatterns on AdsEvent {
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
    TResult Function(_WatchAdRequested value)? watchAdRequested,
    TResult Function(_RewardEarned value)? rewardEarned,
    TResult Function(_TransientStateCleared value)? transientStateCleared,
    TResult Function(_ResetRequested value)? resetRequested,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _WatchAdRequested() when watchAdRequested != null:
        return watchAdRequested(_that);
      case _RewardEarned() when rewardEarned != null:
        return rewardEarned(_that);
      case _TransientStateCleared() when transientStateCleared != null:
        return transientStateCleared(_that);
      case _ResetRequested() when resetRequested != null:
        return resetRequested(_that);
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
    required TResult Function(_WatchAdRequested value) watchAdRequested,
    required TResult Function(_RewardEarned value) rewardEarned,
    required TResult Function(_TransientStateCleared value) transientStateCleared,
    required TResult Function(_ResetRequested value) resetRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started(_that);
      case _WatchAdRequested():
        return watchAdRequested(_that);
      case _RewardEarned():
        return rewardEarned(_that);
      case _TransientStateCleared():
        return transientStateCleared(_that);
      case _ResetRequested():
        return resetRequested(_that);
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
    TResult? Function(_WatchAdRequested value)? watchAdRequested,
    TResult? Function(_RewardEarned value)? rewardEarned,
    TResult? Function(_TransientStateCleared value)? transientStateCleared,
    TResult? Function(_ResetRequested value)? resetRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _WatchAdRequested() when watchAdRequested != null:
        return watchAdRequested(_that);
      case _RewardEarned() when rewardEarned != null:
        return rewardEarned(_that);
      case _TransientStateCleared() when transientStateCleared != null:
        return transientStateCleared(_that);
      case _ResetRequested() when resetRequested != null:
        return resetRequested(_that);
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
    TResult Function(num unlockThreshold)? watchAdRequested,
    TResult Function(num rewardAmount, num unlockThreshold)? rewardEarned,
    TResult Function()? transientStateCleared,
    TResult Function()? resetRequested,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started();
      case _WatchAdRequested() when watchAdRequested != null:
        return watchAdRequested(_that.unlockThreshold);
      case _RewardEarned() when rewardEarned != null:
        return rewardEarned(_that.rewardAmount, _that.unlockThreshold);
      case _TransientStateCleared() when transientStateCleared != null:
        return transientStateCleared();
      case _ResetRequested() when resetRequested != null:
        return resetRequested();
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
    required TResult Function(num unlockThreshold) watchAdRequested,
    required TResult Function(num rewardAmount, num unlockThreshold) rewardEarned,
    required TResult Function() transientStateCleared,
    required TResult Function() resetRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started();
      case _WatchAdRequested():
        return watchAdRequested(_that.unlockThreshold);
      case _RewardEarned():
        return rewardEarned(_that.rewardAmount, _that.unlockThreshold);
      case _TransientStateCleared():
        return transientStateCleared();
      case _ResetRequested():
        return resetRequested();
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
    TResult? Function(num unlockThreshold)? watchAdRequested,
    TResult? Function(num rewardAmount, num unlockThreshold)? rewardEarned,
    TResult? Function()? transientStateCleared,
    TResult? Function()? resetRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started();
      case _WatchAdRequested() when watchAdRequested != null:
        return watchAdRequested(_that.unlockThreshold);
      case _RewardEarned() when rewardEarned != null:
        return rewardEarned(_that.rewardAmount, _that.unlockThreshold);
      case _TransientStateCleared() when transientStateCleared != null:
        return transientStateCleared();
      case _ResetRequested() when resetRequested != null:
        return resetRequested();
      case _:
        return null;
    }
  }
}

/// @nodoc

class _Started implements AdsEvent {
  const _Started();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType && other is _Started);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'AdsEvent.started()';
  }
}

/// @nodoc

class _WatchAdRequested implements AdsEvent {
  const _WatchAdRequested({this.unlockThreshold = 10});

  @JsonKey()
  final num unlockThreshold;

  /// Create a copy of AdsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$WatchAdRequestedCopyWith<_WatchAdRequested> get copyWith =>
      __$WatchAdRequestedCopyWithImpl<_WatchAdRequested>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _WatchAdRequested &&
            (identical(other.unlockThreshold, unlockThreshold) || other.unlockThreshold == unlockThreshold));
  }

  @override
  int get hashCode => Object.hash(runtimeType, unlockThreshold);

  @override
  String toString() {
    return 'AdsEvent.watchAdRequested(unlockThreshold: $unlockThreshold)';
  }
}

/// @nodoc
abstract mixin class _$WatchAdRequestedCopyWith<$Res> implements $AdsEventCopyWith<$Res> {
  factory _$WatchAdRequestedCopyWith(_WatchAdRequested value, $Res Function(_WatchAdRequested) _then) =
      __$WatchAdRequestedCopyWithImpl;
  @useResult
  $Res call({num unlockThreshold});
}

/// @nodoc
class __$WatchAdRequestedCopyWithImpl<$Res> implements _$WatchAdRequestedCopyWith<$Res> {
  __$WatchAdRequestedCopyWithImpl(this._self, this._then);

  final _WatchAdRequested _self;
  final $Res Function(_WatchAdRequested) _then;

  /// Create a copy of AdsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? unlockThreshold = null,
  }) {
    return _then(_WatchAdRequested(
      unlockThreshold: null == unlockThreshold
          ? _self.unlockThreshold
          : unlockThreshold // ignore: cast_nullable_to_non_nullable
              as num,
    ));
  }
}

/// @nodoc

class _RewardEarned implements AdsEvent {
  const _RewardEarned({required this.rewardAmount, this.unlockThreshold = 10});

  final num rewardAmount;
  @JsonKey()
  final num unlockThreshold;

  /// Create a copy of AdsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RewardEarnedCopyWith<_RewardEarned> get copyWith => __$RewardEarnedCopyWithImpl<_RewardEarned>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RewardEarned &&
            (identical(other.rewardAmount, rewardAmount) || other.rewardAmount == rewardAmount) &&
            (identical(other.unlockThreshold, unlockThreshold) || other.unlockThreshold == unlockThreshold));
  }

  @override
  int get hashCode => Object.hash(runtimeType, rewardAmount, unlockThreshold);

  @override
  String toString() {
    return 'AdsEvent.rewardEarned(rewardAmount: $rewardAmount, unlockThreshold: $unlockThreshold)';
  }
}

/// @nodoc
abstract mixin class _$RewardEarnedCopyWith<$Res> implements $AdsEventCopyWith<$Res> {
  factory _$RewardEarnedCopyWith(_RewardEarned value, $Res Function(_RewardEarned) _then) = __$RewardEarnedCopyWithImpl;
  @useResult
  $Res call({num rewardAmount, num unlockThreshold});
}

/// @nodoc
class __$RewardEarnedCopyWithImpl<$Res> implements _$RewardEarnedCopyWith<$Res> {
  __$RewardEarnedCopyWithImpl(this._self, this._then);

  final _RewardEarned _self;
  final $Res Function(_RewardEarned) _then;

  /// Create a copy of AdsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? rewardAmount = null,
    Object? unlockThreshold = null,
  }) {
    return _then(_RewardEarned(
      rewardAmount: null == rewardAmount
          ? _self.rewardAmount
          : rewardAmount // ignore: cast_nullable_to_non_nullable
              as num,
      unlockThreshold: null == unlockThreshold
          ? _self.unlockThreshold
          : unlockThreshold // ignore: cast_nullable_to_non_nullable
              as num,
    ));
  }
}

/// @nodoc

class _TransientStateCleared implements AdsEvent {
  const _TransientStateCleared();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType && other is _TransientStateCleared);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'AdsEvent.transientStateCleared()';
  }
}

/// @nodoc

class _ResetRequested implements AdsEvent {
  const _ResetRequested();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType && other is _ResetRequested);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'AdsEvent.resetRequested()';
  }
}

/// @nodoc
mixin _$AdsState {
  LoadStatus get status;
  ActionStatus get actionStatus;
  AdsEntity get ads;
  bool get shouldUnlockDownload;
  Failure? get failure;

  /// Create a copy of AdsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AdsStateCopyWith<AdsState> get copyWith => _$AdsStateCopyWithImpl<AdsState>(this as AdsState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AdsState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus) &&
            (identical(other.ads, ads) || other.ads == ads) &&
            (identical(other.shouldUnlockDownload, shouldUnlockDownload) ||
                other.shouldUnlockDownload == shouldUnlockDownload) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, actionStatus, ads, shouldUnlockDownload, failure);

  @override
  String toString() {
    return 'AdsState(status: $status, actionStatus: $actionStatus, ads: $ads, shouldUnlockDownload: $shouldUnlockDownload, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class $AdsStateCopyWith<$Res> {
  factory $AdsStateCopyWith(AdsState value, $Res Function(AdsState) _then) = _$AdsStateCopyWithImpl;
  @useResult
  $Res call({LoadStatus status, ActionStatus actionStatus, AdsEntity ads, bool shouldUnlockDownload, Failure? failure});
}

/// @nodoc
class _$AdsStateCopyWithImpl<$Res> implements $AdsStateCopyWith<$Res> {
  _$AdsStateCopyWithImpl(this._self, this._then);

  final AdsState _self;
  final $Res Function(AdsState) _then;

  /// Create a copy of AdsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
    Object? ads = null,
    Object? shouldUnlockDownload = null,
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
      ads: null == ads
          ? _self.ads
          : ads // ignore: cast_nullable_to_non_nullable
              as AdsEntity,
      shouldUnlockDownload: null == shouldUnlockDownload
          ? _self.shouldUnlockDownload
          : shouldUnlockDownload // ignore: cast_nullable_to_non_nullable
              as bool,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

/// Adds pattern-matching-related methods to [AdsState].
extension AdsStatePatterns on AdsState {
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
    TResult Function(_AdsState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AdsState() when $default != null:
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
    TResult Function(_AdsState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AdsState():
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
    TResult? Function(_AdsState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AdsState() when $default != null:
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
            LoadStatus status, ActionStatus actionStatus, AdsEntity ads, bool shouldUnlockDownload, Failure? failure)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AdsState() when $default != null:
        return $default(_that.status, _that.actionStatus, _that.ads, _that.shouldUnlockDownload, _that.failure);
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
            LoadStatus status, ActionStatus actionStatus, AdsEntity ads, bool shouldUnlockDownload, Failure? failure)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AdsState():
        return $default(_that.status, _that.actionStatus, _that.ads, _that.shouldUnlockDownload, _that.failure);
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
            LoadStatus status, ActionStatus actionStatus, AdsEntity ads, bool shouldUnlockDownload, Failure? failure)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AdsState() when $default != null:
        return $default(_that.status, _that.actionStatus, _that.ads, _that.shouldUnlockDownload, _that.failure);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _AdsState implements AdsState {
  const _AdsState(
      {required this.status,
      required this.actionStatus,
      required this.ads,
      required this.shouldUnlockDownload,
      this.failure});

  @override
  final LoadStatus status;
  @override
  final ActionStatus actionStatus;
  @override
  final AdsEntity ads;
  @override
  final bool shouldUnlockDownload;
  @override
  final Failure? failure;

  /// Create a copy of AdsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AdsStateCopyWith<_AdsState> get copyWith => __$AdsStateCopyWithImpl<_AdsState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AdsState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus) &&
            (identical(other.ads, ads) || other.ads == ads) &&
            (identical(other.shouldUnlockDownload, shouldUnlockDownload) ||
                other.shouldUnlockDownload == shouldUnlockDownload) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, actionStatus, ads, shouldUnlockDownload, failure);

  @override
  String toString() {
    return 'AdsState(status: $status, actionStatus: $actionStatus, ads: $ads, shouldUnlockDownload: $shouldUnlockDownload, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class _$AdsStateCopyWith<$Res> implements $AdsStateCopyWith<$Res> {
  factory _$AdsStateCopyWith(_AdsState value, $Res Function(_AdsState) _then) = __$AdsStateCopyWithImpl;
  @override
  @useResult
  $Res call({LoadStatus status, ActionStatus actionStatus, AdsEntity ads, bool shouldUnlockDownload, Failure? failure});
}

/// @nodoc
class __$AdsStateCopyWithImpl<$Res> implements _$AdsStateCopyWith<$Res> {
  __$AdsStateCopyWithImpl(this._self, this._then);

  final _AdsState _self;
  final $Res Function(_AdsState) _then;

  /// Create a copy of AdsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
    Object? ads = null,
    Object? shouldUnlockDownload = null,
    Object? failure = freezed,
  }) {
    return _then(_AdsState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as LoadStatus,
      actionStatus: null == actionStatus
          ? _self.actionStatus
          : actionStatus // ignore: cast_nullable_to_non_nullable
              as ActionStatus,
      ads: null == ads
          ? _self.ads
          : ads // ignore: cast_nullable_to_non_nullable
              as AdsEntity,
      shouldUnlockDownload: null == shouldUnlockDownload
          ? _self.shouldUnlockDownload
          : shouldUnlockDownload // ignore: cast_nullable_to_non_nullable
              as bool,
      failure: freezed == failure
          ? _self.failure
          : failure // ignore: cast_nullable_to_non_nullable
              as Failure?,
    ));
  }
}

// dart format on
