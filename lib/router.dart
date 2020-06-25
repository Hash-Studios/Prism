import 'package:Prism/routing_constants.dart';
import 'package:Prism/ui/pages/abstractScreen.dart';
import 'package:Prism/ui/pages/colorScreen.dart';
import 'package:Prism/ui/pages/curatedScreen.dart';
import 'package:Prism/ui/pages/downloadScreen.dart';
import 'package:Prism/ui/pages/downloadWallpaperViewScreen.dart';
import 'package:Prism/ui/pages/favouriteScreen.dart';
import 'package:Prism/ui/pages/favouriteWallpaperScreen.dart';
import 'package:Prism/ui/pages/homeScreen.dart';
import 'package:Prism/ui/pages/natureScreen.dart';
import 'package:Prism/ui/pages/profileScreen.dart';
import 'package:Prism/ui/pages/searchScreen.dart';
import 'package:Prism/ui/pages/shareWallViewScreen.dart';
import 'package:Prism/ui/pages/splashScreen.dart';
import 'package:Prism/ui/pages/undefinedScreen.dart';
import 'package:Prism/ui/pages/wallpaperScreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case SplashRoute:
      return CupertinoPageRoute(builder: (context) => SplashWidget());
    case SearchRoute:
      return CupertinoPageRoute(builder: (context) => SearchScreen());
    case FavRoute:
      return CupertinoPageRoute(builder: (context) => FavouriteScreen());
    case HomeRoute:
      return CupertinoPageRoute(builder: (context) => HomeScreen());
    case ProfileRoute:
      return CupertinoPageRoute(builder: (context) => ProfileScreen());
    case DownloadRoute:
      return CupertinoPageRoute(builder: (context) => DownloadScreen());
    case CuratedRoute:
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => CuratedScreen());
    case AbstractRoute:
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => AbstractScreen());
    case NatureRoute:
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => NatureScreen());
    case ColorRoute:
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) =>
              ColorScreen(arguments: settings.arguments));
    case WallpaperRoute:
      return CupertinoPageRoute(
          builder: (context) => WallpaperScreen(arguments: settings.arguments));
    case DownloadWallpaperRoute:
      return CupertinoPageRoute(
          builder: (context) =>
              DownloadWallpaperScreen(arguments: settings.arguments));
    case ShareRoute:
      return CupertinoPageRoute(
          builder: (context) =>
              ShareWallpaperViewScreen(arguments: settings.arguments));
    case FavWallViewRoute:
      return CupertinoPageRoute(
          builder: (context) =>
              FavWallpaperViewScreen(arguments: settings.arguments));
    default:
      return CupertinoPageRoute(
        builder: (context) => UndefinedScreen(
          name: settings.name,
        ),
      );
  }
}
