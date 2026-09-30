import 'dart:ui';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/view_stats/view_stats_repository.dart';
import 'package:Prism/core/wallpaper/setup_wallpaper_extensions.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/animated/favourite_icon.dart';
import 'package:Prism/core/widgets/animated/show_up.dart';
import 'package:Prism/core/widgets/content_report/content_report_sheet.dart';
import 'package:Prism/core/widgets/home/core/collapsed_panel.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/features/favourite_setups/views/favourite_setups_bloc_adapter.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:Prism/features/setups/views/widgets/setup_details_tile.dart';
import 'package:Prism/features/setups/views/widgets/setup_overlay.dart';
import 'package:Prism/features/setups/views/widgets/setup_wallpaper_action_button.dart';
import 'package:Prism/global/svg_assets.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

/// Full-screen setup page shared by the setup list, the favourites list and share links.
class SetupDetailView extends StatefulWidget {
  const SetupDetailView({super.key, required this.setup, this.closeOnFavouriteToggle = false, this.sharedLink = false});

  final SetupEntity setup;

  /// Closes the page on favourite toggle, since the favourites list shrinks under it.
  final bool closeOnFavouriteToggle;

  /// Opened from a share link: the actions need Prism Premium and the setup is not shared again from here.
  final bool sharedLink;

  @override
  State<SetupDetailView> createState() => _SetupDetailViewState();
}

