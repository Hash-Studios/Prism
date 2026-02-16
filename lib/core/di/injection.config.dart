// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:cloud_firestore/cloud_firestore.dart' as _i974;
import 'package:firebase_auth/firebase_auth.dart' as _i59;
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart' as _i538;
import 'package:firebase_remote_config/firebase_remote_config.dart' as _i627;
import 'package:get_it/get_it.dart' as _i174;
import 'package:hive/hive.dart' as _i979;
import 'package:injectable/injectable.dart' as _i526;
import 'package:internet_connection_checker/internet_connection_checker.dart' as _i973;
import 'package:quick_actions/quick_actions.dart' as _i578;

import '../../data/notifications/model/inAppNotifModel.dart' as _i1047;
import '../../features/ads/data/repositories/ads_repository_impl.dart' as _i418;
import '../../features/ads/domain/repositories/ads_repository.dart' as _i1055;
import '../../features/ads/domain/usecases/ads_usecases.dart' as _i321;
import '../../features/ads/presentation/bloc/ads_bloc.dart' as _i810;
import '../../features/category_feed/data/repositories/category_feed_repository_impl.dart' as _i307;
import '../../features/category_feed/domain/repositories/category_feed_repository.dart' as _i563;
import '../../features/category_feed/domain/usecases/category_feed_usecases.dart' as _i301;
import '../../features/category_feed/presentation/bloc/category_feed_bloc.dart' as _i130;
import '../../features/connectivity/data/repositories/connectivity_repository_impl.dart' as _i657;
import '../../features/connectivity/domain/repositories/connectivity_repository.dart' as _i325;
import '../../features/connectivity/domain/usecases/connectivity_usecases.dart' as _i410;
import '../../features/connectivity/presentation/bloc/connectivity_bloc.dart' as _i78;
import '../../features/deep_link/data/repositories/deep_link_repository_impl.dart' as _i857;
import '../../features/deep_link/domain/repositories/deep_link_repository.dart' as _i226;
import '../../features/deep_link/domain/usecases/deep_link_usecases.dart' as _i663;
import '../../features/deep_link/presentation/bloc/deep_link_bloc.dart' as _i687;
import '../../features/favourite_setups/data/repositories/favourite_setups_repository_impl.dart' as _i934;
import '../../features/favourite_setups/domain/repositories/favourite_setups_repository.dart' as _i841;
import '../../features/favourite_setups/domain/usecases/favourite_setups_usecases.dart' as _i340;
import '../../features/favourite_setups/presentation/bloc/favourite_setups_bloc.dart' as _i826;
import '../../features/favourite_walls/data/repositories/favourite_walls_repository_impl.dart' as _i176;
import '../../features/favourite_walls/domain/repositories/favourite_walls_repository.dart' as _i643;
import '../../features/favourite_walls/domain/usecases/favourite_walls_usecases.dart' as _i406;
import '../../features/favourite_walls/presentation/bloc/favourite_walls_bloc.dart' as _i526;
import '../../features/in_app_notifications/data/repositories/notifications_repository_impl.dart' as _i1017;
import '../../features/in_app_notifications/domain/repositories/notifications_repository.dart' as _i366;
import '../../features/in_app_notifications/domain/usecases/notifications_usecases.dart' as _i474;
import '../../features/in_app_notifications/presentation/bloc/in_app_notifications_bloc.dart' as _i116;
import '../../features/navigation/data/repositories/navigation_repository_impl.dart' as _i69;
import '../../features/navigation/domain/repositories/navigation_repository.dart' as _i647;
import '../../features/navigation/domain/usecases/navigation_usecases.dart' as _i294;
import '../../features/navigation/presentation/bloc/navigation_bloc.dart' as _i162;
import '../../features/palette/data/repositories/palette_repository_impl.dart' as _i401;
import '../../features/palette/domain/repositories/palette_repository.dart' as _i1019;
import '../../features/palette/domain/usecases/generate_palette_usecase.dart' as _i576;
import '../../features/palette/presentation/bloc/palette_bloc.dart' as _i627;
import '../../features/profile_setups/data/repositories/profile_setups_repository_impl.dart' as _i983;
import '../../features/profile_setups/domain/repositories/profile_setups_repository.dart' as _i563;
import '../../features/profile_setups/domain/usecases/profile_setups_usecases.dart' as _i272;
import '../../features/profile_setups/presentation/bloc/profile_setups_bloc.dart' as _i204;
import '../../features/profile_walls/data/repositories/profile_walls_repository_impl.dart' as _i409;
import '../../features/profile_walls/domain/repositories/profile_walls_repository.dart' as _i668;
import '../../features/profile_walls/domain/usecases/profile_walls_usecases.dart' as _i58;
import '../../features/profile_walls/presentation/bloc/profile_walls_bloc.dart' as _i1031;
import '../../features/public_profile/data/repositories/public_profile_repository_impl.dart' as _i769;
import '../../features/public_profile/domain/repositories/public_profile_repository.dart' as _i817;
import '../../features/public_profile/domain/usecases/public_profile_usecases.dart' as _i446;
import '../../features/public_profile/presentation/bloc/public_profile_bloc.dart' as _i57;
import '../../features/quick_actions/data/repositories/quick_actions_repository_impl.dart' as _i207;
import '../../features/quick_actions/domain/repositories/quick_actions_repository.dart' as _i865;
import '../../features/quick_actions/domain/usecases/quick_actions_usecases.dart' as _i108;
import '../../features/quick_actions/presentation/bloc/quick_actions_bloc.dart' as _i955;
import '../../features/session/data/repositories/session_repository_impl.dart' as _i1021;
import '../../features/session/domain/repositories/session_repository.dart' as _i738;
import '../../features/session/domain/usecases/session_usecases.dart' as _i986;
import '../../features/session/presentation/bloc/session_bloc.dart' as _i844;
import '../../features/setups/data/repositories/setups_repository_impl.dart' as _i415;
import '../../features/setups/domain/repositories/setups_repository.dart' as _i411;
import '../../features/setups/domain/usecases/setups_usecases.dart' as _i247;
import '../../features/setups/presentation/bloc/setups_bloc.dart' as _i868;
import '../../features/startup/data/repositories/startup_repository_impl.dart' as _i152;
import '../../features/startup/domain/repositories/startup_repository.dart' as _i721;
import '../../features/startup/domain/usecases/bootstrap_app_usecase.dart' as _i415;
import '../../features/startup/presentation/bloc/startup_bloc.dart' as _i509;
import '../../features/theme_dark/domain/usecases/theme_dark_usecases.dart' as _i96;
import '../../features/theme_dark/presentation/bloc/theme_dark_bloc.dart' as _i393;
import '../../features/theme_light/data/repositories/theme_repository_impl.dart' as _i404;
import '../../features/theme_light/domain/repositories/theme_repository.dart' as _i425;
import '../../features/theme_light/domain/usecases/theme_light_usecases.dart' as _i518;
import '../../features/theme_light/presentation/bloc/theme_light_bloc.dart' as _i167;
import '../../features/theme_mode/domain/usecases/theme_mode_usecases.dart' as _i836;
import '../../features/theme_mode/presentation/bloc/theme_mode_bloc.dart' as _i777;
import '../../features/user_search/data/repositories/user_search_repository_impl.dart' as _i352;
import '../../features/user_search/domain/repositories/user_search_repository.dart' as _i204;
import '../../features/user_search/domain/usecases/search_users_usecase.dart' as _i750;
import '../../features/user_search/presentation/bloc/user_search_bloc.dart' as _i830;
import '../network/connectivity_service.dart' as _i491;
import 'injection_module.dart' as _i212;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt initGetIt(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(
    getIt,
    environment,
    environmentFilter,
  );
  final appModule = _$AppModule();
  gh.lazySingleton<_i974.FirebaseFirestore>(() => appModule.firebaseFirestore);
  gh.lazySingleton<_i59.FirebaseAuth>(() => appModule.firebaseAuth);
  gh.lazySingleton<_i538.FirebaseDynamicLinks>(() => appModule.firebaseDynamicLinks);
  gh.lazySingleton<_i627.FirebaseRemoteConfig>(() => appModule.remoteConfig);
  gh.lazySingleton<_i973.InternetConnectionChecker>(() => appModule.internetConnectionChecker);
  gh.lazySingleton<_i578.QuickActions>(() => appModule.quickActions);
  gh.lazySingleton<_i979.Box<_i1047.InAppNotif>>(
    () => appModule.inAppNotificationsBox,
    instanceName: 'inAppNotificationsBox',
  );
  gh.lazySingleton<_i738.SessionRepository>(() => _i1021.SessionRepositoryImpl());
  gh.lazySingleton<_i979.Box<dynamic>>(
    () => appModule.prefsBox,
    instanceName: 'prefsBox',
  );
  gh.lazySingleton<_i721.StartupRepository>(() => _i152.StartupRepositoryImpl(
        gh<_i627.FirebaseRemoteConfig>(),
        gh<_i979.Box<dynamic>>(instanceName: 'prefsBox'),
      ));
  gh.lazySingleton<_i1055.AdsRepository>(() => _i418.AdsRepositoryImpl());
  gh.lazySingleton<_i979.Box<dynamic>>(
    () => appModule.localFavBox,
    instanceName: 'localFavBox',
  );
  gh.lazySingleton<_i986.GetSessionUseCase>(() => _i986.GetSessionUseCase(gh<_i738.SessionRepository>()));
  gh.lazySingleton<_i986.RefreshPremiumUseCase>(() => _i986.RefreshPremiumUseCase(gh<_i738.SessionRepository>()));
  gh.lazySingleton<_i986.SignOutUseCase>(() => _i986.SignOutUseCase(gh<_i738.SessionRepository>()));
  gh.lazySingleton<_i366.NotificationsRepository>(() =>
      _i1017.NotificationsRepositoryImpl(gh<_i979.Box<_i1047.InAppNotif>>(instanceName: 'inAppNotificationsBox')));
  gh.lazySingleton<_i647.NavigationRepository>(() => _i69.NavigationRepositoryImpl());
  gh.lazySingleton<_i226.DeepLinkRepository>(() => _i857.DeepLinkRepositoryImpl(gh<_i538.FirebaseDynamicLinks>()));
  gh.lazySingleton<_i1019.PaletteRepository>(() => _i401.PaletteRepositoryImpl());
  gh.lazySingleton<_i474.FetchNotificationsUseCase>(
      () => _i474.FetchNotificationsUseCase(gh<_i366.NotificationsRepository>()));
  gh.lazySingleton<_i474.MarkNotificationAsReadUseCase>(
      () => _i474.MarkNotificationAsReadUseCase(gh<_i366.NotificationsRepository>()));
  gh.lazySingleton<_i474.DeleteNotificationUseCase>(
      () => _i474.DeleteNotificationUseCase(gh<_i366.NotificationsRepository>()));
  gh.lazySingleton<_i474.ClearNotificationsUseCase>(
      () => _i474.ClearNotificationsUseCase(gh<_i366.NotificationsRepository>()));
  gh.lazySingleton<_i415.BootstrapAppUseCase>(() => _i415.BootstrapAppUseCase(gh<_i721.StartupRepository>()));
  gh.lazySingleton<_i204.UserSearchRepository>(() => _i352.UserSearchRepositoryImpl(gh<_i974.FirebaseFirestore>()));
  gh.factory<_i844.SessionBloc>(() => _i844.SessionBloc(
        gh<_i986.GetSessionUseCase>(),
        gh<_i986.RefreshPremiumUseCase>(),
        gh<_i986.SignOutUseCase>(),
      ));
  gh.lazySingleton<_i643.FavouriteWallsRepository>(() => _i176.FavouriteWallsRepositoryImpl(
        gh<_i974.FirebaseFirestore>(),
        gh<_i979.Box<dynamic>>(instanceName: 'localFavBox'),
      ));
  gh.lazySingleton<_i576.GeneratePaletteUseCase>(() => _i576.GeneratePaletteUseCase(gh<_i1019.PaletteRepository>()));
  gh.lazySingleton<_i425.ThemeRepository>(
      () => _i404.ThemeRepositoryImpl(gh<_i979.Box<dynamic>>(instanceName: 'prefsBox')));
  gh.lazySingleton<_i411.SetupsRepository>(() => _i415.SetupsRepositoryImpl(gh<_i974.FirebaseFirestore>()));
  gh.lazySingleton<_i563.ProfileSetupsRepository>(
      () => _i983.ProfileSetupsRepositoryImpl(gh<_i974.FirebaseFirestore>()));
  gh.lazySingleton<_i817.PublicProfileRepository>(
      () => _i769.PublicProfileRepositoryImpl(gh<_i974.FirebaseFirestore>()));
  gh.lazySingleton<_i321.CreateRewardedAdUseCase>(() => _i321.CreateRewardedAdUseCase(gh<_i1055.AdsRepository>()));
  gh.lazySingleton<_i321.AddRewardUseCase>(() => _i321.AddRewardUseCase(gh<_i1055.AdsRepository>()));
  gh.lazySingleton<_i321.ShowRewardedAdUseCase>(() => _i321.ShowRewardedAdUseCase(gh<_i1055.AdsRepository>()));
  gh.lazySingleton<_i321.ResetAdsUseCase>(() => _i321.ResetAdsUseCase(gh<_i1055.AdsRepository>()));
  gh.lazySingleton<_i406.FetchFavouriteWallsUseCase>(
      () => _i406.FetchFavouriteWallsUseCase(gh<_i643.FavouriteWallsRepository>()));
  gh.lazySingleton<_i406.ToggleFavouriteWallUseCase>(
      () => _i406.ToggleFavouriteWallUseCase(gh<_i643.FavouriteWallsRepository>()));
  gh.lazySingleton<_i406.RemoveFavouriteWallUseCase>(
      () => _i406.RemoveFavouriteWallUseCase(gh<_i643.FavouriteWallsRepository>()));
  gh.lazySingleton<_i406.ClearFavouriteWallsUseCase>(
      () => _i406.ClearFavouriteWallsUseCase(gh<_i643.FavouriteWallsRepository>()));
  gh.lazySingleton<_i841.FavouriteSetupsRepository>(() => _i934.FavouriteSetupsRepositoryImpl(
        gh<_i974.FirebaseFirestore>(),
        gh<_i979.Box<dynamic>>(instanceName: 'localFavBox'),
      ));
  gh.lazySingleton<_i865.QuickActionsRepository>(() => _i207.QuickActionsRepositoryImpl(gh<_i578.QuickActions>()));
  gh.lazySingleton<_i563.CategoryFeedRepository>(
      () => _i307.CategoryFeedRepositoryImpl(gh<_i979.Box<dynamic>>(instanceName: 'prefsBox')));
  gh.lazySingleton<_i668.ProfileWallsRepository>(() => _i409.ProfileWallsRepositoryImpl(gh<_i974.FirebaseFirestore>()));
  gh.lazySingleton<_i491.ConnectivityService>(
      () => _i491.InternetConnectivityService(gh<_i973.InternetConnectionChecker>()));
  gh.factory<_i526.FavouriteWallsBloc>(() => _i526.FavouriteWallsBloc(
        gh<_i406.FetchFavouriteWallsUseCase>(),
        gh<_i406.ToggleFavouriteWallUseCase>(),
        gh<_i406.RemoveFavouriteWallUseCase>(),
        gh<_i406.ClearFavouriteWallsUseCase>(),
      ));
  gh.factory<_i627.PaletteBloc>(() => _i627.PaletteBloc(gh<_i576.GeneratePaletteUseCase>()));
  gh.lazySingleton<_i294.GetNavigationStackUseCase>(
      () => _i294.GetNavigationStackUseCase(gh<_i647.NavigationRepository>()));
  gh.lazySingleton<_i294.PushRouteUseCase>(() => _i294.PushRouteUseCase(gh<_i647.NavigationRepository>()));
  gh.lazySingleton<_i294.PopRouteUseCase>(() => _i294.PopRouteUseCase(gh<_i647.NavigationRepository>()));
  gh.lazySingleton<_i294.ResetNavigationUseCase>(() => _i294.ResetNavigationUseCase(gh<_i647.NavigationRepository>()));
  gh.lazySingleton<_i294.ReplaceNavigationStackUseCase>(
      () => _i294.ReplaceNavigationStackUseCase(gh<_i647.NavigationRepository>()));
  gh.lazySingleton<_i301.LoadCategoriesUseCase>(() => _i301.LoadCategoriesUseCase(gh<_i563.CategoryFeedRepository>()));
  gh.lazySingleton<_i301.FetchCategoryFeedUseCase>(
      () => _i301.FetchCategoryFeedUseCase(gh<_i563.CategoryFeedRepository>()));
  gh.lazySingleton<_i663.GetInitialDeepLinkActionUseCase>(
      () => _i663.GetInitialDeepLinkActionUseCase(gh<_i226.DeepLinkRepository>()));
  gh.lazySingleton<_i663.ObserveDeepLinkActionsUseCase>(
      () => _i663.ObserveDeepLinkActionsUseCase(gh<_i226.DeepLinkRepository>()));
  gh.factory<_i116.InAppNotificationsBloc>(() => _i116.InAppNotificationsBloc(
        gh<_i474.FetchNotificationsUseCase>(),
        gh<_i474.MarkNotificationAsReadUseCase>(),
        gh<_i474.DeleteNotificationUseCase>(),
        gh<_i474.ClearNotificationsUseCase>(),
      ));
  gh.factory<_i509.StartupBloc>(() => _i509.StartupBloc(gh<_i415.BootstrapAppUseCase>()));
  gh.lazySingleton<_i340.FetchFavouriteSetupsUseCase>(
      () => _i340.FetchFavouriteSetupsUseCase(gh<_i841.FavouriteSetupsRepository>()));
  gh.lazySingleton<_i340.ToggleFavouriteSetupUseCase>(
      () => _i340.ToggleFavouriteSetupUseCase(gh<_i841.FavouriteSetupsRepository>()));
  gh.lazySingleton<_i340.RemoveFavouriteSetupUseCase>(
      () => _i340.RemoveFavouriteSetupUseCase(gh<_i841.FavouriteSetupsRepository>()));
  gh.lazySingleton<_i340.ClearFavouriteSetupsUseCase>(
      () => _i340.ClearFavouriteSetupsUseCase(gh<_i841.FavouriteSetupsRepository>()));
  gh.lazySingleton<_i446.FetchPublicProfileUseCase>(
      () => _i446.FetchPublicProfileUseCase(gh<_i817.PublicProfileRepository>()));
  gh.lazySingleton<_i446.FetchPublicProfileWallsUseCase>(
      () => _i446.FetchPublicProfileWallsUseCase(gh<_i817.PublicProfileRepository>()));
  gh.lazySingleton<_i446.FetchPublicProfileSetupsUseCase>(
      () => _i446.FetchPublicProfileSetupsUseCase(gh<_i817.PublicProfileRepository>()));
  gh.lazySingleton<_i446.FollowUserUseCase>(() => _i446.FollowUserUseCase(gh<_i817.PublicProfileRepository>()));
  gh.lazySingleton<_i446.UnfollowUserUseCase>(() => _i446.UnfollowUserUseCase(gh<_i817.PublicProfileRepository>()));
  gh.lazySingleton<_i446.UpdatePublicProfileLinksUseCase>(
      () => _i446.UpdatePublicProfileLinksUseCase(gh<_i817.PublicProfileRepository>()));
  gh.lazySingleton<_i247.FetchSetupsUseCase>(() => _i247.FetchSetupsUseCase(gh<_i411.SetupsRepository>()));
  gh.factory<_i162.NavigationBloc>(() => _i162.NavigationBloc(
        gh<_i294.GetNavigationStackUseCase>(),
        gh<_i294.PushRouteUseCase>(),
        gh<_i294.PopRouteUseCase>(),
        gh<_i294.ResetNavigationUseCase>(),
        gh<_i294.ReplaceNavigationStackUseCase>(),
      ));
  gh.factory<_i130.CategoryFeedBloc>(() => _i130.CategoryFeedBloc(
        gh<_i301.LoadCategoriesUseCase>(),
        gh<_i301.FetchCategoryFeedUseCase>(),
      ));
  gh.lazySingleton<_i272.FetchProfileSetupsUseCase>(
      () => _i272.FetchProfileSetupsUseCase(gh<_i563.ProfileSetupsRepository>()));
  gh.factory<_i687.DeepLinkBloc>(() => _i687.DeepLinkBloc(
        gh<_i663.GetInitialDeepLinkActionUseCase>(),
        gh<_i663.ObserveDeepLinkActionsUseCase>(),
      ));
  gh.lazySingleton<_i108.InitializeQuickActionsUseCase>(
      () => _i108.InitializeQuickActionsUseCase(gh<_i865.QuickActionsRepository>()));
  gh.lazySingleton<_i108.SetQuickActionShortcutsUseCase>(
      () => _i108.SetQuickActionShortcutsUseCase(gh<_i865.QuickActionsRepository>()));
  gh.lazySingleton<_i108.ObserveQuickActionsUseCase>(
      () => _i108.ObserveQuickActionsUseCase(gh<_i865.QuickActionsRepository>()));
  gh.lazySingleton<_i750.SearchUsersUseCase>(() => _i750.SearchUsersUseCase(gh<_i204.UserSearchRepository>()));
  gh.factory<_i810.AdsBloc>(() => _i810.AdsBloc(
        gh<_i321.CreateRewardedAdUseCase>(),
        gh<_i321.ShowRewardedAdUseCase>(),
        gh<_i321.AddRewardUseCase>(),
        gh<_i321.ResetAdsUseCase>(),
      ));
  gh.lazySingleton<_i96.LoadThemeDarkUseCase>(() => _i96.LoadThemeDarkUseCase(gh<_i425.ThemeRepository>()));
  gh.lazySingleton<_i96.UpdateThemeDarkUseCase>(() => _i96.UpdateThemeDarkUseCase(gh<_i425.ThemeRepository>()));
  gh.lazySingleton<_i96.UpdateThemeDarkAccentUseCase>(
      () => _i96.UpdateThemeDarkAccentUseCase(gh<_i425.ThemeRepository>()));
  gh.lazySingleton<_i518.LoadThemeLightUseCase>(() => _i518.LoadThemeLightUseCase(gh<_i425.ThemeRepository>()));
  gh.lazySingleton<_i518.UpdateThemeLightUseCase>(() => _i518.UpdateThemeLightUseCase(gh<_i425.ThemeRepository>()));
  gh.lazySingleton<_i518.UpdateThemeLightAccentUseCase>(
      () => _i518.UpdateThemeLightAccentUseCase(gh<_i425.ThemeRepository>()));
  gh.lazySingleton<_i836.LoadThemeModeUseCase>(() => _i836.LoadThemeModeUseCase(gh<_i425.ThemeRepository>()));
  gh.lazySingleton<_i836.UpdateThemeModeUseCase>(() => _i836.UpdateThemeModeUseCase(gh<_i425.ThemeRepository>()));
  gh.lazySingleton<_i325.ConnectivityRepository>(
      () => _i657.ConnectivityRepositoryImpl(gh<_i491.ConnectivityService>()));
  gh.factory<_i57.PublicProfileBloc>(() => _i57.PublicProfileBloc(
        gh<_i446.FetchPublicProfileUseCase>(),
        gh<_i446.FetchPublicProfileWallsUseCase>(),
        gh<_i446.FetchPublicProfileSetupsUseCase>(),
        gh<_i446.FollowUserUseCase>(),
        gh<_i446.UnfollowUserUseCase>(),
        gh<_i446.UpdatePublicProfileLinksUseCase>(),
      ));
  gh.lazySingleton<_i58.FetchProfileWallsUseCase>(
      () => _i58.FetchProfileWallsUseCase(gh<_i668.ProfileWallsRepository>()));
  gh.factory<_i167.ThemeLightBloc>(() => _i167.ThemeLightBloc(
        gh<_i518.LoadThemeLightUseCase>(),
        gh<_i518.UpdateThemeLightUseCase>(),
        gh<_i518.UpdateThemeLightAccentUseCase>(),
      ));
  gh.factory<_i826.FavouriteSetupsBloc>(() => _i826.FavouriteSetupsBloc(
        gh<_i340.FetchFavouriteSetupsUseCase>(),
        gh<_i340.ToggleFavouriteSetupUseCase>(),
        gh<_i340.RemoveFavouriteSetupUseCase>(),
        gh<_i340.ClearFavouriteSetupsUseCase>(),
      ));
  gh.factory<_i955.QuickActionsBloc>(() => _i955.QuickActionsBloc(
        gh<_i108.InitializeQuickActionsUseCase>(),
        gh<_i108.SetQuickActionShortcutsUseCase>(),
        gh<_i108.ObserveQuickActionsUseCase>(),
      ));
  gh.factory<_i868.SetupsBloc>(() => _i868.SetupsBloc(gh<_i247.FetchSetupsUseCase>()));
  gh.factory<_i393.ThemeDarkBloc>(() => _i393.ThemeDarkBloc(
        gh<_i96.LoadThemeDarkUseCase>(),
        gh<_i96.UpdateThemeDarkUseCase>(),
        gh<_i96.UpdateThemeDarkAccentUseCase>(),
      ));
  gh.factory<_i1031.ProfileWallsBloc>(() => _i1031.ProfileWallsBloc(gh<_i58.FetchProfileWallsUseCase>()));
  gh.factory<_i204.ProfileSetupsBloc>(() => _i204.ProfileSetupsBloc(gh<_i272.FetchProfileSetupsUseCase>()));
  gh.factory<_i830.UserSearchBloc>(() => _i830.UserSearchBloc(gh<_i750.SearchUsersUseCase>()));
  gh.lazySingleton<_i410.CheckConnectionUseCase>(
      () => _i410.CheckConnectionUseCase(gh<_i325.ConnectivityRepository>()));
  gh.lazySingleton<_i410.WatchConnectionUseCase>(
      () => _i410.WatchConnectionUseCase(gh<_i325.ConnectivityRepository>()));
  gh.factory<_i777.ThemeModeBloc>(() => _i777.ThemeModeBloc(
        gh<_i836.LoadThemeModeUseCase>(),
        gh<_i836.UpdateThemeModeUseCase>(),
      ));
  gh.factory<_i78.ConnectivityBloc>(() => _i78.ConnectivityBloc(
        gh<_i410.CheckConnectionUseCase>(),
        gh<_i410.WatchConnectionUseCase>(),
      ));
  return getIt;
}

class _$AppModule extends _i212.AppModule {}
