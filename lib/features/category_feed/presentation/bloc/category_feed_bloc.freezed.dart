// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'category_feed_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CategoryFeedEvent {
  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType && other is CategoryFeedEvent);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'CategoryFeedEvent()';
  }
}

/// @nodoc
class $CategoryFeedEventCopyWith<$Res> {
  $CategoryFeedEventCopyWith(CategoryFeedEvent _, $Res Function(CategoryFeedEvent) __);
}

/// Adds pattern-matching-related methods to [CategoryFeedEvent].
extension CategoryFeedEventPatterns on CategoryFeedEvent {
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
    TResult Function(_CategorySelected value)? categorySelected,
    TResult Function(_FetchMoreRequested value)? fetchMoreRequested,
    TResult Function(_RefreshRequested value)? refreshRequested,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _CategorySelected() when categorySelected != null:
        return categorySelected(_that);
      case _FetchMoreRequested() when fetchMoreRequested != null:
        return fetchMoreRequested(_that);
      case _RefreshRequested() when refreshRequested != null:
        return refreshRequested(_that);
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
    required TResult Function(_CategorySelected value) categorySelected,
    required TResult Function(_FetchMoreRequested value) fetchMoreRequested,
    required TResult Function(_RefreshRequested value) refreshRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started(_that);
      case _CategorySelected():
        return categorySelected(_that);
      case _FetchMoreRequested():
        return fetchMoreRequested(_that);
      case _RefreshRequested():
        return refreshRequested(_that);
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
    TResult? Function(_CategorySelected value)? categorySelected,
    TResult? Function(_FetchMoreRequested value)? fetchMoreRequested,
    TResult? Function(_RefreshRequested value)? refreshRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started(_that);
      case _CategorySelected() when categorySelected != null:
        return categorySelected(_that);
      case _FetchMoreRequested() when fetchMoreRequested != null:
        return fetchMoreRequested(_that);
      case _RefreshRequested() when refreshRequested != null:
        return refreshRequested(_that);
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
    TResult Function(CategoryEntity category, bool refresh)? categorySelected,
    TResult Function()? fetchMoreRequested,
    TResult Function()? refreshRequested,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started();
      case _CategorySelected() when categorySelected != null:
        return categorySelected(_that.category, _that.refresh);
      case _FetchMoreRequested() when fetchMoreRequested != null:
        return fetchMoreRequested();
      case _RefreshRequested() when refreshRequested != null:
        return refreshRequested();
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
    required TResult Function(CategoryEntity category, bool refresh) categorySelected,
    required TResult Function() fetchMoreRequested,
    required TResult Function() refreshRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started():
        return started();
      case _CategorySelected():
        return categorySelected(_that.category, _that.refresh);
      case _FetchMoreRequested():
        return fetchMoreRequested();
      case _RefreshRequested():
        return refreshRequested();
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
    TResult? Function(CategoryEntity category, bool refresh)? categorySelected,
    TResult? Function()? fetchMoreRequested,
    TResult? Function()? refreshRequested,
  }) {
    final _that = this;
    switch (_that) {
      case _Started() when started != null:
        return started();
      case _CategorySelected() when categorySelected != null:
        return categorySelected(_that.category, _that.refresh);
      case _FetchMoreRequested() when fetchMoreRequested != null:
        return fetchMoreRequested();
      case _RefreshRequested() when refreshRequested != null:
        return refreshRequested();
      case _:
        return null;
    }
  }
}

/// @nodoc

class _Started implements CategoryFeedEvent {
  const _Started();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType && other is _Started);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'CategoryFeedEvent.started()';
  }
}

/// @nodoc

class _CategorySelected implements CategoryFeedEvent {
  const _CategorySelected({required this.category, this.refresh = true});

  final CategoryEntity category;
  @JsonKey()
  final bool refresh;

  /// Create a copy of CategoryFeedEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CategorySelectedCopyWith<_CategorySelected> get copyWith =>
      __$CategorySelectedCopyWithImpl<_CategorySelected>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CategorySelected &&
            (identical(other.category, category) || other.category == category) &&
            (identical(other.refresh, refresh) || other.refresh == refresh));
  }

  @override
  int get hashCode => Object.hash(runtimeType, category, refresh);

  @override
  String toString() {
    return 'CategoryFeedEvent.categorySelected(category: $category, refresh: $refresh)';
  }
}

/// @nodoc
abstract mixin class _$CategorySelectedCopyWith<$Res> implements $CategoryFeedEventCopyWith<$Res> {
  factory _$CategorySelectedCopyWith(_CategorySelected value, $Res Function(_CategorySelected) _then) =
      __$CategorySelectedCopyWithImpl;
  @useResult
  $Res call({CategoryEntity category, bool refresh});
}

