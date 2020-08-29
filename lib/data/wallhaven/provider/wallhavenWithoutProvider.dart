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

// int pageLandscape = 1;
// int page4K = 1;
// int pagePattern = 1;
// int pageAnime = 1;
// int pageTechnology = 1;
// int pageCode = 1;
// int pageCars = 1;
// int pageSkyscape = 1;
// int pageArchitecture = 1;
// int pageMarvel = 1;
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

// Future<List<WallPaper>> getLandscapeWalls(String mode) async {
//   if (mode == "r") {
//     walls = [];
//     pageLandscape = 1;
//   } else {
//     pageLandscape = 2;
//   }
//   if (navStack.last == "Home") {
//     http
//         .get(
//             "https://wallhaven.cc/api/v1/search?q=Landscape&page=${pageLandscape}")
//         .then(
//       (http.Response response) {
//         var resp = json.decode(response.body);
//         print(resp);
//         for (int i = 0; i < resp["data"].length; i++) {
//           walls.add(
//             WallPaper(
//                 id: resp["data"][i]["id"],
//                 url: resp["data"][i]["url"],
//                 short_url: resp["data"][i]["short_url"],
//                 views: resp["data"][i]["views"].toString(),
//                 favourites: resp["data"][i]["favorites"].toString(),
//                 category: resp["data"][i]["category"],
//                 dimension_x: resp["data"][i]["dimension_x"].toString(),
//                 dimension_y: resp["data"][i]["dimension_y"].toString(),
//                 resolution: resp["data"][i]["resolution"],
//                 file_size: resp["data"][i]["file_size"].toString(),
//                 colors: resp["data"][i]["colors"],
//                 path: resp["data"][i]["path"],
//                 thumbs: resp["data"][i]["thumbs"],
//                 current_page: resp["meta"]["current_page"]),
//           );
//         }
//         pageLandscape = resp["meta"]["current_page"] + 1;
//         print("data done");
//         return walls;
//       },
//     );
//   } else {
//     print("Refresh Blocked");
//   }
// }

// Future<List<WallPaper>> get4KWalls(String mode) async {
//   if (mode == "r") {
//     walls = [];
//     page4K = 1;
//   } else {
//     page4K = 2;
//   }
//   if (navStack.last == "Home") {
//     http.get("https://wallhaven.cc/api/v1/search?q=4K&page=${page4K}").then(
//       (http.Response response) {
//         var resp = json.decode(response.body);
//         print(resp);
//         for (int i = 0; i < resp["data"].length; i++) {
//           walls.add(
//             WallPaper(
//                 id: resp["data"][i]["id"],
//                 url: resp["data"][i]["url"],
//                 short_url: resp["data"][i]["short_url"],
//                 views: resp["data"][i]["views"].toString(),
//                 favourites: resp["data"][i]["favorites"].toString(),
//                 category: resp["data"][i]["category"],
//                 dimension_x: resp["data"][i]["dimension_x"].toString(),
//                 dimension_y: resp["data"][i]["dimension_y"].toString(),
//                 resolution: resp["data"][i]["resolution"],
//                 file_size: resp["data"][i]["file_size"].toString(),
//                 colors: resp["data"][i]["colors"],
//                 path: resp["data"][i]["path"],
//                 thumbs: resp["data"][i]["thumbs"],
//                 current_page: resp["meta"]["current_page"]),
//           );
//         }
//         page4K = resp["meta"]["current_page"] + 1;
//         print("data done");
//         return walls;
//       },
//     );
//   } else {
//     print("Refresh Blocked");
//   }
// }

