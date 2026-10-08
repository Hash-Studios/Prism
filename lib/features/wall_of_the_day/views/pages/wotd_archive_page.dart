import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/core/heading_chip_bar.dart';
import 'package:Prism/core/widgets/home/refreshable_glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_archive_bloc.j.dart';
import 'package:Prism/features/wall_of_the_day/domain/entities/wotd_past_pick.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// The last 30 Wall of the Day picks, newest first.
@RoutePage()
class WotdArchivePage extends StatelessWidget implements AutoRouteWrapper {
  const WotdArchivePage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) => BlocProvider<WotdArchiveBloc>(
    create: (_) => getIt<WotdArchiveBloc>()..add(const WotdArchiveEvent.started()),
    child: this,
  );

  Future<void> _refresh(BuildContext context) {
    final WotdArchiveBloc bloc = context.read<WotdArchiveBloc>();
    PrismHaptics.impact();
    final Future<WotdArchiveState> settled = bloc.stream.firstWhere((state) => state.status != LoadStatus.loading);
    bloc.add(const WotdArchiveEvent.refreshRequested());
    return settled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: const PreferredSize(
        preferredSize: Size(double.infinity, 55),
        child: HeadingChipBar(current: 'Past picks'),
      ),
      body: BlocBuilder<WotdArchiveBloc, WotdArchiveState>(
        builder: (context, state) {
          if (state.picks.isEmpty && state.status != LoadStatus.success && state.status != LoadStatus.failure) {
            return const LoadingCards();
          }
          if (state.picks.isEmpty) {
            final bool failed = state.status == LoadStatus.failure;
            return RefreshableGlintState(
              kind: failed ? GlintStateKind.error : GlintStateKind.empty,
              title: failed ? "Couldn't load past picks" : 'No past picks yet',
              body: failed ? 'Check your connection and try again.' : 'Check back tomorrow.',
              actionLabel: failed ? 'Try again' : null,
              onAction: failed ? () => unawaited(_refresh(context)) : null,
              onRefresh: () => _refresh(context),
            );
          }
          return RefreshIndicator(
            onRefresh: () => _refresh(context),
            child: _PicksGrid(picks: state.picks),
          );
        },
      ),
    );
  }
}

class _PicksGrid extends StatelessWidget {
  const _PicksGrid({required this.picks});

  final List<WotdPastPick> picks;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      itemCount: picks.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 0.45,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) => _PickTile(pick: picks[index], index: index),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({required this.pick, required this.index});

  final WotdPastPick pick;
  final int index;

  void _open(BuildContext context, String heroTag) {
    PrismHaptics.tap();
    unawaited(analytics.track(WotdOpenedEvent(wallId: pick.wallpaper.id, source: 'archive')));
    context.router.push(
      WallpaperDetailRoute(
        entity: PrismFeedItem(id: pick.wallpaper.id, wallpaper: pick.wallpaper),
        heroTag: heroTag,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String dateLabel = DateFormat('EEE d MMM').format(pick.date.toLocal());
    final String heroTag = prismHeroTag(pick, index, pick.wallpaper.id);
    final int decodeHeight = gridTileDecodeHeight(context, crossAxisCount: 2);
    return Semantics(
      button: true,
      label: '${wallpaperSemanticLabel(pick.wallpaper.core.authorName)}, picked $dateLabel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Stack(
              children: <Widget>[
                PrismImageTile(
                  url: pick.wallpaper.thumbnailUrl,
                  fallbackUrl: pick.wallpaper.fullUrl,
                  memCacheHeight: decodeHeight,
                  heroTag: heroTag,
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    splashColor: theme.colorScheme.secondary.withValues(alpha: 0.3),
                    highlightColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
                    enableFeedback: false,
                    onTap: () => _open(context, heroTag),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ExcludeSemantics(
              child: Text(
                dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
