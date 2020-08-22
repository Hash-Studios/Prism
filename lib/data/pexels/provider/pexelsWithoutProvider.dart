import 'dart:convert';

import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/data/pexels/model/wallpaperp.dart';
import 'package:Prism/gitkey.dart';
import 'package:Prism/routes/router.dart';
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
  int index = pageNumbersP.indexOf(pageNumbersP
      .firstWhere((element) => element.keys.toList()[0] == categoryName));
  if (mode == "r") {
    wallsP = [];
    pageNumbersP[index] = {categoryName: 1};
  } else {
    int origPageNumber = pageNumbersP[index][categoryName];
    pageNumbersP[index] = {categoryName: origPageNumber + 1};
  }
  if (navStack.last == "Home") {
    print(
        "https://api.pexels.com/v1/search?query=${categoryName}&per_page=80&page=${pageNumbersP[index][categoryName]}");
    http.get(
        "https://api.pexels.com/v1/search?query=${categoryName}&per_page=80&page=${pageNumbersP[index][categoryName]}",
        headers: {"Authorization": pexelApiKey}).then(
      (http.Response response) {
        var resp = json.decode(response.body);
        for (int i = 0; i < resp["photos"].length; i++) {
          wallsP.add(
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
        pageNumbersP[index][categoryName] = resp["page"] + 1;
        print("data done");
        return wallsP;
      },
    );
  } else {
    print("Refresh Blocked");
  }
}

// int pageAbstractP = 1;
// int pageNatureP = 1;
// int pageArtP = 1;
// int pageMinimalP = 1;
// int pageTexturesP = 1;
// int pageMonochromeP = 1;
// int pageSpaceP = 1;
// int pageAnimalsP = 1;
// int pageNeonP = 1;
// int pageSportsP = 1;
// int pageMusicP = 1;
int pageColorsP = 1;
Future<List<WallPaperP>> getDataP(String mode) async {
  if (mode == "r") {
    wallsP = [];
    pageGetDataP = 1;
  } else {
    pageGetDataP = pageGetDataP + 1;
  }
  if (navStack.last == "Home") {
    http.get(
        "https://api.pexels.com/v1/curated?per_page=24&page=${pageGetDataP}",
        headers: {"Authorization": pexelApiKey}).then(
      (http.Response response) {
        var resp = json.decode(response.body);
        for (int i = 0; i < resp["photos"].length; i++) {
          wallsP.add(
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
        pageGetDataP = resp["page"] + 1;
        print("data done");
        return wallsP;
      },
    );
  } else {
    print("Refresh Blocked");
  }
}

Future<WallPaperP> getWallbyIDP(String id) async {
  print("https://api.pexels.com/v1/photos/$id");
  wall = null;
  http.get("https://api.pexels.com/v1/photos/$id",
      headers: {"Authorization": pexelApiKey}).then(
    (http.Response response) {
      var resp = json.decode(response.body);
      wall = WallPaperP(
          id: resp["id"].toString(),
          url: resp["url"].toString(),
          width: resp["width"].toString(),
          height: resp["height"].toString(),
          photographer: resp["photographer"].toString(),
          src: resp["category"]);
      return wall;
    },
  );
}

Future<List<WallPaperP>> getWallsPbyQuery(String query) async {
  http.get("https://api.pexels.com/v1/search?query=$query&per_page=80&page=1",
      headers: {"Authorization": pexelApiKey}).then(
    (http.Response response) {
      var resp = json.decode(response.body);
      for (int i = 0; i < resp["photos"].length; i++) {
        wallsPS.add(
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
      pageGetQueryP = resp["page"] + 1;
      print("data done");
      return wallsPS;
    },
  );
}

Future<List<WallPaperP>> getWallsPbyQueryPage(String query) async {
  http.get(
      "https://api.pexels.com/v1/search?query=$query&per_page=80&page=${pageGetQueryP}",
      headers: {"Authorization": pexelApiKey}).then(
    (http.Response response) {
      var resp = json.decode(response.body);
      for (int i = 0; i < resp["photos"].length; i++) {
        wallsPS.add(
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
      pageGetQueryP = resp["page"] + 1;
      print("data done");
      return wallsPS;
    },
  );
}

Future<List<WallPaperP>> getWallsPbyColor(String query) async {
  print("https://api.pexels.com/v1/search?query=$query&per_page=24&page=1");
  http.get("https://api.pexels.com/v1/search?query=$query&per_page=24&page=1",
      headers: {"Authorization": pexelApiKey}).then(
    (http.Response response) {
      var resp = json.decode(response.body);
      for (int i = 0; i < resp["photos"].length; i++) {
        wallsC.add(
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
      pageColorsP = resp["page"] + 1;
      print("data done");
      return wallsC;
    },
  );
}

Future<List<WallPaperP>> getWallsPbyColorPage(String query) async {
  print(
      "https://api.pexels.com/v1/search?query=$query&per_page=24&page=${pageColorsP}");
  http.get(
      "https://api.pexels.com/v1/search?query=$query&per_page=24&page=${pageColorsP}",
      headers: {"Authorization": pexelApiKey}).then(
    (http.Response response) {
      var resp = json.decode(response.body);
      for (int i = 0; i < resp["photos"].length; i++) {
        wallsC.add(
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
      pageColorsP = resp["page"] + 1;
      print("data done");
      return wallsC;
    },
  );
}

// Future<List<WallPaperP>> getAbstractWalls() async {
//   if (navStack.last == "Home") {
//     http.get(
//         "https://api.pexels.com/v1/search?query=abstract&per_page=80&page=${pageAbstractP}",
//         headers: {
//           "Authorization":
//               pexelApiKey
//         }).then(
//       (http.Response response) {
//         var resp = json.decode(response.body);
//         print(resp);
//         for (int i = 0; i < resp["photos"].length; i++) {
//           wallsP.add(
//             WallPaperP(
//                 id: resp["photos"][i]["id"].toString(),
//                 url: resp["photos"][i]["url"],
//                 width: resp["photos"][i]["width"].toString(),
//                 height: resp["photos"][i]["height"].toString(),
//                 photographer: resp["photos"][i]["photographer"],
//                 src: resp["photos"][i]["src"],
//                 current_page: resp["page"]),
//           );
//         }
//         pageAbstractP = resp["page"] + 1;
//         print("data done");
//         return wallsP;
//       },
//     );
//   } else {
//     print("Refresh Blocked");
//   }
// }

// Future<List<WallPaperP>> getNatureWalls() async {
//   if (navStack.last == "Home") {
//     http.get(
//         "https://api.pexels.com/v1/search?query=nature&per_page=80&page=${pageNatureP}",
//         headers: {
//           "Authorization":
//               pexelApiKey
//         }).then(
//       (http.Response response) {
//         var resp = json.decode(response.body);
//         for (int i = 0; i < resp["photos"].length; i++) {
//           wallsP.add(
//             WallPaperP(
//                 id: resp["photos"][i]["id"].toString(),
//                 url: resp["photos"][i]["url"],
//                 width: resp["photos"][i]["width"].toString(),
//                 height: resp["photos"][i]["height"].toString(),
//                 photographer: resp["photos"][i]["photographer"],
//                 src: resp["photos"][i]["src"],
//                 current_page: resp["page"]),
//           );
//         }
//         pageNatureP = resp["page"] + 1;
//         print("data done");
//         return wallsP;
//       },
//     );
//   } else {
//     print("Refresh Blocked");
//   }
// }

// Future<List<WallPaperP>> getArtWalls() async {
//   if (navStack.last == "Home") {
//     http.get(
//         "https://api.pexels.com/v1/search?query=art&per_page=80&page=${pageArtP}",
//         headers: {
//           "Authorization":
//               pexelApiKey
//         }).then(
//       (http.Response response) {
//         var resp = json.decode(response.body);
//         print(resp);
//         for (int i = 0; i < resp["photos"].length; i++) {
//           wallsP.add(
//             WallPaperP(
//                 id: resp["photos"][i]["id"].toString(),
//                 url: resp["photos"][i]["url"],
//                 width: resp["photos"][i]["width"].toString(),
//                 height: resp["photos"][i]["height"].toString(),
//                 photographer: resp["photos"][i]["photographer"],
//                 src: resp["photos"][i]["src"],
//                 current_page: resp["page"]),
//           );
//         }
//         pageArtP = resp["page"] + 1;
//         print("data done");
//         return wallsP;
//       },
//     );
//   } else {
//     print("Refresh Blocked");
//   }
// }

// Future<List<WallPaperP>> getMinimalWalls() async {
//   if (navStack.last == "Home") {
//     http.get(
//         "https://api.pexels.com/v1/search?query=Minimal&per_page=80&page=${pageMinimalP}",
//         headers: {
//           "Authorization":
//               pexelApiKey
//         }).then(
//       (http.Response response) {
//         var resp = json.decode(response.body);
//         print(resp);
//         for (int i = 0; i < resp["photos"].length; i++) {
//           wallsP.add(
//             WallPaperP(
//                 id: resp["photos"][i]["id"].toString(),
//                 url: resp["photos"][i]["url"],
//                 width: resp["photos"][i]["width"].toString(),
//                 height: resp["photos"][i]["height"].toString(),
//                 photographer: resp["photos"][i]["photographer"],
//                 src: resp["photos"][i]["src"],
//                 current_page: resp["page"]),
//           );
//         }
//         pageMinimalP = resp["page"] + 1;
//         print("data done");
//         return wallsP;
//       },
//     );
//   } else {
//     print("Refresh Blocked");
//   }
// }

// Future<List<WallPaperP>> getTexturesWalls() async {
//   if (navStack.last == "Home") {
//     http.get(
//         "https://api.pexels.com/v1/search?query=Textures&per_page=80&page=${pageTexturesP}",
//         headers: {
//           "Authorization":
//               pexelApiKey
//         }).then(
//       (http.Response response) {
//         var resp = json.decode(response.body);
//         print(resp);
//         for (int i = 0; i < resp["photos"].length; i++) {
//           wallsP.add(
//             WallPaperP(
//                 id: resp["photos"][i]["id"].toString(),
//                 url: resp["photos"][i]["url"],
//                 width: resp["photos"][i]["width"].toString(),
//                 height: resp["photos"][i]["height"].toString(),
//                 photographer: resp["photos"][i]["photographer"],
//                 src: resp["photos"][i]["src"],
//                 current_page: resp["page"]),
//           );
//         }
//         pageTexturesP = resp["page"] + 1;
//         print("data done");
//         return wallsP;
//       },
//     );
//   } else {
//     print("Refresh Blocked");
//   }
// }

// Future<List<WallPaperP>> getMonochromeWalls() async {
//   if (navStack.last == "Home") {
//     http.get(
//         "https://api.pexels.com/v1/search?query=Monochrome&per_page=80&page=${pageMonochromeP}",
//         headers: {
//           "Authorization":
//               pexelApiKey
//         }).then(
//       (http.Response response) {
//         var resp = json.decode(response.body);
//         print(resp);
//         for (int i = 0; i < resp["photos"].length; i++) {
//           wallsP.add(
//             WallPaperP(
//                 id: resp["photos"][i]["id"].toString(),
//                 url: resp["photos"][i]["url"],
//                 width: resp["photos"][i]["width"].toString(),
//                 height: resp["photos"][i]["height"].toString(),
//                 photographer: resp["photos"][i]["photographer"],
//                 src: resp["photos"][i]["src"],
//                 current_page: resp["page"]),
//           );
//         }
//         pageMonochromeP = resp["page"] + 1;
//         print("data done");
//         return wallsP;
//       },
//     );
//   } else {
//     print("Refresh Blocked");
//   }
// }

// Future<List<WallPaperP>> getSpaceWalls() async {
//   if (navStack.last == "Home") {
//     http.get(
//         "https://api.pexels.com/v1/search?query=Space&per_page=80&page=${pageSpaceP}",
//         headers: {
//           "Authorization":
//               pexelApiKey
//         }).then(
//       (http.Response response) {
//         var resp = json.decode(response.body);
//         print(resp);
//         for (int i = 0; i < resp["photos"].length; i++) {
//           wallsP.add(
//             WallPaperP(
//                 id: resp["photos"][i]["id"].toString(),
//                 url: resp["photos"][i]["url"],
//                 width: resp["photos"][i]["width"].toString(),
//                 height: resp["photos"][i]["height"].toString(),
//                 photographer: resp["photos"][i]["photographer"],
//                 src: resp["photos"][i]["src"],
//                 current_page: resp["page"]),
//           );
//         }
//         pageSpaceP = resp["page"] + 1;
//         print("data done");
//         return wallsP;
//       },
//     );
//   } else {
//     print("Refresh Blocked");
//   }
// }

// Future<List<WallPaperP>> getAnimalsWalls() async {
//   if (navStack.last == "Home") {
//     http.get(
//         "https://api.pexels.com/v1/search?query=Animals&per_page=80&page=${pageAnimalsP}",
//         headers: {
//           "Authorization":
//               pexelApiKey
//         }).then(
//       (http.Response response) {
//         var resp = json.decode(response.body);
//         print(resp);
//         for (int i = 0; i < resp["photos"].length; i++) {
//           wallsP.add(
//             WallPaperP(
//                 id: resp["photos"][i]["id"].toString(),
//                 url: resp["photos"][i]["url"],
//                 width: resp["photos"][i]["width"].toString(),
//                 height: resp["photos"][i]["height"].toString(),
//                 photographer: resp["photos"][i]["photographer"],
//                 src: resp["photos"][i]["src"],
//                 current_page: resp["page"]),
//           );
//         }
//         pageAnimalsP = resp["page"] + 1;
//         print("data done");
//         return wallsP;
//       },
//     );
//   } else {
//     print("Refresh Blocked");
//   }
// }

// Future<List<WallPaperP>> getNeonWalls() async {
//   if (navStack.last == "Home") {
//     http.get(
//         "https://api.pexels.com/v1/search?query=Neon&per_page=80&page=${pageNeonP}",
//         headers: {
//           "Authorization":
//               pexelApiKey
//         }).then(
//       (http.Response response) {
//         var resp = json.decode(response.body);
//         print(resp);
//         for (int i = 0; i < resp["photos"].length; i++) {
//           wallsP.add(
//             WallPaperP(
//                 id: resp["photos"][i]["id"].toString(),
//                 url: resp["photos"][i]["url"],
//                 width: resp["photos"][i]["width"].toString(),
//                 height: resp["photos"][i]["height"].toString(),
//                 photographer: resp["photos"][i]["photographer"],
//                 src: resp["photos"][i]["src"],
//                 current_page: resp["page"]),
//           );
//         }
//         pageNeonP = resp["page"] + 1;
//         print("data done");
//         return wallsP;
//       },
//     );
//   } else {
//     print("Refresh Blocked");
//   }
// }

// Future<List<WallPaperP>> getSportsWalls() async {
//   if (navStack.last == "Home") {
//     http.get(
//         "https://api.pexels.com/v1/search?query=Sports&per_page=80&page=${pageSportsP}",
//         headers: {
//           "Authorization":
//               pexelApiKey
//         }).then(
//       (http.Response response) {
//         var resp = json.decode(response.body);
//         print(resp);
//         for (int i = 0; i < resp["photos"].length; i++) {
//           wallsP.add(
//             WallPaperP(
//                 id: resp["photos"][i]["id"].toString(),
//                 url: resp["photos"][i]["url"],
//                 width: resp["photos"][i]["width"].toString(),
//                 height: resp["photos"][i]["height"].toString(),
//                 photographer: resp["photos"][i]["photographer"],
//                 src: resp["photos"][i]["src"],
//                 current_page: resp["page"]),
//           );
//         }
//         pageSportsP = resp["page"] + 1;
//         print("data done");
//         return wallsP;
//       },
//     );
//   } else {
//     print("Refresh Blocked");
//   }
// }

// Future<List<WallPaperP>> getMusicWalls() async {
//   if (navStack.last == "Home") {
//     http.get(
//         "https://api.pexels.com/v1/search?query=Music&per_page=80&page=${pageMusicP}",
//         headers: {
//           "Authorization":
//               pexelApiKey
//         }).then(
//       (http.Response response) {
//         var resp = json.decode(response.body);
//         print(resp);
//         for (int i = 0; i < resp["photos"].length; i++) {
//           wallsP.add(
//             WallPaperP(
//                 id: resp["photos"][i]["id"].toString(),
//                 url: resp["photos"][i]["url"],
//                 width: resp["photos"][i]["width"].toString(),
//                 height: resp["photos"][i]["height"].toString(),
//                 photographer: resp["photos"][i]["photographer"],
//                 src: resp["photos"][i]["src"],
//                 current_page: resp["page"]),
//           );
//         }
//         pageMusicP = resp["page"] + 1;
//         print("data done");
//         return wallsP;
//       },
//     );
//   } else {
//     print("Refresh Blocked");
//   }
// }
