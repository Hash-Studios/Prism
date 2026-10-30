import 'dart:io';

import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/router/not_found_page.dart';
import 'package:Prism/core/router/route_guards.dart';
import 'package:Prism/core/router/wallpaper_detail_route.dart';
import 'package:Prism/core/share/share_sheet.dart' show ShareSheetOpen;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/popup/edit_profile_panel.dart';
import 'package:Prism/data/upload/github_content_api.dart' show GitHubContent;
import 'package:Prism/features/admin_review/data/admin_moderation_repository.dart';
import 'package:Prism/features/admin_review/views/pages/admin_review_screen.dart';
import 'package:Prism/features/admin_review/views/pages/firestore_telemetry_screen.dart';
import 'package:Prism/features/admin_review/views/pages/swipe_review_screen.dart';
import 'package:Prism/features/admin_review/views/widgets/full_screen_image_view.dart';
import 'package:Prism/features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart';
import 'package:Prism/features/ai_wallpaper/views/pages/ai_wallpaper_tab_page.dart';
import 'package:Prism/features/auto_rotate/views/pages/auto_rotate_screen.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/category_feed/views/pages/collection_view_screen.dart';
import 'package:Prism/features/daily_chest/views/pages/daily_chest_page.dart';
import 'package:Prism/features/debug_panel/views/pages/debug_panel_page.dart';
import 'package:Prism/features/deep_link_input/domain/deep_link_input_workflow.dart';
import 'package:Prism/features/deep_link_input/views/pages/deep_link_input_page.dart';
import 'package:Prism/features/draw/draw.dart';
import 'package:Prism/features/drops/biz/bloc/drops_bloc.j.dart';
import 'package:Prism/features/drops/views/pages/drop_detail_page.dart';
import 'package:Prism/features/drops/views/pages/drop_preview_page.dart';
import 'package:Prism/features/drops/views/pages/drops_page.dart';
import 'package:Prism/features/favourite_walls/views/pages/favourite_wall_screen.dart';
import 'package:Prism/features/folders/views/pages/folder_screen.dart';
import 'package:Prism/features/in_app_notifications/views/pages/notification_screen.dart';
import 'package:Prism/features/ios_shortcuts/views/pages/ios_shortcuts_guide_screen.dart';
import 'package:Prism/features/leaderboard/leaderboard.dart';
import 'package:Prism/features/library/views/pages/library_screen.dart';
import 'package:Prism/features/live_wallpaper/views/pages/live_wallpaper_screen.dart';
import 'package:Prism/features/moods/views/pages/gallery_screen.dart';
import 'package:Prism/features/moods/views/pages/mood_screen.dart';
import 'package:Prism/features/navigation/views/pages/collection_tab_page.dart';
import 'package:Prism/features/navigation/views/pages/dashboard_page.dart';
import 'package:Prism/features/navigation/views/pages/home_tab_page.dart';
import 'package:Prism/features/navigation/views/pages/search_tab_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/onboarding_v2_shell.dart';
import 'package:Prism/features/premium/views/pages/premium_page.dart';
import 'package:Prism/features/public_profile/views/pages/followers_screen.dart';
import 'package:Prism/features/public_profile/views/pages/following_list_screen.dart';
import 'package:Prism/features/public_profile/views/pages/profile_screen.dart';
import 'package:Prism/features/quick_tiles/views/quick_tile_settings_screen.dart';
import 'package:Prism/features/rewards/views/pages/coin_history_page.dart';
import 'package:Prism/features/rewards/views/pages/rewards_page.dart';
import 'package:Prism/features/session/views/pages/about_screen.dart';
import 'package:Prism/features/session/views/pages/settings_screen.dart';
import 'package:Prism/features/session/views/pages/share_prism_screen.dart';
import 'package:Prism/features/shop/shop.dart';
import 'package:Prism/features/spin_wheel/views/pages/spin_wheel_page.dart';
import 'package:Prism/features/startup/views/pages/splash_widget.dart';
import 'package:Prism/features/theme_mode/views/pages/theme_view_page.dart';
import 'package:Prism/features/user_blocks/views/blocked_accounts_screen.dart';
import 'package:Prism/features/user_search/views/pages/search_screen.dart';
import 'package:Prism/features/user_search/views/pages/user_search_page.dart';
import 'package:Prism/features/wall_of_the_day/views/pages/wotd_archive_page.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart' show AiRemixSeed;
import 'package:Prism/features/wall_requests/views/pages/wall_requests_page.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/download_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/download_wallpaper_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_detail_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/pages/wallpaper_filter_screen.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_feed.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:Prism/features/wallpaper_position/views/pages/wallpaper_position_screen.dart';
import 'package:Prism/features/wallpaper_upload/data/upload_draft_store.dart';
import 'package:Prism/features/wallpaper_upload/domain/entities/wall_submission_result.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/edit_wall_screen.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/review_screen.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/upload_wall_screen.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/review_photo_preview.dart';
import 'package:Prism/features/weekly_challenges/views/pages/weekly_challenge_page.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:github/github.dart' show Contributor;

