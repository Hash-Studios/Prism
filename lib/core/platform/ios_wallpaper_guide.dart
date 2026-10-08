import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
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

/// Tells iOS users how to use a saved image as wallpaper. Shows at most once per session.
Future<void> showIosSetWallpaperGuide(BuildContext context) async {
  if (!hideSetWallpaperUi || IosWallpaperGuideSession.shown) return;
  if (!context.mounted) return;
  IosWallpaperGuideSession.shown = true;
  await showPrismSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const IosWallpaperGuideSheet(),
  );
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
        content: const Text('Allow Prism to add photos in Settings to save wallpapers.'),
        action: SnackBarAction(label: 'Open settings', onPressed: () => _launch('app-settings:')),
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
  const IosWallpaperGuideSheet({super.key});

  static const List<String> steps = <String>['Open Photos.', 'Tap Share.', 'Tap Use as Wallpaper.'];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Set it as your wallpaper', style: theme.textTheme.displaySmall),
            const SizedBox(height: 4),
            Text(
              'iOS does not let apps change your wallpaper. Finish in Photos:',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            for (int i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
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
                child: const Text('Open Photos'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Done')),
            ),
          ],
        ),
      ),
    );
  }
}
