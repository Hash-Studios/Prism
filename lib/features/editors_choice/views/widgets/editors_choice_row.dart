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
import 'package:Prism/features/editors_choice/biz/editors_choice_cubit.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Editors' Choice strip between For you grid tiles: title, one line, See all, and up to 10 picks.
/// Nothing while it loads, fails or has fewer than [minPicks] picks.
class EditorsChoiceRow extends StatefulWidget {
  const EditorsChoiceRow({super.key, this.cubit});

  /// Supplied by tests. Otherwise the row creates and closes its own cubit.
  final EditorsChoiceCubit? cubit;

  static const int minPicks = 4;

  @override
  State<EditorsChoiceRow> createState() => _EditorsChoiceRowState();
}

class _EditorsChoiceRowState extends State<EditorsChoiceRow> {
  static const int _loadLimit = 30;
  static const int _stripLimit = 10;
  static const double _visibleCards = 2.4;

  late final EditorsChoiceCubit _cubit;
  late final bool _ownsCubit;
  late final WallpaperImpressionSession _impressionSession;
  bool _seenTracked = false;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? getIt<EditorsChoiceCubit>();
    _impressionSession = WallpaperImpressionSession();
    unawaited(_cubit.load(limit: _loadLimit));
  }

  @override
  void dispose() {
    if (_ownsCubit) unawaited(_cubit.close());
    super.dispose();
  }

  void _seen(int pickCount) {
    if (_seenTracked) return;
    _seenTracked = true;
    unawaited(analytics.track(EditorsChoiceRowSeenEvent(pickCount: pickCount)));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorsChoiceCubit, EditorsChoiceState>(
      bloc: _cubit,
      builder: (context, state) => switch (state) {
        EditorsChoiceLoaded(:final walls) when walls.length >= EditorsChoiceRow.minPicks => _section(context, walls),
        EditorsChoiceLoading() || EditorsChoiceLoaded() || EditorsChoiceFailed() => const SizedBox.shrink(),
      },
    );
  }

  Widget _section(BuildContext context, List<PrismWallpaper> walls) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[_header(context), _wallStrip(context, walls)],
    );
  }

  Widget _header(BuildContext context) {
    final l10n = context.l10n;
    final String title = l10n.editorsChoiceTitle;
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
                  l10n.editorsChoiceRowBody,
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
              onPressed: () => unawaited(context.router.pushPath('/editors-choice?source=row')),
            ),
          ),
        ],
      ),
    );
  }

  double _cardWidth(BuildContext context) =>
      (MediaQuery.sizeOf(context).width - PrismFeedLayout.gridSpacing * 3) / _visibleCards;

  Widget _wallStrip(BuildContext context, List<PrismWallpaper> walls) {
    final List<PrismFeedItem> items = <PrismFeedItem>[
      for (final PrismWallpaper wall in walls.take(_stripLimit)) PrismFeedItem(id: wall.id, wallpaper: wall),
    ];
    final double cardWidth = _cardWidth(context);
    final int decodeHeight = gridTileDecodeHeight(context, crossAxisCount: 2);
    final double cardHeight = cardWidth / PrismFeedLayout.gridTileAspectRatio;
    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: PrismFeedLayout.gridPadding,
        itemCount: math.min(_stripLimit, walls.length),
        separatorBuilder: (_, _) => const SizedBox(width: PrismFeedLayout.gridSpacing),
        itemBuilder: (context, index) => SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: WallpaperTile(
            item: items[index],
            index: index,
            crossAxisCount: 2,
            memCacheHeight: decodeHeight,
            impressionSession: _impressionSession,
            sourceContext: 'home_editors_choice_row',
            feed: items,
            onVisible: () => _seen(walls.length),
          ),
        ),
      ),
    );
  }
}
