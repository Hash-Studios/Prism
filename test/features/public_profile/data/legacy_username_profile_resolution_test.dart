import 'dart:async';
import 'dart:io';

import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/features/public_profile/data/repositories/public_profile_repository_impl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_firestore_client.dart';
import '../../../support/fake_user_block_repository.dart';

class _LegacyUsernameClient extends FakeFirestoreClient {
  _LegacyUsernameClient({super.onQuery});

  @override
  Stream<List<T>> watchQuery<T>(FirestoreQuerySpec spec, T Function(Map<String, dynamic>, String) map) {
    final List<FakeDocRow> rows = spec.collection == FirebaseCollections.profiles
        ? <FakeDocRow>[
            (
              id: 'legacy-uid',
              data: <String, dynamic>{'name': 'Legacy', 'username': 'OldName', 'email': 'private@x.test'},
            ),
          ]
        : const <FakeDocRow>[];
    return Stream<List<T>>.multi((controller) {
      scheduleMicrotask(() => controller.add(rows.map((row) => map(row.data, row.id)).toList()));
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resolves an old public profile username without a registry entry and omits its email', () async {
    final Directory directory = await Directory.systemTemp.createTemp('legacy-username-profile-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => directory.path,
    );
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
      await directory.delete(recursive: true);
    });
    final client = _LegacyUsernameClient(
      onQuery: (spec) =>
          spec.collection == FirebaseCollections.profiles &&
              spec.filters.single.field == 'username' &&
              spec.filters.single.value == 'OldName'
          ? <FakeDocRow>[
              (
                id: 'legacy-uid',
                data: <String, dynamic>{'name': 'Legacy', 'username': 'OldName', 'email': 'private@x.test'},
              ),
            ]
          : const <FakeDocRow>[],
    );
    final repo = PublicProfileRepositoryImpl(client, FakeUserBlockRepository.pending());

    final profile = await repo.watchProfile('OldName').first.timeout(const Duration(seconds: 3));

    expect(profile?.id, 'legacy-uid');
    expect(profile?.email, isEmpty);
    expect(client.querySpecs.map((spec) => spec.collection), contains(FirebaseCollections.profiles));
    expect(client.querySpecs.every((spec) => spec.collection != 'usersv2'), isTrue);
  });
}
