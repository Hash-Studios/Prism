import 'package:Prism/auth/google_auth.dart';
import 'package:flutter/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

GoogleAuth gAuth = GoogleAuth();
String currentAppVersion = '2.5.7';
String currentAppVersionCode = '19';
bool updateChecked = false;
bool updateAvailable = false;
Map versionInfo = {};
double height = 1440.0;
double width = 720.0;
bool loadingAd = true;
bool updateAlerted = false;

List topTitleText = [
  "TOP-RATED",
  "BEST OF COMMUNITY",
  "FAN-FAVOURITE",
  "TRENDING",
];

AutoScrollController categoryController =
    AutoScrollController(axis: Axis.horizontal);

List premiumCollections = [
  "space",
  "abstract",
  "flat",
  "mesh gradients",
  "fluids",
];
