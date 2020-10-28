import 'package:Prism/data/pexels/model/wallpaperp.dart';
import 'package:Prism/data/wallhaven/model/wallpaper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;

class FavouriteProvider extends ChangeNotifier {
  final Firestore databaseReference = Firestore.instance;
  List liked;
  Future<List> getDataBase() async {
    final String uid = main.prefs.get("id") as String;
    liked = [];
    await databaseReference
        .collection("users")
        .document(uid)
        .collection("images")
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
          .collection("images")
          .document(id)
          .delete();
    } catch (e) {
      debugPrint(e.toString());
    }
    await getDataBase();
    return true;
  }

  Future<bool> createDataByWall(String provider, WallPaper wallhaven,
      WallPaperP pexels, Map prism) async {
    final String uid = main.prefs.get("id") as String;
    if (provider == "WallHaven") {
      await databaseReference
          .collection("users")
          .document(uid)
          .collection("images")
          .document(wallhaven.id.toString())
          .setData({
        "id": wallhaven.id.toString(),
        "url": wallhaven.path.toString(),
        "thumb": wallhaven.thumbs["original"].toString(),
        "category": wallhaven.category.toString(),
        "provider": "WallHaven",
        "views": wallhaven.views.toString(),
        "resolution": wallhaven.resolution.toString(),
        "fav": wallhaven.favourites.toString(),
        "size": wallhaven.file_size.toString(),
        "photographer": ""
      });
    } else if (provider == "Pexels") {
      await databaseReference
          .collection("users")
          .document(uid)
          .collection("images")
          .document(pexels.id.toString())
          .setData({
        "id": pexels.id.toString(),
        "url": pexels.src["original"].toString(),
        "thumb": pexels.src["medium"].toString(),
        "category": "",
        "provider": "Pexels",
        "views": "",
        "resolution": "${pexels.width}x${pexels.height}",
        "fav": "",
        "size": "",
        "photographer": pexels.photographer.toString()
      });
    } else if (provider == "Prism") {
      await databaseReference
          .collection("users")
          .document(uid)
          .collection("images")
          .document(prism["id"].toString())
          .setData({
        "id": prism["id"].toString(),
        "url": prism["wallpaper_url"].toString(),
        "thumb": prism["wallpaper_thumb"].toString(),
        "category": prism["desc"].toString(),
        "provider": "Prism",
        "views": "",
        "resolution": prism["resolution"].toString(),
        "fav": "",
        "size": prism["size"].toString(),
        "photographer": prism["by"].toString()
      });
    }
    return true;
  }

  Future favCheck(String id, String provider, WallPaper wallhaven,
      WallPaperP pexels, Map prism) async {
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
          createDataByWall(provider, wallhaven, pexels, prism);
          toasts.codeSend("Wallpaper added to favourites!");
        } else {
          toasts.error("Wallpaper removed from favourites!");
          deleteDataByID(id);
          return false;
        }
      },
    );
  }

  Future<int> countFav() async {
    int favs = 0;
    debugPrint("in countfav");
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
          .collection("images")
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
