import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/data/notifications/model/inAppNotifModel.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:hive/hive.dart';

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

Future<List<Map<String, dynamic>>> getLastMonthNotifs(String modifier) async {
  return firestoreClient.query<Map<String, dynamic>>(
    FirestoreQuerySpec(
      collection: FirebaseCollections.notifications,
      sourceTag: 'notifications.last_month',
      filters: <FirestoreFilter>[
        FirestoreFilter(
          field: "createdAt",
          op: FirestoreFilterOp.isGreaterThan,
          value: DateTime.now().toUtc().subtract(const Duration(days: 30)),
        ),
        FirestoreFilter(field: 'modifier', op: FirestoreFilterOp.isEqualTo, value: modifier),
      ],
      orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
    ),
    (data, _) => data,
  );
}

Future<List<Map<String, dynamic>>> getLatestNotifs(String modifier) async {
  return firestoreClient.query<Map<String, dynamic>>(
    FirestoreQuerySpec(
      collection: FirebaseCollections.notifications,
      sourceTag: 'notifications.latest',
      filters: <FirestoreFilter>[
        FirestoreFilter(
            field: "createdAt", op: FirestoreFilterOp.isGreaterThan, value: main.prefs.get('lastFetchTime')),
        FirestoreFilter(field: 'modifier', op: FirestoreFilterOp.isEqualTo, value: modifier),
      ],
      orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
    ),
    (data, _) => data,
  );
}

Future<void> getNotifs() async {
  logger.d("Fetching notifs");
  final Box<InAppNotif> box = Hive.box('inAppNotifs');
  if (main.prefs.get('lastFetchTime') != null) {
    logger.d("Last fetch time ${main.prefs.get('lastFetchTime')}");
    if (globals.prismUser.premium == false) {
      getLatestNotifs('free').then((snap) {
        for (final doc in snap) {
          final data = _asMap(doc);
          if (data['modifier'] != '' || data['modifier'] != null) {
            box.add(InAppNotif.fromSnapshot(data));
          }
        }
      });
    }
    if (globals.prismUser.premium == true) {
      getLatestNotifs('premium').then((snap) {
        for (final doc in snap) {
          final data = _asMap(doc);
          if (data['modifier'] != '' || data['modifier'] != null) {
            box.add(InAppNotif.fromSnapshot(data));
          }
        }
      });
    }
    getLatestNotifs('all').then((snap) {
      for (final doc in snap) {
        final data = _asMap(doc);
        if (data['modifier'] != '' || data['modifier'] != null) {
          box.add(InAppNotif.fromSnapshot(data));
        }
      }
    });
    getLatestNotifs(globals.currentAppVersion).then((snap) {
      for (final doc in snap) {
        final data = _asMap(doc);
        if (data['modifier'] != '' || data['modifier'] != null) {
          box.add(InAppNotif.fromSnapshot(data));
        }
      }
    });
    getLatestNotifs(globals.prismUser.email).then((snap) {
      for (final doc in snap) {
        final data = _asMap(doc);
        if (data['modifier'] != '' || data['modifier'] != null) {
          box.add(InAppNotif.fromSnapshot(data));
        }
      }
    });
    main.prefs.put('lastFetchTime', DateTime.now());
  } else {
    logger.d("Fetching for first time");
    box.clear();
    if (globals.prismUser.premium == false) {
      getLastMonthNotifs('free').then((snap) {
        for (final doc in snap) {
          final data = _asMap(doc);
          if (data['modifier'] != '' || data['modifier'] != null) {
            box.add(InAppNotif.fromSnapshot(data));
          }
        }
      });
    }
    if (globals.prismUser.premium == true) {
      getLastMonthNotifs('premium').then((snap) {
        for (final doc in snap) {
          final data = _asMap(doc);
          if (data['modifier'] != '' || data['modifier'] != null) {
            box.add(InAppNotif.fromSnapshot(data));
          }
        }
      });
    }
    getLastMonthNotifs('all').then((snap) {
      for (final doc in snap) {
        final data = _asMap(doc);
        if (data['modifier'] != '' || data['modifier'] != null) {
          box.add(InAppNotif.fromSnapshot(data));
        }
      }
    });
    getLastMonthNotifs(globals.currentAppVersion).then((snap) {
      for (final doc in snap) {
        final data = _asMap(doc);
        if (data['modifier'] != '' || data['modifier'] != null) {
          box.add(InAppNotif.fromSnapshot(data));
        }
      }
    });
    getLastMonthNotifs(globals.prismUser.email).then((snap) {
      for (final doc in snap) {
        final data = _asMap(doc);
        if (data['modifier'] != '' || data['modifier'] != null) {
          box.add(InAppNotif.fromSnapshot(data));
        }
      }
    });
    main.prefs.put('lastFetchTime', DateTime.now());
  }
}
