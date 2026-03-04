import 'dart:ui';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/wallpaper/setup_wallpaper_extensions.dart';
import 'package:Prism/core/wallpaper/setup_wallpaper_value.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/animated/favouriteIcon.dart';
import 'package:Prism/core/widgets/animated/showUp.dart';
import 'package:Prism/core/widgets/home/core/collapsedPanel.dart';
import 'package:Prism/core/widgets/menuButton/setWallpaperButton.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/data/informatics/dataManager.dart';
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/favourite_setups/domain/entities/favourite_setup_entity.dart';
import 'package:Prism/features/favourite_setups/domain/entities/favourite_setup_mappers.dart';
import 'package:Prism/features/favourite_setups/views/favourite_setups_bloc_adapter.dart';
import 'package:Prism/features/public_profile/domain/entities/public_profile_setup_entity.dart';
import 'package:Prism/features/public_profile/views/public_profile_bloc_adapter.dart';
import 'package:Prism/features/setups/views/widgets/clock_setup_overlay.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_io/hive_io.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

@RoutePage()
class UserProfileSetupViewScreen extends StatefulWidget {
  const UserProfileSetupViewScreen({super.key, required this.setupIndex});

  final int setupIndex;

  @override
  _UserProfileSetupViewScreenState createState() => _UserProfileSetupViewScreenState();
}

