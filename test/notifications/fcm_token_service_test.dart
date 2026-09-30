import 'package:Prism/notifications/fcm_token_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_firestore_client.dart';

class _MergeRecordingClient extends FakeFirestoreClient {
  bool? merged;

  @override
  Future<void> setDoc(
    String collection,
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
    required String sourceTag,
  }) {
    merged = merge;
    return super.setDoc(collection, id, data, merge: merge, sourceTag: sourceTag);
  }
}

void main() {
  test('the Followers switch is stored where onFollowCreated reads it', () async {
    final client = _MergeRecordingClient();

    await FcmTokenService.instance.saveFollowerAlerts(userId: 'uid1', enabled: false, client: client);

    final write = client.writes.single;
    expect((write.collection, write.id), ('usersv2/uid1/private', 'session'));
    expect(client.merged, isTrue);
    expect(write.data, <String, dynamic>{'followerAlerts': false});
  });
}
