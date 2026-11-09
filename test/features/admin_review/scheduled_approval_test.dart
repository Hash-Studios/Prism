import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/features/admin_review/data/admin_moderation_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_firestore_client.dart';
import 'fake_review_callables.dart';

void main() {
  late FakeFirestoreClient client;
  late AdminModerationRepository repository;

  setUp(() {
    client = FakeFirestoreClient();
    repository = AdminModerationRepository.withCaller(client, FakeReviewCallables(client.docs).call);
  });

  FirestoreDocument pendingWall({DateTime? releaseAt}) => FirestoreDocument('wall-1', <String, dynamic>{
    'review': false,
    'email': 'creator@example.com',
    'collections': <String>['community'],
    'createdAt': DateTime.utc(2026, 11),
    if (releaseAt != null) 'releaseAt': releaseAt,
  });

  test('approving a wall due in 2 hours writes releaseApprovedAt and leaves review and createdAt alone', () async {
    final DateTime releaseAt = DateTime.now().add(const Duration(hours: 2));

    final bool scheduled = await repository.approveWall(pendingWall(releaseAt: releaseAt));

    expect(scheduled, isTrue);
    final Map<String, dynamic> data = client.writes.single.data!;
    expect(data['releaseApprovedAt'], isA<FieldValue>());
    expect(data.containsKey('review'), isFalse);
    expect(data.containsKey('createdAt'), isFalse);
    expect(client.writes.single.collection, FirebaseCollections.walls);
  });

  test('approving a wall with no releaseAt writes review true and returns false', () async {
    final bool scheduled = await repository.approveWall(pendingWall());

    expect(scheduled, isFalse);
    final Map<String, dynamic> data = client.writes.single.data!;
    expect(data['review'], isTrue);
    expect(data.containsKey('releaseApprovedAt'), isFalse);
    expect(data['createdAt'], isA<DateTime>());
  });

  test('approving a wall whose releaseAt is 1 hour in the past writes review true and returns false', () async {
    final bool scheduled = await repository.approveWall(
      pendingWall(releaseAt: DateTime.now().subtract(const Duration(hours: 1))),
    );

    expect(scheduled, isFalse);
    final Map<String, dynamic> data = client.writes.single.data!;
    expect(data['review'], isTrue);
    expect(data.containsKey('releaseApprovedAt'), isFalse);
  });

  test('undoing an approval writes review false and deletes releaseApprovedAt', () async {
    const FirestoreDocument wall = FirestoreDocument('wall-1', <String, dynamic>{
      'review': false,
      'releaseApprovedAt': 'approved',
      'releaseAt': null,
      'collections': <String>['community'],
    });

    await repository.undoApproveWall(wall);

    final Map<String, dynamic> data = client.writes.single.data!;
    expect(data['review'], isFalse);
    // The delete sentinel and the server timestamp are both FieldValue. The sentinel type cannot tell them apart.
    expect(data.containsKey('releaseApprovedAt'), isTrue);
    expect(data['releaseApprovedAt'], isA<FieldValue>());
    expect(data['collections'], <String>['community']);
  });

  group('AdminModerationRepository.awaitsRelease', () {
    final DateTime future = DateTime.utc(2030, 1, 1, 12);

    test('is true only for an approved wall that waits for its release time', () {
      expect(
        AdminModerationRepository.awaitsRelease(
          FirestoreDocument('w', <String, dynamic>{
            'review': false,
            'releaseApprovedAt': DateTime.utc(2026, 11, 5),
            'releaseAt': future,
          }),
        ),
        isTrue,
      );
    });

    test('is false for an unapproved wall with a release time', () {
      expect(
        AdminModerationRepository.awaitsRelease(
          FirestoreDocument('w', <String, dynamic>{'review': false, 'releaseAt': future}),
        ),
        isFalse,
      );
    });

    test('is false for an approved wall with no release time', () {
      expect(
        AdminModerationRepository.awaitsRelease(
          FirestoreDocument('w', <String, dynamic>{'review': false, 'releaseApprovedAt': DateTime.utc(2026, 11, 5)}),
        ),
        isFalse,
      );
    });

    test('is false for a public wall', () {
      expect(
        AdminModerationRepository.awaitsRelease(
          FirestoreDocument('w', <String, dynamic>{
            'review': true,
            'releaseApprovedAt': DateTime.utc(2026, 11, 5),
            'releaseAt': future,
          }),
        ),
        isFalse,
      );
    });

    test('is false for an approved wall that already has publishedAt', () {
      expect(
        AdminModerationRepository.awaitsRelease(
          FirestoreDocument('w', <String, dynamic>{
            'review': false,
            'releaseApprovedAt': DateTime.utc(2026, 11, 5),
            'publishedAt': DateTime.utc(2030),
            'releaseAt': future,
          }),
        ),
        isFalse,
      );
    });
  });
}
