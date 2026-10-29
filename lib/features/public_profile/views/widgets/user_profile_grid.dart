import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/premium_wall_utils.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/widgets/depth_tag.dart';
import 'package:Prism/core/widgets/home/wallpapers/see_more_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/spatial_tag.dart';
import 'package:Prism/features/favourite_walls/views/widgets/favourite_wallpaper_card.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The wallpapers of a profile, as a sliver: empty and error states, then the shared grid with a See more cell.
/// [ownProfile] changes the empty state into an invitation to upload. It also keeps the user's own walls visible when
/// AI walls are hidden.
class UserProfileGrid extends StatefulWidget {
  const UserProfileGrid({super.key, this.ownProfile = false});

  final bool ownProfile;

  @override
  State<UserProfileGrid> createState() => _UserProfileGridState();
}

class _UserProfileGridState extends State<UserProfileGrid> {
  static const int _maxEmptyPages = 5;

  int _emptyPagesLoaded = 0;
  bool _emptyPageLoadScheduled = false;
  String? _lastProfileId;

  /// Visible wall count when the user asked for more, while hidden AI walls keep the new pages empty.
  int? _seeMoreFrom;
  int _seeMorePages = 0;
  LoadStatus? _lastStatus;

  bool get ownProfile => widget.ownProfile;

