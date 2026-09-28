import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/notifications/fcm_token_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingClient implements FirestoreClient {
  final List<(String, String, Map<String, dynamic>, bool)> writes = <(String, String, Map<String, dynamic>, bool)>[];

  @override
  Future<void> setDoc(
    String collection,
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
    required String sourceTag,
  }) async {
    writes.add((collection, id, data, merge));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('the Followers switch is stored where onFollowCreated reads it', () async {
    final client = _RecordingClient();

    await FcmTokenService.instance.saveFollowerAlerts(userId: 'uid1', enabled: false, client: client);

    final (collection, id, data, merge) = client.writes.single;
    expect((collection, id, merge), ('usersv2/uid1/private', 'session', true));
    expect(data, <String, dynamic>{'followerAlerts': false});
  });
}
