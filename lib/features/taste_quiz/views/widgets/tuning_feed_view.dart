import 'dart:async';

import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/taste_quiz/domain/taste_quiz_rules.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// The one line under "Tuning your feed". It says only what the picks clearly agree on.
String tasteSummaryLine(TasteSummary summary, AppLocalizations l10n) {
  final String? tone = summary.tone?.name;
  final String? density = summary.density?.name;
  final String? tag = summary.tag;
  return switch ((tone, density, tag)) {
    (final String tone, final String density, final String tag) => l10n.tasteQuizSummaryFull(tone, density, tag),
    (final String tone, final String density, null) => l10n.tasteQuizSummaryToneDensity(tone, density),
    (final String tone, null, final String tag) => l10n.tasteQuizSummaryToneTag(tone, tag),
    (null, final String density, final String tag) => l10n.tasteQuizSummaryDensityTag(density, tag),
    (final String tone, null, null) => l10n.tasteQuizSummaryTone(tone),
    (null, final String density, null) => l10n.tasteQuizSummaryDensity(density),
    (null, null, final String tag) => l10n.tasteQuizSummaryTag(tag),
    (null, null, null) => l10n.tasteQuizSummaryReady,
  };
}

/// Shows the walls the feed will lead with for [hold], then calls [onDone].
class TuningFeedView extends StatefulWidget {
  const TuningFeedView({super.key, required this.walls, required this.summary, required this.onDone});

  /// Long enough to read one line and see the walls, short enough not to feel like a wait.
  static const Duration hold = Duration(milliseconds: 1500);

  final List<FeedItemEntity> walls;
  final TasteSummary summary;
  final VoidCallback onDone;

  @override
  State<TuningFeedView> createState() => _TuningFeedViewState();
}

class _TuningFeedViewState extends State<TuningFeedView> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(TuningFeedView.hold, widget.onDone);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int columns = widget.walls.length > 4 ? 3 : 2;
    return SafeArea(
      child: PrismMaxWidth(
        maxWidth: _maxWidth,
        child: Padding(
          padding: const EdgeInsets.all(PrismSpace.page),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(context.l10n.tasteQuizTuningTitle, style: PrismTextStyles.screenTitle(context)),
                ),
                const SizedBox(height: PrismSpace.xs),
                Semantics(
                  liveRegion: true,
                  child: Text(tasteSummaryLine(widget.summary, context.l10n), style: PrismTextStyles.body(context)),
                ),
                const SizedBox(height: PrismSpace.xl),
                // The walls take the space left, so a short screen or large text shrinks them instead of overflowing.
                Flexible(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final int rows = (widget.walls.length / columns).ceil();
                      const double gap = PrismSpace.xs;
                      final double byWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
                      final double byHeight = (constraints.maxHeight - gap * (rows - 1)) / rows * _tileAspectRatio;
                      final double tileWidth = byWidth < byHeight ? byWidth : byHeight;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: <Widget>[
                          for (int i = 0; i < widget.walls.length; i++)
                            SizedBox(
                              width: tileWidth,
                              height: tileWidth / _tileAspectRatio,
                              child: _TuningTile(wall: widget.walls[i], index: i),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const double _maxWidth = 520;
  static const double _tileAspectRatio = 9 / 16;
}

/// A wall that rises into place, one stagger step after the one before it.
class _TuningTile extends StatelessWidget {
  const _TuningTile({required this.wall, required this.index});

  final FeedItemEntity wall;
  final int index;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Duration delay = PrismDurations.stagger * index;
    final Duration duration = PrismDurations.base + delay;
    final Widget tile = ClipRRect(
      borderRadius: BorderRadius.circular(PrismRadius.sm),
      child: ColoredBox(
        color: cs.surfaceContainerHighest,
        child: CachedNetworkImage(
          imageUrl: wall.thumbnailUrl,
          cacheManager: PrismImageCache.instance,
          fit: BoxFit.cover,
          fadeInDuration: context.motion(PrismDurations.fast),
          errorWidget: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
    if (context.reduceMotion) return ExcludeSemantics(child: tile);
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: duration,
        curve: Interval(delay.inMicroseconds / duration.inMicroseconds, 1, curve: PrismCurves.enter),
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.95 + 0.05 * t, child: child),
        ),
        child: tile,
      ),
    );
  }
}
