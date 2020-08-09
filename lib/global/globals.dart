import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/global/customPopupMenu.dart';
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
      title: 'Community', func: Data.getPrismWalls(), provider: "Prism"),
  CustomPopupMenu(title: 'Curated', func: home(), provider: "Pexels"),
  CustomPopupMenu(title: 'Shuffle', func: home(), provider: "WallHaven"),
  CustomPopupMenu(title: 'Abstract', func: home(), provider: "Pexels"),
  CustomPopupMenu(title: 'Landscape', func: home(), provider: "WallHaven"),
  CustomPopupMenu(title: 'Nature', func: home(), provider: "Pexels"),
  CustomPopupMenu(title: '4K', func: home(), provider: "WallHaven"),
  CustomPopupMenu(title: 'Art', func: home(), provider: "Pexels"),
  CustomPopupMenu(title: 'Pattern', func: home(), provider: "WallHaven"),
  CustomPopupMenu(title: 'Minimal', func: home(), provider: "Pexels"),
  CustomPopupMenu(title: 'Anime', func: home(), provider: "WallHaven"),
  CustomPopupMenu(title: 'Textures', func: home(), provider: "Pexels"),
  CustomPopupMenu(title: 'Technology', func: home(), provider: "WallHaven"),
  CustomPopupMenu(title: 'Monochrome', func: home(), provider: "Pexels"),
  CustomPopupMenu(title: 'Code', func: home(), provider: "WallHaven"),
  CustomPopupMenu(title: 'Space', func: home(), provider: "Pexels"),
  CustomPopupMenu(title: 'Cars', func: home(), provider: "WallHaven"),
  CustomPopupMenu(title: 'Animals', func: home(), provider: "Pexels"),
  CustomPopupMenu(title: 'Skyscape', func: home(), provider: "WallHaven"),
  CustomPopupMenu(title: 'Neon', func: home(), provider: "Pexels"),
  CustomPopupMenu(title: 'Architecture', func: home(), provider: "WallHaven"),
  CustomPopupMenu(title: 'Sports', func: home(), provider: "Pexels"),
  CustomPopupMenu(title: 'Marvel', func: home(), provider: "WallHaven"),
  CustomPopupMenu(title: 'Music', func: home(), provider: "Pexels"),
  CustomPopupMenu(title: 'Illustrations', func: home(), provider: "WallHaven"),
];

CustomPopupMenu selectedChoices = choices[0];
