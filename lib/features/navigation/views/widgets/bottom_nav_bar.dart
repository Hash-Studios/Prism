import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/purchases/upload_quota.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/features/navigation/views/widgets/inherited_scroll_controller_provider.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart' as floating;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker/image_picker.dart';

class BottomBar extends StatelessWidget {
  final Widget? child;
  const BottomBar({this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return floating.BottomBar(
      iconTooltip: 'Scroll to top',
      iconDecoration: BoxDecoration(color: Theme.of(context).colorScheme.secondary, shape: BoxShape.circle),
      barDecoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(500)),
      child: const _BottomNavBar(),
      body: (context, controller) => PrimaryScrollController(
        controller: controller,
        child: InheritedDataProvider(scrollController: controller, child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

class _BottomNavBar extends StatefulWidget {
  const _BottomNavBar();

  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<_BottomNavBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller2;
  late Animation<double> _paddingAnimation;
  bool? isLoggedin = false;
  bool imageNotFound = false;

  NavTabValue _tabForIndex(int index) {
    switch (index) {
      case 0:
        return NavTabValue.home;
      case 1:
        return NavTabValue.search;
      case 2:
        return NavTabValue.setups;
      case 3:
        return NavTabValue.profile;
      default:
        return NavTabValue.home;
    }
  }

  void _trackTabSelection({required int fromIndex, required int toIndex}) {
    analytics.track(NavTabSelectedEvent(fromTab: _tabForIndex(fromIndex), toTab: _tabForIndex(toIndex)));
  }

  @override
  void initState() {
    super.initState();
    checkSignIn();
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
      isLoggedin = app_state.prismUser.loggedIn;
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
    TabsRouter tabsRouter;
    try {
      tabsRouter = AutoTabsRouter.of(context);
    } catch (_) {
      return const SizedBox.shrink();
    }
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
                    _trackTabSelection(fromIndex: activeIndex, toIndex: 0);
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
                    _trackTabSelection(fromIndex: activeIndex, toIndex: 1);
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
                      analytics.track(
                        const UploadActionSelectedEvent(
                          action: AnalyticsActionValue.uploadSheetOpened,
                          entrypoint: EntryPointValue.bottomNav,
                        ),
                      );
                      showGooglePopUp(() {
                        showModalBottomSheet(
                          isScrollControlled: true,
                          context: context,
                          builder: (context) => const _UploadBottomPanel(),
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
                    _trackTabSelection(fromIndex: activeIndex, toIndex: 2);
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
                    if (app_state.prismUser.loggedIn == true)
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
                                backgroundImage: NetworkImage(app_state.prismUser.profilePhoto),
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
                    _trackTabSelection(fromIndex: activeIndex, toIndex: 3);
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

class _UploadBottomPanel extends StatefulWidget {
  const _UploadBottomPanel();

  @override
  _UploadBottomPanelState createState() => _UploadBottomPanelState();
}

class _UploadBottomPanelState extends State<_UploadBottomPanel> {
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
      router.push(EditWallRoute(image: _wallpaper!));
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
                        analytics.track(
                          const UploadActionSelectedEvent(
                            action: AnalyticsActionValue.uploadWallpaperSelected,
                            entrypoint: EntryPointValue.bottomNav,
                          ),
                        );
                        if (app_state.prismUser.premium != true && !UploadQuota.hasFreeUploadQuotaRemaining()) {
                          toasts.codeSend(
                            "Free users can upload ${UploadQuota.freeUploadsPerWeek} wallpapers per week.",
                          );
                          if (mounted) {
                            Navigator.of(context).pop();
                            await PaywallOrchestrator.instance.present(
                              context,
                              placement: PaywallPlacement.uploadLimitReached,
                              source: 'upload_wallpaper_limit_reached',
                            );
                          }
                          return;
                        }
                        await getImage();
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
                      onTap: () async {
                        analytics.track(
                          const UploadActionSelectedEvent(
                            action: AnalyticsActionValue.uploadSetupSelected,
                            entrypoint: EntryPointValue.bottomNav,
                          ),
                        );
                        if (!app_state.prismUser.premium) {
                          Navigator.pop(context);
                          await PaywallOrchestrator.instance.present(
                            context,
                            placement: PaywallPlacement.blockedSetupCreate,
                            source: 'upload_setup_blocked',
                          );
                          return;
                        }
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

class _AdBannerWidget extends StatefulWidget {
  const _AdBannerWidget(this.bottom);
  static const AdRequest request = AdRequest(
    nonPersonalizedAds: false,
    keywords: <String>['Apps', 'Games', 'Mobile', 'Game'],
  );
  final double bottom;
  @override
  _AdBannerWidgetState createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<_AdBannerWidget> {
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
      request: _AdBannerWidget.request,
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
