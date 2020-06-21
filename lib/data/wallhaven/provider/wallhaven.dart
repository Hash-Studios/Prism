import 'dart:convert';

import 'package:Prism/data/wallhaven/model/tag.dart';
import 'package:Prism/data/wallhaven/model/wallpaper.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WallHavenProvider extends ChangeNotifier {
  List<WallPaper> walls = [];
  void getData() async {
    http.get("https://wallhaven.cc/api/v1/search").then(
      (http.Response response) {
        var resp = json.decode(response.body)["data"];
        for (int i = 0; i < resp.length; i++) {
          this.walls.add(
                WallPaper(
                  id: resp[i]["id"],
                  url: resp[i]["url"],
                  short_url: resp[i]["short_url"],
                  views: resp[i]["views"],
                  favorites: resp[i]["favorites"],
                  category: resp[i]["category"],
                  dimension_x: resp[i]["dimension_x"],
                  dimension_y: resp[i]["dimension_y"],
                  resolution: resp[i]["id"],
                  file_size: resp[i]["file_size"],
                  colors: resp[i]["colors"],
                  path: resp[i]["path"],
                  thumbs: resp[i]["thumbs"],
                ),
              );
        }
      },
    );
    notifyListeners();
  }

  Future<WallPaper> getWallbyID(String id) async {
    http.get("https://wallhaven.cc/api/v1/w/$id").then(
      (http.Response response) {
        var resp = json.decode(response.body)["data"];
        return WallPaper(
          id: resp["id"],
          url: resp["url"],
          short_url: resp["short_url"],
          views: resp["views"],
          favorites: resp["favorites"],
          category: resp["category"],
          dimension_x: resp["dimension_x"],
          dimension_y: resp["dimension_y"],
          resolution: resp["id"],
          file_size: resp["file_size"],
          colors: resp["colors"],
          path: resp["path"],
          thumbs: resp["thumbs"],
          tags: new List<Tag>.generate(
            resp["tags"].length,
            (tag) => Tag(
              id: resp["tags"][tag]["id"],
              name: resp["tags"][tag]["name"],
              alias: resp["tags"][tag]["alias"],
              category_id: resp["tags"][tag]["category_id"],
              category: resp["tags"][tag]["category"],
            ),
          ),
        );
      },
    );
  }

  void getWallsbyQuery(String query) async {
    http.get("https://wallhaven.cc/api/v1/search?query=$query").then(
      (http.Response response) {
        var resp = json.decode(response.body)["data"];
        for (int i = 0; i < resp.length; i++) {
          this.walls.add(
                WallPaper(
                  id: resp[i]["id"],
                  url: resp[i]["url"],
                  short_url: resp[i]["short_url"],
                  views: resp[i]["views"],
                  favorites: resp[i]["favorites"],
                  category: resp[i]["category"],
                  dimension_x: resp[i]["dimension_x"],
                  dimension_y: resp[i]["dimension_y"],
                  resolution: resp[i]["id"],
                  file_size: resp[i]["file_size"],
                  colors: resp[i]["colors"],
                  path: resp[i]["path"],
                  thumbs: resp[i]["thumbs"],
                ),
              );
        }
      },
    );
    notifyListeners();
  }

  void getWallsbyTag(String tagname) async {
    http.get("https://wallhaven.cc/api/v1/search?query=$tagname").then(
      (http.Response response) {
        var resp = json.decode(response.body)["data"];
        for (int i = 0; i < resp.length; i++) {
          this.walls.add(
                WallPaper(
                  id: resp[i]["id"],
                  url: resp[i]["url"],
                  short_url: resp[i]["short_url"],
                  views: resp[i]["views"],
                  favorites: resp[i]["favorites"],
                  category: resp[i]["category"],
                  dimension_x: resp[i]["dimension_x"],
                  dimension_y: resp[i]["dimension_y"],
                  resolution: resp[i]["id"],
                  file_size: resp[i]["file_size"],
                  colors: resp[i]["colors"],
                  path: resp[i]["path"],
                  thumbs: resp[i]["thumbs"],
                ),
              );
        }
      },
    );
    notifyListeners();
  }
}
