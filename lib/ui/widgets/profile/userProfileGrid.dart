import 'package:Prism/data/profile/wallpaper/getUserProfile.dart' as UserData;
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/theme/thumbModel.dart';
import 'package:Prism/ui/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/ui/widgets/home/loading.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

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
    UserData.getuserProfileWalls(widget.email);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // print(UserData.profileWalls);
    return RefreshIndicator(
        backgroundColor: Theme.of(context).primaryColor,
        key: refreshProfileKey,
        onRefresh: refreshList,
        child: UserData.userProfileWalls != null
            ? UserData.userProfileWalls.length == 0
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
                    itemCount: UserData.userProfileWalls.length,
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
                      // print(UserData
                      //     .profileWalls[index]);
                      // print(index);
                      return FocusedMenuHolder(
                        provider: "UserProfileWall",
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
                                          ? UserData.userProfileWalls[index]
                                              ["wallpaper_url"]
                                          : UserData.userProfileWalls[index]
                                              ["wallpaper_thumb"],
                                    ),
                                    fit: BoxFit.cover)),
                          ),
                          onTap: () {
                            if (UserData.userProfileWalls == []) {
                            } else {
                              Navigator.pushNamed(
                                  context, UserProfileWallViewRoute,
                                  arguments: [
                                    index,
                                    UserData.userProfileWalls[index]
                                        ["wallpaper_thumb"],
                                  ]);
                            }
                          },
                        ),
                      );
                    })
            : LoadingCards());
  }
}
