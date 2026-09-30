import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/premium_wall_utils.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/widgets/home/wallpapers/see_more_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The wallpapers of a profile, as a sliver: empty and error states, then the shared grid with a See more cell.
/// [ownProfile] changes the empty state into an invitation to upload.
class UserProfileGrid extends StatelessWidget {
  const UserProfileGrid({super.key, this.ownProfile = false});

  final bool ownProfile;

  @override
  Widget build(BuildContext context) {
    final PublicProfileBloc bloc = context.read<PublicProfileBloc>();
    return BlocBuilder<PublicProfileBloc, PublicProfileState>(
      builder: (context, state) {
        if (state.status == LoadStatus.initial) {
          return const SliverToBoxAdapter(child: LoadingCards());
        }
        final List<PublicProfileWallEntity> walls = state.walls;
        if (walls.isEmpty) {
          final bool failed = state.status == LoadStatus.failure;
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: PrismSpace.xxl),
              child: failed
                  ? GlintState(
                      kind: GlintStateKind.error,
                      title: 'Could not load wallpapers',
                      body: 'Check your connection and try again.',
                      actionLabel: 'Try again',
                      onAction: () => bloc.add(const PublicProfileEvent.refreshRequested()),
                    )
                  : GlintState(
                      kind: GlintStateKind.empty,
                      title: 'No wallpapers yet',
                      body: ownProfile ? 'Upload your first wallpaper to start your gallery.' : null,
                    ),
            ),
          );
        }
        final bool viewerPremium = app_state.prismUser.premium;
        return SliverPadding(
          padding: PrismWallGrid.padding,
          sliver: SliverGrid.builder(
            gridDelegate: PrismWallGrid.delegate(context),
            itemCount: walls.length + (state.hasMoreWalls ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == walls.length) {
                return SeeMoreButton(
                  seeMoreLoader: state.isFetchingMoreWalls,
                  func: () => bloc.add(const PublicProfileEvent.fetchMoreWallsRequested()),
                );
              }
              final PublicProfileWallEntity wall = walls[index];
              final String heroTag = prismHeroTag(bloc, index, wall.id);
              final String thumb = normalizeWallpaperThumbnailUrl(wall.wallpaperThumb?.trim() ?? '');
              final bool premiumWall = isPremiumWall(
                app_state.premiumCollections,
                wall.collections ?? const <String>[],
              );
              return PrismWallTile(
                url: thumb.startsWith('http://') || thumb.startsWith('https://') ? thumb : '',
                heroTag: heroTag,
                semanticLabel: wallpaperSemanticLabel(wall.by),
                overlay: !viewerPremium && premiumWall ? const _PremiumMark() : null,
                onTap: () => context.router.push(
                  WallpaperDetailRoute(
                    entity: wall.toFeedItem(),
                    analyticsSurface: AnalyticsSurfaceValue.profileWallpaperView,
                    heroTag: heroTag,
                  ),
                ),
              );
            },
          ),
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
          child: const Padding(
            padding: EdgeInsets.all(5),
            child: Icon(Icons.star_rounded, size: 16, color: Colors.white, semanticLabel: 'Pro wallpaper'),
          ),
        ),
      ),
    );
  }
}
