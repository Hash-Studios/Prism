// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:app_links/app_links.dart' as _i327;
import 'package:cloud_firestore/cloud_firestore.dart' as _i974;
import 'package:firebase_auth/firebase_auth.dart' as _i59;
import 'package:firebase_remote_config/firebase_remote_config.dart' as _i627;
import 'package:get_it/get_it.dart' as _i174;
import 'package:http/http.dart' as _i519;
import 'package:injectable/injectable.dart' as _i526;
import 'package:internet_connection_checker/internet_connection_checker.dart'
    as _i973;
import 'package:quick_actions/quick_actions.dart' as _i578;

import '../../features/admin_review/biz/bloc/review_batch_bloc.dart' as _i711;
import '../../features/admin_review/data/review_batch_repository.dart' as _i122;
import '../../features/ads/biz/bloc/ads_bloc.j.dart' as _i567;
import '../../features/ads/data/repositories/ads_repository_impl.dart' as _i418;
import '../../features/ads/domain/repositories/ads_repository.dart' as _i1055;
import '../../features/ads/domain/usecases/ads_usecases.dart' as _i321;
import '../../features/category_feed/biz/bloc/category_feed_bloc.j.dart'
    as _i195;
import '../../features/category_feed/data/repositories/category_feed_repository_impl.dart'
    as _i307;
import '../../features/category_feed/domain/repositories/category_feed_repository.dart'
    as _i563;
import '../../features/category_feed/domain/usecases/category_feed_usecases.dart'
    as _i301;
import '../../features/connectivity/biz/bloc/connectivity_bloc.j.dart' as _i301;
import '../../features/connectivity/data/repositories/connectivity_repository_impl.dart'
    as _i657;
import '../../features/connectivity/domain/repositories/connectivity_repository.dart'
    as _i325;
import '../../features/connectivity/domain/usecases/connectivity_usecases.dart'
    as _i410;
import '../../features/deep_link/biz/bloc/deep_link_bloc.j.dart' as _i739;
import '../../features/deep_link/data/repositories/deep_link_repository_impl.dart'
    as _i857;
import '../../features/deep_link/domain/repositories/deep_link_repository.dart'
    as _i226;
import '../../features/deep_link/domain/usecases/deep_link_usecases.dart'
    as _i663;
import '../../features/favourite_setups/biz/bloc/favourite_setups_bloc.j.dart'
    as _i704;
import '../../features/favourite_setups/data/repositories/favourite_setups_repository_impl.dart'
    as _i934;
import '../../features/favourite_setups/domain/repositories/favourite_setups_repository.dart'
    as _i841;
import '../../features/favourite_setups/domain/usecases/favourite_setups_usecases.dart'
    as _i340;
import '../../features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart'
    as _i782;
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
import '../../features/palette/biz/bloc/palette_bloc.j.dart' as _i689;
import '../../features/palette/data/repositories/palette_repository_impl.dart'
    as _i401;
import '../../features/palette/domain/bloc/wallpaper_detail_bloc.dart' as _i358;
import '../../features/palette/domain/repositories/palette_repository.dart'
    as _i1019;
import '../../features/palette/domain/usecases/generate_palette_usecase.dart'
    as _i576;
import '../../features/palette/palette.dart' as _i806;
import '../../features/personalized_feed/biz/bloc/personalized_feed_bloc.j.dart'
    as _i872;
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
import '../../features/prism_feed/data/repositories/prism_wallpaper_repository_impl.dart'
    as _i759;
import '../../features/prism_feed/domain/repositories/prism_wallpaper_repository.dart'
    as _i727;
import '../../features/profile_setups/biz/bloc/profile_setups_bloc.j.dart'
    as _i941;
import '../../features/profile_setups/data/repositories/profile_setups_repository_impl.dart'
    as _i983;
import '../../features/profile_setups/domain/repositories/profile_setups_repository.dart'
    as _i563;
import '../../features/profile_setups/domain/usecases/profile_setups_usecases.dart'
    as _i272;
import '../../features/public_profile/biz/bloc/public_profile_bloc.j.dart'
    as _i717;
import '../../features/public_profile/data/repositories/public_profile_repository_impl.dart'
    as _i769;
import '../../features/public_profile/domain/repositories/public_profile_repository.dart'
    as _i817;
import '../../features/public_profile/domain/usecases/public_profile_usecases.dart'
    as _i446;
