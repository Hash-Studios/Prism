import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/core/widgets/home/wallpapers/seeMoreButton.dart';
import 'package:Prism/core/widgets/premiumBanners/walls.dart';
import 'package:Prism/features/public_profile/views/public_profile_bloc_adapter.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/global/svgAssets.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class UserProfileGrid extends StatefulWidget {
  final String? email;
  const UserProfileGrid({this.email, super.key});

  @override
  _UserProfileGridState createState() => _UserProfileGridState();
}

class _UserProfileGridState extends State<UserProfileGrid> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<Color?>? animation;
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
    await context.publicProfileAdapter(listen: false).refreshProfile(widget.email);
  }

  Future<void> _loadMoreWalls() async {
    if (seeMoreLoader) {
      return;
    }
    setState(() {
      seeMoreLoader = true;
    });
    try {
      await context.publicProfileAdapter(listen: false).seeMoreUserProfileWalls(widget.email);
    } finally {
      if (mounted) {
        setState(() {
          seeMoreLoader = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      backgroundColor: Theme.of(context).primaryColor,
      key: refreshProfileKey,
      onRefresh: refreshList,
      child: context.publicProfileAdapter().userProfileWalls != null
          ? context.publicProfileAdapter().userProfileWalls!.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: <Widget>[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
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
                      const SizedBox(height: 12),
                    ],
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(5, 0, 5, 4),
                    itemCount: context.publicProfileAdapter().userProfileWalls!.length,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
                      childAspectRatio: 0.6625,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemBuilder: (context, index) {
                      if (index == context.publicProfileAdapter(listen: false).userProfileWalls!.length - 1 &&
                          context.publicProfileAdapter(listen: false).hasMoreWalls) {
                        return SeeMoreButton(seeMoreLoader: seeMoreLoader, func: _loadMoreWalls);
                      }
                      return app_state.prismUser.premium != true
                          ? PremiumBannerWalls(
                              comparator: !app_state.isPremiumWall(
                                app_state.premiumCollections,
                                context.publicProfileAdapter().userProfileWalls![index].data()["collections"]
                                        as List? ??
                                    [],
                              ),
                              defaultChild: FocusedMenuHolder(
                                provider: "UserProfileWall",
                                index: index,
                                child: PhotographerWallTile(animation: animation, index: index),
                              ),
                              trueChild: PhotographerWallTile(animation: animation, index: index),
                            )
                          : FocusedMenuHolder(
                              provider: "UserProfileWall",
                              index: index,
                              child: PhotographerWallTile(animation: animation, index: index),
                            );
                    },
                  )
          : const LoadingCards(),
    );
  }
}

class PhotographerWallTile extends StatelessWidget {
  const PhotographerWallTile({super.key, required this.animation, required this.index});

  final Animation<Color?>? animation;
  final int index;

  @override
  Widget build(BuildContext context) {
    final String imageUrl = context.publicProfileAdapter().userProfileWalls![index].data()["wallpaper_thumb"] == null
        ? ""
        : context.publicProfileAdapter().userProfileWalls![index].data()["wallpaper_thumb"].toString().trim();
    final bool hasValidImageUrl = imageUrl.startsWith("http://") || imageUrl.startsWith("https://");
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: animation!.value,
            borderRadius: BorderRadius.circular(20),
            image: hasValidImageUrl
                ? DecorationImage(image: CachedNetworkImageProvider(imageUrl), fit: BoxFit.cover)
                : null,
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
                if (context.publicProfileAdapter(listen: false).userProfileWalls == []) {
                } else {
                  context.router.push(
                    UserProfileWallViewRoute(
                      wallIndex: index,
                      thumbnailUrl: context
                          .publicProfileAdapter(listen: false)
                          .userProfileWalls![index]
                          .data()["wallpaper_thumb"]
                          .toString(),
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