part 'app_router.gr.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  AppRouter({super.navigatorKey});

  final SignedInGuard _signedInGuard = const SignedInGuard();
  final AdminGuard _adminGuard = const AdminGuard();

  /// iOS keeps the Cupertino slide so the edge back-swipe works (a custom route has no back gesture). Android fades
  /// in and slides 24px from the right.
  @override
  RouteType get defaultRouteType => defaultTargetPlatform == TargetPlatform.iOS
      ? const RouteType.adaptive()
      : RouteType.custom(
          duration: PrismDurations.base,
          reverseDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (context.reduceMotion) return child;
            final Animation<double> t = animation.drive(CurveTween(curve: PrismCurves.enter));
            return FadeTransition(
              opacity: t,
              child: AnimatedBuilder(
                animation: t,
                builder: (context, child) => Transform.translate(offset: Offset(24 * (1 - t.value), 0), child: child),
                child: child,
              ),
            );
          },
        );

  @override
  List<AutoRoute> get routes => [
    // Startup
    AutoRoute(path: '/', page: SplashWidgetRoute.page),
    AutoRoute(path: '/onboarding/v2', page: OnboardingV2ShellRoute.page),

    AutoRoute(
      path: '/dashboard',
      page: DashboardRoute.page,
      guards: const [SignedInGuard(allowGuests: true)],
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
        // Rewards tab (was Streak)
        AutoRoute(path: 'rewards', page: RewardsTabRoute.page),
        RedirectRoute(path: 'streak', redirectTo: 'rewards'),
        // Collection tab
        AutoRoute(path: 'collection', page: CollectionTabRoute.page),
      ],
    ),

    // Global routes (pushed over entire shell as full-screen dialogs)
    AutoRoute(path: '/ai', page: AiTabRoute.page),
    CustomRoute(
      path: '/wallpaper-detail',
      page: WallpaperDetailRoute.page,
      customRouteBuilder: wallpaperDetailRouteBuilder,
    ),
    AutoRoute(path: '/wotd-archive', page: WotdArchiveRoute.page),
    AutoRoute(path: '/download-wallpaper', page: DownloadWallpaperRoute.page),
    AutoRoute(path: '/wallpaper-filter', page: WallpaperFilterRoute.page),
    AutoRoute(path: '/choose-wallpaper', page: DeepLinkInputRoute.page),
    AutoRoute(path: '/premium', page: PremiumRoute.page),
    RedirectRoute(path: '/paywall', redirectTo: '/premium'),
    AutoRoute(path: '/photo-preview', page: ReviewPhotoPreviewRoute.page, fullscreenDialog: true),
    CustomRoute(
      path: '/clock-preview',
      page: ClockPreviewRoute.page,
      fullscreenDialog: true,
      opaque: false,
      duration: PrismDurations.base,
      reverseDuration: PrismDurations.fast,
      transitionsBuilder: (context, animation, secondaryAnimation, child) => context.reduceMotion
          ? child
          : FadeTransition(
              opacity: animation.drive(CurveTween(curve: PrismCurves.enter)),
              child: child,
            ),
    ),
    // Standalone path so Edit Profile works when ProfileScreen was opened via
    // root-level ProfileRoute (/user/:id), e.g. home header avatar — nested
    // /dashboard/profile/edit is not reachable from that stack.
    AutoRoute(path: '/edit-profile', page: EditProfilePanelRoute.page, guards: [_signedInGuard]),
    // Same reason: the Streak tab's "Invite a friend" opens the referral screen outside the profile tab.
    AutoRoute(path: '/share-prism', page: SharePrismRoute.page, guards: [_signedInGuard]),
    AutoRoute(path: '/settings', page: SettingsRoute.page),
    AutoRoute(path: '/blocked-accounts', page: BlockedAccountsRoute.page, guards: [_signedInGuard]),
    AutoRoute(path: '/about', page: AboutRoute.page),
    AutoRoute(path: '/fav-walls', page: FavouriteWallpaperRoute.page),
    AutoRoute(path: '/downloads', page: DownloadRoute.page),
    AutoRoute(path: '/library', page: LibraryRoute.page),
    AutoRoute(path: '/folder/:folderId', page: FolderRoute.page, guards: [_signedInGuard]),
    AutoRoute(path: '/upload-wall', page: UploadWallRoute.page, guards: [_signedInGuard]),
    AutoRoute(path: '/edit-wall', page: EditWallRoute.page, guards: [_signedInGuard]),
    AutoRoute(path: '/review', page: ReviewRoute.page, guards: [_signedInGuard]),
    RedirectRoute(path: '/coin-transactions', redirectTo: '/rewards'),
    AutoRoute(path: '/theme', page: ThemeViewRoute.page),
    AutoRoute(path: '/notifications', page: NotificationRoute.page),
    AutoRoute(path: '/collection-view', page: CollectionViewRoute.page),
    AutoRoute(path: '/mood/:moodId', page: MoodRoute.page),
    AutoRoute(path: '/gallery', page: GalleryRoute.page),
    AutoRoute(path: '/requests', page: WallRequestsRoute.page),
    AutoRoute(path: '/challenges/:challengeId', page: WeeklyChallengeRoute.page),
    AutoRoute(path: '/user/:identifier', page: ProfileRoute.page),
    AutoRoute(path: '/followers', page: FollowersRoute.page),
    AutoRoute(path: '/following', page: FollowingListRoute.page),
    AutoRoute(path: '/admin-review', page: AdminReviewRoute.page, guards: [_adminGuard]),
    AutoRoute(path: '/admin-review/swipe', page: SwipeReviewRoute.page, guards: [_adminGuard]),
    AutoRoute(path: '/admin-review/image', page: FullScreenImageRoute.page, guards: [_adminGuard]),
    AutoRoute(path: '/admin-firestore-telemetry', page: FirestoreTelemetryRoute.page, guards: [_adminGuard]),
    AutoRoute(path: '/debug-panel', page: DebugPanelRoute.page, guards: [_adminGuard]),
    AutoRoute(path: '/quick-tile-settings', page: QuickTileSettingsRoute.page),
    AutoRoute(path: '/auto-rotate', page: AutoRotateRoute.page),
    AutoRoute(path: '/ios-shortcuts', page: IosShortcutsGuideRoute.page),
    AutoRoute(path: '/wallpaper-position', page: WallpaperPositionRoute.page),
    AutoRoute(path: '/live-wallpaper', page: LiveWallpaperRoute.page),
    AutoRoute(path: '/rewards', page: RewardsRoute.page),
    AutoRoute(path: '/coin-history', page: CoinHistoryRoute.page, guards: [_signedInGuard]),
    CustomRoute(
      path: '/daily-chest',
      page: DailyChestRoute.page,
      guards: [_signedInGuard],
      duration: PrismDurations.base,
      reverseDuration: PrismDurations.base,
      transitionsBuilder: _rewardTransition,
    ),
    CustomRoute(
      path: '/spin-wheel',
      page: SpinWheelRoute.page,
      guards: [_signedInGuard],
      duration: PrismDurations.base,
      reverseDuration: PrismDurations.base,
      transitionsBuilder: _rewardTransition,
    ),
    AutoRoute(path: '/shop', page: ShopRoute.page, guards: [_signedInGuard]),
    AutoRoute(path: '/drops', page: DropsRoute.page),
    AutoRoute(path: '/drops/:weekKey', page: DropDetailRoute.page),
    CustomRoute(
      path: '/drops/:weekKey/preview/:wallId',
      page: DropPreviewRoute.page,
      fullscreenDialog: true,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          _previewTransition(context, animation, child, Curves.easeOutCubic),
    ),
    AutoRoute(path: '/leaderboard', page: LeaderboardRoute.page, guards: [_signedInGuard]),
    AutoRoute(path: '/draw', page: DrawRoute.page, guards: [_signedInGuard]),
    RedirectRoute(path: '/streak', redirectTo: '/rewards'),
    AutoRoute(path: '/not-found', page: NotFoundRoute.page),
    RedirectRoute(path: '*', redirectTo: '/not-found'),
  ];
}

Widget _rewardTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => _previewTransition(context, animation, child, PrismCurves.enter);

Widget _previewTransition(BuildContext context, Animation<double> animation, Widget child, Curve curve) {
  if (context.reduceMotion) return child;
  final Animation<double> eased = CurvedAnimation(parent: animation, curve: curve);
  return FadeTransition(
    opacity: eased,
    child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1).animate(eased), child: child),
  );
}
