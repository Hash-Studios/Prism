import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'folders_event.j.dart';
part 'folders_state.j.dart';
part 'folders_bloc.j.freezed.dart';

@injectable
class FoldersBloc extends Bloc<FoldersEvent, FoldersState> {
  FoldersBloc(this._repository) : super(FoldersState.initial()) {
    on<_Started>((event, emit) => _serial(() => _onStarted(event, emit)));
    on<_Cleared>((event, emit) => _serial(() async => emit(FoldersState.initial())));
    on<_FolderOpened>((event, emit) => _serial(() => _onFolderOpened(event, emit)));
    on<_MembershipRequested>((event, emit) => _serial(() => _onMembershipRequested(event, emit)));
    on<_CreateRequested>((event, emit) => _serial(() => _onCreateRequested(event, emit)));
    on<_RenameRequested>((event, emit) => _serial(() => _onRenameRequested(event, emit)));
    on<_DeleteRequested>((event, emit) => _serial(() => _onDeleteRequested(event, emit)));
    on<_SaveRequested>((event, emit) => _serial(() => _onSaveRequested(event, emit)));
    on<_ItemRemoved>((event, emit) => _serial(() => _onItemRemoved(event, emit)));
  }

  final FoldersRepository _repository;

  static int _lastOperationId = 0;
  Future<void> _queueTail = Future<void>.value();

  /// Every event runs in order, so two writes never compute counts and covers from the same old folder.
  Future<void> _serial(Future<void> Function() action) async {
    final Future<void> previous = _queueTail;
    final Completer<void> done = Completer<void>();
    _queueTail = done.future;
    await previous;
    try {
      await action();
    } finally {
      done.complete();
    }
  }

  /// Adds the event built by [eventFor] and completes when it is handled. True when it succeeded.
  Future<bool> run(FoldersEvent Function(int operationId) eventFor) async {
    final int operationId = ++_lastOperationId;
    final Future<FoldersState> completion = stream.firstWhere((state) => state.completedOperationId == operationId);
    add(eventFor(operationId));
    return (await completion).actionStatus == ActionStatus.success;
  }

  void _finish(Emitter<FoldersState> emit, int operationId, {Failure? failure}) => emit(
    state.copyWith(
      actionStatus: failure == null ? ActionStatus.success : ActionStatus.failure,
      completedOperationId: operationId,
      failure: failure,
    ),
  );

  List<FolderEntity> _sorted(Iterable<FolderEntity> folders) =>
      folders.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  List<FolderEntity> _replace(FolderEntity folder) =>
      _sorted(<FolderEntity>[folder, ...state.folders.where((other) => other.id != folder.id)]);

  Map<String, Set<String>> _withMembership(String itemKey, String folderId, {required bool member}) {
    final Set<String>? known = state.membership[itemKey];
    if (known == null) return state.membership;
    return <String, Set<String>>{
      ...state.membership,
      itemKey: member ? <String>{...known, folderId} : (known.toSet()..remove(folderId)),
    };
  }

  Future<void> _onStarted(_Started event, Emitter<FoldersState> emit) async {
    final bool sameUser = event.userId == state.userId;
    emit(
      (sameUser ? state : FoldersState.initial().copyWith(userId: event.userId)).copyWith(
        status: LoadStatus.loading,
        failure: null,
      ),
    );
    final Result<List<FolderEntity>> result = await _repository.fetchFolders(event.userId);
    result.fold(
      onSuccess: (folders) => emit(state.copyWith(status: LoadStatus.success, folders: _sorted(folders))),
      onFailure: (failure) => emit(state.copyWith(status: LoadStatus.failure, failure: failure)),
    );
    _finish(emit, event.operationId, failure: result.failure);
  }

