// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:cloud_firestore/cloud_firestore.dart' as _i974;
import 'package:firebase_remote_config/firebase_remote_config.dart' as _i627;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:internet_connection_checker/internet_connection_checker.dart'
    as _i973;

import '../../data/content_reports/firebase_content_report_repository.dart'
    as _i1058;
import '../../data/notifications/notification_tombstones.dart' as _i150;
import '../../data/user_blocks/firebase_user_block_repository.dart' as _i545;
import '../../data/view_stats/firebase_view_stats_repository.dart' as _i818;
import '../../features/admin_review/biz/bloc/review_batch_bloc.dart' as _i711;
import '../../features/admin_review/data/admin_moderation_repository.dart'
    as _i25;
import '../../features/admin_review/data/review_batch_repository.dart' as _i122;
import '../../features/ads/biz/bloc/ads_bloc.j.dart' as _i567;
import '../../features/ads/data/repositories/ads_repository_impl.dart' as _i418;
import '../../features/ads/domain/repositories/ads_repository.dart' as _i1055;
import '../../features/ads/domain/usecases/ads_usecases.dart' as _i321;
import '../../features/ai_wallpaper/data/repositories/ai_generation_repository_impl.dart'
    as _i673;
import '../../features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart' as _i408;
import '../../features/auto_rotate/data/repositories/auto_rotate_repository_impl.dart'
    as _i948;
import '../../features/auto_rotate/domain/repositories/auto_rotate_repository.dart'
    as _i563;
import '../../features/badges/biz/bloc/badges_bloc.dart' as _i219;
import '../../features/badges/data/repositories/badge_repository_impl.dart'
    as _i700;
import '../../features/badges/domain/repositories/badge_repository.dart'
    as _i360;
import '../../features/category_feed/biz/bloc/category_feed_bloc.j.dart'
    as _i195;
import '../../features/category_feed/data/repositories/category_feed_repository_impl.dart'
    as _i307;
import '../../features/category_feed/domain/repositories/category_feed_repository.dart'
    as _i563;
import '../../features/category_feed/domain/usecases/category_feed_usecases.dart'
    as _i301;
import '../../features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart'
    as _i782;
import '../../features/favourite_walls/data/favourites_sync_service.dart'
    as _i99;
import '../../features/favourite_walls/data/guest_favourites_merger.dart'
    as _i649;
import '../../features/favourite_walls/data/guest_favourites_store.dart'
    as _i672;
import '../../features/favourite_walls/data/repositories/favourite_walls_repository_impl.dart'
    as _i176;
import '../../features/favourite_walls/domain/repositories/favourite_walls_repository.dart'
    as _i643;
import '../../features/favourite_walls/domain/usecases/favourite_walls_usecases.dart'
    as _i406;
import '../../features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart'
    as _i584;
import '../../features/in_app_notifications/data/repositories/notifications_repository_impl.dart'
    as _i1017;
import '../../features/in_app_notifications/domain/repositories/notifications_repository.dart'
    as _i366;
import '../../features/in_app_notifications/domain/usecases/notifications_usecases.dart'
    as _i474;
import '../../features/live_wallpaper/data/live_texture_preparer.dart'
    as _i1003;
import '../../features/live_wallpaper/data/repositories/live_wallpaper_repository_impl.dart'
    as _i1067;
import '../../features/live_wallpaper/domain/repositories/live_wallpaper_repository.dart'
    as _i485;
import '../../features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart'
    as _i224;
import '../../features/onboarding_v2/src/data/repo/onboarding_v2_repo.dart'
    as _i897;
import '../../features/onboarding_v2/src/data/repo/onboarding_v2_repo_impl.dart'
    as _i794;
import '../../features/onboarding_v2/src/domain/usecases/complete_onboarding_v2_usecase.dart'
    as _i975;
import '../../features/onboarding_v2/src/domain/usecases/fetch_starter_pack_usecase.dart'
    as _i132;
import '../../features/onboarding_v2/src/domain/usecases/follow_starter_pack_usecase.dart'
    as _i74;
import '../../features/onboarding_v2/src/domain/usecases/save_interests_usecase.dart'
    as _i95;
import '../../features/onboarding_v2/src/services/first_wallpaper_service.dart'
    as _i502;
import '../../features/personalized_feed/biz/bloc/following_feed_bloc.j.dart'
    as _i567;
