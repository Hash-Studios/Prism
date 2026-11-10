import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/generated/analytics_events.g.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/content_report/content_report_sheet.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/folders/biz/folder_discover_cubit.dart';
import 'package:Prism/features/folders/domain/entities/discover_folder.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/features/folders/views/widgets/folder_cover.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum _CardAction { report }

/// One public folder to discover: the 2x2 cover, the name, the owner, the wall count, Follow and a Report menu.
/// It reads and changes the follow state through the [FolderDiscoverCubit] above it.
class DiscoverFolderCard extends StatelessWidget {
  const DiscoverFolderCard({super.key, required this.folder, required this.tab, required this.width});

  final DiscoverFolder folder;

  /// The tab the card is on, for analytics.
  final FolderDiscoverTab tab;
  final double width;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String owner = folder.ownerName.isEmpty ? '' : l10n.foldersByOwner(folder.ownerName);
    final String count = l10n.foldersItemCount(folder.itemCount);
    final Widget menu = PopupMenuButton<_CardAction>(
      tooltip: l10n.foldersMoreOptions,
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (_) => unawaited(_report(context)),
      itemBuilder: (_) => <PopupMenuEntry<_CardAction>>[
        PopupMenuItem<_CardAction>(value: _CardAction.report, child: Text(l10n.foldersReport)),
      ],
    );
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PressScale(
            child: Semantics(
              button: true,
              label: folder.name,
              value: <String>[if (owner.isNotEmpty) owner, count].join(', '),
              excludeSemantics: true,
              onTap: () => _open(context),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _open(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    FolderCover(covers: folder.covers, size: width, radius: PrismRadius.md),
                    const SizedBox(height: PrismSpace.xs),
                    Text(
                      folder.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PrismTextStyles.rowTitle(context),
                    ),
                    if (owner.isNotEmpty)
                      Text(
                        owner,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PrismTextStyles.caption(context),
                      ),
                    Text(count, maxLines: 1, overflow: TextOverflow.ellipsis, style: PrismTextStyles.caption(context)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: PrismSpace.xs),
          // At large text sizes "Following" needs the whole width, so the menu moves under the button.
          if (MediaQuery.textScalerOf(context).scale(1) > 1.4)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _FollowButton(folder: folder, tab: tab),
                Align(alignment: AlignmentDirectional.centerEnd, child: menu),
              ],
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: _FollowButton(folder: folder, tab: tab),
                ),
                menu,
              ],
            ),
        ],
      ),
    );
  }

  void _open(BuildContext context) {
    PrismHaptics.tap();
    context.router.push(FolderRoute(folderId: folder.id));
  }

  Future<void> _report(BuildContext context) async {
    final FolderDiscoverCubit cubit = context.read<FolderDiscoverCubit>();
    final BuildContext reportContext = ModalRoute.of(context)?.subtreeContext ?? context;
    if (!await requireSignedInAction(reportContext) || !reportContext.mounted || cubit.isClosed) return;
    await showContentReportSheet(
      reportContext,
      contentType: 'folder',
      targetFirestoreDocId: folder.id,
      onSubmitted: () {
        analytics.track(const FolderReportedEvent(source: 'discover'));
        if (!cubit.isClosed) cubit.hideReported(folder.id);
      },
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.folder, required this.tab});

  final DiscoverFolder folder;
  final FolderDiscoverTab tab;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool following = context.select<FolderDiscoverCubit, bool>((c) => c.state.followed.contains(folder.id));
    Future<void> onTap() async {
      final FolderDiscoverCubit cubit = context.read<FolderDiscoverCubit>();
      if (!await requireSignedInAction(context)) return;
      final PublicFolderFailure? failure = await cubit.toggleFollow(folder);
      if (failure != null) {
        toasts.error(l10n.foldersFollowFailed);
      } else if (!following) {
        analytics.track(FolderDiscoverFollowedEvent(tab: tab.wire));
      }
    }

    // excludeSemantics drops the button's own tap action, so the wrapper carries it for screen readers.
    return Semantics(
      button: true,
      label: following ? l10n.foldersDiscoverUnfollowNamed(folder.name) : l10n.foldersDiscoverFollowNamed(folder.name),
      excludeSemantics: true,
      onTap: onTap,
      child: PrismButton(
        label: following ? l10n.foldersFollowing : l10n.foldersFollow,
        variant: following ? PrismButtonVariant.ghost : PrismButtonVariant.tonal,
        size: PrismButtonSize.compact,
        expand: true,
        onPressed: onTap,
      ),
    );
  }
}

/// "Folders to follow" in Search: the first trending folders, or the new ones when nothing trends yet. It hides
/// while both lists are empty.
class FoldersDiscoverSection extends StatelessWidget {
  const FoldersDiscoverSection({super.key});

  static const int rowSize = 10;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FolderDiscoverCubit>(
      create: (_) => getIt<FolderDiscoverCubit>()..load(),
      child: BlocBuilder<FolderDiscoverCubit, FolderDiscoverState>(
        builder: (context, state) {
          final bool trending = state.lists.trending.isNotEmpty;
          final List<DiscoverFolder> row = (trending ? state.lists.trending : state.lists.fresh)
              .take(rowSize)
              .toList(growable: false);
          if (state.status != FolderDiscoverStatus.ready || row.isEmpty) return const SizedBox.shrink();
          final double width = (MediaQuery.sizeOf(context).width * 0.42).clamp(140, 200).toDouble();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.6,
                child: PrismSectionHeader(
                  title: context.l10n.foldersDiscoverSectionTitle,
                  actionLabel: context.l10n.creatorsSeeAll,
                  onAction: () => context.router.push(FoldersDiscoverRoute()),
                  padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xl, PrismSpace.page, PrismSpace.sm),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: PrismSpace.pageInsets,
                clipBehavior: Clip.none,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final (int i, DiscoverFolder folder) in row.indexed) ...<Widget>[
                      if (i > 0) const SizedBox(width: PrismSpace.sm),
                      DiscoverFolderCard(
                        folder: folder,
                        tab: trending ? FolderDiscoverTab.trending : FolderDiscoverTab.fresh,
                        width: width,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