// Future<List<WallPaper>> getPatternWalls(String mode) async {
//   if (mode == "r") {
//     walls = [];
//     pagePattern = 1;
//   } else {
//     pagePattern = 2;
//   }
//   if (navStack.last == "Home") {
//     http
//         .get("https://wallhaven.cc/api/v1/search?q=Pattern&page=${pagePattern}")
//         .then(
//       (http.Response response) {
//         var resp = json.decode(response.body);
//         print(resp);
//         for (int i = 0; i < resp["data"].length; i++) {
//           walls.add(
//             WallPaper(
//                 id: resp["data"][i]["id"],
//                 url: resp["data"][i]["url"],
//                 short_url: resp["data"][i]["short_url"],
//                 views: resp["data"][i]["views"].toString(),
//                 favourites: resp["data"][i]["favorites"].toString(),
//                 category: resp["data"][i]["category"],
//                 dimension_x: resp["data"][i]["dimension_x"].toString(),
//                 dimension_y: resp["data"][i]["dimension_y"].toString(),
//                 resolution: resp["data"][i]["resolution"],
//                 file_size: resp["data"][i]["file_size"].toString(),
//                 colors: resp["data"][i]["colors"],
//                 path: resp["data"][i]["path"],
//                 thumbs: resp["data"][i]["thumbs"],
//                 current_page: resp["meta"]["current_page"]),
//           );
//         }
//         pagePattern = resp["meta"]["current_page"] + 1;
//         print("data done");
//         return walls;
//       },
//     );
//   } else {
//     print("Refresh Blocked");
//   }
// }

// Future<List<WallPaper>> getAnimeWalls(String mode) async {
//   if (mode == "r") {
//     walls = [];
//     pageAnime = 1;
//   } else {
//     pageAnime = 2;
//   }
//   if (navStack.last == "Home") {
//     http
//         .get("https://wallhaven.cc/api/v1/search?q=Anime&page=${pageAnime}")
//         .then(
//       (http.Response response) {
//         var resp = json.decode(response.body);
//         print(resp);
//         for (int i = 0; i < resp["data"].length; i++) {
//           walls.add(
//             WallPaper(
//                 id: resp["data"][i]["id"],
//                 url: resp["data"][i]["url"],
//                 short_url: resp["data"][i]["short_url"],
//                 views: resp["data"][i]["views"].toString(),
//                 favourites: resp["data"][i]["favorites"].toString(),
//                 category: resp["data"][i]["category"],
//                 dimension_x: resp["data"][i]["dimension_x"].toString(),
//                 dimension_y: resp["data"][i]["dimension_y"].toString(),
//                 resolution: resp["data"][i]["resolution"],
//                 file_size: resp["data"][i]["file_size"].toString(),
//                 colors: resp["data"][i]["colors"],
//                 path: resp["data"][i]["path"],
//                 thumbs: resp["data"][i]["thumbs"],
//                 current_page: resp["meta"]["current_page"]),
//           );
//         }
//         pageAnime = resp["meta"]["current_page"] + 1;
//         print("data done");
//         return walls;
//       },
//     );
//   } else {
//     print("Refresh Blocked");
//   }
// }

// Future<List<WallPaper>> getTechnologyWalls(String mode) async {
//   if (mode == "r") {
//     walls = [];
//     pageTechnology = 1;
//   } else {
//     pageTechnology = 2;
//   }
//   if (navStack.last == "Home") {
//     http
//         .get(
//             "https://wallhaven.cc/api/v1/search?q=Technology&page=${pageTechnology}")
//         .then(
//       (http.Response response) {
//         var resp = json.decode(response.body);
//         print(resp);
//         for (int i = 0; i < resp["data"].length; i++) {
//           walls.add(
//             WallPaper(
//                 id: resp["data"][i]["id"],
//                 url: resp["data"][i]["url"],
//                 short_url: resp["data"][i]["short_url"],
//                 views: resp["data"][i]["views"].toString(),
//                 favourites: resp["data"][i]["favorites"].toString(),
//                 category: resp["data"][i]["category"],
//                 dimension_x: resp["data"][i]["dimension_x"].toString(),
//                 dimension_y: resp["data"][i]["dimension_y"].toString(),
//                 resolution: resp["data"][i]["resolution"],
//                 file_size: resp["data"][i]["file_size"].toString(),
//                 colors: resp["data"][i]["colors"],
//                 path: resp["data"][i]["path"],
//                 thumbs: resp["data"][i]["thumbs"],
//                 current_page: resp["meta"]["current_page"]),
//           );
//         }
//         pageTechnology = resp["meta"]["current_page"] + 1;
//         print("data done");
//         return walls;
//       },
//     );
//   } else {
//     print("Refresh Blocked");
//   }
// }

