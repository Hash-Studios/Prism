import 'package:Prism/data/notifications/model/notificationModel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/global/globals.dart' as globals;

final FirebaseFirestore databaseReference = FirebaseFirestore.instance;
Future<void> getNotifications() async {
  final Box<List> box = Hive.box('notifications');
  if (box.get('date') == null) {
    debugPrint("-------- Fetching fresh notifications ---------");
    await databaseReference
        .collection("notifications")
        .orderBy("createdAt")
        .get()
        .then((value) {
      debugPrint("-------- Fetched fresh notifications ---------");
      box.delete('notifications');
      for (final f in value.docs) {
        Map<String, dynamic> map;
        map = f.data();
        if (map['modifier'] == "free") {
          if (globals.prismUser.premium == false) {
            writeNotifications(map);
          }
        } else if (map['modifier'] == "premium") {
          if (globals.prismUser.premium == true) {
            writeNotifications(map);
          }
        } else if (map['modifier'] == "all") {
          writeNotifications(map);
        } else if (map['modifier'] == globals.currentAppVersion) {
          writeNotifications(map);
        } else if (map['modifier'] == globals.prismUser.email) {
          if (globals.prismUser.email != "") {
            writeNotifications(map);
          }
        }
      }
      debugPrint(
          "-------- ${value.docs.length} new notifications added ---------");
      box.put(
        'date',
        [DateTime.now()],
      );
      debugPrint("-------- ${DateTime.now()} Fetch Time ---------");
    }).catchError((e) {
      debugPrint(e.toString());
      debugPrint("-------- Notifications fetch error ---------");
    });
  } else if ((box.get('date')![0] as DateTime).compareTo(DateTime.now()) < 0) {
    debugPrint("-------- Fetching only new notifications ---------");
    await databaseReference
        .collection("notifications")
        .orderBy("createdAt")
        .get()
        .then((value) {
      int counter = 0;
      for (final f in value.docs) {
        Map<String, dynamic> map;
        map = f.data();
        if ((map['createdAt'] as Timestamp)
                .toDate()
                .compareTo(box.get('date')![0] as DateTime) >
            0) {
          bool unique = true;
          for (final notification in box.get('notifications')!) {
            if (map['notification']['title'].toString() ==
                notification.title.toString()) {
              unique = false;
            }
          }
          if (unique) {
            if (map['modifier'] == "free") {
              if (globals.prismUser.premium == false) {
                counter++;
                writeNotifications(map);
              }
            } else if (map['modifier'] == "premium") {
              if (globals.prismUser.premium == true) {
                counter++;
                writeNotifications(map);
              }
            } else if (map['modifier'] == "all") {
              counter++;
              writeNotifications(map);
            } else if (map['modifier'] == globals.currentAppVersion) {
              counter++;
              writeNotifications(map);
            } else if (map['modifier'] == globals.prismUser.email) {
              if (globals.prismUser.email != "") {
                counter++;
                writeNotifications(map);
              }
            }
          }
        }
      }
      debugPrint("-------- $counter new notifications ---------");
      box.put(
        'date',
        [DateTime.now()],
      );
      debugPrint("-------- ${DateTime.now()} Fetch Time ---------");
    });
  } else {
    debugPrint("-------- No need to refresh --------");
  }
}

void writeNotifications(Map<String, dynamic> message) {
  final Box<List> box = Hive.box('notifications');
  final notifications = box.get('notifications', defaultValue: []);
  notifications!.add(
    NotifData(
      title: message['notification']['title'] as String? ?? "Notification",
      desc: message['notification']['body'] as String? ?? "",
      imageUrl: message['data']['imageUrl'] as String? ??
          "https://w.wallhaven.cc/full/q6/wallhaven-q6mg5d.jpg",
      pageName: message['data']['pageName'] as String?,
      arguments: message['data']['arguments'] as List? ?? [],
      url: message['data']['url'] as String? ?? "",
      createdAt: (message['createdAt'] as Timestamp).toDate(),
    ),
  );
  box.put('notifications', notifications);
}
