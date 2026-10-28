import 'dart:async';

import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/views/widgets/prefetch_tiles.dart';
import 'package:Prism/features/taste_quiz/domain/taste_quiz_rules.dart';
import 'package:Prism/l10n/l10n.dart';
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

/// Shows the first walls of the For you feed for [hold], then calls [onDone]. [walls] is null while the feed loads.
class TuningFeedView extends StatefulWidget {
  const TuningFeedView({super.key, required this.walls, required this.summary, required this.onDone});

  /// Long enough to read one line and see the walls, short enough not to feel like a wait.
  static const Duration hold = Duration(milliseconds: 1500);

  /// How long the thumbnails get to load before the view gives up on showing them.
  static const Duration paintBudget = Duration(milliseconds: 800);

  /// Fewer loaded thumbnails than this and the view shows the summary line alone.
  static const int minTiles = 4;

  static const int _placeholderTiles = 6;

  /// Loads one thumbnail and says whether it worked. Tests replace it.
  @visibleForTesting
  static Future<bool> Function(BuildContext context, String url, int memCacheHeight)? precacheOverride;

  final List<FeedItemEntity>? walls;
  final TasteSummary summary;
  final VoidCallback onDone;

  @override
  State<TuningFeedView> createState() => _TuningFeedViewState();
}

enum _Phase { loading, tiles, lineOnly }

class _TuningFeedViewState extends State<TuningFeedView> {
  _Phase _phase = _Phase.loading;
  Timer? _timer;
  bool _minHoldPassed = false;
  bool _started = false;
  bool _decided = false;
  bool _doneCalled = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    // The line shows for at least the hold, whatever happens to the walls.
    _startHold();
    if (widget.walls != null) WidgetsBinding.instance.addPostFrameCallback((_) => _onWalls());
  }

  @override
  void didUpdateWidget(TuningFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.walls == null && widget.walls != null) _onWalls();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _generation++;
    super.dispose();
  }

  void _startHold() {
    _timer?.cancel();
    _minHoldPassed = false;
    _timer = Timer(TuningFeedView.hold, () {
      _minHoldPassed = true;
      _finishIfReady();
    });
  }

  Future<void> _onWalls() async {
    if (!mounted || _started) return;
    _started = true;
    final List<FeedItemEntity> walls = widget.walls!;
    final int generation = ++_generation;
    if (walls.length < TuningFeedView.minTiles) return _lineOnly();
    final int columns = wallpaperGridColumns(MediaQuery.sizeOf(context).width);
    final int height = gridTileDecodeHeight(context, crossAxisCount: columns);
    int loaded = 0;
    final precache = TuningFeedView.precacheOverride ?? _precache;
    // The urls are trimmed like the grid prefetch does, so the warmed image is the one the feed asks for.
    final List<Future<void>> loads = <Future<void>>[
      for (final FeedItemEntity wall in walls)
        precache(context, wall.thumbnailUrl.trim(), height).then((ok) {
          if (ok) loaded++;
        }),
    ];
    await Future.wait(loads).timeout(TuningFeedView.paintBudget, onTimeout: () => <void>[]);
    if (!mounted || generation != _generation) return;
    if (loaded < TuningFeedView.minTiles) return _lineOnly();
    _decided = true;
    setState(() => _phase = _Phase.tiles);
    _startHold();
  }

  static Future<bool> _precache(BuildContext context, String url, int memCacheHeight) async {
    if (url.isEmpty) return false;
    bool ok = true;
    await precacheImage(tileImageProvider(url, memCacheHeight: memCacheHeight), context, onError: (_, _) => ok = false);
    return ok;
  }

  void _lineOnly() {
    if (!mounted) return;
    _decided = true;
    setState(() => _phase = _Phase.lineOnly);
    _finishIfReady();
  }

  void _finishIfReady() {
    if (!mounted || _doneCalled || !_decided || !_minHoldPassed) return;
    _doneCalled = true;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final List<FeedItemEntity> walls = widget.walls ?? const <FeedItemEntity>[];
    final int count = switch (_phase) {
      _Phase.loading => TuningFeedView._placeholderTiles,
      _Phase.tiles => walls.length,
      _Phase.lineOnly => 0,
    };
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
                if (count > 0) ...<Widget>[
                  const SizedBox(height: PrismSpace.xl),
                  // The walls take the space left, so a short screen or large text shrinks them instead of overflowing.
                  Flexible(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final int rows = (count / _columns).ceil();
                        const double gap = PrismSpace.xs;
                        final double byWidth = (constraints.maxWidth - gap * (_columns - 1)) / _columns;
                        final double byHeight = (constraints.maxHeight - gap * (rows - 1)) / rows * _tileAspectRatio;
                        final double tileWidth = byWidth < byHeight ? byWidth : byHeight;
                        final int height = gridTileDecodeHeight(
                          context,
                          crossAxisCount: wallpaperGridColumns(MediaQuery.sizeOf(context).width),
                        );
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: <Widget>[
                            for (int i = 0; i < count; i++)
                              SizedBox(
                                width: tileWidth,
                                height: tileWidth / _tileAspectRatio,
                                child: _phase == _Phase.tiles
                                    ? _TuningTile(wall: walls[i], index: i, memCacheHeight: height)
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(PrismRadius.sm),
                                        child: const ExcludeSemantics(child: PulseFill()),
                                      ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const int _columns = 3;
  static const double _maxWidth = 520;
  static const double _tileAspectRatio = 9 / 16;
}

/// A wall that rises into place, one stagger step after the one before it.
class _TuningTile extends StatelessWidget {
  const _TuningTile({required this.wall, required this.index, required this.memCacheHeight});

  final FeedItemEntity wall;
  final int index;
  final int memCacheHeight;

  @override
  Widget build(BuildContext context) {
    final Duration delay = PrismDurations.stagger * index;
    final Duration duration = PrismDurations.base + delay;
    final Widget tile = ClipRRect(
      borderRadius: BorderRadius.circular(PrismRadius.sm),
      child: PrismImageTile(url: wall.thumbnailUrl.trim(), memCacheHeight: memCacheHeight),
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