// Future<List<WallPaper>> getCodeWalls(String mode) async {
//   if (mode == "r") {
//     walls = [];
//     pageCode = 1;
//   } else {
//     pageCode = 2;
//   }
//   if (navStack.last == "Home") {
//     http.get("https://wallhaven.cc/api/v1/search?q=Code&page=${pageCode}").then(
//       (http.Response response) {
//         var resp = json.decode(response.body);
//         print(resp);
//         for (int i = 0; i < resp["data"].length; i++) {
//           walls.add(
//             WallPaper(
//                 id: resp["data"][i]["id"],
//                 url: resp["data"][i]["url"],
//                 short_url: resp["data"][i]["short_url"],
//                 views: resp["data"][i]["views"].toString(),
//                 favourites: resp["data"][i]["favorites"].toString(),
//                 category: resp["data"][i]["category"],
//                 dimension_x: resp["data"][i]["dimension_x"].toString(),
//                 dimension_y: resp["data"][i]["dimension_y"].toString(),
//                 resolution: resp["data"][i]["resolution"],
//                 file_size: resp["data"][i]["file_size"].toString(),
//                 colors: resp["data"][i]["colors"],
//                 path: resp["data"][i]["path"],
//                 thumbs: resp["data"][i]["thumbs"],
//                 current_page: resp["meta"]["current_page"]),
//           );
//         }
//         pageCode = resp["meta"]["current_page"] + 1;
//         print("data done");
//         return walls;
//       },
//     );
//   } else {
//     print("Refresh Blocked");
//   }
// }

// Future<List<WallPaper>> getCarsWalls(String mode) async {
//   if (mode == "r") {
//     walls = [];
//     pageCars = 1;
//   } else {
//     pageCars = 2;
//   }
//   if (navStack.last == "Home") {
//     http.get("https://wallhaven.cc/api/v1/search?q=Cars&page=${pageCars}").then(
//       (http.Response response) {
//         var resp = json.decode(response.body);
//         print(resp);
//         for (int i = 0; i < resp["data"].length; i++) {
//           walls.add(
//             WallPaper(
//                 id: resp["data"][i]["id"],
//                 url: resp["data"][i]["url"],
//                 short_url: resp["data"][i]["short_url"],
//                 views: resp["data"][i]["views"].toString(),
//                 favourites: resp["data"][i]["favorites"].toString(),
//                 category: resp["data"][i]["category"],
//                 dimension_x: resp["data"][i]["dimension_x"].toString(),
//                 dimension_y: resp["data"][i]["dimension_y"].toString(),
//                 resolution: resp["data"][i]["resolution"],
//                 file_size: resp["data"][i]["file_size"].toString(),
//                 colors: resp["data"][i]["colors"],
//                 path: resp["data"][i]["path"],
//                 thumbs: resp["data"][i]["thumbs"],
//                 current_page: resp["meta"]["current_page"]),
//           );
//         }
//         pageCars = resp["meta"]["current_page"] + 1;
//         print("data done");
//         return walls;
//       },
//     );
//   } else {
//     print("Refresh Blocked");
//   }
// }

