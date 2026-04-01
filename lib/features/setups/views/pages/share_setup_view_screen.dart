import 'dart:ui';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/wallpaper/setup_wallpaper_extensions.dart';
import 'package:Prism/core/wallpaper/setup_wallpaper_value.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/animated/favouriteIcon.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/core/widgets/animated/showUp.dart';
import 'package:Prism/core/widgets/home/core/collapsedPanel.dart';
import 'package:Prism/core/widgets/menuButton/setWallpaperButton.dart';
import 'package:Prism/core/widgets/popup/copyrightPopUp.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/favourite_setups/domain/entities/favourite_setup_entity.dart';
import 'package:Prism/features/favourite_setups/domain/entities/favourite_setup_mappers.dart';
import 'package:Prism/features/favourite_setups/views/favourite_setups_bloc_adapter.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:Prism/features/setups/views/setups_bloc_adapter.dart' as sdata;
import 'package:Prism/features/setups/views/widgets/clock_setup_overlay.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:animations/animations.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

@RoutePage()
class ShareSetupViewScreen extends StatefulWidget {
  const ShareSetupViewScreen({super.key, @PathParam('setupName') required this.setupName, this.thumbnailUrl = ''});

  final String setupName;
  final String thumbnailUrl;

  @override
  _ShareSetupViewScreenState createState() => _ShareSetupViewScreenState();
}

class _ShareSetupViewScreenState extends State<ShareSetupViewScreen> with SingleTickerProviderStateMixin {
  final FavoritesLocalDataSource _favoritesLocal = getIt<FavoritesLocalDataSource>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? name;
  String? image;
  Future<SetupEntity?>? _future;
  bool isLoading = true;
  List<Color>? colors;
  PanelController panelController = PanelController();
  late AnimationController shakeController;
  bool panelCollapsed = true;
  bool? viewCounted;
  Future<String>? _futureView;

