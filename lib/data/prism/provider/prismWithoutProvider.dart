import 'package:Prism/routes/router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

final databaseReference = Firestore.instance;
List prismWalls;
List subPrismWalls;
Map wall;
int page = 1;
Future<List> getPrismWalls() async {
  if (navStack.last == "Home") {
    var box = Hive.box('wallpapers');
    if ((box.get('date') !=
            DateFormat("yy-MM-dd").format(
              DateTime.now(),
            )) ||
        (box.get('wallpapers') == null) ||
        (box.get('wallpapers') == [])) {
      prismWalls = [];
      subPrismWalls = [];
      await databaseReference
          .collection("walls")
          .where('review', isEqualTo: true)
          .orderBy("createdAt", descending: true)
          .getDocuments()
          .then((value) {
        prismWalls = [];
        value.documents.forEach((f) {
          var map = f.data;
          map['createdAt'] = map['createdAt'].toString();
          prismWalls.add(map);
        });
        box.delete('wallpapers');
        if (prismWalls != []) {
          box.put('wallpapers', prismWalls);
          print("Wallpapers saved");
          box.put(
            'date',
            DateFormat("yy-MM-dd").format(
              DateTime.now(),
            ),
          );
          print(prismWalls.length);
          subPrismWalls = box.get('wallpapers').sublist(0, 24);
        } else {
          print("Not connected to Internet");
          subPrismWalls = [];
        }
      }).catchError((e) {
        print(e.toString());
        print("data done with error");
      });
    } else {
      print("Community : Data Fetched from cache");
      prismWalls = [];
      subPrismWalls = [];
      prismWalls = box.get('wallpapers');
      subPrismWalls = prismWalls.sublist(0, 24);
    }
  } else {
    print("Refresh blocked");
  }
  return subPrismWalls;
}

// Future<List> getPrismWalls() async {
//   prismWalls = [];
//   subPrismWalls = [];
//   await databaseReference.collection("walls").getDocuments().then((value) {
//     value.documents.forEach((f) {
//       f.reference.updateData(<String, dynamic>{"createdAt": DateTime.now()});
//     });
//   }).catchError((e) {
//     print(e.toString());
//     print("data done with error");
//   });
//   return subPrismWalls;
// }

List seeMorePrism() {
  int len = prismWalls.length;
  double pages = len / 24;
  print(len);
  print(pages);
  print(page);
  if (page < pages.floor()) {
    subPrismWalls.addAll(
        prismWalls.sublist(subPrismWalls.length, subPrismWalls.length + 24));
    page += 1;
  } else {
    subPrismWalls.addAll(prismWalls.sublist(subPrismWalls.length));
  }
  return subPrismWalls;
}

Future<Map> getDataByID(String id) async {
  wall = null;
  await databaseReference.collection("walls").getDocuments().then((value) {
    value.documents.forEach((element) {
      if (element.data["id"] == id) {
        wall = element.data;
      }
    });
    return wall;
  });
}
