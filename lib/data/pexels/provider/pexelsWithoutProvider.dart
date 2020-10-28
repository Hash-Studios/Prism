import 'dart:convert';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/data/pexels/model/wallpaperp.dart';
import 'package:Prism/gitkey.dart';
import 'package:Prism/routes/router.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

List<WallPaperP> wallsP = [];
List<WallPaperP> wallsPS = [];
List<WallPaperP> wallsC = [];
WallPaperP wall;
int pageGetDataP = 1;
int pageGetQueryP = 1;
List<Map<String, int>> pageNumbersP = categories
    .where((category) =>
        category['provider'] == "Pexels" && category['type'] == 'search')
    .map((category) => {category['name'].toString(): 1})
    .toList();

Future<List<WallPaperP>> categoryDataFetcherP(
    String categoryName, String mode) async {
  final int index = pageNumbersP.indexOf(pageNumbersP
      .firstWhere((element) => element.keys.toList()[0] == categoryName));
  if (mode == "r") {
    wallsP = [];
    pageNumbersP[index] = {categoryName: 1};
  } else {
    final int origPageNumber = pageNumbersP[index][categoryName];
    pageNumbersP[index] = {categoryName: origPageNumber + 1};
  }
  if (navStack.last == "Home") {
    debugPrint(
        "https://api.pexels.com/v1/search?query=$categoryName&per_page=80&page=${pageNumbersP[index][categoryName]}");
    http.get(
        "https://api.pexels.com/v1/search?query=$categoryName&per_page=80&page=${pageNumbersP[index][categoryName]}",
        headers: {"Authorization": pexelApiKey}).then(
      (http.Response response) {
        final resp = json.decode(response.body);
        for (int i = 0; i < (resp["photos"].length as int); i++) {
          wallsP.add(
            WallPaperP(
                id: resp["photos"][i]["id"].toString(),
                url: resp["photos"][i]["url"].toString(),
                width: resp["photos"][i]["width"].toString(),
                height: resp["photos"][i]["height"].toString(),
                photographer: resp["photos"][i]["photographer"].toString(),
                src: resp["photos"][i]["src"] as Map,
                currentPage: resp["page"] as int),
          );
        }
        pageNumbersP[index][categoryName] = (resp["page"] as int) + 1;
        debugPrint("data done");
        return wallsP;
      },
    );
  } else {
    debugPrint("Refresh Blocked");
  }
}

int pageColorsP = 1;
Future<List<WallPaperP>> getDataP(String mode) async {
  if (mode == "r") {
    wallsP = [];
    pageGetDataP = 1;
  } else {
    pageGetDataP = pageGetDataP + 1;
  }
  if (navStack.last == "Home") {
    http.get("https://api.pexels.com/v1/curated?per_page=24&page=$pageGetDataP",
        headers: {"Authorization": pexelApiKey}).then(
      (http.Response response) {
        final resp = json.decode(response.body);
        for (int i = 0; i < (resp["photos"].length as int); i++) {
          wallsP.add(
            WallPaperP(
                id: resp["photos"][i]["id"].toString(),
                url: resp["photos"][i]["url"].toString(),
                width: resp["photos"][i]["width"].toString(),
                height: resp["photos"][i]["height"].toString(),
                photographer: resp["photos"][i]["photographer"].toString(),
                src: resp["photos"][i]["src"] as Map,
                currentPage: resp["page"] as int),
          );
        }
        pageGetDataP = (resp["page"] as int) + 1;
        debugPrint("data done");
        return wallsP;
      },
    );
  } else {
    debugPrint("Refresh Blocked");
  }
}

Future<WallPaperP> getWallbyIDP(String id) async {
  debugPrint("https://api.pexels.com/v1/photos/$id");
  wall = null;
  http.get("https://api.pexels.com/v1/photos/$id",
      headers: {"Authorization": pexelApiKey}).then(
    (http.Response response) {
      final resp = json.decode(response.body);
      return wall = WallPaperP(
          id: resp["id"].toString(),
          url: resp["url"].toString(),
          width: resp["width"].toString(),
          height: resp["height"].toString(),
          photographer: resp["photographer"].toString(),
          src: resp["category"] as Map);
    },
  );
}

