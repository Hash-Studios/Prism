import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class FavouriteSetupProvider extends ChangeNotifier {
  final FirebaseFirestore databaseReference = FirebaseFirestore.instance;
  List? liked;
  Future<List?> getDataBase() async {
    final String uid = globals.prismUser.id;
    liked = [];
    await databaseReference
        .collection(USER_NEW_COLLECTION)
        .doc(uid)
        .collection("setups")
        .get()
        .then((value) {
      liked = [];
      for (final f in value.docs) {
        liked!.add(f.data());
      }
    }).catchError((e) {
      logger.d("data done with error");
    });

    return liked;
  }

  Future<bool> deleteDataByID(String id) async {
    final String uid = globals.prismUser.id;
    try {
      await databaseReference
          .collection(USER_NEW_COLLECTION)
          .doc(uid)
          .collection("setups")
          .doc(id)
          .delete();
    } catch (e) {
      logger.d(e.toString());
    }
    await getDataBase();
    return true;
  }

  Future<bool> createFavSetup(Map setup) async {
    final String uid = globals.prismUser.id;
    await databaseReference
        .collection(USER_NEW_COLLECTION)
        .doc(uid)
        .collection("setups")
        .doc(setup["id"].toString())
        .set({
      "by": setup["by"].toString() ?? "",
      "icon": setup["icon"].toString() ?? "",
      "icon_url": setup["icon_url"].toString() ?? "",
      "created_at": DateTime.now().toUtc(),
      "desc": setup["desc"].toString() ?? "",
      "email": setup["email"].toString() ?? "",
      "id": setup["id"].toString() ?? "",
      "image": setup["image"].toString() ?? "",
      "name": setup["name"].toString() ?? "",
      "userPhoto": setup["userPhoto"].toString() ?? "",
      "wall_id": setup["wall_id"].toString() ?? "",
      "wallpaper_provider": setup["wallpaper_provider"].toString() ?? "",
      "wallpaper_thumb": setup["wallpaper_thumb"].toString() ?? "",
      "wallpaper_url": setup["wallpaper_url"] ?? "",
      "widget": setup["widget"].toString() ?? "",
      "widget2": setup["widget2"].toString() ?? "",
      "widget_url": setup["widget_url"].toString() ?? "",
      "widget_url2": setup["widget_url2"].toString() ?? ""
    });

    return true;
  }

  Future favCheck(String id, Map? setup) async {
    int? index;
    await getDataBase().then(
      (value) {
        for (final element in value!) {
          if (element["id"] == id) {
            index = value.indexOf(element);
          }
        }
        if (index == null) {
          logger.d("Fav");
          createFavSetup(setup!);
          localFavSave(id);
        } else {
          localFavDelete(id);
          deleteDataByID(id);
          return false;
        }
      },
    );
  }

  bool localFavSave(String id) {
    final Box box = Hive.box('localFav');
    box.put(id, true);
    return true;
  }

  bool localFavDelete(String id) {
    final Box box = Hive.box('localFav');
    box.delete(id);
    return true;
  }

  Future<int> countFavSetups() async {
    int favs = 0;
    logger.d("in countfavsetup");
    await getDataBase().then((value) {
      logger.d(value!.length.toString());
      favs = value.length;
    });
    return favs;
  }

  Future<bool> deleteData() async {
    final String uid = globals.prismUser.id;
    try {
      await databaseReference
          .collection(USER_NEW_COLLECTION)
          .doc(uid)
          .collection("setups")
          .get()
          .then((snapshot) {
        for (final DocumentSnapshot ds in snapshot.docs) {
          ds.reference.delete();
        }
      });
    } catch (e) {
      logger.d(e.toString());
    }
    await getDataBase();
    return true;
  }
}
