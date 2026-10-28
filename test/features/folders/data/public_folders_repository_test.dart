import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/folders/data/repositories/public_folders_repository_impl.dart';
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
  });
}
