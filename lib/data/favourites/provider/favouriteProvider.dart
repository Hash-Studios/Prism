import 'package:Prism/data/pexels/model/wallpaperp.dart';
import 'package:Prism/data/wallhaven/model/wallpaper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:hive/hive.dart';
import 'package:Prism/global/globals.dart' as globals;

class FavouriteProvider extends ChangeNotifier {
  final databaseReference = Firestore.instance;
  List liked;
  Future<List> getDataBase() async {
    var uid = main.prefs.get("id");
    var box = Hive.box('favourites');
    if (globals.dirty || box.get('favourites') == null) {
      this.liked = [];
      await databaseReference
          .collection("users")
          .document(uid)
          .collection("images")
          .getDocuments()
          .then((value) {
        this.liked = [];
        value.documents.forEach((f) => this.liked.add(f.data));
        box.delete('favourites');
        box.put('favourites', this.liked);
        print("Favourites = " + box.get('favourites').length.toString());
        print("Favourites saved");
        globals.dirty = false;
      }).catchError((e) {
        print("data done with error");
      });
    } else {
      print("Fetching favs from cache");
      return box.get('favourites');
    }
    return this.liked;
  }

  void deleteDataByID(String id) async {
    var uid = main.prefs.get("id");
    try {
      await databaseReference
          .collection("users")
          .document(uid)
          .collection("images")
          .document(id)
          .delete();
    } catch (e) {
      print(e.toString());
    }
    await getDataBase();
  }

  void createDataByWall(String provider, WallPaper wallhaven, WallPaperP pexels,
      Map prism) async {
    var uid = main.prefs.get("id");
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
        "resolution": pexels.width.toString() + "x" + pexels.height.toString(),
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
    // await getDataBase();
  }

  Future favCheck(String id, String provider, WallPaper wallhaven,
      WallPaperP pexels, Map prism) async {
    int index;
    await getDataBase().then(
      (value) {
        value.forEach(
          (element) {
            if (element["id"] == id) {
              index = value.indexOf(element);
            }
          },
        );
        if (index == null) {
          print("Fav");
          createDataByWall(provider, wallhaven, pexels, prism);
          toasts.favWall();
        } else {
          toasts.unfavWall();
          deleteDataByID(id);
          return false;
        }
        globals.dirty = true;
      },
    );
  }

  Future<int> countFav() async {
    int favs;
    print("in countfav");
    await getDataBase().then((value) {
      print(value.length);
      favs = value.length;
    });
    return favs;
  }

  void deleteData() async {
    var uid = main.prefs.get("id");
    try {
      await databaseReference
          .collection("users")
          .document(uid)
          .collection("images")
          .getDocuments()
          .then((snapshot) {
        for (DocumentSnapshot ds in snapshot.documents) {
          ds.reference.delete();
        }
      });
    } catch (e) {
      print(e.toString());
    }
    await getDataBase();
  }
}
