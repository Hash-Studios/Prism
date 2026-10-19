import 'package:Prism/l10n/l10n.dart';

/// Codes the wallpaper plugin returns that a retry cannot fix.
const Set<String> _permanentWallpaperErrors = <String>{'image-too-large', 'wallpaper-not-allowed', 'invalid-image'};

/// True when trying the same wallpaper again can work. Permanent codes return false.
bool canRetryWallpaperError(String? code) => !_permanentWallpaperErrors.contains(code);

/// One short, plain sentence for a plugin error [code]. [live] picks the wording for live wallpapers.
String wallpaperErrorMessage(String? code, AppLocalizations l10n, {bool live = false}) {
  switch (code) {
    case 'source-too-large':
    case 'texture-source-too-large':
      return l10n.coreWallpaperErrorSourceTooLarge;
    case 'image-too-large':
      return live ? l10n.coreWallpaperErrorSourceTooLarge : l10n.coreWallpaperErrorImageTooLarge;
    case 'texture-dimensions-exceeded':
      return l10n.coreWallpaperErrorTextureDimensions;
    case 'wallpaper-not-allowed':
      return l10n.coreWallpaperErrorNotAllowed;
    case 'out-of-memory':
      return l10n.coreWallpaperErrorMemory;
    case 'timeout':
      return l10n.coreWallpaperErrorTimeout;
    case 'invalid-video':
    case 'video-preparation-failed':
      return l10n.coreWallpaperErrorInvalidVideo;
    case 'source-unavailable':
    case 'texture-source-unavailable':
      return l10n.coreWallpaperErrorReadFile;
    case 'permission-denied':
      return l10n.coreWallpaperErrorPermission;
    case 'shader-compilation-failed':
    case 'shader-link-failed':
    case 'opengl-configuration-failed':
    case 'egl-unavailable':
    case 'egl-initialization-failed':
      return l10n.coreWallpaperErrorStyle;
    case 'system-ui-unavailable':
    case 'system-ui-failed':
      return l10n.coreWallpaperErrorSystemPreview;
    default:
      return live ? l10n.coreWallpaperErrorLiveGeneric : l10n.coreWallpaperErrorGeneric;
  }
}
