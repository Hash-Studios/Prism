import 'dart:convert';

import 'package:Prism/data/pexels/model/wallpaperp.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PexelsProvider extends ChangeNotifier {
  List<WallPaperP> wallsP = [];
  List<WallPaperP> wallsC = [];
  WallPaperP wall;
  int pageGetDataP = 1;
  int pageGetQueryP = 1;
  int pageAbstractP = 1;
  int pageNatureP = 1;
  int pageArtP = 1;
  int pageMinimalP = 1;
  int pageTexturesP = 1;
  int pageMonochromeP = 1;
  int pageSpaceP = 1;
  int pageAnimalsP = 1;
  int pageNeonP = 1;
  int pageSportsP = 1;
  int pageMusicP = 1;
  int pageColorsP = 1;
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
    print("https://api.pexels.com/v1/photos/$id");
    this.wall = null;
    http.get("https://api.pexels.com/v1/photos/$id", headers: {
      "Authorization":
          "563492ad6f9170000100000107272bb5cab346b68e27263fbf1b6a72"
    }).then(
      (http.Response response) {
        var resp = json.decode(response.body);
        this.wall = WallPaperP(
            id: resp["id"].toString(),
            url: resp["url"].toString(),
            width: resp["width"].toString(),
            height: resp["height"].toString(),
            photographer: resp["photographer"].toString(),
            src: resp["category"]);
        notifyListeners();
        return this.wall;
      },
    );
  }

  // Future<List<WallPaperP>> getWallsPbyQuery(String query) async {
  //   http.get(
  //       "https://api.pexels.com/v1/search?query=$query&per_page=80&page=${this.pageGetQueryP}",
  //       headers: {
  //         "Authorization":
  //             "563492ad6f9170000100000107272bb5cab346b68e27263fbf1b6a72"
  //       }).then(
  //     (http.Response response) {
  //       var resp = json.decode(response.body);
  //       for (int i = 0; i < resp["photos"].length; i++) {
  //         this.wallsP.add(
  //               WallPaperP(
  //                   id: resp["photos"][i]["id"].toString(),
  //                   url: resp["photos"][i]["url"],
  //                   width: resp["photos"][i]["width"].toString(),
  //                   height: resp["photos"][i]["height"].toString(),
  //                   photographer: resp["photos"][i]["photographer"],
  //                   src: resp["photos"][i]["src"],
  //                   current_page: resp["page"]),
  //             );
  //       }
  //       this.pageGetQueryP = resp["page"] + 1;
  //       print("data done");
  //       return this.wallsP;
  //     },
  //   );
  // }

  Future<List<WallPaperP>> getWallsPbyColor(String query) async {
    print("https://api.pexels.com/v1/search?query=$query&per_page=24&page=1");
    http.get("https://api.pexels.com/v1/search?query=$query&per_page=24&page=1",
        headers: {
          "Authorization":
              "563492ad6f9170000100000107272bb5cab346b68e27263fbf1b6a72"
        }).then(
      (http.Response response) {
        var resp = json.decode(response.body);
        for (int i = 0; i < resp["photos"].length; i++) {
          this.wallsC.add(
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
        this.pageColorsP = resp["page"] + 1;
        print("data done");
        return this.wallsC;
      },
    );
  }

  Future<List<WallPaperP>> getWallsPbyColorPage(String query) async {
    print(
        "https://api.pexels.com/v1/search?query=$query&per_page=24&page=${this.pageColorsP}");
    http.get(
        "https://api.pexels.com/v1/search?query=$query&per_page=24&page=${this.pageColorsP}",
        headers: {
          "Authorization":
              "563492ad6f9170000100000107272bb5cab346b68e27263fbf1b6a72"
        }).then(
      (http.Response response) {
        var resp = json.decode(response.body);
        for (int i = 0; i < resp["photos"].length; i++) {
          this.wallsC.add(
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
        this.pageColorsP = resp["page"] + 1;
        print("data done");
        return this.wallsC;
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
        print(resp);
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

  Future<List<WallPaperP>> getArtWalls() async {
    http.get(
        "https://api.pexels.com/v1/search?query=art&per_page=80&page=${this.pageArtP}",
        headers: {
          "Authorization":
              "563492ad6f9170000100000107272bb5cab346b68e27263fbf1b6a72"
        }).then(
      (http.Response response) {
        var resp = json.decode(response.body);
        print(resp);
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
        this.pageArtP = resp["page"] + 1;
        print("data done");
        return this.wallsP;
      },
    );
  }

  Future<List<WallPaperP>> getMinimalWalls() async {
    http.get(
        "https://api.pexels.com/v1/search?query=Minimal&per_page=80&page=${this.pageMinimalP}",
        headers: {
          "Authorization":
              "563492ad6f9170000100000107272bb5cab346b68e27263fbf1b6a72"
        }).then(
      (http.Response response) {
        var resp = json.decode(response.body);
        print(resp);
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
        this.pageMinimalP = resp["page"] + 1;
        print("data done");
        return this.wallsP;
      },
    );
  }

  Future<List<WallPaperP>> getTexturesWalls() async {
    http.get(
        "https://api.pexels.com/v1/search?query=Textures&per_page=80&page=${this.pageTexturesP}",
        headers: {
          "Authorization":
              "563492ad6f9170000100000107272bb5cab346b68e27263fbf1b6a72"
        }).then(
      (http.Response response) {
        var resp = json.decode(response.body);
        print(resp);
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
        this.pageTexturesP = resp["page"] + 1;
        print("data done");
        return this.wallsP;
      },
    );
  }

  Future<List<WallPaperP>> getMonochromeWalls() async {
    http.get(
        "https://api.pexels.com/v1/search?query=Monochrome&per_page=80&page=${this.pageMonochromeP}",
        headers: {
          "Authorization":
              "563492ad6f9170000100000107272bb5cab346b68e27263fbf1b6a72"
        }).then(
      (http.Response response) {
        var resp = json.decode(response.body);
        print(resp);
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
        this.pageMonochromeP = resp["page"] + 1;
        print("data done");
        return this.wallsP;
      },
    );
  }

  Future<List<WallPaperP>> getSpaceWalls() async {
    http.get(
        "https://api.pexels.com/v1/search?query=Space&per_page=80&page=${this.pageSpaceP}",
        headers: {
          "Authorization":
              "563492ad6f9170000100000107272bb5cab346b68e27263fbf1b6a72"
        }).then(
      (http.Response response) {
        var resp = json.decode(response.body);
        print(resp);
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
        this.pageSpaceP = resp["page"] + 1;
        print("data done");
        return this.wallsP;
      },
    );
  }

  Future<List<WallPaperP>> getAnimalsWalls() async {
    http.get(
        "https://api.pexels.com/v1/search?query=Animals&per_page=80&page=${this.pageAnimalsP}",
        headers: {
          "Authorization":
              "563492ad6f9170000100000107272bb5cab346b68e27263fbf1b6a72"
        }).then(
      (http.Response response) {
        var resp = json.decode(response.body);
        print(resp);
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
        this.pageAnimalsP = resp["page"] + 1;
        print("data done");
        return this.wallsP;
      },
    );
  }

  Future<List<WallPaperP>> getNeonWalls() async {
    http.get(
        "https://api.pexels.com/v1/search?query=Neon&per_page=80&page=${this.pageNeonP}",
        headers: {
          "Authorization":
              "563492ad6f9170000100000107272bb5cab346b68e27263fbf1b6a72"
        }).then(
      (http.Response response) {
        var resp = json.decode(response.body);
        print(resp);
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
        this.pageNeonP = resp["page"] + 1;
        print("data done");
        return this.wallsP;
      },
    );
  }

  Future<List<WallPaperP>> getSportsWalls() async {
    http.get(
        "https://api.pexels.com/v1/search?query=Sports&per_page=80&page=${this.pageSportsP}",
        headers: {
          "Authorization":
              "563492ad6f9170000100000107272bb5cab346b68e27263fbf1b6a72"
        }).then(
      (http.Response response) {
        var resp = json.decode(response.body);
        print(resp);
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
        this.pageSportsP = resp["page"] + 1;
        print("data done");
        return this.wallsP;
      },
    );
  }

  Future<List<WallPaperP>> getMusicWalls() async {
    http.get(
        "https://api.pexels.com/v1/search?query=Music&per_page=80&page=${this.pageMusicP}",
        headers: {
          "Authorization":
              "563492ad6f9170000100000107272bb5cab346b68e27263fbf1b6a72"
        }).then(
      (http.Response response) {
        var resp = json.decode(response.body);
        print(resp);
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
        this.pageMusicP = resp["page"] + 1;
        print("data done");
        return this.wallsP;
      },
    );
  }
}
