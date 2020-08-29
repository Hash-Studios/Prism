import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/payments/upgrade.dart';
import 'package:Prism/ui/pages/collectionViewScreen.dart';
import 'package:Prism/ui/pages/download/downloadScreen.dart';
import 'package:Prism/ui/pages/download/downloadWallpaperViewScreen.dart';
import 'package:Prism/ui/pages/favourite/favouriteWallpaperScreen.dart';
import 'package:Prism/ui/pages/home/pageManager.dart';
import 'package:Prism/ui/pages/home/splashScreen.dart';
import 'package:Prism/ui/pages/home/wallpaperScreen.dart';
import 'package:Prism/ui/pages/photographerProfile.dart';
import 'package:Prism/ui/pages/categories/colorScreen.dart';
import 'package:Prism/ui/pages/profile/profileScreen.dart';
import 'package:Prism/ui/pages/profile/profileWallViewScreen.dart';
import 'package:Prism/ui/pages/profile/themeView.dart';
import 'package:Prism/ui/pages/profile/userProfileWallViewScreen.dart';
import 'package:Prism/ui/pages/search/searchScreen.dart';
import 'package:Prism/ui/pages/search/searchWallpaperScreen.dart';
import 'package:Prism/ui/pages/setupScreen.dart';
import 'package:Prism/ui/pages/setupViewScreen.dart';
import 'package:Prism/ui/pages/share/shareWallViewScreen.dart';
import 'package:Prism/ui/pages/undefinedScreen.dart';
import 'package:Prism/ui/pages/notificationScreen.dart';
import 'package:Prism/ui/pages/upload/editWallScreen.dart';
import 'package:Prism/ui/pages/upload/uploadWallScreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

List<String> navStack = ["Home"];
void SecureWindow() async {
  await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
  print("Added secure flags");
}

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
    // case FavRoute:
    //   navStack.add("Favourites");
    //   print(navStack);
    //   analytics.setCurrentScreen(screenName: FavRoute);
    //   return PageRouteBuilder(
    //       pageBuilder: (context, animation1, animation2) => FavouriteScreen());
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
      return PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => ProfileScreen());
    case PhotographerProfileRoute:
      navStack.add("User Profile");
      print(navStack);
      analytics.setCurrentScreen(screenName: PhotographerProfileRoute);
      return CupertinoPageRoute(
          builder: (context) => UserProfile(settings.arguments));
    case DownloadRoute:
      navStack.add("Downloads");
      print(navStack);
      analytics.setCurrentScreen(screenName: DownloadRoute);
      return CupertinoPageRoute(builder: (context) => DownloadScreen());
    case PremiumRoute:
      navStack.add("Buy Premium");
      print(navStack);
      analytics.setCurrentScreen(screenName: PremiumRoute);
      return CupertinoPageRoute(builder: (context) => UpgradeScreen());
    case NotificationsRoute:
      navStack.add("Notifications");
      print(navStack);
      analytics.setCurrentScreen(screenName: NotificationsRoute);
      return CupertinoPageRoute(builder: (context) => NotificationScreen());
    case ColorRoute:
      navStack.add("Color");
      print(navStack);
      analytics.setCurrentScreen(screenName: ColorRoute);
      return CupertinoPageRoute(
          builder: (context) => ColorScreen(arguments: settings.arguments));
    case CollectionViewRoute:
      navStack.add("CollectionsView");
      print(navStack);
      analytics.setCurrentScreen(screenName: CollectionViewRoute);
      return CupertinoPageRoute(
          builder: (context) =>
              CollectionViewScreen(arguments: settings.arguments));
    case WallpaperRoute:
      navStack.add("Wallpaper");
      print(navStack);
      SecureWindow();
      analytics.setCurrentScreen(screenName: WallpaperRoute);
      return CupertinoPageRoute(
          builder: (context) => WallpaperScreen(arguments: settings.arguments));
    case SearchWallpaperRoute:
      navStack.add("Search Wallpaper");
      print(navStack);
      SecureWindow();
      analytics.setCurrentScreen(screenName: SearchWallpaperRoute);
      return CupertinoPageRoute(
          builder: (context) =>
              SearchWallpaperScreen(arguments: settings.arguments));
    case DownloadWallpaperRoute:
      navStack.add("DownloadedWallpaper");
      print(navStack);
      SecureWindow();
      analytics.setCurrentScreen(screenName: DownloadWallpaperRoute);
      return CupertinoPageRoute(
          builder: (context) =>
              DownloadWallpaperScreen(arguments: settings.arguments));
    case ShareRoute:
      navStack.add("SharedWallpaper");
      print(navStack);
      SecureWindow();
      analytics.setCurrentScreen(screenName: ShareRoute);
      return CupertinoPageRoute(
          builder: (context) =>
              ShareWallpaperViewScreen(arguments: settings.arguments));
    case FavWallViewRoute:
      navStack.add("FavouriteWallpaper");
      print(navStack);
      SecureWindow();
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
    case ProfileWallViewRoute:
      navStack.add("ProfileWallpaper");
      print(navStack);
      analytics.setCurrentScreen(screenName: ProfileWallViewRoute);
      return CupertinoPageRoute(
          builder: (context) =>
              ProfileWallViewScreen(arguments: settings.arguments));
    case UserProfileWallViewRoute:
      navStack.add("User ProfileWallpaper");
      print(navStack);
      analytics.setCurrentScreen(screenName: UserProfileWallViewRoute);
      return CupertinoPageRoute(
          builder: (context) =>
              UserProfileWallViewScreen(arguments: settings.arguments));
    case ThemeViewRoute:
      navStack.add("Themes");
      print(navStack);
      analytics.setCurrentScreen(screenName: ThemeViewRoute);
      return CupertinoPageRoute(
          builder: (context) => ThemeView(arguments: settings.arguments));
    case EditWallRoute:
      navStack.add("Edit Wallpaper");
      print(navStack);
      analytics.setCurrentScreen(screenName: EditWallRoute);
      return MaterialPageRoute(
          builder: (context) => EditWallScreen(arguments: settings.arguments),
          fullscreenDialog: true);
    case UploadWallRoute:
      navStack.add("Add");
      print(navStack);
      analytics.setCurrentScreen(screenName: UploadWallRoute);
      return MaterialPageRoute(
          builder: (context) => UploadWallScreen(arguments: settings.arguments),
          fullscreenDialog: true);
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
