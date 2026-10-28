import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/content_report/content_report_sheet.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/folders/biz/public_folder_cubit.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/features/folders/views/folder_share.dart';
import 'package:Prism/features/moods/views/widgets/wall_ids_grid.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum _PublicFolderMenuAction { report }

/// Someone else's public folder, read-only: the header with the owner, counts, Follow and Share, then the walls.
class PublicFolderView extends StatefulWidget {
  const PublicFolderView({super.key, required this.folderId, this.cubit});

  final String folderId;

  /// For tests. The page makes its own otherwise.
  final PublicFolderCubit? cubit;

  @override
  State<PublicFolderView> createState() => _PublicFolderViewState();
}

class _PublicFolderViewState extends State<PublicFolderView> {
  late final PublicFolderCubit _cubit = widget.cubit ?? getIt<PublicFolderCubit>();
  bool _tracked = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(PublicFolderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folderId == widget.folderId) return;
    _tracked = false;
    unawaited(_load());
  }

  @override
  void dispose() {
    if (widget.cubit == null) unawaited(_cubit.close());
    super.dispose();
  }

  Future<void> _load() async {
    await _cubit.load(widget.folderId, viewerId: app_state.prismUser.id);
    final PublicFolderEntity? folder = _cubit.state.folder;
    if (!mounted || _tracked || _cubit.state.status != PublicFolderStatus.ready || folder == null) return;
    _tracked = true;
    final List<String?> stack = context.router.stack.map((route) => route.name).toList();
    final String source = stack.contains(ProfileRoute.name)
        ? 'profile'
        : stack.contains(LibraryRoute.name)
        ? 'library'
        : 'link';
    unawaited(analytics.track(PublicFolderViewedEvent(source: source, itemCount: folder.itemCount)));
  }

  Future<void> _toggleFollow() async {
    PrismHaptics.tap();
    final AppLocalizations l10n = context.l10n;
    final bool following = !_cubit.state.following;
    final PublicFolderFailure? failure = await _cubit.toggleFollow();
    if (!mounted) return;
    if (failure == null) {
      unawaited(analytics.track(FolderFollowChangedEvent(following: following, source: 'folder_page')));
      return;
    }
    toasts.error(switch (failure.refusal) {
      PublicFolderRefusal.unavailable => l10n.foldersUnavailableTitle,
      PublicFolderRefusal.limit => l10n.foldersLimitRefused,
      _ => l10n.foldersFollowFailed,
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return BlocBuilder<PublicFolderCubit, PublicFolderState>(
      bloc: _cubit,
      builder: (context, state) {
        final PublicFolderEntity? folder = state.folder;
        final bool ready = state.status == PublicFolderStatus.ready && folder != null;
        return PrismPage(
          title: ready ? folder.name : l10n.foldersTitle,
          maxContentWidth: double.infinity,
          actions: <Widget>[
            if (ready)
              PopupMenuButton<_PublicFolderMenuAction>(
                tooltip: l10n.foldersMoreOptions,
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (_) =>
                    unawaited(showContentReportSheet(context, contentType: 'folder', targetFirestoreDocId: folder.id)),
                itemBuilder: (context) => <PopupMenuEntry<_PublicFolderMenuAction>>[
                  PopupMenuItem<_PublicFolderMenuAction>(
                    value: _PublicFolderMenuAction.report,
                    child: Text(l10n.foldersReport),
                  ),
                ],
              ),
          ],
          body: switch (state.status) {
            PublicFolderStatus.loading => const LoadingCards(useFeedLayout: true),
            PublicFolderStatus.unavailable => GlintState(
              kind: GlintStateKind.empty,
              title: l10n.foldersUnavailableTitle,
              body: l10n.foldersUnavailableBody,
              actionLabel: l10n.wallpaperBrowseWallpapers,
              onAction: () => context.router.navigate(const DashboardRoute(children: <PageRouteInfo>[HomeTabRoute()])),
            ),
            PublicFolderStatus.failure => GlintState(
              kind: GlintStateKind.error,
              title: l10n.foldersLoadError,
              body: l10n.wallpaperCheckConnection,
              actionLabel: l10n.wallpaperTryAgain,
              onAction: () => unawaited(_load()),
            ),
            PublicFolderStatus.ready => _ready(context, state, folder!),
          },
        );
      },
    );
  }

  Widget _ready(BuildContext context, PublicFolderState state, PublicFolderEntity folder) {
    final AppLocalizations l10n = context.l10n;
    final Widget header = PublicFolderHeader(
      folder: folder,
      following: state.following,
      followBusy: state.followBusy,
      onFollow: app_state.prismUser.id == folder.ownerId ? null : () => unawaited(_toggleFollow()),
      source: 'folder_page',
    );
    if (state.walls.isEmpty) {
      return ListView(
        children: <Widget>[
          header,
          GlintState(
            kind: GlintStateKind.empty,
            title: l10n.foldersPublicEmptyTitle,
            body: l10n.foldersPublicEmptyBody,
          ),
        ],
      );
    }
    return WallIdsGrid(walls: state.walls, top: header);
  }
}

/// The name of a public folder's owner, read from their public profile. Tapping it opens the profile.
class FolderOwnerLink extends StatelessWidget {
  const FolderOwnerLink({super.key, required this.ownerId, required this.builder});

  final String ownerId;
  final Widget Function(BuildContext context, PublicProfileEntity? owner) builder;

  @override
  Widget build(BuildContext context) {
    if (!getIt.isRegistered<PublicProfileRepository>()) return builder(context, null);
    return StreamBuilder<PublicProfileEntity?>(
      stream: getIt<PublicProfileRepository>().watchProfile(ownerId),
      builder: (context, snapshot) => builder(context, snapshot.data),
    );
  }
}

/// The header of a public folder: owner, counts, and Follow and Share. [onFollow] is null for the owner.
class PublicFolderHeader extends StatelessWidget {
  const PublicFolderHeader({
    super.key,
    required this.folder,
    required this.following,
    required this.source,
    this.followBusy = false,
    this.onFollow,
    this.markPublic = false,
  });

  final PublicFolderEntity folder;
  final bool following;
  final bool followBusy;
  final VoidCallback? onFollow;

  /// Where Share was tapped, for analytics.
  final String source;

  /// Shows the owner that others can see this folder.
  final bool markPublic;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return FolderOwnerLink(
      ownerId: folder.ownerId,
      builder: (context, owner) {
        final String ownerName = (owner?.name.trim().isNotEmpty ?? false)
            ? owner!.name.trim()
            : (owner?.username.trim().isNotEmpty ?? false)
            ? '@${owner!.username.trim()}'
            : l10n.accountCreatorFallback;
        return Padding(
          padding: const EdgeInsets.fromLTRB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                button: true,
                label: l10n.foldersByOwner(ownerName),
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(PrismRadius.pill),
                  onTap: () => unawaited(context.router.push(ProfileRoute(profileIdentifier: folder.ownerId))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: PrismSpace.xxs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        PrismAvatar(url: owner?.profilePhoto, name: ownerName, size: 28),
                        const SizedBox(width: PrismSpace.xs),
                        Flexible(
                          child: Text(
                            l10n.foldersByOwner(ownerName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PrismTextStyles.rowTitle(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: PrismSpace.xs),
              Wrap(
                spacing: PrismSpace.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  if (markPublic) PrismTag(label: l10n.foldersPublic, icon: Icons.public_rounded),
                  Text(
                    '${l10n.foldersItemCount(folder.itemCount)} · ${l10n.foldersFollowerCount(folder.followerCount)}',
                    style: PrismTextStyles.caption(context),
                  ),
                ],
              ),
              const SizedBox(height: PrismSpace.sm),
              Row(
                children: <Widget>[
                  if (onFollow != null) ...<Widget>[
                    AnimatedSwitcher(
                      duration: context.motion(PrismDurations.fast),
                      child: PrismButton(
                        key: ValueKey<bool>(following),
                        label: following ? l10n.foldersFollowing : l10n.foldersFollow,
                        icon: following ? Icons.check_rounded : Icons.add_rounded,
                        variant: following ? PrismButtonVariant.tonal : PrismButtonVariant.primary,
                        size: PrismButtonSize.compact,
                        onPressed: followBusy ? null : onFollow,
                      ),
                    ),
                    const SizedBox(width: PrismSpace.xs),
                  ],
                  PrismIconButton(
                    icon: Icons.ios_share_rounded,
                    tooltip: l10n.foldersShare,
                    filled: true,
                    size: 40,
                    iconSize: 20,
                    onPressed: () => unawaited(shareFolder(context, folder, ownerName: ownerName, source: source)),
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
