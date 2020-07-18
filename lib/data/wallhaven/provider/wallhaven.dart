import 'dart:convert';

import 'package:Prism/data/wallhaven/model/tag.dart';
import 'package:Prism/data/wallhaven/model/wallpaper.dart';
import 'package:Prism/routes/router.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WallHavenProvider extends ChangeNotifier {
  List<WallPaper> walls = [];
  List<WallPaper> wallsS = [];
  WallPaper wall;
  int pageGetData = 1;
  int pageGetQuery = 1;
  int pageGetTag = 1;
  int pageGetPeople = 1;
  int pageLandscape = 1;
  int page4K = 1;
  int pagePattern = 1;
  int pageAnime = 1;
  int pageTechnology = 1;
  int pageCode = 1;
  int pageCars = 1;
  int pageSkyscape = 1;
  int pageArchitecture = 1;
  int pageMarvel = 1;
  Future<List<WallPaper>> getData() async {
    if (navStack.last == "Home") {
      http
          .get(
              "https://wallhaven.cc/api/v1/search?page=${this.pageGetData}&categories=100&purity=100&ratios=9x16&sorting=random&order=des")
          .then(
        (http.Response response) {
          var resp = json.decode(response.body);
          for (int i = 0; i < resp["data"].length; i++) {
            this.walls.add(
                  WallPaper(
                      id: resp["data"][i]["id"],
                      url: resp["data"][i]["url"],
                      short_url: resp["data"][i]["short_url"],
                      views: resp["data"][i]["views"].toString(),
                      favourites: resp["data"][i]["favorites"].toString(),
                      category: resp["data"][i]["category"],
                      dimension_x: resp["data"][i]["dimension_x"].toString(),
                      dimension_y: resp["data"][i]["dimension_y"].toString(),
                      resolution: resp["data"][i]["resolution"],
                      file_size: resp["data"][i]["file_size"].toString(),
                      colors: resp["data"][i]["colors"],
                      path: resp["data"][i]["path"],
                      thumbs: resp["data"][i]["thumbs"],
                      current_page: resp["meta"]["current_page"]),
                );
          }
          this.pageGetData = resp["meta"]["current_page"] + 1;
          print("data done");
          return this.walls;
        },
      ).catchError((e) {
        print("data done with error");
        return this.walls;
      });
    } else {
      print("Refresh Blocked");
    }
  }

  Future<WallPaper> getWallbyID(String id) async {
    print("https://wallhaven.cc/api/v1/w/$id");
    this.wall = null;
    http.get("https://wallhaven.cc/api/v1/w/$id").then(
      (http.Response response) {
        var resp = json.decode(response.body)["data"];
        this.wall = WallPaper(
          id: resp["id"].toString(),
          url: resp["url"],
          short_url: resp["short_url"],
          views: resp["views"].toString(),
          favourites: resp["favorites"].toString(),
          category: resp["category"],
          dimension_x: resp["dimension_x"].toString(),
          dimension_y: resp["dimension_y"].toString(),
          resolution: resp["resolution"],
          file_size: resp["file_size"].toString(),
          colors: resp["colors"],
          path: resp["path"],
          thumbs: resp["thumbs"],
          tags: new List<Tag>.generate(
            resp["tags"].length,
            (tag) => Tag(
              id: resp["tags"][tag]["id"].toString(),
              name: resp["tags"][tag]["name"],
              alias: resp["tags"][tag]["alias"],
              category_id: resp["tags"][tag]["category_id"].toString(),
              category: resp["tags"][tag]["category"],
            ),
          ),
        );
        print("id data done");
        notifyListeners();
        return this.wall;
      },
    );
  }

  Future<List<WallPaper>> getWallsbyQuery(String query) async {
    print("https://wallhaven.cc/api/v1/search?q=$query&page=1");
    http.get("https://wallhaven.cc/api/v1/search?q=$query&page=1").then(
      (http.Response response) {
        var resp = json.decode(response.body);
        print(resp["data"].length);
        print(wallsS.length);
        for (int i = 0; i < resp["data"].length; i++) {
          this.wallsS.add(
                WallPaper(
                    id: resp["data"][i]["id"],
                    url: resp["data"][i]["url"],
                    short_url: resp["data"][i]["short_url"],
                    views: resp["data"][i]["views"].toString(),
                    favourites: resp["data"][i]["favorites"].toString(),
                    category: resp["data"][i]["category"],
                    dimension_x: resp["data"][i]["dimension_x"].toString(),
                    dimension_y: resp["data"][i]["dimension_y"].toString(),
                    resolution: resp["data"][i]["resolution"],
                    file_size: resp["data"][i]["file_size"].toString(),
                    colors: resp["data"][i]["colors"],
                    path: resp["data"][i]["path"],
                    thumbs: resp["data"][i]["thumbs"],
                    current_page: resp["meta"]["current_page"]),
              );
        }
        this.pageGetQuery = this.pageGetQuery + 1;
        return this.wallsS;
      },
    );
  }

  Future<List<WallPaper>> getWallsbyQueryPage(String query) async {
    print(
        "https://wallhaven.cc/api/v1/search?q=$query&page=${this.pageGetQuery}");
    http
        .get(
            "https://wallhaven.cc/api/v1/search?q=$query&page=${this.pageGetQuery}")
        .then(
      (http.Response response) {
        var resp = json.decode(response.body);
        for (int i = 0; i < resp["data"].length; i++) {
          this.wallsS.add(
                WallPaper(
                    id: resp["data"][i]["id"],
                    url: resp["data"][i]["url"],
                    short_url: resp["data"][i]["short_url"],
                    views: resp["data"][i]["views"].toString(),
                    favourites: resp["data"][i]["favorites"].toString(),
                    category: resp["data"][i]["category"],
                    dimension_x: resp["data"][i]["dimension_x"].toString(),
                    dimension_y: resp["data"][i]["dimension_y"].toString(),
                    resolution: resp["data"][i]["resolution"],
                    file_size: resp["data"][i]["file_size"].toString(),
                    colors: resp["data"][i]["colors"],
                    path: resp["data"][i]["path"],
                    thumbs: resp["data"][i]["thumbs"],
                    current_page: resp["meta"]["current_page"]),
              );
        }
        this.pageGetQuery = this.pageGetQuery + 1;
        notifyListeners();
        return this.wallsS;
      },
    );
  }

  // Future<List<WallPaper>> getWallsbyTag(String tagname) async {
  //   http
  //       .get(
  //           "https://wallhaven.cc/api/v1/search?q=$tagname&page=${this.pageGetTag}&categories=100&purity=100&sorting=random&order=des")
  //       .then(
  //     (http.Response response) {
  //       var resp = json.decode(response.body);
  //       for (int i = 0; i < resp["data"].length; i++) {
  //         this.walls.add(
  //               WallPaper(
  //                   id: resp["data"][i]["id"],
  //                   url: resp["data"][i]["url"],
  //                   short_url: resp["data"][i]["short_url"],
  //                   views: resp["data"][i]["views"],
  //                   favourites: resp["data"][i]["favorites"],
  //                   category: resp["data"][i]["category"],
  //                   dimension_x: resp["data"][i]["dimension_x"],
  //                   dimension_y: resp["data"][i]["dimension_y"],
  //                   resolution: resp["data"][i]["id"],
  //                   file_size: resp["data"][i]["file_size"],
  //                   colors: resp["data"][i]["colors"],
  //                   path: resp["data"][i]["path"],
  //                   thumbs: resp["data"][i]["thumbs"],
  //                   current_page: resp["meta"]["current_page"]),
  //             );
  //       }
  //       this.pageGetTag = resp["meta"]["current_page"] + 1;
  //     },
  //   ).whenComplete(() => notifyListeners());
  //   return this.walls;
  // }

  // Future<List<WallPaper>> getDataPeople() async {
  //   http
  //       .get(
  //           "https://wallhaven.cc/api/v1/search?page=${this.pageGetPeople}&categories=111&purity=100&ratios=9x16&sorting=random&order=des")
  //       .then(
  //     (http.Response response) {
  //       var resp = json.decode(response.body);
  //       for (int i = 0; i < resp["data"].length; i++) {
  //         this.walls.add(
  //               WallPaper(
  //                   id: resp["data"][i]["id"],
  //                   url: resp["data"][i]["url"],
  //                   short_url: resp["data"][i]["short_url"],
  //                   views: resp["data"][i]["views"],
  //                   favourites: resp["data"][i]["favorites"],
  //                   category: resp["data"][i]["category"],
  //                   dimension_x: resp["data"][i]["dimension_x"],
  //                   dimension_y: resp["data"][i]["dimension_y"],
  //                   resolution: resp["data"][i]["id"],
  //                   file_size: resp["data"][i]["file_size"],
  //                   colors: resp["data"][i]["colors"],
  //                   path: resp["data"][i]["path"],
  //                   thumbs: resp["data"][i]["thumbs"],
  //                   current_page: resp["meta"]["current_page"]),
  //             );
  //       }
  //       this.pageGetPeople = resp["meta"]["current_page"] + 1;
  //     },
  //   ).whenComplete(() => notifyListeners());
  //   return this.walls;
  // }

  Future<List<WallPaper>> getLandscapeWalls() async {
    if (navStack.last == "Home") {
      http
          .get(
              "https://wallhaven.cc/api/v1/search?q=Landscape&page=${this.pageLandscape}")
          .then(
        (http.Response response) {
          var resp = json.decode(response.body);
          print(resp);
          for (int i = 0; i < resp["data"].length; i++) {
            this.walls.add(
                  WallPaper(
                      id: resp["data"][i]["id"],
                      url: resp["data"][i]["url"],
                      short_url: resp["data"][i]["short_url"],
                      views: resp["data"][i]["views"].toString(),
                      favourites: resp["data"][i]["favorites"].toString(),
                      category: resp["data"][i]["category"],
                      dimension_x: resp["data"][i]["dimension_x"].toString(),
                      dimension_y: resp["data"][i]["dimension_y"].toString(),
                      resolution: resp["data"][i]["resolution"],
                      file_size: resp["data"][i]["file_size"].toString(),
                      colors: resp["data"][i]["colors"],
                      path: resp["data"][i]["path"],
                      thumbs: resp["data"][i]["thumbs"],
                      current_page: resp["meta"]["current_page"]),
                );
          }
          this.pageLandscape = resp["meta"]["current_page"] + 1;
          print("data done");
          return this.walls;
        },
      );
    } else {
      print("Refresh Blocked");
    }
  }

  Future<List<WallPaper>> get4KWalls() async {
    if (navStack.last == "Home") {
      http
          .get("https://wallhaven.cc/api/v1/search?q=4K&page=${this.page4K}")
          .then(
        (http.Response response) {
          var resp = json.decode(response.body);
          print(resp);
          for (int i = 0; i < resp["data"].length; i++) {
            this.walls.add(
                  WallPaper(
                      id: resp["data"][i]["id"],
                      url: resp["data"][i]["url"],
                      short_url: resp["data"][i]["short_url"],
                      views: resp["data"][i]["views"].toString(),
                      favourites: resp["data"][i]["favorites"].toString(),
                      category: resp["data"][i]["category"],
                      dimension_x: resp["data"][i]["dimension_x"].toString(),
                      dimension_y: resp["data"][i]["dimension_y"].toString(),
                      resolution: resp["data"][i]["resolution"],
                      file_size: resp["data"][i]["file_size"].toString(),
                      colors: resp["data"][i]["colors"],
                      path: resp["data"][i]["path"],
                      thumbs: resp["data"][i]["thumbs"],
                      current_page: resp["meta"]["current_page"]),
                );
          }
          this.page4K = resp["meta"]["current_page"] + 1;
          print("data done");
          return this.walls;
        },
      );
    } else {
      print("Refresh Blocked");
    }
  }

  Future<List<WallPaper>> getPatternWalls() async {
    if (navStack.last == "Home") {
      http
          .get(
              "https://wallhaven.cc/api/v1/search?q=Pattern&page=${this.pagePattern}")
          .then(
        (http.Response response) {
          var resp = json.decode(response.body);
          print(resp);
          for (int i = 0; i < resp["data"].length; i++) {
            this.walls.add(
                  WallPaper(
                      id: resp["data"][i]["id"],
                      url: resp["data"][i]["url"],
                      short_url: resp["data"][i]["short_url"],
                      views: resp["data"][i]["views"].toString(),
                      favourites: resp["data"][i]["favorites"].toString(),
                      category: resp["data"][i]["category"],
                      dimension_x: resp["data"][i]["dimension_x"].toString(),
                      dimension_y: resp["data"][i]["dimension_y"].toString(),
                      resolution: resp["data"][i]["resolution"],
                      file_size: resp["data"][i]["file_size"].toString(),
                      colors: resp["data"][i]["colors"],
                      path: resp["data"][i]["path"],
                      thumbs: resp["data"][i]["thumbs"],
                      current_page: resp["meta"]["current_page"]),
                );
          }
          this.pagePattern = resp["meta"]["current_page"] + 1;
          print("data done");
          return this.walls;
        },
      );
    } else {
      print("Refresh Blocked");
    }
  }

  Future<List<WallPaper>> getAnimeWalls() async {
    if (navStack.last == "Home") {
      http
          .get(
              "https://wallhaven.cc/api/v1/search?q=Anime&page=${this.pageAnime}")
          .then(
        (http.Response response) {
          var resp = json.decode(response.body);
          print(resp);
          for (int i = 0; i < resp["data"].length; i++) {
            this.walls.add(
                  WallPaper(
                      id: resp["data"][i]["id"],
                      url: resp["data"][i]["url"],
                      short_url: resp["data"][i]["short_url"],
                      views: resp["data"][i]["views"].toString(),
                      favourites: resp["data"][i]["favorites"].toString(),
                      category: resp["data"][i]["category"],
                      dimension_x: resp["data"][i]["dimension_x"].toString(),
                      dimension_y: resp["data"][i]["dimension_y"].toString(),
                      resolution: resp["data"][i]["resolution"],
                      file_size: resp["data"][i]["file_size"].toString(),
                      colors: resp["data"][i]["colors"],
                      path: resp["data"][i]["path"],
                      thumbs: resp["data"][i]["thumbs"],
                      current_page: resp["meta"]["current_page"]),
                );
          }
          this.pageAnime = resp["meta"]["current_page"] + 1;
          print("data done");
          return this.walls;
        },
      );
    } else {
      print("Refresh Blocked");
    }
  }

  Future<List<WallPaper>> getTechnologyWalls() async {
    if (navStack.last == "Home") {
      http
          .get(
              "https://wallhaven.cc/api/v1/search?q=Technology&page=${this.pageTechnology}")
          .then(
        (http.Response response) {
          var resp = json.decode(response.body);
          print(resp);
          for (int i = 0; i < resp["data"].length; i++) {
            this.walls.add(
                  WallPaper(
                      id: resp["data"][i]["id"],
                      url: resp["data"][i]["url"],
                      short_url: resp["data"][i]["short_url"],
                      views: resp["data"][i]["views"].toString(),
                      favourites: resp["data"][i]["favorites"].toString(),
                      category: resp["data"][i]["category"],
                      dimension_x: resp["data"][i]["dimension_x"].toString(),
                      dimension_y: resp["data"][i]["dimension_y"].toString(),
                      resolution: resp["data"][i]["resolution"],
                      file_size: resp["data"][i]["file_size"].toString(),
                      colors: resp["data"][i]["colors"],
                      path: resp["data"][i]["path"],
                      thumbs: resp["data"][i]["thumbs"],
                      current_page: resp["meta"]["current_page"]),
                );
          }
          this.pageTechnology = resp["meta"]["current_page"] + 1;
          print("data done");
          return this.walls;
        },
      );
    } else {
      print("Refresh Blocked");
    }
  }

  Future<List<WallPaper>> getCodeWalls() async {
    if (navStack.last == "Home") {
      http
          .get(
              "https://wallhaven.cc/api/v1/search?q=Code&page=${this.pageCode}")
          .then(
        (http.Response response) {
          var resp = json.decode(response.body);
          print(resp);
          for (int i = 0; i < resp["data"].length; i++) {
            this.walls.add(
                  WallPaper(
                      id: resp["data"][i]["id"],
                      url: resp["data"][i]["url"],
                      short_url: resp["data"][i]["short_url"],
                      views: resp["data"][i]["views"].toString(),
                      favourites: resp["data"][i]["favorites"].toString(),
                      category: resp["data"][i]["category"],
                      dimension_x: resp["data"][i]["dimension_x"].toString(),
                      dimension_y: resp["data"][i]["dimension_y"].toString(),
                      resolution: resp["data"][i]["resolution"],
                      file_size: resp["data"][i]["file_size"].toString(),
                      colors: resp["data"][i]["colors"],
                      path: resp["data"][i]["path"],
                      thumbs: resp["data"][i]["thumbs"],
                      current_page: resp["meta"]["current_page"]),
                );
          }
          this.pageCode = resp["meta"]["current_page"] + 1;
          print("data done");
          return this.walls;
        },
      );
    } else {
      print("Refresh Blocked");
    }
  }

  Future<List<WallPaper>> getCarsWalls() async {
    if (navStack.last == "Home") {
      http
          .get(
              "https://wallhaven.cc/api/v1/search?q=Cars&page=${this.pageCars}")
          .then(
        (http.Response response) {
          var resp = json.decode(response.body);
          print(resp);
          for (int i = 0; i < resp["data"].length; i++) {
            this.walls.add(
                  WallPaper(
                      id: resp["data"][i]["id"],
                      url: resp["data"][i]["url"],
                      short_url: resp["data"][i]["short_url"],
                      views: resp["data"][i]["views"].toString(),
                      favourites: resp["data"][i]["favorites"].toString(),
                      category: resp["data"][i]["category"],
                      dimension_x: resp["data"][i]["dimension_x"].toString(),
                      dimension_y: resp["data"][i]["dimension_y"].toString(),
                      resolution: resp["data"][i]["resolution"],
                      file_size: resp["data"][i]["file_size"].toString(),
                      colors: resp["data"][i]["colors"],
                      path: resp["data"][i]["path"],
                      thumbs: resp["data"][i]["thumbs"],
                      current_page: resp["meta"]["current_page"]),
                );
          }
          this.pageCars = resp["meta"]["current_page"] + 1;
          print("data done");
          return this.walls;
        },
      );
    } else {
      print("Refresh Blocked");
    }
  }

  Future<List<WallPaper>> getSkyscapeWalls() async {
    if (navStack.last == "Home") {
      http
          .get(
              "https://wallhaven.cc/api/v1/search?q=Skyscape&page=${this.pageSkyscape}")
          .then(
        (http.Response response) {
          var resp = json.decode(response.body);
          print(resp);
          for (int i = 0; i < resp["data"].length; i++) {
            this.walls.add(
                  WallPaper(
                      id: resp["data"][i]["id"],
                      url: resp["data"][i]["url"],
                      short_url: resp["data"][i]["short_url"],
                      views: resp["data"][i]["views"].toString(),
                      favourites: resp["data"][i]["favorites"].toString(),
                      category: resp["data"][i]["category"],
                      dimension_x: resp["data"][i]["dimension_x"].toString(),
                      dimension_y: resp["data"][i]["dimension_y"].toString(),
                      resolution: resp["data"][i]["resolution"],
                      file_size: resp["data"][i]["file_size"].toString(),
                      colors: resp["data"][i]["colors"],
                      path: resp["data"][i]["path"],
                      thumbs: resp["data"][i]["thumbs"],
                      current_page: resp["meta"]["current_page"]),
                );
          }
          this.pageSkyscape = resp["meta"]["current_page"] + 1;
          print("data done");
          return this.walls;
        },
      );
    } else {
      print("Refresh Blocked");
    }
  }

  Future<List<WallPaper>> getArchitectureWalls() async {
    if (navStack.last == "Home") {
      http
          .get(
              "https://wallhaven.cc/api/v1/search?q=Architecture&page=${this.pageArchitecture}")
          .then(
        (http.Response response) {
          var resp = json.decode(response.body);
          print(resp);
          for (int i = 0; i < resp["data"].length; i++) {
            this.walls.add(
                  WallPaper(
                      id: resp["data"][i]["id"],
                      url: resp["data"][i]["url"],
                      short_url: resp["data"][i]["short_url"],
                      views: resp["data"][i]["views"].toString(),
                      favourites: resp["data"][i]["favorites"].toString(),
                      category: resp["data"][i]["category"],
                      dimension_x: resp["data"][i]["dimension_x"].toString(),
                      dimension_y: resp["data"][i]["dimension_y"].toString(),
                      resolution: resp["data"][i]["resolution"],
                      file_size: resp["data"][i]["file_size"].toString(),
                      colors: resp["data"][i]["colors"],
                      path: resp["data"][i]["path"],
                      thumbs: resp["data"][i]["thumbs"],
                      current_page: resp["meta"]["current_page"]),
                );
          }
          this.pageArchitecture = resp["meta"]["current_page"] + 1;
          print("data done");
          return this.walls;
        },
      );
    } else {
      print("Refresh Blocked");
    }
  }

  Future<List<WallPaper>> getMarvelWalls() async {
    if (navStack.last == "Home") {
      http
          .get(
              "https://wallhaven.cc/api/v1/search?q=Marvel&page=${this.pageMarvel}")
          .then(
        (http.Response response) {
          var resp = json.decode(response.body);
          print(resp);
          for (int i = 0; i < resp["data"].length; i++) {
            this.walls.add(
                  WallPaper(
                      id: resp["data"][i]["id"],
                      url: resp["data"][i]["url"],
                      short_url: resp["data"][i]["short_url"],
                      views: resp["data"][i]["views"].toString(),
                      favourites: resp["data"][i]["favorites"].toString(),
                      category: resp["data"][i]["category"],
                      dimension_x: resp["data"][i]["dimension_x"].toString(),
                      dimension_y: resp["data"][i]["dimension_y"].toString(),
                      resolution: resp["data"][i]["resolution"],
                      file_size: resp["data"][i]["file_size"].toString(),
                      colors: resp["data"][i]["colors"],
                      path: resp["data"][i]["path"],
                      thumbs: resp["data"][i]["thumbs"],
                      current_page: resp["meta"]["current_page"]),
                );
          }
          this.pageMarvel = resp["meta"]["current_page"] + 1;
          print("data done");
          return this.walls;
        },
      );
    } else {
      print("Refresh Blocked");
    }
  }
}
