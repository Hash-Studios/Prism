import 'dart:convert';
import 'package:http/http.dart' as http;
// import 'package:complimentary_colors/complimentary_colors.dart';
// import 'package:color/color.dart';

class WallData {
  String fetchUrl;
  Future getData(String query, int width, int height) async {
    width = 1080;
    height = 1920;
    if (query == "") {
      fetchUrl =
          "https://wallhaven.cc/api/v1/search?categories=100&purity=100&ratios=9x16&sorting=random&order=desc&page=1";
    } else {
      fetchUrl =
          "https://wallhaven.cc/api/v1/search?q=$query&categories=100&purity=100&ratios=9x16&sorting=random&order=desc&page=1";
    }
    http.Response response = await http.get(fetchUrl);
    if (response.statusCode == 200) {
      var fetchData = jsonDecode(response.body);
      int wallpPages;
      int currentPage;
      List wallpapersId = [];
      List wallpapersLinks = [];
      List wallpapersThumbs = [];
      List wallpapersColors = [];
      List wallpapersColors2 = [];
      List wallpapersViews = [];
      List wallpapersUrl = [];
      List wallpapersCreatedAt = [];
      List wallpapersResolution = [];
      List wallpapersFav = [];
      List wallpapersSize = [];
      List wallpapers = fetchData["data"];
      Map meta = fetchData["meta"];
      currentPage = meta["current_page"];
      wallpPages = meta["last_page"];
      if (wallpPages >= 5) {
        wallpPages = 5;
      }
      for (int i = 0; i < wallpapers.length; i++) {
        // print(
        //     '${wallpapers[i]["dimension_x"]}x${wallpapers[i]["dimension_y"]}');
        wallpapersLinks.add(wallpapers[i]["path"].toString());
        wallpapersThumbs.add(wallpapers[i]["thumbs"]["original"].toString());
        wallpapersViews.add(wallpapers[i]["views"].toString());
        wallpapersUrl.add(wallpapers[i]["short_url"].toString());
        wallpapersResolution.add(wallpapers[i]["resolution"].toString());
        wallpapersCreatedAt.add(wallpapers[i]["created_at"].toString());
        wallpapersFav.add(wallpapers[i]["favorites"].toString());
        wallpapersId.add(wallpapers[i]["id"].toString());
        wallpapersSize.add(wallpapers[i]["file_size"].toString());
        try {
          wallpapersColors
              .add(wallpapers[i]["colors"][0].toString().substring(1));
          // print(wallpapersColors);
        } catch (e) {
          wallpapersColors.add("FFFFFF");
        }
        try {
          // if(wallpapers[i]["colors"][0].toString().substring(1)!="000000"){
          // HexColor givenColor = new HexColor(wallpapers[i]["colors"][0].toString().substring(1));
          // HexColor complimentaryColor = CalculateComplimentaryColor.fromHex(givenColor);
          // wallpapersColors.add(complimentaryColor.toString());
          // print(wallpapersColors);
          // }else{
          // wallpapersColors.add("FFFFFF");
          // }
          wallpapersColors2
              .add(wallpapers[i]["colors"][2].toString().substring(1));
        } catch (e) {
          // if(wallpapers[i]["colors"][0].toString().substring(1)!="000000"){
          // HexColor givenColor = new HexColor(wallpapers[i]["colors"][0].toString().substring(1));
          // HexColor complimentaryColor = CalculateComplimentaryColor.fromHex(givenColor);
          // wallpapersColors.add(complimentaryColor.toString());
          // print(wallpapersColors);
          // }else{
          wallpapersColors.add("000000");
          // }
        }
      }
      for (int i = 2; i <= 5; i++) {
        if (currentPage == wallpPages) {
          break;
        } else {
          if (query == "") {
            fetchUrl =
                "https://wallhaven.cc/api/v1/search?categories=100&purity=100&ratios=9x16&sorting=random&order=desc&page=$i";
          } else {
            fetchUrl =
                "https://wallhaven.cc/api/v1/search?q=$query&categories=100&purity=100&ratios=9x16&sorting=random&order=desc&page=$i";
          }
          http.Response response = await http.get(fetchUrl);
          if (response.statusCode == 200) {
            var fetchData = jsonDecode(response.body);
            wallpapers = fetchData["data"];
            meta = fetchData["meta"];
            currentPage = meta["current_page"];
            for (int i = 0; i < wallpapers.length; i++) {
              // print(wallpapers[i]["path"]);
              wallpapersLinks.add(wallpapers[i]["path"].toString());
              wallpapersThumbs
                  .add(wallpapers[i]["thumbs"]["original"].toString());
              wallpapersViews.add(wallpapers[i]["views"].toString());
              wallpapersUrl.add(wallpapers[i]["short_url"].toString());
              wallpapersResolution.add(wallpapers[i]["resolution"].toString());
              wallpapersCreatedAt.add(wallpapers[i]["created_at"].toString());
              wallpapersFav.add(wallpapers[i]["favorites"].toString());
              wallpapersId.add(wallpapers[i]["id"].toString());
              wallpapersSize.add(wallpapers[i]["file_size"].toString());
              try {
                wallpapersColors
                    .add(wallpapers[i]["colors"][0].toString().substring(1));
              } catch (e) {
                wallpapersColors.add("FFFFFF");
              }
              try {
                wallpapersColors2
                    .add(wallpapers[i]["colors"][2].toString().substring(1));
              } catch (e) {
                wallpapersColors2.add("000000");
              }
            }
          } else {
            print(response.statusCode);
            throw 'Cannot Fetch Data';
          }
        }
      }
      Map wallheavenData = {
        "id": wallpapersId,
        "links": wallpapersLinks,
        "thumbs": wallpapersThumbs,
        "colors": wallpapersColors,
        "colors2": wallpapersColors2,
        "views": wallpapersViews,
        "url": wallpapersUrl,
        "resolution": wallpapersResolution,
        "created_at": wallpapersCreatedAt,
        "favourites": wallpapersFav,
        "size": wallpapersSize
      };
      // print(wallheavenData.toString());
      return wallheavenData;
    } else {
      print(response.statusCode);
      throw 'Cannot Fetch Data';
    }
  }
}
