import 'package:Prism/data/notifications/model/inAppNotifModel.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

final FirebaseFirestore databaseReference = FirebaseFirestore.instance;

Future<QuerySnapshot> getLastMonthNotifs(String modifier) async {
  return databaseReference
      .collection("notifications")
      .orderBy("createdAt", descending: true)
      .where("createdAt",
          isGreaterThan:
              DateTime.now().toUtc().subtract(const Duration(days: 30)))
      .where('modifier', isEqualTo: modifier)
      .get();
}

Future<QuerySnapshot> getLatestNotifs(String modifier) async {
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
          if (doc.data()['modifier'] != '' || doc.data()['modifier'] != null) {
            box.add(InAppNotif.fromSnapshot(doc.data()));
          }
        }
      });
    }
    if (globals.prismUser.premium == true) {
      getLatestNotifs('premium').then((snap) {
        for (final doc in snap.docs) {
          if (doc.data()['modifier'] != '' || doc.data()['modifier'] != null) {
            box.add(InAppNotif.fromSnapshot(doc.data()));
          }
        }
      });
    }
    getLatestNotifs('all').then((snap) {
      for (final doc in snap.docs) {
        if (doc.data()['modifier'] != '' || doc.data()['modifier'] != null) {
          box.add(InAppNotif.fromSnapshot(doc.data()));
        }
      }
    });
    getLatestNotifs(globals.currentAppVersion).then((snap) {
      for (final doc in snap.docs) {
        if (doc.data()['modifier'] != '' || doc.data()['modifier'] != null) {
          box.add(InAppNotif.fromSnapshot(doc.data()));
        }
      }
    });
    getLatestNotifs(globals.prismUser.email).then((snap) {
      for (final doc in snap.docs) {
        if (doc.data()['modifier'] != '' || doc.data()['modifier'] != null) {
          box.add(InAppNotif.fromSnapshot(doc.data()));
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
          if (doc.data()['modifier'] != '' || doc.data()['modifier'] != null) {
            box.add(InAppNotif.fromSnapshot(doc.data()));
          }
        }
      });
    }
    if (globals.prismUser.premium == true) {
      getLastMonthNotifs('premium').then((snap) {
        for (final doc in snap.docs) {
          if (doc.data()['modifier'] != '' || doc.data()['modifier'] != null) {
            box.add(InAppNotif.fromSnapshot(doc.data()));
          }
        }
      });
    }
    getLastMonthNotifs('all').then((snap) {
      for (final doc in snap.docs) {
        if (doc.data()['modifier'] != '' || doc.data()['modifier'] != null) {
          box.add(InAppNotif.fromSnapshot(doc.data()));
        }
      }
    });
    getLastMonthNotifs(globals.currentAppVersion).then((snap) {
      for (final doc in snap.docs) {
        if (doc.data()['modifier'] != '' || doc.data()['modifier'] != null) {
          box.add(InAppNotif.fromSnapshot(doc.data()));
        }
      }
    });
    getLastMonthNotifs(globals.prismUser.email).then((snap) {
      for (final doc in snap.docs) {
        if (doc.data()['modifier'] != '' || doc.data()['modifier'] != null) {
          box.add(InAppNotif.fromSnapshot(doc.data()));
        }
      }
    });
    main.prefs.put('lastFetchTime', DateTime.now());
  }
}
