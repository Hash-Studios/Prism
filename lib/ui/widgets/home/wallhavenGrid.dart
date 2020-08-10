import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/data/categories/provider/categoriesProvider.dart';
import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart'
    as WData;
import 'package:Prism/global/categoryProvider.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/focussedMenu/focusedMenu.dart';
import 'package:Prism/ui/widgets/home/inheritedScrollControllerProvider.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/theme/toasts.dart' as toasts;

class WallHavenGrid extends StatefulWidget {
  final String provider;
  WallHavenGrid({@required this.provider});
  @override
  _WallHavenGridState createState() => _WallHavenGridState();
}

class _WallHavenGridState extends State<WallHavenGrid>
    with TickerProviderStateMixin {
  AnimationController _controller;
  AnimationController shakeController;
  Animation<Color> animation;
  int longTapIndex;
  var refreshHomeKey = GlobalKey<RefreshIndicatorState>();

  bool seeMoreLoader = false;
  @override
  void initState() {
    super.initState();
    shakeController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
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
  dispose() {
    _controller?.dispose();
    shakeController.dispose();
    super.dispose();
  }

  Future<Null> refreshList() async {
    refreshHomeKey.currentState?.show(atTop: true);
    await Future.delayed(Duration(milliseconds: 500));
    WData.walls = [];
    Provider.of<CategorySupplier>(context, listen: false).changeWallpaperFuture(
        Provider.of<CategorySupplier>(context, listen: false).selectedChoice,
        "r");
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> offsetAnimation = Tween(begin: 0.0, end: 8.0)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(shakeController)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              shakeController.reverse();
            }
          });
    final ScrollController controller =
        InheritedDataProvider.of(context).scrollController;
    return RefreshIndicator(
      backgroundColor: Theme.of(context).primaryColor,
      key: refreshHomeKey,
      onRefresh: refreshList,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            if (!seeMoreLoader) {
              Provider.of<CategorySupplier>(context, listen: false)
                  .changeWallpaperFuture(
                      Provider.of<CategorySupplier>(context, listen: false)
                          .selectedChoice,
                      "s");

              setState(() {
                seeMoreLoader = true;
                Future.delayed(Duration(seconds: 4))
                    .then((value) => seeMoreLoader = false);
              });
            }
          }
        },
        child: GridView.builder(
          controller: controller,
          padding: EdgeInsets.fromLTRB(5, 0, 5, 4),
          itemCount: WData.walls.length == 0 ? 24 : WData.walls.length,
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent:
                  MediaQuery.of(context).orientation == Orientation.portrait
                      ? 300
                      : 250,
              childAspectRatio: 0.6625,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8),
          itemBuilder: (context, index) {
            if (index == WData.walls.length - 1) {
              return FlatButton(
                  color: Provider.of<ThemeModel>(context, listen: false)
                              .returnTheme() ==
                          ThemeType.Dark
                      ? Colors.white10
                      : Colors.black.withOpacity(.1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  onPressed: () {
                    if (!seeMoreLoader) {
                      Provider.of<CategorySupplier>(context, listen: false)
                          .changeWallpaperFuture(
                              Provider.of<CategorySupplier>(context,
                                      listen: false)
                                  .selectedChoice,
                              "s");

                      setState(() {
                        seeMoreLoader = true;
                        Future.delayed(Duration(seconds: 4))
                            .then((value) => seeMoreLoader = false);
                      });
                    }
                  },
                  child: !seeMoreLoader ? Text("See more") : Loader());
            }
            return FocusedMenuHolder(
                provider: widget.provider,
                index: index,
                child: AnimatedBuilder(
                    animation: offsetAnimation,
                    builder: (buildContext, child) {
                      if (offsetAnimation.value < 0.0)
                        print('${offsetAnimation.value + 8.0}');
                      return GestureDetector(
                        child: Padding(
                          padding: index == longTapIndex
                              ? EdgeInsets.symmetric(
                                  vertical: offsetAnimation.value / 2,
                                  horizontal: offsetAnimation.value)
                              : EdgeInsets.all(0),
                          child: Container(
                            decoration: WData.walls.length == 0
                                ? BoxDecoration(
                                    color: animation.value,
                                    borderRadius: BorderRadius.circular(20),
                                  )
                                : BoxDecoration(
                                    color: animation.value,
                                    borderRadius: BorderRadius.circular(20),
                                    image: DecorationImage(
                                        image: NetworkImage(WData
                                            .walls[index].thumbs["original"]),
                                        fit: BoxFit.cover)),
                          ),
                        ),
                        onTap: () {
                          if (WData.walls == []) {
                          } else {
                            Navigator.pushNamed(context, WallpaperRoute,
                                arguments: [
                                  widget.provider,
                                  index,
                                  WData.walls[index].thumbs["small"],
                                ]);
                          }
                        },
                        onLongPress: () {
                          setState(() {
                            longTapIndex = index;
                          });
                          shakeController.forward(from: 0.0);
                          if (WData.walls == []) {
                          } else {
                            HapticFeedback.vibrate();
                            createDynamicLink(
                                WData.walls[index].id,
                                widget.provider,
                                WData.walls[index].path,
                                WData.walls[index].thumbs["original"]);
                          }
                        },
                      );
                    }));
          },
        ),
      ),
    );
  }

  void createDynamicLink(
      String id, String provider, String url, String thumbUrl) async {
    final DynamicLinkParameters parameters = DynamicLinkParameters(
        socialMetaTagParameters: SocialMetaTagParameters(
            title: "Prism Wallpapers - $id",
            imageUrl: Uri.parse(thumbUrl),
            description:
                "Check out this amazing wallpaper I got, from Prism Wallpapers App."),
        dynamicLinkParametersOptions: DynamicLinkParametersOptions(
            shortDynamicLinkPathLength: ShortDynamicLinkPathLength.short),
        uriPrefix: 'https://prismwallpapers.page.link',
        link: Uri.parse(
            'http://prism.hash.com/share?id=$id&provider=$provider&url=$url&thumb=$thumbUrl'),
        androidParameters: AndroidParameters(
          packageName: 'com.hash.prism',
          minimumVersion: 1,
        ),
        iosParameters: IosParameters(
          bundleId: 'com.hash.prism',
          minimumVersion: '1.0.1',
          appStoreId: '1405860595',
        ));
    final ShortDynamicLink shortDynamicLink = await parameters.buildShortLink();
    final Uri shortUrl = shortDynamicLink.shortUrl;
    Clipboard.setData(
        ClipboardData(text: "🔥Check this out ➜ " + shortUrl.toString()));
    analytics.logShare(contentType: 'focussedMenu', itemId: id, method: 'link');
    toasts.shareWall();
    print(shortUrl);
  }
}
