import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/edge_to_edge_overlay_style.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/prism_loader.dart';
import 'package:Prism/features/wrapped/biz/bloc/wrapped_bloc.j.dart';
import 'package:Prism/features/wrapped/domain/wrapped.dart';
import 'package:Prism/features/wrapped/views/widgets/wrapped_card_view.dart';
import 'package:Prism/features/wrapped/views/wrapped_copy.dart';
import 'package:Prism/features/wrapped/views/wrapped_share.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The analytics source for a deep-link or notification intent source.
WrappedSourceValue wrappedSourceFrom(String source) => switch (source) {
  'push' => WrappedSourceValue.push,
  'inbox' => WrappedSourceValue.inbox,
  'home' => WrappedSourceValue.home,
  _ => WrappedSourceValue.deepLink,
};

/// How long a card stays before the story moves on by itself.
const Duration wrappedCardDuration = Duration(seconds: 6);

/// Prism Wrapped: full-screen story cards. Tap the right two thirds for the next card, the left third for the previous
/// one, hold to pause and swipe down to close. With reduced motion or a screen reader the story never moves by itself.
@RoutePage()
class PrismWrappedPage extends StatefulWidget {
  const PrismWrappedPage({super.key, this.source = WrappedSourceValue.deepLink});

  final WrappedSourceValue source;

  @override
  State<PrismWrappedPage> createState() => _PrismWrappedPageState();
}

class _PrismWrappedPageState extends State<PrismWrappedPage> {
  final WrappedBloc _bloc = getIt<WrappedBloc>();
  final String _uid = app_state.prismUser.loggedIn ? app_state.prismUser.id.trim() : '';
  StreamSubscription<String>? _userChanges;
  late String _activeUid;
  bool _notEligibleHandled = false;

