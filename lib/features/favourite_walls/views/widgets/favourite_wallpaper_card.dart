import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_quick_actions.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/biz/favourite_counts_cubit.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/domain/repositories/favourite_counts_repository.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
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

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: enabled
            ? WallpaperQuickActionRegion(item: item, onShowLessLikeThis: onShowLessLikeThis, child: child)
            : child,
      ),
      if (enabled) FavouriteWallpaperFooter(item: item) else const SizedBox(height: favouriteFooterHeight),
    ],
  );
}

const double favouriteFooterHeight = 44;

int? displayedFavouriteCount(WallpaperSource source, {int? published, required bool saved}) => switch (source) {
  WallpaperSource.pexels => published ?? (saved ? 1 : null),
  WallpaperSource.prism || WallpaperSource.wallhaven => published,
  _ => null,
};

class FavouriteWallpaperFooter extends StatefulWidget {
  const FavouriteWallpaperFooter({super.key, required this.item});

  final FeedItemEntity item;

  @override
  State<FavouriteWallpaperFooter> createState() => _FavouriteWallpaperFooterState();
}

class _FavouriteWallpaperFooterState extends State<FavouriteWallpaperFooter> {
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    _request();
  }

  @override
  void didUpdateWidget(FavouriteWallpaperFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id || oldWidget.item.source != widget.item.source) _request();
  }

  void _request() {
    if (widget.item.source == WallpaperSource.prism) getIt<FavouriteCountsCubit>().request(widget.item.id);
  }

  Future<void> _toggle(bool saved) async {
    if (_pending) return;
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
      if (widget.item.source == WallpaperSource.prism) {
        return BlocSelector<FavouriteCountsCubit, Map<String, int>, int?>(
          bloc: getIt<FavouriteCountsCubit>(),
          selector: (counts) => counts[prismStatsId(widget.item.id)],
          builder: (context, count) => _row(saved, count),
        );
      }
      return _row(saved, widget.item.wallpaperCore.favourites);
    },
  );

  Widget _row(bool saved, int? published) {
    final count = displayedFavouriteCount(widget.item.source, published: published, saved: saved);
    final scheme = Theme.of(context).colorScheme;
    final label = saved ? context.l10n.wallpaperUnfavourite : context.l10n.wallpaperFavourite;
    return SizedBox(
      height: favouriteFooterHeight,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Tooltip(
          message: label,
          child: Semantics(
            button: true,
            toggled: saved,
            label: label,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _pending ? null : () => unawaited(_toggle(saved)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 18,
                        color: saved ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                      if (count != null) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '$count',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PrismFavouriteCount extends StatefulWidget {
  const PrismFavouriteCount({super.key, required this.id, required this.builder});
  final String id;
  final Widget Function(BuildContext, int) builder;

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
  Widget build(BuildContext context) => BlocSelector<FavouriteCountsCubit, Map<String, int>, int?>(
    bloc: getIt<FavouriteCountsCubit>(),
    selector: (counts) => counts[prismStatsId(widget.id)],
    builder: (context, count) {
      return count == null ? const SizedBox.shrink() : widget.builder(context, count);
    },
  );
}
