import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_wallpaper_card.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_loading_more.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_wall_tile.dart';
import 'package:Prism/features/prism_feed/biz/bloc/paged_feed_bloc.j.dart';
import 'package:Prism/l10n/l10n.dart';
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
    this.showAi = true,
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
  final bool showAi;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PagedFeedBloc, PagedFeedState>(
      bloc: bloc,
      builder: (context, state) {
        final List<FeedItemEntity> items = AiContentFilter.filterFeedItems(state.items, showAi: showAi);
        if (items.isEmpty) {
          if (state.status == LoadStatus.initial || state.status == LoadStatus.loading) {
            return const SliverToBoxAdapter(child: LoadingCards(useFeedLayout: true));
          }
          if (state.status == LoadStatus.failure) {
            return SliverToBoxAdapter(
              child: GlintState(
                kind: GlintStateKind.error,
                title: failureTitle,
                body: context.l10n.wallpaperCheckConnection,
                actionLabel: context.l10n.wallpaperTryAgain,
                onAction: () => bloc.add(const PagedFeedEvent.refreshRequested()),
              ),
            );
          }
          if (state.status == LoadStatus.success && state.hasMore) {
            if (state.isFetchingMore) {
              return SliverToBoxAdapter(child: FeedLoadingMore(columns: crossAxisCount));
            }
            if (state.actionStatus == ActionStatus.failure && !state.isFetchingMore) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(PrismSpace.md),
                  child: Center(
                    child: PrismButton(
                      label: context.l10n.wallpaperFeedLoadMoreError,
                      variant: PrismButtonVariant.ghost,
                      size: PrismButtonSize.compact,
                      onPressed: () => bloc.add(const PagedFeedEvent.fetchMoreRequested()),
                    ),
                  ),
                ),
              );
            }
            return SliverToBoxAdapter(
              child: GlintState(
                kind: GlintStateKind.empty,
                title: emptyTitle,
                body: emptyBody,
                actionLabel: context.l10n.wallpaperTryAgain,
                onAction: () => bloc.add(const PagedFeedEvent.fetchMoreRequested()),
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
                  footerHeight: favouriteFooterHeight,
                  columns: crossAxisCount,
                  spacing: PrismFeedLayout.gridSpacing,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final FeedItemEntity item = items[index];
                  return KeyedSubtree(
                    key: ValueKey<String>(item.id),
                    child: FeedWallTile(
                      item: item,
                      index: index,
                      crossAxisCount: crossAxisCount,
                      memCacheHeight: tileMemCacheHeight,
                      feed: items,
                    ),
                  );
                }, childCount: items.length),
              ),
            ),
            SliverToBoxAdapter(child: _footer(context, state)),
            const SliverToBoxAdapter(child: SizedBox(height: PrismSpace.bottomBarClearance)),
          ],
        );
      },
    );
  }

  Widget _footer(BuildContext context, PagedFeedState state) {
    if (state.actionStatus == ActionStatus.failure && !state.isFetchingMore) {
      return Padding(
        padding: const EdgeInsets.all(PrismSpace.md),
        child: Center(
          child: PrismButton(
            label: context.l10n.wallpaperFeedLoadMoreError,
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
