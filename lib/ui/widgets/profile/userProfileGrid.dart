import 'package:Prism/data/profile/wallpaper/getUserProfile.dart' as userdata;
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/ui/widgets/home/collections/collectionsGrid.dart';
import 'package:Prism/ui/widgets/home/wallpapers/loading.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/global/globals.dart' as globals;

class UserProfileGrid extends StatefulWidget {
  final String email;
  const UserProfileGrid({
    this.email,
    Key key,
  }) : super(key: key);

  @override
  _UserProfileGridState createState() => _UserProfileGridState();
}

class _UserProfileGridState extends State<UserProfileGrid>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation<Color> animation;
  GlobalKey<RefreshIndicatorState> refreshProfileKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    animation = Provider.of<ThemeModel>(context, listen: false)
                .returnThemeType() ==
            "Dark"
        ? TweenSequence<Color>(
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
          ).animate(_controller)
        : TweenSequence<Color>(
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
          ).animate(_controller)
      ..addListener(() {
        setState(() {});
      });
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> refreshList() async {
    refreshProfileKey.currentState?.show();
    await Future.delayed(const Duration(milliseconds: 500));
    userdata.getuserProfileWalls(widget.email);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
        backgroundColor: Theme.of(context).primaryColor,
        key: refreshProfileKey,
        onRefresh: refreshList,
        child: userdata.userProfileWalls != null
            ? userdata.userProfileWalls.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        child: Provider.of<ThemeModel>(context, listen: false)
                                    .returnThemeType() ==
                                "Dark"
                            ? SvgPicture.string(
                                postsDark
                                    .replaceAll(
                                        "181818",
                                        Theme.of(context)
                                            .primaryColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "E57697",
                                        main.prefs
                                            .get("mainAccentColor")
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "F0F0F0",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "2F2E41",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "3F3D56",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "2F2F2F",
                                        Theme.of(context)
                                            .hintColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2)),
                              )
                            : SvgPicture.string(
                                postsLight
                                    .replaceAll(
                                        "181818",
                                        Theme.of(context)
                                            .primaryColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "E57697",
                                        main.prefs
                                            .get("mainAccentColor")
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "F0F0F0",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "2F2E41",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "3F3D56",
                                        Theme.of(context)
                                            .accentColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2))
                                    .replaceAll(
                                        "2F2F2F",
                                        Theme.of(context)
                                            .hintColor
                                            .value
                                            .toRadixString(16)
                                            .toString()
                                            .substring(2)),
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
                    cacheExtent: 50000,
                    padding: const EdgeInsets.fromLTRB(5, 0, 5, 4),
                    itemCount: userdata.userProfileWalls.length,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent:
                            MediaQuery.of(context).orientation ==
                                    Orientation.portrait
                                ? 300
                                : 250,
                        childAspectRatio: 0.6625,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8),
                    itemBuilder: (context, index) {
                      return main.prefs.get('premium') != true
                          ? PremiumBannerWalls(
                              comparator: !globals.isPremiumWall(
                                  globals.premiumCollections,
                                  userdata.userProfileWalls[index]
                                          ["collections"] as List ??
                                      []),
                              defaultChild: FocusedMenuHolder(
                                provider: "UserProfileWall",
                                index: index,
                                child: PhotographerWallTile(
                                    animation: animation, index: index),
                              ),
                              trueChild: PhotographerWallTile(
                                animation: animation,
                                index: index,
                              ),
                            )
                          : FocusedMenuHolder(
                              provider: "UserProfileWall",
                              index: index,
                              child: PhotographerWallTile(
                                  animation: animation, index: index),
                            );
                    })
            : const LoadingCards());
  }
}

class PhotographerWallTile extends StatelessWidget {
  const PhotographerWallTile({
    Key key,
    @required this.animation,
    @required this.index,
  }) : super(key: key);

  final Animation<Color> animation;
  final int index;

  void showGooglePopUp(BuildContext context, Function func) {
    debugPrint(main.prefs.get("isLoggedin").toString());
    if (main.prefs.get("isLoggedin") == false) {
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
              color: animation.value,
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(
                  image: CachedNetworkImageProvider(
                    userdata.userProfileWalls[index]["wallpaper_thumb"]
                        .toString(),
                  ),
                  fit: BoxFit.cover)),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              splashColor: Theme.of(context).accentColor.withOpacity(0.3),
              highlightColor: Theme.of(context).accentColor.withOpacity(0.1),
              onTap: () {
                if (userdata.userProfileWalls == []) {
                } else {
                  globals.isPremiumWall(
                                  globals.premiumCollections,
                                  userdata.userProfileWalls[index]
                                          ["collections"] as List ??
                                      []) ==
                              true &&
                          main.prefs.get('premium') != true
                      ? showGooglePopUp(context, () {
                          Navigator.pushNamed(
                            context,
                            premiumRoute,
                          );
                        })
                      : Navigator.pushNamed(context, userProfileWallViewRoute,
                          arguments: [
                              index,
                              userdata.userProfileWalls[index]
                                  ["wallpaper_thumb"],
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