class _UserProfileSetupViewScreenState extends State<UserProfileSetupViewScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int? index;
  String? thumb;
  bool isLoading = true;
  PanelController panelController = PanelController();
  late AnimationController shakeController;
  bool panelCollapsed = true;
  Future<String>? _futureView;
  late Box box;

  PublicProfileSetupEntity get _setup => context.publicProfileAdapter(listen: false).userProfileSetups![index!];

  SetupWallpaperValue get _wallpaperValue => _setup.wallpaperValue;

  bool get _hasWallId => (_setup.wallId ?? '').isNotEmpty;

  Future<void> _openSetupWallpaper() async {
    if (!_wallpaperValue.isEncoded) {
      if (!_hasWallId) {
        logger.d('Id Not Found!');
        await openPrismLink(context, _wallpaperValue.primaryUrl);
        return;
      }
      await context.router.push(
        ShareWallpaperViewRoute(
          wallId: _setup.wallId!,
          source: _setup.source ?? WallpaperSource.unknown,
          wallpaperUrl: _wallpaperValue.primaryUrl,
          thumbnailUrl: _setup.wallpaperThumb?.isNotEmpty == true ? _setup.wallpaperThumb! : _wallpaperValue.primaryUrl,
        ),
      );
      return;
    }
    if (_wallpaperValue.hasDeepLink) {
      await openPrismLink(context, _wallpaperValue.deepLinkUrl!);
    }
  }

  @override
  void initState() {
    shakeController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    index = widget.setupIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateViewsSetup(_setup.id.toString().toUpperCase());
      _futureView = getViewsSetup(_setup.id.toString().toUpperCase());
    });
    isLoading = true;
    box = Hive.box('localFav');
    super.initState();
  }

  @override
  void dispose() {
    shakeController.dispose();
    super.dispose();
  }

  Future<void> onFavSetup(FavouriteSetupEntity setup) async {
    setState(() {
      isLoading = true;
    });
    context.favouriteSetupsAdapter(listen: false).favCheck(setup).then((value) {
      analytics.track(SetupFavStatusChangedEvent(setupId: setup.id));
      setState(() {
        isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> offsetAnimation =
        Tween(begin: 0.0, end: 48.0).chain(CurveTween(curve: Curves.easeOutCubic)).animate(shakeController)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              shakeController.reverse();
            }
          });
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).primaryColor,
      body: SlidingUpPanel(
        backdropEnabled: true,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        boxShadow: const [],
        collapsed: CollapsedPanel(panelCollapsed: panelCollapsed, panelController: panelController),
        minHeight: MediaQuery.of(context).size.height / 20,
        parallaxEnabled: true,
        parallaxOffset: 0.00,
        color: Colors.transparent,
        maxHeight: MediaQuery.of(context).size.height * .70 > 600 ? MediaQuery.of(context).size.height * .70 : 600,
        controller: panelController,
        onPanelOpened: () {
          setState(() {
            panelCollapsed = false;
          });
        },
        onPanelClosed: () {
          setState(() {
            panelCollapsed = true;
          });
        },
        panel: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          height: MediaQuery.of(context).size.height * .70 > 600 ? MediaQuery.of(context).size.height * .70 : 600,
          width: MediaQuery.of(context).size.width,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 750),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: panelCollapsed
                      ? Theme.of(context).primaryColor.withValues(alpha: 1)
                      : Theme.of(context).primaryColor.withValues(alpha: .5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: AnimatedOpacity(
                          duration: Duration.zero,
                          opacity: panelCollapsed ? 0.0 : 1.0,
                          child: GestureDetector(
                            onTap: () {
                              panelController.close();
                            },
                            child: Icon(JamIcons.chevron_down, color: Theme.of(context).colorScheme.secondary),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(35, 0, 35, 5),
                            child: panelCollapsed
                                ? Container()
                                : ShowUpTransition(
                                    forward: true,
                                    slideSide: SlideFromSlide.bottom,
                                    child: Text(
                                      context
                                          .publicProfileAdapter()
                                          .userProfileSetups![index!]
                                          .name
                                          .toString()
                                          .toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.fade,
                                      style: Theme.of(context).textTheme.displayLarge!.copyWith(
                                        fontSize: 30,
                                        color: Theme.of(context).colorScheme.secondary,
                                      ),
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(35, 0, 35, 0),
                            child: panelCollapsed
                                ? Container()
                                : ShowUpTransition(
                                    forward: true,
                                    slideSide: SlideFromSlide.bottom,
                                    delay: const Duration(milliseconds: 50),
                                    child: Text(
                                      _setup.desc.toString(),
                                      maxLines: 2,
                                      overflow: TextOverflow.fade,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge!.copyWith(color: Theme.of(context).colorScheme.secondary),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(35, 0, 35, 10),
                        child: panelCollapsed
                            ? Container()
                            : ShowUpTransition(
                                forward: true,
                                delay: const Duration(milliseconds: 100),
                                slideSide: SlideFromSlide.bottom,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        SizedBox(
                                          width: MediaQuery.of(context).size.width * 0.36,
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(0, 5, 0, 5),
                                            child: Row(
                                              children: [
                                                Text(
                                                  context
                                                      .publicProfileAdapter()
                                                      .userProfileSetups![index!]
                                                      .id
                                                      .toString()
                                                      .toUpperCase(),
                                                  overflow: TextOverflow.fade,
                                                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                                    color: Theme.of(context).colorScheme.secondary,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                                  child: Container(
                                                    height: 16,
                                                    color: Theme.of(context).colorScheme.secondary,
                                                    width: 2,
                                                  ),
                                                ),
                                                FutureBuilder(
                                                  future: _futureView,
                                                  builder: (context, snapshot) {
                                                    switch (snapshot.connectionState) {
                                                      case ConnectionState.waiting:
                                                        return Text(
                                                          "",
                                                          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                                            color: Theme.of(context).colorScheme.secondary,
                                                            fontSize: 16,
                                                          ),
                                                        );
                                                      case ConnectionState.none:
                                                        return Text(
                                                          "",
                                                          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                                            color: Theme.of(context).colorScheme.secondary,
                                                            fontSize: 16,
                                                          ),
                                                        );
                                                      default:
                                                        if (snapshot.hasError) {
                                                          return Text(
                                                            "",
                                                            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                                              color: Theme.of(context).colorScheme.secondary,
                                                              fontSize: 16,
                                                            ),
                                                          );
                                                        } else {
                                                          return Text(
                                                            "${snapshot.data} views",
                                                            overflow: TextOverflow.fade,
                                                            softWrap: false,
                                                            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                                              color: Theme.of(context).colorScheme.secondary,
                                                              fontSize: 16,
                                                            ),
                                                          );
                                                        }
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () async {
                                            await createCopyrightLink(
                                              true,
                                              context,
                                              index: index.toString(),
                                              name: _setup.name.toString(),
                                              thumbUrl: _setup.image.toString(),
                                            );
                                          },
                                          child: Row(
                                            children: [
                                              Icon(
                                                JamIcons.info,
                                                size: 20,
                                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: .7),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                "Report",
                                                overflow: TextOverflow.fade,
                                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                  decoration: TextDecoration.underline,
                                                  color: Theme.of(context).colorScheme.secondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: <Widget>[
                                        SizedBox(
                                          width: 150,
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Stack(
                                              children: [
                                                Align(
                                                  alignment: Alignment.topRight,
                                                  child: ActionChip(
                                                    label: Text(
                                                      _setup.by.toString(),
                                                      overflow: TextOverflow.fade,
                                                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                        color: Theme.of(context).colorScheme.secondary,
                                                      ),
                                                    ),
                                                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                                                    avatar: CircleAvatar(
                                                      backgroundImage: CachedNetworkImageProvider(
                                                        _setup.userPhoto.toString(),
                                                      ),
                                                    ),
                                                    labelPadding: const EdgeInsets.fromLTRB(7, 3, 7, 3),
                                                    onPressed: () {
                                                      context.router.push(
                                                        ProfileRoute(profileIdentifier: _setup.email.toString()),
                                                      );
                                                    },
                                                  ),
                                                ),
                                                if (app_state.verifiedUsers.contains(_setup.email.toString()))
                                                  Align(
                                                    alignment: Alignment.topRight,
                                                    child: SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: SvgPicture.string(
                                                        verifiedIcon.replaceAll(
                                                          "E57697",
                                                          Theme.of(context).colorScheme.error == Colors.black
                                                              ? "E57697"
                                                              : Theme.of(context).colorScheme.error
                                                                    .toString()
                                                                    .replaceAll("Color(0xff", "")
                                                                    .replaceAll(")", ""),
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  Container(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    Expanded(
                      flex: 16,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(35, 0, 35, 0),
                        child: _setup.widget == "" || _setup.widget == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SetupDetailsTile(
                                    isInstalled: Future.value(false),
                                    onTap: _openSetupWallpaper,
                                    tileText: _wallpaperValue.tileText(wallId: _setup.wallId),
                                    tileType: "Wallpaper",
                                    panelCollapsed: panelCollapsed,
                                    delay: const Duration(milliseconds: 150),
                                  ),
                                  SetupDetailsTile(
                                    isInstalled: Future.value(false),
                                    onTap: () async {
                                      openPrismLink(context, _setup.iconUrl.toString());
                                    },
                                    tileText: _setup.icon.toString(),
                                    tileType: "Icons",
                                    panelCollapsed: panelCollapsed,
                                    delay: const Duration(milliseconds: 200),
                                  ),
                                ],
                              )
                            : _setup.widget2 == "" || _setup.widget2 == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SetupDetailsTile(
                                    isInstalled: Future.value(false),
                                    onTap: _openSetupWallpaper,
                                    tileText: _wallpaperValue.tileText(wallId: _setup.wallId),
                                    tileType: "Wallpaper",
                                    panelCollapsed: panelCollapsed,
                                    delay: const Duration(milliseconds: 150),
                                  ),
                                  SetupDetailsTile(
                                    isInstalled: Future.value(false),
                                    onTap: () async {
                                      openPrismLink(context, _setup.iconUrl.toString());
                                    },
                                    tileText: _setup.icon.toString(),
                                    tileType: "Icons",
                                    panelCollapsed: panelCollapsed,
                                    delay: const Duration(milliseconds: 200),
                                  ),
                                  SetupDetailsTile(
                                    isInstalled: Future.value(false),
                                    onTap: () async {
                                      openPrismLink(context, _setup.widgetUrl.toString());
                                    },
                                    tileText: _setup.widget.toString(),
                                    tileType: "Widget",
                                    panelCollapsed: panelCollapsed,
                                    delay: const Duration(milliseconds: 250),
                                  ),
                                ],
                              )
                            : Scrollbar(
                                radius: const Radius.circular(500),
                                thickness: 5,
                                child: ListView(
                                  children: [
                                    SetupDetailsTile(
                                      isInstalled: Future.value(false),
                                      onTap: _openSetupWallpaper,
                                      tileText: _wallpaperValue.tileText(wallId: _setup.wallId),
                                      tileType: "Wallpaper",
                                      panelCollapsed: panelCollapsed,
                                      delay: const Duration(milliseconds: 150),
                                    ),
                                    SetupDetailsTile(
                                      isInstalled: Future.value(false),
                                      onTap: () async {
                                        openPrismLink(context, _setup.iconUrl.toString());
                                      },
                                      tileText: _setup.icon.toString(),
                                      tileType: "Icons",
                                      panelCollapsed: panelCollapsed,
                                      delay: const Duration(milliseconds: 200),
                                    ),
                                    SetupDetailsTile(
                                      isInstalled: Future.value(false),
                                      onTap: () async {
                                        openPrismLink(context, _setup.widgetUrl.toString());
                                      },
                                      tileText: _setup.widget.toString(),
                                      tileType: "Widget",
                                      panelCollapsed: panelCollapsed,
                                      delay: const Duration(milliseconds: 250),
                                    ),
                                    SetupDetailsTile(
                                      isInstalled: Future.value(false),
                                      onTap: () async {
                                        openPrismLink(context, _setup.widgetUrl2.toString());
                                      },
                                      tileText: _setup.widget2.toString(),
                                      tileType: "Widget",
                                      panelCollapsed: panelCollapsed,
                                      delay: const Duration(milliseconds: 300),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          ModifiedDownloadButton(index: index),
                          if (!hideSetWallpaperUi) ModifiedSetWallpaperButton(index: index),
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .25),
                                  blurRadius: 4,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              borderRadius: BorderRadius.circular(500),
                            ),
                            padding: const EdgeInsets.all(17),
                            child: FavoriteIcon(
                              valueChanged: () {
                                if (app_state.prismUser.loggedIn == false) {
                                  googleSignInPopUp(context, () {
                                    onFavSetup(_setup.toFavouriteSetupEntity());
                                  });
                                } else {
                                  onFavSetup(_setup.toFavouriteSetupEntity());
                                }
                              },
                              iconColor: Theme.of(context).colorScheme.secondary,
                              iconSize: 30,
                              isFavorite: box.get(_setup.id.toString(), defaultValue: false) as bool,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              createSetupDynamicLink(
                                index.toString(),
                                _setup.name.toString(),
                                _setup.image.toString(),
                                context: context,
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: .25),
                                    blurRadius: 4,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                borderRadius: BorderRadius.circular(500),
                              ),
                              padding: const EdgeInsets.all(17),
                              child: Icon(JamIcons.share_alt, color: Theme.of(context).colorScheme.secondary, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Stack(
          children: <Widget>[
            AnimatedBuilder(
              animation: offsetAnimation,
              builder: (buildContext, child) {
                if (offsetAnimation.value < 0.0) {
                  logger.d('${offsetAnimation.value + 8.0}');
                }
                return GestureDetector(
                  onPanUpdate: (details) {
                    if (details.delta.dy < -10) {
                      panelController.open();
                    }
                  },
                  onLongPress: () {
                    HapticFeedback.vibrate();
                    shakeController.forward(from: 0.0);
                  },
                  onTap: () {
                    HapticFeedback.vibrate();
                    shakeController.forward(from: 0.0);
                  },
                  child: CachedNetworkImage(
                    imageUrl: _setup.image.toString(),
                    imageBuilder: (context, imageProvider) => Container(
                      margin: EdgeInsets.symmetric(
                        vertical: offsetAnimation.value * 1.25,
                        horizontal: offsetAnimation.value / 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(offsetAnimation.value),
                        image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                      ),
                    ),
                    progressIndicatorBuilder: (context, url, downloadProgress) => Stack(
                      children: <Widget>[
                        const SizedBox.expand(child: Text("", overflow: TextOverflow.fade)),
                        Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.error),
                            value: downloadProgress.progress,
                          ),
                        ),
                      ],
                    ),
                    errorWidget: (context, url, error) =>
                        Center(child: Icon(JamIcons.close_circle_f, color: Theme.of(context).colorScheme.secondary)),
                  ),
                );
              },
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.fromLTRB(8.0, app_state.notchSize! + 8, 8, 8),
                child: IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  color: Theme.of(context).colorScheme.secondary,
                  icon: const Icon(JamIcons.chevron_left),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.fromLTRB(8.0, app_state.notchSize! + 8, 8, 8),
                child: IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) {
                          animation = Tween(begin: 0.0, end: 1.0).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SetupOverlay(link: _setup.image.toString()),
                          );
                        },
                        fullscreenDialog: true,
                        opaque: false,
                      ),
                    );
                  },
                  color: Theme.of(context).colorScheme.secondary,
                  icon: const Icon(JamIcons.arrow_up_right),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SetupDetailsTile extends StatelessWidget {
  final bool panelCollapsed;
  final Duration delay;
  final String tileType;
  final String tileText;
  final Function onTap;
  final Future<bool> isInstalled;
  const SetupDetailsTile({
    super.key,
    required this.delay,
    required this.tileText,
    required this.tileType,
    required this.onTap,
    required this.panelCollapsed,
    required this.isInstalled,
  });

  @override
  Widget build(BuildContext context) {
    return panelCollapsed
        ? Container()
        : ShowUpTransition(
            forward: true,
            delay: delay,
            slideSide: SlideFromSlide.bottom,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: 80,
                  child: Stack(
                    children: [
                      Positioned(
                        bottom: -55,
                        left: 0,
                        child: Text(
                          tileType,
                          overflow: TextOverflow.fade,
                          style: TextStyle(
                            fontSize: 140,
                            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 10,
                                child: Text(
                                  tileText,
                                  overflow: TextOverflow.fade,
                                  style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                                ),
                              ),
                              Expanded(
                                child: FutureBuilder<bool>(
                                  future: isInstalled,
                                  initialData: false,
                                  builder: (BuildContext context, AsyncSnapshot snapshot) {
                                    if (snapshot.data == true) {
                                      return Icon(JamIcons.check, color: Theme.of(context).colorScheme.secondary);
                                    }
                                    return Icon(JamIcons.chevron_right, color: Theme.of(context).colorScheme.secondary);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              splashColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                              highlightColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                              onTap: () {
                                onTap();
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
  }
}

class ModifiedDownloadButton extends StatelessWidget {
  final int? index;
  const ModifiedDownloadButton({required this.index});
  @override
  Widget build(BuildContext context) {
    final setup = context.publicProfileAdapter(listen: false).userProfileSetups![index!];
    final wallpaper = setup.wallpaperValue;
    final hasWallId = (setup.wallId ?? '').isNotEmpty;
    return !wallpaper.isEncoded
        ? hasWallId
              ? DownloadButton(link: wallpaper.primaryUrl, colorChanged: false)
              : GestureDetector(
                  onTap: () async {
                    openPrismLink(context, wallpaper.primaryUrl);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .25),
                          blurRadius: 4,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(500),
                    ),
                    padding: const EdgeInsets.all(17),
                    child: Icon(JamIcons.download, color: Theme.of(context).colorScheme.secondary, size: 20),
                  ),
                )
        : GestureDetector(
            onTap: () async {
              openPrismLink(context, wallpaper.deepLinkUrl ?? wallpaper.primaryUrl);
            },
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 4, offset: const Offset(0, 4)),
                ],
                borderRadius: BorderRadius.circular(500),
              ),
              padding: const EdgeInsets.all(17),
              child: Icon(JamIcons.download, color: Theme.of(context).colorScheme.secondary, size: 20),
            ),
          );
  }
}

class ModifiedSetWallpaperButton extends StatelessWidget {
  final int? index;
  const ModifiedSetWallpaperButton({required this.index});
  @override
  Widget build(BuildContext context) {
    final setup = context.publicProfileAdapter(listen: false).userProfileSetups![index!];
    final wallpaper = setup.wallpaperValue;
    final hasWallId = (setup.wallId ?? '').isNotEmpty;
    return !wallpaper.isEncoded
        ? hasWallId
              ? SetWallpaperButton(url: wallpaper.primaryUrl, colorChanged: false)
              : GestureDetector(
                  onTap: () async {
                    openPrismLink(context, wallpaper.primaryUrl);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .25),
                          blurRadius: 4,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(500),
                    ),
                    padding: const EdgeInsets.all(17),
                    child: Icon(JamIcons.picture, color: Theme.of(context).colorScheme.secondary, size: 20),
                  ),
                )
        : GestureDetector(
            onTap: () async {
              openPrismLink(context, wallpaper.deepLinkUrl ?? wallpaper.primaryUrl);
            },
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 4, offset: const Offset(0, 4)),
                ],
                borderRadius: BorderRadius.circular(500),
              ),
              padding: const EdgeInsets.all(17),
              child: Icon(JamIcons.picture, color: Theme.of(context).colorScheme.secondary, size: 20),
            ),
          );
  }
}
