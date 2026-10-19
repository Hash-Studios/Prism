import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/wallpaper/wall_depth.dart';
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

/// Tells iOS users how to use a saved image as wallpaper. Shows at most once per session. For a wall that works with
/// the Depth Effect ([depthTier]), it ends with the step that turns the effect on.
Future<void> showIosSetWallpaperGuide(BuildContext context, {WallDepthTier? depthTier}) async {
  if (!hideSetWallpaperUi || IosWallpaperGuideSession.shown) return;
  if (!context.mounted) return;
  IosWallpaperGuideSession.shown = true;
  await showPrismSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => IosWallpaperGuideSheet(depthTier: depthTier),
  );
}

/// The toast after a save. Once the guide has shown this session, the toast carries the Depth Effect step instead.
String savedWallpaperMessage({required AppLocalizations l10n, WallDepthTier? depthTier}) {
  final String? tip = IosWallpaperGuideSession.shown && showDepthEffectUi
      ? switch (depthTier) {
          WallDepthTier.auto => l10n.coreDepthEffectAutoTip,
          WallDepthTier.menu => l10n.coreDepthEffectMenuTip,
          WallDepthTier.none || null => null,
        }
      : null;
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
  const IosWallpaperGuideSheet({super.key, this.depthTier});

  final WallDepthTier? depthTier;

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
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final List<String> steps = <String>[...IosWallpaperGuideSheet.steps(l10n), ?_depthStepFor(depthTier, l10n)];
    final ColorScheme scheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.coreSetItAsWallpaper, style: theme.textTheme.displaySmall),
            const SizedBox(height: 4),
            Text(
              l10n.coreIosWallpaperGuideBody,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  PrismHaptics.tap();
                  _launch('photos-redirect://');
                },
                child: Text(l10n.coreOpenPhotos),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(l10n.coreDone)),
            ),
          ],
        ),
      ),
    );
  }
}
