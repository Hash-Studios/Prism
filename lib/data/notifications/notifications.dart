import 'package:Prism/data/notifications/model/inAppNotifModel.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

final FirebaseFirestore databaseReference = FirebaseFirestore.instance;

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

Future<QuerySnapshot<Map<String, dynamic>>> getLastMonthNotifs(String modifier) async {
  return databaseReference
      .collection("notifications")
      .orderBy("createdAt", descending: true)
      .where("createdAt", isGreaterThan: DateTime.now().toUtc().subtract(const Duration(days: 30)))
      .where('modifier', isEqualTo: modifier)
      .get();
}

Future<QuerySnapshot<Map<String, dynamic>>> getLatestNotifs(String modifier) async {
  return databaseReference
      .collection("notifications")
      .orderBy("createdAt", descending: true)
      .where("createdAt", isGreaterThan: main.prefs.get('lastFetchTime'))
      .where('modifier', isEqualTo: modifier)
      .get();
}

Future<void> getNotifs() async {
  logger.d("Fetching notifs");
  final Box<InAppNotif> box = Hive.box('inAppNotifs');
  if (main.prefs.get('lastFetchTime') != null) {
    logger.d("Last fetch time ${main.prefs.get('lastFetchTime')}");
    if (globals.prismUser.premium == false) {
      getLatestNotifs('free').then((snap) {
        for (final doc in snap.docs) {
          final data = _asMap(doc.data());
          if (data['modifier'] != '' || data['modifier'] != null) {
            box.add(InAppNotif.fromSnapshot(data));
          }
        }
      });
    }
    if (globals.prismUser.premium == true) {
      getLatestNotifs('premium').then((snap) {
        for (final doc in snap.docs) {
          final data = _asMap(doc.data());
          if (data['modifier'] != '' || data['modifier'] != null) {
            box.add(InAppNotif.fromSnapshot(data));
          }
        }
      });
    }
    getLatestNotifs('all').then((snap) {
      for (final doc in snap.docs) {
        final data = _asMap(doc.data());
        if (data['modifier'] != '' || data['modifier'] != null) {
          box.add(InAppNotif.fromSnapshot(data));
        }
      }
    });
    getLatestNotifs(globals.currentAppVersion).then((snap) {
      for (final doc in snap.docs) {
        final data = _asMap(doc.data());
        if (data['modifier'] != '' || data['modifier'] != null) {
          box.add(InAppNotif.fromSnapshot(data));
        }
      }
    });
    getLatestNotifs(globals.prismUser.email).then((snap) {
      for (final doc in snap.docs) {
        final data = _asMap(doc.data());
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
        for (final doc in snap.docs) {
          final data = _asMap(doc.data());
          if (data['modifier'] != '' || data['modifier'] != null) {
            box.add(InAppNotif.fromSnapshot(data));
          }
        }
      });
    }
    if (globals.prismUser.premium == true) {
      getLastMonthNotifs('premium').then((snap) {
        for (final doc in snap.docs) {
          final data = _asMap(doc.data());
          if (data['modifier'] != '' || data['modifier'] != null) {
            box.add(InAppNotif.fromSnapshot(data));
          }
        }
      });
    }
    getLastMonthNotifs('all').then((snap) {
      for (final doc in snap.docs) {
        final data = _asMap(doc.data());
        if (data['modifier'] != '' || data['modifier'] != null) {
          box.add(InAppNotif.fromSnapshot(data));
        }
      }
    });
    getLastMonthNotifs(globals.currentAppVersion).then((snap) {
      for (final doc in snap.docs) {
        final data = _asMap(doc.data());
        if (data['modifier'] != '' || data['modifier'] != null) {
          box.add(InAppNotif.fromSnapshot(data));
        }
      }
    });
    getLastMonthNotifs(globals.prismUser.email).then((snap) {
      for (final doc in snap.docs) {
        final data = _asMap(doc.data());
        if (data['modifier'] != '' || data['modifier'] != null) {
          box.add(InAppNotif.fromSnapshot(data));
        }
      }
    });
    main.prefs.put('lastFetchTime', DateTime.now());
  }
}
