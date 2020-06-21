import 'dart:convert';

import 'package:Prism/data/wallhaven/model/tag.dart';
import 'package:Prism/data/wallhaven/model/wallpaper.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WallHavenProvider extends ChangeNotifier {
  List<WallPaper> walls = [];
  int pageGetData = 1;
  int pageGetQuery = 1;
  int pageGetTag = 1;
  void getData() async {
    http
        .get("https://wallhaven.cc/api/v1/search?page=${this.pageGetData}")
        .then(
      (http.Response response) {
        var resp = json.decode(response.body);
        for (int i = 0; i < resp.length; i++) {
          this.walls.add(
                WallPaper(
                    id: resp["data"][i]["id"],
                    url: resp["data"][i]["url"],
                    short_url: resp["data"][i]["short_url"],
                    views: resp["data"][i]["views"],
                    favorites: resp["data"][i]["favorites"],
                    category: resp["data"][i]["category"],
                    dimension_x: resp["data"][i]["dimension_x"],
                    dimension_y: resp["data"][i]["dimension_y"],
                    resolution: resp["data"][i]["id"],
                    file_size: resp["data"][i]["file_size"],
                    colors: resp["data"][i]["colors"],
                    path: resp["data"][i]["path"],
                    thumbs: resp["data"][i]["thumbs"],
                    current_page: resp["meta"]["current_page"]),
              );
        }
        this.pageGetData += 1;
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
    http
        .get(
            "https://wallhaven.cc/api/v1/search?query=$query&page=${this.pageGetQuery}")
        .then(
      (http.Response response) {
        var resp = json.decode(response.body);
        for (int i = 0; i < resp.length; i++) {
          this.walls.add(
                WallPaper(
                    id: resp["data"][i]["id"],
                    url: resp["data"][i]["url"],
                    short_url: resp["data"][i]["short_url"],
                    views: resp["data"][i]["views"],
                    favorites: resp["data"][i]["favorites"],
                    category: resp["data"][i]["category"],
                    dimension_x: resp["data"][i]["dimension_x"],
                    dimension_y: resp["data"][i]["dimension_y"],
                    resolution: resp["data"][i]["id"],
                    file_size: resp["data"][i]["file_size"],
                    colors: resp["data"][i]["colors"],
                    path: resp["data"][i]["path"],
                    thumbs: resp["data"][i]["thumbs"],
                    current_page: resp["meta"]["current_page"]),
              );
        }
        this.pageGetQuery += 1;
      },
    );
    notifyListeners();
  }

  void getWallsbyTag(String tagname) async {
    http
        .get(
            "https://wallhaven.cc/api/v1/search?q=$tagname&page=${this.pageGetTag}")
        .then(
      (http.Response response) {
        var resp = json.decode(response.body);
        for (int i = 0; i < resp.length; i++) {
          this.walls.add(
                WallPaper(
                    id: resp["data"][i]["id"],
                    url: resp["data"][i]["url"],
                    short_url: resp["data"][i]["short_url"],
                    views: resp["data"][i]["views"],
                    favorites: resp["data"][i]["favorites"],
                    category: resp["data"][i]["category"],
                    dimension_x: resp["data"][i]["dimension_x"],
                    dimension_y: resp["data"][i]["dimension_y"],
                    resolution: resp["data"][i]["id"],
                    file_size: resp["data"][i]["file_size"],
                    colors: resp["data"][i]["colors"],
                    path: resp["data"][i]["path"],
                    thumbs: resp["data"][i]["thumbs"],
                    current_page: resp["meta"]["current_page"]),
              );
        }
        this.pageGetTag += 1;
      },
    );
    notifyListeners();
  }
}
