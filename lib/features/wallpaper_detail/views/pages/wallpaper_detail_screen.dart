import 'dart:async';
import 'dart:io';
import 'dart:math' show max, min;
import 'dart:ui' show lerpDouble;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/platform/system_accent_channel.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/wallpaper_detail_route.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/edge_to_edge_overlay_style.dart';
import 'package:Prism/core/utils/format_utils.dart';
import 'package:Prism/core/utils/localized_relative_time.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/wallpaper/original_access_service.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/wallpaper/wall_spatial.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_display_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/animated/shake_once.dart';
import 'package:Prism/core/widgets/content_report/content_report_sheet.dart';
import 'package:Prism/core/widgets/depth_tag.dart';
import 'package:Prism/core/widgets/menu_button/edit_button.dart';
import 'package:Prism/core/widgets/menu_button/fav_wallpaper_button.dart';
import 'package:Prism/core/widgets/menu_button/original_access_prompt.dart';
import 'package:Prism/core/widgets/menu_button/prepare_source.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/menu_button/share_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/progressive_wallpaper_image.dart';
import 'package:Prism/core/widgets/spatial_tag.dart';
import 'package:Prism/data/offline/bundled_wallpapers.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_quick_actions.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_pin_toggle.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_wallpaper_card.dart';
import 'package:Prism/features/favourite_walls/views/widgets/wallpaper_stats_row.dart';
import 'package:Prism/features/theme_mode/biz/bloc/theme_bloc.j.dart';
import 'package:Prism/features/theme_mode/domain/custom_accent.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_event.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/biz/block_wall_creator.dart';
import 'package:Prism/features/wallpaper_detail/biz/tag_search_launcher.dart';
import 'package:Prism/features/wallpaper_detail/biz/wallpaper_detail_rules.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_detail/data/wallpaper_tint_renderer.dart';
import 'package:Prism/features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_feed.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/accent_contrast.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/boost_wall_row.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/depth_effect_row.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/make_it_live_button.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/spatial_scene_row.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_action_bar.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_recommendations.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_tag_chips.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

@visibleForTesting
bool shouldRecordWallpaperSetStats(FeedItemEntity entity) =>
    entity.source == WallpaperSource.prism && !BundledWallpapers.isStarter(entity);

@RoutePage()
class WallpaperDetailScreen extends StatefulWidget implements AutoRouteWrapper {
  const WallpaperDetailScreen({
    super.key,
    this.entity,
    this.wallId,
    this.source,
    this.thumbnailUrl,
    this.analyticsSurface = AnalyticsSurfaceValue.wallpaperScreen,
    this.heroTag,
    this.localFile,
    this.requestId,
    this.feed,
  }) : assert(entity != null || (wallId != null && source != null), 'Either entity or wallId+source must be provided');

  final FeedItemEntity? entity;
  final String? wallId;
  final WallpaperSource? source;
  final String? thumbnailUrl;
  final AnalyticsSurfaceValue analyticsSurface;
  final String? requestId;

  /// Set when opened from a grid tile, so the tile image flies into this screen.
  final String? heroTag;

  /// Set when opened from Downloads: shown instead of the network image, and the fallback if loading fails.
  final File? localFile;

  /// The grid this wall was opened from. A sideways swipe on the card shows the next or previous wall in place.
  final WallpaperFeed? feed;

  // One bloc per route: a shared bloc showed the last wallpaper while the new one loaded.
  @override
  Widget wrappedRoute(BuildContext context) {
    final WallpaperFeed? feed = this.feed;
    final FeedItemEntity? entity = this.entity;
    final int start = feed == null || entity == null ? -1 : feed.indexOf(entity);
    if (feed != null && start >= 0) {
      return _DetailImmersion(
        child: _FeedBrowser(screen: this, feed: feed, start: start),
      );
    }
    return _DetailImmersion(
      child: BlocProvider<WallpaperDetailBloc>(
        key: ValueKey<(WallpaperSource, String)>((entity?.source ?? source!, entity?.id ?? wallId!)),
        create: (_) => getIt<WallpaperDetailBloc>(),
        child: this,
      ),
    );
  }

  @override
  State<WallpaperDetailScreen> createState() => _WallpaperDetailScreenState();
}

/// Lets the card of a wall opened from a feed drag the feed to its neighbours.
class _FeedStep extends InheritedWidget {
  const _FeedStep({
    required this.browser,
    required this.active,
    required this.hasPrevious,
    required this.hasNext,
    required super.child,
  });

  final _FeedBrowserState browser;

  /// The wall the feed rests on or settles to. A neighbour shown during a drag is not active and does not load.
  final bool active;
  final bool hasPrevious;
  final bool hasNext;

  static _FeedStep? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_FeedStep>();

  void step(int delta) => browser._settle(browser._target + delta, 0);
  void dragStart() => browser._position.stop();
  void dragUpdate(double dx) => browser._dragUpdate(dx);
  void dragEnd(double velocity) => browser._dragEnd(velocity);

  @override
  bool updateShouldNotify(_FeedStep oldWidget) =>
      active != oldWidget.active || hasPrevious != oldWidget.hasPrevious || hasNext != oldWidget.hasNext;
}

/// Immersive mode for one detail route: the wall fills the screen, and every control and the system bars hide. The walls
/// of a feed share it, so a swipe stays immersive. Back, leaving the route, sending the app to the background and an
/// error all turn it off, and the system bars come back with it.
class _DetailImmersion extends StatefulWidget {
  const _DetailImmersion({required this.child});

  final Widget child;

  @override
  State<_DetailImmersion> createState() => _DetailImmersionState();
}

class _DetailImmersionState extends State<_DetailImmersion>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller = AnimationController(vsync: this, duration: PrismDurations.base);
  late final Animation<double> _progress = CurvedAnimation(parent: _controller, curve: PrismCurves.enter);
  late final Animation<double> _controls = ReverseAnimation(_progress);
  bool _on = false;
  bool _barsHidden = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A route pushed on top, such as a sheet, gets the system bars back.
    if (!(ModalRoute.isCurrentOf(context) ?? true)) _set(false, rebuild: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _set(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _showBars(true);
    _controller.dispose();
    super.dispose();
  }

  void toggle(ImmersiveToggleSourceValue source) {
    _set(!_on);
    unawaited(analytics.track(DetailImmersiveToggledEvent(immersive: _on, source: source)));
  }

  void exit() => _set(false);

  void _set(bool on, {bool rebuild = true}) {
    if (on == _on) return;
    _on = on;
    if (rebuild) setState(() {});
    _controller.duration = context.motion(PrismDurations.base);
    on ? _controller.forward() : _controller.reverse();
    _showBars(!on);
  }

  void _showBars(bool show) {
    if (show != _barsHidden) return;
    _barsHidden = !show;
    unawaited(
      SystemChrome.setEnabledSystemUIMode(show ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky).catchError(
        (Object error, StackTrace stackTrace) =>
            logger.w('Unable to change the system UI mode.', error: error, stackTrace: stackTrace),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_on,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) exit();
      },
      child: _Immersion(state: this, on: _on, child: widget.child),
    );
  }
}

class _Immersion extends InheritedWidget {
  const _Immersion({required this.state, required this.on, required super.child});

  final _DetailImmersionState state;
  final bool on;

  /// 0 shows the card and the controls, 1 is immersive.
  Animation<double> get progress => state._progress;

  /// The opacity of the controls: 1 shown, 0 hidden.
  Animation<double> get controls => state._controls;

  void toggle(ImmersiveToggleSourceValue source) => state.toggle(source);
  void exit() => state.exit();

  static _Immersion? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_Immersion>();

  /// For callbacks: reads without rebuilding on a change.
  static _Immersion? read(BuildContext context) => context.getInheritedWidgetOfExactType<_Immersion>();

  @override
  bool updateShouldNotify(_Immersion oldWidget) => on != oldWidget.on;
}

/// The card area: a tap, a sideways drag of the feed and, when [zoomable], a pinch that zooms the wall and lets go
/// when the fingers lift. A touch that pinched or dragged is never a tap.
///
/// A surface that leaves the tree mid-drag gets no drag end, as the loading overlay does when its wall finishes loading,
/// so it settles the feed itself after the frame.
class _FeedDragSurface extends StatefulWidget {
  const _FeedDragSurface({required this.feed, this.onTap, this.zoomable = false, required this.child});

  final _FeedStep? feed;
  final VoidCallback? onTap;
  final bool zoomable;
  final Widget child;

  @override
  State<_FeedDragSurface> createState() => _FeedDragSurfaceState();
}

class _FeedDragSurfaceState extends State<_FeedDragSurface> with SingleTickerProviderStateMixin {
  static const double _maxZoom = 4;

  bool _dragging = false;
  final Map<int, Offset> _touches = <int, Offset>{};

  /// This touch pinched or dragged, so lifting it is not a tap.
  bool _spent = false;

  /// The two fingers of a pinch, where they met, and the zoom when they landed.
  ({int a, int b, Offset focal, double span, double scale, Offset shift})? _pinch;
  double _scale = 1;
  Offset _shift = Offset.zero;
  late final AnimationController _release = AnimationController(vsync: this)..addListener(_onRelease);
  ({double scale, Offset shift}) _releaseFrom = (scale: 1, shift: Offset.zero);

