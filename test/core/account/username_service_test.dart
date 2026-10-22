import 'package:Prism/core/account/username_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_firestore_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirestoreClient firestore;

  setUp(() async {
    await getIt.reset();
    firestore = FakeFirestoreClient();
    getIt.registerSingleton<FirestoreClient>(firestore);
  });

  tearDown(() => getIt.reset());

  test('returns the server canonical winner, not the provisional initial candidate', () async {
    final service = UsernameService(
      request: (data) async {
        expect(data, <String, Object?>{'username': 'John', 'initial': true});
        return <String, Object?>{'username': 'John_abcd'};
      },
    );
    expect(await service.claim('John', initial: true), 'John_abcd');
  });

  test('a failed claim propagates without a client profile write', () async {
    final service = UsernameService(request: (_) async => throw StateError('already-exists'));
    await expectLater(service.claim('Taken'), throwsStateError);
    expect(firestore.writes, isEmpty);
  });

  test('invalid canonical responses never become usernames', () async {
    for (final Object? response in <Object?>[
      null,
      <String, Object?>{},
      <String, Object?>{'username': ''},
      <String, Object?>{'username': 'bad name'},
    ]) {
      await expectLater(UsernameService(request: (_) async => response).claim('Valid'), throwsStateError);
    }
  });

  test('unreleased reservations are unavailable even without a live profile', () async {
    firestore.docs['usernames'] = <String, Map<String, dynamic>>{
      'deleted': <String, dynamic>{'uid': 'gone'},
    };
    expect(await UsernameService().isAvailable('Deleted', 'me'), isFalse);
    expect(await UsernameService().isAvailable('Deleted', 'gone'), isTrue);
  });

  test('historical deleted profile reservations are available but active and unknown owners are not', () async {
    firestore.docs['usernames'] = <String, Map<String, dynamic>>{
      'reuse': <String, dynamic>{'uid': 'gone'},
    };
    firestore.docs['usersv2'] = <String, Map<String, dynamic>>{
      'gone': <String, dynamic>{'deleted': true, 'usernameLower': 'reuse'},
    };
    firestore.onQuery = (spec) => <FakeDocRow>[(id: 'gone', data: firestore.docs['usersv2']!['gone']!)];
    expect(await UsernameService().isAvailable('Reuse', 'me'), isTrue);
    firestore.docs['usersv2']!['gone'] = <String, dynamic>{'deleted': false};
    expect(await UsernameService().isAvailable('Reuse', 'me'), isFalse);
    firestore.docs['usersv2']!.remove('gone');
    expect(await UsernameService().isAvailable('Reuse', 'me'), isFalse);
    firestore.docs['usernames']!['reuse'] = <String, dynamic>{};
    expect(await UsernameService().isAvailable('Reuse', 'me'), isFalse);
    expect(firestore.writes, isEmpty);
  });

  test('availability rereads a historical reservation whose ownership changed', () async {
    firestore.docs['usernames'] = <String, Map<String, dynamic>>{
      'reuse': <String, dynamic>{'uid': 'gone'},
    };
    firestore.docs['usersv2'] = <String, Map<String, dynamic>>{
      'gone': <String, dynamic>{'deleted': true},
      'newOwner': <String, dynamic>{'deleted': false},
    };
    expect(await UsernameService().isAvailable('Reuse', 'me'), isTrue);
    firestore.docs['usernames']!['reuse'] = <String, dynamic>{'uid': 'newOwner'};
    expect(await UsernameService().isAvailable('Reuse', 'me'), isFalse);
  });

  test('the transport calls claimUsername without writing profiles', () async {
    final backend = CoinsTestBackend();
    await backend.install();
    backend.onCall = (name, parameters) async {
      expect(name, 'claimUsername');
      expect(parameters, <String, dynamic>{'username': 'NewName'});
      return <String, dynamic>{'username': 'NewName', 'usernameLower': 'newname'};
    };
    expect(await UsernameService().claim('NewName'), 'NewName');
    expect(firestore.writes, isEmpty);
  });
}
