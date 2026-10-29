import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'folders_event.j.dart';
part 'folders_state.j.dart';
part 'folders_bloc.j.freezed.dart';

@injectable
class FoldersBloc extends Bloc<FoldersEvent, FoldersState> {
  FoldersBloc(this._repository, this._publicRepository) : super(FoldersState.initial()) {
    on<FoldersEvent>(_serial);
    _writeFailures = _repository.writeFailures.listen((failure) {
      if (!isClosed && failure.ownerId == _session.userId && failure.revision > _session.writeBoundary) {
        add(FoldersEvent.writeFailed(userId: failure.ownerId, failure: failure.failure));
      }
    });
  }

  final FoldersRepository _repository;
  final PublicFoldersRepository _publicRepository;

  static int _lastOperationId = 0;
  _FolderSession _session = _FolderSession('', 0);
  late final StreamSubscription<FolderWriteFailure> _writeFailures;
  final Queue<_FolderSession> _eventSessions = Queue<_FolderSession>();
  final Map<int, Completer<bool>> _operations = <int, Completer<bool>>{};

  @override
  void add(FoldersEvent event) {
    if (isClosed) return super.add(event);
    final String? userId = switch (event) {
      _Started(:final userId) when userId != _session.userId => userId,
      _Cleared() => '',
      _WriteFailed(:final userId) => userId,
      _ => null,
    };
    if (userId != null) {
      _session.cancelled.complete();
      _session = _FolderSession(userId, event is _WriteFailed ? _session.writeBoundary : _repository.writeRevision);
      _cancelOperations();
    }
    _eventSessions.add(_session);
    super.add(event);
  }

  void _cancelOperations() {
    for (final completion in _operations.values) {
      completion.complete(false);
    }
    _operations.clear();
  }

  @override
  Future<void> close() async {
    if (!_session.cancelled.isCompleted) _session.cancelled.complete();
    _cancelOperations();
    await _writeFailures.cancel();
    await super.close();
  }

  /// Every event runs in order, so two writes never compute counts and covers from the same old folder.
  Future<void> _serial(FoldersEvent event, Emitter<FoldersState> emit) async {
    final _FolderSession session = _eventSessions.removeFirst();
    final Future<void> previous = session.queueTail;
    final Completer<void> done = Completer<void>();
    session.queueTail = done.future;
    try {
      await session.wait(previous);
      switch (event) {
        case _Started():
          await _onStarted(event, emit, session);
        case _Cleared():
          emit(FoldersState.initial());
        case _WriteFailed():
          emit(
            FoldersState.initial().copyWith(
              userId: event.userId,
              status: LoadStatus.failure,
              actionStatus: ActionStatus.failure,
              failure: event.failure,
              queuedWriteFailure: event.failure,
            ),
          );
        case _FolderOpened():
          await _onFolderOpened(event, emit, session);
        case _MembershipRequested():
          await _onMembershipRequested(event, emit, session);
        case _CreateRequested():
          await _onCreateRequested(event, emit, session);
        case _RenameRequested():
          await _onRenameRequested(event, emit, session);
        case _VisibilityRequested():
          await _onVisibilityRequested(event, emit, session);
        case _DeleteRequested():
          await _onDeleteRequested(event, emit, session);
        case _SaveRequested():
          await _onSaveRequested(event, emit, session);
        case _ItemRemoved():
          await _onItemRemoved(event, emit, session);
      }
    } on _FolderSessionCancelled {
      // A request already sent to Firestore may finish, but cannot update another session or start more writes.
    } finally {
      done.complete();
    }
  }

  /// Adds the event built by [eventFor] and completes when it is handled. True when it succeeded.
  Future<bool> run(FoldersEvent Function(int operationId) eventFor) async {
    if (isClosed) return false;
    final int operationId = ++_lastOperationId;
    final Completer<bool> completion = Completer<bool>();
    add(eventFor(operationId));
    _operations[operationId] = completion;
    return completion.future;
  }

  void _finish(Emitter<FoldersState> emit, int operationId, {Failure? failure}) {
    emit(
      state.copyWith(
        actionStatus: failure == null ? ActionStatus.success : ActionStatus.failure,
        completedOperationId: operationId,
        failure: failure,
      ),
    );
    _operations.remove(operationId)?.complete(failure == null);
  }

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

  Future<void> _onStarted(_Started event, Emitter<FoldersState> emit, _FolderSession session) async {
    final bool sameUser = event.userId == state.userId;
    emit(
      (sameUser ? state : FoldersState.initial().copyWith(userId: event.userId)).copyWith(
        status: LoadStatus.loading,
        failure: null,
        queuedWriteFailure: null,
      ),
    );
    final Result<List<FolderEntity>> result = await session.wait(_repository.fetchFolders(event.userId));
    result.fold(
      onSuccess: (folders) => emit(
        state.copyWith(
          status: LoadStatus.success,
          folders: _sorted(folders),
          items: const {},
          itemsStatus: const {},
          membership: const {},
          membershipStatus: const {},
        ),
      ),
      onFailure: (failure) => emit(state.copyWith(status: LoadStatus.failure, failure: failure)),
    );
    _finish(emit, event.operationId, failure: result.failure);
  }

