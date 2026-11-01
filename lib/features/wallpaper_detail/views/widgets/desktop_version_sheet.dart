import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/share_service.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/wallpaper/original_access_service.dart';
import 'package:Prism/core/wallpaper/wall_desktop.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/menu_button/original_access_prompt.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// The web page that offers the desktop download. `#desktop` opens its Desktop tab.
Uri desktopWebPageUrl(String wallpaperId) =>
    Uri.https('prismwalls.com', '/wallpaper/${Uri.encodeComponent(wallpaperId)}').replace(fragment: 'desktop');

bool isTabletLayout(BuildContext context) => MediaQuery.sizeOf(context).shortestSide >= PrismLayout.tabletShortestSide;

/// What the sheet does outside the app. Tests replace them.
// ignore: avoid_classes_with_only_static_members
class DesktopVersionActions {
  @visibleForTesting
  static Future<void> Function(BuildContext context, {required String text, required String subject}) share = _share;

  /// Gets the 2560 x 1600 original through original access, then sets it (Android) or saves it to Photos (iPad).
  @visibleForTesting
  static Future<void> Function(BuildContext context, PrismWallpaper wall) applyOnTablet = _applyOnTablet;

  static Future<void> _share(BuildContext context, {required String text, required String subject}) =>
      ShareService.shareText(text: text, subject: subject, context: context);

  static Future<void> _applyOnTablet(BuildContext context, PrismWallpaper wall) async {
    final l10n = context.l10n;
    final WallDesktopVariant? desktop = wall.desktop;
    if (desktop == null) return;
    final action = hideSetWallpaperUi ? OriginalAccessAction.download : OriginalAccessAction.set;
    try {
      final String? url = await resolveOriginalWithConsent(
        context,
        url: wall.fullUrl,
        wallpaperId: wall.id,
        wallpaperSource: WallpaperSource.prism,
        action: action,
        label: hideSetWallpaperUi ? l10n.desktopVersionSaveOnTablet : l10n.desktopVersionSetOnTablet,
        desktop: true,
        desktopVersion: desktop.version,
      );
      if (url == null || !context.mounted) return;
      final file = await WallpaperService.resolveToLocalFile(url);
      if (!context.mounted) return;
      if (hideSetWallpaperUi) {
        final OperationResult result = await PrismMediaHostApi().enqueueDownload(
          DownloadRequest(link: file.path, filenameWithoutExtension: 'prism_${wall.id}_desktop', isLocalFile: true),
        );
        if (!result.success) throw StateError('Save failed: ${result.errorCode}');
        if (context.mounted) toasts.success(l10n.coreWallpaperSavedPhotos);
        return;
      }
      await SetWallpaperFlow.run(
        context,
        url: file.path,
        thumbnailUrl: desktop.thumbnailUrl,
        entryPoint: 'desktop_version_sheet',
      );
    } catch (error, stackTrace) {
      logger.w('Desktop version could not be applied', error: error, stackTrace: stackTrace);
      if (context.mounted) toasts.error(l10n.desktopVersionUnavailable);
    }
  }
}

/// The "Desktop version" chip on the wall detail. It counts one view per wall it shows.
class DesktopVersionChip extends StatefulWidget {
  const DesktopVersionChip({super.key, required this.wall, required this.canSendToComputer});

  final PrismWallpaper wall;

  /// False for premium and exclusive walls: their web page has no download.
  final bool canSendToComputer;

  @override
  State<DesktopVersionChip> createState() => _DesktopVersionChipState();
}

class _DesktopVersionChipState extends State<DesktopVersionChip> {
  @override
  void initState() {
    super.initState();
    analytics.track(DesktopChipShownEvent(contentId: widget.wall.id));
  }

  @override
  void didUpdateWidget(DesktopVersionChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wall.id != widget.wall.id) analytics.track(DesktopChipShownEvent(contentId: widget.wall.id));
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: true,
        label: context.l10n.desktopVersionChipSemantic,
        excludeSemantics: true,
        child: PrismChip(
          label: context.l10n.desktopVersionChip,
          icon: Icons.desktop_mac_outlined,
          onTap: () => showDesktopVersionSheet(context, widget.wall, canSendToComputer: widget.canSendToComputer),
        ),
      ),
    );
  }
}

Future<void> showDesktopVersionSheet(BuildContext context, PrismWallpaper wall, {required bool canSendToComputer}) {
  analytics.track(DesktopSheetOpenedEvent(contentId: wall.id));
  return showPrismSheet<void>(
    context,
    detents: const <PrismSheetDetent>[PrismSheetDetent.fit],
    builder: (sheetContext) => DesktopVersionSheet(wall: wall, canSendToComputer: canSendToComputer),
  );
}

class DesktopVersionSheet extends StatelessWidget {
  const DesktopVersionSheet({super.key, required this.wall, required this.canSendToComputer});

  final PrismWallpaper wall;
  final bool canSendToComputer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final WallDesktopVariant? desktop = wall.desktop;
    if (desktop == null) return const SizedBox.shrink();
    final bool tablet = isTabletLayout(context);
    return PrismSheetBody(
      title: l10n.desktopVersionSheetTitle,
      message: l10n.desktopVersionSheetBody(desktop.width, desktop.height),
      actions: <Widget>[
        if (canSendToComputer)
          PrismButton(
            label: l10n.desktopVersionSendToComputer,
            icon: Icons.send_to_mobile_outlined,
            expand: true,
            variant: tablet ? PrismButtonVariant.tonal : PrismButtonVariant.primary,
            onPressed: () {
              analytics.track(DesktopSendToComputerEvent(contentId: wall.id));
              unawaited(
                DesktopVersionActions.share(
                  context,
                  text: l10n.desktopVersionShareText(desktopWebPageUrl(wall.id).toString()),
                  subject: l10n.desktopVersionShareSubject,
                ),
              );
            },
          ),
        if (tablet)
          PrismButton(
            label: hideSetWallpaperUi ? l10n.desktopVersionSaveOnTablet : l10n.desktopVersionSetOnTablet,
            icon: hideSetWallpaperUi ? Icons.download_rounded : Icons.wallpaper_rounded,
            expand: true,
            onPressed: () => unawaited(DesktopVersionActions.applyOnTablet(context, wall)),
          ),
      ],
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _MonitorPreview(url: desktop.thumbnailUrl, label: l10n.desktopVersionPreviewSemantic),
        ),
      ),
    );
  }
}

/// The 16:10 preview in a thin screen bezel with a stand, so it reads as a computer at a glance.
class _MonitorPreview extends StatelessWidget {
  const _MonitorPreview({required this.url, required this.label});

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 150),
                    placeholder: (_, _) => ColoredBox(color: scheme.surfaceContainer),
                    errorWidget: (_, _, _) => ColoredBox(color: scheme.surfaceContainer),
                  ),
                ),
              ),
            ),
          ),
          Container(width: 72, height: 14, color: scheme.surfaceContainerHighest),
          Container(
            width: 132,
            height: 5,
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(3)),
          ),
        ],
      ),
    );
  }
}
