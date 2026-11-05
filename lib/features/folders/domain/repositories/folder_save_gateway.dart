import 'package:Prism/features/folders/domain/entities/folder_save_plan.dart';
import 'package:Prism/features/folders/domain/entities/folder_save_run.dart';

enum FolderSaveAccess { granted, denied, failed }

/// The outside world of Save all: prices, Downloads, Photos access and the save of one wall.
abstract interface class FolderSaveGateway {
  /// The signed-in account. Empty for a guest.
  String get ownerId;

  FolderSaveAccount account();

  /// How the server sees each Prism wall in [ids]. A wall it no longer serves is left out.
  Future<Map<String, WallAccess>> wallAccess(List<String> ids);

  /// True when the wall is in Downloads now.
  Future<bool> isSaved(FolderSaveWall wall);

  /// Asks for Photos or storage access before anything is charged.
  Future<FolderSaveAccess> requestAccess(String album);

  /// Saves one wall into [album]. Charges at most [maxCoins], and only for a wall that saves. Retries once on a network
  /// error.
  Future<FolderWallOutcome> save(FolderSaveItem item, {required String album, required int maxCoins});

  /// Deletes the downloads a run left behind, for example after the app was killed.
  Future<void> clearTemporaryFiles();
}
