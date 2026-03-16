import 'dart:io';

import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/router/not_found_page.dart';
import 'package:Prism/core/router/route_guards.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/popup/editProfilePanel.dart';
import 'package:Prism/features/admin_review/views/pages/admin_review_screen.dart';
import 'package:Prism/features/admin_review/views/pages/firestore_telemetry_screen.dart';
import 'package:Prism/features/admin_review/views/pages/swipe_review_screen.dart';
import 'package:Prism/features/ads/views/pages/ads_not_loading_page.dart';
import 'package:Prism/features/category_feed/views/pages/collection_view_screen.dart';
import 'package:Prism/features/category_feed/views/pages/color_screen.dart';
import 'package:Prism/features/debug_panel/views/pages/debug_panel_page.dart';
import 'package:Prism/features/favourite_setups/views/pages/favourite_setup_screen.dart';
import 'package:Prism/features/favourite_setups/views/pages/favourite_setup_view_screen.dart';
import 'package:Prism/features/favourite_walls/views/pages/favourite_wall_screen.dart';
import 'package:Prism/features/in_app_notifications/views/pages/notification_screen.dart';
import 'package:Prism/features/navigation/views/pages/ai_tab_page.dart';
import 'package:Prism/features/navigation/views/pages/dashboard_page.dart';
import 'package:Prism/features/navigation/views/pages/home_tab_page.dart';
import 'package:Prism/features/navigation/views/pages/profile_tab_page.dart';
import 'package:Prism/features/navigation/views/pages/search_tab_page.dart';
import 'package:Prism/features/navigation/views/pages/setups_tab_page.dart';
import 'package:Prism/features/navigation/views/pages/streak_tab_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/onboarding_v2_shell.dart';
import 'package:Prism/features/palette/domain/entities/wallpaper_detail_entity.dart';
import 'package:Prism/features/palette/views/pages/download_screen.dart';
import 'package:Prism/features/palette/views/pages/download_wallpaper_screen.dart';
import 'package:Prism/features/palette/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/palette/views/pages/wallpaper_filter_screen.dart';
import 'package:Prism/features/profile_setups/views/pages/profile_setup_view_screen.dart';
import 'package:Prism/features/public_profile/views/pages/followers_screen.dart';
import 'package:Prism/features/public_profile/views/pages/following_list_screen.dart';
import 'package:Prism/features/public_profile/views/pages/profile_screen.dart';
import 'package:Prism/features/public_profile/views/pages/user_profile_setup_view_screen.dart';
import 'package:Prism/features/quick_tiles/views/quick_tile_settings_screen.dart';
import 'package:Prism/features/session/views/pages/about_screen.dart';
import 'package:Prism/features/session/views/pages/coin_transactions_screen.dart';
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
import 'package:Prism/features/startup/views/pages/splash_widget.dart';
import 'package:Prism/features/streak/views/pages/streak_page.dart';
import 'package:Prism/features/theme_mode/views/pages/theme_view_page.dart';
import 'package:Prism/features/user_search/views/pages/search_screen.dart';
import 'package:Prism/features/user_search/views/pages/user_search_page.dart';
import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' show Image;

