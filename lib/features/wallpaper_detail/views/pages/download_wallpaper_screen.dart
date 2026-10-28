import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/animated/shake_once.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/l10n/l10n.dart';
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

  void _bounce({bool longPress = false}) {
    if (longPress) {
      PrismHaptics.impact();
    } else {
      PrismHaptics.tap();
    }
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
                onLongPress: () => _bounce(longPress: true),
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
                      errorBuilder: (_, _, _) => GlintState(
                        kind: GlintStateKind.error,
                        title: context.l10n.wallpaperOpenFileError,
                        body: context.l10n.wallpaperFileMovedOrDeleted,
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
          PositionedDirectional(
            top: topPad,
            start: PrismSpace.md,
            child: PrismIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: context.l10n.wallpaperBack,
              onImage: true,
              onPressed: () {
                _trackAction(AnalyticsActionValue.backTapped);
                Navigator.pop(context);
              },
            ),
          ),
          PositionedDirectional(
            top: topPad,
            end: PrismSpace.md,
            child: PrismIconButton(
              icon: Icons.smartphone_rounded,
              tooltip: context.l10n.wallpaperPreviewOnScreen,
              onImage: true,
              onPressed: () {
                _trackAction(AnalyticsActionValue.clockOverlayOpened);
                if (hideSetWallpaperUi) {
                  pushClockPreview(context, link: widget.file.path, file: true);
                  return;
                }
                unawaited(
                  SetWallpaperFlow.run(
                    context,
                    url: widget.file.path,
                    wallpaperSource: WallpaperSource.downloaded,
                    forceScreen: true,
                    entryPoint: 'wallpaper_preview',
                  ),
                );
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
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.94),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(PrismRadius.xl)),
          side: BorderSide(color: cs.onSurface.withValues(alpha: 0.08)),
        ),
      ),
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
                      file.uri.pathSegments.isEmpty
                          ? context.l10n.wallpaperDownloadedWallpaper
                          : file.uri.pathSegments.last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PrismTextStyles.cardTitle(context),
                    ),
                    Text(context.l10n.wallpaperSavedOnDevice, style: PrismTextStyles.caption(context)),
                  ],
                ),
              ),
              const SizedBox(width: PrismSpace.sm),
              SetWallpaperButton(
                url: file.path,
                wallpaperSource: WallpaperSource.downloaded,
                primary: true,
                entryPoint: 'download_wallpaper',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
