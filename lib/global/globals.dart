import 'package:Prism/auth/google_auth.dart';
import 'package:flutter/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

var gAuth = GoogleAuth();
var currentAppVersion = '2.4.4';
var currentAppVersionCode = '11';
var updateChecked = false;
var updateAvailable = false;
var versionInfo = {};
var noNewNotification = false;
var height = 1440.0;

// GlobalKey keyCategoriesBar = GlobalKey();
// GlobalKey keyBottomBar = GlobalKey();
// GlobalKey keySearchButton = GlobalKey();
// GlobalKey keyFavButton = GlobalKey();
// GlobalKey keyProfileButton = GlobalKey();

AutoScrollController categoryController =
    AutoScrollController(axis: Axis.horizontal);
