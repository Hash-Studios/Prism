import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_quick_actions.dart';
import 'package:Prism/features/favourite_walls/biz/favourite_counts_cubit.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_counts_repository.dart';
import 'package:Prism/features/favourite_walls/views/widgets/wallpaper_stats_row.dart';
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

  /// A tile is image only. Favourite, folders and the rest live in the hold menu and on the detail screen.
  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return WallpaperQuickActionRegion(item: item, onShowLessLikeThis: onShowLessLikeThis, child: child);
  }
}

/// Space a grid keeps under each tile. Tiles have no footer, so it is 0. Kept so grids that add it still compile.
const double favouriteFooterHeight = 0;

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
