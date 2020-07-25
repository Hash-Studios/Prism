import 'dart:math';
import 'package:Prism/routes/router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

class PrismProvider extends ChangeNotifier {
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
        this.prismWalls = [];
        this.subPrismWalls = [];
        await databaseReference
            .collection("walls")
            .where('review', isEqualTo: true)
            .orderBy("id")
            .getDocuments()
            .then((value) {
          this.prismWalls = [];
          value.documents.forEach((f) {
            var map = f.data;
            map['createdAt'] = map['createdAt'].toString();
            this.prismWalls.add(map);
          });
          this.prismWalls.shuffle(Random.secure());
          box.delete('wallpapers');
          box.put('wallpapers', prismWalls);
          print("Wallpapers saved");
          box.put(
            'date',
            DateFormat("yy-MM-dd").format(
              DateTime.now(),
            ),
          );
          print(this.prismWalls.length);
          this.subPrismWalls = box.get('wallpapers').sublist(0, 24);
        }).catchError((e) {
          print(e.toString());
          print("data done with error");
        });
      } else {
        print("Fetching data from cache");
        this.prismWalls = [];
        this.subPrismWalls = [];
        this.prismWalls = box.get('wallpapers');
        this.prismWalls.shuffle(Random.secure());
        this.subPrismWalls = this.prismWalls.sublist(0, 24);
      }
    } else {
      print("Refresh blocked");
    }
    return this.subPrismWalls;
  }

  // Future<List> getPrismWalls() async {
  //   this.prismWalls = [];
  //   this.subPrismWalls = [];
  //   await databaseReference.collection("walls").getDocuments().then((value) {
  //     value.documents.forEach((f) {
  //       f.reference.updateData(<String, dynamic>{"createdAt": DateTime.now()});
  //     });
  //   }).catchError((e) {
  //     print(e.toString());
  //     print("data done with error");
  //   });
  //   return this.subPrismWalls;
  // }

  List seeMorePrism() {
    int len = this.prismWalls.length;
    double pages = len / 24;
    print(len);
    print(pages);
    print(this.page);
    if (this.page < pages.round()) {
      this.subPrismWalls.addAll(this
          .prismWalls
          .sublist(this.subPrismWalls.length, this.subPrismWalls.length + 24));
      this.page += 1;
    } else {
      this
          .subPrismWalls
          .addAll(this.prismWalls.sublist(this.subPrismWalls.length));
    }
    return this.subPrismWalls;
  }

  Future<Map> getDataByID(String id) async {
    this.wall = null;
    await databaseReference.collection("walls").getDocuments().then((value) {
      value.documents.forEach((element) {
        if (element.data["id"] == id) {
          this.wall = element.data;
        }
      });
      notifyListeners();
      return this.wall;
    });
  }
}
