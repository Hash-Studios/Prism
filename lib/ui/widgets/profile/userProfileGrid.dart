import 'package:Prism/data/profile/wallpaper/getUserProfile.dart' as userdata;
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/ui/widgets/home/wallpapers/loading.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:Prism/main.dart' as main;

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
                                postsDark.replaceAll(
                                    "E57697",
                                    main.prefs
                                        .get("mainAccentColor")
                                        .toRadixString(16)
                                        .toString()
                                        .substring(2)),
                              )
                            : SvgPicture.string(
                                postsLight.replaceAll(
                                    "E57697",
                                    main.prefs
                                        .get("mainAccentColor")
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
                      return FocusedMenuHolder(
                        provider: "UserProfileWall",
                        index: index,
                        child: GestureDetector(
                          onTap: () {
                            if (userdata.userProfileWalls == []) {
                            } else {
                              Navigator.pushNamed(
                                  context, userProfileWallViewRoute,
                                  arguments: [
                                    index,
                                    userdata.userProfileWalls[index]
                                        ["wallpaper_thumb"],
                                  ]);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                                color: animation.value,
                                borderRadius: BorderRadius.circular(20),
                                image: DecorationImage(
                                    image: CachedNetworkImageProvider(
                                      userdata.userProfileWalls[index]
                                              ["wallpaper_thumb"]
                                          .toString(),
                                    ),
                                    fit: BoxFit.cover)),
                          ),
                        ),
                      );
                    })
            : const LoadingCards());
  }
}
