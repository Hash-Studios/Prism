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
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/core/widgets/selection_action_bar.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_tile_image.dart';
import 'package:Prism/features/library/data/favourites_export.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

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

enum _FavouritesMenuAction { export, clearAll }

class FavouriteGrid extends StatefulWidget {
  const FavouriteGrid({super.key, this.header});

  /// Shown above the toolbar when nothing is selected. The Library hub puts its smart rows here.
  final Widget? header;

  @override
  State<FavouriteGrid> createState() => _FavouriteGridState();
}

class _FavouriteGridState extends State<FavouriteGrid> {
  final ScrollMilestoneTracker _scrollMilestoneTracker = ScrollMilestoneTracker();
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();
  late final TextEditingController _searchController;
  final Set<String> _selected = <String>{};
  final Set<String> _unavailable = <String>{};

  /// A guest closes the sign-in banner once per app session.
  static bool _guestBannerDismissed = false;

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
    _exitSelection();
    await _removeWalls(walls);
  }

  Future<void> _removeWalls(List<FavouriteWallEntity> walls) async {
    final FavouriteWallsAdapter adapter = context.favouriteWallsAdapter(listen: false);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    PrismHaptics.tap();
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

  Future<void> _clearAll(List<FavouriteWallEntity> all) async {
    if (all.isEmpty) return;
    final bool guest = app_state.prismUser.id.isEmpty;
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(all.length == 1 ? 'Clear 1 favourite?' : 'Clear ${all.length} favourites?'),
            content: Text(guest ? 'This removes them from this device.' : 'This removes them from your account.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text('Clear all', style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    final FavouriteWallsAdapter adapter = context.favouriteWallsAdapter(listen: false);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final List<FavouriteWallEntity> before = List<FavouriteWallEntity>.of(all);
    PrismHaptics.tap();
    _exitSelection();
    if (!await adapter.deleteData()) {
      toasts.error("Couldn't clear favourites. Try again.");
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(before.length == 1 ? 'Cleared 1 favourite' : 'Cleared ${before.length} favourites'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              if (!await adapter.restoreWalls(before)) toasts.error("Couldn't restore favourites.");
            },
          ),
        ),
      );
  }

  Future<void> _export(List<FavouriteWallEntity> all) async {
    if (all.isEmpty) {
      toasts.info('No favourites to export yet.');
      return;
    }
    PrismHaptics.tap();
    final RenderObject? box = context.findRenderObject();
    final Rect origin = box is RenderBox && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : Rect.zero;
    try {
      final file = await writeFavouritesExportFile(all);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path)],
          sharePositionOrigin: origin.isEmpty ? const Rect.fromLTWH(1, 1, 1, 1) : origin,
        ),
      );
      unawaited(analytics.track(FavouritesExportedEvent(count: all.length)));
    } catch (error, stackTrace) {
      logger.e('Could not export favourites', error: error, stackTrace: stackTrace, tag: favouritesExportSourceTag);
      toasts.error("Couldn't export favourites. Try again.");
    }
  }

  void _markUnavailable(String id) {
    if (_unavailable.contains(id) || !mounted) return;
    setState(() => _unavailable.add(id));
  }

  Widget _guestBanner(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 2, 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Sign in to keep them on every device',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.secondary),
                ),
              ),
              TextButton(
                onPressed: () {
                  PrismHaptics.tap();
                  googleSignInPopUp(context, () => main.RestartWidget.restartApp(context));
                },
                child: const Text('Sign in'),
              ),
              IconButton(
                tooltip: 'Dismiss',
                icon: Icon(JamIcons.close, size: 18, color: theme.hintColor),
                onPressed: () => setState(() => _guestBannerDismissed = true),
              ),
            ],
          ),
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
              PopupMenuButton<_FavouritesMenuAction>(
                tooltip: 'More favourites actions',
                icon: Icon(JamIcons.more_vertical, color: theme.colorScheme.secondary),
                onSelected: (action) => switch (action) {
                  _FavouritesMenuAction.export => unawaited(_export(state.items)),
                  _FavouritesMenuAction.clearAll => unawaited(_clearAll(state.items)),
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<_FavouritesMenuAction>(
                    value: _FavouritesMenuAction.export,
                    child: Text('Export favourites'),
                  ),
                  PopupMenuItem<_FavouritesMenuAction>(
                    value: _FavouritesMenuAction.clearAll,
                    child: Text('Clear all favourites'),
                  ),
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
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 0, 0),
              child: Text(
                state.items.length == 1 ? '1 favourite' : '${state.items.length} favourites',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              ),
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
            child: FavouriteTileImage(
              thumbnailUrl: wall.thumbnailUrl,
              fullUrl: wall.fullUrl,
              heroTag: prismHeroTag(this, index, wall.id),
              onUnavailable: () => _markUnavailable(wall.id),
            ),
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
          if (_unavailable.contains(wall.id) && !isSelected)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Center(
                child: TextButton.icon(
                  onPressed: () => unawaited(_removeWalls(<FavouriteWallEntity>[wall])),
                  icon: Icon(JamIcons.trash, size: 16, color: scheme.error),
                  label: Text('Remove', style: TextStyle(color: scheme.error)),
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
        return _scrollable(const SignInPrompt(feature: 'favourites'));
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
    return BlocConsumer<FavouriteWallsBloc, FavouriteWallsState>(
      listenWhen: (previous, current) =>
          previous.status != LoadStatus.failure && current.status == LoadStatus.failure && current.items.isNotEmpty,
      listener: (context, state) => toasts.info("Couldn't refresh favourites. Showing your saved list."),
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
              else ...[
                ?widget.header,
                if (app_state.prismUser.id.isEmpty && state.items.isNotEmpty && !_guestBannerDismissed)
                  _guestBanner(context),
                if (state.items.isNotEmpty) _toolbar(context, state),
              ],
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
