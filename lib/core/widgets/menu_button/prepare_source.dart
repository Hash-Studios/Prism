import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

/// Runs a button's `prepareSource`. Returns the path it made, or null after telling the user it failed.
Future<String?> runPrepareSource(Future<String> Function() prepare) async {
  try {
    return await prepare();
  } catch (error, stackTrace) {
    logger.w('Could not prepare the wallpaper source', error: error, stackTrace: stackTrace);
    toasts.error("Couldn't apply the colour. Try again.");
    return null;
  }
}
