import 'package:Prism/core/router/route_names.dart';
import 'package:Prism/core/widgets/home/wallpapers/seeMoreButton.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/core/widgets/premiumBanners/setupPhotographer.dart';
import 'package:Prism/features/public_profile/views/public_profile_bloc_adapter.dart';
import 'package:Prism/features/setups/views/widgets/loading_setup_cards.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class UserProfileSetupGrid extends StatefulWidget {
  final String? email;
  const UserProfileSetupGrid({
    this.email,
    super.key,
  });

  @override
  _UserProfileSetupGridState createState() => _UserProfileSetupGridState();
}

class _UserProfileSetupGridState extends State<UserProfileSetupGrid> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<Color?> animation;
  GlobalKey<RefreshIndicatorState> refreshProfileKey = GlobalKey<RefreshIndicatorState>();
  bool seeMoreLoader = false;

  void showPremiumPopUp(Function func) {
    if (globals.prismUser.premium == false) {
      context.pushNamedRoute(premiumRoute);
    } else {
      func();
    }
  }

  void showGooglePopUp(Function func) {
    logger.d(globals.prismUser.loggedIn.toString());
    if (globals.prismUser.loggedIn == false) {
      googleSignInPopUp(context, func);
    } else {
      func();
    }
  }

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
    context.publicProfileAdapter(listen: false).getUserProfileSetups(widget.email);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
        backgroundColor: Theme.of(context).primaryColor,
        key: refreshProfileKey,
        onRefresh: refreshList,
        child: context.publicProfileAdapter().userProfileSetups != null
            ? context.publicProfileAdapter().userProfileSetups!.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: MediaQuery.of(context).size.width,
                        child: context.prismModeStyleForContext() == "Dark"
                            ? SvgPicture.string(
                                postsDark
                                    .replaceAll("181818",
                                        Theme.of(context).primaryColor.toARGB32().toRadixString(16).substring(2))
                                    .replaceAll(
                                        "E57697",
                                        Theme.of(context)
                                            .colorScheme
                                            .error
                                            .toString()
                                            .replaceAll("Color(0xff", "")
                                            .replaceAll(")", ""))
                                    .replaceAll(
                                        "F0F0F0",
                                        Theme.of(context)
                                            .colorScheme
                                            .secondary
                                            .toARGB32()
                                            .toRadixString(16)
                                            .substring(2))
                                    .replaceAll(
                                        "2F2E41",
                                        Theme.of(context)
                                            .colorScheme
                                            .secondary
                                            .toARGB32()
                                            .toRadixString(16)
                                            .substring(2))
                                    .replaceAll(
                                        "3F3D56",
                                        Theme.of(context)
                                            .colorScheme
                                            .secondary
                                            .toARGB32()
                                            .toRadixString(16)
                                            .substring(2))
                                    .replaceAll("2F2F2F",
                                        Theme.of(context).hintColor.toARGB32().toRadixString(16).substring(2)),
                              )
                            : SvgPicture.string(
                                postsLight
                                    .replaceAll("181818",
                                        Theme.of(context).primaryColor.toARGB32().toRadixString(16).substring(2))
                                    .replaceAll(
                                        "E57697",
                                        Theme.of(context)
                                            .colorScheme
                                            .error
                                            .toString()
                                            .replaceAll("Color(0xff", "")
                                            .replaceAll(")", ""))
                                    .replaceAll(
                                        "F0F0F0",
                                        Theme.of(context)
                                            .colorScheme
                                            .secondary
                                            .toARGB32()
                                            .toRadixString(16)
                                            .substring(2))
                                    .replaceAll(
                                        "2F2E41",
                                        Theme.of(context)
                                            .colorScheme
                                            .secondary
                                            .toARGB32()
                                            .toRadixString(16)
                                            .substring(2))
                                    .replaceAll(
                                        "3F3D56",
                                        Theme.of(context)
                                            .colorScheme
                                            .secondary
                                            .toARGB32()
                                            .toRadixString(16)
                                            .substring(2))
                                    .replaceAll("2F2F2F",
                                        Theme.of(context).hintColor.toARGB32().toRadixString(16).substring(2)),
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
                    itemCount: context.publicProfileAdapter().userProfileSetups!.length,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
                        childAspectRatio: 0.5025,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8),
                    itemBuilder: (context, index) {
                      if (index == context.publicProfileAdapter(listen: false).userProfileSetups!.length - 1 &&
                          !(context.publicProfileAdapter(listen: false).userProfileSetups!.length < 8)) {
                        return SeeMoreButton(
                          seeMoreLoader: seeMoreLoader,
                          func: () {
                            if (!seeMoreLoader) {
                              setState(() {
                                seeMoreLoader = true;
                              });
                              context.publicProfileAdapter(listen: false).seeMoreUserProfileSetups(widget.email);
                              setState(() {
                                Future.delayed(const Duration(seconds: 1)).then((value) => seeMoreLoader = false);
                              });
                            }
                          },
                        );
                      }
                      return PremiumBannerSetupPhotographer(
                        comparator: false,
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                  color: animation.value,
                                  borderRadius: BorderRadius.circular(20),
                                  image: DecorationImage(
                                      image: CachedNetworkImageProvider(
                                        context
                                            .publicProfileAdapter()
                                            .userProfileSetups![index]
                                            .data()["image"]
                                            .toString(),
                                      ),
                                      fit: BoxFit.cover)),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  splashColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                                  highlightColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                                  onTap: () {
                                    if (context.publicProfileAdapter(listen: false).userProfileSetups == []) {
                                    } else {
                                      if (globals.prismUser.premium == true) {
                                        context.pushNamedRoute(userProfileSetupViewRoute, arguments: [index]);
                                      } else {
                                        showGooglePopUp(() {
                                          showPremiumPopUp(() {
                                            main.RestartWidget.restartApp(context);
                                          });
                                        });
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    })
            : const LoadingSetupCards());
  }
}
