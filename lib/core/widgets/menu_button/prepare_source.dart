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

  /// The name of this variation of [link] in the Downloads index, and the name it is saved under without its extension.
  ///
  /// [downloadBaseName] keeps only the last path segment, so a `#fragment` would give every variation the name of the
  /// original. The `.png` stands in for the extension the native side adds. Without it a wallpaper name that has a dot
  /// would lose the key.
  String identityOf(String link) => '${downloadBaseName(link)}_$key.png';
}
