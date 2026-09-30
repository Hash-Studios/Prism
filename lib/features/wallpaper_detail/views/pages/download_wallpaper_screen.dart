import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@RoutePage()
class DownloadWallpaperScreen extends StatefulWidget {
  const DownloadWallpaperScreen({super.key, required this.source, required this.file});

  final WallpaperSource source;
  final File file;

  @override
  State<DownloadWallpaperScreen> createState() => _DownloadWallpaperScreenState();
}

class _DownloadWallpaperScreenState extends State<DownloadWallpaperScreen> with SingleTickerProviderStateMixin {
  late final AnimationController shakeController;
  late final Animation<double> offsetAnimation;

  String get _sourceContext => '${widget.source.wireValue}_download_wallpaper_screen';

  void _trackAction(AnalyticsActionValue action) {
    unawaited(
      analytics.track(
        SurfaceActionTappedEvent(
          surface: AnalyticsSurfaceValue.downloadWallpaperScreen,
          action: action,
          sourceContext: _sourceContext,
          itemType: ItemTypeValue.wallpaper,
          itemId: widget.file.path,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    shakeController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    offsetAnimation =
        Tween(begin: 0.0, end: 48.0).chain(CurveTween(curve: Curves.easeOutCubic)).animate(shakeController)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              shakeController.reverse();
            }
          });
  }

  @override
  void dispose() {
    shakeController.dispose();
    super.dispose();
  }

  void _bounce() {
    HapticFeedback.vibrate();
    shakeController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final topPad = (app_state.notchSize ?? MediaQuery.paddingOf(context).top) + 8;
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Stack(
        children: <Widget>[
          AnimatedBuilder(
            animation: offsetAnimation,
            builder: (buildContext, child) {
              return GestureDetector(
                onLongPress: _bounce,
                onTap: _bounce,
                child: Container(
                  margin: EdgeInsets.symmetric(
                    vertical: offsetAnimation.value * 1.25,
                    horizontal: offsetAnimation.value / 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(offsetAnimation.value),
                    image: DecorationImage(image: FileImage(widget.file), fit: BoxFit.cover),
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
                child: SetWallpaperButton(url: widget.file.path),
              ),
            ),
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8.0, topPad, 8, 8),
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
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
              padding: EdgeInsets.fromLTRB(8.0, topPad, 8, 8),
              child: IconButton(
                tooltip: 'Clock preview',
                onPressed: () {
                  _trackAction(AnalyticsActionValue.clockOverlayOpened);
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) {
                        animation = Tween(begin: 0.0, end: 1.0).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: ClockOverlay(colorChanged: false, accent: null, link: widget.file.path, file: true),
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
