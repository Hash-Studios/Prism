import 'package:Prism/ui/profile/public_profile_legacy_bridge.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/ui/theme/theme_bloc_utils.dart';
import 'package:Prism/ui/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/ui/widgets/home/wallpapers/loading.dart';
import 'package:Prism/ui/widgets/home/wallpapers/seeMoreButton.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:Prism/ui/widgets/premiumBanners/walls.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class UserProfileGrid extends StatefulWidget {
  final String? email;
  const UserProfileGrid({
    this.email,
    super.key,
  });

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
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    animation = context.prismModeStyleForWindow(listen: false) == "Dark"
        ? TweenSequence<Color?>(
            [
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: Colors.white10,
                  end: const Color(0x22FFFFFF),
                ),
              ),
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: const Color(0x22FFFFFF),
                  end: Colors.white10,
                ),
              ),
            ],
          ).animate(_controller!)
        : TweenSequence<Color?>(
            [
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: Colors.black.withOpacity(.1),
                  end: Colors.black.withOpacity(.14),
                ),
              ),
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: Colors.black.withOpacity(.14),
                  end: Colors.black.withOpacity(.1),
                ),
              ),
            ],
          ).animate(_controller!)
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
    context.publicProfileLegacyProvider(listen: false).getuserProfileWalls(widget.email);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
        backgroundColor: Theme.of(context).primaryColor,
        key: refreshProfileKey,
        onRefresh: refreshList,
        child: context.publicProfileLegacyProvider().userProfileWalls != null
            ? context.publicProfileLegacyProvider().userProfileWalls!.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        child: context.prismModeStyleForContext() == "Dark"
                            ? SvgPicture.string(
                                postsDark
                                    .replaceAll(
                                        "181818", Theme.of(context).primaryColor.value.toRadixString(16).substring(2))
                                    .replaceAll(
                                        "E57697",
                                        Theme.of(context)
                                            .colorScheme
                                            .error
                                            .toString()
                                            .replaceAll("Color(0xff", "")
                                            .replaceAll(")", ""))
                                    .replaceAll("F0F0F0",
                                        Theme.of(context).colorScheme.secondary.value.toRadixString(16).substring(2))
                                    .replaceAll("2F2E41",
                                        Theme.of(context).colorScheme.secondary.value.toRadixString(16).substring(2))
                                    .replaceAll("3F3D56",
                                        Theme.of(context).colorScheme.secondary.value.toRadixString(16).substring(2))
                                    .replaceAll(
                                        "2F2F2F", Theme.of(context).hintColor.value.toRadixString(16).substring(2)),
                              )
                            : SvgPicture.string(
                                postsLight
                                    .replaceAll(
                                        "181818", Theme.of(context).primaryColor.value.toRadixString(16).substring(2))
                                    .replaceAll(
                                        "E57697",
                                        Theme.of(context)
                                            .colorScheme
                                            .error
                                            .toString()
                                            .replaceAll("Color(0xff", "")
                                            .replaceAll(")", ""))
                                    .replaceAll("F0F0F0",
                                        Theme.of(context).colorScheme.secondary.value.toRadixString(16).substring(2))
                                    .replaceAll("2F2E41",
                                        Theme.of(context).colorScheme.secondary.value.toRadixString(16).substring(2))
                                    .replaceAll("3F3D56",
                                        Theme.of(context).colorScheme.secondary.value.toRadixString(16).substring(2))
                                    .replaceAll(
                                        "2F2F2F", Theme.of(context).hintColor.value.toRadixString(16).substring(2)),
                              ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height * 0.1,
                      )
                    ],
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(5, 0, 5, 4),
                    itemCount: context.publicProfileLegacyProvider().userProfileWalls!.length,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
                        childAspectRatio: 0.6625,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8),
                    itemBuilder: (context, index) {
                      if (index == context.publicProfileLegacyProvider(listen: false).userProfileWalls!.length - 1 &&
                          !(context.publicProfileLegacyProvider(listen: false).userProfileWalls!.length < 12)) {
                        return SeeMoreButton(
                          seeMoreLoader: seeMoreLoader,
                          func: () {
                            if (!seeMoreLoader) {
                              setState(() {
                                seeMoreLoader = true;
                              });
                              context.publicProfileLegacyProvider(listen: false).seeMoreUserProfileWalls(widget.email);
                              setState(() {
                                Future.delayed(const Duration(seconds: 1)).then((value) => seeMoreLoader = false);
                              });
                            }
                          },
                        );
                      }
                      return globals.prismUser.premium != true
                          ? PremiumBannerWalls(
                              comparator: !globals.isPremiumWall(
                                  globals.premiumCollections,
                                  context.publicProfileLegacyProvider().userProfileWalls![index].data()["collections"]
                                          as List? ??
                                      []),
                              defaultChild: FocusedMenuHolder(
                                provider: "UserProfileWall",
                                index: index,
                                child: PhotographerWallTile(animation: animation, index: index),
                              ),
                              trueChild: PhotographerWallTile(
                                animation: animation,
                                index: index,
                              ),
                            )
                          : FocusedMenuHolder(
                              provider: "UserProfileWall",
                              index: index,
                              child: PhotographerWallTile(animation: animation, index: index),
                            );
                    })
            : const LoadingCards());
  }
}

class PhotographerWallTile extends StatelessWidget {
  const PhotographerWallTile({
    super.key,
    required this.animation,
    required this.index,
  });

  final Animation<Color?>? animation;
  final int index;

  void showGooglePopUp(BuildContext context, Function func) {
    logger.d(globals.prismUser.loggedIn.toString());
    if (globals.prismUser.loggedIn == false) {
      googleSignInPopUp(context, func);
    } else {
      func();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
              color: animation!.value,
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(
                  image: CachedNetworkImageProvider(
                    context.publicProfileLegacyProvider().userProfileWalls![index].data()["wallpaper_thumb"].toString(),
                  ),
                  fit: BoxFit.cover)),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              splashColor: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
              highlightColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              onTap: () {
                if (context.publicProfileLegacyProvider(listen: false).userProfileWalls == []) {
                } else {
                  globals.isPremiumWall(
                                  globals.premiumCollections,
                                  context
                                          .publicProfileLegacyProvider(listen: false)
                                          .userProfileWalls![index]
                                          .data()["collections"] as List? ??
                                      []) ==
                              true &&
                          globals.prismUser.premium != true
                      ? showGooglePopUp(context, () {
                          Navigator.pushNamed(
                            context,
                            premiumRoute,
                          );
                        })
                      : Navigator.pushNamed(context, userProfileWallViewRoute, arguments: [
                          index,
                          context
                              .publicProfileLegacyProvider(listen: false)
                              .userProfileWalls![index]
                              .data()["wallpaper_thumb"],
                        ]);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
