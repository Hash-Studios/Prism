import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/views/folders_access.dart';
import 'package:Prism/features/folders/views/widgets/folder_cover.dart';
import 'package:Prism/features/folders/views/widgets/folder_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Library's row of folder cards, with a New folder card first. Guests do not see it.
class FoldersRow extends StatefulWidget {
  const FoldersRow({super.key});

  static const double cardSize = 112;

  @override
  State<FoldersRow> createState() => _FoldersRowState();
}

class _FoldersRowState extends State<FoldersRow> {
  @override
  void initState() {
    super.initState();
    unawaited(ensureFoldersLoaded(context));
  }

  Future<void> _create() async {
    final FoldersBloc bloc = context.read<FoldersBloc>();
    final String ownerId = app_state.prismUser.id;
    final AppLocalizations l10n = context.l10n;
    final String? name = await showFolderNameSheet(
      context,
      title: l10n.foldersNewFolder,
      actionLabel: l10n.foldersCreate,
    );
    if (name == null || !mounted || app_state.prismUser.id != ownerId || bloc.state.userId != ownerId) return;
    final bool ok = await bloc.run((id) => FoldersEvent.createRequested(name: name, operationId: id));
    if (!ok) {
      toasts.error(l10n.foldersUpdateFailed);
      return;
    }
    unawaited(analytics.track(const FolderCreatedEvent(source: 'library', withWall: false)));
  }

  void _open(FolderEntity folder) {
    PrismHaptics.tap();
    unawaited(context.router.push(FolderRoute(folderId: folder.id)));
  }

  @override
  Widget build(BuildContext context) {
    final FoldersBloc? bloc = context.read<FoldersBloc?>();
    if (bloc == null) return const SizedBox.shrink();
    return BlocBuilder<FoldersBloc, FoldersState>(
      bloc: bloc,
      builder: (context, state) {
        if (app_state.prismUser.id.isEmpty) return const SizedBox.shrink();
        final AppLocalizations l10n = context.l10n;
        final bool loading = state.status == LoadStatus.initial || state.status == LoadStatus.loading;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PrismSectionHeader(
              title: l10n.foldersTitle,
              small: true,
              padding: const EdgeInsets.fromLTRB(
                PrismWallGrid.margin,
                PrismSpace.sm,
                PrismWallGrid.margin,
                PrismSpace.xs,
              ),
            ),
            SizedBox(
              // Room for the name and count lines at the current text size.
              height: FoldersRow.cardSize + PrismSpace.xs + MediaQuery.textScalerOf(context).scale(48),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: PrismWallGrid.margin),
                children: <Widget>[
                  _Card(
                    key: const ValueKey<String>('folders-new'),
                    title: l10n.foldersNewFolder,
                    cover: const _NewFolderTile(size: FoldersRow.cardSize),
                    onTap: () => unawaited(_create()),
                  ),
                  if (loading && state.folders.isEmpty)
                    for (int i = 0; i < 2; i++) ...<Widget>[
                      const SizedBox(width: PrismSpace.sm),
                      const PrismBone(width: FoldersRow.cardSize, height: FoldersRow.cardSize, radius: PrismRadius.sm),
                    ]
                  else if (state.status == LoadStatus.failure)
                    Padding(
                      padding: const EdgeInsets.only(left: PrismSpace.md),
                      child: SizedBox(
                        width: 180,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(l10n.foldersLoadError, style: PrismTextStyles.body(context)),
                            PrismButton(
                              label: l10n.wallpaperTryAgain,
                              onPressed: () => unawaited(ensureFoldersLoaded(context)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (state.folders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: PrismSpace.md, top: PrismSpace.xl),
                      child: SizedBox(
                        width: 180,
                        child: Text(l10n.foldersNoFolders, style: PrismTextStyles.body(context)),
                      ),
                    ),
                  for (final FolderEntity folder in state.folders) ...<Widget>[
                    const SizedBox(width: PrismSpace.sm),
                    _Card(
                      key: ValueKey<String>(folder.id),
                      title: folder.name,
                      subtitle: l10n.foldersItemCount(folder.itemCount),
                      cover: FolderCover(covers: folder.covers, size: FoldersRow.cardSize),
                      onTap: () => _open(folder),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({super.key, required this.title, required this.cover, required this.onTap, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget cover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: Semantics(
        button: true,
        label: title,
        value: subtitle,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: FoldersRow.cardSize,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                cover,
                const SizedBox(height: PrismSpace.xs),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: PrismTextStyles.rowTitle(context)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PrismTextStyles.caption(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewFolderTile extends StatelessWidget {
  const _NewFolderTile({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PrismRadius.sm),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.16), width: 1.5),
      ),
      child: Icon(Icons.add_rounded, size: 32, color: cs.primary),
    );
  }
}
