import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;

class FavouriteSetupProvider extends ChangeNotifier {
  final Firestore databaseReference = Firestore.instance;
  List liked;
  Future<List> getDataBase() async {
    final String uid = main.prefs.get("id") as String;
    liked = [];
    await databaseReference
        .collection("users")
        .document(uid)
        .collection("setups")
        .getDocuments()
        .then((value) {
      liked = [];
      for (final f in value.documents) {
        liked.add(f.data);
      }
    }).catchError((e) {
      debugPrint("data done with error");
    });

    return liked;
  }

  Future<bool> deleteDataByID(String id) async {
    final String uid = main.prefs.get("id") as String;
    try {
      await databaseReference
          .collection("users")
          .document(uid)
          .collection("setups")
          .document(id)
          .delete();
    } catch (e) {
      debugPrint(e.toString());
    }
    await getDataBase();
    return true;
  }

  Future<bool> createFavSetup(Map setup) async {
    final String uid = main.prefs.get("id") as String;
    await databaseReference
        .collection("users")
        .document(uid)
        .collection("setups")
        .document(setup["id"].toString())
        .setData({
      "by": setup["by"].toString() ?? "",
      "icon": setup["icon"].toString() ?? "",
      "icon_url": setup["icon_url"].toString() ?? "",
      "created_at": DateTime.now(),
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

  Future favCheck(String id, Map setup) async {
    int index;
    await getDataBase().then(
      (value) {
        for (final element in value) {
          if (element["id"] == id) {
            index = value.indexOf(element);
          }
        }
        if (index == null) {
          debugPrint("Fav");
          createFavSetup(setup);
          toasts.codeSend("Setup added to favourites!");
        } else {
          toasts.error("Setup removed from favourites!");
          deleteDataByID(id);
          return false;
        }
      },
    );
  }

  Future<int> countFavSetups() async {
    int favs = 0;
    debugPrint("in countfavsetup");
    await getDataBase().then((value) {
      debugPrint(value.length.toString());
      favs = value.length;
    });
    return favs;
  }

  Future<bool> deleteData() async {
    final String uid = main.prefs.get("id") as String;
    try {
      await databaseReference
          .collection("users")
          .document(uid)
          .collection("setups")
          .getDocuments()
          .then((snapshot) {
        for (final DocumentSnapshot ds in snapshot.documents) {
          ds.reference.delete();
        }
      });
    } catch (e) {
      debugPrint(e.toString());
    }
    await getDataBase();
    return true;
  }
}
