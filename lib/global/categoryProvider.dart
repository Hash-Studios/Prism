import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as Data;
import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart'
    as WData;
import 'package:Prism/global/customPopupMenu.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/cupertino.dart';

final List choices = [
  CustomPopupMenu(
      title: 'Community',
      // func: Data.getPrismWalls(),
      provider: "Prism",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Curated',
      // func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Shuffle',
      // func: WData.getData("r"),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Abstract',
      // func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Landscape',
      // func: WData.getLandscapeWalls("r"),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Nature',
      // func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: '4K',
      // func: WData.get4KWalls("r"),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Art',
      // func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Pattern',
      // func: WData.getPatternWalls("r"),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Minimal',
      // func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Anime',
      // func: WData.getAnimeWalls("r"),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Textures',
      // func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Technology',
      // func: WData.getTechnologyWalls("r"),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Monochrome',
      // func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Code',
      // func: WData.getCodeWalls("r"),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Space',
      // func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Cars',
      // func: WData.getCarsWalls("r"),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Animals',
      // func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Skyscape',
      // func: WData.getSkyscapeWalls("r"),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Neon',
      // func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Architecture',
      // func: WData.getArchitectureWalls("r"),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Sports',
      // func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Marvel',
      // func: WData.getMarvelWalls("r"),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Music',
      // func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
];

class CategorySupplier extends ChangeNotifier {
  Future<List> home() async {
    Data.getPrismWalls();
  }

  CustomPopupMenu selectedChoices = choices[0];

  void changeSelectedChoice(choice) {
    this.selectedChoices = choice;
    notifyListeners();
  }

  Future<List> returnFuture(String mode) {
    return this.selectedChoices.title == choices[0].title
        ? Data.getPrismWalls()
        : this.selectedChoices.title == choices[2].title
            ? WData.getData(mode)
            : this.selectedChoices.title == choices[4].title
                ? WData.getLandscapeWalls(mode)
                : this.selectedChoices.title == choices[6].title
                    ? WData.get4KWalls(mode)
                    : this.selectedChoices.title == choices[8].title
                        ? WData.getPatternWalls(mode)
                        : this.selectedChoices.title == choices[10].title
                            ? WData.getAnimeWalls(mode)
                            : this.selectedChoices.title == choices[12].title
                                ? WData.getTechnologyWalls(mode)
                                : this.selectedChoices.title ==
                                        choices[14].title
                                    ? WData.getCodeWalls(mode)
                                    : this.selectedChoices.title ==
                                            choices[16].title
                                        ? WData.getCarsWalls(mode)
                                        : this.selectedChoices.title ==
                                                choices[18].title
                                            ? WData.getSkyscapeWalls(mode)
                                            : this.selectedChoices.title ==
                                                    choices[20].title
                                                ? WData.getArchitectureWalls(
                                                    mode)
                                                : this.selectedChoices.title ==
                                                        choices[22].title
                                                    ? WData.getMarvelWalls(mode)
                                                    : WData.getData(mode);
  }
}
