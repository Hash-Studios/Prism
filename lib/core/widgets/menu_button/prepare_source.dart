import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/wallpaper/wall_desktop.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

/// Runs a button's `prepareSource`, or the `prepare` of a [DownloadVariant]. Returns the path it made, or null after
/// telling the user it failed.
Future<String?> runPrepareSource(Future<String> Function() prepare, {required AppLocalizations l10n}) async {
  try {
    return await prepare();
  } catch (error, stackTrace) {
    logger.w('Could not prepare the wallpaper source', error: error, stackTrace: stackTrace);
    toasts.error(l10n.coreWallpaperEditApplyColorFailed);
    return null;
  }
}

/// A changed copy of a wallpaper, such as a colour variation, that a download saves in place of the original.
///
/// Each variation is its own purchase. Its [identityOf] keys the coin gate recovery marker and the Downloads index,
/// so a variation the user already saved never hides a failed payment for another one.
class DownloadVariant {
  const DownloadVariant({required this.key, required this.prepare, this.prepareAuthorized});

  final Future<String> Function(String source)? prepareAuthorized;

  /// Safe in a file name and different for every variation of one wallpaper, for example `tint-ff8800`.
  final String key;

  /// Makes the image and returns its local path. It runs once per tap, before the coin gate.
  final Future<String> Function() prepare;

  static final RegExp _unsafeCharacters = RegExp('[^A-Za-z0-9._-]');
  static final RegExp _leadingDot = RegExp(r'^\.');
  static const int _maxNameLength = 200;

  /// The name of this variation of [link] in the Downloads index, and the name it is saved under without its extension.
  ///
  /// It is a plain file name, so [downloadBaseName] gives the same stem back. [downloadBaseName] decodes the link, and
  /// a decoded `#` or `?` would start a fragment or query the next time it parses the name and drop the key. Every
  /// character outside `[A-Za-z0-9._-]` becomes `_`, the base is cut so the stem stays within the 200 bytes the native
  /// side accepts, and the `.png` stands in for the extension the native side adds. Without it a wallpaper name that
  /// has a dot would lose the key.
  String identityOf(String link) => identityFor(link, key);

  /// [identityOf] for a variation that has no [DownloadVariant], such as the desktop version.
  static String identityFor(String link, String key) {
    final String safe = downloadBaseName(link).replaceAll(_unsafeCharacters, '_').replaceFirst(_leadingDot, '_');
    final String suffix = '_$key';
    final int room = _maxNameLength - suffix.length;
    return '${safe.length > room ? safe.substring(0, room) : safe}$suffix.png';
  }
}

/// Files a download saves with the wall in the same purchase, such as a watch set. The coin gate runs one time for the
/// whole set: the phone wall, the files [prepare] makes from it, and the [desktop] version when there is one.
class DownloadSet {
  const DownloadSet({required this.key, required this.prepare, this.desktop, this.onSaved, this.onBusyChanged});

  /// Names the set in the Downloads index, for example `watch-apple_46`. The file that [prepare] returns under this
  /// key carries the same name, so the set reads as saved while that file is in Downloads.
  final String key;

  /// Makes the extra files from the phone source the gate authorized: a URL or a local path. Returns local paths by
  /// name key. It runs once per tap, before any file is saved. The button deletes the files after the save.
  final Future<Map<String, String>> Function(String phoneSource) prepare;

  /// The desktop version. It needs its own server grant, which the same gate run asks for.
  final WallDesktopVariant? desktop;

  /// Runs after the set is saved, before the button deletes [files]: copy a file to keep it. [desktopSaved] is false
  /// when the set has a desktop version that did not save.
  final void Function({required bool desktopSaved, required Map<String, String> files})? onSaved;

  /// True while a tap of the set runs, until its temporary files are deleted.
  final void Function(bool busy)? onBusyChanged;

  /// Each paid item counts as one download: the phone wall and the desktop version. The extra files are free.
  int get paidItems => desktop == null ? 1 : 2;
}
