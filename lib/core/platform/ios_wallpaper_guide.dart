import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
import 'package:Prism/core/wallpaper/wall_spatial.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const String photosPermissionDeniedCode = 'PHOTO_PERMISSION_DENIED';

/// Whether the guide has opened automatically in this app session. Tests reset it.
// ignore: avoid_classes_with_only_static_members
abstract final class IosWallpaperGuideSession {
  static bool shown = false;
}

bool isPhotosPermissionDenied(String? errorCode) => errorCode == photosPermissionDeniedCode;

bool _suitsSpatialScene(WallSpatialTier? tier) => showSpatialSceneUi && (tier?.suitsSpatialScene ?? false);

/// Tells iOS users how to use a saved image as wallpaper. Shows at most once per session. For a wall that works with
/// the Depth Effect ([depthTier]) or a Spatial Scene ([spatialTier]), it ends with the steps that turn them on.
Future<void> showIosSetWallpaperGuide(
  BuildContext context, {
  WallDepthTier? depthTier,
  WallSpatialTier? spatialTier,
}) async {
  if (!hideSetWallpaperUi || IosWallpaperGuideSession.shown) return;
  if (!context.mounted) return;
  IosWallpaperGuideSession.shown = true;
  await showPrismSheet<void>(
    context,
    builder: (_) => IosWallpaperGuideSheet(depthTier: depthTier, spatialTier: spatialTier),
  );
}

/// Opens the Spatial Scene guide from the detail row. Unlike the save guide, it opens every time.
Future<void> showSpatialSceneGuide(
  BuildContext context, {
  required String wallId,
  required WallSpatialTier tier,
}) async {
  unawaited(analytics.track(SpatialGuideOpenedEvent(wallId: wallId, tier: tier.name)));
  await showPrismSheet<void>(context, builder: (_) => const SpatialSceneGuideSheet());
}

/// The toast after a save. Once the guide has shown this session, the toast carries the Depth Effect step instead,
/// or the Spatial Scene step when the wall has no Depth Effect.
String savedWallpaperMessage({required AppLocalizations l10n, WallDepthTier? depthTier, WallSpatialTier? spatialTier}) {
  final String? depthTip = IosWallpaperGuideSession.shown && showDepthEffectUi
      ? switch (depthTier) {
          WallDepthTier.auto => l10n.coreDepthEffectAutoTip,
          WallDepthTier.menu => l10n.coreDepthEffectMenuTip,
          WallDepthTier.none || null => null,
        }
      : null;
  final String? tip =
      depthTip ?? (IosWallpaperGuideSession.shown && _suitsSpatialScene(spatialTier) ? l10n.coreSpatialSceneTip : null);
  final String saved = wallpaperSavedMessage(l10n);
  return tip == null ? saved : l10n.coreWallpaperSavedWithTip(saved, tip);
}

/// Shows a snackbar with an Open settings action after iOS refused access to Photos.
void showPhotosPermissionDenied(BuildContext context) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  PrismHaptics.error();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(context.l10n.corePhotosPermissionMessage),
        action: SnackBarAction(label: context.l10n.coreOpenSettings, onPressed: () => _launch('app-settings:')),
      ),
    );
}

Future<void> _launch(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (error, stackTrace) {
    logger.w('Could not open $url', error: error, stackTrace: stackTrace);
  }
}

class IosWallpaperGuideSheet extends StatelessWidget {
  const IosWallpaperGuideSheet({super.key, this.depthTier, this.spatialTier});

  final WallDepthTier? depthTier;
  final WallSpatialTier? spatialTier;

  static List<String> steps(AppLocalizations l10n) => <String>[
    l10n.corePhotosStepOpen,
    l10n.corePhotosStepShare,
    l10n.corePhotosStepUseAsWallpaper,
  ];

  static String? _depthStepFor(WallDepthTier? tier, AppLocalizations l10n) => switch (tier) {
    WallDepthTier.auto => l10n.coreDepthEffectAutoLongTip,
    WallDepthTier.menu => l10n.coreDepthEffectMenuShortTip,
    WallDepthTier.none || null => null,
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<String> steps = <String>[
      ...IosWallpaperGuideSheet.steps(l10n),
      ?_depthStepFor(depthTier, l10n),
      if (_suitsSpatialScene(spatialTier)) l10n.wallpaperSpatialStepButton,
    ];
    return PrismSheetBody(
      title: l10n.coreSetItAsWallpaper,
      message: l10n.coreIosWallpaperGuideBody,
      actions: <Widget>[
        FilledButton(
          onPressed: () {
            PrismHaptics.tap();
            _launch('photos-redirect://');
          },
          child: Text(l10n.coreOpenPhotos),
        ),
        TextButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(l10n.coreDone)),
      ],
      child: _NumberedSteps(steps: steps),
    );
  }
}

class SpatialSceneGuideSheet extends StatelessWidget {
  const SpatialSceneGuideSheet({super.key});

  static List<String> steps(AppLocalizations l10n) => <String>[
    l10n.wallpaperSpatialStepSave,
    l10n.wallpaperSpatialStepPick,
    l10n.wallpaperSpatialStepButton,
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return PrismSheetBody(
      title: l10n.wallpaperSpatialGuideTitle,
      message: l10n.wallpaperSpatialGuideBody,
      actions: <Widget>[TextButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(l10n.coreDone))],
      child: _NumberedSteps(steps: SpatialSceneGuideSheet.steps(l10n)),
    );
  }
}

/// The numbered steps both guide sheets show.
class _NumberedSteps extends StatelessWidget {
  const _NumberedSteps({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                CircleAvatar(
                  radius: 14,
                  backgroundColor: scheme.primary,
                  child: Text('${i + 1}', style: theme.textTheme.labelLarge?.copyWith(color: scheme.onPrimary)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(steps[i], style: theme.textTheme.bodyLarge)),
              ],
            ),
          ),
      ],
    );
  }
}
