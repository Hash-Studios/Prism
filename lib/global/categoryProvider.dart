import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as Data;
import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart'
    as WData;
import 'package:Prism/data/pexels/provider/pexelsWithoutProvider.dart' as PData;
import 'package:Prism/global/categoryMenu.dart';
import 'package:flutter/cupertino.dart';

final List choices = categories
    .map(
      (category) => CategoryMenu(
        name: category['name'],
        provider: category['provider'],
        icon: category['icon'],
      ),
    )
    .toList();

class CategorySupplier extends ChangeNotifier {
  Future<List> wallpaperFutureRefresh = Data.getPrismWalls();
  Future<List> home() async {
    Data.getPrismWalls();
  }

  CategoryMenu selectedChoice = choices[0];
  void changeSelectedChoice(choice) {
    this.selectedChoice = choice;
    notifyListeners();
  }

  Future<List> changeWallpaperFuture(choice, String mode) {
    for (var category in categories) {
      if (category['name'] == choice.name) {
        if (category['type'] == 'search') {
          if (category['provider'] == "WallHaven") {
            this.wallpaperFutureRefresh =
                WData.categoryDataFetcher(category['name'], mode);
          } else if (category['provider'] == "Pexels") {
            this.wallpaperFutureRefresh =
                PData.categoryDataFetcherP(category['name'], mode);
          }
        } else if (category['type'] == 'non-search') {
          if (category['name'] == 'Community') {
            this.wallpaperFutureRefresh = Data.getPrismWalls();
          } else if (category['name'] == 'Curated') {
            this.wallpaperFutureRefresh = PData.getDataP(mode);
          } else if (category['name'] == 'Popular') {
            this.wallpaperFutureRefresh = WData.getData(mode);
          }
        }
      }
    }
    notifyListeners();
  }
}
