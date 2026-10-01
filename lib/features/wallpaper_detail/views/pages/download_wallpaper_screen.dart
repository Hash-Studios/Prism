import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/animated/shake_once.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class DownloadWallpaperScreen extends StatefulWidget {
  const DownloadWallpaperScreen({super.key, required this.source, required this.file});

  final WallpaperSource source;
  final File file;

  @override
  State<DownloadWallpaperScreen> createState() => _DownloadWallpaperScreenState();
}

class _DownloadWallpaperScreenState extends State<DownloadWallpaperScreen> {
  final ShakeController _shake = ShakeController();

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
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _bounce() {
    PrismHaptics.tap();
    _shake.shake();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = (app_state.notchSize ?? MediaQuery.paddingOf(context).top) + 8;
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Stack(
        children: <Widget>[
          ShakeOnce(
            controller: _shake,
            distance: 48,
            builder: (buildContext, value, _) {
              return GestureDetector(
                onLongPress: _bounce,
                onTap: _bounce,
                child: Container(
                  margin: EdgeInsets.symmetric(vertical: value * 1.25, horizontal: value / 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(value),
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
                      transitionDuration: context.motion(const Duration(milliseconds: 200)),
                      reverseTransitionDuration: context.motion(const Duration(milliseconds: 200)),
                      pageBuilder: (context, animation, secondaryAnimation) {
                        return FadeTransition(
                          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
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
