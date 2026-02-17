import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/router/undefined_screen.dart';
import 'package:Prism/core/widgets/popup/editProfilePanel.dart';
import 'package:Prism/features/ads/views/pages/ads_not_loading_page.dart';
import 'package:Prism/features/category_feed/views/pages/collection_view_screen.dart';
import 'package:Prism/features/category_feed/views/pages/color_screen.dart';
import 'package:Prism/features/favourite_setups/views/pages/favourite_setup_screen.dart';
import 'package:Prism/features/favourite_setups/views/pages/favourite_setup_view_screen.dart';
import 'package:Prism/features/favourite_walls/views/pages/favourite_wall_screen.dart';
import 'package:Prism/features/favourite_walls/views/pages/favourite_wall_view_screen.dart';
import 'package:Prism/features/in_app_notifications/views/pages/notification_screen.dart';
import 'package:Prism/features/navigation/views/pages/page_manager.dart';
import 'package:Prism/features/palette/views/pages/download_screen.dart';
import 'package:Prism/features/palette/views/pages/download_wallpaper_screen.dart';
import 'package:Prism/features/palette/views/pages/search_wallpaper_screen.dart';
import 'package:Prism/features/palette/views/pages/share_wall_view_screen.dart';
import 'package:Prism/features/palette/views/pages/wallpaper_filter_screen.dart';
import 'package:Prism/features/palette/views/pages/wallpaper_screen.dart';
import 'package:Prism/features/profile_setups/views/pages/profile_setup_view_screen.dart';
import 'package:Prism/features/profile_walls/views/pages/profile_wall_view_screen.dart';
import 'package:Prism/features/public_profile/views/pages/followers_screen.dart';
import 'package:Prism/features/public_profile/views/pages/profile_screen.dart';
import 'package:Prism/features/public_profile/views/pages/user_profile_setup_view_screen.dart';
import 'package:Prism/features/public_profile/views/pages/user_profile_wall_view_screen.dart';
import 'package:Prism/features/session/views/pages/about_screen.dart';
import 'package:Prism/features/session/views/pages/settings_screen.dart';
import 'package:Prism/features/session/views/pages/share_prism_screen.dart';
import 'package:Prism/features/setups/views/pages/draft_setup_screen.dart';
import 'package:Prism/features/setups/views/pages/edit_setup_review_screen.dart';
import 'package:Prism/features/setups/views/pages/edit_wall_screen.dart';
import 'package:Prism/features/setups/views/pages/review_screen.dart';
import 'package:Prism/features/setups/views/pages/setup_guidelines_screen.dart';
import 'package:Prism/features/setups/views/pages/setup_screen.dart';
import 'package:Prism/features/setups/views/pages/setup_view_screen.dart';
import 'package:Prism/features/setups/views/pages/share_setup_view_screen.dart';
import 'package:Prism/features/setups/views/pages/upload_setup_screen.dart';
import 'package:Prism/features/setups/views/pages/upload_wall_screen.dart';
import 'package:Prism/features/startup/views/pages/onboarding_screen.dart';
import 'package:Prism/features/startup/views/pages/splash_widget.dart';
import 'package:Prism/features/theme_mode/views/pages/theme_view_page.dart';
import 'package:Prism/features/user_search/views/pages/search_screen.dart';
import 'package:Prism/features/user_search/views/pages/user_search_page.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/payments/upgrade.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:flutter/cupertino.dart';
import 'package:image/image.dart' as imagelib;

