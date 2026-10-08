import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/features/favourite_walls/views/widgets/fav_grid.dart';
import 'package:Prism/features/library/views/widgets/offline_chip.dart';
import 'package:Prism/features/library/views/widgets/recently_set_row.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/download_screen.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

enum LibraryTab {
  favourites('Favourites'),
  downloads('Downloads'),
  history('History');

  const LibraryTab(this.label);

  final String label;
}

/// Favourites, Downloads and History in one place. History is Android only, because iOS cannot set a wallpaper.
@RoutePage()
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, this.initialTab = LibraryTab.favourites});

  final LibraryTab initialTab;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late final List<LibraryTab> _tabs = <LibraryTab>[
    LibraryTab.favourites,
    LibraryTab.downloads,
    if (!hideSetWallpaperUi) LibraryTab.history,
  ];
  late final TabController _controller;
  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();
    final int start = _tabs.indexOf(widget.initialTab);
    _lastIndex = start < 0 ? 0 : start;
    _controller = TabController(length: _tabs.length, vsync: this, initialIndex: _lastIndex)
      ..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_controller.indexIsChanging || _controller.index == _lastIndex) return;
    _lastIndex = _controller.index;
    unawaited(analytics.track(LibraryTabChangedEvent(tab: _tabs[_lastIndex].name)));
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  Widget _body(LibraryTab tab) => switch (tab) {
    LibraryTab.favourites => FavouriteGrid(header: hideSetWallpaperUi ? null : const RecentlySetRow()),
    LibraryTab.downloads => const DownloadsBody(),
    LibraryTab.history => const _HistoryTab(),
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.primaryColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        backgroundColor: theme.primaryColor,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: Icon(JamIcons.chevron_left, color: scheme.secondary),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text('Library', style: theme.textTheme.displaySmall?.copyWith(color: scheme.secondary)),
        actions: const [OfflineChip(), SizedBox(width: 12)],
        bottom: TabBar(
          controller: _controller,
          labelColor: scheme.secondary,
          unselectedLabelColor: theme.hintColor,
          indicatorColor: scheme.secondary,
          tabs: [for (final LibraryTab tab in _tabs) Tab(text: tab.label)],
        ),
      ),
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _controller,
          children: [for (final LibraryTab tab in _tabs) _KeepAlive(child: _body(tab))],
        ),
      ),
    );
  }
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

/// History keeps its own screen. This tab opens it, so the list and its Clear action stay in one place.
class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return GlintState(
      kind: GlintStateKind.empty,
      title: 'Wallpaper history',
      body: 'The wallpapers you set, so you can set them again.',
      actionLabel: 'Open history',
      onAction: () => context.router.push(const WallpaperHistoryRoute()),
    );
  }
}
