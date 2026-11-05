import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';

/// Why the walls could not be made ready for the Shortcuts action.
enum DayNightPrepareFailure { needsDownload, offlineCopyFailed }

class DayNightPrepareException implements Exception {
  const DayNightPrepareException(this.failure, {this.slot});

  final DayNightPrepareFailure failure;

  /// The slot whose wall failed, when one wall is the cause.
  final DayNightSlot? slot;

  @override
  String toString() => 'DayNightPrepareException($failure, $slot)';
}

enum DayNightSwitchSource {
  alarm('alarm'),
  appOpen('app_open');

  const DayNightSwitchSource(this.wireValue);

  final String wireValue;
}

/// A wall change the user has not seen in the app yet.
typedef DayNightSwitch = ({DayNightSlot slot, DayNightSwitchSource source});

/// What the apply on app open found. [running] is false when the device schedule is gone and must start again.
typedef DayNightOpenResult = ({bool running, DayNightSwitch? switched});

abstract class DayNightRepository {
  /// True when the device runs the schedule itself and the app only resumes it on open (Android).
  bool get runsOnDevice;

  /// The saved pair. A pair saved by another account loads as an empty pair.
  Future<DayNightPair> load({required String ownerId});

  Future<void> save(DayNightPair pair, {required String ownerId});

  /// Makes the pair run. iOS keeps an offline copy of both walls and writes the snapshot the Shortcuts action reads.
  /// Android starts the device schedule, which caches both walls and applies the current one.
  /// Throws [DayNightPrepareException] when a wall cannot be served without the network.
  Future<void> publish(DayNightPair pair);

  /// Stops the pair. iOS removes the Shortcuts snapshot, so the action asks the user to open Prism. Android stops the
  /// device schedule.
  Future<void> unpublish();

  /// Android: applies the wall for the current time unless it is already up. Only call it when [runsOnDevice].
  Future<DayNightOpenResult> applyOnOpen();
}
