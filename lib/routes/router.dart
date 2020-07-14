import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/ui/pages/categories/abstractScreen.dart';
import 'package:Prism/ui/pages/categories/animalsScreen.dart';
import 'package:Prism/ui/pages/categories/artScreen.dart';
import 'package:Prism/ui/pages/categories/colorScreen.dart';
import 'package:Prism/ui/pages/categories/curatedScreen.dart';
import 'package:Prism/ui/pages/categories/minimalScreen.dart';
import 'package:Prism/ui/pages/categories/monochromeScreen.dart';
import 'package:Prism/ui/pages/categories/musicScreen.dart';
import 'package:Prism/ui/pages/categories/natureScreen.dart';
import 'package:Prism/ui/pages/categories/neonScreen.dart';
import 'package:Prism/ui/pages/categories/spaceScreen.dart';
import 'package:Prism/ui/pages/categories/sportsScreen.dart';
import 'package:Prism/ui/pages/categories/texturesScreen.dart';
import 'package:Prism/ui/pages/download/downloadScreen.dart';
import 'package:Prism/ui/pages/download/downloadWallpaperViewScreen.dart';
import 'package:Prism/ui/pages/favourite/favouriteScreen.dart';
import 'package:Prism/ui/pages/favourite/favouriteWallpaperScreen.dart';
import 'package:Prism/ui/pages/home/pageManager.dart';
import 'package:Prism/ui/pages/home/splashScreen.dart';
import 'package:Prism/ui/pages/home/wallpaperScreen.dart';
import 'package:Prism/ui/pages/profile/profileScreen.dart';
import 'package:Prism/ui/pages/search/searchScreen.dart';
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
    case ArtRoute:
      navStack.add("Art");
      print(navStack);
      analytics.setCurrentScreen(screenName: ArtRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => ArtScreen());
    case MinimalRoute:
      navStack.add("Minimal");
      print(navStack);
      analytics.setCurrentScreen(screenName: MinimalRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => MinimalScreen());
    case TexturesRoute:
      navStack.add("Textures");
      print(navStack);
      analytics.setCurrentScreen(screenName: TexturesRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => TexturesScreen());
    case MonochromeRoute:
      navStack.add("Monochrome");
      print(navStack);
      analytics.setCurrentScreen(screenName: MonochromeRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => MonochromeScreen());
    case SpaceRoute:
      navStack.add("Space");
      print(navStack);
      analytics.setCurrentScreen(screenName: SpaceRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => SpaceScreen());
    case AnimalsRoute:
      navStack.add("Animals");
      print(navStack);
      analytics.setCurrentScreen(screenName: AnimalsRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => AnimalsScreen());
    case NeonRoute:
      navStack.add("Neon");
      print(navStack);
      analytics.setCurrentScreen(screenName: NeonRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => NeonScreen());
    case SportsRoute:
      navStack.add("Sports");
      print(navStack);
      analytics.setCurrentScreen(screenName: SportsRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => SportsScreen());
    case MusicRoute:
      navStack.add("Music");
      print(navStack);
      analytics.setCurrentScreen(screenName: MusicRoute);
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => MusicScreen());
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
