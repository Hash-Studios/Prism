import 'dart:async';

import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFoldersRepository extends Fake implements FoldersRepository {
  _FakeFoldersRepository(this.folders);

  final List<FolderEntity> folders;
  final StreamController<FolderWriteFailure> _writeFailures = StreamController<FolderWriteFailure>.broadcast();

  @override
  Stream<FolderWriteFailure> get writeFailures => _writeFailures.stream;

  @override
  int get writeRevision => 0;

  @override
  Future<Result<List<FolderEntity>>> fetchFolders(String userId) async => Result.success(folders);

  Future<void> close() => _writeFailures.close();
}

class _FakePublicFolders extends Fake implements PublicFoldersRepository {
  final List<({String id, bool isPublic})> setPublicCalls = <({String id, bool isPublic})>[];
  Result<bool> Function(String folderId, bool isPublic)? onSetPublic;

  @override
  Future<Result<bool>> setPublic(String folderId, {required bool isPublic}) async {
    setPublicCalls.add((id: folderId, isPublic: isPublic));
    return onSetPublic?.call(folderId, isPublic) ?? Result.success(isPublic);
  }
}

FolderEntity _folder(String id) => FolderEntity(
  id: id,
  ownerId: 'u1',
  name: 'F-$id',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  itemCount: 0,
  covers: const <String>[],
);

Future<bool> _setVisibility(FoldersBloc bloc, String folderId, {required bool isPublic}) =>
    bloc.run((id) => FoldersEvent.visibilityRequested(folderId: folderId, isPublic: isPublic, operationId: id));

void main() {
  late _FakeFoldersRepository repo;
  late _FakePublicFolders publicRepo;
  late FoldersBloc bloc;

  Future<void> start() async {
    repo = _FakeFoldersRepository(<FolderEntity>[_folder('a')]);
    publicRepo = _FakePublicFolders();
    bloc = FoldersBloc(repo, publicRepo);
    expect(await bloc.run((id) => FoldersEvent.started(userId: 'u1', operationId: id)), isTrue);
  }

  tearDown(() async {
    await bloc.close();
    await repo.close();
  });

  test('making a folder public returns true and marks it public', () async {
    await start();

    expect(await _setVisibility(bloc, 'a', isPublic: true), isTrue);
    expect(bloc.state.folder('a')!.isPublic, isTrue);
    expect(publicRepo.setPublicCalls, <({String id, bool isPublic})>[(id: 'a', isPublic: true)]);
  });

  test('making a folder private returns true and marks it private', () async {
    await start();
    await _setVisibility(bloc, 'a', isPublic: true);

    expect(await _setVisibility(bloc, 'a', isPublic: false), isTrue);
    expect(bloc.state.folder('a')!.isPublic, isFalse);
    expect(publicRepo.setPublicCalls.last, (id: 'a', isPublic: false));
  });

  test('a refused visibility change keeps the folder as it was and reports the refusal', () async {
    await start();
    publicRepo.onSetPublic = (_, _) =>
        Result.error<bool>(const PublicFolderFailure('name', refusal: PublicFolderRefusal.name));

    expect(await _setVisibility(bloc, 'a', isPublic: true), isFalse);
    expect(bloc.state.folder('a')!.isPublic, isFalse);
    expect(bloc.state.failure, isA<PublicFolderFailure>());
    expect((bloc.state.failure! as PublicFolderFailure).refusal, PublicFolderRefusal.name);
  });

  test('an unknown folder id returns false and never calls the server', () async {
    await start();

    expect(await _setVisibility(bloc, 'missing', isPublic: true), isFalse);
    expect(publicRepo.setPublicCalls, isEmpty);
  });
}