List<String> navStack = ["Home"];

Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case splashRoute:
      navStack.add("Splash");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: splashRoute);
      return CupertinoPageRoute(builder: (context) => const SplashWidget());
    case searchRoute:
      navStack.add("Search");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: searchRoute);
      return PageRouteBuilder(
          transitionDuration: const Duration(), pageBuilder: (context, animation1, animation2) => SearchScreen());
    case homeRoute:
      navStack.add("Home");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: homeRoute);
      return PageRouteBuilder(
          transitionDuration: const Duration(), pageBuilder: (context, animation1, animation2) => PageManager());
    case profileRoute:
      navStack.add("Profile");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: profileRoute);
      return PageRouteBuilder(
          transitionDuration: const Duration(),
          pageBuilder: (context, animation1, animation2) => ProfileScreen(settings.arguments as List?));
    case followerProfileRoute:
      navStack.add("Follower Profile");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: followerProfileRoute);
      return CupertinoPageRoute(builder: (context) => ProfileScreen(settings.arguments as List?));
    case downloadRoute:
      navStack.add("Downloads");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: downloadRoute);
      return CupertinoPageRoute(builder: (context) => DownloadScreen());
    case reviewRoute:
      navStack.add("Review Screen");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: reviewRoute);
      return CupertinoPageRoute(builder: (context) => ReviewScreen());
    case favWallRoute:
      navStack.add("Fav Walls");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: favWallRoute);
      return CupertinoPageRoute(builder: (context) => const FavouriteWallpaperScreen());
    case favSetupRoute:
      navStack.add("Fav Setups");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: favSetupRoute);
      return CupertinoPageRoute(builder: (context) => const FavouriteSetupScreen());
    case premiumRoute:
      navStack.add("Buy Premium");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: premiumRoute);
      return CupertinoPageRoute(builder: (context) => UpgradeScreen());
    case editProfileRoute:
      navStack.add("Edit Profile");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: editProfileRoute);
      return CupertinoPageRoute(builder: (context) => const EditProfilePanel());
    case notificationsRoute:
      navStack.add("Notifications");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: notificationsRoute);
      analytics.logEvent(
        name: 'notifications_checked',
      );
      return CupertinoPageRoute(builder: (context) => NotificationScreen());
    case colorRoute:
      navStack.add("Color");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: colorRoute);
      return CupertinoPageRoute(builder: (context) => ColorScreen(arguments: settings.arguments as List?));
    case collectionViewRoute:
      navStack.add("CollectionsView");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: collectionViewRoute);
      return CupertinoPageRoute(builder: (context) => CollectionViewScreen(arguments: settings.arguments as List?));
    case wallpaperRoute:
      navStack.add("Wallpaper");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: wallpaperRoute);
      return CupertinoPageRoute(
          builder: (context) => WallpaperScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case searchWallpaperRoute:
      navStack.add("Search Wallpaper");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: searchWallpaperRoute);
      return CupertinoPageRoute(
          builder: (context) => SearchWallpaperScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case downloadWallpaperRoute:
      navStack.add("DownloadedWallpaper");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: downloadWallpaperRoute);
      return CupertinoPageRoute(
          builder: (context) => DownloadWallpaperScreen(arguments: settings.arguments as List?),
          fullscreenDialog: true);
    case shareRoute:
      navStack.add("SharedWallpaper");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: shareRoute);
      return CupertinoPageRoute(
          builder: (context) => ShareWallpaperViewScreen(arguments: settings.arguments as List?),
          fullscreenDialog: true);
    case shareSetupViewRoute:
      navStack.add("SharedSetup");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: shareSetupViewRoute);
      return CupertinoPageRoute(
          builder: (context) => ShareSetupViewScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case favWallViewRoute:
      navStack.add("FavouriteWallpaper");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: favWallViewRoute);
      return CupertinoPageRoute(
          builder: (context) => FavWallpaperViewScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case favSetupViewRoute:
      navStack.add("Favourite Setup View");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: favSetupViewRoute);
      return CupertinoPageRoute(
          builder: (context) => FavSetupViewScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case setupRoute:
      navStack.add("Setups");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: setupRoute);
      return PageRouteBuilder(
          transitionDuration: const Duration(), pageBuilder: (context, animation1, animation2) => const SetupScreen());
    case setupViewRoute:
      navStack.add("SetupView");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: setupViewRoute);
      return CupertinoPageRoute(
          builder: (context) => SetupViewScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case profileSetupViewRoute:
      navStack.add("ProfileSetupView");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: profileSetupViewRoute);
      return CupertinoPageRoute(
          builder: (context) => ProfileSetupViewScreen(
                arguments: settings.arguments as List?,
              ),
          fullscreenDialog: true);
    case profileWallViewRoute:
      navStack.add("ProfileWallpaper");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: profileWallViewRoute);
      return CupertinoPageRoute(
          builder: (context) => ProfileWallViewScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case userProfileWallViewRoute:
      navStack.add("User ProfileWallpaper");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: userProfileWallViewRoute);
      return CupertinoPageRoute(
          builder: (context) => UserProfileWallViewScreen(arguments: settings.arguments as List?),
          fullscreenDialog: true);
    case userProfileSetupViewRoute:
      navStack.add("User ProfileSetup");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: userProfileSetupViewRoute);
      return CupertinoPageRoute(
          builder: (context) => UserProfileSetupViewScreen(arguments: settings.arguments as List?),
          fullscreenDialog: true);
    case themeViewRoute:
      navStack.add("Themes");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: themeViewRoute);
      return CupertinoPageRoute(builder: (context) => ThemeView());
    case editWallRoute:
      navStack.add("Edit Wallpaper");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: editWallRoute);
      return CupertinoPageRoute(
          builder: (context) => EditWallScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case uploadSetupRoute:
      navStack.add("Upload Setup");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: uploadSetupRoute);
      return CupertinoPageRoute(
          builder: (context) => UploadSetupScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case editSetupDetailsRoute:
      navStack.add("Edit Setup Details");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: editSetupDetailsRoute);
      return CupertinoPageRoute(
          builder: (context) => EditSetupReviewScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case draftSetupRoute:
      navStack.add("Draft Setup");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: draftSetupRoute);
      return CupertinoPageRoute(builder: (context) => const DraftSetupScreen(), fullscreenDialog: true);
    case adsNotLoadingRoute:
      navStack.add("Ads Not Loading");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: adsNotLoadingRoute);
      return CupertinoPageRoute(builder: (context) => const AdsNotLoading(), fullscreenDialog: true);
    case userSearchRoute:
      navStack.add("Search Users");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: userSearchRoute);
      return CupertinoPageRoute(
        builder: (context) => const UserSearch(),
      );
    case setupGuidelinesRoute:
      navStack.add("Setup Guidelines");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: setupGuidelinesRoute);
      return CupertinoPageRoute(builder: (context) => const SetupGuidelinesScreen(), fullscreenDialog: true);
    case uploadWallRoute:
      navStack.add("Add");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: uploadWallRoute);
      return CupertinoPageRoute(
          builder: (context) => UploadWallScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case aboutRoute:
      navStack.add("About Prism");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: aboutRoute);
      return CupertinoPageRoute(builder: (context) => AboutScreen(), fullscreenDialog: true);
    case settingsRoute:
      navStack.add("Settings");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: settingsRoute);
      return CupertinoPageRoute(builder: (context) => const SettingsScreen(), fullscreenDialog: true);
    case sharePrismRoute:
      navStack.add("Share Prism");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: sharePrismRoute);
      return CupertinoPageRoute(builder: (context) => SharePrismScreen(), fullscreenDialog: true);
    case wallpaperFilterRoute:
      navStack.add("Wallpaper Filter");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: wallpaperFilterRoute);
      return CupertinoPageRoute(
          builder: (context) => WallpaperFilterScreen(
                image: (settings.arguments as List?)![0] as imagelib.Image,
                finalImage: (settings.arguments as List?)![1] as imagelib.Image,
                filename: (settings.arguments as List?)![2] as String,
                finalFilename: (settings.arguments as List?)![3] as String,
              ),
          fullscreenDialog: true);
    case onboardingRoute:
      navStack.add("Onboarding");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: wallpaperFilterRoute);
      return CupertinoPageRoute(
        builder: (context) => OnboardingScreen(),
      );
    case followersRoute:
      navStack.add("Followers");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: followersRoute);
      return CupertinoPageRoute(
          builder: (context) => FollowersScreen(
                arguments: settings.arguments as List?,
              ));
    default:
      navStack.add("undefined");
      logger.d(navStack.toString());
      analytics.setCurrentScreen(screenName: "/undefined");
      return CupertinoPageRoute(
        builder: (context) => UndefinedScreen(
          name: settings.name,
        ),
      );
  }
}
