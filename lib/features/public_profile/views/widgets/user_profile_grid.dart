import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/premium_wall_utils.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/home/wallpapers/see_more_button.dart';
import 'package:Prism/core/widgets/premium_banners/premium_banner.dart';
import 'package:Prism/core/widgets/prism_image_tile.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_wall_entity.dart';
import 'package:Prism/global/svg_assets.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

class UserProfileGrid extends StatelessWidget {
  const UserProfileGrid({super.key});

  Future<void> _refresh(PublicProfileBloc bloc) async {
    bloc.add(const PublicProfileEvent.refreshRequested());
    await bloc.stream.firstWhere((state) => state.status != LoadStatus.loading);
  }

  @override
  Widget build(BuildContext context) {
    final PublicProfileBloc bloc = context.read<PublicProfileBloc>();
    return RefreshIndicator(
      backgroundColor: Theme.of(context).primaryColor,
      onRefresh: () {
        PrismHaptics.impact();
        return _refresh(bloc);
      },
      child: BlocBuilder<PublicProfileBloc, PublicProfileState>(
        builder: (context, state) {
          if (state.status == LoadStatus.initial) {
            return const LoadingCards();
          }
          final List<PublicProfileWallEntity> walls = state.walls;
          if (walls.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                const SizedBox(height: 12),
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: SvgPicture.string(themedIllustration(context, dark: postsDark, light: postsLight)),
                ),
                const SizedBox(height: 12),
              ],
            );
          }
          return PulsePlaceholder(
            builder: (context, _) => GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: walls.length + (state.hasMoreWalls ? 1 : 0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: wallpaperGridColumns(MediaQuery.sizeOf(context).width),
                childAspectRatio: 0.5,
              ),
              itemBuilder: (context, index) {
                if (index == walls.length && state.hasMoreWalls) {
                  return SeeMoreButton(
                    seeMoreLoader: state.isFetchingMoreWalls,
                    func: () => bloc.add(const PublicProfileEvent.fetchMoreWallsRequested()),
                  );
                }
                final tile = _PhotographerWallTile(
                  wall: walls[index],
                  heroTag: prismHeroTag(bloc, index, walls[index].id),
                );
                return app_state.prismUser.premium
                    ? tile
                    : PremiumBanner(
                        comparator: !isPremiumWall(
                          app_state.premiumCollections,
                          walls[index].collections ?? const <String>[],
                        ),
                        top: (MediaQuery.of(context).size.width / 2) / 0.6225 - 68,
                        left: MediaQuery.of(context).size.width / 2 - 53.5,
                        right: null,
                        bottom: null,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        iconSize: 24,
                        iconPadding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                        fit: StackFit.loose,
                        clipBehavior: Clip.hardEdge,
                        child: tile,
                      );
              },
            ),
          );
        },
      ),
    );
  }
}

class _PhotographerWallTile extends StatelessWidget {
  const _PhotographerWallTile({required this.wall, required this.heroTag});

  final PublicProfileWallEntity wall;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final String imageUrl = normalizeWallpaperThumbnailUrl(wall.wallpaperThumb?.trim() ?? '');
    final bool hasValidImageUrl = imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
    return Semantics(
      button: true,
      label: wallpaperSemanticLabel(wall.by),
      child: Stack(
        children: [
          PrismImageTile(url: hasValidImageUrl ? imageUrl : '', heroTag: heroTag),
          Material(
            color: Colors.transparent,
            child: InkWell(
              splashColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
              highlightColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
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
          ),
        ],
      ),
    );
  }
}
