import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/wallpaper/wall_live.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/session/data/low_data_mode.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';

/// Where a live wall plays. It names the analytics surface and sets the rules below.
enum LiveSurface {
  /// A grid card. Cards share one player, so a long feed holds at most one video in memory. No controls.
  feed,

  /// The wall's own page. A pause button shows over the video.
  detail,

  /// The admin review queue. It plays even with data saver or reduced motion, because the admin must see it.
  review,
}

/// Plays the silent loop of a live wall over its [poster] while at least half of it is on screen, in the current
/// route, with the app in the foreground. Off screen it pauses, and a feed card frees its player.
///
/// With reduced motion or data saver, [LiveSurface.feed] shows only the poster and [LiveSurface.detail] shows the
/// poster with a play button.
class LiveWallVideo extends StatefulWidget {
  const LiveWallVideo({super.key, required this.live, required this.poster, required this.surface});

  final WallLive live;
  final Widget poster;
  final LiveSurface surface;

  /// Tests swap in a controller that needs no platform player. Local QA builds point it at the fixture server.
  /// The longest a card waits for its old player to close before another card may play.
  static const Duration releaseBudget = Duration(seconds: 2);

  static VideoPlayerController Function(Uri url) createController = (url) =>
      VideoPlayerController.networkUrl(url, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));

  @override
  State<LiveWallVideo> createState() => _LiveWallVideoState();
}

/// The one feed card that may hold a player.
final ValueNotifier<State<LiveWallVideo>?> _feedSlot = ValueNotifier<State<LiveWallVideo>?>(null);

class _LiveWallVideoState extends State<LiveWallVideo> with WidgetsBindingObserver {
  final Set<ScrollPosition> _positions = <ScrollPosition>{};
  Animation<double>? _secondaryAnimation;
  VideoPlayerController? _controller;
  Future<bool>? _initializationFuture;
  Future<void>? _releaseFuture;
  bool _visible = false;
  bool _userPaused = false;
  bool _userStarted = false;
  bool _showVideo = false;
  bool _checkScheduled = false;
  bool _tracked = false;

  bool get _limited =>
      widget.surface != LiveSurface.review && (MediaQuery.disableAnimationsOf(context) || LowDataMode.enabled.value);