  Future<void> _onFolderOpened(_FolderOpened event, Emitter<FoldersState> emit, _FolderSession session) async {
    final String id = event.folderId;
    emit(state.copyWith(itemsStatus: <String, LoadStatus>{...state.itemsStatus, id: LoadStatus.loading}));
    if (state.folder(id) == null && state.userId.isNotEmpty) {
      final Result<List<FolderEntity>> folders = await session.wait(_repository.fetchFolders(state.userId));
      if (folders.failure case final failure?) {
        emit(state.copyWith(itemsStatus: <String, LoadStatus>{...state.itemsStatus, id: LoadStatus.failure}));
        _finish(emit, event.operationId, failure: failure);
        return;
      }
      if (folders.data case final List<FolderEntity> list) {
        emit(state.copyWith(status: LoadStatus.success, folders: _sorted(list)));
      }
      // Still not in the list: the folder is someone else's or gone. The page shows its public projection, if any.
      if (state.folder(id) == null) {
        emit(state.copyWith(itemsStatus: <String, LoadStatus>{...state.itemsStatus, id: LoadStatus.success}));
        _finish(emit, event.operationId);
        return;
      }
    }
    final Result<List<FavouriteWallEntity>?> result = await session.wait(
      _repository.fetchItems(id, userId: state.userId),
    );
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
        items: items == null
            ? (<String, List<FavouriteWallEntity>>{...state.items}..remove(id))
            : <String, List<FavouriteWallEntity>>{...state.items, id: items},
        membership: items == null
            ? state.membership.map((key, ids) => MapEntry(key, ids.toSet()..remove(id)))
            : state.membership,
        itemsStatus: <String, LoadStatus>{...state.itemsStatus, id: LoadStatus.success},
      ),
    );
    _finish(emit, event.operationId);
  }

  Future<Failure?> _loadMembership(FavouriteWallEntity wall, Emitter<FoldersState> emit, _FolderSession session) async {
    session.ensureActive();
    final String key = folderItemKey(wall);
    final Result<Set<String>> result = state.folders.isEmpty
        ? Result.success(<String>{})
        : await session.wait(_repository.foldersContaining(state.folders.map((folder) => folder.id).toList(), key));
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

  Future<void> _onMembershipRequested(
    _MembershipRequested event,
    Emitter<FoldersState> emit,
    _FolderSession session,
  ) async {
    final String key = folderItemKey(event.wall);
    emit(state.copyWith(membershipStatus: <String, LoadStatus>{...state.membershipStatus, key: LoadStatus.loading}));
    _finish(emit, event.operationId, failure: await session.wait(_loadMembership(event.wall, emit, session)));
  }

  Future<Failure?> _create(
    String rawName,
    FavouriteWallEntity? wall,
    Emitter<FoldersState> emit,
    _FolderSession session, {
    void Function(String folderId)? onCreated,
  }) async {
    session.ensureActive();
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
    final Result<void> result = await session.wait(_repository.createFolder(folder, firstWall: wall));
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
    onCreated?.call(folder.id);
    return null;
  }

  Future<void> _onCreateRequested(_CreateRequested event, Emitter<FoldersState> emit, _FolderSession session) async {
    _finish(emit, event.operationId, failure: await session.wait(_create(event.name, event.wall, emit, session)));
  }

  Future<void> _onRenameRequested(_RenameRequested event, Emitter<FoldersState> emit, _FolderSession session) async {
    final String? name = normalizeFolderName(event.name);
    final FolderEntity? folder = state.folder(event.folderId);
    if (name == null || folder == null) {
      _finish(emit, event.operationId, failure: const ValidationFailure('Cannot rename this folder.'));
      return;
    }
    final FolderEntity renamed = folder.copyWith(name: name, updatedAt: DateTime.now().toUtc());
    final Result<void> result = await session.wait(_repository.renameFolder(renamed));
    if (result.isSuccess) emit(state.copyWith(folders: _replace(renamed)));
    _finish(emit, event.operationId, failure: result.failure);
  }

  Future<void> _onVisibilityRequested(
    _VisibilityRequested event,
    Emitter<FoldersState> emit,
    _FolderSession session,
  ) async {
    final FolderEntity? folder = state.folder(event.folderId);
    if (folder == null) {
      _finish(emit, event.operationId, failure: const ValidationFailure('Cannot change this folder.'));
      return;
    }
    final Result<bool> result = await session.wait(_publicRepository.setPublic(folder.id, isPublic: event.isPublic));
    final FolderEntity? current = state.folder(event.folderId);
    if (result.isSuccess && current != null) {
      emit(state.copyWith(folders: _replace(current.copyWith(isPublic: result.data))));
    }
    _finish(emit, event.operationId, failure: result.failure);
  }

  Future<void> _onDeleteRequested(_DeleteRequested event, Emitter<FoldersState> emit, _FolderSession session) async {
    final String id = event.folderId;
    final Result<void> result = await session.wait(
      _repository.deleteFolder(id, userId: state.userId, isCancelled: () => session.cancelled.isCompleted),
    );
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

  Future<Failure?> _add(
    String folderId,
    FavouriteWallEntity wall,
    Emitter<FoldersState> emit,
    _FolderSession session,
  ) async {
    session.ensureActive();
    final FolderEntity? folder = state.folder(folderId);
    if (folder == null) return const ValidationFailure('This folder is gone.');
    final String key = folderItemKey(wall);
    final FolderEntity next = folder.withItemAdded(wall.thumbnailUrl, DateTime.now().toUtc());
    final Result<void> result = await session.wait(_repository.addItem(next, wall));
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

  Future<Failure?> _remove(
    String folderId,
    FavouriteWallEntity wall,
    Emitter<FoldersState> emit,
    _FolderSession session,
  ) async {
    session.ensureActive();
    final FolderEntity? folder = state.folder(folderId);
    if (folder == null) return const ValidationFailure('This folder is gone.');
    final String key = folderItemKey(wall);
    final List<FavouriteWallEntity>? loaded = state.items[folderId];
    if (loaded != null && !loaded.any((item) => folderItemKey(item) == key)) return null;
    if (loaded == null) {
      final membership = await session.wait(_repository.foldersContaining(<String>[folderId], key));
      if (membership.failure case final failure?) return failure;
      if (!membership.data!.contains(folderId)) return null;
    }
    List<FavouriteWallEntity>? newest = loaded;
    if (newest == null) {
      final result = await session.wait(
        _repository.fetchItems(folderId, userId: state.userId, limit: folderMaxCovers + 1),
      );
      if (result.failure case final failure?) return failure;
      newest = result.data;
      if (newest == null) return const ValidationFailure('This folder is gone.');
    }
    final List<String> covers = newest
        .where((item) => folderItemKey(item) != key)
        .map((item) => item.thumbnailUrl)
        .toList();
    final FolderEntity next = folder.withItemRemoved(covers, DateTime.now().toUtc());
    final Result<void> result = await session.wait(_repository.removeItem(next, wall));
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

  Future<void> _onSaveRequested(_SaveRequested event, Emitter<FoldersState> emit, _FolderSession session) async {
    final String key = folderItemKey(event.wall);
    Failure? failure = state.membership.containsKey(key)
        ? null
        : await session.wait(_loadMembership(event.wall, emit, session));
    final Set<String>? current = state.membership[key];
    if (failure != null || current == null) {
      _finish(emit, event.operationId, failure: failure ?? const ServerFailure('Could not read folders.'));
      return;
    }
    final requestKey = jsonEncode(<Object>[key, event.folderIds.toList()..sort(), event.newNames]);
    final progress = session.saves.putIfAbsent(requestKey, _SaveProgress.new);
    final selected = <String>{...event.folderIds, ...progress.createdFolderIds};
    for (final String id in selected.difference(current)) {
      failure = await session.wait(_add(id, event.wall, emit, session));
      if (failure != null) {
        _finish(emit, event.operationId, failure: failure);
        return;
      }
    }
    for (final String id in current.difference(selected)) {
      failure = await session.wait(_remove(id, event.wall, emit, session));
      if (failure != null) {
        _finish(emit, event.operationId, failure: failure);
        return;
      }
    }
    while (progress.nextName < event.newNames.length) {
      failure = await session.wait(
        _create(event.newNames[progress.nextName], event.wall, emit, session, onCreated: progress.createdFolderIds.add),
      );
      if (failure != null) {
        _finish(emit, event.operationId, failure: failure);
        return;
      }
      progress.nextName++;
    }
    session.saves.remove(requestKey);
    _finish(emit, event.operationId);
  }

  Future<void> _onItemRemoved(_ItemRemoved event, Emitter<FoldersState> emit, _FolderSession session) async {
    _finish(emit, event.operationId, failure: await session.wait(_remove(event.folderId, event.wall, emit, session)));
  }
}

class _FolderSession {
  _FolderSession(this.userId, this.writeBoundary);

  final String userId;
  final int writeBoundary;
  final Completer<void> cancelled = Completer<void>();
  Future<void> queueTail = Future<void>.value();
  final Map<String, _SaveProgress> saves = <String, _SaveProgress>{};

  void ensureActive() {
    if (cancelled.isCompleted) throw const _FolderSessionCancelled();
  }

  Future<T> wait<T>(Future<T> future) {
    return Future.any(<Future<T>>[future, cancelled.future.then<T>((_) => throw const _FolderSessionCancelled())]).then(
      (value) {
        ensureActive();
        return value;
      },
    );
  }
}

class _SaveProgress {
  final Set<String> createdFolderIds = <String>{};
  int nextName = 0;
}

class _FolderSessionCancelled implements Exception {
  const _FolderSessionCancelled();
}