class _SetupDetailViewState extends State<SetupDetailView> with SingleTickerProviderStateMixin {
  final FavoritesLocalDataSource _favoritesLocal = getIt<FavoritesLocalDataSource>();
  final PanelController _panelController = PanelController();
  late final AnimationController _shakeController = AnimationController(
    duration: const Duration(milliseconds: 300),
    vsync: this,
  );
  late final Animation<double> _offsetAnimation =
      Tween(begin: 0.0, end: 48.0).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_shakeController)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _shakeController.reverse();
          }
        });
  late final Future<String> _futureView;
  bool _panelCollapsed = true;

  SetupEntity get _setup => widget.setup;

  @override
  void initState() {
    super.initState();
    _futureView = getIt<ViewStatsRepository>()
        .recordSetupView(_setup.id.toUpperCase())
        .then((r) => r.fold(onSuccess: (s) => s, onFailure: (_) => '0'));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _openSetupWallpaper() async {
    final wallpaper = _setup.wallpaperValue;
    if (!wallpaper.isEncoded) {
      if (_setup.wallId.isEmpty) {
        await openPrismLink(context, wallpaper.primaryUrl);
        return;
      }
      await context.router.push(
        WallpaperDetailRoute(
          wallId: _setup.wallId,
          source: _setup.source ?? WallpaperSource.unknown,
          wallpaperUrl: wallpaper.primaryUrl,
          thumbnailUrl: _setup.wallpaperThumb.isNotEmpty ? _setup.wallpaperThumb : wallpaper.primaryUrl,
          analyticsSurface: widget.sharedLink
              ? AnalyticsSurfaceValue.shareSetupViewScreen
              : AnalyticsSurfaceValue.shareWallpaperView,
        ),
      );
      return;
    }
    if (wallpaper.hasDeepLink) {
      await openPrismLink(context, wallpaper.deepLinkUrl!);
    }
  }

  Future<void> _onFavSetup() async {
    final adapter = context.favouriteSetupsAdapter(listen: false);
    if (widget.closeOnFavouriteToggle) {
      Navigator.pop(context);
    }
    await adapter.toggle(_setup);
    analytics.track(SetupFavStatusChangedEvent(setupId: _setup.id));
  }

  void _reportSetup() {
    final String docId = _setup.firestoreDocumentId;
    if (docId.isEmpty) {
      toasts.error('Report unavailable for this setup.');
      return;
    }
    showContentReportSheet(context, contentType: 'setup', targetFirestoreDocId: docId, subtitle: _setup.name);
  }

  void _openImageOverlay() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          animation = Tween(begin: 0.0, end: 1.0).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SetupOverlay(link: _setup.image),
          );
        },
        fullscreenDialog: true,
        opaque: false,
      ),
    );
  }

  Widget _buildTiles() {
    final setup = _setup;
    final entries = <(String, String, VoidCallback)>[
      ('Wallpaper', setup.wallpaperValue.tileText(wallId: setup.wallId), _openSetupWallpaper),
      ('Icons', setup.icon, () => openPrismLink(context, setup.iconUrl)),
      if (setup.widget.isNotEmpty) ('Widget', setup.widget, () => openPrismLink(context, setup.widgetUrl)),
      if (setup.widget.isNotEmpty && setup.widget2.isNotEmpty)
        ('Widget', setup.widget2, () => openPrismLink(context, setup.widgetUrl2)),
    ];
    final tiles = <Widget>[
      for (final (i, (type, text, onTap)) in entries.indexed)
        SetupDetailsTile(
          onTap: onTap,
          tileText: text,
          tileType: type,
          panelCollapsed: _panelCollapsed,
          delay: Duration(milliseconds: 150 + 50 * i),
        ),
    ];
    if (tiles.length < 4) {
      return Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, mainAxisSize: MainAxisSize.min, children: tiles);
    }
    return Scrollbar(
      radius: const Radius.circular(500),
      thickness: 5,
      child: ListView(children: tiles),
    );
  }

  Widget _buildPremiumRequired(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GestureDetector(
          onTap: () async {
            await PaywallOrchestrator.instance.presentOrRequireSignIn(
              context,
              placement: PaywallPlacement.mainUpsell,
              source: 'share_setup_view',
            );
            toasts.codeSend('This is a premium wallpaper.');
          },
          child: SetupActionCircle(
            padding: const EdgeInsets.all(17),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(JamIcons.stop_sign, color: Theme.of(context).colorScheme.secondary, size: 30),
                const SizedBox(width: 4),
                Text('Premium Required', style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        SetupWallpaperActionButton(setup: _setup, action: SetupWallpaperAction.download),
        if (!hideSetWallpaperUi) SetupWallpaperActionButton(setup: _setup, action: SetupWallpaperAction.setWallpaper),
        SetupActionCircle(
          child: FavoriteIcon(
            tapTargetExtent: 53,
            valueChanged: () {
              if (!app_state.prismUser.loggedIn) {
                googleSignInPopUp(context, _onFavSetup);
              } else {
                _onFavSetup();
              }
            },
            iconColor: Theme.of(context).colorScheme.secondary,
            iconSize: 30,
            isFavorite: _favoritesLocal.isSetupFavourite(app_state.prismUser.id, _setup.id),
          ),
        ),
        if (!widget.sharedLink)
          GestureDetector(
            onTap: () {
              createSetupDynamicLink(_setup.name, _setup.image, context: context);
            },
            child: SetupActionCircle(
              padding: const EdgeInsets.all(17),
              child: Icon(JamIcons.share_alt, color: Theme.of(context).colorScheme.secondary, size: 20),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color secondary = theme.colorScheme.secondary;
    final Size screen = MediaQuery.of(context).size;
    final setup = _setup;
    final bool premiumGated = widget.sharedLink && !app_state.prismUser.premium;
    final double panelHeight = premiumGated ? 300 : (screen.height * .70 > 600 ? screen.height * .70 : 600);
    final TextStyle infoStyle = theme.textTheme.bodyLarge!.copyWith(color: secondary, fontSize: 16);
    return Scaffold(
      backgroundColor: theme.primaryColor,
      body: SlidingUpPanel(
        backdropEnabled: true,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        boxShadow: const [],
        collapsed: CollapsedPanel(panelCollapsed: _panelCollapsed, panelController: _panelController),
        minHeight: screen.height / 20,
        parallaxEnabled: true,
        parallaxOffset: 0.00,
        color: Colors.transparent,
        maxHeight: panelHeight,
        controller: _panelController,
        onPanelOpened: () {
          setState(() {
            _panelCollapsed = false;
          });
        },
        onPanelClosed: () {
          setState(() {
            _panelCollapsed = true;
          });
        },
        panel: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          height: panelHeight,
          width: screen.width,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 750),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: _panelCollapsed
                      ? theme.primaryColor.withValues(alpha: 1)
                      : theme.primaryColor.withValues(alpha: .5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: AnimatedOpacity(
                          duration: Duration.zero,
                          opacity: _panelCollapsed ? 0.0 : 1.0,
                          child: GestureDetector(
                            onTap: () {
                              _panelController.close();
                            },
                            child: Icon(JamIcons.chevron_down, color: secondary),
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
                            child: _panelCollapsed
                                ? Container()
                                : ShowUpTransition(
                                    forward: true,
                                    slideSide: SlideFromSlide.bottom,
                                    child: Text(
                                      setup.name.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.fade,
                                      style: theme.textTheme.displayLarge!.copyWith(fontSize: 30, color: secondary),
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(35, 0, 35, 0),
                            child: _panelCollapsed
                                ? Container()
                                : ShowUpTransition(
                                    forward: true,
                                    slideSide: SlideFromSlide.bottom,
                                    delay: const Duration(milliseconds: 50),
                                    child: Text(
                                      setup.desc,
                                      maxLines: 2,
                                      overflow: TextOverflow.fade,
                                      style: theme.textTheme.titleLarge!.copyWith(color: secondary),
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
                        child: _panelCollapsed
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
                                          width: screen.width * 0.36,
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(0, 5, 0, 5),
                                            child: Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    setup.id.toUpperCase(),
                                                    overflow: TextOverflow.fade,
                                                    softWrap: false,
                                                    style: infoStyle,
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                                  child: Container(height: 16, color: secondary, width: 2),
                                                ),
                                                Flexible(
                                                  child: FutureBuilder<String>(
                                                    future: _futureView,
                                                    builder: (context, snapshot) => Text(
                                                      snapshot.hasData ? '${snapshot.data} views' : '',
                                                      overflow: TextOverflow.fade,
                                                      softWrap: false,
                                                      style: infoStyle,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: _reportSetup,
                                          child: Row(
                                            children: [
                                              Icon(JamIcons.info, size: 20, color: secondary.withValues(alpha: .7)),
                                              const SizedBox(width: 10),
                                              Text(
                                                'Report',
                                                overflow: TextOverflow.fade,
                                                style: theme.textTheme.bodyMedium!.copyWith(
                                                  decoration: TextDecoration.underline,
                                                  color: secondary,
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
                                                      setup.by,
                                                      overflow: TextOverflow.fade,
                                                      style: theme.textTheme.bodyMedium!.copyWith(color: secondary),
                                                    ),
                                                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                                                    avatar: CircleAvatar(
                                                      backgroundImage: CachedNetworkImageProvider(setup.userPhoto),
                                                    ),
                                                    labelPadding: const EdgeInsets.fromLTRB(7, 3, 7, 3),
                                                    onPressed: () {
                                                      context.router.push(ProfileRoute(profileIdentifier: setup.email));
                                                    },
                                                  ),
                                                ),
                                                if (app_state.verifiedUsers.contains(setup.email))
                                                  Align(
                                                    alignment: Alignment.topRight,
                                                    child: SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: SvgPicture.string(
                                                        verifiedIcon.replaceAll(
                                                          'E57697',
                                                          theme.colorScheme.error == Colors.black
                                                              ? 'E57697'
                                                              : theme.colorScheme.error.rgbHex,
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
                    if (premiumGated)
                      Container()
                    else
                      Expanded(
                        flex: 16,
                        child: Padding(padding: const EdgeInsets.fromLTRB(35, 0, 35, 0), child: _buildTiles()),
                      ),
                    Expanded(flex: 5, child: premiumGated ? _buildPremiumRequired(context) : _buildActions(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Stack(
          children: <Widget>[
            AnimatedBuilder(
              animation: _offsetAnimation,
              builder: (buildContext, child) {
                return GestureDetector(
                  onPanUpdate: (details) {
                    if (details.delta.dy < -10) {
                      _panelController.open();
                    }
                  },
                  onLongPress: () {
                    HapticFeedback.vibrate();
                    _shakeController.forward(from: 0.0);
                  },
                  onTap: () {
                    HapticFeedback.vibrate();
                    _shakeController.forward(from: 0.0);
                  },
                  child: CachedNetworkImage(
                    imageUrl: setup.image,
                    imageBuilder: (context, imageProvider) => Container(
                      margin: EdgeInsets.symmetric(
                        vertical: _offsetAnimation.value * 1.25,
                        horizontal: _offsetAnimation.value / 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_offsetAnimation.value),
                        image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                      ),
                    ),
                    progressIndicatorBuilder: (context, url, downloadProgress) => Stack(
                      children: <Widget>[
                        const SizedBox.expand(child: Text('', overflow: TextOverflow.fade)),
                        Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(theme.colorScheme.error),
                            value: downloadProgress.progress,
                          ),
                        ),
                      ],
                    ),
                    errorWidget: (context, url, error) =>
                        Center(child: Icon(JamIcons.close_circle_f, color: secondary)),
                  ),
                );
              },
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.fromLTRB(8.0, app_state.notchSize! + 8, 8, 8),
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  color: secondary,
                  icon: const Icon(JamIcons.chevron_left),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.fromLTRB(8.0, app_state.notchSize! + 8, 8, 8),
                child: IconButton(
                  onPressed: _openImageOverlay,
                  color: secondary,
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