  bool get _shouldPlay => _visible && !_userPaused && (!_limited || _userStarted);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LowDataMode.enabled.addListener(_scheduleCheck);
    _feedSlot.addListener(_scheduleCheck);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _secondaryAnimation?.removeListener(_scheduleCheck);
    _secondaryAnimation = ModalRoute.of(context)?.secondaryAnimation;
    _secondaryAnimation?.addListener(_scheduleCheck);
    for (final ScrollPosition position in _positions) {
      position.removeListener(_scheduleCheck);
    }
    _positions.clear();
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        _positions.add((element.state as ScrollableState).position);
      }
      return true;
    });
    for (final ScrollPosition position in _positions) {
      position.addListener(_scheduleCheck);
    }
    _scheduleCheck();
  }

  @override
  void didUpdateWidget(LiveWallVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surface != widget.surface) _release();
    if (oldWidget.live.videoUrl != widget.live.videoUrl) {
      _release();
      _userPaused = false;
      _userStarted = false;
      _tracked = false;
    }
    _scheduleCheck();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleCheck();
      return;
    }
    if (_visible) setState(() => _visible = false);
    unawaited(_sync());
  }

  void _scheduleCheck() {
    if (_checkScheduled || !mounted) return;
    _checkScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (mounted) _check();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  bool _onScreen() {
    if (!TickerMode.valuesOf(context).enabled || !(ModalRoute.isCurrentOf(context) ?? true)) return false;
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

  void _check() {
    bool visible = _onScreen();
    if (widget.surface == LiveSurface.feed) {
      if (!visible || _limited) {
        visible = false;
      } else if (_feedSlot.value == null) {
        _feedSlot.value = this;
      }
      visible = visible && _feedSlot.value == this;
    }
    if (visible != _visible) setState(() => _visible = visible);
    unawaited(_sync());
  }

  Future<void> _sync() async {
    final Future<void>? release = _releaseFuture;
    if (release != null) {
      await release;
      if (mounted) _scheduleCheck();
      return;
    }
    if (!_shouldPlay) {
      if (widget.surface == LiveSurface.feed) {
        await _release();
      } else {
        await _controller?.pause();
      }
      return;
    }
    if (widget.surface == LiveSurface.feed && (_feedSlot.value != this || !_visible)) return;
    final VideoPlayerController controller = _controller ??= _create();
    if (!controller.value.isInitialized) return;
    await controller.play();
    if (!_tracked) {
      _tracked = true;
      unawaited(analytics.track(LiveWallPreviewPlayedEvent(surface: widget.surface.name)));
    }
  }

  VideoPlayerController _create() {
    final VideoPlayerController controller = LiveWallVideo.createController(Uri.parse(widget.live.videoUrl));
    controller.addListener(_onValue);
    final Future<bool> initialization = _initialize(controller);
    _initializationFuture = initialization;
    unawaited(
      initialization.then((initialized) {
        if (!mounted || !identical(_controller, controller)) return;
        if (!initialized) {
          unawaited(_release());
        } else {
          unawaited(_sync());
        }
      }),
    );
    return controller;
  }

  Future<bool> _initialize(VideoPlayerController controller) async {
    try {
      await controller.setVolume(0);
      await controller.setLooping(widget.live.loop);
      await controller.initialize();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _onValue() {
    final VideoPlayerValue? value = _controller?.value;
    final bool show = value != null && value.isInitialized && !value.hasError && value.isPlaying;
    if (show && !_showVideo && mounted) setState(() => _showVideo = true);
  }

  Future<void> _release({bool rebuild = true}) {
    final Future<void>? release = _releaseFuture;
    if (release != null) return release;
    final VideoPlayerController? controller = _controller;
    final Future<bool>? initialization = _initializationFuture;
    _controller = null;
    _initializationFuture = null;
    if (_showVideo && rebuild) setState(() => _showVideo = false);
    if (controller == null) {
      if (_feedSlot.value == this) _feedSlot.value = null;
      return Future<void>.value();
    }
    controller.removeListener(_onValue);
    late final Future<void> releaseFuture;
    releaseFuture = () async {
      try {
        // video_player 2.x never finishes dispose after a failed native create, so the feed slot waits a bounded time.
        final Completer<void> closed = Completer<void>();
        final Timer budget = Timer(LiveWallVideo.releaseBudget, closed.complete);
        unawaited(
          Future.wait<Object?>(<Future<Object?>>[
            controller.dispose(),
            ?initialization,
          ]).then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
            budget.cancel();
            if (!closed.isCompleted) closed.complete();
          }),
        );
        await closed.future;
      } finally {
        if (_feedSlot.value == this) _feedSlot.value = null;
        if (identical(_releaseFuture, releaseFuture)) _releaseFuture = null;
      }
    }();
    _releaseFuture = releaseFuture;
    return releaseFuture;
  }

  void _toggle() {
    final bool playing = _shouldPlay;
    setState(() {
      if (playing) {
        _userPaused = true;
      } else {
        _userPaused = false;
        _userStarted = true;
      }
    });
    unawaited(_sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LowDataMode.enabled.removeListener(_scheduleCheck);
    _feedSlot.removeListener(_scheduleCheck);
    _secondaryAnimation?.removeListener(_scheduleCheck);
    for (final ScrollPosition position in _positions) {
      position.removeListener(_scheduleCheck);
    }
    unawaited(_release(rebuild: false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? controller = _controller;
    final bool showControls = widget.surface != LiveSurface.feed;
    final bool playing = _shouldPlay;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.poster,
        if (controller != null)
          AnimatedOpacity(
            opacity: _showVideo ? 1 : 0,
            duration: PrismDurations.fast,
            curve: PrismCurves.enter,
            child: ExcludeSemantics(
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width <= 0 ? 1 : controller.value.size.width,
                    height: controller.value.size.height <= 0 ? 1 : controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
            ),
          ),
        if (showControls)
          PositionedDirectional(
            end: PrismSpace.sm,
            bottom: PrismSpace.sm,
            child: SafeArea(
              child: PrismIconButton(
                icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                tooltip: playing ? context.l10n.liveWallPause : context.l10n.liveWallPlay,
                onImage: true,
                onPressed: _toggle,
              ),
            ),
          ),
      ],
    );
  }
}
