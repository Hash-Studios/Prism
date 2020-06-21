import 'dart:convert';

import 'package:Prism/data/pexels/model/wallpaperp.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PexelsProvider extends ChangeNotifier {
  List<WallPaperP> wallsP = [];
  int pageGetDataP = 1;
  int pageGetQueryP = 1;
  void getDataP() async {
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
                    id: resp["photos"][i]["id"],
                    url: resp["photos"][i]["url"],
                    width: resp["photos"][i]["width"],
                    height: resp["photos"][i]["height"],
                    photographer: resp["photos"][i]["photographer"],
                    src: resp["photos"][i]["category"],
                    current_page: resp["page"]),
              );
        }
        this.pageGetDataP = int.parse(resp["page"]) + 1;
      },
    );
    notifyListeners();
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

  void getWallsPbyQuery(String query) async {
    http
        .get(
            "https://api.pexels.com/v1/search?query=$query&per_page=80&page=${this.pageGetQueryP}")
        .then(
      (http.Response response) {
        var resp = json.decode(response.body);
        for (int i = 0; i < resp["photos"].length; i++) {
          this.wallsP.add(
                WallPaperP(
                    id: resp["photos"][i]["id"],
                    url: resp["photos"][i]["url"],
                    width: resp["photos"][i]["width"],
                    height: resp["photos"][i]["height"],
                    photographer: resp["photos"][i]["photographer"],
                    src: resp["photos"][i]["category"],
                    current_page: resp["page"]),
              );
        }
        this.pageGetQueryP = int.parse(resp["page"]) + 1;
      },
    );
    notifyListeners();
  }
}
