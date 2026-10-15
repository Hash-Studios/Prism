import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

/// Runs a button's `prepareSource`, or the `prepare` of a [DownloadVariant]. Returns the path it made, or null after
/// telling the user it failed.
Future<String?> runPrepareSource(Future<String> Function() prepare) async {
  try {
    return await prepare();
  } catch (error, stackTrace) {
    logger.w('Could not prepare the wallpaper source', error: error, stackTrace: stackTrace);
    toasts.error("Couldn't apply the colour. Try again.");
    return null;
  }
}

/// A changed copy of a wallpaper, such as a colour variation, that a download saves in place of the original.
///
/// Each variation is its own purchase. Its [identityOf] keys the coin gate recovery marker and the Downloads index,
/// so a variation the user already saved never hides a failed payment for another one.
class DownloadVariant {
  const DownloadVariant({required this.key, required this.prepare});

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
  String identityOf(String link) {
    final String safe = downloadBaseName(link).replaceAll(_unsafeCharacters, '_').replaceFirst(_leadingDot, '_');
    final String suffix = '_$key';
    final int room = _maxNameLength - suffix.length;
    return '${safe.length > room ? safe.substring(0, room) : safe}$suffix.png';
  }
}
