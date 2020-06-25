import 'package:Prism/data/pexels/model/wallpaperp.dart';
import 'package:Prism/data/wallhaven/model/wallpaper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;

class FavouriteProvider extends ChangeNotifier {
  final databaseReference = Firestore.instance;
  List liked;
  Future<List> getDataBase() {
    this.liked = [];
    var uid = main.prefs.getString("id");
    databaseReference
        .collection("users")
        .document(uid)
        .collection("images")
        .getDocuments()
        .then((value) {
      print(value);
      value.documents.forEach((f) => this.liked.add(f.data));
      print(this.liked);
      return this.liked;
    });
  }

  void deleteDataByID(String id) {
    var uid = main.prefs.getString("id");
    try {
      databaseReference
          .collection("users")
          .document(uid)
          .collection("images")
          .document(id)
          .delete();
    } catch (e) {
      print(e.toString());
    }
  }

  void createDataByWall(
      String provider, WallPaper wallhaven, WallPaperP pexels) async {
    var uid = main.prefs.getString("id");
    if (provider == "WallHaven") {
      await databaseReference
          .collection("users")
          .document(uid)
          .collection("images")
          .document(wallhaven.id.toString())
          .setData({
        "id": wallhaven.id.toString(),
        "url": wallhaven.path.toString(),
        "thumb": wallhaven.thumbs["original"],
        "category": wallhaven.category.toString(),
        "provider": "WallHaven",
        "views": wallhaven.views.toString(),
        "resolution": wallhaven.resolution.toString(),
        "fav": wallhaven.favorites.toString(),
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
        "url": pexels.src["portrait"].toString(),
        "thumb": pexels.src["medium"],
        "category": "",
        "provider": "Pexels",
        "views": "",
        "resolution": pexels.width.toString() + "x" + pexels.height.toString(),
        "fav": "",
        "size": "",
        "photographer": pexels.photographer
      });
    }
  }
}
