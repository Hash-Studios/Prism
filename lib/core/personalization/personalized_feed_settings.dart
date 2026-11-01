import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:flutter/foundation.dart';

final ValueNotifier<int> personalizedFeedSettingsRevision = ValueNotifier<int>(0);

/// Stores the one AI setting that the Settings switch, the Tune sheet chip and the empty feed action share. The caller
/// refreshes any feed bloc it holds.
Future<bool> setShowAiWallpapers(SettingsLocalDataSource settings, bool value, {bool notify = true}) async {
  if (!await AiContentFilter.setShowsAi(settings, value)) return false;
  if (notify) personalizedFeedSettingsRevision.value += 1;
  return true;
}
