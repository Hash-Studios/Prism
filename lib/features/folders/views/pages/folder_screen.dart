import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/views/folders_access.dart';
import 'package:Prism/features/folders/views/widgets/folder_sheet.dart';
import 'package:Prism/features/library/views/widgets/offline_chip.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_feed.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum _FolderMenuAction { rename, delete }

/// The walls in one of the user's folders. Owner only: the rules refuse anyone else.
@RoutePage()
class FolderScreen extends StatefulWidget {
  const FolderScreen({super.key, @PathParam('folderId') required this.folderId});

  final String folderId;

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  bool _tracked = false;
  String? _loadingKey;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(FolderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The router can reuse this page for another folder, for example a link opened from a folder.
    if (oldWidget.folderId == widget.folderId) return;
    _tracked = false;
    unawaited(_load());
  }

  Future<void> _load() async {
    final FoldersBloc bloc = context.read<FoldersBloc>();
    final String ownerId = app_state.prismUser.id;
    final String folderId = widget.folderId;
    final String key = '$ownerId/$folderId';
    if (ownerId.isEmpty || _loadingKey == key) return;
    _loadingKey = key;
    bool current() =>
        mounted && widget.folderId == folderId && app_state.prismUser.id == ownerId && bloc.state.userId == ownerId;
    try {
      await ensureFoldersLoaded(context);
      if (!current() || bloc.state.status != LoadStatus.success) return;
      await bloc.run((id) => FoldersEvent.folderOpened(folderId: folderId, operationId: id));
      if (!current()) return;
      final FolderEntity? folder = bloc.state.folder(folderId);
      if (_tracked || folder == null) return;
      _tracked = true;
      final bool fromLibrary = context.router.stack.any((route) => route.name == LibraryRoute.name);
      unawaited(
        analytics.track(FolderOpenedEvent(source: fromLibrary ? 'library' : 'link', itemCount: folder.itemCount)),
      );
    } finally {
      if (_loadingKey == key) _loadingKey = null;
    }
  }

  String _heroTag(FavouriteWallEntity wall) => prismHeroTag(this, 0, '${wall.source.name}:${wall.id}');

