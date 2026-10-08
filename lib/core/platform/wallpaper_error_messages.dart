/// Codes the wallpaper plugin returns that a retry cannot fix.
const Set<String> _permanentWallpaperErrors = <String>{'image-too-large', 'wallpaper-not-allowed', 'invalid-image'};

/// True when trying the same wallpaper again can work. Permanent codes return false.
bool canRetryWallpaperError(String? code) => !_permanentWallpaperErrors.contains(code);

/// One short, plain sentence for a plugin error [code]. [live] picks the wording for live wallpapers.
String wallpaperErrorMessage(String? code, {bool live = false}) {
  switch (code) {
    case 'source-too-large':
    case 'texture-source-too-large':
      return 'That file is too large for a live wallpaper.';
    case 'image-too-large':
      return live ? 'That file is too large for a live wallpaper.' : 'This image is too large for your device to set.';
    case 'texture-dimensions-exceeded':
      return 'That image is too large for a live wallpaper.';
    case 'wallpaper-not-allowed':
      return 'Your device or work profile does not allow wallpaper changes.';
    case 'out-of-memory':
      return 'Not enough memory. Close other apps and try again.';
    case 'timeout':
      return 'Timed out. Check your connection and try again.';
    case 'invalid-video':
    case 'video-preparation-failed':
      return 'That video cannot be played as a wallpaper. Try another clip.';
    case 'source-unavailable':
    case 'texture-source-unavailable':
      return "Couldn't read the file. Try again.";
    case 'permission-denied':
      return 'Prism does not have permission to read that file.';
    case 'shader-compilation-failed':
    case 'shader-link-failed':
    case 'opengl-configuration-failed':
    case 'egl-unavailable':
    case 'egl-initialization-failed':
      return 'This device could not start that style. Try another one.';
    case 'system-ui-unavailable':
    case 'system-ui-failed':
      return "Couldn't open the system preview.";
    default:
      return live ? "Couldn't set the live wallpaper. Try again." : "Couldn't set the wallpaper.";
  }
}
