import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/content_load_tracker.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/widgets/menuButton/setWallpaperButton.dart';
import 'package:Prism/features/palette/views/widgets/clock_overlay.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@RoutePage()
class DownloadWallpaperScreen extends StatefulWidget {
  const DownloadWallpaperScreen({super.key, required this.provider, required this.file});

  final String provider;
  final File file;

  @override
  _DownloadWallpaperScreenState createState() => _DownloadWallpaperScreenState();
}

class _DownloadWallpaperScreenState extends State<DownloadWallpaperScreen> with SingleTickerProviderStateMixin {
  final ContentLoadTracker _contentLoadTracker = ContentLoadTracker();
  late AnimationController shakeController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final String provider;
  late final File file;

  String get _sourceContext => '${provider.toLowerCase()}_download_wallpaper_screen';

  void _trackAction(AnalyticsActionValue action) {
    unawaited(
      analytics.track(
        SurfaceActionTappedEvent(
          surface: AnalyticsSurfaceValue.downloadWallpaperScreen,
          action: action,
          sourceContext: _sourceContext,
          itemType: ItemTypeValue.wallpaper,
          itemId: file.path,
        ),
      ),
    );
  }

  @override
  void initState() {
    shakeController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    super.initState();
    provider = widget.provider;
    file = widget.file;
    _contentLoadTracker.start();
    _contentLoadTracker.success(
      itemCount: 1,
      onSuccess: ({required int loadTimeMs, int? itemCount}) async {
        await analytics.track(
          SurfaceContentLoadedEvent(
            surface: AnalyticsSurfaceValue.downloadWallpaperScreen,
            result: EventResultValue.success,
            loadTimeMs: loadTimeMs,
            sourceContext: _sourceContext,
            itemCount: itemCount,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    shakeController.dispose();
    super.dispose();
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
      body: Stack(
        children: <Widget>[
          AnimatedBuilder(
            animation: offsetAnimation,
            builder: (buildContext, child) {
              if (offsetAnimation.value < 0.0) {
                logger.d('${offsetAnimation.value + 8.0}');
              }
              return GestureDetector(
                onLongPress: () {
                  _trackAction(AnalyticsActionValue.paletteResetLongPressed);
                  HapticFeedback.vibrate();
                  shakeController.forward(from: 0.0);
                },
                onTap: () {
                  _trackAction(AnalyticsActionValue.paletteCycleTapped);
                  HapticFeedback.vibrate();
                  shakeController.forward(from: 0.0);
                },
                child: Container(
                  margin: EdgeInsets.symmetric(
                    vertical: offsetAnimation.value * 1.25,
                    horizontal: offsetAnimation.value / 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(offsetAnimation.value),
                    image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
                  ),
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                ),
              );
            },
          ),
          if (!hideSetWallpaperUi)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: SetWallpaperButton(colorChanged: false, url: file.path),
              ),
            ),
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8.0, app_state.notchSize! + 8, 8, 8),
              child: IconButton(
                onPressed: () {
                  _trackAction(AnalyticsActionValue.backTapped);
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
                  _trackAction(AnalyticsActionValue.clockOverlayOpened);
                  final link = file.path;
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) {
                        animation = Tween(begin: 0.0, end: 1.0).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: ClockOverlay(colorChanged: false, accent: null, link: link, file: true),
                        );
                      },
                      fullscreenDialog: true,
                      opaque: false,
                    ),
                  );
                },
                color: Theme.of(context).colorScheme.secondary,
                icon: const Icon(JamIcons.clock),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
