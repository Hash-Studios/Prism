import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/favourite_walls/views/widgets/fav_grid.dart';
import 'package:Prism/features/folders/folders.dart';
import 'package:Prism/features/folders/views/folders_access.dart';
import 'package:Prism/features/library/views/widgets/offline_chip.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/download_screen.dart';
import 'package:Prism/features/wallpaper_history/biz/bloc/wallpaper_history_bloc.j.dart';
import 'package:Prism/features/wallpaper_history/views/widgets/wallpaper_history_list.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum LibraryTab {
  favourites,
  folders,
  downloads,
  history;

  String label(AppLocalizations l10n) => switch (this) {
    LibraryTab.favourites => l10n.wallpaperLibraryFavourites,
    LibraryTab.folders => l10n.foldersTitle,
    LibraryTab.downloads => l10n.wallpaperLibraryDownloads,
    LibraryTab.history => l10n.wallpaperLibraryHistory,
  };
}

/// The tabs in screen order. History needs a device that can set a wallpaper, so iOS does not get it.
List<LibraryTab> libraryTabs({required bool canSetWallpaper}) => <LibraryTab>[
  for (final LibraryTab tab in LibraryTab.values)
    if (tab != LibraryTab.history || canSetWallpaper) tab,
];

/// Favourites, Folders, Downloads and History in one place.
@RoutePage()
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, this.initialTab = LibraryTab.favourites});

  final LibraryTab initialTab;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late final List<LibraryTab> _tabs = libraryTabs(canSetWallpaper: !hideSetWallpaperUi);
  late final TabController _controller;
  late final WallpaperHistoryBloc? _history = _tabs.contains(LibraryTab.history)
      ? (getIt<WallpaperHistoryBloc>()..add(const WallpaperHistoryEvent.started()))
      : null;
  Object? _tabRequest;
  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabRequest = _routeTabRequest;
    _lastIndex = _indexOf(widget.initialTab);
    _controller = TabController(length: _tabs.length, vsync: this, initialIndex: _lastIndex)
      ..addListener(_onTabChanged);
    _trackView();
  }

  int _indexOf(LibraryTab tab) => _tabs.indexOf(tab).clamp(0, _tabs.length - 1);

  LibraryTab get _currentTab => _tabs[_controller.index];

  void _onTabChanged() {
    if (_controller.indexIsChanging || _controller.index == _lastIndex) return;
    _lastIndex = _controller.index;
    if (_currentTab == LibraryTab.history) _history?.add(const WallpaperHistoryEvent.started());
    _trackView();
  }

  void _trackView() => unawaited(analytics.track(LibraryTabViewedEvent(tab: _tabs[_lastIndex].name)));

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Object? request = _routeTabRequest;
    final bool newRequest = !identical(_tabRequest, request);
    _tabRequest = request;
    if (oldWidget.initialTab == widget.initialTab && !newRequest) return;
    _controller.index = _indexOf(widget.initialTab);
  }

  // Typed navigation creates fresh args even for the same tab; rebuilds and push/pop retain them.
  Object? get _routeTabRequest => context.findAncestorWidgetOfExactType<RouteDataScope>()?.routeData.args;

  @override
  void dispose() {
    _controller
      ..removeListener(_onTabChanged)
      ..dispose();
    unawaited(_history?.close());
    super.dispose();
  }

  Widget _body(LibraryTab tab) => switch (tab) {
    LibraryTab.favourites => const FavouriteGrid(),
    LibraryTab.folders => const FoldersGrid(),
    LibraryTab.downloads => const DownloadsBody(),
    LibraryTab.history => const WallpaperHistoryList(),
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color accent = prismReadableAccent(theme);
    final TextStyle label = PrismTextStyles.rowTitle(context);
    final Widget page = PrismPage(
      title: context.l10n.wallpaperLibraryTitle,
      maxContentWidth: double.infinity,
      actions: <Widget>[
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _TabAction(tab: _currentTab),
        ),
        const OfflineChip(),
      ],
      headerBottom: _ClampedTabBar(
        TabBar(
          controller: _controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs),
          labelPadding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm),
          labelColor: accent,
          unselectedLabelColor: prismSoftInk(theme),
          labelStyle: label,
          unselectedLabelStyle: label,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(color: accent, width: 3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: cs.onSurface.withValues(alpha: 0.08),
          tabs: <Widget>[for (final LibraryTab tab in _tabs) Tab(text: tab.label(context.l10n))],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: <Widget>[for (final LibraryTab tab in _tabs) _KeepAlive(child: _body(tab))],
      ),
    );
    final WallpaperHistoryBloc? history = _history;
    return history == null ? page : BlocProvider<WallpaperHistoryBloc>.value(value: history, child: page);
  }
}

/// The one app bar action of the tab on screen: New folder on Folders, Clear on a History with items.
class _TabAction extends StatelessWidget {
  const _TabAction({required this.tab});

  final LibraryTab tab;

  Widget _action(BuildContext context) {
    switch (tab) {
      case LibraryTab.folders:
        if (context.read<FoldersBloc?>() == null || app_state.prismUser.id.isEmpty) break;
        return PrismIconButton(
          key: const ValueKey<String>('library-new-folder'),
          icon: Icons.create_new_folder_outlined,
          tooltip: context.l10n.foldersNewFolder,
          onPressed: () => unawaited(createFolderFromLibrary(context)),
        );
      case LibraryTab.history:
        final bool hasItems = context.select((WallpaperHistoryBloc bloc) => bloc.state.items.isNotEmpty);
        if (!hasItems) break;
        return PrismButton(
          key: const ValueKey<String>('library-clear-history'),
          label: context.l10n.wallpaperClear,
          variant: PrismButtonVariant.ghost,
          size: PrismButtonSize.compact,
          onPressed: () => unawaited(confirmClearHistory(context)),
        );
      case LibraryTab.favourites:
      case LibraryTab.downloads:
        break;
    }
    return const SizedBox.shrink(key: ValueKey<String>('library-no-action'));
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: context.motion(PrismDurations.fast),
    switchInCurve: PrismCurves.enter,
    switchOutCurve: PrismCurves.enter,
    child: _action(context),
  );
}

class _ClampedTabBar extends StatelessWidget implements PreferredSizeWidget {
  const _ClampedTabBar(this.tabBar);

  final TabBar tabBar;

  @override
  Size get preferredSize => tabBar.preferredSize;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(maxScaleFactor: 1.5, child: tabBar);
}

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