  @override
  void initState() {
    viewCounted = false;
    shakeController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    name = widget.setupName;
    image = widget.thumbnailUrl;
    _future = sdata.getSetupFromName(name);
    isLoading = true;
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
      body: FutureBuilder(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<SetupEntity?> snapshot) {
          logger.d(snapshot.connectionState.toString());
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return Center(child: Loader());
            case ConnectionState.none:
              return Center(child: Loader());
            case ConnectionState.active:
              return Center(child: Loader());
            case ConnectionState.done:
              if (snapshot.hasError) {
                return Center(child: Loader());
              } else {
                final setup = snapshot.data ?? sdata.setup;
                if (setup == null) {
                  return Center(child: Loader());
                }
                final SetupWallpaperValue wallpaperValue = setup.wallpaperValue;
                if (viewCounted == false) {
                  _futureView = getIt<ViewStatsRepository>().recordSetupView(setup.id.toUpperCase()).then(
                    (r) => r.fold(onSuccess: (s) => s, onFailure: (_) => '0'),
                  );
                  viewCounted = true;
                }
                return SlidingUpPanel(
                  backdropEnabled: true,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  boxShadow: const [],
                  collapsed: CollapsedPanel(panelCollapsed: panelCollapsed, panelController: panelController),
                  minHeight: MediaQuery.of(context).size.height / 20,
                  parallaxEnabled: true,
                  parallaxOffset: 0.00,
                  color: Colors.transparent,
                  maxHeight: app_state.prismUser.premium == true
                      ? MediaQuery.of(context).size.height * .70 > 600
                            ? MediaQuery.of(context).size.height * .70
                            : 600
                      : 300,
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
                    height: app_state.prismUser.premium == true
                        ? MediaQuery.of(context).size.height * .70 > 600
                              ? MediaQuery.of(context).size.height * .70
                              : 600
                        : 300,
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
                                      child: Icon(
                                        JamIcons.chevron_down,
                                        color: Theme.of(context).colorScheme.secondary,
                                      ),
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
                                                setup.name.toString().toUpperCase(),
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
                                                setup.desc.toString(),
                                                maxLines: 2,
                                                overflow: TextOverflow.fade,
                                                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                                  color: Theme.of(context).colorScheme.secondary,
                                                ),
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
                                                            setup.id.toUpperCase(),
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
                                                                    style: Theme.of(context).textTheme.bodyLarge!
                                                                        .copyWith(
                                                                          color: Theme.of(
                                                                            context,
                                                                          ).colorScheme.secondary,
                                                                          fontSize: 16,
                                                                        ),
                                                                  );
                                                                case ConnectionState.none:
                                                                  return Text(
                                                                    "",
                                                                    style: Theme.of(context).textTheme.bodyLarge!
                                                                        .copyWith(
                                                                          color: Theme.of(
                                                                            context,
                                                                          ).colorScheme.secondary,
                                                                          fontSize: 16,
                                                                        ),
                                                                  );
                                                                default:
                                                                  if (snapshot.hasError) {
                                                                    return Text(
                                                                      "",
                                                                      style: Theme.of(context).textTheme.bodyLarge!
                                                                          .copyWith(
                                                                            color: Theme.of(
                                                                              context,
                                                                            ).colorScheme.secondary,
                                                                            fontSize: 16,
                                                                          ),
                                                                    );
                                                                  } else {
                                                                    return Text(
                                                                      "${snapshot.data} views",
                                                                      overflow: TextOverflow.fade,
                                                                      softWrap: false,
                                                                      style: Theme.of(context).textTheme.bodyLarge!
                                                                          .copyWith(
                                                                            color: Theme.of(
                                                                              context,
                                                                            ).colorScheme.secondary,
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
                                                    onTap: () {
                                                      showModal(
                                                        context: context,
                                                        builder: (BuildContext context) => CopyrightPopUp(
                                                          setup: true,
                                                          shortlink: "Setup ID - ${setup.id}",
                                                        ),
                                                      );
                                                    },
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          JamIcons.info,
                                                          size: 20,
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.secondary.withValues(alpha: .7),
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
                                                                setup.by.toString(),
                                                                overflow: TextOverflow.fade,
                                                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                                  color: Theme.of(context).colorScheme.secondary,
                                                                ),
                                                              ),
                                                              padding: const EdgeInsets.symmetric(
                                                                vertical: 5,
                                                                horizontal: 5,
                                                              ),
                                                              avatar: CircleAvatar(
                                                                backgroundImage: CachedNetworkImageProvider(
                                                                  setup.userPhoto.toString(),
                                                                ),
                                                              ),
                                                              labelPadding: const EdgeInsets.fromLTRB(7, 3, 7, 3),
                                                              onPressed: () {
                                                                context.router.push(
                                                                  ProfileRoute(
                                                                    profileIdentifier: setup.email.toString(),
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                          if (app_state.verifiedUsers.contains(setup.email.toString()))
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
                              if (app_state.prismUser.premium == true)
                                Expanded(
                                  flex: 16,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(35, 0, 35, 0),
                                    child: setup.widget == "" || setup.widget == null
                                        ? Column(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SetupDetailsTile(
                                                isInstalled: Future.value(false),
                                                onTap: () async {
                                                  if (!wallpaperValue.isEncoded) {
                                                    if (setup.wallId == null || setup.wallId == "") {
                                                      logger.d("Id Not Found!");
                                                      openPrismLink(context, wallpaperValue.primaryUrl);
                                                    } else {
                                                      context.router.push(
                                                        WallpaperDetailRoute(
                                                          wallId: setup.wallId.toString(),
                                                          source: setup.source ?? WallpaperSource.prism,
                                                          wallpaperUrl: wallpaperValue.primaryUrl,
                                                          thumbnailUrl: wallpaperValue.primaryUrl,
                                                          analyticsSurface: AnalyticsSurfaceValue.shareSetupViewScreen,
                                                        ),
                                                      );
                                                    }
                                                  } else {
                                                    openPrismLink(context, wallpaperValue.primaryUrl);
                                                  }
                                                },
                                                tileText: wallpaperValue.tileText(wallId: setup.wallId),
                                                tileType: "Wallpaper",
                                                panelCollapsed: panelCollapsed,
                                                delay: const Duration(milliseconds: 150),
                                              ),
                                              SetupDetailsTile(
                                                isInstalled: Future.value(false),
                                                onTap: () async {
                                                  openPrismLink(context, setup.iconUrl.toString());
                                                },
                                                tileText: setup.icon.toString(),
                                                tileType: "Icons",
                                                panelCollapsed: panelCollapsed,
                                                delay: const Duration(milliseconds: 200),
                                              ),
                                            ],
                                          )
                                        : setup.widget2 == "" || setup.widget2 == null
                                        ? Column(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SetupDetailsTile(
                                                isInstalled: Future.value(false),
                                                onTap: () async {
                                                  if (!wallpaperValue.isEncoded) {
                                                    if (setup.wallId == null || setup.wallId == "") {
                                                      logger.d("Id Not Found!");
                                                      openPrismLink(context, wallpaperValue.primaryUrl);
                                                    } else {
                                                      context.router.push(
                                                        WallpaperDetailRoute(
                                                          wallId: setup.wallId.toString(),
                                                          source: setup.source ?? WallpaperSource.prism,
                                                          wallpaperUrl: wallpaperValue.primaryUrl,
                                                          thumbnailUrl: wallpaperValue.primaryUrl,
                                                          analyticsSurface: AnalyticsSurfaceValue.shareSetupViewScreen,
                                                        ),
                                                      );
                                                    }
                                                  } else {
                                                    openPrismLink(context, wallpaperValue.primaryUrl);
                                                  }
                                                },
                                                tileText: wallpaperValue.tileText(wallId: setup.wallId),
                                                tileType: "Wallpaper",
                                                panelCollapsed: panelCollapsed,
                                                delay: const Duration(milliseconds: 150),
                                              ),
                                              SetupDetailsTile(
                                                isInstalled: Future.value(false),
                                                onTap: () async {
                                                  openPrismLink(context, setup.iconUrl.toString());
                                                },
                                                tileText: setup.icon.toString(),
                                                tileType: "Icons",
                                                panelCollapsed: panelCollapsed,
                                                delay: const Duration(milliseconds: 200),
                                              ),
                                              SetupDetailsTile(
                                                isInstalled: Future.value(false),
                                                onTap: () async {
                                                  openPrismLink(context, setup.widgetUrl.toString());
                                                },
                                                tileText: setup.widget.toString(),
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
                                                  onTap: () async {
                                                    if (!wallpaperValue.isEncoded) {
                                                      if (setup.wallId == null || setup.wallId == "") {
                                                        logger.d("Id Not Found!");
                                                        openPrismLink(context, wallpaperValue.primaryUrl);
                                                      } else {
                                                        context.router.push(
                                                          WallpaperDetailRoute(
                                                            wallId: setup.wallId.toString(),
                                                            source: setup.source ?? WallpaperSource.prism,
                                                            wallpaperUrl: wallpaperValue.primaryUrl,
                                                            thumbnailUrl: wallpaperValue.primaryUrl,
                                                            analyticsSurface:
                                                                AnalyticsSurfaceValue.shareSetupViewScreen,
                                                          ),
                                                        );
                                                      }
                                                    } else {
                                                      openPrismLink(context, wallpaperValue.primaryUrl);
                                                    }
                                                  },
                                                  tileText: wallpaperValue.tileText(wallId: setup.wallId),
                                                  tileType: "Wallpaper",
                                                  panelCollapsed: panelCollapsed,
                                                  delay: const Duration(milliseconds: 150),
                                                ),
                                                SetupDetailsTile(
                                                  isInstalled: Future.value(false),
                                                  onTap: () async {
                                                    openPrismLink(context, setup.iconUrl.toString());
                                                  },
                                                  tileText: setup.icon.toString(),
                                                  tileType: "Icons",
                                                  panelCollapsed: panelCollapsed,
                                                  delay: const Duration(milliseconds: 200),
                                                ),
                                                SetupDetailsTile(
                                                  isInstalled: Future.value(false),
                                                  onTap: () async {
                                                    openPrismLink(context, setup.widgetUrl.toString());
                                                  },
                                                  tileText: setup.widget.toString(),
                                                  tileType: "Widget",
                                                  panelCollapsed: panelCollapsed,
                                                  delay: const Duration(milliseconds: 250),
                                                ),
                                                SetupDetailsTile(
                                                  isInstalled: Future.value(false),
                                                  onTap: () async {
                                                    openPrismLink(context, setup.widgetUrl2.toString());
                                                  },
                                                  tileText: setup.widget2.toString(),
                                                  tileType: "Widget",
                                                  panelCollapsed: panelCollapsed,
                                                  delay: const Duration(milliseconds: 300),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                )
                              else
                                Container(),
                              if (app_state.prismUser.premium == true)
                                Expanded(
                                  flex: 5,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: <Widget>[
                                      _ModifiedShareDownloadButton(setup: setup),
                                      if (!hideSetWallpaperUi) _ModifiedShareSetWallpaperButton(setup: setup),
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
                                        child: FavoriteIcon(
                                          tapTargetExtent: 53,
                                          valueChanged: () {
                                            if (app_state.prismUser.loggedIn == false) {
                                              googleSignInPopUp(context, () {
                                                onFavSetup(setup.toFavouriteSetupEntity());
                                              });
                                            } else {
                                              onFavSetup(setup.toFavouriteSetupEntity());
                                            }
                                          },
                                          iconColor: Theme.of(context).colorScheme.secondary,
                                          iconSize: 30,
                                          isFavorite: _favoritesLocal.isSetupFavourite(
                                            app_state.prismUser.id,
                                            setup.id,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Expanded(
                                  flex: 5,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      GestureDetector(
                                        onTap: () async {
                                          if (app_state.prismUser.loggedIn == true) {
                                            await PaywallOrchestrator.instance.present(
                                              context,
                                              placement: PaywallPlacement.mainUpsell,
                                              source: 'share_setup_view',
                                            );
                                          } else {
                                            googleSignInPopUp(context, () {
                                              PaywallOrchestrator.instance.present(
                                                context,
                                                placement: PaywallPlacement.mainUpsell,
                                                source: 'share_setup_view',
                                              );
                                            });
                                          }
                                          toasts.codeSend("This is a premium wallpaper.");
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
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                JamIcons.stop_sign,
                                                color: Theme.of(context).colorScheme.secondary,
                                                size: 30,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "Premium Required",
                                                style: Theme.of(context).textTheme.headlineMedium,
                                              ),
                                            ],
                                          ),
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
                              imageUrl: setup.image,
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
                              errorWidget: (context, url, error) => Center(
                                child: Icon(JamIcons.close_circle_f, color: Theme.of(context).colorScheme.secondary),
                              ),
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
                                      child: SetupOverlay(link: setup.image),
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
                );
              }
          }
        },
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

class _ModifiedShareDownloadButton extends StatelessWidget {
  const _ModifiedShareDownloadButton({required this.setup});

  final SetupEntity setup;

  @override
  Widget build(BuildContext context) {
    final SetupWallpaperValue wallpaperValue = setup.wallpaperValue;
    return !wallpaperValue.isEncoded
        ? setup.wallId != null && setup.wallId != ""
              ? DownloadButton(link: wallpaperValue.primaryUrl, colorChanged: false)
              : GestureDetector(
                  onTap: () async {
                    openPrismLink(context, wallpaperValue.primaryUrl);
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
              openPrismLink(context, wallpaperValue.primaryUrl);
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

class _ModifiedShareSetWallpaperButton extends StatelessWidget {
  const _ModifiedShareSetWallpaperButton({required this.setup});

  final SetupEntity setup;

  @override
  Widget build(BuildContext context) {
    final SetupWallpaperValue wallpaperValue = setup.wallpaperValue;
    return !wallpaperValue.isEncoded
        ? setup.wallId != null && setup.wallId != ""
              ? SetWallpaperButton(url: wallpaperValue.primaryUrl, colorChanged: false)
              : GestureDetector(
                  onTap: () async {
                    openPrismLink(context, wallpaperValue.primaryUrl);
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
              openPrismLink(context, wallpaperValue.primaryUrl);
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
