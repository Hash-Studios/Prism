import 'dart:convert';

import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/data/wallhaven/model/tag.dart';
import 'package:Prism/data/wallhaven/model/wallpaper.dart';
import 'package:Prism/routes/router.dart';
import 'package:http/http.dart' as http;

List<WallPaper> walls = [];
List<WallPaper> wallsS = [];
WallPaper wall;
int pageGetData = 1;
int pageGetQuery = 1;
int pageGetTag = 1;
int pageGetPeople = 1;
List<Map<String, int>> pageNumbers = categories
    .where((category) =>
        category['provider'] == "WallHaven" && category['type'] == 'search')
    .map((category) => {category['name'].toString(): 1})
    .toList();

Future<List<WallPaper>> categoryDataFetcher(
    String categoryName, String mode) async {
  int index = pageNumbers.indexOf(pageNumbers
      .firstWhere((element) => element.keys.toList()[0] == categoryName));
  if (mode == "r") {
    walls = [];
    pageNumbers[index] = {categoryName: 1};
  } else {
    int origPageNumber = pageNumbers[index][categoryName];
    pageNumbers[index] = {categoryName: origPageNumber + 1};
  }
  if (navStack.last == "Home") {
    http
        .get(
            "https://wallhaven.cc/api/v1/search?q=${categoryName}&page=${pageNumbers[index][categoryName]}")
        .then(
      (http.Response response) {
        var resp = json.decode(response.body);
        print(resp);
        for (int i = 0; i < resp["data"].length; i++) {
          walls.add(
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
        pageNumbers[index][categoryName] = resp["meta"]["current_page"] + 1;
        print("data done");
        return walls;
      },
    );
  } else {
    print("Refresh Blocked");
  }
}

Future<List<WallPaper>> getData(String mode) async {
  if (mode == "r") {
    walls = [];
    pageGetData = 1;
  } else {
    pageGetData = pageGetData + 1;
  }
  if (navStack.last == "Home") {
    http
        .get(
            "https://wallhaven.cc/api/v1/search?page=${pageGetData}&categories=100&purity=100&sorting=toplist&order=des")
        .then(
      (http.Response response) {
        var resp = json.decode(response.body);
        for (int i = 0; i < resp["data"].length; i++) {
          walls.add(
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
        pageGetData = resp["meta"]["current_page"] + 1;
        print("data done");
        return walls;
      },
    ).catchError((e) {
      print("data done with error");
      return walls;
    });
  } else {
    print("Refresh Blocked");
  }
}

Future<WallPaper> getWallbyID(String id) async {
  print("https://wallhaven.cc/api/v1/w/$id");
  wall = null;
  http.get("https://wallhaven.cc/api/v1/w/$id").then(
    (http.Response response) {
      var resp = json.decode(response.body)["data"];
      wall = WallPaper(
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
      return wall;
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
        wallsS.add(
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
      pageGetQuery = 2;
      return wallsS;
    },
  );
}

Future<List<WallPaper>> getWallsbyQueryPage(String query) async {
  print("https://wallhaven.cc/api/v1/search?q=$query&page=${pageGetQuery}");
  http
      .get("https://wallhaven.cc/api/v1/search?q=$query&page=${pageGetQuery}")
      .then(
    (http.Response response) {
      var resp = json.decode(response.body);
      for (int i = 0; i < resp["data"].length; i++) {
        wallsS.add(
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
      pageGetQuery = pageGetQuery + 1;
      return wallsS;
    },
  );
}
