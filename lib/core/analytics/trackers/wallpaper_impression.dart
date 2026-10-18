import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/analytics_correlation.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// One result set. Pagination keeps this object; refresh replaces it.
class WallpaperImpressionSession {
  static final Expando<WallpaperImpressionSession> _sessions = Expando<WallpaperImpressionSession>();
  WallpaperImpressionSession({String? requestId}) : requestId = requestId ?? AnalyticsCorrelation.newId();

  final String requestId;
  final Set<String> _seen = <String>{};

  bool record(String provider, String itemId) => _seen.add('$provider:$itemId');

  factory WallpaperImpressionSession.forContext(BuildContext context) {
    final WallpaperImpressionSession? scope = WallpaperImpressionScope.maybeOf(context);
    if (scope != null) return scope;
    final Object owner = Scrollable.maybeOf(context) ?? context;
    return _sessions[owner] ??= WallpaperImpressionSession();
  }
}

class WallpaperImpressionScope extends InheritedWidget {
  const WallpaperImpressionScope({super.key, required this.session, required super.child});
  final WallpaperImpressionSession session;
  static WallpaperImpressionSession? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WallpaperImpressionScope>()?.session;
  @override
  bool updateShouldNotify(WallpaperImpressionScope oldWidget) => session != oldWidget.session;
}

/// Counts a tile only after at least half its area remains visible for 500 ms.
class WallpaperImpression extends StatefulWidget {
  const WallpaperImpression({
    super.key,
    required this.itemId,
    required this.provider,
    required this.surface,
    required this.source,
    required this.index,
    required this.child,
    this.session,
    this.onVisible,
  });

  final String itemId;
  final String provider;
  final AnalyticsSurfaceValue surface;
  final String source;
  final int index;
  final Widget child;
  final WallpaperImpressionSession? session;
  final VoidCallback? onVisible;

  @override
  State<WallpaperImpression> createState() => _WallpaperImpressionState();
}

class _WallpaperImpressionState extends State<WallpaperImpression>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final Set<ScrollPosition> _positions = <ScrollPosition>{};
  Animation<double>? _secondaryAnimation;
  bool _initialized = false;
  Duration? _visibleSince;
  bool _recorded = false;
  late WallpaperImpressionSession _session;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _check());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _secondaryAnimation?.removeListener(_check);
    _secondaryAnimation = ModalRoute.of(context)?.secondaryAnimation;
    _secondaryAnimation?.addListener(_check);
    final WallpaperImpressionSession session =
        widget.session ?? WallpaperImpressionScope.maybeOf(context) ?? WallpaperImpressionSession.forContext(context);
    if (_initialized && _session != session) {
      _recorded = false;
      _visibleSince = null;
    }
    _session = session;
    _initialized = true;
    for (final position in _positions) {
      position.removeListener(_onScroll);
    }
    _positions.clear();
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        _positions.add((element.state as ScrollableState).position);
      }
      return true;
    });
    for (final position in _positions) {
      position.addListener(_onScroll);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _check();
    });
  }

  @override
  void didUpdateWidget(WallpaperImpression oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session ||
        oldWidget.itemId != widget.itemId ||
        oldWidget.provider != widget.provider) {
      _visibleSince = null;
      _recorded = false;
      if (widget.session != null) _session = widget.session!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _check();
      });
    }
  }

  bool _isVisible() {
    final bool tickerEnabled = TickerMode.of(context);
    final bool routeCurrent = ModalRoute.isCurrentOf(context) ?? true;
    if (!tickerEnabled || !routeCurrent) return false;
    final AppLifecycleState? lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return false;
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.attached || !object.hasSize || object.size.isEmpty) return false;
    final Rect bounds = object.localToGlobal(Offset.zero) & object.size;
    Rect visible = bounds.intersect(Offset.zero & MediaQuery.sizeOf(context));
    RenderObject? ancestor = object.parent;
    while (ancestor != null) {
      if (ancestor is RenderAbstractViewport && ancestor is RenderBox) {
        final RenderBox viewport = ancestor as RenderBox;
        visible = visible.intersect(viewport.localToGlobal(Offset.zero) & viewport.size);
      }
      ancestor = ancestor.parent;
    }
    return !visible.isEmpty && visible.width * visible.height >= bounds.width * bounds.height * 0.5;
  }

  void _onScroll() {
    _check();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _check();
    });
  }

  void _check() {
    if (!mounted || _recorded) return;
    if (!_isVisible()) {
      _visibleSince = null;
      _ticker.stop();
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _check();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
      return;
    }
    final Duration now = SchedulerBinding.instance.currentFrameTimeStamp;
    _visibleSince ??= now;
    if (now - _visibleSince! < const Duration(milliseconds: 500)) {
      if (!_ticker.isActive) _ticker.start();
      return;
    }
    _recorded = true;
    _ticker.stop();
    if (!_session.record(widget.provider, widget.itemId)) return;
    widget.onVisible?.call();
    unawaited(
      analytics.track(
        WallpaperImpressionEvent(
          itemId: widget.itemId,
          provider: widget.provider,
          surface: widget.surface.wireValue,
          requestId: _session.requestId,
          index: widget.index,
          source: widget.source,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _secondaryAnimation?.removeListener(_check);
    for (final position in _positions) {
      position.removeListener(_onScroll);
    }
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    TickerMode.of(context);
    ModalRoute.isCurrentOf(context);
    return widget.child;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visibleSince = null;
    _ticker.stop();
    if (state == AppLifecycleState.resumed) _check();
  }
}