part 'app_router.gr.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  AppRouter({super.navigatorKey});

  final SignedInGuard _signedInGuard = const SignedInGuard();
  final AdminGuard _adminGuard = const AdminGuard();

  @override
  List<AutoRoute> get routes => [
    // Startup
    AutoRoute(path: '/', page: SplashWidgetRoute.page),
    AutoRoute(path: '/onboarding/v2', page: OnboardingV2ShellRoute.page),

    // Dashboard shell with bottom nav tabs
    AutoRoute(
      path: '/dashboard',
      page: DashboardRoute.page,
      guards: [_signedInGuard],
      children: [
        // Home tab
        AutoRoute(path: 'home', page: HomeTabRoute.page),
        // Search tab
        AutoRoute(
          path: 'search',
          page: SearchTabRoute.page,
          children: [
            AutoRoute(path: '', page: SearchRoute.page),
            AutoRoute(path: 'users', page: UserSearchRoute.page),
          ],
        ),
        // Setups tab
        AutoRoute(
          path: 'setups',
          page: SetupsTabRoute.page,
          children: [AutoRoute(path: '', page: SetupRoute.page)],
        ),
        // Streak tab
        AutoRoute(path: 'streak', page: StreakTabRoute.page),
        // Profile tab
        AutoRoute(
          path: 'profile',
          page: ProfileTabRoute.page,
          children: [
            AutoRoute(path: '', page: ProfileRoute.page),
            AutoRoute(path: 'settings', page: SettingsRoute.page),
            AutoRoute(path: 'about', page: AboutRoute.page),
            AutoRoute(path: 'share-prism', page: SharePrismRoute.page),
            AutoRoute(path: 'edit', page: EditProfilePanelRoute.page),
            AutoRoute(path: 'fav-walls', page: FavouriteWallpaperRoute.page),
            AutoRoute(path: 'fav-setups', page: FavouriteSetupRoute.page),
            AutoRoute(path: 'downloads', page: DownloadRoute.page),
            AutoRoute(path: 'followers', page: FollowersRoute.page),
            AutoRoute(path: 'following', page: FollowingListRoute.page),
          ],
        ),
      ],
    ),

    // Global routes (pushed over entire shell as full-screen dialogs)
    AutoRoute(path: '/ai', page: AiTabRoute.page),
    AutoRoute(path: '/wallpaper-detail', page: WallpaperDetailRoute.page),
    RedirectRoute(path: '/share', redirectTo: '/wallpaper-detail'), // Replaces ShareWallpaperViewRoute
    AutoRoute(path: '/download-wallpaper', page: DownloadWallpaperRoute.page),
    AutoRoute(path: '/wallpaper-filter', page: WallpaperFilterRoute.page),
    AutoRoute(path: '/fav-setup-view', page: FavSetupViewRoute.page, guards: [_signedInGuard]),
    AutoRoute(path: '/setup-view', page: SetupViewRoute.page),
    AutoRoute(path: '/setup/:setupName', page: ShareSetupViewRoute.page),
    AutoRoute(path: '/profile-setup-view', page: ProfileSetupViewRoute.page),
    AutoRoute(path: '/user-profile-setup-view', page: UserProfileSetupViewRoute.page),
    AutoRoute(path: '/upload-setup', page: UploadSetupRoute.page, guards: [_signedInGuard]),
    AutoRoute(path: '/edit-setup-details', page: EditSetupReviewRoute.page, guards: [_signedInGuard]),
    AutoRoute(path: '/setup-guidelines', page: SetupGuidelinesRoute.page, guards: [_signedInGuard]),
    AutoRoute(path: '/upload-wall', page: UploadWallRoute.page, guards: [_signedInGuard]),
    AutoRoute(path: '/edit-wall', page: EditWallRoute.page, guards: [_signedInGuard]),
    AutoRoute(path: '/draft-setup', page: DraftSetupRoute.page, guards: [_signedInGuard]),
    AutoRoute(path: '/review', page: ReviewRoute.page, guards: [_signedInGuard]),
    AutoRoute(path: '/coin-transactions', page: CoinTransactionsRoute.page),
    AutoRoute(path: '/theme', page: ThemeViewRoute.page),
    AutoRoute(path: '/notifications', page: NotificationRoute.page),
    AutoRoute(path: '/color', page: ColorRoute.page),
    AutoRoute(path: '/collection-view', page: CollectionViewRoute.page),
    AutoRoute(path: '/user/:identifier', page: ProfileRoute.page),
    AutoRoute(path: '/ads-not-loading', page: AdsNotLoadingRoute.page),
    AutoRoute(path: '/admin-review', page: AdminReviewRoute.page, guards: [_adminGuard]),
    AutoRoute(path: '/admin-review/swipe', page: SwipeReviewRoute.page, guards: [_adminGuard]),
    AutoRoute(path: '/admin-firestore-telemetry', page: FirestoreTelemetryRoute.page, guards: [_adminGuard]),
    AutoRoute(path: '/debug-panel', page: DebugPanelRoute.page, guards: [_adminGuard]),
    AutoRoute(path: '/quick-tile-settings', page: QuickTileSettingsRoute.page),
    AutoRoute(path: '/streak', page: StreakRoute.page),
    AutoRoute(path: '/not-found', page: NotFoundRoute.page),
    RedirectRoute(path: '*', redirectTo: '/not-found'),
  ];
}