// Future<List<WallPaper>> getSkyscapeWalls(String mode) async {
//   if (mode == "r") {
//     walls = [];
//     pageSkyscape = 1;
//   } else {
//     pageSkyscape = 2;
//   }
//   if (navStack.last == "Home") {
//     http
//         .get(
//             "https://wallhaven.cc/api/v1/search?q=Skyscape&page=${pageSkyscape}")
//         .then(
//       (http.Response response) {
//         var resp = json.decode(response.body);
//         print(resp);
//         for (int i = 0; i < resp["data"].length; i++) {
//           walls.add(
//             WallPaper(
//                 id: resp["data"][i]["id"],
//                 url: resp["data"][i]["url"],
//                 short_url: resp["data"][i]["short_url"],
//                 views: resp["data"][i]["views"].toString(),
//                 favourites: resp["data"][i]["favorites"].toString(),
//                 category: resp["data"][i]["category"],
//                 dimension_x: resp["data"][i]["dimension_x"].toString(),
//                 dimension_y: resp["data"][i]["dimension_y"].toString(),
//                 resolution: resp["data"][i]["resolution"],
//                 file_size: resp["data"][i]["file_size"].toString(),
//                 colors: resp["data"][i]["colors"],
//                 path: resp["data"][i]["path"],
//                 thumbs: resp["data"][i]["thumbs"],
//                 current_page: resp["meta"]["current_page"]),
//           );
//         }
//         pageSkyscape = resp["meta"]["current_page"] + 1;
//         print("data done");
//         return walls;
//       },
//     );
//   } else {
//     print("Refresh Blocked");
//   }
// }

// Future<List<WallPaper>> getArchitectureWalls(String mode) async {
//   if (mode == "r") {
//     walls = [];
//     pageArchitecture = 1;
//   } else {
//     pageArchitecture = 2;
//   }
//   if (navStack.last == "Home") {
//     http
//         .get(
//             "https://wallhaven.cc/api/v1/search?q=Architecture&page=${pageArchitecture}")
//         .then(
//       (http.Response response) {
//         var resp = json.decode(response.body);
//         print(resp);
//         for (int i = 0; i < resp["data"].length; i++) {
//           walls.add(
//             WallPaper(
//                 id: resp["data"][i]["id"],
//                 url: resp["data"][i]["url"],
//                 short_url: resp["data"][i]["short_url"],
//                 views: resp["data"][i]["views"].toString(),
//                 favourites: resp["data"][i]["favorites"].toString(),
//                 category: resp["data"][i]["category"],
//                 dimension_x: resp["data"][i]["dimension_x"].toString(),
//                 dimension_y: resp["data"][i]["dimension_y"].toString(),
//                 resolution: resp["data"][i]["resolution"],
//                 file_size: resp["data"][i]["file_size"].toString(),
//                 colors: resp["data"][i]["colors"],
//                 path: resp["data"][i]["path"],
//                 thumbs: resp["data"][i]["thumbs"],
//                 current_page: resp["meta"]["current_page"]),
//           );
//         }
//         pageArchitecture = resp["meta"]["current_page"] + 1;
//         print("data done");
//         return walls;
//       },
//     );
//   } else {
//     print("Refresh Blocked");
//   }
// }

// Future<List<WallPaper>> getMarvelWalls(String mode) async {
//   if (mode == "r") {
//     walls = [];
//     pageMarvel = 1;
//   } else {
//     pageMarvel = 2;
//   }
//   if (navStack.last == "Home") {
//     http
//         .get("https://wallhaven.cc/api/v1/search?q=Marvel&page=${pageMarvel}")
//         .then(
//       (http.Response response) {
//         var resp = json.decode(response.body);
//         print(resp);
//         for (int i = 0; i < resp["data"].length; i++) {
//           walls.add(
//             WallPaper(
//                 id: resp["data"][i]["id"],
//                 url: resp["data"][i]["url"],
//                 short_url: resp["data"][i]["short_url"],
//                 views: resp["data"][i]["views"].toString(),
//                 favourites: resp["data"][i]["favorites"].toString(),
//                 category: resp["data"][i]["category"],
//                 dimension_x: resp["data"][i]["dimension_x"].toString(),
//                 dimension_y: resp["data"][i]["dimension_y"].toString(),
//                 resolution: resp["data"][i]["resolution"],
//                 file_size: resp["data"][i]["file_size"].toString(),
//                 colors: resp["data"][i]["colors"],
//                 path: resp["data"][i]["path"],
//                 thumbs: resp["data"][i]["thumbs"],
//                 current_page: resp["meta"]["current_page"]),
//           );
//         }
//         pageMarvel = resp["meta"]["current_page"] + 1;
//         print("data done");
//         return walls;
//       },
//     );
//   } else {
//     print("Refresh Blocked");
//   }
// }
