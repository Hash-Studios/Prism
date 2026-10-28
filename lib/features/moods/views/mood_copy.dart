import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/l10n/l10n.dart';

extension WallMoodCopy on WallMood {
  String title(AppLocalizations l10n) => switch (this) {
    WallMood.dreamy => l10n.moodDreamyTitle,
    WallMood.darkQuiet => l10n.moodDarkQuietTitle,
    WallMood.brightBold => l10n.moodBrightBoldTitle,
    WallMood.minimal => l10n.moodMinimalTitle,
    WallMood.spatialReady => l10n.moodSpatialReadyTitle,
    WallMood.depthReady => l10n.moodDepthReadyTitle,
  };

  /// The one line under the title.
  String body(AppLocalizations l10n) => switch (this) {
    WallMood.dreamy => l10n.moodDreamyBody,
    WallMood.darkQuiet => l10n.moodDarkQuietBody,
    WallMood.brightBold => l10n.moodBrightBoldBody,
    WallMood.minimal => l10n.moodMinimalBody,
    WallMood.spatialReady => l10n.moodSpatialReadyBody,
    WallMood.depthReady => l10n.moodDepthReadyBody,
  };
}