import '../../features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart'
    as _i872;
import '../../features/personalized_feed/biz/bloc/popular_feed_bloc.j.dart'
    as _i226;
import '../../features/personalized_feed/data/feed_impression_store.dart'
    as _i535;
import '../../features/personalized_feed/data/personalized_feed_repository_impl.dart'
    as _i903;
import '../../features/personalized_feed/domain/repositories/personalized_feed_repository.dart'
    as _i567;
import '../../features/personalized_feed/domain/usecases/personalized_feed_usecases.dart'
    as _i212;
import '../../features/pexels_feed/data/repositories/pexels_wallpaper_repository_impl.dart'
    as _i914;
import '../../features/pexels_feed/domain/repositories/pexels_wallpaper_repository.dart'
    as _i312;
import '../../features/prism_feed/biz/bloc/latest_feed_bloc.j.dart' as _i462;
import '../../features/prism_feed/data/prism_wall_search.dart' as _i289;
import '../../features/prism_feed/data/repositories/prism_wallpaper_repository_impl.dart'
    as _i759;
import '../../features/prism_feed/domain/repositories/prism_wallpaper_repository.dart'
    as _i727;
import '../../features/public_profile/biz/bloc/public_profile_bloc.j.dart'
    as _i717;
import '../../features/public_profile/data/repositories/public_profile_repository_impl.dart'
    as _i769;
import '../../features/public_profile/domain/repositories/public_profile_repository.dart'
    as _i817;
import '../../features/public_profile/domain/usecases/public_profile_usecases.dart'
    as _i446;
import '../../features/session/biz/bloc/session_bloc.j.dart' as _i364;
import '../../features/session/data/repositories/session_repository_impl.dart'
    as _i1021;
import '../../features/session/domain/repositories/session_repository.dart'
    as _i738;
import '../../features/session/domain/usecases/session_usecases.dart' as _i986;
import '../../features/startup/biz/bloc/startup_bloc.j.dart' as _i313;
import '../../features/startup/data/repositories/startup_repository_impl.dart'
    as _i152;
import '../../features/startup/domain/repositories/startup_repository.dart'
    as _i721;
import '../../features/startup/domain/usecases/bootstrap_app_usecase.dart'
    as _i415;
import '../../features/streak/bloc/streak_shop_bloc.dart' as _i456;
import '../../features/theme_mode/biz/bloc/theme_bloc.j.dart' as _i583;
import '../../features/theme_mode/data/repositories/theme_repository_impl.dart'
    as _i593;
import '../../features/theme_mode/domain/repositories/theme_repository.dart'
    as _i428;
import '../../features/theme_mode/domain/usecases/theme_usecases.dart' as _i937;
import '../../features/user_blocks/domain/repositories/user_block_repository.dart'
    as _i112;
import '../../features/user_search/biz/bloc/search_discovery_bloc.j.dart'
    as _i39;
import '../../features/user_search/biz/bloc/user_search_bloc.j.dart' as _i733;
import '../../features/user_search/data/repositories/user_search_repository_impl.dart'
    as _i352;
import '../../features/user_search/data/wallpaper_search_service.dart' as _i577;
import '../../features/user_search/domain/repositories/user_search_repository.dart'
    as _i204;
import '../../features/user_search/domain/usecases/search_users_usecase.dart'
    as _i750;
import '../../features/wall_of_the_day/biz/bloc/wotd_archive_bloc.j.dart'
    as _i71;
import '../../features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart' as _i183;
import '../../features/wall_of_the_day/data/repositories/wall_of_the_day_repository_impl.dart'
    as _i1070;
import '../../features/wall_of_the_day/domain/repositories/wall_of_the_day_repository.dart'
    as _i489;
import '../../features/wall_of_the_day/domain/usecases/fetch_wall_of_the_day_usecase.dart'
    as _i398;
import '../../features/wall_of_the_day/domain/usecases/fetch_wotd_archive_usecase.dart'
    as _i353;
import '../../features/wallhaven_feed/data/repositories/wallhaven_wallpaper_repository_impl.dart'
    as _i387;
import '../../features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart'
    as _i604;
import '../../features/wallpaper_detail/biz/bloc/wallpaper_detail_bloc.dart'
    as _i618;
import '../../features/wallpaper_detail/data/downloaded_wall_index.dart'
    as _i567;
