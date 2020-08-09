import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/global/customPopupMenu.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as Data;
import 'package:Prism/data/wallhaven/provider/wallhavenWithoutProvider.dart'
    as WData;

var gAuth = GoogleAuth();
var currentAppVersion = '2.4.7';
var currentAppVersionCode = '13';
var updateChecked = false;
var updateAvailable = false;
var versionInfo = {};
var noNewNotification = false;
var height = 1440.0;

AutoScrollController categoryController =
    AutoScrollController(axis: Axis.horizontal);

Future<List> home() async {
  Data.getPrismWalls();
}

List choices = [
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
CustomPopupMenu selectedChoices = choices[0];

Future<List> returnFuture(String mode) {
  return selectedChoices.title == choices[0].title
      ? Data.getPrismWalls()
      : selectedChoices.title == choices[2].title
          ? WData.getData(mode)
          : selectedChoices.title == choices[4].title
              ? WData.getLandscapeWalls(mode)
              : selectedChoices.title == choices[6].title
                  ? WData.get4KWalls(mode)
                  : selectedChoices.title == choices[8].title
                      ? WData.getPatternWalls(mode)
                      : selectedChoices.title == choices[10].title
                          ? WData.getAnimeWalls(mode)
                          : selectedChoices.title == choices[12].title
                              ? WData.getTechnologyWalls(mode)
                              : selectedChoices.title == choices[14].title
                                  ? WData.getCodeWalls(mode)
                                  : selectedChoices.title == choices[16].title
                                      ? WData.getCarsWalls(mode)
                                      : selectedChoices.title ==
                                              choices[18].title
                                          ? WData.getSkyscapeWalls(mode)
                                          : selectedChoices.title ==
                                                  choices[20].title
                                              ? WData.getArchitectureWalls(mode)
                                              : selectedChoices.title ==
                                                      choices[22].title
                                                  ? WData.getMarvelWalls(mode)
                                                  : WData.getData(mode);
}
