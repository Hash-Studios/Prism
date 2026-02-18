import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/data/notifications/model/inAppNotifModel.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:hive_io/hive_io.dart';

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

DateTime? _asUtcDateTime(Object? raw) {
  if (raw is DateTime) {
    return raw.toUtc();
  }
  if (raw is String) {
    try {
      return DateTime.parse(raw).toUtc();
    } catch (_) {
      return null;
    }
  }
  return null;
}

List<String> _notificationModifiers() {
  final String audience = globals.prismUser.premium ? 'premium' : 'free';
  return <String>[
    audience,
    'all',
    globals.currentAppVersion.trim(),
    globals.prismUser.email.trim(),
  ].where((value) => value.isNotEmpty).toSet().toList(growable: false);
}

Future<List<Map<String, dynamic>>> _fetchNotificationsSince({
  required DateTime sinceUtc,
  required String sourceTag,
  int limit = _defaultNotifLimit,
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
        FirestoreFilter(field: "createdAt", op: FirestoreFilterOp.isGreaterThan, value: sinceUtc),
        FirestoreFilter(field: 'modifier', op: FirestoreFilterOp.whereIn, value: modifiers),
      ],
      orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
      limit: limit,
      dedupeWindowMs: 1500,
    ),
    (data, _) => data,
  );
}

String _notifKey(InAppNotif notif) {
  final String title = notif.title ?? '';
  final String body = notif.body ?? '';
  final String pageName = notif.pageName ?? '';
  final String url = notif.url ?? '';
  final String createdAt = notif.createdAt?.toUtc().toIso8601String() ?? '';
  return '$title|$body|$pageName|$url|$createdAt';
}

Future<void> _addUniqueNotifications(Box<InAppNotif> box, List<Map<String, dynamic>> docs) async {
  final Set<String> seen = box.values.map(_notifKey).toSet();
  for (final Map<String, dynamic> raw in docs) {
    try {
      final InAppNotif notif = InAppNotif.fromSnapshot(raw);
      final String key = _notifKey(notif);
      if (seen.add(key)) {
        await box.add(notif);
      }
    } catch (e) {
      logger.w('Skipping malformed in-app notification payload: $e');
    }
  }
}

Future<void> getNotifs() async {
  logger.d("Fetching notifs");
  final Box<InAppNotif> box = Hive.box('inAppNotifs');
  final DateTime nowUtc = DateTime.now().toUtc();
  final DateTime? lastFetchTime = _asUtcDateTime(main.prefs.get('lastFetchTime'));
  if (lastFetchTime == null) {
    logger.d("Fetching for first time");
    await box.clear();
    final List<Map<String, dynamic>> snap = await _fetchNotificationsSince(
      sinceUtc: nowUtc.subtract(const Duration(days: 30)),
      sourceTag: 'notifications.last_month',
    );
    await _addUniqueNotifications(box, snap.map(_asMap).toList(growable: false));
    main.prefs.put('lastFetchTime', nowUtc);
    return;
  }
  logger.d("Last fetch time $lastFetchTime");
  final List<Map<String, dynamic>> snap = await _fetchNotificationsSince(
    sinceUtc: lastFetchTime,
    sourceTag: 'notifications.latest',
  );
  await _addUniqueNotifications(box, snap.map(_asMap).toList(growable: false));
  main.prefs.put('lastFetchTime', nowUtc);
}
