import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PrismProvider extends ChangeNotifier {
  final databaseReference = Firestore.instance;
  List prismWalls;
  List subPrismWalls;
  Map wall;
  int page = 1;
  Future<List> getPrismWalls() async {
    this.prismWalls = [];
    this.subPrismWalls = [];
    await databaseReference
        .collection("walls")
        .orderBy("id")
        .getDocuments()
        .then((value) {
      this.prismWalls = [];
      value.documents.forEach((f) {
        this.prismWalls.add(f.data);
      });
      this.prismWalls.shuffle(Random.secure());
      print(this.prismWalls.length);
      this.subPrismWalls = this.prismWalls.sublist(0, 24);
    }).catchError((e) {
      print("data done with error");
    });
    return this.subPrismWalls;
  }

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
