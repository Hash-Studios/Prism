import 'package:Prism/auth/google_auth.dart';
import 'package:flutter/material.dart';

GoogleAuth gAuth = GoogleAuth();
String currentAppVersion = '2.6.0';
String currentAppVersionCode = '51';
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

List premiumCollections = [
  "space",
  "abstract",
  "flat",
  "mesh gradients",
  "fluids",
];
