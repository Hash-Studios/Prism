import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/ios_shortcuts/data/shortcuts_folders_store.dart';

class ShortcutsFoldersSyncService {
  const ShortcutsFoldersSyncService(this._repository);

  final FoldersRepository _repository;

  Future<void> sync({required String ownerId, required List<FolderEntity> folders}) => ShortcutsFoldersStore.sync(
    ownerId: ownerId,
    folders: folders,
    fetchItems: (folderId) => _repository.fetchItems(folderId, userId: ownerId, limit: ShortcutsFoldersStore.maxItems),
  );
}