  /// A page that hides every wall asks for the next one, up to [_maxEmptyPages] times.
  void _loadMoreWhileEmpty(PublicProfileBloc bloc, SettingsLocalDataSource settings, String profileId) {
    if (_emptyPageLoadScheduled) return;
    _emptyPageLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emptyPageLoadScheduled = false;
      final PublicProfileState current = bloc.state;
      if (!mounted ||
          bloc.isClosed ||
          ownProfile ||
          AiContentFilter.showsAi(settings) ||
          current.profileId != profileId ||
          current.status != LoadStatus.success ||
          current.isFetchingMoreWalls ||
          !current.hasMoreWalls ||
          _emptyPagesLoaded >= _maxEmptyPages) {
        return;
      }
      _emptyPagesLoaded += 1;
      bloc.add(const PublicProfileEvent.fetchMoreWallsRequested());
    });
  }

  void _seeMore(PublicProfileBloc bloc, int visible) {
    _seeMoreFrom = visible;
    _seeMorePages = 1;
    bloc.add(const PublicProfileEvent.fetchMoreWallsRequested());
  }

  /// A requested page that added no visible wall asks for the next one, up to [_maxEmptyPages] pages.
  void _continueSeeMore(PublicProfileBloc bloc, PublicProfileState state, int visible) {
    final int? from = _seeMoreFrom;
    if (from == null || state.isFetchingMoreWalls) return;
    if (visible > from ||
        !state.hasMoreWalls ||
        state.status == LoadStatus.failure ||
        _seeMorePages >= _maxEmptyPages) {
      _seeMoreFrom = null;
      return;
    }
    _seeMorePages += 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !bloc.isClosed && !bloc.state.isFetchingMoreWalls) {
        bloc.add(const PublicProfileEvent.fetchMoreWallsRequested());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final PublicProfileBloc bloc = context.read<PublicProfileBloc>();
    return ValueListenableBuilder<int>(
      valueListenable: personalizedFeedSettingsRevision,
      builder: (context, _, _) => _buildGrid(context, bloc),
    );
  }

  Widget _buildGrid(BuildContext context, PublicProfileBloc bloc) {
    final SettingsLocalDataSource settings = getIt<SettingsLocalDataSource>();
    final bool hideAi = !ownProfile && !AiContentFilter.showsAi(settings);
    return BlocBuilder<PublicProfileBloc, PublicProfileState>(
      builder: (context, state) {
        if (_lastProfileId != state.profileId) {
          _lastProfileId = state.profileId;
          _emptyPagesLoaded = 0;
          _seeMoreFrom = null;
          _emptyPageLoadScheduled = false;
        } else if (state.status == LoadStatus.loading && _lastStatus != LoadStatus.loading) {
          // A refresh of this same profile starts a new bounded hidden-page scan.
          _emptyPagesLoaded = 0;
        }
        _lastStatus = state.status;
        if (state.status == LoadStatus.initial || (state.status == LoadStatus.loading && state.walls.isEmpty)) {
          return const SliverToBoxAdapter(child: LoadingCards());
        }
        final List<PublicProfileWallEntity> walls = hideAi
            ? state.walls.where((wall) => !wall.isAiGenerated).toList(growable: false)
            : state.walls;
        final bool failed = state.status == LoadStatus.failure;
        if (_lastProfileId == state.profileId) _continueSeeMore(bloc, state, walls.length);
        final Widget retryState = GlintState(
          kind: GlintStateKind.error,
          title: context.l10n.accountCouldNotLoadWallpapers,
          body: context.l10n.accountConnectionTryAgain,
          actionLabel: context.l10n.accountTryAgain,
          onAction: () => bloc.add(const PublicProfileEvent.refreshRequested()),
        );
        if (walls.isNotEmpty || !hideAi) _emptyPagesLoaded = 0;
        final bool morePagesToTry = hideAi && state.hasMoreWalls && !failed && _emptyPagesLoaded < _maxEmptyPages;
        if (walls.isEmpty && hideAi && state.isFetchingMoreWalls) {
          return const SliverToBoxAdapter(child: LoadingCards());
        }
        if (walls.isEmpty && morePagesToTry) {
          if (!state.isFetchingMoreWalls && state.status != LoadStatus.loading) {
            _loadMoreWhileEmpty(bloc, settings, state.profileId);
          }
          return const SliverToBoxAdapter(child: LoadingCards());
        }
        if (walls.isEmpty && hideAi && !failed && state.walls.isNotEmpty) {
          if (state.hasMoreWalls) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: PrismSpace.xxl),
                child: PrismInlineState(
                  icon: Icons.auto_awesome_rounded,
                  title: context.l10n.accountNoWallpapersYet,
                  actionLabel: context.l10n.wallpaperTryAgain,
                  onAction: () => bloc.add(const PublicProfileEvent.fetchMoreWallsRequested()),
                ),
              ),
            );
          }
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: PrismSpace.xxl),
              child: PrismInlineState(
                icon: Icons.auto_awesome_rounded,
                title: context.l10n.feedNoHumanWalls,
                actionLabel: context.l10n.feedShowAiWalls,
                onAction: () async {
                  await setShowAiWallpapers(settings, true);
                  if (mounted && !bloc.isClosed) bloc.add(const PublicProfileEvent.refreshRequested());
                },
              ),
            ),
          );
        }
        if (walls.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: PrismSpace.xxl),
              child: failed
                  ? retryState
                  : GlintState(
                      kind: GlintStateKind.empty,
                      title: context.l10n.accountNoWallpapersYet,
                      body: ownProfile ? context.l10n.accountUploadFirstWallpaper : null,
                    ),
            ),
          );
        }
        final bool viewerPremium = app_state.prismUser.premium;
        final int decodeHeight = gridTileDecodeHeight(
          context,
          crossAxisCount: wallpaperGridColumns(MediaQuery.sizeOf(context).width),
        );
        return SliverMainAxisGroup(
          slivers: <Widget>[
            if (failed)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: PrismSpace.md),
                  child: retryState,
                ),
              ),
            SliverPadding(
              padding: PrismWallGrid.padding,
              sliver: SliverGrid.builder(
                gridDelegate: PrismWallGrid.delegate(context, footerHeight: favouriteFooterHeight),
                itemCount: walls.length + (state.hasMoreWalls ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == walls.length) {
                    return SeeMoreButton(
                      seeMoreLoader: state.isFetchingMoreWalls,
                      func: () => _seeMore(bloc, walls.length),
                    );
                  }
                  final PublicProfileWallEntity wall = walls[index];
                  final String heroTag = prismHeroTag(bloc, index, wall.id);
                  final String thumb = normalizeWallpaperThumbnailUrl(wall.wallpaperThumb?.trim() ?? '');
                  final bool premiumWall = isPremiumWall(
                    app_state.premiumCollections,
                    wall.collections ?? const <String>[],
                  );
                  final Widget? depthTag = stackTags(<Widget?>[
                    depthTagFor(wall.depthTier),
                    spatialTagFor(wall.spatial?.tier),
                  ]);
                  return FavouriteWallpaperCard(
                    item: wall.toFeedItem(),
                    child: PrismWallTile(
                      key: ValueKey<String>(wall.id),
                      memCacheHeight: decodeHeight,
                      url: thumb.startsWith('http://') || thumb.startsWith('https://') ? thumb : '',
                      heroTag: heroTag,
                      semanticLabel: wallpaperSemanticLabel(wall.by, context.l10n),
                      overlay: !viewerPremium && premiumWall
                          ? Stack(fit: StackFit.expand, children: <Widget>[const _PremiumMark(), ?depthTag])
                          : depthTag,
                      onTap: () {
                        PrismHaptics.tap();
                        context.router.push(
                          WallpaperDetailRoute(
                            entity: wall.toFeedItem(),
                            analyticsSurface: AnalyticsSurfaceValue.profileWallpaperView,
                            heroTag: heroTag,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A small star on a scrim, top end of a tile, for wallpapers that need Pro.
class _PremiumMark extends StatelessWidget {
  const _PremiumMark();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(PrismSpace.xs),
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.38), shape: BoxShape.circle),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              Icons.star_rounded,
              size: 16,
              color: Colors.white,
              semanticLabel: context.l10n.accountProWallpaperSemantics,
            ),
          ),
        ),
      ),
    );
  }
}
