import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/animated/shake_once.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/detail_panel.dart';
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
    HapticFeedback.vibrate();
    _shake.shake();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double topPad = (app_state.notchSize ?? MediaQuery.paddingOf(context).top) + PrismSpace.xs;
    return Scaffold(
      backgroundColor: cs.surface,
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
                  height: double.infinity,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(value),
                    child: Image.file(
                      widget.file,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const GlintState(
                        kind: GlintStateKind.error,
                        title: "Couldn't open this wallpaper",
                        body: 'The file may have been moved or deleted.',
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (!hideSetWallpaperUi)
            Align(
              alignment: Alignment.bottomCenter,
              child: _ActionPanel(file: widget.file),
            ),
          Positioned(
            top: topPad,
            left: PrismSpace.md,
            child: PrismIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onImage: true,
              onPressed: () {
                _trackAction(AnalyticsActionValue.backTapped);
                Navigator.pop(context);
              },
            ),
          ),
          Positioned(
            top: topPad,
            right: PrismSpace.md,
            child: PrismIconButton(
              icon: Icons.schedule_rounded,
              tooltip: 'Clock preview',
              onImage: true,
              onPressed: () {
                _trackAction(AnalyticsActionValue.clockOverlayOpened);
                pushClockPreview(context, link: widget.file.path, file: true);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The docked bar at the bottom of the viewer: the file name and the one main action.
class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: DetailPanel.surfaceDecoration(context),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: PrismSpace.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.lg, PrismSpace.page, 0),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      file.uri.pathSegments.isEmpty ? 'Downloaded wallpaper' : file.uri.pathSegments.last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PrismTextStyles.cardTitle(context),
                    ),
                    Text('Saved on this device', style: PrismTextStyles.caption(context)),
                  ],
                ),
              ),
              const SizedBox(width: PrismSpace.sm),
              SetWallpaperButton(url: file.path, primary: true),
            ],
          ),
        ),
      ),
    );
  }
}