  void _openWall(BuildContext grid, List<FavouriteWallEntity> walls, int index) {
    PrismHaptics.tap();
    final FavouriteWallEntity wall = walls[index];
    unawaited(
      context.router.push(
        WallpaperDetailRoute(
          entity: wall.toFeedItem(),
          analyticsSurface: AnalyticsSurfaceValue.favouriteWallpaperView,
          heroTag: _heroTag(wall),
          feed: WallpaperFeed(
            grid: grid,
            indexInGrid: (item) {
              final List<FavouriteWallEntity> current =
                  context.read<FoldersBloc>().state.items[widget.folderId] ?? const <FavouriteWallEntity>[];
              return current.indexWhere((candidate) => candidate.id == item.id && candidate.source == item.source);
            },
            tiles: <WallpaperFeedTile>[
              for (final (int i, FavouriteWallEntity w) in walls.indexed)
                if (w is! LegacyFavouriteWall) (item: w.toFeedItem(), index: i, heroTag: _heroTag(w)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _remove(FavouriteWallEntity wall) async {
    PrismHaptics.impact();
    final FoldersBloc bloc = context.read<FoldersBloc>();
    final String ownerId = app_state.prismUser.id;
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showPrismConfirm(
      context,
      title: l10n.foldersRemoveTitle,
      message: l10n.foldersRemoveMessage,
      confirmLabel: l10n.foldersRemoveConfirm,
      destructive: true,
    );
    if (!confirmed || !mounted || app_state.prismUser.id != ownerId || bloc.state.userId != ownerId) return;
    final bool ok = await bloc.run(
      (id) => FoldersEvent.itemRemoved(folderId: widget.folderId, wall: wall, operationId: id),
    );
    ok ? toasts.success(l10n.foldersRemoved) : toasts.error(l10n.foldersUpdateFailed);
  }

  Future<void> _onMenu(_FolderMenuAction action, FolderEntity folder) async {
    final FoldersBloc bloc = context.read<FoldersBloc>();
    final AppLocalizations l10n = context.l10n;
    switch (action) {
      case _FolderMenuAction.rename:
        final String? name = await showFolderNameSheet(
          context,
          title: l10n.foldersRenameTitle,
          actionLabel: l10n.foldersRename,
          initialName: folder.name,
        );
        if (name == null ||
            name == folder.name ||
            !mounted ||
            app_state.prismUser.id != folder.ownerId ||
            bloc.state.userId != folder.ownerId) {
          return;
        }
        final bool ok = await bloc.run(
          (id) => FoldersEvent.renameRequested(folderId: folder.id, name: name, operationId: id),
        );
        if (!ok) toasts.error(l10n.foldersUpdateFailed);
      case _FolderMenuAction.delete:
        final bool confirmed = await showPrismConfirm(
          context,
          title: l10n.foldersDeleteTitle(folder.name),
          message: l10n.foldersDeleteMessage,
          confirmLabel: l10n.foldersDeleteConfirm,
          destructive: true,
        );
        if (!confirmed || !mounted || app_state.prismUser.id != folder.ownerId || bloc.state.userId != folder.ownerId) {
          return;
        }
        final StackRouter router = context.router;
        final bool ok = await bloc.run((id) => FoldersEvent.deleteRequested(folderId: folder.id, operationId: id));
        if (!ok) {
          toasts.error(l10n.foldersUpdateFailed);
          return;
        }
        toasts.success(l10n.foldersDeleted);
        await router.maybePop();
    }
  }

  Widget _body(BuildContext context, FoldersState state, FolderEntity? folder) {
    final AppLocalizations l10n = context.l10n;
    if (app_state.prismUser.id.isEmpty) return SignInPrompt(feature: l10n.foldersSignInFeature);
    if (state.userId != app_state.prismUser.id) return const LoadingCards();
    final LoadStatus? status = state.itemsStatus[widget.folderId];
    final List<FavouriteWallEntity>? walls = state.items[widget.folderId];
    if (state.status == LoadStatus.failure || status == LoadStatus.failure) {
      return GlintState(
        kind: GlintStateKind.error,
        title: l10n.foldersLoadError,
        body: l10n.wallpaperCheckConnection,
        actionLabel: l10n.wallpaperTryAgain,
        onAction: () => unawaited(_load()),
      );
    }
    if (status == LoadStatus.success && (folder == null || walls == null)) {
      return GlintState(
        kind: GlintStateKind.empty,
        title: l10n.foldersNotFoundTitle,
        body: l10n.foldersNotFoundBody,
        actionLabel: l10n.wallpaperBrowseWallpapers,
        onAction: () => context.router.navigate(const DashboardRoute(children: <PageRouteInfo>[HomeTabRoute()])),
      );
    }
    if (walls == null) return const LoadingCards();
    if (walls.isEmpty) {
      return GlintState(
        kind: GlintStateKind.empty,
        title: l10n.foldersEmptyTitle,
        body: l10n.foldersEmptyBody,
        actionLabel: l10n.wallpaperBrowseWallpapers,
        onAction: () => context.router.navigate(const DashboardRoute(children: <PageRouteInfo>[HomeTabRoute()])),
      );
    }
    return GridView.builder(
      padding: PrismWallGrid.padding.copyWith(bottom: MediaQuery.paddingOf(context).bottom + PrismSpace.md),
      gridDelegate: PrismWallGrid.delegate(context),
      itemCount: walls.length,
      itemBuilder: (grid, index) {
        final FavouriteWallEntity wall = walls[index];
        return PrismWallTile(
          key: ValueKey<String>(folderItemKey(wall)),
          url: wall.thumbnailUrl,
          fallbackUrl: wall.source == WallpaperSource.prism ? null : wall.fullUrl,
          heroTag: _heroTag(wall),
          semanticLabel: wallpaperSemanticLabel(wall.authorName, l10n),
          onTap: wall is LegacyFavouriteWall ? null : () => _openWall(grid, walls, index),
          onLongPress: () => unawaited(_remove(wall)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FoldersBloc, FoldersState>(
      listenWhen: (previous, current) =>
          previous.userId != current.userId ||
          (previous.status != current.status && current.status == LoadStatus.success),
      listener: (context, state) {
        if (state.userId.isNotEmpty &&
            state.userId == app_state.prismUser.id &&
            !state.itemsStatus.containsKey(widget.folderId)) {
          unawaited(_load());
        }
      },
      builder: (context, state) {
        final FolderEntity? folder = state.userId == app_state.prismUser.id && state.userId.isNotEmpty
            ? state.folder(widget.folderId)
            : null;
        return PrismPage(
          title: folder?.name ?? context.l10n.foldersTitle,
          maxContentWidth: double.infinity,
          actions: <Widget>[
            const OfflineChip(),
            if (folder != null)
              PopupMenuButton<_FolderMenuAction>(
                tooltip: context.l10n.foldersMoreOptions,
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (action) => unawaited(_onMenu(action, folder)),
                itemBuilder: (context) => <PopupMenuEntry<_FolderMenuAction>>[
                  PopupMenuItem<_FolderMenuAction>(
                    value: _FolderMenuAction.rename,
                    child: Text(context.l10n.foldersRename),
                  ),
                  PopupMenuItem<_FolderMenuAction>(
                    value: _FolderMenuAction.delete,
                    child: Text(
                      context.l10n.foldersDelete,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
              ),
          ],
          body: _body(context, state, folder),
        );
      },
    );
  }
}
