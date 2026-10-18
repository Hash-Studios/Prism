import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_loading_more.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_wall_tile.dart';
import 'package:Prism/features/prism_feed/biz/bloc/paged_feed_bloc.j.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The wallpapers of one home tab (Latest, Following or Popular) as slivers.
class PagedChipSliver extends StatelessWidget {
  const PagedChipSliver({
    super.key,
    required this.bloc,
    required this.failureTitle,
    required this.emptyTitle,
    required this.crossAxisCount,
    required this.tileMemCacheHeight,
    this.emptyBody,
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  final PagedFeedBloc bloc;
  final String failureTitle;
  final String emptyTitle;
  final String? emptyBody;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final int crossAxisCount;
  final int tileMemCacheHeight;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PagedFeedBloc, PagedFeedState>(
      bloc: bloc,
      builder: (context, state) {
        if (state.items.isEmpty) {
          if (state.status == LoadStatus.initial || state.status == LoadStatus.loading) {
            return const SliverToBoxAdapter(child: LoadingCards(useFeedLayout: true));
          }
          if (state.status == LoadStatus.failure) {
            return SliverToBoxAdapter(
              child: GlintState(
                kind: GlintStateKind.error,
                title: failureTitle,
                body: 'Check your connection and try again.',
                actionLabel: 'Try again',
                onAction: () => bloc.add(const PagedFeedEvent.refreshRequested()),
              ),
            );
          }
          return SliverToBoxAdapter(
            child: GlintState(
              kind: GlintStateKind.empty,
              title: emptyTitle,
              body: emptyBody,
              actionLabel: emptyActionLabel,
              onAction: onEmptyAction,
            ),
          );
        }
        return SliverMainAxisGroup(
          slivers: <Widget>[
            SliverPadding(
              padding: PrismFeedLayout.gridPadding,
              sliver: SliverGrid(
                gridDelegate: PrismWallGrid.delegate(
                  context,
                  columns: crossAxisCount,
                  spacing: PrismFeedLayout.gridSpacing,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final FeedItemEntity item = state.items[index];
                  return KeyedSubtree(
                    key: ValueKey<String>(item.id),
                    child: FeedWallTile(
                      item: item,
                      index: index,
                      crossAxisCount: crossAxisCount,
                      memCacheHeight: tileMemCacheHeight,
                    ),
                  );
                }, childCount: state.items.length),
              ),
            ),
            SliverToBoxAdapter(child: _footer(state)),
            const SliverToBoxAdapter(child: SizedBox(height: PrismSpace.bottomBarClearance)),
          ],
        );
      },
    );
  }

  Widget _footer(PagedFeedState state) {
    if (state.actionStatus == ActionStatus.failure && !state.isFetchingMore) {
      return Padding(
        padding: const EdgeInsets.all(PrismSpace.md),
        child: Center(
          child: PrismButton(
            label: "Couldn't load more. Try again",
            variant: PrismButtonVariant.ghost,
            size: PrismButtonSize.compact,
            onPressed: () {
              bloc.add(const PagedFeedEvent.fetchMoreRequested());
            },
          ),
        ),
      );
    }
    if (state.isFetchingMore) {
      return FeedLoadingMore(columns: crossAxisCount);
    }
    return const SizedBox(height: PrismFeedLayout.endOfPageSpacerHeight);
  }
}