Future<List<WallPaperP>> getWallsPbyQuery(String query) async {
  http.get("https://api.pexels.com/v1/search?query=$query&per_page=80&page=1",
      headers: {"Authorization": pexelApiKey}).then(
    (http.Response response) {
      final resp = json.decode(response.body);
      for (int i = 0; i < (resp["photos"].length as int); i++) {
        wallsPS.add(
          WallPaperP(
              id: resp["photos"][i]["id"].toString(),
              url: resp["photos"][i]["url"].toString(),
              width: resp["photos"][i]["width"].toString(),
              height: resp["photos"][i]["height"].toString(),
              photographer: resp["photos"][i]["photographer"].toString(),
              src: resp["photos"][i]["src"] as Map,
              currentPage: resp["page"] as int),
        );
      }
      pageGetQueryP = (resp["page"] as int) + 1;
      debugPrint("data done");
      return wallsPS;
    },
  );
}

Future<List<WallPaperP>> getWallsPbyQueryPage(String query) async {
  http.get(
      "https://api.pexels.com/v1/search?query=$query&per_page=80&page=$pageGetQueryP",
      headers: {"Authorization": pexelApiKey}).then(
    (http.Response response) {
      final resp = json.decode(response.body);
      for (int i = 0; i < (resp["photos"].length as int); i++) {
        wallsPS.add(
          WallPaperP(
              id: resp["photos"][i]["id"].toString(),
              url: resp["photos"][i]["url"].toString(),
              width: resp["photos"][i]["width"].toString(),
              height: resp["photos"][i]["height"].toString(),
              photographer: resp["photos"][i]["photographer"].toString(),
              src: resp["photos"][i]["src"] as Map,
              currentPage: resp["page"] as int),
        );
      }
      pageGetQueryP = (resp["page"] as int) + 1;
      debugPrint("data done");
      return wallsPS;
    },
  );
}

Future<List<WallPaperP>> getWallsPbyColor(String query) async {
  debugPrint(
      "https://api.pexels.com/v1/search?query=$query&per_page=24&page=1");
  http.get("https://api.pexels.com/v1/search?query=$query&per_page=24&page=1",
      headers: {"Authorization": pexelApiKey}).then(
    (http.Response response) {
      final resp = json.decode(response.body);
      for (int i = 0; i < (resp["photos"].length as int); i++) {
        wallsC.add(
          WallPaperP(
              id: resp["photos"][i]["id"].toString(),
              url: resp["photos"][i]["url"].toString(),
              width: resp["photos"][i]["width"].toString(),
              height: resp["photos"][i]["height"].toString(),
              photographer: resp["photos"][i]["photographer"].toString(),
              src: resp["photos"][i]["src"] as Map,
              currentPage: resp["page"] as int),
        );
      }
      pageColorsP = (resp["page"] as int) + 1;
      debugPrint("data done");
      return wallsC;
    },
  );
}

Future<List<WallPaperP>> getWallsPbyColorPage(String query) async {
  debugPrint(
      "https://api.pexels.com/v1/search?query=$query&per_page=24&page=$pageColorsP");
  http.get(
      "https://api.pexels.com/v1/search?query=$query&per_page=24&page=$pageColorsP",
      headers: {"Authorization": pexelApiKey}).then(
    (http.Response response) {
      final resp = json.decode(response.body);
      for (int i = 0; i < (resp["photos"].length as int); i++) {
        wallsC.add(
          WallPaperP(
              id: resp["photos"][i]["id"].toString(),
              url: resp["photos"][i]["url"].toString(),
              width: resp["photos"][i]["width"].toString(),
              height: resp["photos"][i]["height"].toString(),
              photographer: resp["photos"][i]["photographer"].toString(),
              src: resp["photos"][i]["src"] as Map,
              currentPage: resp["page"] as int),
        );
      }
      pageColorsP = (resp["page"] as int) + 1;
      debugPrint("data done");
      return wallsC;
    },
  );
}