import '../../features/quick_actions/biz/bloc/quick_actions_bloc.j.dart'
    as _i1055;
import '../../features/quick_actions/data/repositories/quick_actions_repository_impl.dart'
    as _i207;
import '../../features/quick_actions/domain/repositories/quick_actions_repository.dart'
    as _i865;
import '../../features/quick_actions/domain/usecases/quick_actions_usecases.dart'
    as _i108;
import '../../features/session/biz/bloc/session_bloc.j.dart' as _i364;
import '../../features/session/data/repositories/session_repository_impl.dart'
    as _i1021;
import '../../features/session/domain/repositories/session_repository.dart'
    as _i738;
import '../../features/session/domain/usecases/session_usecases.dart' as _i986;
import '../../features/setups/biz/bloc/setups_bloc.j.dart' as _i318;
import '../../features/setups/data/repositories/setups_repository_impl.dart'
    as _i415;
import '../../features/setups/domain/repositories/setups_repository.dart'
    as _i411;
import '../../features/setups/domain/usecases/setups_usecases.dart' as _i247;
import '../../features/startup/biz/bloc/startup_bloc.j.dart' as _i313;
import '../../features/startup/data/repositories/startup_repository_impl.dart'
    as _i152;
import '../../features/startup/domain/repositories/startup_repository.dart'
    as _i721;
import '../../features/startup/domain/usecases/bootstrap_app_usecase.dart'
    as _i415;
import '../../features/streak/bloc/streak_shop_bloc.dart' as _i456;
import '../../features/theme_dark/biz/bloc/theme_dark_bloc.j.dart' as _i97;
import '../../features/theme_dark/domain/usecases/theme_dark_usecases.dart'
    as _i96;
import '../../features/theme_light/biz/bloc/theme_light_bloc.j.dart' as _i716;
import '../../features/theme_light/data/repositories/theme_repository_impl.dart'
    as _i404;
import '../../features/theme_light/domain/repositories/theme_repository.dart'
    as _i425;
import '../../features/theme_light/domain/usecases/theme_light_usecases.dart'
    as _i518;
import '../../features/theme_mode/biz/bloc/theme_mode_bloc.j.dart' as _i736;
import '../../features/theme_mode/domain/usecases/theme_mode_usecases.dart'
    as _i836;
import '../../features/user_search/biz/bloc/search_discovery_bloc.j.dart'
    as _i39;
import '../../features/user_search/biz/bloc/user_search_bloc.j.dart' as _i733;
import '../../features/user_search/data/repositories/user_search_repository_impl.dart'
    as _i352;
import '../../features/user_search/domain/repositories/user_search_repository.dart'
    as _i204;
import '../../features/user_search/domain/usecases/search_users_usecase.dart'
    as _i750;
import '../../features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart' as _i183;
import '../../features/wall_of_the_day/data/repositories/wall_of_the_day_repository_impl.dart'
    as _i1070;
import '../../features/wall_of_the_day/domain/repositories/wall_of_the_day_repository.dart'
    as _i489;
import '../../features/wall_of_the_day/domain/usecases/fetch_wall_of_the_day_usecase.dart'
    as _i398;
import '../../features/wallhaven_feed/data/repositories/wallhaven_wallpaper_repository_impl.dart'
    as _i387;
import '../../features/wallhaven_feed/domain/repositories/wallhaven_wallpaper_repository.dart'
    as _i604;
