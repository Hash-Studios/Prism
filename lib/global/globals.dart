import 'package:Prism/auth/google_auth.dart';
import 'package:flutter/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

var gAuth = GoogleAuth();

var updateChecked = false;
var updateAvailable = false;
var versionInfo = {};
var noNewNotification = false;

<<<<<<< HEAD
GlobalKey keyCategoriesBar = GlobalKey();
GlobalKey keyBottomBar = GlobalKey();
GlobalKey keySearchButton = GlobalKey();
GlobalKey keyFavButton = GlobalKey();
GlobalKey keyProfileButton = GlobalKey();

AutoScrollController categoryController =
    AutoScrollController(axis: Axis.horizontal);
=======
// GlobalKey keyCategoriesBar = GlobalKey();
// GlobalKey keyBottomBar = GlobalKey();
// GlobalKey keySearchButton = GlobalKey();
// GlobalKey keyFavButton = GlobalKey();
// GlobalKey keyProfileButton = GlobalKey();
>>>>>>> e008c86... fixed global key bugs 🤟😀😀
