import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    kotlinOptions: KotlinOptions(errorClassName: 'PrismWidgetFlutterError'),
    swiftOptions: SwiftOptions(errorClassName: 'PrismWidgetError'),
  ),
)
class StreakWidgetSnapshot {
  StreakWidgetSnapshot({
    required this.count,
    required this.lastKeptDay,
    required this.utcOffsetMinutes,
    required this.freezes,
  });

  int count;

  /// The last kept day as yyyy-MM-dd in the streak's time zone.
  String lastKeptDay;
  int utcOffsetMinutes;
  int freezes;
}

@HostApi()
abstract class PrismWidgetHostApi {
  /// Saves the snapshot for the streak widgets (iOS Lock Screen, Android home screen) and reloads them. Null clears it (signed out).
  void setStreakSnapshot(StreakWidgetSnapshot? snapshot);

  /// Reloads the Wall of the Day widgets, for example after a Wall of the Day push.
  void reloadWallOfTheDay();
}
