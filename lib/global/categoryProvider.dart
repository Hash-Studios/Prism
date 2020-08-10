import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as Data;
import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart'
    as WData;
import 'package:Prism/global/customPopupMenu.dart';
import 'package:flutter/cupertino.dart';

final List choices = categories
    .map(
      (category) => CustomPopupMenu(
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

  CustomPopupMenu selectedChoice = choices[0];
  void changeSelectedChoice(choice) {
    this.selectedChoice = choice;
    notifyListeners();
  }

  Future<List> changeWallpaperFuture(choice, String mode) {
    this.wallpaperFutureRefresh = choice.name == choices[0].name
        ? Data.getPrismWalls()
        : choice.name == choices[2].name
            ? WData.getData(mode)
            : choice.name == choices[4].name
                ? WData.getLandscapeWalls(mode)
                : choice.name == choices[6].name
                    ? WData.get4KWalls(mode)
                    : choice.name == choices[8].name
                        ? WData.getPatternWalls(mode)
                        : choice.name == choices[10].name
                            ? WData.getAnimeWalls(mode)
                            : choice.name == choices[12].name
                                ? WData.getTechnologyWalls(mode)
                                : choice.name == choices[14].name
                                    ? WData.getCodeWalls(mode)
                                    : choice.name == choices[16].name
                                        ? WData.getCarsWalls(mode)
                                        : choice.name == choices[18].name
                                            ? WData.getSkyscapeWalls(mode)
                                            : choice.name == choices[20].name
                                                ? WData.getArchitectureWalls(
                                                    mode)
                                                : choice.name ==
                                                        choices[22].name
                                                    ? WData.getMarvelWalls(mode)
                                                    : WData.getData(mode);
    notifyListeners();
  }
}
