import 'dart:async';

import 'package:Prism/core/cache/prism_full_image_cache.dart';
import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/taste_quiz/biz/bloc/taste_quiz_bloc.j.dart';
import 'package:Prism/features/taste_quiz/domain/entities/taste_quiz.dart';
import 'package:Prism/features/taste_quiz/views/widgets/tuning_feed_view.dart';
import 'package:Prism/features/wallpaper_detail/biz/wallpaper_detail_rules.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Runs one "This or that" quiz over [plan], then "Tuning your feed". [onFinished] gets false when the user skipped.
class TasteQuizView extends StatefulWidget {
  const TasteQuizView({
    super.key,
    required this.plan,
    required this.source,
    required this.interests,
    required this.onFinished,
    this.tasteSignals,
  });

  final TasteQuizPlan plan;
  final TasteQuizSource source;
  final List<String> interests;
  final ValueChanged<bool> onFinished;

  /// Defaults to the app-wide store.
  final TasteSignalStore? tasteSignals;

  @override
  State<TasteQuizView> createState() => _TasteQuizViewState();
}

class _TasteQuizViewState extends State<TasteQuizView> {
  late final TasteQuizBloc _bloc = TasteQuizBloc(
    plan: widget.plan,
    source: widget.source,
    interests: widget.interests,
    tasteSignals: widget.tasteSignals ?? getIt<TasteSignalStore>(),
  );

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider<TasteQuizBloc>.value(
    value: _bloc,
    child: TasteQuizBody(onFinished: widget.onFinished),
  );
}

/// The quiz screens for the [TasteQuizBloc] above it.
class TasteQuizBody extends StatelessWidget {
  const TasteQuizBody({super.key, required this.onFinished});

