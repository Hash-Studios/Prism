import 'dart:async';

import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_quick_actions.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/biz/favourite_counts_cubit.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_counts_repository.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/favourite_walls/views/widgets/wallpaper_stats_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FavouriteWallpaperCard extends StatelessWidget {
  const FavouriteWallpaperCard({
    super.key,
    required this.item,
    required this.child,
    this.enabled = true,
    this.onShowLessLikeThis,
  });

  final FeedItemEntity item;
  final Widget child;
  final bool enabled;
  final VoidCallback? onShowLessLikeThis;

  /// The heart sits on the image at the bottom-start corner, inside the long-press region: a tap on it toggles the
  /// favourite before the hold menu can start, and a hold anywhere on the tile still opens the menu.
  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return WallpaperQuickActionRegion(
      item: item,
      onShowLessLikeThis: onShowLessLikeThis,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          PositionedDirectional(start: 0, bottom: 0, child: FavouriteWallpaperFooter(item: item)),
        ],
      ),
    );
  }
}

/// Space a grid keeps under each tile for the heart. The heart is on the image now, so it is 0. Kept so grids that
/// add it still compile and leave no gap.
const double favouriteFooterHeight = 0;

/// The heart on a wallpaper tile: a favourite toggle only, in a 44 point target. Counts belong on the detail screen,
/// not on every tile. Place it over the image's bottom-start corner.
class FavouriteWallpaperFooter extends StatefulWidget {
  const FavouriteWallpaperFooter({super.key, required this.item});

  final FeedItemEntity item;

  @override
  State<FavouriteWallpaperFooter> createState() => _FavouriteWallpaperFooterState();
}

class _FavouriteWallpaperFooterState extends State<FavouriteWallpaperFooter> {
  bool _pending = false;

  Future<void> _toggle(bool saved) async {
    if (_pending) return;
    if (!await requireSignedInAction(context) || !mounted) return;
    final item = widget.item;
    setState(() => _pending = true);
    try {
      final success = await context
          .favouriteWallsAdapter(listen: false)
          .favCheck(FavouriteWallEntity.fromFeedItem(item), desired: !saved);
      if (!success && mounted) toasts.error(context.l10n.coreCouldNotUpdateFavourites);
    } on Object {
      if (mounted) toasts.error(context.l10n.coreCouldNotUpdateFavourites);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<FavouriteWallsBloc, FavouriteWallsState>(
    builder: (context, state) {
      final loaded = state.userId == app_state.prismUser.id && state.status == LoadStatus.success;
      final saved = loaded
          ? state.items.any((wall) => wall.id == widget.item.id && wall.source == widget.item.source)
          : getIt<FavoritesLocalDataSource>().isWallFavourite(app_state.prismUser.id, widget.item.id);
      return _row(saved);
    },
  );

  Widget _row(bool saved) => WallpaperStatsRow(
    favouriteActionLabel: saved ? context.l10n.wallpaperUnfavourite : context.l10n.wallpaperFavourite,
    favouriteSaved: saved,
    favouriteIcon: saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
    favouriteEnabled: !_pending,
    onFavouriteTap: () => unawaited(_toggle(saved)),
  );
}

class PrismFavouriteCount extends StatefulWidget {
  const PrismFavouriteCount({super.key, required this.id, this.views, this.builder, this.showFavourites = true});
  final String id;
  final int? views;
  final Widget Function(BuildContext, int)? builder;
  final bool showFavourites;

  @override
  State<PrismFavouriteCount> createState() => _PrismFavouriteCountState();
}

class _PrismFavouriteCountState extends State<PrismFavouriteCount> {
  @override
  void initState() {
    super.initState();
    getIt<FavouriteCountsCubit>().request(widget.id);
  }

  @override
  void didUpdateWidget(PrismFavouriteCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) getIt<FavouriteCountsCubit>().request(widget.id);
  }

  @override
  Widget build(BuildContext context) =>
      BlocSelector<FavouriteCountsCubit, Map<String, PrismWallpaperStats>, PrismWallpaperStats?>(
        bloc: getIt<FavouriteCountsCubit>(),
        selector: (stats) => stats[prismStatsId(widget.id)],
        builder: (context, stats) {
          if (widget.builder case final builder?) {
            return stats == null ? const SizedBox.shrink() : builder(context, stats.favourites);
          }
          final views = widget.views ?? stats?.views;
          if (stats == null && views == null) return const SizedBox.shrink();
          return WallpaperStatsRow(favourites: widget.showFavourites ? stats?.favourites : null, views: views);
        },
      );
}
