import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/features/folders/views/folders_access.dart';
import 'package:Prism/features/folders/views/widgets/folder_card.dart';
import 'package:Prism/features/folders/views/widgets/smart_folder_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Library's Folders tab: a grid of the user's folders with their covers, names and counts.
class FoldersGrid extends StatefulWidget {
  const FoldersGrid({super.key});

  /// A folder card is at most this wide, so a tablet gets more columns instead of huge covers.
  static const double maxCardWidth = 200;

  @override
  State<FoldersGrid> createState() => _FoldersGridState();
}

class _FoldersGridState extends State<FoldersGrid> {
  List<PublicFolderEntity> _followed = const <PublicFolderEntity>[];
  String _followedUserId = '';
  String _requestedFollowedUserId = '';
  int _followedRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    if (context.read<FoldersBloc?>() != null) unawaited(ensureFoldersLoaded(context));
    unawaited(_loadFollowed());
  }

  /// The public folders the user follows. A failed read keeps the last list: the section is extra.
  Future<void> _loadFollowed() async {
    final String userId = app_state.prismUser.id;
    if (userId.isEmpty) {
      _followedRequestVersion++;
      _requestedFollowedUserId = '';
      if (mounted) setState(() => _followedUserId = '');
      return;
    }
    if (!getIt.isRegistered<PublicFoldersRepository>()) return;
    _requestedFollowedUserId = userId;
    final int requestVersion = ++_followedRequestVersion;
    final Result<List<PublicFolderEntity>> result = await getIt<PublicFoldersRepository>().fetchFollowedFolders(userId);
    if (mounted && requestVersion == _followedRequestVersion && result.isSuccess && app_state.prismUser.id == userId) {
      setState(() {
        _followed = result.data!;
        _followedUserId = userId;
      });
    }
  }

  Future<void> _open(String folderId) async {
    PrismHaptics.tap();
    await context.router.push(FolderRoute(folderId: folderId));
    // The user may have followed or unfollowed on the folder page.
    await _loadFollowed();
  }

  /// Keeps a message scrollable, like the other Library tabs.
  Widget _message(Widget child) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(child: child),
      ),
    ),
  );

  /// The height one line of [style] takes at the current text size, as a [Text] here would draw it.
  static double _lineHeight(BuildContext context, TextStyle style) {
    final double? lineHeight = MediaQuery.maybeLineHeightScaleFactorOverrideOf(context);
    final TextPainter painter = TextPainter(
      text: TextSpan(style: DefaultTextStyle.of(context).style.merge(style).merge(TextStyle(height: lineHeight))),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    final double height = painter.preferredLineHeight;
    painter.dispose();
    return height;
  }

  Widget _grid(
    BuildContext context, {
    required int itemCount,
    required Widget Function(int, double) card,
    List<FolderEntity> shared = const <FolderEntity>[],
    List<PublicFolderEntity> followed = const <PublicFolderEntity>[],
  }) {
    final double textHeight =
        _lineHeight(context, PrismTextStyles.rowTitle(context)) +
        _lineHeight(context, PrismTextStyles.caption(context));
    return LayoutBuilder(
      builder: (context, constraints) {
        const double gap = PrismSpace.sm;
        final double inner = constraints.maxWidth - 2 * PrismWallGrid.margin;
        final int columns = math.max(2, ((inner + gap) / (FoldersGrid.maxCardWidth + gap)).ceil());
        final double cardWidth = (inner - gap * (columns - 1)) / columns;
        Widget section(int count, Widget Function(int) build) => SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: PrismWallGrid.margin),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: gap,
              mainAxisSpacing: PrismSpace.md,
              mainAxisExtent: cardWidth + PrismSpace.xs + textHeight,
            ),
            itemCount: count,
            itemBuilder: (context, index) => build(index),
          ),
        );
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            const SliverToBoxAdapter(child: SizedBox(height: PrismSpace.sm)),
            section(itemCount, (index) => card(index, cardWidth)),
            if (shared.isNotEmpty) ...<Widget>[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: PrismWallGrid.margin),
                sliver: SliverToBoxAdapter(child: PrismSectionHeader(title: context.l10n.foldersSharedWithYou)),
              ),
              section(shared.length, (index) {
                final FolderEntity folder = shared[index];
                return FolderCard(
                  key: ValueKey<String>('shared:${folder.id}'),
                  name: folder.name,
                  covers: folder.covers,
                  itemCount: folder.itemCount,
                  coverSize: cardWidth,
                  markShared: true,
                  onTap: () => unawaited(_open(folder.id)),
                );
              }),
            ],
            if (followed.isNotEmpty) ...<Widget>[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: PrismWallGrid.margin),
                sliver: SliverToBoxAdapter(child: PrismSectionHeader(title: context.l10n.foldersYouFollow)),
              ),
              section(followed.length, (index) {
                final PublicFolderEntity folder = followed[index];
                return FolderCard(
                  key: ValueKey<String>('followed:${folder.id}'),
                  name: folder.name,
                  covers: folder.covers,
                  itemCount: folder.itemCount,
                  coverSize: cardWidth,
                  onTap: () => unawaited(_open(folder.id)),
                );
              }),
            ],
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + PrismSpace.xl)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final FoldersBloc? bloc = context.read<FoldersBloc?>();
    final AppLocalizations l10n = context.l10n;
    if (app_state.prismUser.id.isEmpty) {
      _followedRequestVersion++;
      _requestedFollowedUserId = '';
      return _message(SignInPrompt(feature: l10n.foldersSignInFeature));
    }
    if (bloc == null) return const SizedBox.shrink();
    return BlocBuilder<FoldersBloc, FoldersState>(
      bloc: bloc,
      builder: (context, state) {
        if (app_state.prismUser.id.isEmpty) {
          _followedRequestVersion++;
          _requestedFollowedUserId = '';
          return _message(SignInPrompt(feature: l10n.foldersSignInFeature));
        }
        if (state.userId == app_state.prismUser.id &&
            state.userId.isNotEmpty &&
            getIt.isRegistered<PublicFoldersRepository>() &&
            _requestedFollowedUserId != state.userId) {
          _requestedFollowedUserId = state.userId;
          scheduleMicrotask(_loadFollowed);
        }
        // Until the bloc reloads for a new account, it still holds the last account's folders.
        final bool otherAccount = state.userId != app_state.prismUser.id;
        final List<PublicFolderEntity> followed = _followedUserId == app_state.prismUser.id
            ? _followed
            : const <PublicFolderEntity>[];
        final bool loading = state.status == LoadStatus.initial || state.status == LoadStatus.loading;
        if (otherAccount || (state.folders.isEmpty && loading)) {
          return IgnorePointer(
            child: _grid(
              context,
              itemCount: 4,
              card: (_, width) => Align(
                alignment: Alignment.topCenter,
                child: PrismBone(width: width, height: width, radius: PrismRadius.sm),
              ),
            ),
          );
        }
        if (state.status == LoadStatus.failure) {
          return _message(
            GlintState(
              kind: GlintStateKind.error,
              title: l10n.foldersLoadAllError,
              body: l10n.wallpaperCheckConnection,
              actionLabel: l10n.wallpaperTryAgain,
              onAction: () => unawaited(ensureFoldersLoaded(context)),
            ),
          );
        }
        final List<FolderEntity> owned = state.folders.where((folder) => folder.isOwnedBy(state.userId)).toList();
        final List<FolderEntity> shared = state.folders.where((folder) => !folder.isOwnedBy(state.userId)).toList();
        if (owned.isEmpty && shared.isEmpty && followed.isEmpty) {
          return _message(
            GlintState(
              kind: GlintStateKind.empty,
              title: l10n.foldersLibraryEmptyTitle,
              body: l10n.foldersLibraryEmptyBody,
              actionLabel: l10n.foldersNewFolder,
              onAction: () => unawaited(createFolderFromLibrary(context)),
            ),
          );
        }
        return _grid(
          context,
          itemCount: owned.length + 2,
          shared: shared,
          followed: followed,
          card: (index, width) {
            if (index == 0) {
              return _NewFolderTile(size: width, onTap: () => unawaited(createFolderFromLibrary(context)));
            }
            if (index == 1) {
              return _NewFolderTile(size: width, smart: true, onTap: () => unawaited(showSmartFolderSheet(context)));
            }
            final FolderEntity folder = owned[index - 2];
            return FolderCard(
              key: ValueKey<String>(folder.id),
              name: folder.name,
              covers: folder.covers,
              itemCount: folder.itemCount,
              coverSize: width,
              markPublic: folder.isPublic,
              markShared: folder.editors.isNotEmpty,
              markSmart: folder.isSmart,
              onTap: () => unawaited(_open(folder.id)),
            );
          },
        );
      },
    );
  }
}

/// The first tiles of the owner's folders: a dashed-look square that starts a new folder or a new smart folder.
class _NewFolderTile extends StatelessWidget {
  const _NewFolderTile({required this.size, required this.onTap, this.smart = false});

  final double size;
  final VoidCallback onTap;
  final bool smart;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String label = smart ? context.l10n.foldersSmartNew : context.l10n.foldersNewFolder;
    return PressScale(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          key: ValueKey<String>(smart ? 'folders-new-smart-folder-tile' : 'folders-new-folder-tile'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(PrismRadius.sm),
                  border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
                ),
                child: Icon(smart ? Icons.auto_awesome_rounded : Icons.add_rounded, size: 32, color: cs.onSurface),
              ),
              const SizedBox(height: PrismSpace.xs),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: PrismTextStyles.rowTitle(context)),
            ],
          ),
        ),
      ),
    );
  }
}
