import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/global/customPopupMenu.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:Prism/data/prism/provider/prismWithoutProvider.dart' as Data;

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
      func: Data.getPrismWalls(),
      provider: "Prism",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Curated',
      func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Shuffle',
      func: home(),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Abstract',
      func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Landscape',
      func: home(),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Nature',
      func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: '4K',
      func: home(),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Art',
      func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Pattern',
      func: home(),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Minimal',
      func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Anime',
      func: home(),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Textures',
      func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Technology',
      func: home(),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Monochrome',
      func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Code',
      func: home(),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Space',
      func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Cars',
      func: home(),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Animals',
      func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Skyscape',
      func: home(),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Neon',
      func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Architecture',
      func: home(),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Sports',
      func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Marvel',
      func: home(),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Music',
      func: home(),
      provider: "Pexels",
      icon: JamIcons.pizza_slice),
  CustomPopupMenu(
      title: 'Illustrations',
      func: home(),
      provider: "WallHaven",
      icon: JamIcons.pizza_slice),
];

CustomPopupMenu selectedChoices = choices[0];