  @override
  void initState() {
    super.initState();
    _activeUid = _uid;
    _bloc.add(WrappedEvent.load(_uid));
    _userChanges = _bloc.userChanges.listen((uid) {
      if (uid == _activeUid) return;
      _activeUid = uid;
      if (mounted) {
        setState(() {});
        if (ModalRoute.of(context)?.isCurrent ?? true) unawaited(Navigator.of(context).maybePop());
      }
    });
    if (_uid.isEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _leave());
    if (_bloc.state case WrappedNotEligible(uid: final uid) when uid == _uid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _leave());
    }
  }

  @override
  void dispose() {
    unawaited(_userChanges?.cancel());
    super.dispose();
  }

  void _leave() {
    if (!mounted || _notEligibleHandled) return;
    _notEligibleHandled = true;
    analytics.track(WrappedNotEligibleEvent(source: widget.source));
    toasts.info(context.l10n.wrappedNotEligible);
    unawaited(Navigator.of(context).maybePop());
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: edgeToEdgeOverlayStyle(statusBarIconBrightness: Brightness.light),
      child: Scaffold(
        backgroundColor: WrappedCardStyle.backdrop,
        body: BlocConsumer<WrappedBloc, WrappedState>(
          bloc: _bloc,
          listenWhen: (_, state) => state is WrappedNotEligible && state.uid == _uid,
          listener: (_, _) => _leave(),
          builder: (context, state) => _activeUid != _uid
              ? const SizedBox.shrink()
              : state is WrappedNotEligible && state.uid == _uid
              ? const SizedBox.shrink()
              : switch (state) {
                  WrappedReady(:final uid, :final year) when uid == _uid => WrappedStory(
                    year: year,
                    source: widget.source,
                    ownerUserId: uid,
                    ownerChanges: _bloc.userChanges,
                  ),
                  WrappedFailed(:final uid) when uid == _uid => _Failed(
                    onRetry: () => _bloc.add(WrappedEvent.load(_uid)),
                  ),
                  _ => Center(
                    child: Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(onSurface: WrappedCardStyle.text)),
                      child: const PrismLoader(),
                    ),
                  ),
                },
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Stack(
      children: <Widget>[
        PositionedDirectional(
          top: PrismSpace.sm,
          end: PrismSpace.sm,
          child: PrismIconButton(
            icon: Icons.close_rounded,
            tooltip: context.l10n.wrappedClose,
            onImage: true,
            onPressed: () {
              PrismHaptics.tap();
              unawaited(Navigator.of(context).maybePop());
            },
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(PrismSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  context.l10n.wrappedLoadFailed,
                  textAlign: TextAlign.center,
                  style: PrismTextStyles.cardTitle(context).copyWith(color: WrappedCardStyle.text),
                ),
                const SizedBox(height: PrismSpace.lg),
                PrismButton(label: context.l10n.coreRetry, onPressed: onRetry),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// The story itself, for a loaded [year].
class WrappedStory extends StatefulWidget {
  const WrappedStory({
    required this.year,
    required this.source,
    required this.ownerUserId,
    this.ownerChanges,
    this.share = shareWrappedCard,
    super.key,
  });

  final WrappedYear year;
  final WrappedSourceValue source;
  final String ownerUserId;
  final Stream<String>? ownerChanges;
  final Future<void> Function(
    BuildContext, {
    required WrappedCard card,
    required WrappedCopy copy,
    required Color accent,
    required String ownerUserId,
    Stream<String>? ownerChanges,
  })
  share;

  @override
  State<WrappedStory> createState() => _WrappedStoryState();
}

class _WrappedStoryState extends State<WrappedStory> with TickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(vsync: this, duration: wrappedCardDuration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _go(_index + 1);
    });
  late final AnimationController _drag = AnimationController(vsync: this, upperBound: double.infinity);
  final Set<String> _seen = <String>{};
  int _index = 0;
  bool _held = false;
  bool _paused = false;
  bool _still = false;
  bool _finished = false;
  bool _sharing = false;

  List<WrappedCard> get _cards => widget.year.cards;
  WrappedCard get _card => _cards[_index];
  bool get _onSummary => _card.kind == WrappedCardKind.summary;
  Color get _accent => wrappedAccent(widget.year.accents.firstOrNull?.color);

  @override
  void initState() {
    super.initState();
    analytics.track(WrappedOpenedEvent(source: widget.source));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool still = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    final bool first = _seen.isEmpty;
    if (still != _still || first) {
      _still = still;
      _enter(_index);
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _drag.dispose();
    super.dispose();
  }

  void _go(int index) {
    if (index < 0 || index >= _cards.length || index == _index) {
      if (index < 0) _enter(0);
      return;
    }
    setState(() => _index = index);
    _enter(index);
  }

  void _enter(int index) {
    final WrappedCard card = _cards[index];
    if (_seen.add(card.id)) analytics.track(WrappedCardViewedEvent(cardId: card.id));
    if (card.kind == WrappedCardKind.summary && !_finished) {
      _finished = true;
      analytics.track(const WrappedFinishedEvent());
    }
    if (index + 1 < _cards.length) {
      for (final String url in wrappedCardImages(_cards[index + 1])) {
        if (url.isNotEmpty) {
          unawaited(
            precacheImage(
              CachedNetworkImageProvider(url, cacheManager: PrismImageCache.instance),
              context,
              onError: (_, _) {},
            ),
          );
        }
      }
    }
    _progress.value = 0;
    if (!_still && !_paused && card.kind != WrappedCardKind.summary) unawaited(_progress.forward());
  }

  void _hold(bool held) {
    if (_held == held) return;
    setState(() => _held = held);
    _syncProgress();
  }

  void _togglePause() {
    PrismHaptics.selection();
    setState(() => _paused = !_paused);
    _syncProgress();
  }

  void _syncProgress() {
    if (_held || _paused || _still || _onSummary) {
      _progress.stop();
    } else if (!_progress.isAnimating && _progress.value < 1) {
      unawaited(_progress.forward());
    }
  }

  /// A deliberate step by the user. The timer's own advance calls [_go] without a haptic.
  void _step(int index) {
    if (index < 0 || index >= _cards.length || index == _index) return _go(index);
    PrismHaptics.selection();
    _go(index);
  }

  void _tap(TapUpDetails details, double width) {
    final bool back = Directionality.of(context) == TextDirection.rtl
        ? details.localPosition.dx > width * 2 / 3
        : details.localPosition.dx < width / 3;
    _step(back ? _index - 1 : _index + 1);
  }

  void _dragEnd(DragEndDetails details) {
    if (_drag.value > 140 || (details.primaryVelocity ?? 0) > 900) {
      PrismHaptics.impact();
      unawaited(Navigator.of(context).maybePop());
      return;
    }
    _hold(false);
    if (_still) {
      _drag.value = 0;
    } else {
      unawaited(_drag.animateTo(0, duration: PrismDurations.base, curve: PrismCurves.enter));
    }
  }

  Future<void> _share(WrappedCopy copy) async {
    if (_sharing) return;
    _sharing = true;
    _hold(true);
    try {
      await widget.share(
        context,
        card: _card,
        copy: copy,
        accent: _accent,
        ownerUserId: widget.ownerUserId,
        ownerChanges: widget.ownerChanges,
      );
    } finally {
      _sharing = false;
      if (mounted) _hold(false);
    }
  }

  Widget _background(WrappedCard card) {
    final List<String> urls = wrappedCardImages(card);
    final int cache = (MediaQuery.sizeOf(context).height * MediaQuery.devicePixelRatioOf(context)).round();
    return WrappedCollage(
      tiles: <Widget>[
        for (final String url in urls) PrismImageTile(url: url, memCacheHeight: urls.length > 1 ? cache ~/ 2 : cache),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final WrappedCopy copy = wrappedCopy(l10n, Localizations.localeOf(context).toLanguageTag(), widget.year, _card);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final Duration fade = _still ? Duration.zero : context.motion(PrismDurations.base);
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: _drag,
        builder: (context, child) {
          final double offset = _drag.value;
          return ColoredBox(
            color: Colors.black.withValues(alpha: (1 - offset / 600).clamp(0.0, 1.0)),
            child: Transform.translate(
              offset: Offset(0, offset),
              child: Transform.scale(scale: (1 - offset / 2400).clamp(0.85, 1.0), child: child),
            ),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _tap(details, constraints.maxWidth),
              onLongPressStart: (_) => _hold(true),
              onLongPressEnd: (_) => _hold(false),
              onVerticalDragStart: (_) => _hold(true),
              onVerticalDragUpdate: (details) =>
                  _drag.value = (_drag.value + details.delta.dy).clamp(0.0, double.infinity),
              onVerticalDragEnd: _dragEnd,
              child: Semantics(
                container: true,
                liveRegion: true,
                label: '${l10n.wrappedCardPosition(_index + 1, _cards.length)}. ${copy.semantics}',
                child: ExcludeSemantics(
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.6,
                    child: AnimatedSwitcher(
                      duration: fade,
                      switchInCurve: PrismCurves.enter,
                      switchOutCurve: PrismCurves.exit,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 1.03, end: 1).animate(animation),
                          child: child,
                        ),
                      ),
                      child: WrappedCardView(
                        key: ValueKey<int>(_index),
                        copy: copy,
                        accent: _accent,
                        background: _background(_card),
                        topInset: safe.top + 64,
                        bottomInset: safe.bottom + (_onSummary ? 88 : 8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: safe.top + PrismSpace.xs,
              left: PrismSpace.sm,
              right: PrismSpace.sm,
              child: AnimatedOpacity(
                opacity: _held ? 0 : 1,
                duration: _still ? Duration.zero : context.motion(PrismDurations.fast),
                child: _Chrome(
                  count: _cards.length,
                  index: _index,
                  progress: _progress,
                  still: _still,
                  paused: _paused,
                  onPause: _still || _onSummary ? null : _togglePause,
                  onShare: () {
                    PrismHaptics.tap();
                    unawaited(_share(copy));
                  },
                  onPrevious: () => _step(_index - 1),
                  onNext: () => _step(_index + 1),
                ),
              ),
            ),
            if (_onSummary)
              Positioned(
                left: PrismSpace.lg,
                right: PrismSpace.lg,
                bottom: safe.bottom + PrismSpace.lg,
                child: PrismButton(
                  label: l10n.wrappedShare,
                  icon: Icons.ios_share_rounded,
                  expand: true,
                  onPressed: () => _share(copy),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chrome extends StatelessWidget {
  const _Chrome({
    required this.count,
    required this.index,
    required this.progress,
    required this.still,
    required this.paused,
    required this.onPause,
    required this.onShare,
    required this.onPrevious,
    required this.onNext,
  });

  final int count;
  final int index;
  final Animation<double> progress;
  final bool still;
  final bool paused;
  final VoidCallback? onPause;
  final VoidCallback onShare;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      children: <Widget>[
        ExcludeSemantics(
          child: Row(
            children: <Widget>[
              for (int i = 0; i < count; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == count - 1 ? 0 : 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 3,
                        // The last card (the summary) never times out, so its bar shows full.
                        child: i == index && !still && i < count - 1
                            ? AnimatedBuilder(
                                animation: progress,
                                builder: (_, _) => _Bar(fill: progress.value),
                              )
                            : _Bar(fill: i <= index ? 1 : 0),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: PrismSpace.xs),
        Row(
          children: <Widget>[
            if (still) ...<Widget>[
              PrismIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: l10n.wrappedPreviousCard,
                onImage: true,
                onPressed: index == 0 ? null : onPrevious,
              ),
              PrismIconButton(
                icon: Icons.chevron_right_rounded,
                tooltip: l10n.wrappedNextCard,
                onImage: true,
                onPressed: index == count - 1 ? null : onNext,
              ),
            ],
            const Spacer(),
            if (onPause != null)
              PrismIconButton(
                icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                tooltip: paused ? l10n.wrappedPlay : l10n.wrappedPause,
                onImage: true,
                onPressed: onPause,
              ),
            const SizedBox(width: PrismSpace.xs),
            PrismIconButton(
              icon: Icons.ios_share_rounded,
              tooltip: l10n.wrappedShareCard,
              onImage: true,
              onPressed: onShare,
            ),
            const SizedBox(width: PrismSpace.xs),
            PrismIconButton(
              icon: Icons.close_rounded,
              tooltip: l10n.wrappedClose,
              onImage: true,
              onPressed: () {
                PrismHaptics.tap();
                unawaited(Navigator.of(context).maybePop());
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fill});

  final double fill;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      const ColoredBox(color: Color(0x4DFFFFFF)),
      FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: fill.clamp(0.0, 1.0),
        child: const ColoredBox(color: WrappedCardStyle.text),
      ),
    ],
  );
}
