import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_carousel.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_wall_tile.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PersonalizedFeedScreen extends StatefulWidget {
  const PersonalizedFeedScreen({super.key, this.onTuneTap});

  final VoidCallback? onTuneTap;

  @override
  State<PersonalizedFeedScreen> createState() => _PersonalizedFeedScreenState();
}

class _PersonalizedFeedScreenState extends State<PersonalizedFeedScreen> with AutomaticKeepAliveClientMixin {
  static const int _carouselPreviewCount = PrismFeedLayout.carouselPreviewCount;

  late final PersonalizedFeedBloc _bloc;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<PersonalizedFeedBloc>();
    personalizedFeedSettingsRevision.addListener(_onFeedSettingsChanged);
    _bloc.add(const PersonalizedFeedEvent.started());
  }

  void _onFeedSettingsChanged() {
    if (mounted) {
      _bloc.add(const PersonalizedFeedEvent.refreshRequested());
    }
  }

  @override
  void dispose() {
    personalizedFeedSettingsRevision.removeListener(_onFeedSettingsChanged);
    _scrollController.dispose();
    _bloc.close();
    super.dispose();
  }

  void _refresh() => _bloc.add(const PersonalizedFeedEvent.refreshRequested());

  void _maybeFetchMore(PersonalizedFeedBloc bloc, ScrollMetrics metrics) {
    if (metrics.maxScrollExtent <= 0) {
      return;
    }
    final state = bloc.state;
    if (state.isFetchingMore || !state.hasMore || state.status == LoadStatus.loading) {
      return;
    }

    if (metrics.pixels >= metrics.maxScrollExtent - PrismFeedLayout.prefetchThreshold) {
      bloc.add(const PersonalizedFeedEvent.fetchMoreRequested());
    }
  }

  Future<void> _showTileActions(FeedItemEntity item) async {
    HapticFeedback.mediumImpact();
    final bool? lessLikeThis = await showPrismSheet<bool>(
      context: context,
      builder: (BuildContext sheetContext) => PrismSheetBody(
        child: PrismRow(
          icon: Icons.visibility_off_rounded,
          title: 'Show less like this',
          subtitle: "You'll see fewer walls like this.",
          padding: EdgeInsets.zero,
          onTap: () => Navigator.of(sheetContext).pop(true),
        ),
      ),
    );
    if (lessLikeThis != true || !mounted) {
      return;
    }
    _bloc.add(PersonalizedFeedEvent.lessLikeThisRequested(item));
    toasts.success("Got it. You'll see fewer like this.");
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<PersonalizedFeedBloc, PersonalizedFeedState>(
        buildWhen: (prev, curr) =>
            prev.status != curr.status ||
            prev.items.length != curr.items.length ||
            prev.isFetchingMore != curr.isFetchingMore ||
            prev.hasMore != curr.hasMore,
        builder: (context, state) {
          final bloc = context.read<PersonalizedFeedBloc>();
          if (state.status == LoadStatus.initial || (state.status == LoadStatus.loading && state.items.isEmpty)) {
            return const _FeedSkeleton();
          }

          if (state.status == LoadStatus.failure && state.items.isEmpty) {
            return _refreshable(
              ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: <Widget>[
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.6,
                    child: GlintState(
                      kind: GlintStateKind.error,
                      title: "Couldn't load your feed",
                      body: 'Check your connection, then try again.',
                      actionLabel: 'Try again',
                      onAction: _refresh,
                    ),
                  ),
                ],
              ),
            );
          }

          final prismItems = state.items.whereType<PrismFeedItem>();
          final previewWalls = prismItems.take(_carouselPreviewCount).toList(growable: false);
          final previewSet = prismItems.take(_carouselPreviewCount).toSet();
          final visibleItems = state.items.where((item) => !previewSet.contains(item)).toList(growable: false);
          final crossAxisCount = wallpaperGridColumns(MediaQuery.sizeOf(context).width);

          return _refreshable(
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.depth == 0) {
                  _maybeFetchMore(bloc, notification.metrics);
                }
                return false;
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(child: FeedCarousel(previewWalls: previewWalls)),
                  SliverToBoxAdapter(child: _ForYouHeader(onTuneTap: widget.onTuneTap)),
                  SliverPadding(
                    padding: PrismWallGrid.padding,
                    sliver: SliverGrid(
                      gridDelegate: PrismWallGrid.delegate(context, columns: crossAxisCount),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => FeedWallTile(
                          item: visibleItems[index],
                          index: index,
                          onLongPress: () => unawaited(_showTileActions(visibleItems[index])),
                        ),
                        childCount: visibleItems.length,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: _bottomState(context, state, crossAxisCount)),
                  const SliverToBoxAdapter(child: SizedBox(height: PrismSpace.bottomBarClearance)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _refreshable(Widget child) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      color: cs.primary,
      backgroundColor: cs.surfaceContainerHigh,
      onRefresh: () async => _refresh(),
      child: child,
    );
  }

  Widget _bottomState(BuildContext context, PersonalizedFeedState state, int columns) {
    if (state.items.isEmpty) {
      return GlintState(
        kind: GlintStateKind.empty,
        title: 'Shape this feed',
        body: 'Follow creators or choose interests so we can surface more of what you like.',
        actionLabel: widget.onTuneTap == null ? null : 'Tune your feed',
        onAction: widget.onTuneTap,
      );
    }

    if (state.isFetchingMore) {
      return PrismSkeleton(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(PrismWallGrid.margin, PrismWallGrid.spacing, PrismWallGrid.margin, 0),
          child: Row(
            children: <Widget>[
              for (int i = 0; i < columns; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: PrismWallGrid.spacing),
                const Expanded(
                  child: AspectRatio(
                    aspectRatio: PrismFeedLayout.gridTileAspectRatio,
                    child: PulseFill(borderRadius: PrismWallGrid.tileRadius),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (state.hasMore) {
      return const SizedBox(height: PrismFeedLayout.endOfPageSpacerHeight);
    }

    return const GlintState(
      kind: GlintStateKind.nothingNew,
      glintSize: 64,
      title: 'You are all caught up',
      body: 'Pull down to refresh. New picks will land here.',
      padding: EdgeInsets.fromLTRB(PrismSpace.xl, PrismSpace.xl, PrismSpace.xl, 0),
    );
  }
}

class _ForYouHeader extends StatelessWidget {
  const _ForYouHeader({required this.onTuneTap});

  final VoidCallback? onTuneTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        PrismWallGrid.margin + 4,
        PrismSpace.lg,
        PrismWallGrid.margin - 4,
        0,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(header: true, child: Text('For you', style: PrismTextStyles.sectionTitle(context))),
          ),
          PrismIconButton(icon: Icons.tune_rounded, tooltip: 'Tune your feed', onPressed: onTuneTap),
        ],
      ),
    );
  }
}

/// The feed while it loads: a card-shaped block for the carousel, a title bone and the wallpaper grid skeleton.
class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: <Widget>[
        PrismSkeleton(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: PrismWallGrid.margin),
                child: PrismBone(height: feedCarouselCardHeight(context), radius: PrismRadius.lg),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(PrismWallGrid.margin + 4, PrismSpace.xl, 0, PrismSpace.sm),
                child: PrismBone(width: 88, height: 20),
              ),
            ],
          ),
        ),
        const LoadingCards(),
      ],
    );
  }
}
