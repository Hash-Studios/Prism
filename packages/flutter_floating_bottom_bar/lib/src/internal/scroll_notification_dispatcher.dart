import 'dart:collection';

import 'package:flutter/widgets.dart';

/// Routes [ScrollNotification]s to a single visibility decision per scrollable.
///
/// Tracks per-scrollable last offset, applies a delta threshold, and calls
/// `onShouldHide(true)` when the bar should hide and `onShouldHide(false)`
/// when it should show. Also tracks the most recently observed
/// [ScrollPosition] for `BottomBarController.scrollToStart`/`scrollToEnd`.
///
/// Bounded to 16 tracked scrollables (LRU eviction).
class ScrollNotificationDispatcher {
  ScrollNotificationDispatcher({
    required this.onShouldHide,
    this.deltaThreshold = 8,
    this.reverse = false,
    this.showAtStart = false,
    this.showOnScrollEnd = false,
    this.predicate,
  });

  final ValueChanged<bool> onShouldHide;
  double deltaThreshold;
  bool reverse;
  bool showAtStart;
  bool showOnScrollEnd;
  bool Function(ScrollNotification)? predicate;

  static const int _maxTracked = 16;
  final LinkedHashMap<int, _TrackedScrollState> _trackedScrollables =
      LinkedHashMap<int, _TrackedScrollState>();

  _TrackedScrollState? _externalState;

  ScrollPosition? _lastActivePosition;
  ScrollPosition? get lastActivePosition => _lastActivePosition;

  BuildContext? _lastActiveContext;

  /// Drops the cached scrollable. The position [Scrollable] owned may already
  /// have been disposed.
  void forgetActiveScrollable() {
    _lastActivePosition = null;
    _lastActiveContext = null;
  }

  /// Records the scrollable that boundary scrolling should drive.
  ///
  /// [position] must be the position currently attached to [context]. A later
  /// [Scrollable.didChangeDependencies] can dispose [position] and create a
  /// new one under the same [context]; callers resolve that live position at
  /// use time instead of animating this snapshot.
  void rememberActiveScrollable(ScrollPosition position, BuildContext context) {
    _lastActivePosition = position;
    _lastActiveContext = context;
  }

  /// The [BuildContext] of the most recently active scrollable.
  ///
  /// Used by `BottomBarController.scrollToStart`/`scrollToEnd` to locate an
  /// enclosing [NestedScrollView], whose header and body scroll on two
  /// coordinated [ScrollPosition]s that must both be animated to fully return
  /// to the top.
  BuildContext? get lastActiveContext => _lastActiveContext;

  int _keyFor(ScrollNotification n, ScrollPosition? position) {
    if (position != null) return identityHashCode(position);
    final context = n.context;
    if (context != null) return identityHashCode(context);
    return Object.hash(n.depth, n.metrics.axis);
  }

  void handle(ScrollNotification notification) {
    final filter = predicate;
    if (filter != null && !filter(notification)) return;

    // Bottom bar visibility is driven by vertical scrolls only. Horizontal
    // scrolls (e.g. PageView/TabBarView between siblings) must not be allowed
    // to flip visibility.
    if (notification.metrics.axis != Axis.vertical) return;

    final metrics = notification.metrics;
    if (notification is ScrollEndNotification) {
      // Coming to rest at the start shows the bar, unless [reverse] makes
      // scrolling toward the start the hide direction.
      if (showOnScrollEnd ||
          (!reverse && metrics.pixels <= metrics.minScrollExtent)) {
        onShouldHide(false);
      }
      return;
    }

    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollStartNotification) {
      return;
    }

    final position = _maybePositionOf(notification);
    // Keep the previous target when this notification cannot name one.
    // A null context must not wipe a live scrollable, and a disposed one is
    // dropped so scroll-to-boundary cannot animate it later.
    if (position != null) {
      _lastActivePosition = position;
    }
    final activeContext = notification.context;
    if (activeContext != null && activeContext.mounted) {
      _lastActiveContext = activeContext;
    }
    final key = _keyFor(notification, position);
    // Overscroll and its spring-back (BouncingScrollPhysics) aren't the user
    // scrolling: pin tracking to the edge so the rebound off the top doesn't
    // read as a scroll down.
    final pixels = metrics.pixels
        .clamp(metrics.minScrollExtent, metrics.maxScrollExtent)
        .toDouble();

    // LRU touch.
    final state =
        _trackedScrollables.remove(key) ??
        _TrackedScrollState(anchorPixels: pixels, lastPixels: pixels);
    _trackedScrollables[key] = state;

    // Evict oldest if over capacity.
    while (_trackedScrollables.length > _maxTracked) {
      _trackedScrollables.remove(_trackedScrollables.keys.first);
    }

    if (notification is ScrollStartNotification) {
      _resetState(state, pixels);

      if (showAtStart && pixels <= notification.metrics.minScrollExtent) {
        onShouldHide(false);
      }
      return;
    }

    if (showAtStart && pixels <= notification.metrics.minScrollExtent) {
      _resetState(state, pixels);
      onShouldHide(false);
      return;
    }

    _handlePixels(state, pixels);
  }

  /// Reports a scroll delta from a source that never emits
  /// [ScrollNotification]s (e.g. an embedded WebView).
  ///
  /// [delta] is signed: positive moves toward the end (the usual hide
  /// direction), negative moves toward the start (the usual show direction).
  /// Applies the same [deltaThreshold]/[reverse] accumulation as [handle],
  /// but tracks its own independent accumulator: it never runs [predicate],
  /// never touches [lastActivePosition]/[lastActiveContext], and does not
  /// share state with notification-tracked scrollables.
  void handleDelta(double delta) {
    if (delta == 0) return;

    final state = _externalState ??= _TrackedScrollState(
      anchorPixels: 0,
      lastPixels: 0,
    );
    _handlePixels(state, state.lastPixels + delta);
  }

  void _handlePixels(_TrackedScrollState state, double pixels) {
    final delta = pixels - state.lastPixels;
    state.lastPixels = pixels;
    if (delta == 0) return;

    final direction = delta.sign;
    if (state.direction != direction) {
      state
        ..anchorPixels = state.lastPixels - delta
        ..direction = direction;
    }

    final accumulatedDelta = pixels - state.anchorPixels;
    if (accumulatedDelta.abs() < deltaThreshold) return;

    final shouldHide = reverse ? accumulatedDelta < 0 : accumulatedDelta > 0;
    state.anchorPixels = pixels;
    onShouldHide(shouldHide);
  }

  ScrollPosition? _maybePositionOf(ScrollNotification n) {
    final ctx = n.context;
    if (ctx == null || !ctx.mounted) return null;
    // Scrollable replaces its position when dependencies change (a route
    // transition does this). The notification context stays mounted and now
    // points at the new position; the previous one is disposed.
    return Scrollable.maybeOf(ctx)?.position;
  }

  void _resetState(_TrackedScrollState state, double pixels) {
    state
      ..anchorPixels = pixels
      ..lastPixels = pixels
      ..direction = null;
  }
}

class _TrackedScrollState {
  _TrackedScrollState({required this.anchorPixels, required this.lastPixels});

  double anchorPixels;
  double lastPixels;
  double? direction;
}
