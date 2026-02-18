import 'dart:io';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/features/navigation/views/widgets/inherited_scroll_controller_provider.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class BottomBar extends StatefulWidget {
  final Widget? child;
  const BottomBar({this.child, super.key});

  @override
  _BottomBarState createState() => _BottomBarState();
}

class _BottomBarState extends State<BottomBar> with SingleTickerProviderStateMixin {
  ScrollController scrollBottomBarController = ScrollController();
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  bool isScrollingDown = false;
  bool isOnTop = true;
  late double bottom;

  @override
  void initState() {
    myScroll();
    super.initState();
    bottom = 10;
    _controller = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 2),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut))
      ..addListener(() {
        setState(() {});
      });
  }

  void showBottomBar() {
    setState(() {
      _controller.reverse();
    });
  }

  void hideBottomBar() {
    setState(() {
      _controller.forward();
    });
  }

  Future<void> myScroll() async {
    scrollBottomBarController.addListener(() {
      if (scrollBottomBarController.position.userScrollDirection == ScrollDirection.reverse) {
        if (!isScrollingDown) {
          isScrollingDown = true;
          isOnTop = false;
          hideBottomBar();
        }
      }
      if (scrollBottomBarController.position.userScrollDirection == ScrollDirection.forward) {
        if (isScrollingDown) {
          isScrollingDown = false;
          isOnTop = true;
          showBottomBar();
        }
      }
    });
  }

  @override
  void dispose() {
    scrollBottomBarController.removeListener(() {});
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.bottomCenter,
      children: [
        InheritedDataProvider(scrollController: scrollBottomBarController, child: widget.child!),
        Positioned(
          bottom: bottom,
          child: SlideTransition(position: _offsetAnimation, child: BottomNavBar()),
        ),
        if (isOnTop == true)
          Container()
        else
          Positioned(
            right: 10,
            bottom: bottom,
            child: FloatingActionButton(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              mini: true,
              onPressed: () {
                scrollBottomBarController
                    .animateTo(
                  scrollBottomBarController.position.minScrollExtent,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeIn,
                )
                    .then((value) {
                  setState(() {
                    isOnTop = true;
                    isScrollingDown = false;
                  });
                  showBottomBar();
                });
              },
              child: Icon(JamIcons.arrow_up, color: Theme.of(context).primaryColor),
            ),
          ),
      ],
    );
  }
}

class BottomNavBar extends StatefulWidget {
  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller2;
  late Animation<double> _paddingAnimation;
  bool? isLoggedin = false;
  bool imageNotFound = false;
  @override
  void initState() {
    checkSignIn();
    super.initState();
    _controller2 = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _paddingAnimation =
        Tween(begin: 14.0, end: 20.0).animate(CurvedAnimation(parent: _controller2, curve: Curves.easeOutCubic))
          ..addListener(() {
            setState(() {});
          });
    _controller2.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller2.dispose();
    super.dispose();
  }

  Future<void> checkSignIn() async {
    setState(() {
      isLoggedin = globals.prismUser.loggedIn;
    });
  }

  void showGooglePopUp(VoidCallback func) {
    logger.d(isLoggedin.toString());
    if (isLoggedin == false) {
      googleSignInPopUp(context, func);
    } else {
      func();
    }
  }