  @override
  void didUpdateWidget(_FeedDragSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.zoomable && oldWidget.zoomable) {
      _pinch = null;
      _release.stop();
      _scale = 1;
      _shift = Offset.zero;
    }
  }

  @override
  void dispose() {
    final _FeedBrowserState? browser = widget.feed?.browser;
    if (_dragging && browser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (browser.mounted) browser._dragEnd(0);
      });
    }
    _release.dispose();
    super.dispose();
  }

  void _onDown(PointerDownEvent event) {
    if (_touches.isEmpty) _spent = false;
    _touches[event.pointer] = event.localPosition;
    if (_touches.length < 2) return;
    _spent = true;
    // A second finger turns a swipe into a pinch, so the feed settles where it is.
    _endDrag();
    if (widget.zoomable && _pinch == null) _startPinch();
  }

  void _onMove(PointerMoveEvent event) {
    if (!_touches.containsKey(event.pointer)) return;
    _touches[event.pointer] = event.localPosition;
    final pinch = _pinch;
    final Offset? a = _touches[pinch?.a];
    final Offset? b = _touches[pinch?.b];
    if (pinch == null || a == null || b == null) return;
    final double scale = (pinch.scale * (a - b).distance / pinch.span).clamp(1.0, _maxZoom);
    // The point of the wall under the fingers when they landed stays under them.
    final Offset content = (pinch.focal - pinch.shift) / pinch.scale;
    setState(() {
      _scale = scale;
      _shift = (a + b) / 2 - content * scale;
    });
  }

  void _onUp(PointerEvent event) {
    _touches.remove(event.pointer);
    final pinch = _pinch;
    if (pinch != null && (event.pointer == pinch.a || event.pointer == pinch.b)) {
      _pinch = null;
      _letGo();
    }
  }

  void _startPinch() {
    final List<int> ids = _touches.keys.take(2).toList(growable: false);
    final Offset a = _touches[ids[0]]!;
    final Offset b = _touches[ids[1]]!;
    final double span = (a - b).distance;
    if (span < 1) return;
    _release.stop();
    _pinch = (a: ids[0], b: ids[1], focal: (a + b) / 2, span: span, scale: _scale, shift: _shift);
  }

  void _letGo() {
    if (_scale == 1 && _shift == Offset.zero) return;
    _releaseFrom = (scale: _scale, shift: _shift);
    final Duration duration = context.motion(PrismDurations.base);
    if (duration == Duration.zero) {
      setState(() {
        _scale = 1;
        _shift = Offset.zero;
      });
      return;
    }
    _release
      ..duration = duration
      ..forward(from: 0);
  }

  void _onRelease() {
    final double t = PrismCurves.enter.transform(_release.value);
    setState(() {
      _scale = lerpDouble(_releaseFrom.scale, 1, t)!;
      _shift = Offset.lerp(_releaseFrom.shift, Offset.zero, t)!;
    });
  }

  void _endDrag() {
    if (!_dragging) return;
    _dragging = false;
    widget.feed?.dragEnd(0);
  }

  @override
  Widget build(BuildContext context) {
    final _FeedStep? feed = widget.feed;
    final bool zoomed = _scale != 1 || _shift != Offset.zero;
    return Listener(
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onUp,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The card's own Semantics carries the tap and the feed steps.
        excludeFromSemantics: true,
        onTap: widget.onTap == null
            ? null
            : () {
                if (!_spent) widget.onTap!();
              },
        onHorizontalDragStart: feed == null
            ? null
            : (_) {
                _spent = true;
                if (_touches.length > 1) return;
                _dragging = true;
                feed.dragStart();
              },
        onHorizontalDragUpdate: feed == null
            ? null
            : (details) {
                if (_dragging) feed.dragUpdate(details.primaryDelta ?? 0);
              },
        onHorizontalDragEnd: feed == null
            ? null
            : (details) {
                if (!_dragging) return;
                _dragging = false;
                feed.dragEnd(details.primaryVelocity ?? 0);
              },
        onHorizontalDragCancel: feed == null ? null : _endDrag,
        // The same widgets with or without a zoom, so the picture never rebuilds from scratch.
        child: ClipRect(
          clipBehavior: zoomed ? Clip.hardEdge : Clip.none,
          child: Transform(
            transform: Matrix4.translationValues(_shift.dx, _shift.dy, 0)..scaleByDouble(_scale, _scale, 1, 1),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Pages through a feed in place. Each wall gets its own bloc and screen, as a new route would.
class _FeedBrowser extends StatefulWidget {
  const _FeedBrowser({required this.screen, required this.feed, required this.start});

  final WallpaperDetailScreen screen;
  final WallpaperFeed feed;
  final int start;

  @override
  State<_FeedBrowser> createState() => _FeedBrowserState();
}

class _FeedBrowserState extends State<_FeedBrowser> with SingleTickerProviderStateMixin {
  /// A fling faster than this, in logical pixels a second, moves to the wall it points at.
  static const double _flingVelocity = 300;
  static final SpringDescription _spring = SpringDescription.withDampingRatio(mass: 1, stiffness: 500);

  late final AnimationController _position = AnimationController.unbounded(vsync: this, value: widget.start.toDouble())
    ..addListener(_onMove);
  late int _target = widget.start;
  late (int, int) _span = (widget.start, widget.start);
  double _width = 1;

  List<WallpaperFeedTile> get _tiles => widget.feed.tiles;
  double get _sign => Directionality.of(context) == TextDirection.rtl ? -1 : 1;

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  void _onMove() {
    final double position = _position.value;
    final (int, int) span = (position.floor(), position.ceil());
    if (span != _span) setState(() => _span = span);
  }

  void _dragUpdate(double dx) {
    _position.value = (_position.value - dx * _sign / _width).clamp(0.0, _tiles.length - 1.0);
  }

  void _dragEnd(double velocity) {
    final double walls = -velocity * _sign / _width;
    final double position = _position.value;
    final int target = velocity.abs() > _flingVelocity
        ? (walls > 0 ? position.ceil() : position.floor())
        : position.round();
    _settle(target, walls);
  }

  /// Moves to [target], at [velocity] walls a second, and makes it the active wall at once so it starts loading.
  void _settle(int target, double velocity) {
    final int next = target.clamp(0, _tiles.length - 1);
    if (next != _target) {
      PrismHaptics.selection();
      setState(() => _target = next);
    }
    if (context.reduceMotion) {
      _position.value = next.toDouble();
      return;
    }
    // A fast fling overshoots the target. Past either end there is no wall to show.
    _position.animateWith(
      ClampedSimulation(
        SpringSimulation(_spring, _position.value, next.toDouble(), velocity, snapToEnd: true),
        xMin: 0,
        xMax: _tiles.length - 1.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<int> shown = <int>{_span.$1, _span.$2, _target}.toList()..sort();
    return PopScope(
      // A back swipe shows the grid as it is, so moving it under the finger would jump.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !Navigator.of(context).userGestureInProgress) widget.feed.reveal(_target);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          _width = max(1, constraints.maxWidth);
          return Stack(children: [for (final int index in shown) _page(index)]);
        },
      ),
    );
  }

  Widget _page(int index) {
    final WallpaperFeedTile tile = _tiles[index];
    final WallpaperDetailScreen screen = widget.screen;
    final bool active = index == _target;
    return AnimatedBuilder(
      key: ValueKey<int>(index),
      animation: _position,
      builder: (context, child) =>
          FractionalTranslation(translation: Offset((index - _position.value) * _sign, 0), child: child),
      child: HeroMode(
        enabled: active,
        child: ExcludeSemantics(
          excluding: !active,
          child: IgnorePointer(
            ignoring: !active,
            child: _FeedStep(
              browser: this,
              active: active,
              hasPrevious: index > 0,
              hasNext: index < _tiles.length - 1,
              child: BlocProvider<WallpaperDetailBloc>(
                create: (_) => getIt<WallpaperDetailBloc>(),
                child: WallpaperDetailScreen(
                  entity: tile.item,
                  analyticsSurface: screen.analyticsSurface,
                  requestId: screen.requestId,
                  heroTag: tile.heroTag,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WallpaperDetailScreenState extends State<WallpaperDetailScreen> {
  /// The set or save button of the phone preview. The action bar rebuilds it, so it always has the current tint.
  /// The Set button in the action bar. On Android the phone preview opens its Set screen.
  final GlobalKey<SetWallpaperButtonState> _setButtonKey = GlobalKey<SetWallpaperButtonState>();

  /// iOS only: builds Save to Photos for the phone preview.
  Widget Function(String label)? _saveAction;
  static const double _sheetHPad = PrismSpace.md;

  /// Text and icons in the panel that sit one step below the title.
  static const double _secondaryAlpha = 0.85;

  /// The wallpaper is a card just under the status bar: a small side gap and large corners.
  static const double _cardInset = PrismSpace.xxs;
  static const double _cardRadius = PrismRadius.lg;

  /// A tall card stops at this share of the screen, so the actions and the next wallpapers show on the first screen.
  static const double _maxCardShare = 0.66;

  /// The widest a card gets for its height. On a phone the card spans the screen. On a tablet or in landscape it
  /// narrows and centres instead of cropping a tall wallpaper to a strip.
  static const double _widestCardAspect = 0.85;

  /// Back and the clock sit this far inside the top corners of the card.
  static const double _chromePad = PrismSpace.xxs;
  static const double _chromeSize = 44;

  /// A colour variation swatch, and the 44 point target around it that holds its selection ring.
  static const double _swatchSize = 36;
  static const double _swatchTarget = 44;

  /// "Set N times" shows from this count, so a small number never reads as a poor wallpaper.
  static const int _minSetCountShown = 5;

  /// Set once the first detail screen showed the "Tap to hide controls" hint.
  static const String _immersiveHintKey = 'wallpaper_detail.immersive_hint_shown';
  static const Duration _immersiveHintTime = Duration(seconds: 3);

  final ShakeController _shake = ShakeController();
  bool _immersive = false;
  bool _hintChecked = false;
  bool _hintVisible = false;
  Timer? _hintTimer;
  final ScrollController _scroll = ScrollController();
  final Object _recommendationHeroScope = Object();

  /// Scroll offsets between which the card is under the status bar icons. Past the end the rows and the feed are under
  /// them, on a fade of the page colour so the icons stay readable.
  double _imageStatusStart = double.infinity;
  double _imageStatusEnd = double.infinity;
  bool _imageBehindStatusBar = false;
  bool _feedBehindStatusBar = false;

  bool _imageUnderStatusBar(double offset) => offset > _imageStatusStart && offset < _imageStatusEnd;

  void _loadMoreRecommendations() {
    context.read<WallpaperDetailBloc>().add(const LoadRecommendations());
  }

  void _onDiscoveryScroll() {
    if (_scroll.hasClients) {
      final imageBehindStatusBar = _imageUnderStatusBar(_scroll.offset);
      final feedBehindStatusBar = _scroll.offset >= _imageStatusEnd;
      if (imageBehindStatusBar != _imageBehindStatusBar || feedBehindStatusBar != _feedBehindStatusBar) {
        setState(() {
          _imageBehindStatusBar = imageBehindStatusBar;
          _feedBehindStatusBar = feedBehindStatusBar;
        });
      }
    }
    final state = context.read<WallpaperDetailBloc>().state;
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 600 &&
        state is WallpaperDetailLoaded &&
        !state.recommendations.loading &&
        !state.recommendations.failed &&
        state.recommendations.hasMore) {
      _loadMoreRecommendations();
    }
  }

  bool _openRecorded = false;
  bool _loaded = false;
  String? _offlinePreviewKey;
  Future<File?>? _offlinePreviewFuture;

  void _recordTaste(TasteAction action, FeedItemEntity entity) {
    final TasteSignal signal = entity.when(
      prism: (_, w) => TasteSignal.forWallpaper(action, w.core, tags: w.tags, collections: w.collections),
      wallhaven: (_, w) => TasteSignal.forWallpaper(action, w.core, tags: w.tags),
      pexels: (_, w) => TasteSignal.forWallpaper(action, w.core),
    );
    unawaited(getIt<TasteSignalStore>().record(signal));
  }

  String _getSourceContext(WallpaperDetailState? blocState) {
    final source = blocState is WallpaperDetailLoaded ? blocState.entity.source : widget.source;
    return '${source?.wireValue ?? 'unknown'}_wallpaper_screen';
  }

  void _trackAction(WallpaperDetailState? blocState, AnalyticsActionValue action) {
    final itemId = blocState is WallpaperDetailLoaded ? blocState.entity.id : null;
    unawaited(
      analytics.track(
        SurfaceActionTappedEvent(
          surface: widget.analyticsSurface,
          action: action,
          sourceContext: _getSourceContext(blocState),
          itemType: ItemTypeValue.wallpaper,
          itemId: itemId,
          requestId: widget.requestId,
          provider: blocState is WallpaperDetailLoaded ? blocState.entity.source.name : widget.source?.name,
        ),
      ),
    );
  }

  void _handlePanelOpened(BuildContext context, WallpaperDetailLoaded state) {
    context.read<WallpaperDetailBloc>().add(const OnPanelOpened());
    _trackAction(state, AnalyticsActionValue.panelOpened);
  }

  void _handlePanelClosed(BuildContext context, WallpaperDetailLoaded state) {
    context.read<WallpaperDetailBloc>().add(const OnPanelClosed());
    _trackAction(state, AnalyticsActionValue.panelClosed);
  }

  void _handleAccentLongPress(BuildContext context, WallpaperDetailLoaded state) {
    context.read<WallpaperDetailBloc>().add(const ResetAccentColor());
    _trackAction(state, AnalyticsActionValue.paletteResetLongPressed);
    PrismHaptics.impact();
    _shake.shake();
  }

  void _handleColorSelected(BuildContext context, Color color) {
    context.read<WallpaperDetailBloc>().add(SelectAccentColor(color: color));
  }

  Future<void> _useAsAppAccent(BuildContext context, Color color) async {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (!accentReadsOn(color, Theme.of(context).colorScheme.surface)) {
      toasts.error(context.l10n.coreCustomAccentLowContrast);
      return;
    }
    PrismHaptics.selection();
    await getIt<SettingsLocalDataSource>().set(SystemAccentChannel.settingsKey, false);
    if (!context.mounted) return;
    if (dark) {
      context.setPrismDarkAccent(color);
    } else {
      context.setPrismLightAccent(color);
    }
    analytics.track(AccentChangedEvent(color: color.rgbHex));
    toasts.success(context.l10n.wallpaperAppAccentUpdated);
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onDiscoveryScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool immersive = _Immersion.maybeOf(context)?.on ?? false;
    if (immersive && !_immersive) {
      _hideHint();
      // The card grows from the top of the page, so the page scrolls back to it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients || _scroll.offset <= 0) return;
        final Duration duration = context.motion(PrismDurations.base);
        duration == Duration.zero
            ? _scroll.jumpTo(0)
            : unawaited(_scroll.animateTo(0, duration: duration, curve: PrismCurves.enter));
      });
    }
    _immersive = immersive;
    // A neighbour shown during a drag shows its tile picture and loads only when the feed settles on it.
    if (!_loaded && (_FeedStep.maybeOf(context)?.active ?? true)) {
      _loaded = true;
      _loadWallpaper(context);
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _shake.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _loadWallpaper(BuildContext context) {
    final bloc = context.read<WallpaperDetailBloc>();
    final entity = widget.entity;
    if (entity != null) {
      bloc.add(LoadFromEntity(entity: entity, localFilePath: widget.localFile?.path));
    } else {
      bloc.add(
        LoadFromId(
          wallId: widget.wallId!,
          source: widget.source!,
          thumbnailUrl: widget.thumbnailUrl,
          localFilePath: widget.localFile?.path,
        ),
      );
    }
  }

  void _toggleImmersive() {
    _hideHint();
    _Immersion.read(context)?.toggle(ImmersiveToggleSourceValue.tap);
  }

  /// Shows "Tap to hide controls" on the first wall the user ever opens, for a few seconds.
  void _maybeShowImmersiveHint() {
    if (_hintChecked || !mounted) return;
    _hintChecked = true;
    if (_Immersion.read(context) == null || !getIt.isRegistered<SettingsLocalDataSource>()) return;
    final SettingsLocalDataSource settings = getIt<SettingsLocalDataSource>();
    if (settings.get<bool>(_immersiveHintKey, defaultValue: false)) return;
    unawaited(settings.set(_immersiveHintKey, true));
    unawaited(analytics.track(const DetailImmersiveHintShownEvent()));
    setState(() => _hintVisible = true);
    _hintTimer = Timer(_immersiveHintTime, _hideHint);
  }

  void _hideHint() {
    _hintTimer?.cancel();
    if (mounted && _hintVisible) setState(() => _hintVisible = false);
  }

  /// A control that fades out, and leaves the semantics tree, while the wall is immersive.
  Widget _hiddenWhenImmersive(Widget child) {
    final _Immersion? immersion = _Immersion.maybeOf(context);
    if (immersion == null) return child;
    return IgnorePointer(
      ignoring: immersion.on,
      child: ExcludeSemantics(
        excluding: immersion.on,
        child: FadeTransition(opacity: immersion.controls, child: child),
      ),
    );
  }

  /// The top of the card: just under the status bar.
  double _statusInset(BuildContext context) => app_state.notchSize ?? MediaQuery.paddingOf(context).top;

  @override
  Widget build(BuildContext context) {
    return BlocListener<WallpaperDetailBloc, WallpaperDetailState>(
      listener: (context, state) {
        if (state is WallpaperDetailError) _Immersion.read(context)?.exit();
        if (state is WallpaperDetailError &&
            widget.localFile?.existsSync() == true &&
            ModalRoute.of(context)?.isCurrent == true) {
          context.router.replace(DownloadWallpaperRoute(source: WallpaperSource.downloaded, file: widget.localFile!));
          return;
        }
        if (state is WallpaperDetailLoaded && !state.recommendations.started) {
          _loadMoreRecommendations();
        }
        if (state is WallpaperDetailLoaded && !_openRecorded) {
          _openRecorded = true;
          _recordTaste(TasteAction.open, state.entity);
        }
      },
      child: BlocBuilder<WallpaperDetailBloc, WallpaperDetailState>(
        builder: (context, state) {
          final entity = widget.entity;
          return switch (state) {
            // Keep the destination Hero mounted while Prism resolves its canonical access policy.
            WallpaperDetailInitial() || WallpaperDetailLoading() when entity != null => _buildLoadedState(
              context,
              WallpaperDetailLoaded(entity: entity),
              canonicalLoading: true,
            ),
            WallpaperDetailInitial() || WallpaperDetailLoading() => _buildLoadingState(state),
            WallpaperDetailLoaded() => _buildLoadedState(context, state),
            WallpaperDetailError() => _buildErrorState(state),
          };
        },
      ),
    );
  }

  Widget _buildLoadingState(WallpaperDetailState state) {
    final localFile = widget.localFile;
    final thumbnail = normalizeWallpaperThumbnailUrl(
      (state is WallpaperDetailLoading ? state.thumbnailUrl : widget.thumbnailUrl) ?? widget.entity?.thumbnailUrl ?? '',
    );
    final Size card = _cardSize(context, widget.entity?.wallpaperCore);
    final Widget image;
    if (localFile != null) {
      image = ProgressiveWallpaperImage(
        display: WallpaperDisplaySource(thumbnail: '', full: localFile.path),
        decodeBox: card,
        errorBuilder: (_, _) =>
            GlintState(kind: GlintStateKind.error, title: context.l10n.wallpaperDownloadedWallpaperUnavailable),
      );
    } else if (thumbnail.isNotEmpty) {
      image = ProgressiveWallpaperImage(display: _routeDisplay(thumbnail), decodeBox: card);
    } else {
      image = GlintState(kind: GlintStateKind.loading, title: context.l10n.wallpaperLoadingWallpaper);
    }
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            top: false,
            bottom: false,
            // Scrolls rather than overflowing a short or split-screen window.
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(_cardInset, _statusInset(context), _cardInset, 0),
                    child: SizedBox.fromSize(size: card, child: _withHero(image)),
                  ),
                  _panelColumn(_buildPendingDetails()),
                ],
              ),
            ),
          ),
          ..._pinnedChrome(state, card),
        ],
      ),
    );
  }

  /// Back and, once the wallpaper is ready, the clock. Both stay in the top corners of the card while the page
  /// scrolls under them, on a dark scrim that reads over any wallpaper.
  List<Widget> _pinnedChrome(WallpaperDetailState state, Size card, {VoidCallback? onClock}) {
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final double top = _statusInset(context) + _chromePad;
    // A narrowed card is centred, so its corners sit in from the side insets.
    final double centring = max(0.0, (_availableCardWidth(context) - card.width) / 2);
    return [
      PositionedDirectional(
        start: padding.left + _cardInset + centring + _chromePad,
        top: top,
        child: _hiddenWhenImmersive(
          _chromeButton(
            icon: JamIcons.chevron_left,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () {
              _trackAction(state, AnalyticsActionValue.backTapped);
              Navigator.pop(context);
            },
          ),
        ),
      ),
      if (onClock != null)
        PositionedDirectional(
          end: padding.right + _cardInset + centring + _chromePad,
          top: top,
          child: _hiddenWhenImmersive(
            _chromeButton(
              icon: Icons.smartphone_rounded,
              tooltip: context.l10n.wallpaperPreviewOnScreen,
              onPressed: onClock,
            ),
          ),
        ),
    ];
  }

  Widget _chromeButton({required IconData icon, required String tooltip, required VoidCallback onPressed}) {
    return PressScale(
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        color: PrismColors.onPrimary,
        style: IconButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.55),
          minimumSize: const Size.square(_chromeSize),
          fixedSize: const Size.square(_chromeSize),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
        ),
      ),
    );
  }

  /// The card. From a tile it is the Hero that flies in, and the route grows the page out of the tile with it.
  Widget _withHero(Widget image) {
    final Animation<double> immersion = _Immersion.maybeOf(context)?.progress ?? kAlwaysDismissedAnimation;
    return AnimatedBuilder(
      animation: immersion,
      child: image,
      builder: (context, image) {
        // Immersive, the card loses its corners as it fills the screen.
        final double radius = lerpDouble(_cardRadius, 0, immersion.value)!;
        if (widget.heroTag == null) return ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
        return HeroMode(
          enabled: !context.reduceMotion,
          child: WallpaperDetailHero(tag: widget.heroTag!, radius: radius, image: image!),
        );
      },
    );
  }

  /// The wall this route was opened for, before its entity loads.
  WallpaperDisplaySource _routeDisplay(String thumbnail) {
    final FeedItemEntity? entity = widget.entity;
    if (entity != null) return WallpaperDisplaySource.of(entity);

    final String? id = widget.wallId;
    final WallpaperSource source = widget.source ?? WallpaperSource.prism;
    if (id == null || id.isEmpty) return const WallpaperDisplaySource(thumbnail: '', full: '');
    final String safeThumbnail = source == WallpaperSource.prism && !isSafePrismThumbnailUrl(thumbnail)
        ? ''
        : thumbnail;
    return WallpaperDisplaySource.forWall(id: id, source: source, thumbnail: safeThumbnail);
  }

  Widget _buildErrorState(WallpaperDetailError state) {
    final theme = Theme.of(context);
    final thumbnailUrl = normalizeWallpaperThumbnailUrl(state.thumbnailUrl ?? '');
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl.isNotEmpty) ProgressiveWallpaperImage(display: _routeDisplay(thumbnailUrl)),
          Container(color: theme.primaryColor.withValues(alpha: thumbnailUrl.isEmpty ? 1 : 0.8)),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: GlintState(
                    kind: GlintStateKind.error,
                    title: context.l10n.wallpaperOpenError,
                    body: switch (state.failure) {
                      WallpaperDetailLoadFailure.notFound => context.l10n.wallpaperDetailNotFound,
                      WallpaperDetailLoadFailure.unavailable => context.l10n.wallpaperCheckConnection,
                    },
                    actionLabel: context.l10n.wallpaperTryAgain,
                    onAction: () => _loadWallpaper(context),
                  ),
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.wallpaperGoBack)),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadedState(BuildContext context, WallpaperDetailLoaded state, {bool canonicalLoading = false}) {
    if (!canonicalLoading && !_hintChecked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowImmersiveHint());
    }
    final _FeedStep? feed = _FeedStep.maybeOf(context);
    final _Immersion? immersion = _Immersion.maybeOf(context);
    final bool immersive = immersion?.on ?? false;
    final Animation<double> progress = immersion?.progress ?? kAlwaysDismissedAnimation;
    final EdgeInsets safePadding = MediaQuery.paddingOf(context);
    final Size screen = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);
    final Size card = _cardSize(context, state.entity.wallpaperCore);
    final double statusInset = _statusInset(context);
    // The status bar icons sit about half way down the inset. The card is under them from when its top edge passes
    // them until its bottom edge does.
    _imageStatusStart = statusInset / 2;
    _imageStatusEnd = card.height + statusInset / 2;
    _imageBehindStatusBar = _scroll.hasClients && _imageUnderStatusBar(_scroll.offset);
    _feedBehindStatusBar = _scroll.hasClients && _scroll.offset >= _imageStatusEnd;
    final chromeBackground = _imageBehindStatusBar
        ? (state.paletteLoading ? theme.primaryColor : state.accent ?? theme.scaffoldBackgroundColor)
        : theme.scaffoldBackgroundColor;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: edgeToEdgeOverlayStyle(
        statusBarIconBrightness: onColor(chromeBackground) == Colors.black ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: canonicalLoading,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (canonicalLoading) return false;
                    if (notification is ScrollStartNotification) {
                      context.read<WallpaperDetailBloc>().add(const OnPanelScrollStart());
                    } else if (notification is ScrollEndNotification) {
                      context.read<WallpaperDetailBloc>().add(const OnPanelScrollEnd());
                    }
                    return false;
                  },
                  child: CustomScrollView(
                    key: PageStorageKey<Object>(_recommendationHeroScope),
                    controller: _scroll,
                    // Immersive, the wall is the whole page.
                    physics: immersive ? const NeverScrollableScrollPhysics() : null,
                    slivers: [
                      // Immersive, the card grows to the whole screen.
                      AnimatedBuilder(
                        animation: progress,
                        child: _buildImageBody(
                          context,
                          state.paletteLoading,
                          state,
                          canonicalLoading: canonicalLoading,
                        ),
                        builder: (context, body) => SliverPadding(
                          padding: EdgeInsets.lerp(
                            EdgeInsets.fromLTRB(
                              safePadding.left + _cardInset,
                              statusInset,
                              safePadding.right + _cardInset,
                              0,
                            ),
                            EdgeInsets.zero,
                            progress.value,
                          )!,
                          sliver: SliverToBoxAdapter(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: SizedBox.fromSize(size: Size.lerp(card, screen, progress.value), child: body),
                            ),
                          ),
                        ),
                      ),
                      SliverIgnorePointer(
                        ignoring: immersive,
                        sliver: SliverFadeTransition(
                          opacity: immersion?.controls ?? kAlwaysCompleteAnimation,
                          sliver: SliverMainAxisGroup(
                            slivers: [
                              if (canonicalLoading)
                                SliverToBoxAdapter(
                                  child: SafeArea(
                                    top: false,
                                    bottom: false,
                                    child: _panelColumn(_buildPendingDetails()),
                                  ),
                                )
                              else ...[
                                SliverToBoxAdapter(
                                  child: SafeArea(
                                    top: false,
                                    bottom: false,
                                    child: _panelColumn(_buildActionBar(context, state)),
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: SafeArea(
                                    top: false,
                                    bottom: false,
                                    child: _panelColumn(_buildColorBar(context, state)),
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: SafeArea(
                                    top: false,
                                    bottom: false,
                                    child: _panelColumn(_buildSummary(context, state)),
                                  ),
                                ),
                                if (!state.panelCollapsed)
                                  SliverToBoxAdapter(
                                    child: SafeArea(
                                      top: false,
                                      bottom: false,
                                      child: _panelColumn(
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _buildMetadataRow(context, state.entity, state),
                                            ..._buildPanelExtras(context, state),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                WallpaperRecommendations(
                                  state: state.recommendations,
                                  heroScope: _recommendationHeroScope,
                                  onLoadMore: _loadMoreRecommendations,
                                  onOpen: (item, hero, feed) => context.router.push(
                                    WallpaperDetailRoute(
                                      entity: item,
                                      thumbnailUrl: item.thumbnailUrl,
                                      heroTag: hero,
                                      feed: feed,
                                    ),
                                  ),
                                ),
                                SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (canonicalLoading && feed != null) _feedSwipeOverlay(feed, card, statusInset),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: statusInset + PrismSpace.sm,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  key: const ValueKey<String>('detail-status-fade'),
                  opacity: _feedBehindStatusBar ? 1 : 0,
                  duration: context.motion(PrismDurations.fast),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.6, 1],
                        colors: [theme.scaffoldBackgroundColor, theme.scaffoldBackgroundColor.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ..._pinnedChrome(
              state,
              card,
              onClock: canonicalLoading
                  ? null
                  : () {
                      final entity = state.entity;
                      _trackAction(state, AnalyticsActionValue.clockOverlayOpened);
                      if (!hideSetWallpaperUi) {
                        unawaited(_setButtonKey.currentState?.openSetScreen(entryPoint: 'wallpaper_preview'));
                        return;
                      }
                      final display = WallpaperDisplaySource.of(entity);
                      pushClockPreview(
                        context,
                        link: widget.localFile?.path ?? display.bestLink,
                        file: widget.localFile != null,
                        wallpaperId: entity.id,
                        wallpaperSource: entity.source,
                        thumbnailUrl: display.thumbnail,
                        tint: state.tint,
                        saveAction: _saveAction,
                        spatialMapUrl: spatialOf(entity)?.mapUrl,
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedSwipeOverlay(_FeedStep feed, Size card, double statusInset) {
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final double start = padding.left + _cardInset + max(0, (_availableCardWidth(context) - card.width) / 2);
    final Rect cardRect = Rect.fromLTWH(start, statusInset, card.width, card.height);
    final Rect screen = Offset.zero & MediaQuery.sizeOf(context);
    final Animation<double> progress = _Immersion.maybeOf(context)?.progress ?? kAlwaysDismissedAnimation;
    // Over the card, or the whole screen while immersive. Positioned in its own Stack so it can follow the card.
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: progress,
        child: _cardSemantics(
          feed,
          child: _FeedDragSurface(feed: feed, onTap: _toggleImmersive, child: const SizedBox.expand()),
        ),
        builder: (context, child) => Stack(
          children: [Positioned.fromRect(rect: Rect.lerp(cardRect, screen, progress.value)!, child: child!)],
        ),
      ),
    );
  }

  /// What a screen reader hears on the card, with actions to hide or show the controls and to step through the feed.
  Widget _cardSemantics(_FeedStep? feed, {required Widget child}) {
    final _Immersion? immersion = _Immersion.maybeOf(context);
    final String? immersiveAction = immersion == null
        ? null
        : immersion.on
        ? context.l10n.wallpaperShowPreviewControls
        : context.l10n.wallpaperHidePreviewControls;
    void toggle() {
      _hideHint();
      immersion?.toggle(ImmersiveToggleSourceValue.semantics);
    }

    return Semantics(
      label: context.l10n.wallpaperImageSemanticLabel,
      hint: context.l10n.wallpaperImageSemanticHint,
      onTap: immersion == null ? null : toggle,
      onTapHint: immersiveAction,
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        if (immersiveAction != null) CustomSemanticsAction(label: immersiveAction): toggle,
        if (feed != null && feed.hasPrevious)
          CustomSemanticsAction(label: context.l10n.wallpaperPreviousInFeed): () => feed.step(-1),
        if (feed != null && feed.hasNext)
          CustomSemanticsAction(label: context.l10n.wallpaperNextInFeed): () => feed.step(1),
      },
      child: child,
    );
  }

  /// The rows under the card keep to the panel width on a tablet, as the details panel did.
  Widget _panelColumn(Widget child) => PrismMaxWidth(maxWidth: PrismLayout.panelWidth, child: child);

  double _availableCardWidth(BuildContext context) =>
      max(0.0, MediaQuery.sizeOf(context).width - MediaQuery.paddingOf(context).horizontal - 2 * _cardInset);

  /// Card size: the wallpaper's own shape across the width, up to [_maxCardShare] of the screen height. A taller
  /// wallpaper fills the card and crops at the top and bottom. The clock preview shows it whole.
  Size _cardSize(BuildContext context, WallpaperCore? core) {
    final viewport = MediaQuery.sizeOf(context);
    final stableCore = widget.entity?.wallpaperCore ?? core;
    final width = stableCore?.width;
    final height = stableCore?.height;
    final parts = stableCore?.resolution?.toLowerCase().split('x');
    final parsed = width != null && height != null && width > 0 && height > 0
        ? width / height
        : parts?.length == 2
        ? (double.tryParse(parts![0]) ?? 0) / (double.tryParse(parts[1]) ?? 1)
        : 9 / 16;
    final ratio = parsed.isFinite && parsed > 0 ? parsed : 9 / 16;
    final maxHeight = viewport.height * _maxCardShare;
    final cardWidth = min(
      min(_availableCardWidth(context), PrismLayout.panelWidth),
      maxHeight * max(ratio, _widestCardAspect),
    );
    return Size(cardWidth, min(cardWidth / ratio, maxHeight));
  }

  /// Placeholders in the shape of the actions and summary while Prism confirms the wallpaper, so nothing jumps when
  /// they arrive.
  Widget _buildPendingDetails() {
    return Semantics(
      label: context.l10n.wallpaperLoadingWallpaper,
      child: ExcludeSemantics(
        child: PrismSkeleton(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(_sheetHPad, PrismSpace.sm, PrismSpace.xs + _cardInset, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    PrismBone.circle(size: 26),
                    SizedBox(width: PrismSpace.lg),
                    PrismBone.circle(size: 26),
                    SizedBox(width: PrismSpace.lg),
                    PrismBone.circle(size: 26),
                    Spacer(),
                    PrismBone(width: 88, height: 46, radius: PrismRadius.md),
                  ],
                ),
                const SizedBox(height: PrismSpace.lg),
                Row(
                  children: [
                    for (int i = 0; i < 4; i++) ...[
                      const PrismBone.circle(size: _swatchSize),
                      const SizedBox(width: PrismSpace.xs),
                    ],
                  ],
                ),
                const SizedBox(height: PrismSpace.lg),
                const PrismBone(width: 120),
                const SizedBox(height: PrismSpace.xs),
                const PrismBone(width: 200, height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleDetails(BuildContext context, WallpaperDetailLoaded state) {
    if (state.panelScrollInProgress) return;
    _trackAction(state, AnalyticsActionValue.panelCollapseTapped);
    state.panelCollapsed ? _handlePanelOpened(context, state) : _handlePanelClosed(context, state);
  }

  /// Who made the wallpaper and where it is from, then its title and the details disclosure. A tap anywhere on it
  /// opens or closes the details.
  Widget _buildSummary(BuildContext context, WallpaperDetailLoaded state) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final FeedItemEntity entity = state.entity;
    final String name = entity.wallpaperCore.authorName?.trim() ?? '';
    final String? creator = name.isEmpty || name.contains('@') ? null : name;
    final String provider = entity.source == WallpaperSource.wallhaven
        ? context.l10n.wallpaperProviderWallhaven
        : entity.source.legacyProviderString;
    final String photo = entity.maybeWhen(prism: (_, wall) => wall.core.authorPhoto?.trim(), orElse: () => null) ?? '';
    return InkWell(
      onTap: () => _toggleDetails(context, state),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_sheetHPad, PrismSpace.xs, PrismSpace.xxs + _cardInset, PrismSpace.xs),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      PrismAvatar(url: photo, name: creator ?? provider, size: 22),
                      const SizedBox(width: PrismSpace.xs),
                      if (creator != null) ...[
                        Flexible(
                          child: Text(
                            creator,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PrismTextStyles.body(context).copyWith(color: cs.onSurface),
                          ),
                        ),
                        const SizedBox(width: PrismSpace.xs),
                      ],
                      Text(provider, maxLines: 1, style: PrismTextStyles.body(context)),
                    ],
                  ),
                  const SizedBox(height: PrismSpace.xxs + 2),
                  Text(
                    wallpaperPreviewTitle(context.l10n, entity),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PrismTextStyles.rowTitle(context).copyWith(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: state.panelCollapsed
                  ? context.l10n.wallpaperExpandDetails
                  : context.l10n.wallpaperCollapseDetails,
              onPressed: () => _toggleDetails(context, state),
              icon: AnimatedRotation(
                turns: state.panelCollapsed ? 0 : 0.5,
                duration: context.motion(PrismDurations.fast),
                curve: PrismCurves.move,
                child: const Icon(Icons.expand_more_rounded, size: 22),
              ),
              color: cs.onSurface,
              style: IconButton.styleFrom(
                backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                fixedSize: const Size.square(34),
                minimumSize: const Size.square(34),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.padded,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(PrismRadius.xs + 2)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorBar(BuildContext context, WallpaperDetailLoaded state) {
    final String fullUrl = state.entity.fullUrl.trim();
    if (widget.localFile != null || !isValidNetworkUrl(fullUrl)) {
      return _buildColorBarWithImage(context, state, localFile: widget.localFile);
    }

    return FutureBuilder<File?>(
      future: _offlinePreviewFor(state.entity),
      builder: (BuildContext context, AsyncSnapshot<File?> snapshot) {
        final bool pending = snapshot.connectionState != ConnectionState.done;
        final File? retained = snapshot.data;
        return _buildColorBarWithImage(
          context,
          state,
          localFile: !pending && retained != null && retained.existsSync() ? retained : null,
          withholdThumbnail: pending,
        );
      },
    );
  }

  Widget _buildColorBarWithImage(
    BuildContext context,
    WallpaperDetailLoaded state, {
    required File? localFile,
    bool withholdThumbnail = false,
  }) {
    final colors = state.colors;
    final thumbnailUrl = withholdThumbnail ? '' : WallpaperDisplaySource.of(state.entity).thumbnail;

    // Build the default (no-filter) swatch + one swatch per palette color.
    final swatches = <Widget>[
      _buildColorSwatch(
        context: context,
        thumbnailUrl: thumbnailUrl,
        localFile: localFile,
        color: null,
        isSelected: !state.colorChanged,
        onTap: () {
          context.read<WallpaperDetailBloc>().add(const ResetAccentColor());
        },
        onLongPress: null,
      ),
      for (final color in colors ?? const <Color>[])
        _buildColorSwatch(
          context: context,
          thumbnailUrl: thumbnailUrl,
          localFile: localFile,
          color: color,
          isSelected: state.colorChanged && color == state.accent,
          onTap: () => _handleColorSelected(context, color),
          onLongPress: () {
            PrismHaptics.impact();
            final String copiedMessage = context.l10n.wallpaperDetailColorCodeCopied;
            Clipboard.setData(
              ClipboardData(text: '#${color.rgbHex.toUpperCase()}'),
            ).then((_) => toasts.color(color, message: copiedMessage));
          },
        ),
    ];

    final Color? accent = state.accent;
    // A row of small round variations, the untouched wallpaper first. The ring sits inside each 44 point target.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: _sheetHPad - (_swatchTarget - _swatchSize) / 2),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: swatches),
          ),
        ),
        if (state.colorChanged && accent != null && _themeTakesAccent(context))
          Padding(
            padding: const EdgeInsetsDirectional.only(start: _sheetHPad, top: PrismSpace.sm),
            child: PrismButton(
              label: context.l10n.wallpaperUseAsAppAccent,
              icon: Icons.palette_outlined,
              variant: PrismButtonVariant.tonal,
              size: PrismButtonSize.compact,
              onPressed: () => _useAsAppAccent(context, accent),
            ),
          ),
      ],
    );
  }

  Widget _buildColorSwatch({
    required BuildContext context,
    required String thumbnailUrl,
    required File? localFile,
    required Color? color,
    required bool isSelected,
    required VoidCallback? onTap,
    required VoidCallback? onLongPress,
  }) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final label = color == null ? context.l10n.wallpaperAccentColorsOriginal : context.l10n.wallpaperAccentColor;
    final placeholder = color ?? cs.onSurface.withValues(alpha: 0.08);
    final hint = color == null ? null : context.l10n.wallpaperCopyAccentHexHint;
    final BlendMode? blendMode = color == null ? null : BlendMode.hue;
    return Semantics(
      button: onTap != null,
      selected: isSelected,
      label: label,
      hint: hint,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                PrismHaptics.selection();
                onTap();
              },
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: _swatchTarget,
          child: AnimatedContainer(
            duration: context.motion(PrismDurations.fast),
            curve: PrismCurves.move,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? cs.onSurface : Colors.transparent, width: 2),
            ),
            child: ClipOval(
              child: localFile != null
                  ? Image.file(
                      localFile,
                      fit: BoxFit.cover,
                      color: color,
                      colorBlendMode: blendMode,
                      errorBuilder: (_, _, _) => ColoredBox(color: placeholder),
                    )
                  : thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      cacheManager: PrismImageCache.instance,
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 120,
                      color: color,
                      colorBlendMode: blendMode,
                      placeholder: (_, u) => ColoredBox(color: placeholder),
                      errorWidget: (_, u, e) => ColoredBox(color: placeholder),
                    )
                  : ColoredBox(color: placeholder),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataRow(BuildContext context, FeedItemEntity entity, WallpaperDetailLoaded state) {
    return entity.when(
      prism: (_, wallpaper) => _buildPrismMetadata(context, wallpaper, state),
      wallhaven: (_, wallpaper) => _buildWallhavenMetadata(context, wallpaper),
      pexels: (_, wallpaper) => _buildPexelsMetadata(context, wallpaper),
    );
  }

  Widget _metadataShell({required List<Widget> left, required List<Widget> right}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_sheetHPad, 4, _sheetHPad, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 5,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: left),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 4,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: right),
          ),
        ],
      ),
    );
  }

  Widget _buildPrismMetadata(BuildContext context, PrismWallpaper wallpaper, WallpaperDetailLoaded state) {
    final secondary = Theme.of(context).colorScheme.secondary;
    final TextStyle dimmedHeadline = Theme.of(
      context,
    ).textTheme.headlineSmall!.copyWith(color: secondary.withValues(alpha: _secondaryAlpha));
    final collections = wallpaper.collections;
    final category = wallpaper.core.category;
    final resolution = wallpaper.core.resolution;
    final sizeBytes = wallpaper.core.sizeBytes;
    final createdAt = wallpaper.core.createdAt;
    return _metadataShell(
      left: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: LayoutBuilder(
            builder: (context, constraints) => Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: Text(
                    wallpaperTitle(context.l10n, state.entity),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall!.copyWith(color: secondary),
                  ),
                ),
                if (state.setCount case final int sets when sets >= _minSetCountShown) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 6),
                      Flexible(child: Text(context.l10n.wallpaperSetCount(sets), style: dimmedHeadline)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: PrismFavouriteCount(
            id: wallpaper.id,
            showFavourites: false,
            views: switch (int.tryParse(state.views ?? '')) {
              final int count when count >= 0 => count,
              _ => null,
            },
          ),
        ),
        if (collections != null && collections.isNotEmpty) ...[
          _buildInfoRow(context, JamIcons.folder, collections.take(2).join(', ')),
          const SizedBox(height: 4),
        ],
        if (category != null) ...[_buildInfoRow(context, JamIcons.unordered_list, category), const SizedBox(height: 4)],
        if (resolution != null) ...[_buildInfoRow(context, JamIcons.set_square, resolution), const SizedBox(height: 4)],
        if (sizeBytes != null) _buildInfoRow(context, JamIcons.save, formatMegabytes(sizeBytes, context.l10n)),
      ],
      right: [
        _buildPrismAuthorRow(context, wallpaper),
        if (createdAt != null) ...[
          const SizedBox(height: 4),
          _buildInfoRow(
            context,
            JamIcons.calendar,
            _formatDate(createdAt, context.l10n, Localizations.localeOf(context)),
            reversed: true,
          ),
        ],
        const SizedBox(height: 4),
        _buildInfoRow(context, JamIcons.database, 'Prism', reversed: true),
      ],
    );
  }

  Widget _buildWallhavenMetadata(BuildContext context, WallhavenWallpaper wallpaper) {
    final views = wallpaper.views;
    final sizeBytes = wallpaper.sizeBytes ?? wallpaper.core.sizeBytes;
    final author = wallpaper.core.authorName;
    final category = wallpaper.core.category;
    final resolution = wallpaper.core.resolution;
    return _metadataShell(
      left: [
        _buildInfoTitle(context, wallpaper.id.toUpperCase()),
        WallpaperStatsRow(views: views),
        if (sizeBytes != null) ...[
          const SizedBox(height: 4),
          _buildInfoRow(context, JamIcons.save, formatMegabytes(sizeBytes, context.l10n)),
        ],
      ],
      right: [
        if (author != null && author.isNotEmpty) ...[
          _buildAuthorLink(context, author, Uri.https('wallhaven.cc', '/user/${Uri.encodeComponent(author)}')),
          const SizedBox(height: 4),
        ],
        if (category != null) ...[
          _buildInfoRow(context, JamIcons.unordered_list, category, reversed: true),
          const SizedBox(height: 4),
        ],
        if (resolution != null) ...[
          _buildInfoRow(context, JamIcons.set_square, resolution, reversed: true),
          const SizedBox(height: 4),
        ],
        _buildInfoRow(context, JamIcons.database, context.l10n.wallpaperProviderWallhaven, reversed: true),
      ],
    );
  }

  Widget _buildPexelsMetadata(BuildContext context, PexelsWallpaper wallpaper) {
    final width = wallpaper.core.width;
    final height = wallpaper.core.height;
    final photographer = wallpaper.photographer;
    final photographerUrl = wallpaper.photographerUrl?.trim() ?? '';
    return _metadataShell(
      left: [
        _buildInfoTitle(context, wallpaper.id),
        if (width != null && height != null) ...[
          const SizedBox(height: 4),
          _buildInfoRow(context, JamIcons.set_square, "${width}x$height"),
        ],
      ],
      right: [
        if (photographer != null && photographer.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildAuthorLink(
              context,
              photographer,
              photographerUrl.isEmpty ? null : Uri.tryParse(photographerUrl),
            ),
          ),
          const SizedBox(height: 4),
        ],
        _buildInfoRow(context, JamIcons.database, 'Pexels', reversed: true),
      ],
    );
  }

  Widget _buildPrismAuthorRow(BuildContext context, PrismWallpaper wallpaper) {
    final String nameTrimmed = wallpaper.core.authorName?.trim() ?? '';
    final String photoTrimmed = wallpaper.core.authorPhoto?.trim() ?? '';
    final String creatorUid = wallpaper.core.authorUid?.trim() ?? '';
    final bool hasName = nameTrimmed.isNotEmpty;
    final bool hasPhoto = photoTrimmed.isNotEmpty;

    final String? displayLabel = hasName ? nameTrimmed : null;

    if (displayLabel == null && !hasPhoto) {
      return const SizedBox.shrink();
    }

    final String initialChar = displayLabel != null && displayLabel.isNotEmpty
        ? displayLabel.characters.first.toUpperCase()
        : '?';

    final Color secondary = Theme.of(context).colorScheme.secondary;
    final Widget avatar = CircleAvatar(
      radius: 13,
      backgroundColor: secondary.withValues(alpha: 0.15),
      child: hasPhoto
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: photoTrimmed,
                width: 26,
                height: 26,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Text(
                  initialChar,
                  style: TextStyle(color: secondary, fontWeight: FontWeight.w600, fontSize: 11),
                ),
              ),
            )
          : Text(
              initialChar,
              style: TextStyle(color: secondary, fontWeight: FontWeight.w600, fontSize: 11),
            ),
    );

    final String profileIdentifier = creatorUid;
    Widget tappable(Widget child) => profileIdentifier.isEmpty
        ? child
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                PrismHaptics.tap();
                context.router.push(ProfileRoute(profileIdentifier: profileIdentifier));
              },
              borderRadius: BorderRadius.circular(8),
              child: child,
            ),
          );

    if (displayLabel == null) {
      return tappable(Padding(padding: const EdgeInsets.only(bottom: 4), child: avatar));
    }

    return tappable(
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                displayLabel,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: secondary),
              ),
            ),
            const SizedBox(width: 10),
            avatar,
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorLink(BuildContext context, String text, Uri? uri) {
    final style = Theme.of(context).textTheme.headlineSmall!.copyWith(color: Theme.of(context).colorScheme.secondary);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite ? min(constraints.maxWidth, 200.0) : 200.0;
        final label = Text(text, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: style);
        return SizedBox(
          width: maxW,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: uri == null
                ? label
                : InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                      if (!ok && context.mounted) {
                        toasts.error(context.l10n.wallpaperProfileOpenError);
                      }
                    },
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: label),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: Theme.of(context).colorScheme.secondary),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text, {bool reversed = false}) {
    final iconWidget = Icon(
      icon,
      size: 20,
      color: Theme.of(context).colorScheme.secondary.withValues(alpha: _secondaryAlpha),
    );
    final textWidget = Flexible(
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
      ),
    );
    const spacer = SizedBox(width: 10);
    if (reversed) {
      return Row(mainAxisSize: MainAxisSize.min, children: [textWidget, spacer, iconWidget]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [iconWidget, spacer, textWidget]);
  }

  /// Stored wall colours: Prism palette ids or Wallhaven hex values such as "#663399".
  List<Color> _sharePalette(FeedItemEntity entity) {
    final List<String> stored = entity.when(
      prism: (_, wall) => wall.colors ?? const <String>[],
      wallhaven: (_, wall) => wall.colors ?? const <String>[],
      pexels: (_, _) => const <String>[],
    );
    return <Color>[
      for (final String value in stored)
        if (paletteColorById(value)?.color ?? _hexColor(value) case final Color color) color,
    ];
  }

  static Color? _hexColor(String value) {
    final String hex = value.replaceFirst('#', '');
    final int? rgb = hex.length == 6 ? int.tryParse(hex, radix: 16) : null;
    return rgb == null ? null : Color(0xFF000000 | rgb);
  }

  static String _tintKey(Color tint) => 'tint-${tint.rgbHex}';

  static final RegExp _savedTintKey = RegExp(r'_(tint-[0-9a-f]{6})(?: \(\d+\))?$');

  /// The colour key in the name of a tinted wallpaper saved from this screen, so a reopened file is that variation.
  static String? _savedTintKeyOf(String path) => _savedTintKey.firstMatch(downloadBaseName(path))?.group(1);

  Widget _buildActionBar(BuildContext context, WallpaperDetailLoaded state) {
    final entity = state.entity;
    final url = entity.fullUrl;
    final String previewTitle = wallpaperPreviewTitle(context.l10n, entity);
    final File? localFile = widget.localFile;
    final DownloadedWallRef? localIdentity = localFile != null && getIt.isRegistered<DownloadedWallIndex>()
        ? getIt<DownloadedWallIndex>().resolve(localFile.path)
        : null;
    final WallpaperSource indexSource =
        localFile == null || (localIdentity?.id == entity.id && localIdentity?.source == entity.source)
        ? entity.source
        : WallpaperSource.downloaded;
    final String source = localFile?.path ?? url;
    final Future<String> Function()? localSource = localFile == null ? null : () async => localFile.path;
    final Color? tint = state.tint;
    final double deviceLongSidePx = _screenPixels(context).longestSide;
    Future<String> Function()? prepareSource;
    Future<String> Function(String)? prepareAuthorized;
    DownloadVariant? variant;
    if (tint != null) {
      prepareAuthorized = (authorized) => renderTintedWallpaper(
        source: authorized,
        tint: tint,
        deviceLongSidePx: deviceLongSidePx,
        wallpaperId: entity.id,
        wallpaperSource: entity.source,
      );
      prepareSource = () => prepareAuthorized!(source);
      variant = DownloadVariant(key: _tintKey(tint), prepare: prepareSource, prepareAuthorized: prepareAuthorized);
    } else if (localFile != null) {
      final String? savedKey = _savedTintKeyOf(localFile.path);
      if (savedKey != null) variant = DownloadVariant(key: savedKey, prepare: () async => localFile.path);
    }
    // The round icon buttons press-scale themselves. Only the labelled pill needs the wrapper.
    Widget downloadButton({String? label}) {
      final Widget button = DownloadButton(
        label: label,
        link: source,
        variant: variant,
        isPremiumContent: isPremiumFeedItem(entity, app_state.premiumCollections),
        contentId: entity.id,
        wallpaperSource: localFile == null ? entity.source : WallpaperSource.downloaded,
        indexSource: indexSource,
        savedIdentity: localFile != null && tint == null && getIt.isRegistered<DownloadedWallIndex>()
            ? getIt<DownloadedWallIndex>().acquiredIdentityForLocalFile(
                filePath: localFile.path,
                id: entity.id,
                source: indexSource,
              )
            : null,
        depthTier: depthTierOf(entity),
        spatialTier: spatialOf(entity)?.tier,
        sourceContext: _getSourceContext(state),
        requestId: widget.requestId,
        onDownloaded: () {
          _recordTaste(TasteAction.download, entity);
        },
      );
      return label == null ? button : PressScale(child: button);
    }

    Widget setButton({required String label}) => PressScale(
      child: SetWallpaperButton(
        key: _setButtonKey,
        label: label,
        url: source,
        wallpaperId: entity.id,
        wallpaperSource: localFile == null ? entity.source : WallpaperSource.downloaded,
        prepareSource: prepareSource,
        prepareAuthorized: prepareAuthorized,
        thumbnailUrl: entity.thumbnailUrl,
        promptNotificationPermissionOnSuccess: true,
        entryPoint: 'wallpaper_detail',
        requestId: widget.requestId,
        previewTint: tint,
        notes: wallpaperResolutionNotes(context.l10n, entity.wallpaperCore, _screenPixels(context)),
        onMatchAccent: _matchAccentAction(context, state),
        onSet: () => _onWallpaperSet(entity),
      ),
    );
    _saveAction = hideSetWallpaperUi ? (label) => downloadButton(label: label) : null;
    final primary = hideSetWallpaperUi
        ? WallpaperBarAction(
            label: context.l10n.wallpaperSaveToPhotos,
            child: downloadButton(label: context.l10n.wallpaperSave),
          )
        : WallpaperBarAction(
            label: context.l10n.wallpaperSetAsWallpaper,
            child: setButton(label: context.l10n.wallpaperSet),
          );
    final TextStyle countStyle = PrismTextStyles.rowTitle(context).copyWith(fontWeight: FontWeight.w500);
    final NumberFormat compactCount = NumberFormat.compact(locale: context.l10n.localeName)..maximumFractionDigits = 1;
    // Shown compact like the stats rows ("12.3K") and read as "12,345 favourites". An invalid total stays hidden.
    Widget favouriteCount(int count) => count < 0
        ? const SizedBox.shrink()
        : Semantics(
            container: true,
            label: context.l10n.wallpaperFavouriteCount(count),
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: PrismSpace.xxs),
                child: Text(compactCount.format(count), style: countStyle),
              ),
            ),
          );
    return WallpaperActionBar(
      primary: primary,
      secondary: [
        if (!hideSetWallpaperUi) WallpaperBarAction(label: context.l10n.wallpaperDownload, child: downloadButton()),
      ],
      actions: [
        WallpaperBarAction(
          label: context.l10n.wallpaperFavourite,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PressScale(
                child: FavouriteWallpaperButton(
                  wall: FavouriteWallEntity.fromFeedItem(entity),
                  trash: false,
                  onFavourited: () => _recordTaste(TasteAction.favourite, entity),
                ),
              ),
              // The published total sits beside the heart.
              ...entity.when(
                prism: (_, wall) => [PrismFavouriteCount(id: wall.id, builder: (_, count) => favouriteCount(count))],
                wallhaven: (_, wall) => [
                  if (wall.favorites ?? wall.core.favourites case final int count) favouriteCount(count),
                ],
                pexels: (_, _) => const <Widget>[],
              ),
            ],
          ),
        ),
        WallpaperBarAction(
          label: context.l10n.wallpaperShare,
          child: ShareButton(
            id: entity.id,
            source: entity.source,
            url: entity.fullUrl,
            thumbUrl: entity.thumbnailUrl,
            creator: entity.wallpaperCore.authorName,
            palette: _sharePalette(entity),
            createLink: (id, source, url, thumbUrl) => createDynamicLink(
              id,
              source,
              url,
              thumbUrl,
              l10n: context.l10n,
              title: previewTitle,
              core: entity.wallpaperCore,
            ),
          ),
        ),
        WallpaperBarAction(
          label: context.l10n.wallpaperEdit,
          child: EditButton(
            url: source,
            wallpaperId: entity.id,
            wallpaperSource: localFile == null ? entity.source : WallpaperSource.downloaded,
            prepareSource: prepareSource ?? localSource,
            prepareAuthorized: prepareAuthorized,
          ),
        ),
      ],
    );
  }

  /// Opens Make it live. The first palette colour seeds its gradients, so they follow this wallpaper.
  Future<void> _openMakeItLive(BuildContext context, WallpaperDetailLoaded state) async {
    final entity = state.entity;
    String? imageUrl;
    try {
      imageUrl = await resolveOriginalWithConsent(
        context,
        url: widget.localFile?.path ?? entity.fullUrl,
        wallpaperId: entity.id,
        wallpaperSource: widget.localFile == null ? entity.source : WallpaperSource.downloaded,
        action: OriginalAccessAction.live,
        label: context.l10n.wallpaperMakeItLive,
      );
    } catch (_) {
      if (context.mounted) toasts.error(context.l10n.coreCouldNotLoadWallpaperForEditing);
      return;
    }
    if (context.mounted && imageUrl != null) {
      await context.router.push(
        LiveWallpaperRoute(
          imageUrl: imageUrl,
          accentSeed: state.colors?.firstOrNull,
          depthMapUrl: spatialOf(entity)?.mapUrl,
        ),
      );
    }
  }

  Size _screenPixels(BuildContext context) {
    final Size px = MediaQuery.sizeOf(context) * MediaQuery.devicePixelRatioOf(context);
    return Size(px.shortestSide, px.longestSide);
  }

  void _onWallpaperSet(FeedItemEntity entity) {
    _recordTaste(TasteAction.set, entity);
    if (shouldRecordWallpaperSetStats(entity)) {
      unawaited(getIt<RecordWallpaperActionUseCase>()(entity.id, WallpaperAction.set));
    }
  }

  /// "Match accent" on the success snackbar: sets Prism's accent to the first palette colour of this wallpaper.
  VoidCallback? _matchAccentAction(BuildContext context, WallpaperDetailLoaded state) {
    final Color? color = state.colors?.firstOrNull;
    if (color == null) return null;
    final ThemeBloc? themeBloc = _themeBloc(context);
    if (themeBloc == null || !_themeTakesAccent(context)) return null;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return () {
      themeBloc.add(
        dark
            ? ThemeEvent.darkAccentChanged(accentColorValue: color.toARGB32())
            : ThemeEvent.lightAccentChanged(accentColorValue: color.toARGB32()),
      );
      unawaited(analytics.track(const AccentMatchedFromWallEvent()));
    };
  }

  /// False while the active theme brings its own accent (Material You), so accent actions do nothing there.
  bool _themeTakesAccent(BuildContext context) =>
      _themeBloc(context)?.state.themeOption(Theme.of(context).brightness).usesAccent ?? true;

  ThemeBloc? _themeBloc(BuildContext context) {
    try {
      return context.read<ThemeBloc>();
    } catch (_) {
      return null;
    }
  }

  List<Widget> _buildPanelExtras(BuildContext context, WallpaperDetailLoaded state) {
    final entity = state.entity;
    final theme = Theme.of(context);
    final tags = wallpaperTags(entity);
    final notes = wallpaperResolutionNotes(context.l10n, entity.wallpaperCore, _screenPixels(context));
    final bool canBlock = canBlockWallCreator(entity);
    final WallDepthTier? depthTier = depthTierOf(entity);
    final WallSpatial? spatial = spatialOf(entity);
    final String? reportWallDocId = BundledWallpapers.isStarter(entity)
        ? null
        : switch (entity) {
            PrismFeedItem(:final wallpaper) => wallpaper.firestoreDocumentId,
            _ => null,
          };
    const gap = SizedBox(height: 12);
    Widget padded(Widget child) =>
        Padding(padding: const EdgeInsets.fromLTRB(_sheetHPad, 0, _sheetHPad, 12), child: child);
    return [
      for (final note in notes)
        padded(
          Row(
            children: [
              Icon(JamIcons.alert, size: 18, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(note, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.secondary)),
              ),
            ],
          ),
        ),
      if (tags.isNotEmpty) padded(WallpaperTagChips(tags: tags, onTagTap: (tag) => openTagSearch(context, tag))),
      if (depthTier != null && showsDepthEffect(depthTier)) padded(DepthEffectRow(tier: depthTier)),
      if (spatial != null && showsSpatialScene(spatial.tier))
        padded(SpatialSceneRow(tier: spatial.tier, wallId: entity.id)),
      if (!hideSetWallpaperUi && (entity.fullUrl.trim().isNotEmpty || entity.source == WallpaperSource.prism))
        padded(
          Align(
            alignment: Alignment.centerLeft,
            child: MakeItLiveButton(onPressed: () => _openMakeItLive(context, state)),
          ),
        ),
      if (entity case PrismFeedItem(:final wallpaper) when canBoostWall(wallpaper))
        padded(PrismGroup(children: <Widget>[BoostWallRow(wall: wallpaper)])),
      if (reportWallDocId != null && reportWallDocId.isNotEmpty)
        padded(
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              children: [
                TextButton.icon(
                  onPressed: () => showContentReportSheet(
                    context,
                    contentType: 'wall',
                    targetFirestoreDocId: reportWallDocId,
                    subtitle: entity.id,
                    onBlockCreator: canBlock ? () => unawaited(blockWallCreator(context, entity)) : null,
                  ),
                  icon: Icon(JamIcons.flag, size: 20, color: theme.colorScheme.secondary),
                  label: Text(context.l10n.wallpaperReport, style: TextStyle(color: theme.colorScheme.secondary)),
                ),
                if (canBlock)
                  TextButton.icon(
                    onPressed: () => unawaited(blockWallCreator(context, entity)),
                    icon: Icon(JamIcons.user_remove, size: 20, color: theme.colorScheme.secondary),
                    label: Text(
                      context.l10n.wallpaperBlockCreator,
                      style: TextStyle(color: theme.colorScheme.secondary),
                    ),
                  ),
              ],
            ),
          ),
        ),
      gap,
    ];
  }

  Widget _buildImageBody(
    BuildContext context,
    bool paletteLoading,
    WallpaperDetailLoaded state, {
    bool canonicalLoading = false,
  }) {
    final _FeedStep? feed = _FeedStep.maybeOf(context);
    final entity = state.entity;
    final Widget image = _buildWallpaperImage(context, state, paletteLoading);
    final Widget card = Stack(
      fit: StackFit.expand,
      children: [
        // A hold that resets the original gives the card a short press: it shrinks a little and settles. A tap hides
        // the controls instead, and the card growing to the screen is its feedback.
        ShakeOnce(
          controller: _shake,
          distance: 0.03,
          builder: (context, t, child) => Transform.scale(scale: 1 - t, child: child),
          child: WallpaperQuickActionRegion(
            item: entity,
            onResetOriginal: () => _handleAccentLongPress(context, state),
            preview: ClipRRect(borderRadius: const BorderRadius.all(Radius.circular(_cardRadius)), child: image),
            readIsPinned: () => _favouritePinState(entity),
            onTogglePin: () => unawaited(
              toggleFavouritePin(
                context,
                entity.id,
                pin: !isFavouritePinned(context, entity.id),
                surface: FavouritePinSurfaceValue.detail,
              ),
            ),
            child: _cardSemantics(
              feed,
              child: _FeedDragSurface(
                feed: feed,
                zoomable: _Immersion.maybeOf(context)?.on ?? false,
                onTap: _toggleImmersive,
                child: _withHero(image),
              ),
            ),
          ),
        ),
        if (!canonicalLoading &&
            !hideSetWallpaperUi &&
            (entity.fullUrl.trim().isNotEmpty || entity.source == WallpaperSource.prism))
          PositionedDirectional(
            start: _chromePad,
            bottom: _chromePad,
            child: _hiddenWhenImmersive(MakeItLiveChip(onPressed: () => _openMakeItLive(context, state))),
          ),
        PositionedDirectional(
          start: _chromePad,
          end: _chromePad,
          bottom: _chromePad + _chromeSize + PrismSpace.xs,
          child: IgnorePointer(
            child: Center(
              child: AnimatedOpacity(
                opacity: _hintVisible ? 1 : 0,
                duration: context.motion(PrismDurations.base),
                curve: PrismCurves.enter,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.55),
                    borderRadius: const BorderRadius.all(Radius.circular(PrismRadius.lg)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm, vertical: PrismSpace.xs),
                    child: Text(
                      context.l10n.wallpaperImmersiveHint,
                      style: PrismTextStyles.body(context).copyWith(color: PrismColors.onPrimary),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    return ExcludeSemantics(excluding: canonicalLoading && feed != null, child: card);
  }

  /// Whether the favourite [entity] is pinned, or null when it is not a favourite, so the hold menu shows no Pin.
  bool? _favouritePinState(FeedItemEntity entity) {
    if (!getIt<FavoritesLocalDataSource>().isWallFavourite(app_state.prismUser.id, entity.id)) return null;
    return isFavouritePinned(context, entity.id);
  }

  /// The card's picture: thumbnail first, then the best image the user may see. The spinner lives outside this subtree.
  /// It decodes for the whole screen, so immersive mode shows the same picture with no new decode.
  Widget _buildWallpaperImage(BuildContext context, WallpaperDetailLoaded state, bool paletteLoading) {
    final FeedItemEntity entity = state.entity;
    final File? localFile = widget.localFile;
    final Widget image = localFile != null
        ? ProgressiveWallpaperImage(
            display: WallpaperDisplaySource(
              thumbnail: '',
              full: localFile.path,
              pixelSize: wallpaperPixelSize(entity.wallpaperCore),
            ),
            errorBuilder: (_, _) =>
                GlintState(kind: GlintStateKind.error, title: context.l10n.wallpaperDownloadedWallpaperUnavailable),
          )
        : ProgressiveWallpaperImage(
            display: WallpaperDisplaySource.of(entity),
            errorBuilder: (_, _) =>
                Center(child: Icon(JamIcons.close_circle_f, color: _chromeColor(context, paletteLoading, state))),
          );
    return SizedBox.expand(
      child: _HueTint(tint: state.tint, duration: context.motion(const Duration(milliseconds: 220)), child: image),
    );
  }

  Future<File?> _offlinePreviewFor(FeedItemEntity entity) {
    if (entity.source == WallpaperSource.prism && !BundledWallpapers.isStarter(entity)) {
      return Future<File?>.value();
    }
    final String url = entity.fullUrl.trim();
    final String key = '${entity.source.wireValue}\u0000${entity.id}\u0000$url';
    if (_offlinePreviewKey != key) {
      _offlinePreviewKey = key;
      _offlinePreviewFuture = WallpaperService.resolveToLocalFile(
        url,
        allowNetwork: false,
        wallpaperId: entity.id,
        wallpaperSource: entity.source,
      ).then<File?>((File file) => file).catchError((Object _) => null);
    }
    return _offlinePreviewFuture ?? Future<File?>.value();
  }

  Color _chromeColor(BuildContext context, bool paletteLoading, WallpaperDetailLoaded state) {
    if (paletteLoading) return Theme.of(context).colorScheme.secondary;
    final accent = state.accent;
    return accent == null ? Colors.white : onColor(accent);
  }

  String _formatDate(DateTime date, AppLocalizations l10n, Locale locale) {
    final local = date.toLocal();
    final now = DateTime.now();
    if (now.difference(local).inDays < 7) {
      return localizedRelativeTime(l10n, local, locale: locale);
    }
    return (local.year == now.year ? DateFormat.MMMd(l10n.localeName) : DateFormat.yMMMd(l10n.localeName)).format(
      local,
    );
  }
}

/// The tint [t] of the way from [a] to [b]. Colours blend in HSL space and the hue takes the short way round. A blend in
/// RGB passes through grey between opposite hues, and a grey tint takes the colour out of the wallpaper. With no tint
/// at one end, the other fades in or out.
@visibleForTesting
Color? lerpHueTint(Color? a, Color? b, double t) {
  if (a == null || b == null) return Color.lerp(a, b, t);
  final HSLColor from = HSLColor.fromColor(a);
  final HSLColor to = HSLColor.fromColor(b);
  final double sweep = ((to.hue - from.hue + 540) % 360) - 180;
  return HSLColor.fromAHSL(
    lerpDouble(from.alpha, to.alpha, t)!,
    (from.hue + sweep * t) % 360,
    lerpDouble(from.saturation, to.saturation, t)!,
    lerpDouble(from.lightness, to.lightness, t)!,
  ).toColor();
}

class _HueTintTween extends Tween<Color?> {
  _HueTintTween({super.begin, super.end});

  @override
  Color? lerp(double t) => lerpHueTint(begin, end, t);
}

/// Shows [child] with the hue of [tint]. A new tint slides over from the one on screen, and no tint fades the hue out.
class _HueTint extends StatefulWidget {
  const _HueTint({required this.tint, required this.duration, required this.child});

  final Color? tint;
  final Duration duration;
  final Widget child;

  @override
  State<_HueTint> createState() => _HueTintState();
}

class _HueTintState extends State<_HueTint> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration)..value = 1;
  late _HueTintTween _tween = _HueTintTween(begin: widget.tint, end: widget.tint);

  Color? get _shown => _tween.transform(Curves.easeOutCubic.transform(_controller.value));

  @override
  void didUpdateWidget(_HueTint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tint == widget.tint) return;
    _tween = _HueTintTween(begin: _shown, end: widget.tint);
    _controller
      ..duration = widget.duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: RepaintBoundary(child: widget.child),
      builder: (BuildContext context, Widget? child) {
        final Color? tint = _shown;
        return tint == null ? child! : ColorFiltered(colorFilter: ColorFilter.mode(tint, BlendMode.hue), child: child);
      },
    );
  }
}
