import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/notifications/model/inAppNotifModel.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/logger/logger.dart';

const int _defaultNotifLimit = 50;

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

List<String> _notificationModifiers() {
  final String audience = app_state.prismUser.premium ? 'premium' : 'free';
  return <String>[
    audience,
    'all',
    app_state.currentAppVersion.trim(),
    app_state.prismUser.email.trim(),
  ].where((value) => value.isNotEmpty).toSet().toList(growable: false);
}

Future<List<Map<String, dynamic>>> _fetchNotificationsSince({
  required DateTime sinceUtc,
  required String sourceTag,
  int limit = _defaultNotifLimit,
  FirestoreCachePolicy cachePolicy = FirestoreCachePolicy.networkOnly,
}) async {
  final List<String> modifiers = _notificationModifiers();
  if (modifiers.isEmpty) {
    return <Map<String, dynamic>>[];
  }
  return firestoreClient.query<Map<String, dynamic>>(
    FirestoreQuerySpec(
      collection: FirebaseCollections.notifications,
      sourceTag: sourceTag,
      filters: <FirestoreFilter>[
        FirestoreFilter(field: 'createdAt', op: FirestoreFilterOp.isGreaterThan, value: sinceUtc),
        FirestoreFilter(field: 'modifier', op: FirestoreFilterOp.whereIn, value: modifiers),
      ],
      orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
      limit: limit,
      dedupeWindowMs: 1500,
      cachePolicy: cachePolicy,
    ),
    (data, _) => data,
  );
}

InAppNotificationEntity _toEntity(Map<String, dynamic> raw) {
  final InAppNotif notif = InAppNotif.fromSnapshot(raw);
  final DateTime createdAt = notif.createdAt?.toUtc() ?? DateTime.now().toUtc();
  final String title = notif.title ?? '';
  final String body = notif.body ?? '';
  final String pageName = notif.pageName ?? '';
  final String url = notif.url ?? '';
  return InAppNotificationEntity(
    id: buildInAppNotificationId(title: title, body: body, pageName: pageName, url: url, createdAt: createdAt),
    title: title,
    pageName: pageName,
    body: body,
    imageUrl: notif.imageUrl ?? '',
    arguments: (notif.arguments ?? const <Object>[]).whereType<Object>().toList(growable: false),
    url: url,
    createdAt: createdAt,
    read: notif.read ?? false,
    route: notif.route,
    wallId: notif.wallId,
    followerEmail: notif.followerEmail,
  );
}

Future<void> syncInAppNotificationsFromRemote() async {
  logger.d('Fetching in-app notifications');
  final notificationsLocal = getIt<NotificationsLocalDataSource>();
  final DateTime nowUtc = DateTime.now().toUtc();
  final DateTime? lastFetchTime = notificationsLocal.lastFetchAtUtc();

  try {
    if (lastFetchTime == null) {
      final List<Map<String, dynamic>> snap = await _fetchNotificationsSince(
        sinceUtc: nowUtc.subtract(const Duration(days: 30)),
        sourceTag: 'notifications.last_month',
      );
      final entities = snap.map(_asMap).map(_toEntity).toList(growable: false);
      await notificationsLocal.writeAll(entities);
      await notificationsLocal.setLastFetchAtUtc(nowUtc);
      return;
    }

    final List<Map<String, dynamic>> snap = await _fetchNotificationsSince(
      sinceUtc: lastFetchTime,
      sourceTag: 'notifications.latest',
      cachePolicy: FirestoreCachePolicy.memoryFirst,
    );
    final entities = snap.map(_asMap).map(_toEntity).toList(growable: false);
    if (entities.isNotEmpty) {
      await notificationsLocal.upsertAll(entities);
    }
    await notificationsLocal.setLastFetchAtUtc(nowUtc);
  } on FirestoreError catch (e) {
    if (e.code == 'permission-denied') {
      logger.w(
        'Notifications sync skipped: permission denied — check Firestore rules for collection: ${FirebaseCollections.notifications}',
      );
      return;
    }
    rethrow;
  }
}
