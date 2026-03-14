import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_action_payload.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/home/wallpapers/seeMoreButton.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/palette/domain/entities/wallpaper_detail_entity.dart';
import 'package:Prism/features/profile_walls/views/profile_walls_bloc_adapter.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ProfileGrid extends StatefulWidget {
  const ProfileGrid({super.key});

  @override
  _ProfileGridState createState() => _ProfileGridState();
}

class _ProfileGridState extends State<ProfileGrid> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<Color?> animation;
  GlobalKey<RefreshIndicatorState> refreshProfileKey = GlobalKey<RefreshIndicatorState>();
  bool seeMoreLoader = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    animation =
        context.prismModeStyleForWindow(listen: false) == "Dark"
              ? TweenSequence<Color?>([
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(begin: Colors.white10, end: const Color(0x22FFFFFF)),
                  ),
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(begin: const Color(0x22FFFFFF), end: Colors.white10),
                  ),
                ]).animate(_controller!)
              : TweenSequence<Color?>([
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(
                      begin: Colors.black.withValues(alpha: .1),
                      end: Colors.black.withValues(alpha: .14),
                    ),
                  ),
                  TweenSequenceItem(
                    weight: 1.0,
                    tween: ColorTween(
                      begin: Colors.black.withValues(alpha: .14),
                      end: Colors.black.withValues(alpha: .1),
                    ),
                  ),
                ]).animate(_controller!)
          ..addListener(() {
            setState(() {});
          });
    _controller!.repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> refreshList() async {
    refreshProfileKey.currentState?.show();
    context.loadProfileWalls();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      backgroundColor: Theme.of(context).primaryColor,
      key: refreshProfileKey,
      onRefresh: refreshList,
      child: context.profileWalls(listen: false) != null
          ? context.profileWalls(listen: false)!.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.7,
                        child: context.prismModeStyleForContext() == "Dark"
                            ? SvgPicture.string(
                                postsDark
                                    .replaceAll(
                                      "181818",
                                      Theme.of(context).primaryColor.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "E57697",
                                      Theme.of(
                                        context,
                                      ).colorScheme.error.toString().replaceAll("Color(0xff", "").replaceAll(")", ""),
                                    )
                                    .replaceAll(
                                      "F0F0F0",
                                      Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "2F2E41",
                                      Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "3F3D56",
                                      Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "2F2F2F",
                                      Theme.of(context).hintColor.toARGB32().toRadixString(16).substring(2),
                                    ),
                              )
                            : SvgPicture.string(
                                postsLight
                                    .replaceAll(
                                      "181818",
                                      Theme.of(context).primaryColor.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "E57697",
                                      Theme.of(
                                        context,
                                      ).colorScheme.error.toString().replaceAll("Color(0xff", "").replaceAll(")", ""),
                                    )
                                    .replaceAll(
                                      "F0F0F0",
                                      Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "2F2E41",
                                      Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "3F3D56",
                                      Theme.of(context).colorScheme.secondary.toARGB32().toRadixString(16).substring(2),
                                    )
                                    .replaceAll(
                                      "2F2F2F",
                                      Theme.of(context).hintColor.toARGB32().toRadixString(16).substring(2),
                                    ),
                              ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height * 0.1,
                      ),
                    ],
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(5, 0, 5, 4),
                    itemCount: context.profileWalls()!.length,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
                      childAspectRatio: 0.6625,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemBuilder: (context, index) {
                      if (index == context.profileWalls(listen: false)!.length - 1 &&
                          !(context.profileWalls(listen: false)!.length < 12)) {
                        return SeeMoreButton(
                          seeMoreLoader: seeMoreLoader,
                          func: () {
                            if (!seeMoreLoader) {
                              setState(() {
                                seeMoreLoader = true;
                              });
                              context.fetchMoreProfileWalls();
                              setState(() {
                                Future.delayed(const Duration(seconds: 1)).then((value) => seeMoreLoader = false);
                              });
                            }
                          },
                        );
                      }
                      final wall = context.profileWalls()![index];
                      final collections = wall.collections as List? ?? const [];
                      final photographer = (wall.by ?? '').trim();
                      final prismWallpaper = PrismWallpaper(
                        core: WallpaperCore(
                          id: wall.id,
                          source: WallpaperSource.prism,
                          fullUrl: wall.wallpaperUrl,
                          thumbnailUrl: wall.wallpaperThumb ?? '',
                          resolution: wall.resolution,
                          sizeBytes: int.tryParse(wall.size ?? '0'),
                          createdAt: wall.createdAt,
                          authorName: wall.by,
                          authorEmail: wall.email,
                        ),
                        collections: wall.collections,
                      );
                      final payload = WallpaperActionPayload(
                        providerLabel: 'ProfileWall',
                        title: photographer.isEmpty ? 'Prism' : photographer,
                        subtitle: wall.id.toUpperCase(),
                        stats: [
                          WallpaperActionStat(
                            kind: WallpaperActionStatKind.size,
                            label: (wall.size ?? '').trim().isEmpty ? '0' : wall.size!,
                          ),
                          WallpaperActionStat(
                            kind: WallpaperActionStatKind.resolution,
                            label: (wall.resolution ?? '').trim().isEmpty ? '-' : wall.resolution!,
                          ),
                        ],
                        fullUrl: wall.wallpaperUrl,
                        favouriteWall: PrismFavouriteWall(id: wall.id, wallpaper: prismWallpaper),
                        favouriteTrash: false,
                        cardTopFactor: 4 / 10,
                        cardHeightFactor: 6 / 10,
                        isPremiumContent: app_state.isPremiumWall(app_state.premiumCollections, collections),
                        contentId: wall.id,
                        sourceContext: 'focused_menu.ProfileWall',
                      );
                      return FocusedMenuHolder.payload(
                        payload: payload,
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: animation.value,
                                borderRadius: BorderRadius.circular(20),
                                image: DecorationImage(
                                  image: CachedNetworkImageProvider(wall.wallpaperThumb.toString()),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  splashColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                                  highlightColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                                  onTap: () {
                                    if (context.profileWalls(listen: false) == null ||
                                        context.profileWalls(listen: false)!.isEmpty) {
                                    } else {
                                      final profileWalls = context.profileWalls(listen: false)!;
                                      final entity = WallpaperDetailEntityX.fromProfileWall(profileWalls[index]);
                                      context.router.push(
                                        WallpaperDetailRoute(
                                          entity: entity,
                                          analyticsSurface: AnalyticsSurfaceValue.profileWallpaperView,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
          : const LoadingCards(),
    );
  }
}