import '../../features/wallpaper_detail/data/repositories/palette_repository_impl.dart'
    as _i446;
import '../../features/wallpaper_detail/domain/repositories/palette_repository.dart'
    as _i652;
import '../../features/wallpaper_detail/domain/usecases/wallpaper_stats_usecases.dart'
    as _i364;
import '../../features/wallpaper_detail/domain/usecases/wallpaper_views_usecase.dart'
    as _i231;
import '../../features/wallpaper_history/biz/bloc/wallpaper_history_bloc.j.dart'
    as _i62;
import '../../features/wallpaper_history/data/wallpaper_history_store.dart'
    as _i121;
import '../../features/wallpaper_position/biz/bloc/wallpaper_position_bloc.j.dart'
    as _i638;
import '../../features/wallpaper_position/data/repositories/wallpaper_position_repository_impl.dart'
    as _i536;
import '../../features/wallpaper_position/domain/repositories/wallpaper_position_repository.dart'
    as _i307;
import '../content_reports/content_report_repository.dart' as _i177;
import '../firestore/firestore_client.dart' as _i349;
import '../firestore/firestore_telemetry.dart' as _i393;
import '../network/connectivity_service.dart' as _i491;
import '../persistence/data_sources/app_icons_local_data_source.dart' as _i1003;
import '../persistence/data_sources/cache_maintenance_service.dart' as _i601;
import '../persistence/data_sources/favorites_local_data_source.dart' as _i640;
import '../persistence/data_sources/feed_cache_local_data_source.dart' as _i954;
import '../persistence/data_sources/notifications_local_data_source.dart'
    as _i290;