/// @nodoc
class __$CategorySelectedCopyWithImpl<$Res> implements _$CategorySelectedCopyWith<$Res> {
  __$CategorySelectedCopyWithImpl(this._self, this._then);

  final _CategorySelected _self;
  final $Res Function(_CategorySelected) _then;

  /// Create a copy of CategoryFeedEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? category = null,
    Object? refresh = null,
  }) {
    return _then(_CategorySelected(
      category: null == category
          ? _self.category
          : category // ignore: cast_nullable_to_non_nullable
              as CategoryEntity,
      refresh: null == refresh
          ? _self.refresh
          : refresh // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _FetchMoreRequested implements CategoryFeedEvent {
  const _FetchMoreRequested();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType && other is _FetchMoreRequested);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'CategoryFeedEvent.fetchMoreRequested()';
  }
}

/// @nodoc

class _RefreshRequested implements CategoryFeedEvent {
  const _RefreshRequested();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType && other is _RefreshRequested);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'CategoryFeedEvent.refreshRequested()';
  }
}

/// @nodoc
mixin _$CategoryFeedState {
  LoadStatus get status;
  ActionStatus get actionStatus;
  List<CategoryEntity> get categories;
  CategoryEntity? get selectedCategory;
  List<FeedItemEntity> get items;
  bool get hasMore;
  String? get nextCursor;
  bool get isFetchingMore;
  Failure? get failure;

  /// Create a copy of CategoryFeedState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CategoryFeedStateCopyWith<CategoryFeedState> get copyWith =>
      _$CategoryFeedStateCopyWithImpl<CategoryFeedState>(this as CategoryFeedState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CategoryFeedState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus) &&
            const DeepCollectionEquality().equals(other.categories, categories) &&
            (identical(other.selectedCategory, selectedCategory) || other.selectedCategory == selectedCategory) &&
            const DeepCollectionEquality().equals(other.items, items) &&
            (identical(other.hasMore, hasMore) || other.hasMore == hasMore) &&
            (identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor) &&
            (identical(other.isFetchingMore, isFetchingMore) || other.isFetchingMore == isFetchingMore) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, actionStatus, const DeepCollectionEquality().hash(categories),
      selectedCategory, const DeepCollectionEquality().hash(items), hasMore, nextCursor, isFetchingMore, failure);

  @override
  String toString() {
    return 'CategoryFeedState(status: $status, actionStatus: $actionStatus, categories: $categories, selectedCategory: $selectedCategory, items: $items, hasMore: $hasMore, nextCursor: $nextCursor, isFetchingMore: $isFetchingMore, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class $CategoryFeedStateCopyWith<$Res> {
  factory $CategoryFeedStateCopyWith(CategoryFeedState value, $Res Function(CategoryFeedState) _then) =
      _$CategoryFeedStateCopyWithImpl;
  @useResult
  $Res call(
      {LoadStatus status,
      ActionStatus actionStatus,
      List<CategoryEntity> categories,
      CategoryEntity? selectedCategory,
      List<FeedItemEntity> items,
      bool hasMore,
      String? nextCursor,
      bool isFetchingMore,
      Failure? failure});
}

/// @nodoc
class _$CategoryFeedStateCopyWithImpl<$Res> implements $CategoryFeedStateCopyWith<$Res> {
  _$CategoryFeedStateCopyWithImpl(this._self, this._then);

  final CategoryFeedState _self;
  final $Res Function(CategoryFeedState) _then;

