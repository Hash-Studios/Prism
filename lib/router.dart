import 'package:Prism/routing_constants.dart';
import 'package:Prism/ui/pages/abstractScreen.dart';
import 'package:Prism/ui/pages/blueScreen.dart';
import 'package:Prism/ui/pages/curatedScreen.dart';
import 'package:Prism/ui/pages/favouriteScreen.dart';
import 'package:Prism/ui/pages/greenScreen.dart';
import 'package:Prism/ui/pages/homeScreen.dart';
import 'package:Prism/ui/pages/natureScreen.dart';
import 'package:Prism/ui/pages/redScreen.dart';
import 'package:Prism/ui/pages/searchScreen.dart';
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
    case CuratedRoute:
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => CuratedScreen());
    case AbstractRoute:
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => AbstractScreen());
    case NatureRoute:
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => NatureScreen());
    case RedRoute:
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => RedScreen());
    case BlueRoute:
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => BlueScreen());
    case GreenRoute:
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => GreenScreen());
    case WallpaperRoute:
      return CupertinoPageRoute(
          builder: (context) =>
              WallpaperScreen(arguements: settings.arguments));
    default:
      return CupertinoPageRoute(
        builder: (context) => UndefinedScreen(
          name: settings.name,
        ),
      );
  }
}
