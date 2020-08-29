import 'package:Prism/data/profile/wallpaper/profileWallProvider.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/theme/thumbModel.dart';
import 'package:Prism/ui/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/ui/widgets/home/loading.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class ProfileGrid extends StatefulWidget {
  const ProfileGrid({
    Key key,
  }) : super(key: key);

  @override
  _ProfileGridState createState() => _ProfileGridState();
}

class _ProfileGridState extends State<ProfileGrid>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation<Color> animation;
  // String userId = '';
  var refreshProfileKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    animation = Provider.of<ThemeModel>(context, listen: false).returnTheme() ==
            ThemeType.Dark
        ? TweenSequence<Color>(
            [
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: Colors.white10,
                  end: Color(0x22FFFFFF),
                ),
              ),
              TweenSequenceItem(
                weight: 1.0,
                tween: ColorTween(
                  begin: Color(0x22FFFFFF),
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

  Future<Null> refreshList() async {
    refreshProfileKey.currentState?.show(atTop: true);
    await Future.delayed(Duration(milliseconds: 500));
    Provider.of<ProfileWallProvider>(context, listen: false).getProfileWalls();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // print(Provider.of<ProfileWallProvider>(context, listen: false).profileWalls);
    return RefreshIndicator(
        backgroundColor: Theme.of(context).primaryColor,
        key: refreshProfileKey,
        onRefresh: refreshList,
        child: Provider.of<ProfileWallProvider>(context, listen: false)
                    .profileWalls !=
                null
            ? Provider.of<ProfileWallProvider>(context, listen: false)
                        .profileWalls
                        .length ==
                    0
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        child: Provider.of<ThemeModel>(context, listen: false)
                                    .returnTheme() ==
                                ThemeType.Dark
                            ? SvgPicture.asset(
                                "assets/images/posts dark.svg",
                              )
                            : SvgPicture.asset(
                                "assets/images/posts light.svg",
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
                    padding: EdgeInsets.fromLTRB(5, 0, 5, 4),
                    itemCount: Provider.of<ProfileWallProvider>(context)
                        .profileWalls
                        .length,
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
                      // print(Provider.of<ProfileWallProvider>(context, listen: false)
                      //     .profileWalls[index]);
                      // print(index);
                      return FocusedMenuHolder(
                        provider: "ProfileWall",
                        index: index,
                        child: GestureDetector(
                          child: Container(
                            decoration: BoxDecoration(
                                color: animation.value,
                                borderRadius: BorderRadius.circular(20),
                                image: DecorationImage(
                                    image: CachedNetworkImageProvider(
                                      Provider.of<ThumbModel>(context,
                                                      listen: false)
                                                  .thumbType ==
                                              ThumbType.High
                                          ? Provider.of<ProfileWallProvider>(
                                                      context)
                                                  .profileWalls[index]
                                              ["wallpaper_url"]
                                          : Provider.of<ProfileWallProvider>(
                                                      context)
                                                  .profileWalls[index]
                                              ["wallpaper_thumb"],
                                    ),
                                    fit: BoxFit.cover)),
                          ),
                          onTap: () {
                            if (Provider.of<ProfileWallProvider>(context,
                                        listen: false)
                                    .profileWalls ==
                                []) {
                            } else {
                              Navigator.pushNamed(context, ProfileWallViewRoute,
                                  arguments: [
                                    index,
                                    Provider.of<ProfileWallProvider>(context,
                                            listen: false)
                                        .profileWalls[index]["wallpaper_thumb"],
                                  ]);
                            }
                          },
                        ),
                      );
                    })
            : LoadingCards());
  }
}
