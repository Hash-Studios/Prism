import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/widgets/pexels_tile.dart';
import 'package:Prism/features/category_feed/views/widgets/wallhaven_tile.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart';
import 'package:Prism/features/personalized_feed/views/widgets/animated_feed_tile.dart';
import 'package:Prism/features/personalized_feed/views/widgets/decorated_background.dart';
import 'package:Prism/features/personalized_feed/views/widgets/empty_card.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_header.dart';
import 'package:Prism/features/personalized_feed/views/widgets/loading_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PersonalizedFeedScreen extends StatefulWidget {
  const PersonalizedFeedScreen({super.key});

  @override
  State<PersonalizedFeedScreen> createState() => _PersonalizedFeedScreenState();
}

class _PersonalizedFeedScreenState extends State<PersonalizedFeedScreen> {
  late final PersonalizedFeedBloc _bloc;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _bloc = getIt<PersonalizedFeedBloc>();
    _scrollController.addListener(_onScroll);
    _bloc.add(const PersonalizedFeedEvent.started());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _bloc.close();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final state = _bloc.state;
    if (state.isFetchingMore || !state.hasMore || state.status == LoadStatus.loading) {
      return;
    }

    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      _bloc.add(const PersonalizedFeedEvent.fetchMoreRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocConsumer<PersonalizedFeedBloc, PersonalizedFeedState>(
        listener: (_, __) {},
        builder: (context, state) {
          final theme = Theme.of(context);
          final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

          if (state.status == LoadStatus.initial || (state.status == LoadStatus.loading && state.items.isEmpty)) {
            return Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBackground(colorScheme: theme.colorScheme),
                const PersonalizedLoadingGrid(),
              ],
            );
          }

          if (state.status == LoadStatus.failure && state.items.isEmpty) {
            return Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBackground(colorScheme: theme.colorScheme),
                RefreshIndicator(
                  onRefresh: () async => _bloc.add(const PersonalizedFeedEvent.refreshRequested()),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.14)),
                        ),
                        child: Column(
                          children: const [
                            Icon(Icons.wifi_tethering_error_rounded, size: 28),
                            SizedBox(height: 10),
                            Text("Couldn't load your personalized feed."),
                            SizedBox(height: 6),
                            Text('Pull down to retry.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBackground(colorScheme: theme.colorScheme),
              RefreshIndicator(
                onRefresh: () async => _bloc.add(const PersonalizedFeedEvent.refreshRequested()),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    SliverToBoxAdapter(
                      child: AnimatedOpacity(
                        opacity: state.status == LoadStatus.success ? 1 : 0,
                        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                        child: AnimatedSlide(
                          offset: state.status == LoadStatus.success ? Offset.zero : const Offset(0, 0.06),
                          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          child: PersonalizedFeedHeader(
                            prismCount: state.sourcePrism,
                            wallhavenCount: state.sourceWallhaven,
                            pexelsCount: state.sourcePexels,
                            itemCount: state.items.length,
                            isFetchingMore: state.isFetchingMore,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(5, 8, 5, 4),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
                          childAspectRatio: 0.6625,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = state.items[index];
                          final tile = switch (item) {
                            PrismFeedItem prism => WallpaperTile(item: prism, index: index),
                            WallhavenFeedItem wallhaven => WallhavenTile(item: wallhaven, index: index),
                            PexelsFeedItem pexels => PexelsTile(item: pexels, index: index),
                          };

                          return AnimatedFeedTile(index: index, reduceMotion: reduceMotion, child: tile);
                        }, childCount: state.items.length),
                      ),
                    ),
                    SliverToBoxAdapter(child: _bottomState(context, state)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bottomState(BuildContext context, PersonalizedFeedState state) {
    if (state.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 26),
        child: PersonalizedEmptyCard(message: 'Follow more creators or pick interests to improve your For You feed.'),
      );
    }

    if (state.isFetchingMore) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(0, 8, 0, 26),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }

    if (state.hasMore) {
      return const SizedBox(height: 22);
    }

    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 26),
      child: PersonalizedEmptyCard(message: 'You are all caught up. Pull to refresh for fresh picks.'),
    );
  }
}
