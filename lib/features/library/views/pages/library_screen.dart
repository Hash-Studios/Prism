import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/features/favourite_walls/views/widgets/fav_grid.dart';
import 'package:Prism/features/folders/folders.dart';
import 'package:Prism/features/library/views/widgets/offline_chip.dart';
import 'package:Prism/features/library/views/widgets/recently_set_row.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/download_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

enum LibraryTab {
  favourites,
  downloads,
  history;

  String label(AppLocalizations l10n) => switch (this) {
    LibraryTab.favourites => l10n.wallpaperLibraryFavourites,
    LibraryTab.downloads => l10n.wallpaperLibraryDownloads,
    LibraryTab.history => l10n.wallpaperLibraryHistory,
  };
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
  static const TextStyle _tabLabelStyle = TextStyle(
    fontFamily: PrismFonts.proximaNova,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  late final List<LibraryTab> _tabs = <LibraryTab>[
    LibraryTab.favourites,
    LibraryTab.downloads,
    if (!hideSetWallpaperUi) LibraryTab.history,
  ];
  late final TabController _controller;
  Object? _tabRequest;
  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabRequest = _routeTabRequest;
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
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Object? request = _routeTabRequest;
    final bool newRequest = !identical(_tabRequest, request);
    _tabRequest = request;
    if (oldWidget.initialTab == widget.initialTab && !newRequest) return;
    final int requested = _tabs.indexOf(widget.initialTab);
    _lastIndex = requested < 0 ? 0 : requested;
    _controller.index = _lastIndex;
  }

  // Typed navigation creates fresh args even for the same tab; rebuilds and push/pop retain them.
  Object? get _routeTabRequest => context.findAncestorWidgetOfExactType<RouteDataScope>()?.routeData.args;

  @override
  void dispose() {
    _controller
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  Widget _body(LibraryTab tab) => switch (tab) {
    LibraryTab.favourites => FavouriteGrid(
      header: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[const FoldersRow(), if (!hideSetWallpaperUi) const RecentlySetRow()],
      ),
    ),
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
        title: Text(
          context.l10n.wallpaperLibraryTitle,
          style: theme.textTheme.displaySmall?.copyWith(color: scheme.secondary),
        ),
        actions: const [OfflineChip(), SizedBox(width: 12)],
        bottom: _ClampedTabBar(
          TabBar(
            controller: _controller,
            labelColor: prismReadableInk(theme),
            unselectedLabelColor: prismSoftInk(theme),
            labelStyle: _tabLabelStyle,
            unselectedLabelStyle: _tabLabelStyle,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            indicatorColor: prismReadableInk(theme),
            dividerColor: scheme.secondary.withValues(alpha: 0.08),
            tabs: [for (final LibraryTab tab in _tabs) Tab(text: tab.label(context.l10n))],
          ),
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

/// History keeps its own screen. This tab opens it, so the list and its Clear action stay in one place.
class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return GlintState(
      kind: GlintStateKind.empty,
      title: context.l10n.wallpaperLibraryHistoryTitle,
      body: context.l10n.wallpaperLibraryHistoryBody,
      actionLabel: context.l10n.wallpaperLibraryOpenHistory,
      onAction: () => context.router.push(const WallpaperHistoryRoute()),
    );
  }
}