import '../persistence/data_sources/session_local_data_source.dart' as _i704;
import '../persistence/data_sources/settings_local_data_source.dart' as _i1073;
import '../persistence/local_store.dart' as _i496;
import '../personalization/taste_signals.dart' as _i731;
import '../view_stats/view_stats_repository.dart' as _i602;
import 'injection_module.dart' as _i212;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt initGetIt(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(getIt, environment, environmentFilter);
  final appModule = _$AppModule();
  gh.lazySingleton<_i974.FirebaseFirestore>(() => appModule.firebaseFirestore);
  gh.lazySingleton<_i393.FirestoreTelemetrySink>(
    () => appModule.firestoreTelemetrySink,
  );
  gh.lazySingleton<_i627.FirebaseRemoteConfig>(() => appModule.remoteConfig);
  gh.lazySingleton<_i973.InternetConnectionChecker>(
    () => appModule.internetConnectionChecker,
  );
  gh.lazySingleton<_i496.LocalStore>(() => appModule.localStore);
  gh.lazySingleton<_i1003.AppIconsLocalDataSource>(
    () => _i1003.AppIconsLocalDataSource(),
  );
  gh.lazySingleton<_i954.FeedCacheLocalDataSource>(
    () => _i954.FeedCacheLocalDataSource(),
  );
  gh.lazySingleton<_i673.AiGenerationRepositoryImpl>(
    () => _i673.AiGenerationRepositoryImpl(),
  );
  gh.lazySingleton<_i672.GuestFavouritesStore>(
    () => _i672.GuestFavouritesStore(),
  );
  gh.lazySingleton<_i1003.LiveTexturePreparer>(
    () => const _i1003.LiveTexturePreparer(),
  );
  gh.lazySingleton<_i307.WallpaperPositionRepository>(
    () => _i536.WallpaperPositionRepositoryImpl(),
  );
  gh.lazySingleton<_i721.StartupRepository>(
    () => _i152.StartupRepositoryImpl(),
  );
  gh.lazySingleton<_i640.FavoritesLocalDataSource>(
    () => _i640.FavoritesLocalDataSource(gh<_i496.LocalStore>()),
  );
  gh.lazySingleton<_i290.NotificationsLocalDataSource>(
    () => _i290.NotificationsLocalDataSource(gh<_i496.LocalStore>()),
  );
  gh.lazySingleton<_i704.SessionLocalDataSource>(
    () => _i704.SessionLocalDataSource(gh<_i496.LocalStore>()),
  );
  gh.lazySingleton<_i1073.SettingsLocalDataSource>(
    () => _i1073.SettingsLocalDataSource(gh<_i496.LocalStore>()),
  );
  gh.lazySingleton<_i150.NotificationTombstones>(
    () => _i150.NotificationTombstones(gh<_i496.LocalStore>()),
  );
  gh.lazySingleton<_i312.PexelsWallpaperRepository>(
    () => _i914.PexelsWallpaperRepositoryImpl(
      gh<_i954.FeedCacheLocalDataSource>(),
    ),
  );
  gh.lazySingleton<_i360.BadgeRepository>(() => _i700.BadgeRepositoryImpl());
  gh.lazySingleton<_i1055.AdsRepository>(() => _i418.AdsRepositoryImpl());
  gh.lazySingleton<_i652.PaletteRepository>(
    () => _i446.PaletteRepositoryImpl(),
  );
  gh.lazySingleton<_i366.NotificationsRepository>(
    () => _i1017.NotificationsRepositoryImpl(
      gh<_i290.NotificationsLocalDataSource>(),
      gh<_i150.NotificationTombstones>(),
    ),
  );
  gh.lazySingleton<_i177.ContentReportRepository>(
    () => _i1058.FirebaseContentReportRepository(),
  );
  gh.lazySingleton<_i604.WallhavenWallpaperRepository>(
    () => _i387.WallhavenWallpaperRepositoryImpl(
      gh<_i954.FeedCacheLocalDataSource>(),
    ),
  );
  gh.lazySingleton<_i474.FetchNotificationsUseCase>(
    () => _i474.FetchNotificationsUseCase(gh<_i366.NotificationsRepository>()),
  );
  gh.lazySingleton<_i474.MarkNotificationAsReadUseCase>(
    () => _i474.MarkNotificationAsReadUseCase(
      gh<_i366.NotificationsRepository>(),
    ),
  );
  gh.lazySingleton<_i474.DeleteNotificationUseCase>(
    () => _i474.DeleteNotificationUseCase(gh<_i366.NotificationsRepository>()),
  );
  gh.lazySingleton<_i474.ClearNotificationsUseCase>(
    () => _i474.ClearNotificationsUseCase(gh<_i366.NotificationsRepository>()),
  );
  gh.lazySingleton<_i474.DeleteNotificationsByIdsUseCase>(
    () => _i474.DeleteNotificationsByIdsUseCase(
      gh<_i366.NotificationsRepository>(),
    ),
  );
  gh.lazySingleton<_i474.MarkAllNotificationsAsReadUseCase>(
    () => _i474.MarkAllNotificationsAsReadUseCase(
      gh<_i366.NotificationsRepository>(),
    ),
  );
  gh.lazySingleton<_i474.RestoreNotificationsUseCase>(
    () =>
        _i474.RestoreNotificationsUseCase(gh<_i366.NotificationsRepository>()),
  );
  gh.lazySingleton<_i349.FirestoreClient>(
    () => appModule.firestoreClient(
      gh<_i974.FirebaseFirestore>(),
      gh<_i393.FirestoreTelemetrySink>(),
    ),
  );
  gh.lazySingleton<_i602.ViewStatsRepository>(
    () => _i818.FirebaseViewStatsRepository(gh<_i349.FirestoreClient>()),
  );
  gh.lazySingleton<_i485.LiveWallpaperRepository>(
    () => _i1067.LiveWallpaperRepositoryImpl(
      texturePreparer: gh<_i1003.LiveTexturePreparer>(),
    ),
  );
  gh.lazySingleton<_i415.BootstrapAppUseCase>(
    () => _i415.BootstrapAppUseCase(gh<_i721.StartupRepository>()),
  );
  gh.lazySingleton<_i428.ThemeRepository>(
    () => _i593.ThemeRepositoryImpl(gh<_i1073.SettingsLocalDataSource>()),
  );
  gh.lazySingleton<_i601.CacheMaintenanceService>(
    () => _i601.CacheMaintenanceService(
      gh<_i290.NotificationsLocalDataSource>(),
      gh<_i954.FeedCacheLocalDataSource>(),
      gh<_i1003.AppIconsLocalDataSource>(),
    ),
  );
  gh.factory<_i638.WallpaperPositionBloc>(
    () => _i638.WallpaperPositionBloc(gh<_i307.WallpaperPositionRepository>()),
  );
  gh.factory<_i219.BadgesBloc>(
    () => _i219.BadgesBloc(gh<_i360.BadgeRepository>()),
  );
  gh.lazySingleton<_i321.CreateRewardedAdUseCase>(
    () => _i321.CreateRewardedAdUseCase(gh<_i1055.AdsRepository>()),
  );
  gh.lazySingleton<_i321.ShowRewardedAdUseCase>(
    () => _i321.ShowRewardedAdUseCase(gh<_i1055.AdsRepository>()),
  );
  gh.lazySingleton<_i649.GuestFavouritesMerger>(
    () => _i649.GuestFavouritesMerger(
      gh<_i349.FirestoreClient>(),
      gh<_i672.GuestFavouritesStore>(),
      gh<_i640.FavoritesLocalDataSource>(),
    ),
  );
  gh.lazySingleton<_i937.LoadThemeUseCase>(
    () => _i937.LoadThemeUseCase(gh<_i428.ThemeRepository>()),
  );
  gh.lazySingleton<_i937.UpdateThemeUseCase>(
    () => _i937.UpdateThemeUseCase(gh<_i428.ThemeRepository>()),
  );
  gh.lazySingleton<_i121.WallpaperHistoryStore>(
    () => _i121.WallpaperHistoryStore(gh<_i1073.SettingsLocalDataSource>()),
  );
  gh.lazySingleton<_i491.ConnectivityService>(
    () => _i491.InternetConnectivityService(
      gh<_i973.InternetConnectionChecker>(),
    ),
  );
  gh.lazySingleton<_i731.TasteSignalStore>(
    () => _i731.TasteSignalStore(gh<_i1073.SettingsLocalDataSource>()),
  );
  gh.lazySingleton<_i535.FeedImpressionStore>(
    () => _i535.FeedImpressionStore(gh<_i1073.SettingsLocalDataSource>()),
  );
  gh.lazySingleton<_i567.DownloadedWallIndex>(
    () => _i567.DownloadedWallIndex(gh<_i1073.SettingsLocalDataSource>()),
  );
  gh.lazySingleton<_i738.SessionRepository>(
    () => _i1021.SessionRepositoryImpl(gh<_i704.SessionLocalDataSource>()),
  );
  gh.factory<_i567.AdsBloc>(
    () => _i567.AdsBloc(
      gh<_i321.CreateRewardedAdUseCase>(),
      gh<_i321.ShowRewardedAdUseCase>(),
    ),
  );
  gh.factory<_i313.StartupBloc>(
    () => _i313.StartupBloc(gh<_i415.BootstrapAppUseCase>()),
  );
  gh.lazySingleton<_i986.GetSessionUseCase>(
    () => _i986.GetSessionUseCase(gh<_i738.SessionRepository>()),
  );
  gh.lazySingleton<_i897.OnboardingV2Repository>(
    () => _i794.OnboardingV2RepositoryImpl(
      gh<_i627.FirebaseRemoteConfig>(),
      gh<_i349.FirestoreClient>(),
      gh<_i1073.SettingsLocalDataSource>(),
    ),
  );
  gh.lazySingleton<_i584.InAppNotificationsBloc>(
    () => _i584.InAppNotificationsBloc(
      gh<_i474.FetchNotificationsUseCase>(),
      gh<_i474.MarkNotificationAsReadUseCase>(),
      gh<_i474.DeleteNotificationUseCase>(),
      gh<_i474.DeleteNotificationsByIdsUseCase>(),
      gh<_i474.ClearNotificationsUseCase>(),
      gh<_i474.MarkAllNotificationsAsReadUseCase>(),
      gh<_i474.RestoreNotificationsUseCase>(),
    ),
  );
  gh.lazySingleton<_i25.AdminModerationRepository>(
    () => _i25.AdminModerationRepository(gh<_i349.FirestoreClient>()),
  );
  gh.lazySingleton<_i643.FavouriteWallsRepository>(
    () => _i176.FavouriteWallsRepositoryImpl(
      gh<_i349.FirestoreClient>(),
      gh<_i640.FavoritesLocalDataSource>(),
      gh<_i672.GuestFavouritesStore>(),
    ),
  );
  gh.factory<_i39.SearchDiscoveryBloc>(
    () => _i39.SearchDiscoveryBloc(gh<_i604.WallhavenWallpaperRepository>()),
  );
  gh.lazySingleton<_i364.RecordWallpaperActionUseCase>(
    () => _i364.RecordWallpaperActionUseCase(gh<_i602.ViewStatsRepository>()),
  );
  gh.lazySingleton<_i364.GetWallpaperSetCountUseCase>(
    () => _i364.GetWallpaperSetCountUseCase(gh<_i602.ViewStatsRepository>()),
  );
  gh.lazySingleton<_i231.RecordPrismWallpaperViewsUsecase>(
    () =>
        _i231.RecordPrismWallpaperViewsUsecase(gh<_i602.ViewStatsRepository>()),
  );
  gh.factory<_i364.SessionBloc>(
    () => _i364.SessionBloc(
      gh<_i986.GetSessionUseCase>(),
      sessionRepository: gh<_i738.SessionRepository>(),
    ),
  );
  gh.lazySingleton<_i122.ReviewBatchRepository>(
    () => _i122.ReviewBatchRepository(gh<_i349.FirestoreClient>()),
  );
  gh.lazySingleton<_i112.UserBlockRepository>(
    () => _i545.FirebaseUserBlockRepository(
      gh<_i738.SessionRepository>(),
      gh<_i349.FirestoreClient>(),
    ),
  );
  gh.lazySingleton<_i99.FavouritesSyncService>(
    () => _i99.FavouritesSyncService(
      gh<_i349.FirestoreClient>(),
      gh<_i640.FavoritesLocalDataSource>(),
      gh<_i649.GuestFavouritesMerger>(),
    ),
  );
  gh.lazySingleton<_i204.UserSearchRepository>(
    () => _i352.UserSearchRepositoryImpl(
      gh<_i349.FirestoreClient>(),
      gh<_i112.UserBlockRepository>(),
    ),
  );
  gh.factory<_i711.ReviewBatchBloc>(
    () => _i711.ReviewBatchBloc(
      gh<_i122.ReviewBatchRepository>(),
      gh<_i25.AdminModerationRepository>(),
    ),
  );
  gh.lazySingleton<_i750.SearchUsersUseCase>(
    () => _i750.SearchUsersUseCase(gh<_i204.UserSearchRepository>()),
  );
  gh.lazySingleton<_i727.PrismWallpaperRepository>(
    () => _i759.PrismWallpaperRepositoryImpl(
      gh<_i349.FirestoreClient>(),
      gh<_i954.FeedCacheLocalDataSource>(),
      gh<_i112.UserBlockRepository>(),
    ),
  );
  gh.lazySingleton<_i817.PublicProfileRepository>(
    () => _i769.PublicProfileRepositoryImpl(
      gh<_i349.FirestoreClient>(),
      gh<_i112.UserBlockRepository>(),
    ),
  );
  gh.lazySingleton<_i975.CompleteOnboardingV2UseCase>(
    () => _i975.CompleteOnboardingV2UseCase(gh<_i897.OnboardingV2Repository>()),
  );
  gh.lazySingleton<_i132.FetchStarterPackUseCase>(
    () => _i132.FetchStarterPackUseCase(gh<_i897.OnboardingV2Repository>()),
  );
  gh.lazySingleton<_i74.FollowStarterPackUseCase>(
    () => _i74.FollowStarterPackUseCase(gh<_i897.OnboardingV2Repository>()),
  );
  gh.lazySingleton<_i95.SaveInterestsUseCase>(
    () => _i95.SaveInterestsUseCase(gh<_i897.OnboardingV2Repository>()),
  );
  gh.lazySingleton<_i406.FetchFavouriteWallsUseCase>(
    () =>
        _i406.FetchFavouriteWallsUseCase(gh<_i643.FavouriteWallsRepository>()),
  );
  gh.lazySingleton<_i406.ToggleFavouriteWallUseCase>(
    () =>
        _i406.ToggleFavouriteWallUseCase(gh<_i643.FavouriteWallsRepository>()),
  );
  gh.lazySingleton<_i406.ClearFavouriteWallsUseCase>(
    () =>
        _i406.ClearFavouriteWallsUseCase(gh<_i643.FavouriteWallsRepository>()),
  );
  gh.factory<_i62.WallpaperHistoryBloc>(
    () => _i62.WallpaperHistoryBloc(gh<_i121.WallpaperHistoryStore>()),
  );
  gh.lazySingleton<_i289.PrismWallSearch>(
    () => _i289.PrismWallSearch(
      gh<_i349.FirestoreClient>(),
      gh<_i112.UserBlockRepository>(),
    ),
  );
  gh.factory<_i583.ThemeBloc>(
    () => _i583.ThemeBloc(
      gh<_i937.LoadThemeUseCase>(),
      gh<_i937.UpdateThemeUseCase>(),
      gh<_i428.ThemeRepository>(),
    ),
  );
  gh.lazySingleton<_i563.CategoryFeedRepository>(
    () => _i307.CategoryFeedRepositoryImpl(
      gh<_i1073.SettingsLocalDataSource>(),
      gh<_i954.FeedCacheLocalDataSource>(),
      gh<_i727.PrismWallpaperRepository>(),
      gh<_i604.WallhavenWallpaperRepository>(),
      gh<_i312.PexelsWallpaperRepository>(),
    ),
  );
  gh.lazySingleton<_i301.LoadCategoriesUseCase>(
    () => _i301.LoadCategoriesUseCase(gh<_i563.CategoryFeedRepository>()),
  );
  gh.lazySingleton<_i301.FetchCategoryFeedUseCase>(
    () => _i301.FetchCategoryFeedUseCase(gh<_i563.CategoryFeedRepository>()),
  );
  gh.lazySingleton<_i577.WallpaperSearchService>(
    () => _i577.WallpaperSearchService(
      gh<_i604.WallhavenWallpaperRepository>(),
      gh<_i312.PexelsWallpaperRepository>(),
      gh<_i1073.SettingsLocalDataSource>(),
      gh<_i289.PrismWallSearch>(),
    ),
  );
  gh.factory<_i782.FavouriteWallsBloc>(
    () => _i782.FavouriteWallsBloc(
      gh<_i406.FetchFavouriteWallsUseCase>(),
      gh<_i406.ToggleFavouriteWallUseCase>(),
      gh<_i406.ClearFavouriteWallsUseCase>(),
    ),
  );
  gh.factory<_i618.WallpaperDetailBloc>(
    () => _i618.WallpaperDetailBloc(
      gh<_i727.PrismWallpaperRepository>(),
      gh<_i604.WallhavenWallpaperRepository>(),
      gh<_i312.PexelsWallpaperRepository>(),
      gh<_i231.RecordPrismWallpaperViewsUsecase>(),
      gh<_i652.PaletteRepository>(),
      gh<_i364.GetWallpaperSetCountUseCase>(),
    ),
  );
  gh.lazySingleton<_i567.PersonalizedFeedRepository>(
    () => _i903.PersonalizedFeedRepositoryImpl(
      gh<_i349.FirestoreClient>(),
      gh<_i954.FeedCacheLocalDataSource>(),
      gh<_i1073.SettingsLocalDataSource>(),
      gh<_i604.WallhavenWallpaperRepository>(),
      gh<_i312.PexelsWallpaperRepository>(),
      gh<_i112.UserBlockRepository>(),
      gh<_i643.FavouriteWallsRepository>(),
      gh<_i731.TasteSignalStore>(),
      gh<_i535.FeedImpressionStore>(),
    ),
  );
  gh.factory<_i733.UserSearchBloc>(
    () => _i733.UserSearchBloc(gh<_i750.SearchUsersUseCase>()),
  );
  gh.factory<_i462.LatestFeedBloc>(
    () => _i462.LatestFeedBloc(gh<_i727.PrismWallpaperRepository>()),
  );
  gh.factory<_i456.StreakShopBloc>(
    () => _i456.StreakShopBloc(gh<_i727.PrismWallpaperRepository>()),
  );
  gh.lazySingleton<_i446.FetchPublicProfileWallsUseCase>(
    () => _i446.FetchPublicProfileWallsUseCase(
      gh<_i817.PublicProfileRepository>(),
    ),
  );
  gh.lazySingleton<_i446.FollowUserUseCase>(
    () => _i446.FollowUserUseCase(gh<_i817.PublicProfileRepository>()),
  );
  gh.lazySingleton<_i446.UnfollowUserUseCase>(
    () => _i446.UnfollowUserUseCase(gh<_i817.PublicProfileRepository>()),
  );
  gh.lazySingleton<_i446.FetchUserSummariesPageUseCase>(
    () => _i446.FetchUserSummariesPageUseCase(
      gh<_i817.PublicProfileRepository>(),
    ),
  );
  gh.lazySingleton<_i446.SearchUsersByUsernameUseCase>(
    () =>
        _i446.SearchUsersByUsernameUseCase(gh<_i817.PublicProfileRepository>()),
  );
  gh.lazySingleton<_i489.WallOfTheDayRepository>(
    () => _i1070.WallOfTheDayRepositoryImpl(
      gh<_i349.FirestoreClient>(),
      gh<_i727.PrismWallpaperRepository>(),
      gh<_i112.UserBlockRepository>(),
    ),
  );
  gh.lazySingleton<_i502.FirstWallpaperService>(
    () => _i502.FirstWallpaperService(
      gh<_i563.CategoryFeedRepository>(),
      gh<_i489.WallOfTheDayRepository>(),
    ),
  );
  gh.factory<_i717.PublicProfileBloc>(
    () => _i717.PublicProfileBloc(
      gh<_i446.FetchPublicProfileWallsUseCase>(),
      gh<_i446.FollowUserUseCase>(),
      gh<_i446.UnfollowUserUseCase>(),
      gh<_i446.FetchUserSummariesPageUseCase>(),
      gh<_i446.SearchUsersByUsernameUseCase>(),
    ),
  );
  gh.lazySingleton<_i212.FetchPersonalizedFeedUseCase>(
    () => _i212.FetchPersonalizedFeedUseCase(
      gh<_i567.PersonalizedFeedRepository>(),
    ),
  );
  gh.factory<_i567.FollowingFeedBloc>(
    () => _i567.FollowingFeedBloc(gh<_i567.PersonalizedFeedRepository>()),
  );
  gh.factory<_i226.PopularFeedBloc>(
    () => _i226.PopularFeedBloc(gh<_i567.PersonalizedFeedRepository>()),
  );
  gh.factory<_i195.CategoryFeedBloc>(
    () => _i195.CategoryFeedBloc(
      gh<_i301.LoadCategoriesUseCase>(),
      gh<_i301.FetchCategoryFeedUseCase>(),
      gh<_i112.UserBlockRepository>(),
    ),
  );
  gh.factory<_i224.OnboardingV2Bloc>(
    () => _i224.OnboardingV2Bloc(
      gh<_i132.FetchStarterPackUseCase>(),
      gh<_i95.SaveInterestsUseCase>(),
      gh<_i74.FollowStarterPackUseCase>(),
      gh<_i975.CompleteOnboardingV2UseCase>(),
      gh<_i502.FirstWallpaperService>(),
      gh<_i563.CategoryFeedRepository>(),
      gh<_i897.OnboardingV2Repository>(),
      gh<_i1073.SettingsLocalDataSource>(),
      gh<_i627.FirebaseRemoteConfig>(),
    ),
  );
  gh.lazySingleton<_i398.FetchWallOfTheDayUseCase>(
    () => _i398.FetchWallOfTheDayUseCase(gh<_i489.WallOfTheDayRepository>()),
  );
  gh.lazySingleton<_i353.FetchWotdArchiveUseCase>(
    () => _i353.FetchWotdArchiveUseCase(gh<_i489.WallOfTheDayRepository>()),
  );
  gh.lazySingleton<_i563.AutoRotateRepository>(
    () => _i948.AutoRotateRepositoryImpl(
      gh<_i1073.SettingsLocalDataSource>(),
      gh<_i727.PrismWallpaperRepository>(),
      gh<_i489.WallOfTheDayRepository>(),
      gh<_i121.WallpaperHistoryStore>(),
    ),
  );
  gh.factory<_i872.PersonalizedFeedBloc>(
    () => _i872.PersonalizedFeedBloc(
      gh<_i212.FetchPersonalizedFeedUseCase>(),
      gh<_i567.PersonalizedFeedRepository>(),
      gh<_i112.UserBlockRepository>(),
    ),
  );
  gh.factory<_i408.AutoRotateBloc>(
    () => _i408.AutoRotateBloc(gh<_i563.AutoRotateRepository>()),
  );
  gh.factory<_i183.WotdBloc>(
    () => _i183.WotdBloc(gh<_i398.FetchWallOfTheDayUseCase>()),
  );
  gh.factory<_i71.WotdArchiveBloc>(
    () => _i71.WotdArchiveBloc(gh<_i353.FetchWotdArchiveUseCase>()),
  );
  return getIt;
}

class _$AppModule extends _i212.AppModule {}
