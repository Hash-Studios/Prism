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
import 'package:Prism/payments/upgrade.dart';
import 'package:Prism/core/router/route_names.dart';
import 'package:flutter/cupertino.dart';
import 'package:image/image.dart' as imagelib;

Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case splashRoute:
      pushNavStack("Splash");
      analytics.setCurrentScreen(screenName: splashRoute);
      return CupertinoPageRoute(builder: (context) => const SplashWidget());
    case searchRoute:
      pushNavStack("Search");
      analytics.setCurrentScreen(screenName: searchRoute);
      return PageRouteBuilder(
          transitionDuration: const Duration(), pageBuilder: (context, animation1, animation2) => SearchScreen());
    case homeRoute:
      pushNavStack("Home");
      analytics.setCurrentScreen(screenName: homeRoute);
      return PageRouteBuilder(
          transitionDuration: const Duration(), pageBuilder: (context, animation1, animation2) => PageManager());
    case profileRoute:
      pushNavStack("Profile");
      analytics.setCurrentScreen(screenName: profileRoute);
      return PageRouteBuilder(
          transitionDuration: const Duration(),
          pageBuilder: (context, animation1, animation2) => ProfileScreen(settings.arguments as List?));
    case followerProfileRoute:
      pushNavStack("Follower Profile");
      analytics.setCurrentScreen(screenName: followerProfileRoute);
      return CupertinoPageRoute(builder: (context) => ProfileScreen(settings.arguments as List?));
    case downloadRoute:
      pushNavStack("Downloads");
      analytics.setCurrentScreen(screenName: downloadRoute);
      return CupertinoPageRoute(builder: (context) => DownloadScreen());
    case reviewRoute:
      pushNavStack("Review Screen");
      analytics.setCurrentScreen(screenName: reviewRoute);
      return CupertinoPageRoute(builder: (context) => ReviewScreen());
    case favWallRoute:
      pushNavStack("Fav Walls");
      analytics.setCurrentScreen(screenName: favWallRoute);
      return CupertinoPageRoute(builder: (context) => const FavouriteWallpaperScreen());
    case favSetupRoute:
      pushNavStack("Fav Setups");
      analytics.setCurrentScreen(screenName: favSetupRoute);
      return CupertinoPageRoute(builder: (context) => const FavouriteSetupScreen());
    case premiumRoute:
      pushNavStack("Buy Premium");
      analytics.setCurrentScreen(screenName: premiumRoute);
      return CupertinoPageRoute(builder: (context) => UpgradeScreen());
    case editProfileRoute:
      pushNavStack("Edit Profile");
      analytics.setCurrentScreen(screenName: editProfileRoute);
      return CupertinoPageRoute(builder: (context) => const EditProfilePanel());
    case notificationsRoute:
      pushNavStack("Notifications");
      analytics.setCurrentScreen(screenName: notificationsRoute);
      analytics.logEvent(
        name: 'notifications_checked',
      );
      return CupertinoPageRoute(builder: (context) => NotificationScreen());
    case colorRoute:
      pushNavStack("Color");
      analytics.setCurrentScreen(screenName: colorRoute);
      return CupertinoPageRoute(builder: (context) => ColorScreen(arguments: settings.arguments as List?));
    case collectionViewRoute:
      pushNavStack("CollectionsView");
      analytics.setCurrentScreen(screenName: collectionViewRoute);
      return CupertinoPageRoute(builder: (context) => CollectionViewScreen(arguments: settings.arguments as List?));
    case wallpaperRoute:
      pushNavStack("Wallpaper");
      analytics.setCurrentScreen(screenName: wallpaperRoute);
      return CupertinoPageRoute(
          builder: (context) => WallpaperScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case searchWallpaperRoute:
      pushNavStack("Search Wallpaper");
      analytics.setCurrentScreen(screenName: searchWallpaperRoute);
      return CupertinoPageRoute(
          builder: (context) => SearchWallpaperScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case downloadWallpaperRoute:
      pushNavStack("DownloadedWallpaper");
      analytics.setCurrentScreen(screenName: downloadWallpaperRoute);
      return CupertinoPageRoute(
          builder: (context) => DownloadWallpaperScreen(arguments: settings.arguments as List?),
          fullscreenDialog: true);
    case shareRoute:
      pushNavStack("SharedWallpaper");
      analytics.setCurrentScreen(screenName: shareRoute);
      return CupertinoPageRoute(
          builder: (context) => ShareWallpaperViewScreen(arguments: settings.arguments as List?),
          fullscreenDialog: true);
    case shareSetupViewRoute:
      pushNavStack("SharedSetup");
      analytics.setCurrentScreen(screenName: shareSetupViewRoute);
      return CupertinoPageRoute(
          builder: (context) => ShareSetupViewScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case favWallViewRoute:
      pushNavStack("FavouriteWallpaper");
      analytics.setCurrentScreen(screenName: favWallViewRoute);
      return CupertinoPageRoute(
          builder: (context) => FavWallpaperViewScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case favSetupViewRoute:
      pushNavStack("Favourite Setup View");
      analytics.setCurrentScreen(screenName: favSetupViewRoute);
      return CupertinoPageRoute(
          builder: (context) => FavSetupViewScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case setupRoute:
      pushNavStack("Setups");
      analytics.setCurrentScreen(screenName: setupRoute);
      return PageRouteBuilder(
          transitionDuration: const Duration(), pageBuilder: (context, animation1, animation2) => const SetupScreen());
    case setupViewRoute:
      pushNavStack("SetupView");
      analytics.setCurrentScreen(screenName: setupViewRoute);
      return CupertinoPageRoute(
          builder: (context) => SetupViewScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case profileSetupViewRoute:
      pushNavStack("ProfileSetupView");
      analytics.setCurrentScreen(screenName: profileSetupViewRoute);
      return CupertinoPageRoute(
          builder: (context) => ProfileSetupViewScreen(
                arguments: settings.arguments as List?,
              ),
          fullscreenDialog: true);
    case profileWallViewRoute:
      pushNavStack("ProfileWallpaper");
      analytics.setCurrentScreen(screenName: profileWallViewRoute);
      return CupertinoPageRoute(
          builder: (context) => ProfileWallViewScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case userProfileWallViewRoute:
      pushNavStack("User ProfileWallpaper");
      analytics.setCurrentScreen(screenName: userProfileWallViewRoute);
      return CupertinoPageRoute(
          builder: (context) => UserProfileWallViewScreen(arguments: settings.arguments as List?),
          fullscreenDialog: true);
    case userProfileSetupViewRoute:
      pushNavStack("User ProfileSetup");
      analytics.setCurrentScreen(screenName: userProfileSetupViewRoute);
      return CupertinoPageRoute(
          builder: (context) => UserProfileSetupViewScreen(arguments: settings.arguments as List?),
          fullscreenDialog: true);
    case themeViewRoute:
      pushNavStack("Themes");
      analytics.setCurrentScreen(screenName: themeViewRoute);
      return CupertinoPageRoute(builder: (context) => ThemeView());
    case editWallRoute:
      pushNavStack("Edit Wallpaper");
      analytics.setCurrentScreen(screenName: editWallRoute);
      return CupertinoPageRoute(
          builder: (context) => EditWallScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case uploadSetupRoute:
      pushNavStack("Upload Setup");
      analytics.setCurrentScreen(screenName: uploadSetupRoute);
      return CupertinoPageRoute(
          builder: (context) => UploadSetupScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case editSetupDetailsRoute:
      pushNavStack("Edit Setup Details");
      analytics.setCurrentScreen(screenName: editSetupDetailsRoute);
      return CupertinoPageRoute(
          builder: (context) => EditSetupReviewScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case draftSetupRoute:
      pushNavStack("Draft Setup");
      analytics.setCurrentScreen(screenName: draftSetupRoute);
      return CupertinoPageRoute(builder: (context) => const DraftSetupScreen(), fullscreenDialog: true);
    case adsNotLoadingRoute:
      pushNavStack("Ads Not Loading");
      analytics.setCurrentScreen(screenName: adsNotLoadingRoute);
      return CupertinoPageRoute(builder: (context) => const AdsNotLoading(), fullscreenDialog: true);
    case userSearchRoute:
      pushNavStack("Search Users");
      analytics.setCurrentScreen(screenName: userSearchRoute);
      return CupertinoPageRoute(
        builder: (context) => const UserSearch(),
      );
    case setupGuidelinesRoute:
      pushNavStack("Setup Guidelines");
      analytics.setCurrentScreen(screenName: setupGuidelinesRoute);
      return CupertinoPageRoute(builder: (context) => const SetupGuidelinesScreen(), fullscreenDialog: true);
    case uploadWallRoute:
      pushNavStack("Add");
      analytics.setCurrentScreen(screenName: uploadWallRoute);
      return CupertinoPageRoute(
          builder: (context) => UploadWallScreen(arguments: settings.arguments as List?), fullscreenDialog: true);
    case aboutRoute:
      pushNavStack("About Prism");
      analytics.setCurrentScreen(screenName: aboutRoute);
      return CupertinoPageRoute(builder: (context) => AboutScreen(), fullscreenDialog: true);
    case settingsRoute:
      pushNavStack("Settings");
      analytics.setCurrentScreen(screenName: settingsRoute);
      return CupertinoPageRoute(builder: (context) => const SettingsScreen(), fullscreenDialog: true);
    case sharePrismRoute:
      pushNavStack("Share Prism");
      analytics.setCurrentScreen(screenName: sharePrismRoute);
      return CupertinoPageRoute(builder: (context) => SharePrismScreen(), fullscreenDialog: true);
    case wallpaperFilterRoute:
      pushNavStack("Wallpaper Filter");
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
      pushNavStack("Onboarding");
      analytics.setCurrentScreen(screenName: wallpaperFilterRoute);
      return CupertinoPageRoute(
        builder: (context) => OnboardingScreen(),
      );
    case followersRoute:
      pushNavStack("Followers");
      analytics.setCurrentScreen(screenName: followersRoute);
      return CupertinoPageRoute(
          builder: (context) => FollowersScreen(
                arguments: settings.arguments as List?,
              ));
    default:
      pushNavStack("undefined");
      analytics.setCurrentScreen(screenName: "/undefined");
      return CupertinoPageRoute(
        builder: (context) => UndefinedScreen(
          name: settings.name,
        ),
      );
  }
}