  Future<void> _onFolderOpened(_FolderOpened event, Emitter<FoldersState> emit) async {
    final String id = event.folderId;
    emit(state.copyWith(itemsStatus: <String, LoadStatus>{...state.itemsStatus, id: LoadStatus.loading}));
    if (state.folder(id) == null && state.userId.isNotEmpty) {
      final Result<List<FolderEntity>> folders = await _repository.fetchFolders(state.userId);
      if (folders.data case final List<FolderEntity> list) {
        emit(state.copyWith(status: LoadStatus.success, folders: _sorted(list)));
      }
    }
    final Result<List<FavouriteWallEntity>?> result = await _repository.fetchItems(id);
    if (result.failure case final Failure failure) {
      emit(state.copyWith(itemsStatus: <String, LoadStatus>{...state.itemsStatus, id: LoadStatus.failure}));
      _finish(emit, event.operationId, failure: failure);
      return;
    }
    final List<FavouriteWallEntity>? items = result.data;
    emit(
      state.copyWith(
        // Null means the folder is gone or not the user's.
        folders: items == null ? state.folders.where((folder) => folder.id != id).toList() : state.folders,
        items: <String, List<FavouriteWallEntity>>{...state.items, id: ?items},
        itemsStatus: <String, LoadStatus>{...state.itemsStatus, id: LoadStatus.success},
      ),
    );
    _finish(emit, event.operationId);
  }

  Future<Failure?> _loadMembership(FavouriteWallEntity wall, Emitter<FoldersState> emit) async {
    final String key = folderItemKey(wall);
    final Result<Set<String>> result = state.folders.isEmpty
        ? Result.success(<String>{})
        : await _repository.foldersContaining(state.folders.map((folder) => folder.id).toList(), key);
    return result.fold(
      onSuccess: (ids) {
        emit(
          state.copyWith(
            membership: <String, Set<String>>{...state.membership, key: ids},
            membershipStatus: <String, LoadStatus>{...state.membershipStatus, key: LoadStatus.success},
          ),
        );
        return null;
      },
      onFailure: (failure) {
        emit(
          state.copyWith(membershipStatus: <String, LoadStatus>{...state.membershipStatus, key: LoadStatus.failure}),
        );
        return failure;
      },
    );
  }

  Future<void> _onMembershipRequested(_MembershipRequested event, Emitter<FoldersState> emit) async {
    final String key = folderItemKey(event.wall);
    emit(state.copyWith(membershipStatus: <String, LoadStatus>{...state.membershipStatus, key: LoadStatus.loading}));
    _finish(emit, event.operationId, failure: await _loadMembership(event.wall, emit));
  }

  Future<Failure?> _create(String rawName, FavouriteWallEntity? wall, Emitter<FoldersState> emit) async {
    final String? name = normalizeFolderName(rawName);
    if (name == null) return const ValidationFailure('A folder name needs 1 to $folderNameMaxLength characters.');
    if (state.userId.isEmpty) return const ValidationFailure('Sign in to make folders.');
    final DateTime now = DateTime.now().toUtc();
    final FolderEntity empty = FolderEntity(
      id: newFolderId(),
      ownerId: state.userId,
      name: name,
      createdAt: now,
      updatedAt: now,
      itemCount: 0,
      covers: const <String>[],
    );
    final FolderEntity folder = wall == null ? empty : empty.withItemAdded(wall.thumbnailUrl, now);
    final Result<void> result = await _repository.createFolder(folder, firstWall: wall);
    if (result.failure case final Failure failure) return failure;
    emit(
      state.copyWith(
        folders: _replace(folder),
        items: <String, List<FavouriteWallEntity>>{
          ...state.items,
          folder.id: <FavouriteWallEntity>[?wall],
        },
        itemsStatus: <String, LoadStatus>{...state.itemsStatus, folder.id: LoadStatus.success},
        membership: wall == null ? state.membership : _withMembership(folderItemKey(wall), folder.id, member: true),
      ),
    );
    return null;
  }

  Future<void> _onCreateRequested(_CreateRequested event, Emitter<FoldersState> emit) async {
    _finish(emit, event.operationId, failure: await _create(event.name, event.wall, emit));
  }

  Future<void> _onRenameRequested(_RenameRequested event, Emitter<FoldersState> emit) async {
    final String? name = normalizeFolderName(event.name);
    final FolderEntity? folder = state.folder(event.folderId);
    if (name == null || folder == null) {
      _finish(emit, event.operationId, failure: const ValidationFailure('Cannot rename this folder.'));
      return;
    }
    final FolderEntity renamed = folder.copyWith(name: name, updatedAt: DateTime.now().toUtc());
    final Result<void> result = await _repository.renameFolder(renamed);
    if (result.isSuccess) emit(state.copyWith(folders: _replace(renamed)));
    _finish(emit, event.operationId, failure: result.failure);
  }

