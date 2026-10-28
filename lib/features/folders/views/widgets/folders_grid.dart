import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/views/folders_access.dart';
import 'package:Prism/features/folders/views/widgets/folder_cover.dart';
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
  @override
  void initState() {
    super.initState();
    if (context.read<FoldersBloc?>() != null) unawaited(ensureFoldersLoaded(context));
  }

  void _open(FolderEntity folder) {
    PrismHaptics.tap();
    unawaited(context.router.push(FolderRoute(folderId: folder.id)));
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

  Widget _grid(BuildContext context, {required int itemCount, required Widget Function(int, double) card}) {
    final double textHeight =
        _lineHeight(context, PrismTextStyles.rowTitle(context)) +
        _lineHeight(context, PrismTextStyles.caption(context));
    return LayoutBuilder(
      builder: (context, constraints) {
        const double gap = PrismSpace.sm;
        final double inner = constraints.maxWidth - 2 * PrismWallGrid.margin;
        final int columns = math.max(2, ((inner + gap) / (FoldersGrid.maxCardWidth + gap)).ceil());
        final double cardWidth = (inner - gap * (columns - 1)) / columns;
        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            PrismWallGrid.margin,
            PrismSpace.sm,
            PrismWallGrid.margin,
            MediaQuery.paddingOf(context).bottom + PrismSpace.xl,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: gap,
            mainAxisSpacing: PrismSpace.md,
            mainAxisExtent: cardWidth + PrismSpace.xs + textHeight,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) => card(index, cardWidth),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final FoldersBloc? bloc = context.read<FoldersBloc?>();
    final AppLocalizations l10n = context.l10n;
    if (app_state.prismUser.id.isEmpty) {
      return _message(SignInPrompt(feature: l10n.foldersSignInFeature));
    }
    if (bloc == null) return const SizedBox.shrink();
    return BlocBuilder<FoldersBloc, FoldersState>(
      bloc: bloc,
      builder: (context, state) {
        if (app_state.prismUser.id.isEmpty) return _message(SignInPrompt(feature: l10n.foldersSignInFeature));
        // Until the bloc reloads for a new account, it still holds the last account's folders.
        final bool otherAccount = state.userId != app_state.prismUser.id;
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
        if (state.folders.isEmpty) {
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
          itemCount: state.folders.length,
          card: (index, width) {
            final FolderEntity folder = state.folders[index];
            return _FolderCard(
              key: ValueKey<String>(folder.id),
              folder: folder,
              coverSize: width,
              onTap: () => _open(folder),
            );
          },
        );
      },
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({super.key, required this.folder, required this.coverSize, required this.onTap});

  final FolderEntity folder;
  final double coverSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String count = context.l10n.foldersItemCount(folder.itemCount);
    return PressScale(
      child: Semantics(
        button: true,
        label: folder.name,
        value: count,
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FolderCover(covers: folder.covers, size: coverSize),
              const SizedBox(height: PrismSpace.xs),
              Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: PrismTextStyles.rowTitle(context)),
              Text(count, maxLines: 1, overflow: TextOverflow.ellipsis, style: PrismTextStyles.caption(context)),
            ],
          ),
        ),
      ),
    );
  }
}
