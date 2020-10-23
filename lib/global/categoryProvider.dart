import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as data;
import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart'
    as wdata;
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as pdata;
import 'package:Prism/global/categoryMenu.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/cupertino.dart';

final List choices = categories
    .map(
      (category) => CategoryMenu(
        name: category['name'].toString(),
        provider: category['provider'].toString(),
        icon: JamIcons.arrow_right,
      ),
    )
    .toList();

class CategorySupplier extends ChangeNotifier {
  Future<List> wallpaperFutureRefresh = categories[0]['type'] == 'non-search'
      ? categories[0]['name'] == 'Popular'
          ? wdata.getData("r")
          : categories[0]['name'] == 'Curated'
              ? pdata.getDataP("r")
              : categories[0]['name'] == 'Community'
                  ? data.getPrismWalls()
                  : data.getPrismWalls()
      : data.getPrismWalls();

  CategoryMenu selectedChoice = choices[0] as CategoryMenu;
  void changeSelectedChoice(CategoryMenu choice) {
    selectedChoice = choice;
    notifyListeners();
  }

  Future<List> changeWallpaperFuture(CategoryMenu choice, String mode) async {
    for (final category in categories) {
      if (category['name'] == choice.name) {
        if (category['type'] == 'search') {
          if (category['provider'] == "WallHaven") {
            wallpaperFutureRefresh =
                wdata.categoryDataFetcher(category['name'].toString(), mode);
          } else if (category['provider'] == "Pexels") {
            wallpaperFutureRefresh =
                pdata.categoryDataFetcherP(category['name'].toString(), mode);
          }
        } else if (category['type'] == 'non-search') {
          if (category['name'] == 'Community') {
            wallpaperFutureRefresh = data.getPrismWalls();
          } else if (category['name'] == 'Curated') {
            wallpaperFutureRefresh = pdata.getDataP(mode);
          } else if (category['name'] == 'Popular') {
            wallpaperFutureRefresh = wdata.getData(mode);
          }
        }
      }
    }
    notifyListeners();
  }
}
