import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/wallpaper_impression.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/moods/biz/mood_walls_cubit.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/views/mood_copy.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A mood between For you grid tiles: title, one line, See all, and a strip of the user's best-matching walls.
/// Nothing while it fails or has too few walls. [slot] is 0 or 1, for analytics.
class MoodRow extends StatefulWidget {
  const MoodRow({super.key, required this.list, required this.slot});

  final MoodList list;
  final int slot;

  @override
  State<MoodRow> createState() => _MoodRowState();
}

class _MoodRowState extends State<MoodRow> {
  static const int _loadLimit = 30;
  static const int _stripLimit = 10;
  int get _minWalls => widget.list.mood == WallMood.duoReveal ? 1 : 3;
  static const double _visibleCards = 2.4;

  late final MoodWallsCubit _cubit;
  late WallpaperImpressionSession _impressionSession;
  bool _seenTracked = false;

  @override
  void initState() {
    super.initState();
    _cubit = getIt<MoodWallsCubit>();
    _impressionSession = WallpaperImpressionSession();
    unawaited(_cubit.load(widget.list.mood, limit: _loadLimit, wallIds: widget.list.wallIds));
  }

  @override
  void didUpdateWidget(MoodRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool moodChanged = oldWidget.list.mood != widget.list.mood;
    if (moodChanged || !listEquals(oldWidget.list.wallIds, widget.list.wallIds)) {
      if (moodChanged) {
        _seenTracked = false;
        _impressionSession = WallpaperImpressionSession();
      }
      unawaited(_cubit.load(widget.list.mood, limit: _loadLimit, wallIds: widget.list.wallIds));
    }
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  void _seen() {
    if (_seenTracked) return;
    _seenTracked = true;
    unawaited(analytics.track(MoodRowSeenEvent(moodId: widget.list.mood.id, slot: widget.slot)));
  }

  void _open(BuildContext context) {
    if (widget.list.mood == WallMood.duoReveal) {
      unawaited(analytics.track(const DuoRowOpenedEvent(source: 'row')));
    }
    unawaited(context.router.pushPath('/mood/${widget.list.mood.id}?source=row'));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MoodWallsCubit, MoodWallsState>(
      bloc: _cubit,
      builder: (context, state) {
        switch (state) {
          case MoodWallsLoading():
            return widget.list.mood == WallMood.duoReveal
                ? const SizedBox.shrink()
                : _section(context, _skeletonStrip(context));
          case MoodWallsLoaded(:final walls) when walls.length >= _minWalls:
            return _section(context, _wallStrip(context, walls));
          case MoodWallsLoaded():
          case MoodWallsFailed():
            return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _section(BuildContext context, Widget strip) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[_header(context), strip]);
  }

  Widget _header(BuildContext context) {
    final l10n = context.l10n;
    final String title = widget.list.mood.title(l10n);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PrismFeedLayout.gridSpacing + 4,
        PrismSpace.lg,
        PrismFeedLayout.gridSpacing + 4,
        PrismSpace.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PrismTextStyles.sectionTitle(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.list.mood.body(l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PrismTextStyles.body(context),
                ),
              ],
            ),
          ),
          Semantics(
            hint: l10n.moodSeeAllHint(title),
            child: PrismButton(
              label: l10n.moodSeeAll,
              variant: PrismButtonVariant.ghost,
              size: PrismButtonSize.compact,
              onPressed: () => _open(context),
            ),
          ),
        ],
      ),
    );
  }

  double _cardWidth(BuildContext context) =>
      (MediaQuery.sizeOf(context).width - PrismFeedLayout.gridSpacing * 3) / _visibleCards;

  Widget _strip(BuildContext context, {required int itemCount, required IndexedWidgetBuilder itemBuilder}) {
    final double cardHeight = _cardWidth(context) / PrismFeedLayout.gridTileAspectRatio;
    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: PrismFeedLayout.gridPadding,
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: PrismFeedLayout.gridSpacing),
        itemBuilder: itemBuilder,
      ),
    );
  }

  Widget _skeletonStrip(BuildContext context) {
    final double cardWidth = _cardWidth(context);
    final double cardHeight = cardWidth / PrismFeedLayout.gridTileAspectRatio;
    return PrismSkeleton(
      child: _strip(
        context,
        itemCount: _minWalls,
        itemBuilder: (_, _) => PrismBone(width: cardWidth, height: cardHeight, radius: PrismRadius.sm),
      ),
    );
  }

  Widget _wallStrip(BuildContext context, List<PrismWallpaper> walls) {
    final List<PrismFeedItem> items = <PrismFeedItem>[
      for (final PrismWallpaper wall in walls.take(_stripLimit)) PrismFeedItem(id: wall.id, wallpaper: wall),
    ];
    final double cardWidth = _cardWidth(context);
    final int decodeHeight = gridTileDecodeHeight(context, crossAxisCount: 2);
    return _strip(
      context,
      itemCount: math.min(_stripLimit, walls.length),
      itemBuilder: (context, index) => SizedBox(
        width: cardWidth,
        height: cardWidth / PrismFeedLayout.gridTileAspectRatio,
        child: WallpaperTile(
          item: items[index],
          index: index,
          crossAxisCount: 2,
          memCacheHeight: decodeHeight,
          impressionSession: _impressionSession,
          sourceContext: 'home_mood_row',
          feed: items,
          onVisible: _seen,
        ),
      ),
    );
  }
}
