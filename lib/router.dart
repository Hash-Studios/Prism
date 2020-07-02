import 'package:Prism/routing_constants.dart';
import 'package:Prism/ui/pages/abstractScreen.dart';
import 'package:Prism/ui/pages/colorScreen.dart';
import 'package:Prism/ui/pages/curatedScreen.dart';
import 'package:Prism/ui/pages/downloadScreen.dart';
import 'package:Prism/ui/pages/downloadWallpaperViewScreen.dart';
import 'package:Prism/ui/pages/favouriteScreen.dart';
import 'package:Prism/ui/pages/favouriteWallpaperScreen.dart';
import 'package:Prism/ui/pages/natureScreen.dart';
import 'package:Prism/ui/pages/pageManager.dart';
import 'package:Prism/ui/pages/profileScreen.dart';
import 'package:Prism/ui/pages/searchScreen.dart';
import 'package:Prism/ui/pages/shareWallViewScreen.dart';
import 'package:Prism/ui/pages/splashScreen.dart';
import 'package:Prism/ui/pages/undefinedScreen.dart';
import 'package:Prism/ui/pages/wallpaperScreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

String currentRoute = "Home";
String previousRoute;
Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case SplashRoute:
      previousRoute = currentRoute;
      currentRoute = "Splash";
      print(currentRoute);
      return CupertinoPageRoute(builder: (context) => SplashWidget());
    case SearchRoute:
      previousRoute = currentRoute;
      currentRoute = "Search";
      print(currentRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => SearchScreen());
    case FavRoute:
      previousRoute = currentRoute;
      currentRoute = "Favourites";
      print(currentRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => FavouriteScreen());
    case HomeRoute:
      previousRoute = currentRoute;
      currentRoute = "Home";
      print(currentRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => PageManager());
    case ProfileRoute:
      previousRoute = currentRoute;
      currentRoute = "Profile";
      print(currentRoute);
      return CupertinoPageRoute(builder: (context) => ProfileScreen());
    case DownloadRoute:
      previousRoute = currentRoute;
      currentRoute = "Downloads";
      print(currentRoute);
      return CupertinoPageRoute(builder: (context) => DownloadScreen());
    case CuratedRoute:
      previousRoute = currentRoute;
      currentRoute = "Curated";
      print(currentRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => CuratedScreen());
    case AbstractRoute:
      previousRoute = currentRoute;
      currentRoute = "Abstract";
      print(currentRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => AbstractScreen());
    case NatureRoute:
      previousRoute = currentRoute;
      currentRoute = "Nature";
      print(currentRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => NatureScreen());
    case ColorRoute:
      previousRoute = currentRoute;
      currentRoute = "Color";
      print(currentRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) =>
              ColorScreen(arguments: settings.arguments));
    case WallpaperRoute:
      previousRoute = currentRoute;
      currentRoute = "Wallpaper";
      print(currentRoute);
      return CupertinoPageRoute(
          builder: (context) => WallpaperScreen(arguments: settings.arguments));
    case DownloadWallpaperRoute:
      previousRoute = currentRoute;
      currentRoute = "DownloadedWallpaper";
      print(currentRoute);
      return CupertinoPageRoute(
          builder: (context) =>
              DownloadWallpaperScreen(arguments: settings.arguments));
    case ShareRoute:
      previousRoute = currentRoute;
      currentRoute = "SharedWallpaper";
      print(currentRoute);
      return CupertinoPageRoute(
          builder: (context) =>
              ShareWallpaperViewScreen(arguments: settings.arguments));
    case FavWallViewRoute:
      previousRoute = currentRoute;
      currentRoute = "FavouriteWallpaper";
      print(currentRoute);
      return CupertinoPageRoute(
          builder: (context) =>
              FavWallpaperViewScreen(arguments: settings.arguments));
    default:
      previousRoute = currentRoute;
      currentRoute = "Undefined";
      print(currentRoute);
      return CupertinoPageRoute(
        builder: (context) => UndefinedScreen(
          name: settings.name,
        ),
      );
  }
}
