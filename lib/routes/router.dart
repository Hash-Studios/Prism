import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/ui/pages/categories/abstractScreen.dart';
import 'package:Prism/ui/pages/categories/colorScreen.dart';
import 'package:Prism/ui/pages/categories/curatedScreen.dart';
import 'package:Prism/ui/pages/categories/natureScreen.dart';
import 'package:Prism/ui/pages/download/downloadScreen.dart';
import 'package:Prism/ui/pages/download/downloadWallpaperViewScreen.dart';
import 'package:Prism/ui/pages/favourite/favouriteScreen.dart';
import 'package:Prism/ui/pages/favourite/favouriteWallpaperScreen.dart';
import 'package:Prism/ui/pages/home/pageManager.dart';
import 'package:Prism/ui/pages/home/splashScreen.dart';
import 'package:Prism/ui/pages/home/wallpaperScreen.dart';
import 'package:Prism/ui/pages/profile/profileScreen.dart';
import 'package:Prism/ui/pages/search/searchScreen.dart';
import 'package:Prism/ui/pages/setupScreen.dart';
import 'package:Prism/ui/pages/setupViewScreen.dart';
import 'package:Prism/ui/pages/share/shareWallViewScreen.dart';
import 'package:Prism/ui/pages/undefinedScreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

List<String> navStack = ["Home"];
Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case SplashRoute:
      navStack.add("Splash");
      print(navStack);
      analytics.setCurrentScreen(screenName: SplashRoute);
      return CupertinoPageRoute(builder: (context) => SplashWidget());
    case SearchRoute:
      navStack.add("Search");
      print(navStack);
      analytics.setCurrentScreen(screenName: SearchRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => SearchScreen());
    case FavRoute:
      navStack.add("Favourites");
      print(navStack);
      analytics.setCurrentScreen(screenName: FavRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => FavouriteScreen());
    case HomeRoute:
      navStack.add("Home");
      print(navStack);
      analytics.setCurrentScreen(screenName: HomeRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => PageManager());
    case ProfileRoute:
      navStack.add("Profile");
      print(navStack);
      analytics.setCurrentScreen(screenName: ProfileRoute);
      return CupertinoPageRoute(builder: (context) => ProfileScreen());
    case DownloadRoute:
      navStack.add("Downloads");
      print(navStack);
      analytics.setCurrentScreen(screenName: DownloadRoute);
      return CupertinoPageRoute(builder: (context) => DownloadScreen());
    case CuratedRoute:
      navStack.add("Curated");
      print(navStack);
      analytics.setCurrentScreen(screenName: CuratedRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => CuratedScreen());
    case AbstractRoute:
      navStack.add("Abstract");
      print(navStack);
      analytics.setCurrentScreen(screenName: AbstractRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => AbstractScreen());
    case NatureRoute:
      navStack.add("Nature");
      print(navStack);
      analytics.setCurrentScreen(screenName: NatureRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => NatureScreen());
    case ColorRoute:
      navStack.add("Color");
      print(navStack);
      analytics.setCurrentScreen(screenName: ColorRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) =>
              ColorScreen(arguments: settings.arguments));
    case WallpaperRoute:
      navStack.add("Wallpaper");
      print(navStack);
      analytics.setCurrentScreen(screenName: WallpaperRoute);
      return CupertinoPageRoute(
          builder: (context) => WallpaperScreen(arguments: settings.arguments));
    case DownloadWallpaperRoute:
      navStack.add("DownloadedWallpaper");
      print(navStack);
      analytics.setCurrentScreen(screenName: DownloadWallpaperRoute);
      return CupertinoPageRoute(
          builder: (context) =>
              DownloadWallpaperScreen(arguments: settings.arguments));
    case ShareRoute:
      navStack.add("SharedWallpaper");
      print(navStack);
      analytics.setCurrentScreen(screenName: ShareRoute);
      return CupertinoPageRoute(
          builder: (context) =>
              ShareWallpaperViewScreen(arguments: settings.arguments));
    case FavWallViewRoute:
      navStack.add("FavouriteWallpaper");
      print(navStack);
      analytics.setCurrentScreen(screenName: FavWallViewRoute);
      return CupertinoPageRoute(
          builder: (context) =>
              FavWallpaperViewScreen(arguments: settings.arguments));
    case SetupRoute:
      navStack.add("Setups");
      print(navStack);
      analytics.setCurrentScreen(screenName: SetupRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => SetupScreen());
    case SetupViewRoute:
      navStack.add("SetupView");
      print(navStack);
      analytics.setCurrentScreen(screenName: SetupViewRoute);
      return MaterialPageRoute(
          builder: (context) => SetupViewScreen(arguments: settings.arguments));
    default:
      navStack.add("undefined");
      print(navStack);
      analytics.setCurrentScreen(screenName: "/undefined");
      return CupertinoPageRoute(
        builder: (context) => UndefinedScreen(
          name: settings.name,
        ),
      );
  }
}
