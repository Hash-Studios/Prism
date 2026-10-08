import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/analytics/trackers/scroll_milestone_tracker.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/share_service.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/core/widgets/selection_action_bar.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

String _sourceLabel(WallpaperSource source) => switch (source) {
  WallpaperSource.prism => 'Prism',
  WallpaperSource.wallhaven => 'Wallhaven',
  WallpaperSource.pexels => 'Pexels',
  WallpaperSource.downloaded => 'Downloads',
  WallpaperSource.unknown => 'Other',
};

String _sortLabel(FavouriteSort sort) => switch (sort) {
  FavouriteSort.recentlyAdded => 'Recently added',
  FavouriteSort.oldest => 'Oldest',
  FavouriteSort.source => 'Source',
};

const List<WallpaperSource> _filterSources = <WallpaperSource>[
  WallpaperSource.prism,
  WallpaperSource.wallhaven,
  WallpaperSource.pexels,
];

class FavouriteGrid extends StatefulWidget {
  const FavouriteGrid({super.key});

  @override
  State<FavouriteGrid> createState() => _FavouriteGridState();
}

class _FavouriteGridState extends State<FavouriteGrid> {
  final ScrollMilestoneTracker _scrollMilestoneTracker = ScrollMilestoneTracker();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();
  late final TextEditingController _searchController;
  final Set<String> _selected = <String>{};

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: context.read<FavouriteWallsBloc>().state.query);
    _contentLoadTracker.start();
    unawaited(context.favouriteWallsAdapter(listen: false).getDataBase());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> refreshList() async {
    _contentLoadTracker.start();
    _scrollMilestoneTracker.reset();
    await context.favouriteWallsAdapter(listen: false).getDataBase(forceRefresh: true);
  }

  void _exitSelection() {
    if (!mounted) return;
    setState(_selected.clear);
  }

  void _toggleSelected(FavouriteWallEntity wall) {
    PrismHaptics.tap();
    setState(() {
      if (!_selected.remove(wall.id)) _selected.add(wall.id);
    });
  }

  void _openWall(List<FavouriteWallEntity> walls, int index) {
    final FavouriteWallEntity wall = walls[index];
    if (wall is LegacyFavouriteWall) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('This favourite is from an older version and cannot be opened. Press and hold to remove it.'),
          ),
        );
      return;
    }
    unawaited(
      analytics.track(
        SurfaceActionTappedEvent(
          surface: AnalyticsSurfaceValue.favouriteWallsGrid,
          action: AnalyticsActionValue.tileOpened,
          sourceContext: 'favourite_walls_grid_tile',
          itemType: ItemTypeValue.wallpaper,
          itemId: wall.id,
          index: index,
        ),
      ),
    );
    context.router.push(
      WallpaperDetailRoute(
        entity: wall.toFeedItem(),
        analyticsSurface: AnalyticsSurfaceValue.favouriteWallpaperView,
        heroTag: prismHeroTag(this, index, wall.id),
      ),
    );
  }

  List<FavouriteWallEntity> _selectedWalls(List<FavouriteWallEntity> all) {
    final Map<String, FavouriteWallEntity> byId = <String, FavouriteWallEntity>{for (final wall in all) wall.id: wall};
    return _selected.map((id) => byId[id]).whereType<FavouriteWallEntity>().toList(growable: false);
  }

  Future<void> _removeSelected(List<FavouriteWallEntity> all) async {
    final List<FavouriteWallEntity> walls = _selectedWalls(all);
    if (walls.isEmpty) return;
    final FavouriteWallsAdapter adapter = context.favouriteWallsAdapter(listen: false);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    PrismHaptics.tap();
    _exitSelection();
    final bool removed = await adapter.removeWalls(walls.map((wall) => wall.id).toList(growable: false));
    if (!removed) {
      toasts.error("Couldn't remove favourites. Try again.");
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(walls.length == 1 ? 'Removed from favourites' : 'Removed ${walls.length} favourites'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              if (!await adapter.restoreWalls(walls)) toasts.error("Couldn't restore favourites.");
            },
          ),
        ),
      );
  }

  Future<void> _shareSelected(List<FavouriteWallEntity> all) async {
    final List<FavouriteWallEntity> walls = _selectedWalls(all);
    if (walls.isEmpty) return;
    PrismHaptics.tap();
    try {
      final FavouriteWallEntity first = walls.first;
      String? link;
      if (walls.length == 1 && first is! LegacyFavouriteWall) {
        link = await createDynamicLink(first.id, first.source, first.fullUrl, first.thumbnailUrl);
      }
      if (!mounted) return;
      final String text = link ?? walls.map((wall) => wall.fullUrl).where((url) => url.isNotEmpty).join('\n');
      if (text.isEmpty) return;
      await ShareService.shareText(text: text, context: context);
    } catch (error, stackTrace) {
      logger.e('Could not share favourites', error: error, stackTrace: stackTrace);
      toasts.error("Couldn't share. Try again.");
    }
  }

  Widget _scrollable(Widget child) => LayoutBuilder(
    builder: (context, constraints) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [SizedBox(height: constraints.maxHeight, child: child)],
    ),
  );

  Widget _toolbar(BuildContext context, FavouriteWallsState state) {
    final ThemeData theme = Theme.of(context);
    final FavouriteWallsBloc bloc = context.read<FavouriteWallsBloc>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 4, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => bloc.add(FavouriteWallsEvent.queryChanged(query: value)),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search by creator or category',
                    prefixIcon: Icon(JamIcons.search, size: 18, color: theme.hintColor),
                    suffixIcon: state.query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: Icon(JamIcons.close, size: 18, color: theme.hintColor),
                            onPressed: () {
                              _searchController.clear();
                              bloc.add(const FavouriteWallsEvent.queryChanged(query: ''));
                            },
                          ),
                    filled: true,
                    fillColor: theme.colorScheme.secondary.withValues(alpha: 0.08),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ),
              PopupMenuButton<FavouriteSort>(
                tooltip: 'Sort',
                icon: Icon(JamIcons.filter, color: theme.colorScheme.secondary),
                initialValue: state.sort,
                onSelected: (sort) => bloc.add(FavouriteWallsEvent.sortChanged(sort: sort)),
                itemBuilder: (context) => [
                  for (final FavouriteSort sort in FavouriteSort.values)
                    PopupMenuItem<FavouriteSort>(value: sort, child: Text(_sortLabel(sort))),
                ],
              ),
            ],
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _sourceChip(context, label: 'All', selected: state.sourceFilter == null),
                for (final WallpaperSource source in _filterSources)
                  _sourceChip(
                    context,
                    label: _sourceLabel(source),
                    selected: state.sourceFilter == source,
                    source: source,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceChip(BuildContext context, {required String label, required bool selected, WallpaperSource? source}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          PrismHaptics.tap();
          context.read<FavouriteWallsBloc>().add(FavouriteWallsEvent.sourceFilterChanged(source: source));
        },
      ),
    );
  }

  Widget _tile(BuildContext context, List<FavouriteWallEntity> walls, int index) {
    final FavouriteWallEntity wall = walls[index];
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isSelected = _selected.contains(wall.id);
    return Semantics(
      button: true,
      selected: isSelected,
      label: wallpaperSemanticLabel(wall.authorName),
      child: Stack(
        key: ValueKey<String>(wall.id),
        children: [
          Positioned.fill(
            child: PrismImageTile(url: wall.thumbnailUrl, heroTag: prismHeroTag(this, index, wall.id)),
          ),
          if (isSelected)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.25),
                  border: Border.all(color: scheme.primary, width: 3),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: scheme.primary,
                      child: Icon(JamIcons.check, size: 16, color: scheme.onPrimary),
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                splashColor: scheme.secondary.withValues(alpha: 0.3),
                highlightColor: scheme.secondary.withValues(alpha: 0.1),
                onTap: () {
                  if (_selecting) {
                    _toggleSelected(wall);
                    return;
                  }
                  PrismHaptics.tap();
                  _openWall(walls, index);
                },
                onLongPress: () => _toggleSelected(wall),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, FavouriteWallsState state, bool loaded) {
    final List<FavouriteWallEntity> walls = state.visibleItems;
    if (!loaded) {
      if (state.status == LoadStatus.initial && app_state.prismUser.id.isEmpty) {
        return _scrollable(
          const GlintState(
            kind: GlintStateKind.empty,
            title: 'Sign in to save favourites',
            body: 'Your favourite wallpapers show up here once you are signed in.',
          ),
        );
      }
      return const LoadingCards();
    }
    if (state.items.isEmpty) {
      return _scrollable(
        state.status == LoadStatus.failure
            ? GlintState(
                kind: GlintStateKind.error,
                title: "Couldn't load favourites",
                body: 'Check your connection and try again.',
                actionLabel: 'Retry',
                onAction: () => unawaited(refreshList()),
              )
            : GlintState(
                kind: GlintStateKind.empty,
                title: 'No favourites yet',
                body: 'Tap the heart on a wallpaper to save it here.',
                actionLabel: 'Browse wallpapers',
                onAction: () => context.router.popUntilRoot(),
              ),
      );
    }
    if (walls.isEmpty) {
      return _scrollable(
        GlintState(
          kind: GlintStateKind.empty,
          title: 'No matching favourites',
          body: 'Try a different search or source.',
          actionLabel: 'Clear filters',
          onAction: () {
            _searchController.clear();
            context.read<FavouriteWallsBloc>()
              ..add(const FavouriteWallsEvent.queryChanged(query: ''))
              ..add(const FavouriteWallsEvent.sourceFilterChanged());
          },
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        _scrollMilestoneTracker.onScroll(
          metrics: notification.metrics,
          itemCount: walls.length,
          onMilestoneReached: (depth, {required int itemCount}) async {
            await analytics.track(
              ScrollMilestoneReachedEvent(
                surface: AnalyticsSurfaceValue.favouriteWallsGrid,
                listName: ScrollListNameValue.favouriteWallsGrid,
                depth: depth,
                sourceContext: 'favourite_walls_grid_scroll',
                itemCount: itemCount,
              ),
            );
          },
        );
        return false;
      },
      child: PulsePlaceholder(
        builder: (context, _) => GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: walls.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: wallpaperGridColumns(MediaQuery.sizeOf(context).width),
            childAspectRatio: 0.5,
          ),
          itemBuilder: (context, index) => _tile(context, walls, index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavouriteWallsBloc, FavouriteWallsState>(
      builder: (context, state) {
        final bool loaded =
            state.status != LoadStatus.initial && (state.status != LoadStatus.loading || state.items.isNotEmpty);
        if (loaded) {
          _contentLoadTracker.success(
            itemCount: state.items.length,
            onSuccess: ({required int loadTimeMs, int? itemCount}) async {
              await analytics.track(
                SurfaceContentLoadedEvent(
                  surface: AnalyticsSurfaceValue.favouriteWallsGrid,
                  result: (itemCount ?? 0) > 0 ? EventResultValue.success : EventResultValue.empty,
                  loadTimeMs: loadTimeMs,
                  sourceContext: 'favourite_walls_grid_initial',
                  itemCount: itemCount,
                ),
              );
            },
          );
        }
        final List<FavouriteWallEntity> selectedWalls = _selectedWalls(state.items);
        final bool selecting = selectedWalls.isNotEmpty;
        return PopScope(
          canPop: !selecting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _exitSelection();
          },
          child: Column(
            children: [
              if (selecting)
                SelectionHeader(
                  count: selectedWalls.length,
                  hint: selectedWalls.length > 1 && !hideSetWallpaperUi ? 'Set uses the first one you picked' : null,
                  onCancel: _exitSelection,
                )
              else if (state.items.isNotEmpty)
                _toolbar(context, state),
              Expanded(
                child: RefreshIndicator(
                  backgroundColor: Theme.of(context).primaryColor,
                  onRefresh: () {
                    PrismHaptics.impact();
                    return refreshList();
                  },
                  child: _content(context, state, loaded),
                ),
              ),
              if (selecting)
                SelectionActionBar(
                  actions: [
                    CircularMenuButton(
                      label: 'Remove from favourites',
                      isLoading: false,
                      onTap: () => unawaited(_removeSelected(state.items)),
                      child: Icon(JamIcons.trash, color: Theme.of(context).colorScheme.secondary, size: 20),
                    ),
                    if (!hideSetWallpaperUi)
                      SetWallpaperButton(
                        url: selectedWalls.first.fullUrl,
                        thumbnailUrl: selectedWalls.first.thumbnailUrl,
                        onSet: _exitSelection,
                      ),
                    CircularMenuButton(
                      label: 'Share',
                      isLoading: false,
                      onTap: () => unawaited(_shareSelected(state.items)),
                      child: Icon(JamIcons.share_alt, color: Theme.of(context).colorScheme.secondary, size: 20),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
