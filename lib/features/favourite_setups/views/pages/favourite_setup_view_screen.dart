import 'dart:ui';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/animated/favouriteIcon.dart';
import 'package:Prism/core/widgets/animated/showUp.dart';
import 'package:Prism/core/widgets/home/core/collapsedPanel.dart';
import 'package:Prism/core/widgets/menuButton/setWallpaperButton.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/data/informatics/dataManager.dart';
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/favourite_setups/views/favourite_setups_bloc_adapter.dart';
import 'package:Prism/features/setups/views/widgets/clock_setup_overlay.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_io/hive_io.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

@RoutePage()
class FavSetupViewScreen extends StatefulWidget {
  final List? arguments;
  const FavSetupViewScreen({this.arguments});

  @override
  _FavSetupViewScreenState createState() => _FavSetupViewScreenState();
}

class _FavSetupViewScreenState extends State<FavSetupViewScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int? index;
  String? thumb;
  bool isLoading = true;
  PanelController panelController = PanelController();
  late AnimationController shakeController;
  bool panelCollapsed = true;
  Future<String>? _futureView;
  late Box box;

  @override
  void initState() {
    shakeController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    index = widget.arguments![0] as int;
    updateViewsSetup(context.favouriteSetupsAdapter(listen: false).liked![index!]["id"].toString().toUpperCase());
    _futureView = getViewsSetup(
      context.favouriteSetupsAdapter(listen: false).liked![index!]["id"].toString().toUpperCase(),
    );
    isLoading = true;
    box = Hive.box('localFav');
    super.initState();
  }

  @override
  void dispose() {
    shakeController.dispose();
    super.dispose();
  }

  Future<void> onFavSetup(String id, Map setupMap) async {
    setState(() {
      isLoading = true;
    });
    Navigator.pop(context);
    context.favouriteSetupsAdapter(listen: false).favCheck(id, setupMap).then((value) {
      analytics.logEvent(name: 'setup_fav_status_changed', parameters: {'id': id});
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
                                          .favouriteSetupsAdapter(listen: false)
                                          .liked![index!]["name"]
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
                                      context.favouriteSetupsAdapter(listen: false).liked![index!]["desc"].toString(),
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
                                                      .favouriteSetupsAdapter(listen: false)
                                                      .liked![index!]["id"]
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
                                              name: context
                                                  .favouriteSetupsAdapter(listen: false)
                                                  .liked![index!]["name"]
                                                  .toString(),
                                              thumbUrl: context
                                                  .favouriteSetupsAdapter(listen: false)
                                                  .liked![index!]["image"]
                                                  .toString(),
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
                                                      context
                                                          .favouriteSetupsAdapter(listen: false)
                                                          .liked![index!]["by"]
                                                          .toString(),
                                                      overflow: TextOverflow.fade,
                                                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                        color: Theme.of(context).colorScheme.secondary,
                                                      ),
                                                    ),
                                                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                                                    avatar: CircleAvatar(
                                                      backgroundImage: CachedNetworkImageProvider(
                                                        context
                                                            .favouriteSetupsAdapter(listen: false)
                                                            .liked![index!]["userPhoto"]
                                                            .toString(),
                                                      ),
                                                    ),
                                                    labelPadding: const EdgeInsets.fromLTRB(7, 3, 7, 3),
                                                    onPressed: () {
                                                      context.router.push(
                                                        ProfileRoute(
                                                          arguments: [
                                                            context
                                                                .favouriteSetupsAdapter(listen: false)
                                                                .liked![index!]["email"],
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                                if (globals.verifiedUsers.contains(
                                                  context
                                                      .favouriteSetupsAdapter(listen: false)
                                                      .liked![index!]["email"]
                                                      .toString(),
                                                ))
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
                        child:
                            context.favouriteSetupsAdapter(listen: false).liked![index!]["widget"] == "" ||
                                context.favouriteSetupsAdapter(listen: false).liked![index!]["widget"] == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SetupDetailsTile(
                                    isInstalled: Future.value(false),
                                    onTap: () async {
                                      if (context
                                              .favouriteSetupsAdapter(listen: false)
                                              .liked![index!]["wallpaper_url"]
                                              .toString()[0] !=
                                          "[") {
                                        if (context.favouriteSetupsAdapter(listen: false).liked![index!]["wall_id"] ==
                                                null ||
                                            context.favouriteSetupsAdapter(listen: false).liked![index!]["wall_id"] ==
                                                "") {
                                          logger.d("Id Not Found!");
                                          launch(
                                            context
                                                .favouriteSetupsAdapter(listen: false)
                                                .liked![index!]["wallpaper_url"]
                                                .toString(),
                                          );
                                        } else {
                                          context.router.push(
                                            ShareWallpaperViewRoute(
                                              arguments: [
                                                context
                                                    .favouriteSetupsAdapter(listen: false)
                                                    .liked![index!]["wall_id"]
                                                    .toString(),
                                                context
                                                    .favouriteSetupsAdapter(listen: false)
                                                    .liked![index!]["wallpaper_provider"]
                                                    .toString(),
                                                context
                                                    .favouriteSetupsAdapter(listen: false)
                                                    .liked![index!]["wallpaper_url"]
                                                    .toString(),
                                                context
                                                    .favouriteSetupsAdapter(listen: false)
                                                    .liked![index!]["wallpaper_url"]
                                                    .toString(),
                                              ],
                                            ),
                                          );
                                        }
                                      } else {
                                        launch(
                                          context
                                              .favouriteSetupsAdapter(listen: false)
                                              .liked![index!]["wallpaper_url"][1]
                                              .toString(),
                                        );
                                      }
                                    },
                                    tileText:
                                        context
                                                .favouriteSetupsAdapter(listen: false)
                                                .liked![index!]["wallpaper_url"]
                                                .toString()[0] !=
                                            "["
                                        ? (context.favouriteSetupsAdapter(listen: false).liked![index!]["wall_id"] ==
                                                      null ||
                                                  context
                                                          .favouriteSetupsAdapter(listen: false)
                                                          .liked![index!]["wall_id"] ==
                                                      "")
                                              ? "Wall Link"
                                              : "Prism (${context.favouriteSetupsAdapter(listen: false).liked![index!]["wall_id"]})"
                                        : "${context.favouriteSetupsAdapter(listen: false).liked![index!]["wallpaper_url"][0]} - ${(context.favouriteSetupsAdapter(listen: false).liked![index!]["wallpaper_url"] as List).length > 2 ? context.favouriteSetupsAdapter(listen: false).liked![index!]["wallpaper_url"][2].toString() : ""}",
                                    tileType: "Wallpaper",
                                    panelCollapsed: panelCollapsed,
                                    delay: const Duration(milliseconds: 150),
                                  ),
                                  SetupDetailsTile(
                                    isInstalled:
                                        context
                                            .favouriteSetupsAdapter(listen: false)
                                            .liked![index!]["icon_url"]
                                            .toString()
                                            .contains('play.google.com/store/apps/details?id=')
                                        ? DeviceApps.isAppInstalled(
                                            context
                                                .favouriteSetupsAdapter(listen: false)
                                                .liked![index!]["icon_url"]
                                                .toString()
                                                .split("details?id=")[1]
                                                .split("&")[0],
                                          )
                                        : Future.value(false),
                                    onTap: () async {
                                      if (context
                                          .favouriteSetupsAdapter(listen: false)
                                          .liked![index!]["icon_url"]
                                          .toString()
                                          .contains('play.google.com/store/apps/details?id=')) {
                                        final isInstalled = await DeviceApps.isAppInstalled(
                                          context
                                              .favouriteSetupsAdapter(listen: false)
                                              .liked![index!]["icon_url"]
                                              .toString()
                                              .split("details?id=")[1]
                                              .split("&")[0],
                                        );
                                        isInstalled
                                            ? DeviceApps.openApp(
                                                context
                                                    .favouriteSetupsAdapter(listen: false)
                                                    .liked![index!]["icon_url"]
                                                    .toString()
                                                    .split("details?id=")[1]
                                                    .split("&")[0],
                                              )
                                            : launch(
                                                context
                                                    .favouriteSetupsAdapter(listen: false)
                                                    .liked![index!]["icon_url"]
                                                    .toString(),
                                              );
                                      } else {
                                        launch(
                                          context
                                              .favouriteSetupsAdapter(listen: false)
                                              .liked![index!]["icon_url"]
                                              .toString(),
                                        );
                                      }
                                    },
                                    tileText: context
                                        .favouriteSetupsAdapter(listen: false)
                                        .liked![index!]["icon"]
                                        .toString(),
                                    tileType: "Icons",
                                    panelCollapsed: panelCollapsed,
                                    delay: const Duration(milliseconds: 200),
                                  ),
                                ],
                              )
                            : context.favouriteSetupsAdapter(listen: false).liked![index!]["widget2"] == "" ||
                                  context.favouriteSetupsAdapter(listen: false).liked![index!]["widget2"] == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SetupDetailsTile(
                                    isInstalled: Future.value(false),
                                    onTap: () async {
                                      if (context
                                              .favouriteSetupsAdapter(listen: false)
                                              .liked![index!]["wallpaper_url"]
                                              .toString()[0] !=
                                          "[") {
                                        if (context.favouriteSetupsAdapter(listen: false).liked![index!]["wall_id"] ==
                                                null ||
                                            context.favouriteSetupsAdapter(listen: false).liked![index!]["wall_id"] ==
                                                "") {
                                          logger.d("Id Not Found!");
                                          launch(
                                            context
                                                .favouriteSetupsAdapter(listen: false)
                                                .liked![index!]["wallpaper_url"]
                                                .toString(),
                                          );
                                        } else {
                                          context.router.push(
                                            ShareWallpaperViewRoute(
                                              arguments: [
                                                context
                                                    .favouriteSetupsAdapter(listen: false)
                                                    .liked![index!]["wall_id"]
                                                    .toString(),
                                                context
                                                    .favouriteSetupsAdapter(listen: false)
                                                    .liked![index!]["wallpaper_provider"]
                                                    .toString(),
                                                context
                                                    .favouriteSetupsAdapter(listen: false)
                                                    .liked![index!]["wallpaper_url"]
                                                    .toString(),
                                                context
                                                    .favouriteSetupsAdapter(listen: false)
                                                    .liked![index!]["wallpaper_url"]
                                                    .toString(),
                                              ],
                                            ),
                                          );
                                        }
                                      } else {
                                        launch(
                                          context
                                              .favouriteSetupsAdapter(listen: false)
                                              .liked![index!]["wallpaper_url"][1]
                                              .toString(),
                                        );
                                      }
                                    },
                                    tileText:
                                        context
                                                .favouriteSetupsAdapter(listen: false)
                                                .liked![index!]["wallpaper_url"]
                                                .toString()[0] !=
                                            "["
                                        ? (context.favouriteSetupsAdapter(listen: false).liked![index!]["wall_id"] ==
                                                      null ||
                                                  context
                                                          .favouriteSetupsAdapter(listen: false)
                                                          .liked![index!]["wall_id"] ==
                                                      "")
                                              ? "Wall Link"
                                              : "Prism (${context.favouriteSetupsAdapter(listen: false).liked![index!]["wall_id"]})"
                                        : "${context.favouriteSetupsAdapter(listen: false).liked![index!]["wallpaper_url"][0]} - ${(context.favouriteSetupsAdapter(listen: false).liked![index!]["wallpaper_url"] as List).length > 2 ? context.favouriteSetupsAdapter(listen: false).liked![index!]["wallpaper_url"][2].toString() : ""}",
                                    tileType: "Wallpaper",
                                    panelCollapsed: panelCollapsed,
                                    delay: const Duration(milliseconds: 150),
                                  ),
                                  SetupDetailsTile(
                                    isInstalled:
                                        context
                                            .favouriteSetupsAdapter(listen: false)
                                            .liked![index!]["icon_url"]
                                            .toString()
                                            .contains('play.google.com/store/apps/details?id=')
                                        ? DeviceApps.isAppInstalled(
                                            context
                                                .favouriteSetupsAdapter(listen: false)
                                                .liked![index!]["icon_url"]
                                                .toString()
                                                .split("details?id=")[1]
                                                .split("&")[0],
                                          )
                                        : Future.value(false),
                                    onTap: () async {
                                      if (context
                                          .favouriteSetupsAdapter(listen: false)
                                          .liked![index!]["icon_url"]
                                          .toString()
                                          .contains('play.google.com/store/apps/details?id=')) {
                                        final isInstalled = await DeviceApps.isAppInstalled(
                                          context
                                              .favouriteSetupsAdapter(listen: false)
                                              .liked![index!]["icon_url"]
                                              .toString()
                                              .split("details?id=")[1]
                                              .split("&")[0],
                                        );
                                        isInstalled
                                            ? DeviceApps.openApp(
                                                context
                                                    .favouriteSetupsAdapter(listen: false)
                                                    .liked![index!]["icon_url"]
                                                    .toString()
                                                    .split("details?id=")[1]
                                                    .split("&")[0],
                                              )
                                            : launch(
                                                context
                                                    .favouriteSetupsAdapter(listen: false)
                                                    .liked![index!]["icon_url"]
                                                    .toString(),
                                              );
                                      } else {
                                        launch(
                                          context
                                              .favouriteSetupsAdapter(listen: false)
                                              .liked![index!]["icon_url"]
                                              .toString(),
                                        );
                                      }
                                    },
                                    tileText: context
                                        .favouriteSetupsAdapter(listen: false)
                                        .liked![index!]["icon"]
                                        .toString(),
                                    tileType: "Icons",
                                    panelCollapsed: panelCollapsed,
                                    delay: const Duration(milliseconds: 200),
                                  ),
                                  SetupDetailsTile(
                                    isInstalled:
                                        context
                                            .favouriteSetupsAdapter(listen: false)
                                            .liked![index!]["widget_url"]
                                            .toString()
                                            .contains('play.google.com/store/apps/details?id=')
                                        ? DeviceApps.isAppInstalled(
                                            context
                                                .favouriteSetupsAdapter(listen: false)
                                                .liked![index!]["widget_url"]
                                                .toString()
                                                .split("details?id=")[1]
                                                .split("&")[0],
                                          )
                                        : Future.value(false),
                                    onTap: () async {
                                      if (context
                                          .favouriteSetupsAdapter(listen: false)
                                          .liked![index!]["widget_url"]
                                          .toString()
                                          .contains('play.google.com/store/apps/details?id=')) {
                                        final isInstalled = await DeviceApps.isAppInstalled(
                                          context
                                              .favouriteSetupsAdapter(listen: false)
                                              .liked![index!]["widget_url"]
                                              .toString()
                                              .split("details?id=")[1]
                                              .split("&")[0],
                                        );
                                        isInstalled
                                            ? DeviceApps.openApp(
                                                context
                                                    .favouriteSetupsAdapter(listen: false)
                                                    .liked![index!]["widget_url"]
                                                    .toString()
                                                    .split("details?id=")[1]
                                                    .split("&")[0],
                                              )
                                            : launch(
                                                context
                                                    .favouriteSetupsAdapter(listen: false)
                                                    .liked![index!]["widget_url"]
                                                    .toString(),
                                              );
                                      } else {
                                        launch(
                                          context
                                              .favouriteSetupsAdapter(listen: false)
                                              .liked![index!]["widget_url"]
                                              .toString(),
                                        );
                                      }
                                    },
                                    tileText: context
                                        .favouriteSetupsAdapter(listen: false)
                                        .liked![index!]["widget"]
                                        .toString(),
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
                                        if (context
                                                .favouriteSetupsAdapter(listen: false)
                                                .liked![index!]["wallpaper_url"]
                                                .toString()[0] !=
                                            "[") {
                                          if (context.favouriteSetupsAdapter(listen: false).liked![index!]["wall_id"] ==
                                                  null ||
                                              context.favouriteSetupsAdapter(listen: false).liked![index!]["wall_id"] ==
                                                  "") {
                                            logger.d("Id Not Found!");
                                            launch(
                                              context
                                                  .favouriteSetupsAdapter(listen: false)
                                                  .liked![index!]["wallpaper_url"]
                                                  .toString(),
                                            );
                                          } else {
                                            context.router.push(
                                              ShareWallpaperViewRoute(
                                                arguments: [
                                                  context
                                                      .favouriteSetupsAdapter(listen: false)
                                                      .liked![index!]["wall_id"]
                                                      .toString(),
                                                  context
                                                      .favouriteSetupsAdapter(listen: false)
                                                      .liked![index!]["wallpaper_provider"]
                                                      .toString(),
                                                  context
                                                      .favouriteSetupsAdapter(listen: false)
                                                      .liked![index!]["wallpaper_url"]
                                                      .toString(),
                                                  context
                                                      .favouriteSetupsAdapter(listen: false)
                                                      .liked![index!]["wallpaper_url"]
                                                      .toString(),
                                                ],
                                              ),
                                            );
                                          }
                                        } else {
                                          launch(
                                            context
                                                .favouriteSetupsAdapter(listen: false)
                                                .liked![index!]["wallpaper_url"][1]
                                                .toString(),
                                          );
                                        }
                                      },
                                      tileText:
                                          context
                                                  .favouriteSetupsAdapter(listen: false)
                                                  .liked![index!]["wallpaper_url"]
                                                  .toString()[0] !=
                                              "["
                                          ? (context.favouriteSetupsAdapter(listen: false).liked![index!]["wall_id"] ==
                                                        null ||
                                                    context
                                                            .favouriteSetupsAdapter(listen: false)
                                                            .liked![index!]["wall_id"] ==
                                                        "")
                                                ? "Wall Link"
                                                : "Prism (${context.favouriteSetupsAdapter(listen: false).liked![index!]["wall_id"]})"
                                          : "${context.favouriteSetupsAdapter(listen: false).liked![index!]["wallpaper_url"][0]} - ${(context.favouriteSetupsAdapter(listen: false).liked![index!]["wallpaper_url"] as List).length > 2 ? context.favouriteSetupsAdapter(listen: false).liked![index!]["wallpaper_url"][2].toString() : ""}",
                                      tileType: "Wallpaper",
                                      panelCollapsed: panelCollapsed,
                                      delay: const Duration(milliseconds: 150),
                                    ),
                                    SetupDetailsTile(
                                      isInstalled:
                                          context
                                              .favouriteSetupsAdapter(listen: false)
                                              .liked![index!]["icon_url"]
                                              .toString()
                                              .contains('play.google.com/store/apps/details?id=')
                                          ? DeviceApps.isAppInstalled(
                                              context
                                                  .favouriteSetupsAdapter(listen: false)
                                                  .liked![index!]["icon_url"]
                                                  .toString()
                                                  .split("details?id=")[1]
                                                  .split("&")[0],
                                            )
                                          : Future.value(false),
                                      onTap: () async {
                                        if (context
                                            .favouriteSetupsAdapter(listen: false)
                                            .liked![index!]["icon_url"]
                                            .toString()
                                            .contains('play.google.com/store/apps/details?id=')) {
                                          final isInstalled = await DeviceApps.isAppInstalled(
                                            context
                                                .favouriteSetupsAdapter(listen: false)
                                                .liked![index!]["icon_url"]
                                                .toString()
                                                .split("details?id=")[1]
                                                .split("&")[0],
                                          );
                                          isInstalled
                                              ? DeviceApps.openApp(
                                                  context
                                                      .favouriteSetupsAdapter(listen: false)
                                                      .liked![index!]["icon_url"]
                                                      .toString()
                                                      .split("details?id=")[1]
                                                      .split("&")[0],
                                                )
                                              : launch(
                                                  context
                                                      .favouriteSetupsAdapter(listen: false)
                                                      .liked![index!]["icon_url"]
                                                      .toString(),
                                                );
                                        } else {
                                          launch(
                                            context
                                                .favouriteSetupsAdapter(listen: false)
                                                .liked![index!]["icon_url"]
                                                .toString(),
                                          );
                                        }
                                      },
                                      tileText: context
                                          .favouriteSetupsAdapter(listen: false)
                                          .liked![index!]["icon"]
                                          .toString(),
                                      tileType: "Icons",
                                      panelCollapsed: panelCollapsed,
                                      delay: const Duration(milliseconds: 200),
                                    ),
                                    SetupDetailsTile(
                                      isInstalled:
                                          context
                                              .favouriteSetupsAdapter(listen: false)
                                              .liked![index!]["widget_url"]
                                              .toString()
                                              .contains('play.google.com/store/apps/details?id=')
                                          ? DeviceApps.isAppInstalled(
                                              context
                                                  .favouriteSetupsAdapter(listen: false)
                                                  .liked![index!]["widget_url"]
                                                  .toString()
                                                  .split("details?id=")[1]
                                                  .split("&")[0],
                                            )
                                          : Future.value(false),
                                      onTap: () async {
                                        if (context
                                            .favouriteSetupsAdapter(listen: false)
                                            .liked![index!]["widget_url"]
                                            .toString()
                                            .contains('play.google.com/store/apps/details?id=')) {
                                          final isInstalled = await DeviceApps.isAppInstalled(
                                            context
                                                .favouriteSetupsAdapter(listen: false)
                                                .liked![index!]["widget_url"]
                                                .toString()
                                                .split("details?id=")[1]
                                                .split("&")[0],
                                          );
                                          isInstalled
                                              ? DeviceApps.openApp(
                                                  context
                                                      .favouriteSetupsAdapter(listen: false)
                                                      .liked![index!]["widget_url"]
                                                      .toString()
                                                      .split("details?id=")[1]
                                                      .split("&")[0],
                                                )
                                              : launch(
                                                  context
                                                      .favouriteSetupsAdapter(listen: false)
                                                      .liked![index!]["widget_url"]
                                                      .toString(),
                                                );
                                        } else {
                                          launch(
                                            context
                                                .favouriteSetupsAdapter(listen: false)
                                                .liked![index!]["widget_url"]
                                                .toString(),
                                          );
                                        }
                                      },
                                      tileText: context
                                          .favouriteSetupsAdapter(listen: false)
                                          .liked![index!]["widget"]
                                          .toString(),
                                      tileType: "Widget",
                                      panelCollapsed: panelCollapsed,
                                      delay: const Duration(milliseconds: 250),
                                    ),
                                    SetupDetailsTile(
                                      isInstalled:
                                          context
                                              .favouriteSetupsAdapter(listen: false)
                                              .liked![index!]["widget_url2"]
                                              .toString()
                                              .contains('play.google.com/store/apps/details?id=')
                                          ? DeviceApps.isAppInstalled(
                                              context
                                                  .favouriteSetupsAdapter(listen: false)
                                                  .liked![index!]["widget_url2"]
                                                  .toString()
                                                  .split("details?id=")[1]
                                                  .split("&")[0],
                                            )
                                          : Future.value(false),
                                      onTap: () async {
                                        if (context
                                            .favouriteSetupsAdapter(listen: false)
                                            .liked![index!]["widget_url2"]
                                            .toString()
                                            .contains('play.google.com/store/apps/details?id=')) {
                                          final isInstalled = await DeviceApps.isAppInstalled(
                                            context
                                                .favouriteSetupsAdapter(listen: false)
                                                .liked![index!]["widget_url2"]
                                                .toString()
                                                .split("details?id=")[1]
                                                .split("&")[0],
                                          );
                                          isInstalled
                                              ? DeviceApps.openApp(
                                                  context
                                                      .favouriteSetupsAdapter(listen: false)
                                                      .liked![index!]["widget_url2"]
                                                      .toString()
                                                      .split("details?id=")[1]
                                                      .split("&")[0],
                                                )
                                              : launch(
                                                  context
                                                      .favouriteSetupsAdapter(listen: false)
                                                      .liked![index!]["widget_url2"]
                                                      .toString(),
                                                );
                                        } else {
                                          launch(
                                            context
                                                .favouriteSetupsAdapter(listen: false)
                                                .liked![index!]["widget_url2"]
                                                .toString(),
                                          );
                                        }
                                      },
                                      tileText: context
                                          .favouriteSetupsAdapter(listen: false)
                                          .liked![index!]["widget2"]
                                          .toString(),
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
                          ModifiedSetWallpaperButton(index: index),
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
                                if (globals.prismUser.loggedIn == false) {
                                  googleSignInPopUp(context, () {
                                    onFavSetup(
                                      context
                                          .favouriteSetupsAdapter(listen: false)
                                          .liked![index!]
                                          .data()["id"]
                                          .toString(),
                                      context.favouriteSetupsAdapter(listen: false).liked![index!].data() as Map,
                                    );
                                  });
                                } else {
                                  onFavSetup(
                                    context
                                        .favouriteSetupsAdapter(listen: false)
                                        .liked![index!]
                                        .data()["id"]
                                        .toString(),
                                    context.favouriteSetupsAdapter(listen: false).liked![index!].data() as Map,
                                  );
                                }
                              },
                              iconColor: Theme.of(context).colorScheme.secondary,
                              iconSize: 30,
                              isFavorite:
                                  box.get(
                                        context.favouriteSetupsAdapter(listen: false).liked![index!]["id"].toString(),
                                        defaultValue: false,
                                      )
                                      as bool,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              createSetupDynamicLink(
                                index.toString(),
                                context.favouriteSetupsAdapter(listen: false).liked![index!]["name"].toString(),
                                context.favouriteSetupsAdapter(listen: false).liked![index!]["image"].toString(),
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
                      // HapticFeedback.vibrate();
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
                    imageUrl: context.favouriteSetupsAdapter(listen: false).liked![index!]["image"].toString(),
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
                padding: EdgeInsets.fromLTRB(8.0, globals.notchSize! + 8, 8, 8),
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
                padding: EdgeInsets.fromLTRB(8.0, globals.notchSize! + 8, 8, 8),
                child: IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) {
                          animation = Tween(begin: 0.0, end: 1.0).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SetupOverlay(
                              link: context.favouriteSetupsAdapter(listen: false).liked![index!]["image"].toString(),
                            ),
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
    return context.favouriteSetupsAdapter(listen: false).liked![index!]["wallpaper_url"].toString()[0] != "["
        ? context.favouriteSetupsAdapter(listen: false).liked![index!]["wall_id"] != null &&
                  context.favouriteSetupsAdapter(listen: false).liked![index!]["wall_id"] != ""
              ? DownloadButton(
                  link: context.favouriteSetupsAdapter(listen: false).liked![index!]["wallpaper_url"].toString(),
                  colorChanged: false,
                )
              : GestureDetector(
                  onTap: () async {
                    launch(context.favouriteSetupsAdapter(listen: false).liked![index!]["wallpaper_url"].toString());
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
              launch(context.favouriteSetupsAdapter(listen: false).liked![index!]["wallpaper_url"][1].toString());
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
    return context.favouriteSetupsAdapter(listen: false).liked![index!]["wallpaper_url"].toString()[0] != "["
        ? context.favouriteSetupsAdapter(listen: false).liked![index!]["wall_id"] != null &&
                  context.favouriteSetupsAdapter(listen: false).liked![index!]["wall_id"] != ""
              ? SetWallpaperButton(
                  url: context.favouriteSetupsAdapter(listen: false).liked![index!]["wallpaper_url"].toString(),
                  colorChanged: false,
                )
              : GestureDetector(
                  onTap: () async {
                    launch(context.favouriteSetupsAdapter(listen: false).liked![index!]["wallpaper_url"].toString());
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
              launch(context.favouriteSetupsAdapter(listen: false).liked![index!]["wallpaper_url"][1].toString());
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