  /// Create a copy of CategoryFeedState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
    Object? categories = null,
    Object? selectedCategory = freezed,
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
      categories: null == categories
          ? _self.categories
          : categories // ignore: cast_nullable_to_non_nullable
              as List<CategoryEntity>,
      selectedCategory: freezed == selectedCategory
          ? _self.selectedCategory
          : selectedCategory // ignore: cast_nullable_to_non_nullable
              as CategoryEntity?,
      items: null == items
          ? _self.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<FeedItemEntity>,
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

/// Adds pattern-matching-related methods to [CategoryFeedState].
extension CategoryFeedStatePatterns on CategoryFeedState {
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
    TResult Function(_CategoryFeedState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CategoryFeedState() when $default != null:
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
    TResult Function(_CategoryFeedState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CategoryFeedState():
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
    TResult? Function(_CategoryFeedState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CategoryFeedState() when $default != null:
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
            List<CategoryEntity> categories,
            CategoryEntity? selectedCategory,
            List<FeedItemEntity> items,
            bool hasMore,
            String? nextCursor,
            bool isFetchingMore,
            Failure? failure)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CategoryFeedState() when $default != null:
        return $default(_that.status, _that.actionStatus, _that.categories, _that.selectedCategory, _that.items,
            _that.hasMore, _that.nextCursor, _that.isFetchingMore, _that.failure);
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
            List<CategoryEntity> categories,
            CategoryEntity? selectedCategory,
            List<FeedItemEntity> items,
            bool hasMore,
            String? nextCursor,
            bool isFetchingMore,
            Failure? failure)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CategoryFeedState():
        return $default(_that.status, _that.actionStatus, _that.categories, _that.selectedCategory, _that.items,
            _that.hasMore, _that.nextCursor, _that.isFetchingMore, _that.failure);
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
            List<CategoryEntity> categories,
            CategoryEntity? selectedCategory,
            List<FeedItemEntity> items,
            bool hasMore,
            String? nextCursor,
            bool isFetchingMore,
            Failure? failure)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CategoryFeedState() when $default != null:
        return $default(_that.status, _that.actionStatus, _that.categories, _that.selectedCategory, _that.items,
            _that.hasMore, _that.nextCursor, _that.isFetchingMore, _that.failure);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _CategoryFeedState implements CategoryFeedState {
  const _CategoryFeedState(
      {required this.status,
      required this.actionStatus,
      required final List<CategoryEntity> categories,
      required this.selectedCategory,
      required final List<FeedItemEntity> items,
      required this.hasMore,
      required this.nextCursor,
      required this.isFetchingMore,
      this.failure})
      : _categories = categories,
        _items = items;

  @override
  final LoadStatus status;
  @override
  final ActionStatus actionStatus;
  final List<CategoryEntity> _categories;
  @override
  List<CategoryEntity> get categories {
    if (_categories is EqualUnmodifiableListView) return _categories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_categories);
  }

  @override
  final CategoryEntity? selectedCategory;
  final List<FeedItemEntity> _items;
  @override
  List<FeedItemEntity> get items {
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

  /// Create a copy of CategoryFeedState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CategoryFeedStateCopyWith<_CategoryFeedState> get copyWith =>
      __$CategoryFeedStateCopyWithImpl<_CategoryFeedState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CategoryFeedState &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.actionStatus, actionStatus) || other.actionStatus == actionStatus) &&
            const DeepCollectionEquality().equals(other._categories, _categories) &&
            (identical(other.selectedCategory, selectedCategory) || other.selectedCategory == selectedCategory) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.hasMore, hasMore) || other.hasMore == hasMore) &&
            (identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor) &&
            (identical(other.isFetchingMore, isFetchingMore) || other.isFetchingMore == isFetchingMore) &&
            (identical(other.failure, failure) || other.failure == failure));
  }

  @override
  int get hashCode => Object.hash(runtimeType, status, actionStatus, const DeepCollectionEquality().hash(_categories),
      selectedCategory, const DeepCollectionEquality().hash(_items), hasMore, nextCursor, isFetchingMore, failure);

  @override
  String toString() {
    return 'CategoryFeedState(status: $status, actionStatus: $actionStatus, categories: $categories, selectedCategory: $selectedCategory, items: $items, hasMore: $hasMore, nextCursor: $nextCursor, isFetchingMore: $isFetchingMore, failure: $failure)';
  }
}

/// @nodoc
abstract mixin class _$CategoryFeedStateCopyWith<$Res> implements $CategoryFeedStateCopyWith<$Res> {
  factory _$CategoryFeedStateCopyWith(_CategoryFeedState value, $Res Function(_CategoryFeedState) _then) =
      __$CategoryFeedStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {LoadStatus status,
      ActionStatus actionStatus,
      List<CategoryEntity> categories,
      CategoryEntity? selectedCategory,
      List<FeedItemEntity> items,
      bool hasMore,
      String? nextCursor,
      bool isFetchingMore,
      Failure? failure});
}

/// @nodoc
class __$CategoryFeedStateCopyWithImpl<$Res> implements _$CategoryFeedStateCopyWith<$Res> {
  __$CategoryFeedStateCopyWithImpl(this._self, this._then);

  final _CategoryFeedState _self;
  final $Res Function(_CategoryFeedState) _then;

  /// Create a copy of CategoryFeedState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? status = null,
    Object? actionStatus = null,
    Object? categories = null,
    Object? selectedCategory = freezed,
    Object? items = null,
    Object? hasMore = null,
    Object? nextCursor = freezed,
    Object? isFetchingMore = null,
    Object? failure = freezed,
  }) {
    return _then(_CategoryFeedState(
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as LoadStatus,
      actionStatus: null == actionStatus
          ? _self.actionStatus
          : actionStatus // ignore: cast_nullable_to_non_nullable
              as ActionStatus,
      categories: null == categories
          ? _self._categories
          : categories // ignore: cast_nullable_to_non_nullable
              as List<CategoryEntity>,
      selectedCategory: freezed == selectedCategory
          ? _self.selectedCategory
          : selectedCategory // ignore: cast_nullable_to_non_nullable
              as CategoryEntity?,
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<FeedItemEntity>,
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