  Future<void> _onDeleteRequested(_DeleteRequested event, Emitter<FoldersState> emit) async {
    final String id = event.folderId;
    final Result<void> result = await _repository.deleteFolder(id);
    if (result.isSuccess) {
      emit(
        state.copyWith(
          folders: state.folders.where((folder) => folder.id != id).toList(),
          items: <String, List<FavouriteWallEntity>>{...state.items}..remove(id),
          itemsStatus: <String, LoadStatus>{...state.itemsStatus}..remove(id),
          membership: state.membership.map((key, ids) => MapEntry(key, ids.toSet()..remove(id))),
        ),
      );
    }
    _finish(emit, event.operationId, failure: result.failure);
  }

  Future<Failure?> _add(String folderId, FavouriteWallEntity wall, Emitter<FoldersState> emit) async {
    final FolderEntity? folder = state.folder(folderId);
    if (folder == null) return const ValidationFailure('This folder is gone.');
    final String key = folderItemKey(wall);
    final FolderEntity next = folder.withItemAdded(wall.thumbnailUrl, DateTime.now().toUtc());
    final Result<void> result = await _repository.addItem(next, wall);
    if (result.failure case final Failure failure) return failure;
    final List<FavouriteWallEntity>? loaded = state.items[folderId];
    emit(
      state.copyWith(
        folders: _replace(next),
        items: loaded == null
            ? state.items
            : <String, List<FavouriteWallEntity>>{
                ...state.items,
                folderId: <FavouriteWallEntity>[wall, ...loaded.where((item) => folderItemKey(item) != key)],
              },
        membership: _withMembership(key, folderId, member: true),
      ),
    );
    return null;
  }

  Future<Failure?> _remove(String folderId, FavouriteWallEntity wall, Emitter<FoldersState> emit) async {
    final FolderEntity? folder = state.folder(folderId);
    if (folder == null) return const ValidationFailure('This folder is gone.');
    final String key = folderItemKey(wall);
    final List<FavouriteWallEntity>? loaded = state.items[folderId];
    final List<FavouriteWallEntity>? newest =
        loaded ?? (await _repository.fetchItems(folderId, limit: folderMaxCovers + 1)).data;
    final List<String> covers =
        newest?.where((item) => folderItemKey(item) != key).map((item) => item.thumbnailUrl).toList() ??
        folder.covers.where((url) => url != wall.thumbnailUrl).toList();
    final FolderEntity next = folder.withItemRemoved(covers, DateTime.now().toUtc());
    final Result<void> result = await _repository.removeItem(next, wall);
    if (result.failure case final Failure failure) return failure;
    emit(
      state.copyWith(
        folders: _replace(next),
        items: loaded == null
            ? state.items
            : <String, List<FavouriteWallEntity>>{
                ...state.items,
                folderId: loaded.where((item) => folderItemKey(item) != key).toList(),
              },
        membership: _withMembership(key, folderId, member: false),
      ),
    );
    return null;
  }

  Future<void> _onSaveRequested(_SaveRequested event, Emitter<FoldersState> emit) async {
    final String key = folderItemKey(event.wall);
    Failure? failure = state.membership.containsKey(key) ? null : await _loadMembership(event.wall, emit);
    final Set<String>? current = state.membership[key];
    if (failure != null || current == null) {
      _finish(emit, event.operationId, failure: failure ?? const ServerFailure('Could not read folders.'));
      return;
    }
    for (final String id in event.folderIds.difference(current)) {
      failure = await _add(id, event.wall, emit) ?? failure;
    }
    for (final String id in current.difference(event.folderIds)) {
      failure = await _remove(id, event.wall, emit) ?? failure;
    }
    for (final String name in event.newNames) {
      failure = await _create(name, event.wall, emit) ?? failure;
    }
    _finish(emit, event.operationId, failure: failure);
  }

  Future<void> _onItemRemoved(_ItemRemoved event, Emitter<FoldersState> emit) async {
    _finish(emit, event.operationId, failure: await _remove(event.folderId, event.wall, emit));
  }
}
