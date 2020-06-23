import 'dart:convert';

import 'package:Prism/data/pexels/model/wallpaperp.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PexelsProvider extends ChangeNotifier {
  List<WallPaperP> wallsP = [];
  int pageGetDataP = 1;
  int pageGetQueryP = 1;
  int pageAbstractP = 1;
  int pageNatureP = 1;
  int pageRedP = 1;
  int pageBlueP = 1;
  int pageGreenP = 1;
  Future<List<WallPaperP>> getDataP() async {
    http.get(
        "https://api.pexels.com/v1/curated?per_page=24&page=${this.pageGetDataP}",
        headers: {
          "Authorization":
              "563492ad6f9170000100000107272bb5cab346b68e27263fbf1b6a72"
        }).then(
      (http.Response response) {
        var resp = json.decode(response.body);
        for (int i = 0; i < resp["photos"].length; i++) {
          this.wallsP.add(
                WallPaperP(
                    id: resp["photos"][i]["id"].toString(),
                    url: resp["photos"][i]["url"],
                    width: resp["photos"][i]["width"].toString(),
                    height: resp["photos"][i]["height"].toString(),
                    photographer: resp["photos"][i]["photographer"],
                    src: resp["photos"][i]["src"],
                    current_page: resp["page"]),
              );
        }
        this.pageGetDataP = resp["page"] + 1;
        print("data done");
        return this.wallsP;
      },
    );
  }

  Future<WallPaperP> getWallbyIDP(String id) async {
    http.get("https://api.pexels.com/v1/photos/$id").then(
      (http.Response response) {
        var resp = json.decode(response.body)["data"];
        return WallPaperP(
            id: resp["id"],
            url: resp["url"],
            width: resp["width"],
            height: resp["height"],
            photographer: resp["photographer"],
            src: resp["category"]);
      },
    );
  }

  Future<List<WallPaperP>> getWallsPbyQuery(String query) async {
    http.get(
        "https://api.pexels.com/v1/search?query=$query&per_page=80&page=${this.pageGetQueryP}",
        headers: {
          "Authorization":
              "563492ad6f9170000100000107272bb5cab346b68e27263fbf1b6a72"
        }).then(
      (http.Response response) {
        var resp = json.decode(response.body);
        for (int i = 0; i < resp["photos"].length; i++) {
          this.wallsP.add(
                WallPaperP(
                    id: resp["photos"][i]["id"].toString(),
                    url: resp["photos"][i]["url"],
                    width: resp["photos"][i]["width"].toString(),
                    height: resp["photos"][i]["height"].toString(),
                    photographer: resp["photos"][i]["photographer"],
                    src: resp["photos"][i]["src"],
                    current_page: resp["page"]),
              );
        }
        this.pageGetQueryP = resp["page"] + 1;
        print("data done");
        return this.wallsP;
      },
    );
  }

  Future<List<WallPaperP>> getAbstractWalls() async {
    http.get(
        "https://api.pexels.com/v1/search?query=abstract&per_page=80&page=${this.pageAbstractP}",
        headers: {
          "Authorization":
              "563492ad6f9170000100000107272bb5cab346b68e27263fbf1b6a72"
        }).then(
      (http.Response response) {
        var resp = json.decode(response.body);
        for (int i = 0; i < resp["photos"].length; i++) {
          this.wallsP.add(
                WallPaperP(
                    id: resp["photos"][i]["id"].toString(),
                    url: resp["photos"][i]["url"],
                    width: resp["photos"][i]["width"].toString(),
                    height: resp["photos"][i]["height"].toString(),
                    photographer: resp["photos"][i]["photographer"],
                    src: resp["photos"][i]["src"],
                    current_page: resp["page"]),
              );
        }
        this.pageAbstractP = resp["page"] + 1;
        print("data done");
        return this.wallsP;
      },
    );
  }

  Future<List<WallPaperP>> getNatureWalls() async {
    http.get(
        "https://api.pexels.com/v1/search?query=nature&per_page=80&page=${this.pageNatureP}",
        headers: {
          "Authorization":
              "563492ad6f9170000100000107272bb5cab346b68e27263fbf1b6a72"
        }).then(
      (http.Response response) {
        var resp = json.decode(response.body);
        for (int i = 0; i < resp["photos"].length; i++) {
          this.wallsP.add(
                WallPaperP(
                    id: resp["photos"][i]["id"].toString(),
                    url: resp["photos"][i]["url"],
                    width: resp["photos"][i]["width"].toString(),
                    height: resp["photos"][i]["height"].toString(),
                    photographer: resp["photos"][i]["photographer"],
                    src: resp["photos"][i]["src"],
                    current_page: resp["page"]),
              );
        }
        this.pageNatureP = resp["page"] + 1;
        print("data done");
        return this.wallsP;
      },
    );
  }

  Future<List<WallPaperP>> getRedWalls() async {
    String query = "color: red";
    http.get(
        "https://api.pexels.com/v1/search?query=$query&per_page=80&page=${this.pageRedP}",
        headers: {
          "Authorization":
              "563492ad6f9170000100000107272bb5cab346b68e27263fbf1b6a72"
        }).then(
      (http.Response response) {
        var resp = json.decode(response.body);
        for (int i = 0; i < resp["photos"].length; i++) {
          this.wallsP.add(
                WallPaperP(
                    id: resp["photos"][i]["id"].toString(),
                    url: resp["photos"][i]["url"],
                    width: resp["photos"][i]["width"].toString(),
                    height: resp["photos"][i]["height"].toString(),
                    photographer: resp["photos"][i]["photographer"],
                    src: resp["photos"][i]["src"],
                    current_page: resp["page"]),
              );
        }
        this.pageRedP = resp["page"] + 1;
        print("data done");
        return this.wallsP;
      },
    );
  }

  Future<List<WallPaperP>> getBlueWalls() async {
    String query = "color: blue";
    http.get(
        "https://api.pexels.com/v1/search?query=$query&per_page=80&page=${this.pageBlueP}",
        headers: {
          "Authorization":
              "563492ad6f9170000100000107272bb5cab346b68e27263fbf1b6a72"
        }).then(
      (http.Response response) {
        var resp = json.decode(response.body);
        for (int i = 0; i < resp["photos"].length; i++) {
          this.wallsP.add(
                WallPaperP(
                    id: resp["photos"][i]["id"].toString(),
                    url: resp["photos"][i]["url"],
                    width: resp["photos"][i]["width"].toString(),
                    height: resp["photos"][i]["height"].toString(),
                    photographer: resp["photos"][i]["photographer"],
                    src: resp["photos"][i]["src"],
                    current_page: resp["page"]),
              );
        }
        this.pageBlueP = resp["page"] + 1;
        print("data done");
        return this.wallsP;
      },
    );
  }

  Future<List<WallPaperP>> getGreenWalls() async {
    String query = "color: green";
    http.get(
        "https://api.pexels.com/v1/search?query=$query&per_page=80&page=${this.pageGreenP}",
        headers: {
          "Authorization":
              "563492ad6f9170000100000107272bb5cab346b68e27263fbf1b6a72"
        }).then(
      (http.Response response) {
        var resp = json.decode(response.body);
        for (int i = 0; i < resp["photos"].length; i++) {
          this.wallsP.add(
                WallPaperP(
                    id: resp["photos"][i]["id"].toString(),
                    url: resp["photos"][i]["url"],
                    width: resp["photos"][i]["width"].toString(),
                    height: resp["photos"][i]["height"].toString(),
                    photographer: resp["photos"][i]["photographer"],
                    src: resp["photos"][i]["src"],
                    current_page: resp["page"]),
              );
        }
        this.pageGreenP = resp["page"] + 1;
        print("data done");
        return this.wallsP;
      },
    );
  }
}