  final ValueChanged<bool> onFinished;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: BlocConsumer<TasteQuizBloc, TasteQuizState>(
        listenWhen: (prev, curr) => curr is TasteQuizFinished && prev is! TasteQuizFinished,
        listener: (context, state) => onFinished((state as TasteQuizFinished).completed),
        // The last screen stays up while the host moves on.
        buildWhen: (prev, curr) => curr is! TasteQuizFinished,
        builder: (context, state) => AnimatedSwitcher(
          duration: context.motion(PrismDurations.base),
          switchInCurve: PrismCurves.enter,
          switchOutCurve: PrismCurves.enter,
          child: switch (state) {
            final TasteQuizPlaying playing => _Rounds(key: const ValueKey<String>('rounds'), state: playing),
            final TasteQuizTuning tuning => TuningFeedView(
              key: const ValueKey<String>('tuning'),
              walls: tuning.walls,
              summary: tuning.summary,
              onDone: () => context.read<TasteQuizBloc>().add(const TasteQuizEvent.tuningShown()),
            ),
            TasteQuizFinished() => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }
}

/// One image size per tile, shared by the prefetch and the tile, so a prefetched image is the one that shows.
class _QuizImages {
  _QuizImages(BuildContext context, {required double tileWidth})
    : _cacheWidth = previewCacheWidth(tileWidth, MediaQuery.devicePixelRatioOf(context)),
      _projectId = Firebase.apps.isEmpty ? null : Firebase.app().options.projectId;

  final int _cacheWidth;
  final String? _projectId;

  ImageProvider thumbnail(QuizWall wall) => _sized(wall.item.thumbnailUrl, PrismImageCache.instance);

  /// The same full-quality preview the wallpaper screen shows.
  ImageProvider full(QuizWall wall) =>
      _sized(wallpaperDetailPreviewUrl(wall.item, projectId: _projectId), PrismFullImageCache.instance);

  ImageProvider _sized(String url, BaseCacheManager cache) =>
      ResizeImage(CachedNetworkImageProvider(url.trim(), cacheManager: cache), width: _cacheWidth);

  void prefetch(BuildContext context, QuizRound round) {
    for (final QuizWall wall in <QuizWall>[round.left, round.right]) {
      for (final ImageProvider image in <ImageProvider>[thumbnail(wall), full(wall)]) {
        unawaited(precacheImage(image, context, onError: (_, _) {}));
      }
    }
  }
}

class _Rounds extends StatefulWidget {
  const _Rounds({super.key, required this.state});

  final TasteQuizPlaying state;

  @override
  State<_Rounds> createState() => _RoundsState();
}

class _RoundsState extends State<_Rounds> {
  /// The side tapped in the round on screen. Further taps wait for the next round.
  QuizSide? _chosen;
  _QuizImages? _images;
  double? _tileWidth;

  int get _round => widget.state.picks.length;
  List<QuizRound> get _rounds => widget.state.plan.rounds;

  @override
  void didUpdateWidget(_Rounds old) {
    super.didUpdateWidget(old);
    if (old.state.picks.length != _round) {
      _chosen = null;
      _prefetchAhead();
    }
  }

  void _onLayout(double tileWidth) {
    if (_tileWidth == tileWidth) return;
    _tileWidth = tileWidth;
    _images = _QuizImages(context, tileWidth: tileWidth);
    _images!.prefetch(context, _rounds[_round]);
    _prefetchAhead();
  }

  /// The next pair loads while the user looks at this one, so a round never waits on the network.
  void _prefetchAhead() {
    final _QuizImages? images = _images;
    if (images != null && _round + 1 < _rounds.length) images.prefetch(context, _rounds[_round + 1]);
  }

  void _pick(QuizSide side) {
    if (_chosen != null) return;
    PrismHaptics.selection();
    setState(() => _chosen = side);
    final int round = _round;
    final TasteQuizBloc bloc = context.read<TasteQuizBloc>();
    Future<void>.delayed(context.motion(_pickHold), () => bloc.add(TasteQuizEvent.picked(round: round, side: side)));
  }

  /// How long the pick shows before the next pair comes in.
  static const Duration _pickHold = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final QuizRound round = _rounds[_round];
    final int total = _rounds.length;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(PrismSpace.page, PrismSpace.xs, PrismSpace.xs, 0),
            child: Row(
              children: <Widget>[
                Semantics(
                  label: context.l10n.tasteQuizProgressLabel(_round + 1, total),
                  liveRegion: true,
                  excludeSemantics: true,
                  child: Text(
                    context.l10n.tasteQuizProgress(_round + 1, total),
                    style: PrismTextStyles.rowTitle(context).copyWith(
                      color: cs.onSurfaceVariant,
                      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const Spacer(),
                PrismButton(
                  label: context.l10n.tasteQuizSkip,
                  variant: PrismButtonVariant.ghost,
                  size: PrismButtonSize.compact,
                  onPressed: () => context.read<TasteQuizBloc>().add(const TasteQuizEvent.skipped()),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
            child: _ProgressBar(done: _round, total: total),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.lg, PrismSpace.page, PrismSpace.md),
            child: AnimatedSwitcher(
              duration: context.motion(PrismDurations.fast),
              child: Column(
                key: ValueKey<bool>(round.wildCard),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (round.wildCard) ...<Widget>[
                    Text(context.l10n.tasteQuizWildCard, style: PrismTextStyles.eyebrow(context)),
                    const SizedBox(height: PrismSpace.xxs),
                  ],
                  Semantics(
                    header: true,
                    child: Text(context.l10n.tasteQuizTitle, style: PrismTextStyles.screenTitle(context)),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Two portrait walls side by side. On a wide screen the pair keeps a portrait shape and centres.
                final double width = constraints.maxWidth.clamp(0, constraints.maxHeight * _maxPairAspect);
                final double tileWidth = (width - _gap) / 2;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _onLayout(tileWidth);
                });
                return Center(
                  child: SizedBox(
                    width: width,
                    child: AnimatedSwitcher(
                      duration: context.motion(PrismDurations.base),
                      switchInCurve: PrismCurves.enter,
                      switchOutCurve: PrismCurves.enter,
                      child: Row(
                        key: ValueKey<int>(_round),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          for (final QuizSide side in QuizSide.values) ...<Widget>[
                            if (side == QuizSide.right) const SizedBox(width: _gap),
                            Expanded(
                              child: _WallChoice(
                                wall: round.wallAt(side),
                                images: _images ?? _QuizImages(context, tileWidth: tileWidth),
                                position: side.index + 1,
                                chosen: _chosen == null ? null : _chosen == side,
                                onPick: () => _pick(side),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static const double _gap = PrismSpace.xxs;

  /// Width over height of the pair: two 9:16 walls side by side, a little wider.
  static const double _maxPairAspect = 1.25;
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Row(
        children: <Widget>[
          for (int i = 0; i < total; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: PrismSpace.xxs),
            Expanded(
              child: AnimatedContainer(
                duration: context.motion(PrismDurations.fast),
                curve: PrismCurves.enter,
                height: _height,
                decoration: BoxDecoration(
                  color: i <= done ? cs.primary : cs.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(_height),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const double _height = 3;
}

/// One wall of the pair. The thumbnail shows at once and the full-quality preview fades in over it.
class _WallChoice extends StatelessWidget {
  const _WallChoice({
    required this.wall,
    required this.images,
    required this.position,
    required this.chosen,
    required this.onPick,
  });

  final QuizWall wall;
  final _QuizImages images;
  final int position;

  /// Null until the user picks in this round.
  final bool? chosen;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Duration fast = context.motion(PrismDurations.fast);
    return Semantics(
      button: true,
      selected: chosen ?? false,
      label: context.l10n.tasteQuizPickLabel(position, 2),
      onTap: onPick,
      excludeSemantics: true,
      child: PressScale(
        scale: 0.97,
        child: GestureDetector(
          onTap: onPick,
          child: AnimatedOpacity(
            opacity: chosen == false ? _passedOpacity : 1,
            duration: fast,
            curve: PrismCurves.enter,
            child: AnimatedScale(
              scale: chosen == false ? _passedScale : 1,
              duration: fast,
              curve: PrismCurves.enter,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(PrismRadius.sm)),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ColoredBox(color: cs.surfaceContainerHighest),
                    _FadeInImage(image: images.thumbnail(wall), duration: fast),
                    _FadeInImage(image: images.full(wall), duration: fast),
                    PositionedDirectional(
                      top: PrismSpace.sm,
                      end: PrismSpace.sm,
                      child: AnimatedScale(
                        scale: chosen == true ? 1 : 0.95,
                        duration: fast,
                        curve: PrismCurves.pop,
                        child: AnimatedOpacity(
                          opacity: chosen == true ? 1 : 0,
                          duration: fast,
                          child: Container(
                            width: _badgeSize,
                            height: _badgeSize,
                            decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                            child: Icon(Icons.check_rounded, size: _badgeSize * 0.6, color: cs.onPrimary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const double _passedOpacity = 0.4;
  static const double _passedScale = 0.96;
  static const double _badgeSize = 32;
}

class _FadeInImage extends StatelessWidget {
  const _FadeInImage({required this.image, required this.duration});

  final ImageProvider image;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: image,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) => wasSynchronouslyLoaded
          ? child
          : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: duration, child: child),
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}
