/// Shared helpers for the wall/setup moderation batch writes used by the
/// admin review and review-batch repositories.
library;

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';

/// Coerces a Firestore field value to a display-safe string, defaulting to
/// an empty string for null.
String safeModerationString(Object? value) => value?.toString() ?? '';

/// Queues a moderation-outcome notification doc onto [batch] for the given
/// user [modifier] (email), skipping the write entirely when [modifier] is
/// empty (no recipient to notify).
void addModerationNotificationToBatch(
  FirestoreBatch batch, {
  required String modifier,
  required String title,
  required String body,
  required String imageUrl,
  String route = '',
  String wallId = '',
}) {
  if (modifier.isEmpty) {
    return;
  }
  batch.addDoc(FirebaseCollections.notifications, <String, dynamic>{
    'modifier': modifier,
    'notification': <String, dynamic>{'title': title, 'body': body},
    'data': <String, dynamic>{
      'pageName': '',
      'arguments': const <Object?>[],
      'url': '',
      'imageUrl': imageUrl,
      'route': route,
      if (wallId.isNotEmpty) 'wall_id': wallId,
    },
    'createdAt': DateTime.now().toUtc(),
  });
}
