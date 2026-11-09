import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/generated/analytics_events.g.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/folders/biz/folder_discover_cubit.dart';
import 'package:Prism/features/folders/domain/entities/discover_folder.dart';
import 'package:Prism/features/folders/views/widgets/discover_folders.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Public folders to discover, in three tabs: Trending, New and Like your saves.
@RoutePage()
class FoldersDiscoverPage extends StatefulWidget {
  const FoldersDiscoverPage({super.key, this.source = 'search'});

  /// Where the page was opened from, for analytics.
  final String source;

  @override
  State<FoldersDiscoverPage> createState() => _FoldersDiscoverPageState();
}

class _FoldersDiscoverPageState extends State<FoldersDiscoverPage> {
  final FolderDiscoverCubit _cubit = getIt<FolderDiscoverCubit>()..load();
  FolderDiscoverTab _tab = FolderDiscoverTab.trending;

  @override
  void initState() {
    super.initState();
    analytics.track(FolderDiscoverOpenedEvent(tab: _tab.wire, source: widget.source));
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  void _select(FolderDiscoverTab tab) {
    if (tab == _tab) return;
    analytics.track(FolderDiscoverOpenedEvent(tab: tab.wire, source: 'tab'));
    if (tab == FolderDiscoverTab.likeYourSaves) _cubit.loadLikeYourSaves();
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return BlocProvider<FolderDiscoverCubit>.value(
      value: _cubit,
      child: PrismPage(
        title: l10n.foldersDiscoverTitle,
        headerBottom: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: PrismSpace.pageInsets,
          child: Row(
            children: <Widget>[
              for (final (int i, FolderDiscoverTab tab) in FolderDiscoverTab.values.indexed) ...<Widget>[
                if (i > 0) const SizedBox(width: PrismSpace.xs),
                PrismChip(label: _label(l10n, tab), selected: tab == _tab, onTap: () => _select(tab)),
              ],
            ],
          ),
        ),
        body: BlocBuilder<FolderDiscoverCubit, FolderDiscoverState>(
          builder: (context, state) =>
              _Body(state: state, tab: _tab, onSeeTrending: () => _select(FolderDiscoverTab.trending)),
        ),
      ),
    );
  }

  static String _label(AppLocalizations l10n, FolderDiscoverTab tab) => switch (tab) {
    FolderDiscoverTab.trending => l10n.foldersDiscoverTabTrending,
    FolderDiscoverTab.fresh => l10n.foldersDiscoverTabNew,
    FolderDiscoverTab.likeYourSaves => l10n.foldersDiscoverTabLikeYourSaves,
  };
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.tab, required this.onSeeTrending});

  final FolderDiscoverState state;
  final FolderDiscoverTab tab;
  final VoidCallback onSeeTrending;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final FolderDiscoverCubit cubit = context.read<FolderDiscoverCubit>();
    if (state.status == FolderDiscoverStatus.loading) return PrismSkeleton.cards();
    if (state.status == FolderDiscoverStatus.failed) {
      return GlintState(
        kind: GlintStateKind.error,
        title: l10n.foldersDiscoverLoadError,
        actionLabel: l10n.wallpaperTryAgain,
        onAction: cubit.load,
      );
    }
    final List<DiscoverFolder>? folders = switch (tab) {
      FolderDiscoverTab.trending => state.lists.trending,
      FolderDiscoverTab.fresh => state.lists.fresh,
      FolderDiscoverTab.likeYourSaves => state.likeYourSaves,
    };
    if (folders == null) {
      if (state.likeYourSavesFailed) {
        return GlintState(
          kind: GlintStateKind.error,
          title: l10n.foldersDiscoverSavesError,
          actionLabel: l10n.wallpaperTryAgain,
          onAction: cubit.loadLikeYourSaves,
        );
      }
      return PrismSkeleton.cards();
    }
    if (folders.isEmpty) return _empty(l10n);
    return RefreshIndicator(
      onRefresh: cubit.load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final int columns = constraints.maxWidth >= 600 ? 3 : 2;
          final double width = (constraints.maxWidth - 2 * PrismSpace.page - (columns - 1) * PrismSpace.sm) / columns;
          final int rows = (folders.length / columns).ceil();
          // Rows instead of a fixed-height grid, so a card grows with large text and never clips.
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              PrismSpace.page,
              PrismSpace.md,
              PrismSpace.page,
              PrismSpace.bottomBarClearance,
            ),
            itemCount: rows,
            separatorBuilder: (_, _) => const SizedBox(height: PrismSpace.lg),
            itemBuilder: (context, row) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int c = 0; c < columns; c++) ...<Widget>[
                  if (c > 0) const SizedBox(width: PrismSpace.sm),
                  if (row * columns + c < folders.length)
                    DiscoverFolderCard(folder: folders[row * columns + c], tab: tab, width: width)
                  else
                    SizedBox(width: width),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _empty(AppLocalizations l10n) => switch (tab) {
    FolderDiscoverTab.trending => GlintState(
      kind: GlintStateKind.empty,
      title: l10n.foldersDiscoverTrendingEmptyTitle,
      body: l10n.foldersDiscoverTrendingEmptyBody,
    ),
    FolderDiscoverTab.fresh => GlintState(
      kind: GlintStateKind.empty,
      title: l10n.foldersDiscoverNewEmptyTitle,
      body: l10n.foldersDiscoverNewEmptyBody,
      actionLabel: state.lists.trending.isEmpty ? null : l10n.foldersDiscoverSeeTrending,
      onAction: state.lists.trending.isEmpty ? null : onSeeTrending,
    ),
    FolderDiscoverTab.likeYourSaves => GlintState(
      kind: GlintStateKind.empty,
      title: l10n.foldersDiscoverSavesEmptyTitle,
      body: l10n.foldersDiscoverSavesEmptyBody,
      actionLabel: state.lists.trending.isEmpty ? null : l10n.foldersDiscoverSeeTrending,
      onAction: state.lists.trending.isEmpty ? null : onSeeTrending,
    ),
  };
}
