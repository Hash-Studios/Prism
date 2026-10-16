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
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
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
      toasts.info('This favourite is from an older version and cannot be opened. Press and hold to remove it.');
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

  void _showUndo(ScaffoldMessengerState messenger, String message, Future<bool> Function() undo) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              if (!await undo()) toasts.error("Couldn't restore favourites.");
            },
          ),
        ),
      );
  }

  Future<void> _removeWalls(List<FavouriteWallEntity> walls, {bool playTapHaptic = true}) async {
    final FavouriteWallsAdapter adapter = context.favouriteWallsAdapter(listen: false);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (playTapHaptic) PrismHaptics.tap();
    final bool removed = await adapter.removeWalls(walls.map((wall) => wall.id).toList(growable: false));
    if (!removed) {
      toasts.error("Couldn't remove favourites. Try again.");
      return;
    }
    _showUndo(
      messenger,
      walls.length == 1 ? 'Removed from favourites' : 'Removed ${walls.length} favourites',
      () => adapter.restoreWalls(walls),
    );
  }

  Future<void> _clearAll(List<FavouriteWallEntity> all) async {
    if (all.isEmpty) return;
    final bool guest = app_state.prismUser.id.isEmpty;
    final bool confirmed = await showPrismConfirm(
      context,
      title: all.length == 1 ? 'Clear 1 favourite?' : 'Clear ${all.length} favourites?',
      message: guest ? 'This removes them from this device.' : 'This removes them from your account.',
      confirmLabel: 'Clear all',
      destructive: true,
    );
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
    _showUndo(
      messenger,
      before.length == 1 ? 'Cleared 1 favourite' : 'Cleared ${before.length} favourites',
      () => adapter.restoreWalls(before),
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
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(PrismWallGrid.margin, 0, PrismWallGrid.margin, PrismSpace.xs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(PrismRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(PrismSpace.md, PrismSpace.xxs, PrismSpace.xxs, PrismSpace.xxs),
          child: Row(
            children: <Widget>[
              Expanded(child: Text('Sign in to keep them on every device', style: PrismTextStyles.body(context))),
              PrismButton(
                label: 'Sign in',
                variant: PrismButtonVariant.ghost,
                size: PrismButtonSize.compact,
                onPressed: () {
                  googleSignInPopUp(context, () => main.RestartWidget.restartApp(context));
                },
              ),
              PrismIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Dismiss',
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

  /// Lets a short state scroll, so pull to refresh still works on it.
  Widget _pullable(Widget child) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(child: child),
      ),
    ),
  );

  Widget _toolbar(BuildContext context, FavouriteWallsState state) {
    final FavouriteWallsBloc bloc = context.read<FavouriteWallsBloc>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(PrismWallGrid.margin, 0, PrismSpace.xxs, PrismSpace.xxs),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: PrismTextField(
                  controller: _searchController,
                  hint: 'Search by creator or category',
                  prefixIcon: Icons.search_rounded,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => bloc.add(FavouriteWallsEvent.queryChanged(query: value)),
                  suffix: state.query.isEmpty
                      ? null
                      : PrismIconButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            bloc.add(const FavouriteWallsEvent.queryChanged(query: ''));
                          },
                        ),
                ),
              ),
              PopupMenuButton<FavouriteSort>(
                tooltip: 'Sort',
                icon: const Icon(Icons.sort_rounded),
                initialValue: state.sort,
                onSelected: (sort) => bloc.add(FavouriteWallsEvent.sortChanged(sort: sort)),
                itemBuilder: (context) => <PopupMenuEntry<FavouriteSort>>[
                  for (final FavouriteSort sort in FavouriteSort.values)
                    PopupMenuItem<FavouriteSort>(value: sort, child: Text(_sortLabel(sort))),
                ],
              ),
              PopupMenuButton<_FavouritesMenuAction>(
                tooltip: 'More favourites actions',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (action) => switch (action) {
                  _FavouritesMenuAction.export => unawaited(_export(state.items)),
                  _FavouritesMenuAction.clearAll => unawaited(_clearAll(state.items)),
                },
                itemBuilder: (context) => const <PopupMenuEntry<_FavouritesMenuAction>>[
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
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
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
              padding: const EdgeInsets.only(left: PrismSpace.xxs),
              child: Text(
                state.items.length == 1 ? '1 favourite' : '${state.items.length} favourites',
                style: PrismTextStyles.caption(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceChip(BuildContext context, {required String label, required bool selected, WallpaperSource? source}) {
    return Padding(
      padding: const EdgeInsets.only(right: PrismSpace.xs),
      child: PrismChip(
        label: label,
        selected: selected,
        onTap: () => context.read<FavouriteWallsBloc>().add(FavouriteWallsEvent.sourceFilterChanged(source: source)),
      ),
    );
  }

  Widget _tile(BuildContext context, List<FavouriteWallEntity> walls, int index) {
    final FavouriteWallEntity wall = walls[index];
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool isSelected = _selected.contains(wall.id);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return KeyedSubtree(
      key: ValueKey<String>(wall.id),
      child: PressScale(
        scale: 0.97,
        child: Semantics(
          button: true,
          image: true,
          selected: isSelected,
          label: wallpaperSemanticLabel(wall.authorName),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_selecting) {
                _toggleSelected(wall);
                return;
              }
              PrismHaptics.tap();
              _openWall(walls, index);
            },
            onLongPress: () => _toggleSelected(wall),
            child: ClipRRect(
              borderRadius: PrismWallGrid.tileRadius,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  FavouriteTileImage(
                    thumbnailUrl: wall.thumbnailUrl,
                    fullUrl: wall.fullUrl,
                    heroTag: prismHeroTag(this, index, wall.id),
                    onUnavailable: () => _markUnavailable(wall.id),
                  ),
                  if (wall is LegacyFavouriteWall)
                    IgnorePointer(child: ColoredBox(color: Colors.black.withValues(alpha: 0.4))),
                  // A pure white or black hairline keeps dark images from melting into the page.
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: PrismWallGrid.tileRadius,
                        border: Border.all(color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.08)),
                      ),
                    ),
                  ),
                  if (isSelected)
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.25),
                          borderRadius: PrismWallGrid.tileRadius,
                          border: Border.all(color: cs.primary, width: 3),
                        ),
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(PrismSpace.xs),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: cs.primary,
                              child: Icon(Icons.check_rounded, size: 16, color: cs.onPrimary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_unavailable.contains(wall.id) && !isSelected)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: PrismSpace.xs,
                      child: Center(
                        child: PrismButton(
                          label: 'Remove',
                          variant: PrismButtonVariant.danger,
                          size: PrismButtonSize.compact,
                          onPressed: () => unawaited(_removeWalls(<FavouriteWallEntity>[wall], playTapHaptic: false)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, FavouriteWallsState state, bool loaded) {
    final List<FavouriteWallEntity> walls = state.visibleItems;
    if (!loaded) {
      if (state.status == LoadStatus.initial && app_state.prismUser.id.isEmpty) {
        return _pullable(const SignInPrompt(feature: 'favourites'));
      }
      return const LoadingCards();
    }
    if (state.items.isEmpty) {
      return _pullable(
        state.status == LoadStatus.failure
            ? GlintState(
                kind: GlintStateKind.error,
                title: "Couldn't load your favourites",
                body: 'Check your connection and try again.',
                actionLabel: 'Try again',
                onAction: () => unawaited(refreshList()),
              )
            : GlintState(
                kind: GlintStateKind.empty,
                title: 'No favourites yet',
                body: 'Tap the heart on a wallpaper to keep it here.',
                actionLabel: 'Browse wallpapers',
                onAction: () =>
                    context.router.navigate(const DashboardRoute(children: <PageRouteInfo>[HomeTabRoute()])),
              ),
      );
    }
    if (walls.isEmpty) {
      return _pullable(
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
          padding: PrismWallGrid.padding.copyWith(
            top: PrismSpace.xxs,
            bottom: MediaQuery.paddingOf(context).bottom + PrismSpace.md,
          ),
          itemCount: walls.length,
          gridDelegate: PrismWallGrid.delegate(context),
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
        final ColorScheme cs = Theme.of(context).colorScheme;
        final List<FavouriteWallEntity> selectedWalls = _selectedWalls(state.items);
        final bool selecting = selectedWalls.isNotEmpty;
        return PopScope(
          canPop: !selecting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _exitSelection();
          },
          child: Column(
            children: <Widget>[
              if (selecting)
                SelectionHeader(
                  count: selectedWalls.length,
                  hint: selectedWalls.length > 1 && !hideSetWallpaperUi ? 'Set uses the first one you picked' : null,
                  onCancel: _exitSelection,
                )
              else ...<Widget>[
                ?widget.header,
                if (app_state.prismUser.id.isEmpty && state.items.isNotEmpty && !_guestBannerDismissed)
                  _guestBanner(context),
                if (state.items.isNotEmpty) _toolbar(context, state),
              ],
              Expanded(
                child: RefreshIndicator(
                  color: cs.primary,
                  backgroundColor: cs.surfaceContainerHigh,
                  onRefresh: () {
                    PrismHaptics.impact();
                    return refreshList();
                  },
                  child: _content(context, state, loaded),
                ),
              ),
              if (selecting)
                SelectionActionBar(
                  actions: <Widget>[
                    CircularMenuButton(
                      label: 'Remove from favourites',
                      isLoading: false,
                      onTap: () => unawaited(_removeSelected(state.items)),
                      child: const Icon(Icons.delete_outline_rounded),
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
                      child: const Icon(Icons.ios_share_rounded),
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