  @override
  Widget build(BuildContext context) {
    checkSignIn();
    final tabsRouter = AutoTabsRouter.of(context);
    final activeIndex = tabsRouter.activeIndex;
    final isHome = activeIndex == 0;
    final isSearch = activeIndex == 1;
    final isSetups = activeIndex == 2;
    final isProfile = activeIndex == 3;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        boxShadow: [
          BoxShadow(color: const Color(0xFF000000).withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 4)),
        ],
        borderRadius: BorderRadius.circular(500),
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 0, 10),
              child: IconButton(
                tooltip: 'Home',
                padding: EdgeInsets.zero,
                icon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(height: isHome ? 9 : 0),
                    Icon(JamIcons.home_f, color: Theme.of(context).colorScheme.secondary),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(500),
                        color: isHome
                            ? Theme.of(context).colorScheme.error == Colors.black
                                ? Colors.white24
                                : Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.secondary,
                      ),
                      margin: isHome ? const EdgeInsets.all(3) : EdgeInsets.zero,
                      width: isHome ? _paddingAnimation.value : 0,
                      height: isHome ? 3 : 0,
                    ),
                  ],
                ),
                onPressed: () {
                  if (isHome) {
                    logger.d("Currently on Home");
                  } else {
                    tabsRouter.setActiveIndex(0);
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
              child: IconButton(
                tooltip: 'Search',
                padding: EdgeInsets.zero,
                icon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(height: isSearch ? 9 : 0),
                    Icon(JamIcons.search, color: Theme.of(context).colorScheme.secondary),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(500),
                        color: isSearch
                            ? Theme.of(context).colorScheme.error == Colors.black
                                ? Colors.white24
                                : Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.secondary,
                      ),
                      margin: isSearch ? const EdgeInsets.all(3) : EdgeInsets.zero,
                      width: isSearch ? _paddingAnimation.value : 0,
                      height: isSearch ? 3 : 0,
                    ),
                  ],
                ),
                onPressed: () {
                  if (isSearch) {
                    logger.d("Currently on Search");
                  } else {
                    tabsRouter.setActiveIndex(1);
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 45,
                    width: 45,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.error == Colors.black
                            ? Colors.black
                            : Theme.of(context).colorScheme.error,
                        width: Theme.of(context).colorScheme.error == Colors.black ? 1 : 0,
                      ),
                      color: Theme.of(context).colorScheme.error == Colors.black
                          ? Colors.white24
                          : Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(500),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Upload',
                    padding: EdgeInsets.zero,
                    icon: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(height: 0),
                        Icon(
                          JamIcons.plus,
                          color: Theme.of(context).colorScheme.error == Colors.black
                              ? Colors.white
                              : Theme.of(context).colorScheme.secondary,
                        ),
                        Container(height: 0),
                      ],
                    ),
                    onPressed: () {
                      showGooglePopUp(() {
                        showModalBottomSheet(
                          isScrollControlled: true,
                          context: context,
                          builder: (context) => const UploadBottomPanel(),
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
              child: IconButton(
                tooltip: 'Setups',
                padding: EdgeInsets.zero,
                icon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(height: isSetups ? 9 : 0),
                    Icon(JamIcons.instant_picture_f, color: Theme.of(context).colorScheme.secondary),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(500),
                        color: isSetups
                            ? Theme.of(context).colorScheme.error == Colors.black
                                ? Colors.white24
                                : Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.secondary,
                      ),
                      margin: isSetups ? const EdgeInsets.all(3) : EdgeInsets.zero,
                      width: isSetups ? _paddingAnimation.value : 0,
                      height: isSetups ? 3 : 0,
                    ),
                  ],
                ),
                onPressed: () {
                  if (isSetups) {
                    logger.d("Currently on Setups");
                  } else {
                    tabsRouter.setActiveIndex(2);
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 18, 10),
              child: IconButton(
                tooltip: 'Profile',
                padding: EdgeInsets.zero,
                icon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(height: isProfile ? 9 : 0),
                    if (globals.prismUser.loggedIn == true)
                      imageNotFound
                          ? Icon(JamIcons.user_circle, color: Theme.of(context).primaryColor)
                          : Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(500),
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              child: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.secondary,
                                radius: 11,
                                backgroundImage: NetworkImage(globals.prismUser.profilePhoto),
                                onBackgroundImageError: (_, st) {
                                  setState(() {
                                    imageNotFound = true;
                                  });
                                },
                              ),
                            )
                    else
                      Icon(JamIcons.cog_f, color: Theme.of(context).colorScheme.secondary),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(500),
                        color: isProfile
                            ? Theme.of(context).colorScheme.error == Colors.black
                                ? Colors.white24
                                : Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.secondary,
                      ),
                      margin: isProfile ? const EdgeInsets.all(3) : EdgeInsets.zero,
                      width: isProfile ? _paddingAnimation.value : 0,
                      height: isProfile ? 3 : 0,
                    ),
                  ],
                ),
                onPressed: () {
                  if (isProfile) {
                    logger.d("Currently on Profile");
                  } else {
                    tabsRouter.setActiveIndex(3);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UploadBottomPanel extends StatefulWidget {
  const UploadBottomPanel({super.key});

  @override
  _UploadBottomPanelState createState() => _UploadBottomPanelState();
}

class _UploadBottomPanelState extends State<UploadBottomPanel> {
  File? _wallpaper;
  final picker = ImagePicker();
  @override
  void initState() {
    super.initState();
  }

  Future getImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (!mounted) {
      return;
    }
    if (pickedFile != null) {
      setState(() {
        _wallpaper = File(pickedFile.path);
      });
      final router = context.router;
      Navigator.pop(context);
      router.push(EditWallRoute(arguments: [_wallpaper]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.85;
    return Container(
      height: MediaQuery.of(context).size.height / 1.5 > 500 ? MediaQuery.of(context).size.height / 1.5 : 500,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  height: 5,
                  width: 30,
                  decoration: BoxDecoration(
                    color: Theme.of(context).hintColor,
                    borderRadius: BorderRadius.circular(500),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text("Upload", style: Theme.of(context).textTheme.displayMedium),
          const Spacer(flex: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GestureDetector(
                      onTap: () async {
                        int dailyWallUpload = main.prefs.get("dailyWallUpload", defaultValue: 0) as int;
                        if (main.prefs.get('date') != DateFormat("yy-MM-dd").format(DateTime.now())) {
                          dailyWallUpload = 0;
                        }
                        main.prefs.put('date', DateFormat("yy-MM-dd").format(DateTime.now()));
                        if (globals.prismUser.premium == false) {
                          if (dailyWallUpload < 5) {
                            await getImage();
                          } else {
                            toasts.codeSend("Free users can only upload 5 walls a day.");
                            if (globals.prismUser.loggedIn == false) {
                              googleSignInPopUp(context, () {
                                final router = context.router;
                                Navigator.of(context).pop();
                                router.push(const UpgradeRoute());
                              });
                            } else {
                              final router = context.router;
                              Navigator.of(context).pop();
                              router.push(const UpgradeRoute());
                            }
                          }
                        } else {
                          await getImage();
                        }
                      },
                      child: SizedBox(
                        width: width / 2 - 20,
                        height: width / 2 / 0.6625,
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            Container(
                              width: width / 2 - 14,
                              height: width / 2 / 0.6625,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                                border: Border.all(color: Theme.of(context).colorScheme.error, width: 3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Opacity(
                                  opacity: 1,
                                  child: Image.asset('assets/images/wallpaper.jpg', fit: BoxFit.cover),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 60.0),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Theme.of(context).colorScheme.error),
                                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Icon(JamIcons.plus, color: Theme.of(context).colorScheme.error, size: 40),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Text(
                    "Wallpapers",
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GestureDetector(
                      onTap: () {
                        final router = context.router;
                        Navigator.pop(context);
                        router.push(const SetupGuidelinesRoute());
                      },
                      child: SizedBox(
                        width: width / 2 - 20,
                        height: width / 2 / 0.6625,
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            Container(
                              width: width / 2 - 14,
                              height: width / 2 / 0.6625,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                                border: Border.all(color: Theme.of(context).colorScheme.error, width: 3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Opacity(
                                  opacity: 1,
                                  child: Image.asset('assets/images/setup.jpg', fit: BoxFit.cover),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 60.0),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Theme.of(context).colorScheme.error),
                                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Icon(JamIcons.plus, color: Theme.of(context).colorScheme.error, size: 40),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Text(
                    "Setups",
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(flex: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Text(
                "Please only upload high-quality original wallpapers and setups. Please do not upload wallpapers from other apps. You can also report wallpapers or setups by clicking the copyright button after opening them.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.secondary),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

int adHeight = 80;

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget(this.bottom, {super.key});
  static const AdRequest request = AdRequest(
    nonPersonalizedAds: false,
    keywords: <String>['Apps', 'Games', 'Mobile', 'Game'],
  );
  final double bottom;
  @override
  _AdBannerWidgetState createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _anchoredBanner;

  bool _loadingAnchoredBanner = false;

  Future<void> _createAnchoredBanner(BuildContext context) async {
    setState(() {
      _anchoredBanner = null;
    });
    final AnchoredAdaptiveBannerAdSize? size = await AdSize.getAnchoredAdaptiveBannerAdSize(
      Orientation.portrait,
      MediaQuery.of(context).size.width.truncate(),
    );

    if (size == null) {
      logger.d('Unable to get height of anchored banner.');
      return;
    } else {
      if (mounted) {
        setState(() {
          adHeight = size.height;
        });
      }
      logger.d('ad height is equal to $adHeight');
    }

    final BannerAd banner = BannerAd(
      size: size,
      request: AdBannerWidget.request,
      adUnitId: kReleaseMode ? "ca-app-pub-4649644680694757/8480286673" : "ca-app-pub-3940256099942544/6300978111",
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          logger.d('$BannerAd loaded.');
          setState(() {
            _anchoredBanner = ad as BannerAd?;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          logger.d('$BannerAd failedToLoad: $error');
          setState(() {
            adHeight = 0;
          });
          ad.dispose();
        },
        onAdOpened: (Ad ad) => logger.d('$BannerAd onAdOpened.'),
        onAdClosed: (Ad ad) => logger.d('$BannerAd onAdClosed.'),
      ),
    );
    return banner.load();
  }

  @override
  void dispose() {
    _anchoredBanner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      child: Builder(
        builder: (context) {
          if (!_loadingAnchoredBanner && widget.bottom != 10) {
            _loadingAnchoredBanner = true;
            _createAnchoredBanner(context);
          }
          return adHeight == 0
              ? Container(width: MediaQuery.of(context).size.width, height: 60, color: Theme.of(context).primaryColor)
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Theme.of(context).primaryColor.withValues(alpha: 0), Theme.of(context).primaryColor],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  width: _anchoredBanner != null
                      ? _anchoredBanner!.size.width.toDouble()
                      : MediaQuery.of(context).size.width,
                  height: adHeight * 1.0,
                  child: _anchoredBanner != null
                      ? Align(
                          alignment: Alignment.bottomCenter,
                          child: AdWidget(ad: _anchoredBanner!, key: ValueKey(_anchoredBanner!.adUnitId)),
                        )
                      : Container(),
                );
        },
      ),
    );
  }
}