import '../../features/wallpaper_detail/domain/usecases/wallpaper_views_usecase.dart'
    as _i231;
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
  gh.lazySingleton<_i59.FirebaseAuth>(() => appModule.firebaseAuth);
  gh.lazySingleton<_i327.AppLinks>(() => appModule.appLinks);
  gh.lazySingleton<_i627.FirebaseRemoteConfig>(() => appModule.remoteConfig);
  gh.lazySingleton<_i973.InternetConnectionChecker>(
    () => appModule.internetConnectionChecker,
  );
  gh.lazySingleton<_i578.QuickActions>(() => appModule.quickActions);
  gh.lazySingleton<_i496.LocalStore>(() => appModule.localStore);
  gh.lazySingleton<_i519.Client>(() => appModule.httpClient);
  gh.lazySingleton<_i1003.AppIconsLocalDataSource>(
    () => _i1003.AppIconsLocalDataSource(),
  );
  gh.lazySingleton<_i954.FeedCacheLocalDataSource>(
    () => _i954.FeedCacheLocalDataSource(),
  );
  gh.lazySingleton<_i231.FetchWallpaperViewsUsecase>(
    () => const _i231.FetchWallpaperViewsUsecase(),
  );
  gh.lazySingleton<_i231.UpdateWallpaperViewsUsecase>(
    () => const _i231.UpdateWallpaperViewsUsecase(),
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
  gh.lazySingleton<_i1055.AdsRepository>(() => _i418.AdsRepositoryImpl());
  gh.lazySingleton<_i604.WallhavenWallpaperRepository>(
    () => _i387.WallhavenWallpaperRepositoryImpl(
      gh<_i954.FeedCacheLocalDataSource>(),
    ),
  );
  gh.lazySingleton<_i312.PexelsWallpaperRepository>(
    () => _i914.PexelsWallpaperRepositoryImpl(
      gh<_i954.FeedCacheLocalDataSource>(),
    ),
  );
  gh.factory<_i39.SearchDiscoveryBloc>(
    () => _i39.SearchDiscoveryBloc(gh<_i604.WallhavenWallpaperRepository>()),
  );
  gh.lazySingleton<_i1019.PaletteRepository>(
    () => _i401.PaletteRepositoryImpl(),
  );
  gh.lazySingleton<_i226.DeepLinkRepository>(
    () => _i857.DeepLinkRepositoryImpl(gh<_i327.AppLinks>()),
    dispose: (i) => i.dispose(),
  );
  gh.lazySingleton<_i349.FirestoreClient>(
    () => appModule.firestoreClient(
      gh<_i974.FirebaseFirestore>(),
      gh<_i393.FirestoreTelemetrySink>(),
    ),
  );
  gh.lazySingleton<_i643.FavouriteWallsRepository>(
    () => _i176.FavouriteWallsRepositoryImpl(
      gh<_i349.FirestoreClient>(),
      gh<_i640.FavoritesLocalDataSource>(),
    ),
  );
  gh.lazySingleton<_i727.PrismWallpaperRepository>(
    () => _i759.PrismWallpaperRepositoryImpl(
      gh<_i349.FirestoreClient>(),
      gh<_i954.FeedCacheLocalDataSource>(),
    ),
  );
  gh.lazySingleton<_i366.NotificationsRepository>(
    () => _i1017.NotificationsRepositoryImpl(
      gh<_i290.NotificationsLocalDataSource>(),
    ),
  );
  gh.lazySingleton<_i576.GeneratePaletteUseCase>(
    () => _i576.GeneratePaletteUseCase(gh<_i1019.PaletteRepository>()),
  );
  gh.lazySingleton<_i601.CacheMaintenanceService>(
    () => _i601.CacheMaintenanceService(
      gh<_i290.NotificationsLocalDataSource>(),
      gh<_i954.FeedCacheLocalDataSource>(),
      gh<_i1003.AppIconsLocalDataSource>(),
    ),
  );
  gh.lazySingleton<_i321.CreateRewardedAdUseCase>(
    () => _i321.CreateRewardedAdUseCase(gh<_i1055.AdsRepository>()),
  );
  gh.lazySingleton<_i321.AddRewardUseCase>(
    () => _i321.AddRewardUseCase(gh<_i1055.AdsRepository>()),
  );
  gh.lazySingleton<_i321.ShowRewardedAdUseCase>(
    () => _i321.ShowRewardedAdUseCase(gh<_i1055.AdsRepository>()),
  );
  gh.lazySingleton<_i321.ResetAdsUseCase>(
    () => _i321.ResetAdsUseCase(gh<_i1055.AdsRepository>()),
  );
  gh.lazySingleton<_i406.FetchFavouriteWallsUseCase>(
    () =>
        _i406.FetchFavouriteWallsUseCase(gh<_i643.FavouriteWallsRepository>()),
  );
  gh.lazySingleton<_i406.ToggleFavouriteWallUseCase>(
    () =>
        _i406.ToggleFavouriteWallUseCase(gh<_i643.FavouriteWallsRepository>()),
  );
  gh.lazySingleton<_i406.RemoveFavouriteWallUseCase>(
    () =>
        _i406.RemoveFavouriteWallUseCase(gh<_i643.FavouriteWallsRepository>()),
  );
  gh.lazySingleton<_i406.ClearFavouriteWallsUseCase>(
    () =>
        _i406.ClearFavouriteWallsUseCase(gh<_i643.FavouriteWallsRepository>()),
  );
  gh.lazySingleton<_i841.FavouriteSetupsRepository>(
    () => _i934.FavouriteSetupsRepositoryImpl(
      gh<_i349.FirestoreClient>(),
      gh<_i640.FavoritesLocalDataSource>(),
    ),
  );
  gh.lazySingleton<_i865.QuickActionsRepository>(
    () => _i207.QuickActionsRepositoryImpl(gh<_i578.QuickActions>()),
  );
  gh.lazySingleton<_i425.ThemeRepository>(
    () => _i404.ThemeRepositoryImpl(gh<_i1073.SettingsLocalDataSource>()),
  );
  gh.lazySingleton<_i721.StartupRepository>(
    () => _i152.StartupRepositoryImpl(gh<_i1073.SettingsLocalDataSource>()),
  );
  gh.lazySingleton<_i411.SetupsRepository>(
    () => _i415.SetupsRepositoryImpl(
      gh<_i349.FirestoreClient>(),
      gh<_i954.FeedCacheLocalDataSource>(),
    ),
  );
  gh.lazySingleton<_i491.ConnectivityService>(
    () => _i491.InternetConnectivityService(
      gh<_i973.InternetConnectionChecker>(),
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
  gh.lazySingleton<_i738.SessionRepository>(
    () => _i1021.SessionRepositoryImpl(gh<_i704.SessionLocalDataSource>()),
  );
  gh.factory<_i782.FavouriteWallsBloc>(
    () => _i782.FavouriteWallsBloc(
      gh<_i406.FetchFavouriteWallsUseCase>(),
      gh<_i406.ToggleFavouriteWallUseCase>(),
      gh<_i406.RemoveFavouriteWallUseCase>(),
      gh<_i406.ClearFavouriteWallsUseCase>(),
    ),
  );
  gh.lazySingleton<_i689.PaletteBloc>(
    () => _i689.PaletteBloc(gh<_i576.GeneratePaletteUseCase>()),
  );
  gh.lazySingleton<_i301.LoadCategoriesUseCase>(
    () => _i301.LoadCategoriesUseCase(gh<_i563.CategoryFeedRepository>()),
  );
  gh.lazySingleton<_i301.FetchCategoryFeedUseCase>(
    () => _i301.FetchCategoryFeedUseCase(gh<_i563.CategoryFeedRepository>()),
  );
  gh.lazySingleton<_i663.GetInitialDeepLinkActionUseCase>(
    () => _i663.GetInitialDeepLinkActionUseCase(gh<_i226.DeepLinkRepository>()),
  );
  gh.lazySingleton<_i663.ObserveDeepLinkActionsUseCase>(
    () => _i663.ObserveDeepLinkActionsUseCase(gh<_i226.DeepLinkRepository>()),
  );
  gh.lazySingleton<_i204.UserSearchRepository>(
    () => _i352.UserSearchRepositoryImpl(gh<_i349.FirestoreClient>()),
  );
  gh.lazySingleton<_i563.ProfileSetupsRepository>(
    () => _i983.ProfileSetupsRepositoryImpl(gh<_i349.FirestoreClient>()),
  );
  gh.lazySingleton<_i817.PublicProfileRepository>(
    () => _i769.PublicProfileRepositoryImpl(gh<_i349.FirestoreClient>()),
  );
  gh.lazySingleton<_i986.GetSessionUseCase>(
    () => _i986.GetSessionUseCase(gh<_i738.SessionRepository>()),
  );
  gh.lazySingleton<_i986.RefreshPremiumUseCase>(
    () => _i986.RefreshPremiumUseCase(gh<_i738.SessionRepository>()),
  );
  gh.lazySingleton<_i986.SignOutUseCase>(
    () => _i986.SignOutUseCase(gh<_i738.SessionRepository>()),
  );
  gh.lazySingleton<_i897.OnboardingV2Repository>(
    () => _i794.OnboardingV2RepositoryImpl(
      gh<_i627.FirebaseRemoteConfig>(),
      gh<_i349.FirestoreClient>(),
      gh<_i1073.SettingsLocalDataSource>(),
    ),
  );
  gh.lazySingleton<_i340.FetchFavouriteSetupsUseCase>(
    () => _i340.FetchFavouriteSetupsUseCase(
      gh<_i841.FavouriteSetupsRepository>(),
    ),
  );
  gh.lazySingleton<_i340.ToggleFavouriteSetupUseCase>(
    () => _i340.ToggleFavouriteSetupUseCase(
      gh<_i841.FavouriteSetupsRepository>(),
    ),
  );
  gh.lazySingleton<_i340.RemoveFavouriteSetupUseCase>(
    () => _i340.RemoveFavouriteSetupUseCase(
      gh<_i841.FavouriteSetupsRepository>(),
    ),
  );
  gh.lazySingleton<_i340.ClearFavouriteSetupsUseCase>(
    () => _i340.ClearFavouriteSetupsUseCase(
      gh<_i841.FavouriteSetupsRepository>(),
    ),
  );
  gh.factory<_i358.WallpaperDetailBloc>(
    () => _i358.WallpaperDetailBloc(
      gh<_i727.PrismWallpaperRepository>(),
      gh<_i604.WallhavenWallpaperRepository>(),
      gh<_i312.PexelsWallpaperRepository>(),
      gh<_i231.FetchWallpaperViewsUsecase>(),
      gh<_i231.UpdateWallpaperViewsUsecase>(),
      gh<_i806.PaletteBloc>(),
    ),
  );
  gh.factory<_i456.StreakShopBloc>(
    () => _i456.StreakShopBloc(gh<_i727.PrismWallpaperRepository>()),
  );
  gh.lazySingleton<_i122.ReviewBatchRepository>(
    () => _i122.ReviewBatchRepository(gh<_i349.FirestoreClient>()),
  );
  gh.lazySingleton<_i446.FetchPublicProfileUseCase>(
    () => _i446.FetchPublicProfileUseCase(gh<_i817.PublicProfileRepository>()),
  );
  gh.lazySingleton<_i446.FetchPublicProfileWallsUseCase>(
    () => _i446.FetchPublicProfileWallsUseCase(
      gh<_i817.PublicProfileRepository>(),
    ),
  );
  gh.lazySingleton<_i446.FetchPublicProfileSetupsUseCase>(
    () => _i446.FetchPublicProfileSetupsUseCase(
      gh<_i817.PublicProfileRepository>(),
    ),
  );
  gh.lazySingleton<_i446.FollowUserUseCase>(
    () => _i446.FollowUserUseCase(gh<_i817.PublicProfileRepository>()),
  );
  gh.lazySingleton<_i446.UnfollowUserUseCase>(
    () => _i446.UnfollowUserUseCase(gh<_i817.PublicProfileRepository>()),
  );
  gh.lazySingleton<_i446.UpdatePublicProfileLinksUseCase>(
    () => _i446.UpdatePublicProfileLinksUseCase(
      gh<_i817.PublicProfileRepository>(),
    ),
  );
  gh.lazySingleton<_i446.FetchUserSummariesUseCase>(
    () => _i446.FetchUserSummariesUseCase(gh<_i817.PublicProfileRepository>()),
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
  gh.lazySingleton<_i567.PersonalizedFeedRepository>(
    () => _i903.PersonalizedFeedRepositoryImpl(
      gh<_i349.FirestoreClient>(),
      gh<_i954.FeedCacheLocalDataSource>(),
      gh<_i1073.SettingsLocalDataSource>(),
      gh<_i604.WallhavenWallpaperRepository>(),
      gh<_i312.PexelsWallpaperRepository>(),
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
  gh.lazySingleton<_i489.WallOfTheDayRepository>(
    () => _i1070.WallOfTheDayRepositoryImpl(gh<_i349.FirestoreClient>()),
  );
  gh.lazySingleton<_i247.FetchSetupsUseCase>(
    () => _i247.FetchSetupsUseCase(gh<_i411.SetupsRepository>()),
  );
  gh.lazySingleton<_i502.FirstWallpaperService>(
    () => _i502.FirstWallpaperService(
      gh<_i563.CategoryFeedRepository>(),
      gh<_i489.WallOfTheDayRepository>(),
    ),
  );
  gh.factory<_i195.CategoryFeedBloc>(
    () => _i195.CategoryFeedBloc(
      gh<_i301.LoadCategoriesUseCase>(),
      gh<_i301.FetchCategoryFeedUseCase>(),
    ),
  );
  gh.lazySingleton<_i272.FetchProfileSetupsUseCase>(
    () => _i272.FetchProfileSetupsUseCase(gh<_i563.ProfileSetupsRepository>()),
  );
  gh.factory<_i739.DeepLinkBloc>(
    () => _i739.DeepLinkBloc(
      gh<_i663.GetInitialDeepLinkActionUseCase>(),
      gh<_i663.ObserveDeepLinkActionsUseCase>(),
    ),
  );
  gh.lazySingleton<_i415.BootstrapAppUseCase>(
    () => _i415.BootstrapAppUseCase(gh<_i721.StartupRepository>()),
  );
  gh.lazySingleton<_i108.InitializeQuickActionsUseCase>(
    () =>
        _i108.InitializeQuickActionsUseCase(gh<_i865.QuickActionsRepository>()),
  );
  gh.lazySingleton<_i108.SetQuickActionShortcutsUseCase>(
    () => _i108.SetQuickActionShortcutsUseCase(
      gh<_i865.QuickActionsRepository>(),
    ),
  );
  gh.lazySingleton<_i108.ObserveQuickActionsUseCase>(
    () => _i108.ObserveQuickActionsUseCase(gh<_i865.QuickActionsRepository>()),
  );
  gh.lazySingleton<_i750.SearchUsersUseCase>(
    () => _i750.SearchUsersUseCase(gh<_i204.UserSearchRepository>()),
  );
  gh.factory<_i567.AdsBloc>(
    () => _i567.AdsBloc(
      gh<_i321.CreateRewardedAdUseCase>(),
      gh<_i321.ShowRewardedAdUseCase>(),
      gh<_i321.AddRewardUseCase>(),
      gh<_i321.ResetAdsUseCase>(),
    ),
  );
  gh.lazySingleton<_i96.LoadThemeDarkUseCase>(
    () => _i96.LoadThemeDarkUseCase(gh<_i425.ThemeRepository>()),
  );
  gh.lazySingleton<_i96.UpdateThemeDarkUseCase>(
    () => _i96.UpdateThemeDarkUseCase(gh<_i425.ThemeRepository>()),
  );
  gh.lazySingleton<_i96.UpdateThemeDarkAccentUseCase>(
    () => _i96.UpdateThemeDarkAccentUseCase(gh<_i425.ThemeRepository>()),
  );
  gh.lazySingleton<_i518.LoadThemeLightUseCase>(
    () => _i518.LoadThemeLightUseCase(gh<_i425.ThemeRepository>()),
  );
  gh.lazySingleton<_i518.UpdateThemeLightUseCase>(
    () => _i518.UpdateThemeLightUseCase(gh<_i425.ThemeRepository>()),
  );
  gh.lazySingleton<_i518.UpdateThemeLightAccentUseCase>(
    () => _i518.UpdateThemeLightAccentUseCase(gh<_i425.ThemeRepository>()),
  );
  gh.lazySingleton<_i836.LoadThemeModeUseCase>(
    () => _i836.LoadThemeModeUseCase(gh<_i425.ThemeRepository>()),
  );
  gh.lazySingleton<_i836.UpdateThemeModeUseCase>(
    () => _i836.UpdateThemeModeUseCase(gh<_i425.ThemeRepository>()),
  );
  gh.lazySingleton<_i325.ConnectivityRepository>(
    () => _i657.ConnectivityRepositoryImpl(gh<_i491.ConnectivityService>()),
  );
  gh.factory<_i717.PublicProfileBloc>(
    () => _i717.PublicProfileBloc(
      gh<_i446.FetchPublicProfileUseCase>(),
      gh<_i446.FetchPublicProfileWallsUseCase>(),
      gh<_i446.FetchPublicProfileSetupsUseCase>(),
      gh<_i446.FollowUserUseCase>(),
      gh<_i446.UnfollowUserUseCase>(),
      gh<_i446.UpdatePublicProfileLinksUseCase>(),
      gh<_i446.FetchUserSummariesPageUseCase>(),
      gh<_i446.SearchUsersByUsernameUseCase>(),
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
  gh.factory<_i716.ThemeLightBloc>(
    () => _i716.ThemeLightBloc(
      gh<_i518.LoadThemeLightUseCase>(),
      gh<_i518.UpdateThemeLightUseCase>(),
      gh<_i518.UpdateThemeLightAccentUseCase>(),
    ),
  );
  gh.factory<_i704.FavouriteSetupsBloc>(
    () => _i704.FavouriteSetupsBloc(
      gh<_i340.FetchFavouriteSetupsUseCase>(),
      gh<_i340.ToggleFavouriteSetupUseCase>(),
      gh<_i340.RemoveFavouriteSetupUseCase>(),
      gh<_i340.ClearFavouriteSetupsUseCase>(),
    ),
  );
  gh.lazySingleton<_i212.GetPersistedSeenKeysUseCase>(
    () => _i212.GetPersistedSeenKeysUseCase(
      gh<_i567.PersonalizedFeedRepository>(),
    ),
  );
  gh.lazySingleton<_i212.FetchPersonalizedFeedUseCase>(
    () => _i212.FetchPersonalizedFeedUseCase(
      gh<_i567.PersonalizedFeedRepository>(),
    ),
  );
  gh.factory<_i1055.QuickActionsBloc>(
    () => _i1055.QuickActionsBloc(
      gh<_i108.InitializeQuickActionsUseCase>(),
      gh<_i108.SetQuickActionShortcutsUseCase>(),
      gh<_i108.ObserveQuickActionsUseCase>(),
    ),
  );
  gh.factory<_i872.PersonalizedFeedBloc>(
    () => _i872.PersonalizedFeedBloc(
      gh<_i212.FetchPersonalizedFeedUseCase>(),
      gh<_i212.GetPersistedSeenKeysUseCase>(),
    ),
  );
  gh.factory<_i364.SessionBloc>(
    () => _i364.SessionBloc(
      gh<_i986.GetSessionUseCase>(),
      gh<_i986.RefreshPremiumUseCase>(),
      gh<_i986.SignOutUseCase>(),
      sessionRepository: gh<_i738.SessionRepository>(),
    ),
  );
  gh.factory<_i318.SetupsBloc>(
    () => _i318.SetupsBloc(gh<_i247.FetchSetupsUseCase>()),
  );
  gh.factory<_i97.ThemeDarkBloc>(
    () => _i97.ThemeDarkBloc(
      gh<_i96.LoadThemeDarkUseCase>(),
      gh<_i96.UpdateThemeDarkUseCase>(),
      gh<_i96.UpdateThemeDarkAccentUseCase>(),
    ),
  );
  gh.factory<_i584.InAppNotificationsBloc>(
    () => _i584.InAppNotificationsBloc(
      gh<_i474.FetchNotificationsUseCase>(),
      gh<_i474.MarkNotificationAsReadUseCase>(),
      gh<_i474.DeleteNotificationUseCase>(),
      gh<_i474.ClearNotificationsUseCase>(),
    ),
  );
  gh.factory<_i941.ProfileSetupsBloc>(
    () => _i941.ProfileSetupsBloc(gh<_i272.FetchProfileSetupsUseCase>()),
  );
  gh.factory<_i313.StartupBloc>(
    () => _i313.StartupBloc(gh<_i415.BootstrapAppUseCase>()),
  );
  gh.factory<_i733.UserSearchBloc>(
    () => _i733.UserSearchBloc(gh<_i750.SearchUsersUseCase>()),
  );
  gh.lazySingleton<_i398.FetchWallOfTheDayUseCase>(
    () => _i398.FetchWallOfTheDayUseCase(gh<_i489.WallOfTheDayRepository>()),
  );
  gh.factory<_i711.ReviewBatchBloc>(
    () => _i711.ReviewBatchBloc(gh<_i122.ReviewBatchRepository>()),
  );
  gh.lazySingleton<_i410.CheckConnectionUseCase>(
    () => _i410.CheckConnectionUseCase(gh<_i325.ConnectivityRepository>()),
  );
  gh.lazySingleton<_i410.WatchConnectionUseCase>(
    () => _i410.WatchConnectionUseCase(gh<_i325.ConnectivityRepository>()),
  );
  gh.factory<_i736.ThemeModeBloc>(
    () => _i736.ThemeModeBloc(
      gh<_i836.LoadThemeModeUseCase>(),
      gh<_i836.UpdateThemeModeUseCase>(),
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
    ),
  );
  gh.factory<_i301.ConnectivityBloc>(
    () => _i301.ConnectivityBloc(
      gh<_i410.CheckConnectionUseCase>(),
      gh<_i410.WatchConnectionUseCase>(),
    ),
  );
  gh.factory<_i183.WotdBloc>(
    () => _i183.WotdBloc(gh<_i398.FetchWallOfTheDayUseCase>()),
  );
  return getIt;
}

class _$AppModule extends _i212.AppModule {}
