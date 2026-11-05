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

abstract class DayNightRepository {
  /// The saved pair. A pair saved by another account loads as an empty pair.
  Future<DayNightPair> load({required String ownerId});

  Future<void> save(DayNightPair pair, {required String ownerId});

  /// Keeps an offline copy of both walls and writes the snapshot the Shortcuts action reads.
  /// Throws [DayNightPrepareException] when a wall cannot be served without the network.
  Future<void> publish(DayNightPair pair);

  /// Removes the Shortcuts snapshot, so the action asks the user to open Prism.
  Future<void> unpublish();
}
