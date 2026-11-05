import 'package:Prism/features/folders/domain/entities/folder_save_plan.dart';

/// The folder a run saves. [name] is the album name.
class FolderSaveTarget {
  const FolderSaveTarget({required this.folderId, required this.name, required this.ownerId});

  final String folderId;
  final String name;

  /// The account that started the run. The run stops when another account signs in.
  final String ownerId;
}

enum FolderWallStatus { saved, skipped, failed }

/// Why a wall did not save. A failed Prism save may keep its paid original grant for retry.
enum FolderSaveFailure {
  network,
  notEnoughCoins,

  /// The server asked for more coins than the plan showed.
  priceChanged,
  unavailable,
  storage,
  unknown,
}

class FolderWallOutcome {
  const FolderWallOutcome.saved() : status = FolderWallStatus.saved, failure = null;
  const FolderWallOutcome.skipped() : status = FolderWallStatus.skipped, failure = null;
  const FolderWallOutcome.failed(FolderSaveFailure this.failure) : status = FolderWallStatus.failed;

  final FolderWallStatus status;
  final FolderSaveFailure? failure;
}

/// The walls of one Save all and how each one ended. A wall with no outcome has not finished.
class FolderSaveRun {
  const FolderSaveRun({
    required this.queue,
    this.outcomes = const <String, FolderWallOutcome>{},
    this.skippedAtPlan = 0,
  });

  /// The walls to save, in folder order.
  final List<FolderSaveItem> queue;

  /// By [FolderSaveWall.key].
  final Map<String, FolderWallOutcome> outcomes;

  /// Walls the plan found in Downloads. They never join the queue.
  final int skippedAtPlan;

  FolderSaveRun withOutcome(FolderSaveWall wall, FolderWallOutcome outcome) => FolderSaveRun(
    queue: queue,
    outcomes: <String, FolderWallOutcome>{...outcomes, wall.key: outcome},
    skippedAtPlan: skippedAtPlan,
  );

  /// The same run with the failed walls back in line.
  FolderSaveRun withFailedCleared() => FolderSaveRun(
    queue: queue,
    outcomes: <String, FolderWallOutcome>{
      for (final MapEntry<String, FolderWallOutcome> entry in outcomes.entries)
        if (entry.value.status != FolderWallStatus.failed) entry.key: entry.value,
    },
    skippedAtPlan: skippedAtPlan,
  );

  int get total => queue.length;
  int get done => outcomes.length;
  int _count(FolderWallStatus status) => outcomes.values.where((outcome) => outcome.status == status).length;
  int get saved => _count(FolderWallStatus.saved);
  int get skipped => skippedAtPlan + _count(FolderWallStatus.skipped);
  int get failed => _count(FolderWallStatus.failed);

  /// Walls a cancel stopped before they started.
  int get notStarted => total - done;

  List<FolderSaveItem> get failedItems =>
      queue.where((item) => outcomes[item.wall.key]?.status == FolderWallStatus.failed).toList(growable: false);

  List<FolderSaveItem> get pending =>
      queue.where((item) => !outcomes.containsKey(item.wall.key)).toList(growable: false);
}
