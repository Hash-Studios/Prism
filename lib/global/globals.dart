import 'package:Prism/auth/google_auth.dart';
import 'package:flutter/material.dart';

var gAuth = GoogleAuth();

var updateAvailable = false;
var versionInfo = {};
var noNewNotification = false;

GlobalKey keyCategoriesBar = GlobalKey();
GlobalKey keyBottomBar = GlobalKey();
GlobalKey keySearchButton = GlobalKey();
GlobalKey keyFavButton = GlobalKey();
GlobalKey keyProfileButton = GlobalKey();
GlobalKey keyHomeWallpaperList = GlobalKey();
