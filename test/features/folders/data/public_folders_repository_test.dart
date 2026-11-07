import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/folders/data/repositories/public_folders_repository_impl.dart';
import 'package:Prism/features/folders/domain/entities/folder_section.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:cloud_functions/cloud_functions.dart' show FirebaseFunctionsException;
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_firestore_client.dart';

void main() {
  group('publicFolderFailure', () {
    FirebaseFunctionsException callable(String code, [String message = '']) =>
        FirebaseFunctionsException(code: code, message: message);

    test('maps a precondition failure with a name message to the name refusal', () {
      final PublicFolderFailure failure = publicFolderFailure(callable('failed-precondition', 'name'));

      expect(failure.refusal, PublicFolderRefusal.name);
    });

    test('maps a precondition failure with a hidden message to the hidden refusal', () {
      final PublicFolderFailure failure = publicFolderFailure(callable('failed-precondition', 'hidden'));

      expect(failure.refusal, PublicFolderRefusal.hidden);
    });

    test('maps other precondition failures to the unavailable refusal', () {
      final PublicFolderFailure failure = publicFolderFailure(callable('failed-precondition', 'other'));

      expect(failure.refusal, PublicFolderRefusal.unavailable);
    });

    test('maps not-found to the unavailable refusal', () {
      final PublicFolderFailure failure = publicFolderFailure(callable('not-found'));

      expect(failure.refusal, PublicFolderRefusal.unavailable);
    });

    test('maps resource-exhausted to the limit refusal', () {
      final PublicFolderFailure failure = publicFolderFailure(callable('resource-exhausted'));

      expect(failure.refusal, PublicFolderRefusal.limit);
    });

    test('maps internal errors to no refusal', () {
      final PublicFolderFailure failure = publicFolderFailure(callable('internal'));

      expect(failure.refusal, isNull);
    });

    test('maps a plain exception to no refusal', () {
      final PublicFolderFailure failure = publicFolderFailure(Exception('offline'));

      expect(failure.refusal, isNull);
    });
  });

  group('PublicFoldersRepositoryImpl callables', () {
    late List<({String name, Map<String, Object?> data})> calls;
    late Future<Object?> Function(String name, Map<String, Object?> data) respond;
    late PublicFoldersRepositoryImpl repository;

    setUp(() {
      calls = <({String name, Map<String, Object?> data})>[];
      respond = (name, data) async => null;
      repository = PublicFoldersRepositoryImpl(
        FakeFirestoreClient(),
        callFunction: (name, data) {
          calls.add((name: name, data: data));
          return respond(name, data);
        },
      );
    });

    test('setPublic calls setFolderPublic and returns the server value', () async {
      respond = (name, data) async => <String, Object?>{'public': false};

      final Result<bool> result = await repository.setPublic('f1', isPublic: true);

      expect(calls, hasLength(1));
      expect(calls.single.name, 'setFolderPublic');
      expect(calls.single.data, <String, Object?>{'folderId': 'f1', 'public': true});
      expect(result.isSuccess, isTrue);
      expect(result.data, isFalse);
    });

    test('setFollowing calls setFolderFollow with the folder and the new state', () async {
      final Result<void> result = await repository.setFollowing('f1', following: true);

      expect(result.isSuccess, isTrue);
      expect(calls.single.name, 'setFolderFollow');
      expect(calls.single.data, <String, Object?>{'folderId': 'f1', 'following': true});
    });

    test('a permission-denied item query is reported as an unavailable folder', () async {
      final PublicFoldersRepositoryImpl repository = PublicFoldersRepositoryImpl(
        FakeFirestoreClient()..queryError = FirestoreError(code: 'permission-denied', message: 'blocked'),
      );

      final Result<List<PublicFolderWall>> result = await repository.fetchWallIds('f1');

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<PublicFolderFailure>());
      expect((result.failure! as PublicFolderFailure).refusal, PublicFolderRefusal.unavailable);
    });

    test('fetchWallIds keeps a valid section id and drops an invalid one', () async {
      final PublicFoldersRepositoryImpl repository = PublicFoldersRepositoryImpl(
        FakeFirestoreClient(
          onQuery: (spec) => <FakeDocRow>[
            (id: 'W1', data: <String, dynamic>{'id': 'W1', 'sectionId': 'lock'}),
            (id: 'W2', data: <String, dynamic>{'id': 'W2', 'sectionId': 'bad id'}),
          ],
        ),
      );

      final Result<List<PublicFolderWall>> result = await repository.fetchWallIds('f1');

      expect(result.isSuccess, isTrue);
      expect(result.data!.map((w) => w.id).toList(), <String>['W1', 'W2']);
      expect(result.data![0].sectionId, 'lock');
      expect(result.data![1].sectionId, isNull);
    });

    test('fetchFolder parses the header sections', () async {
      final PublicFoldersRepositoryImpl repository = PublicFoldersRepositoryImpl(
        FakeFirestoreClient(
          docs: <String, Map<String, Map<String, dynamic>>>{
            'publicFolders': <String, Map<String, dynamic>>{
              'f1': <String, dynamic>{
                'ownerId': 'o1',
                'name': 'Name',
                'itemCount': 1,
                'covers': <String>[],
                'followerCount': 0,
                'sections': <Map<String, String>>[
                  <String, String>{'id': 'lock', 'name': 'Lock screens'},
                ],
              },
            },
          },
        ),
      );

      final Result<PublicFolderEntity?> result = await repository.fetchFolder('f1');

      expect(result.data!.sections, <FolderSection>[const FolderSection(id: 'lock', name: 'Lock screens')]);
    });
  });
}
