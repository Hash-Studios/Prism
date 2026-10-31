import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/google_auth.dart' show WrongAccountException;
import 'package:Prism/core/account/delete_account_service.dart';
import 'package:Prism/core/account/reauth_cancelled.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/cache_maintenance_service.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/personalization/personalized_feed_settings.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/state/auth_runtime.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/creator_directory/views/widgets/creator_directory_opt_out_row.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/in_app_notifications/views/widgets/notification_settings_sheet.dart';
import 'package:Prism/features/ios_shortcuts/data/ios_shortcuts_support.dart';
import 'package:Prism/features/ios_widgets/views/widget_guide_sheet.dart';
import 'package:Prism/features/library/views/pages/library_screen.dart' show LibraryTab;
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/features/quick_tiles/data/quick_tile_defaults.dart';
import 'package:Prism/features/session/data/low_data_mode.dart';
import 'package:Prism/features/session/data/report_problem_service.dart' show ReportTrigger;
import 'package:Prism/features/session/data/shake_to_report.dart';
import 'package:Prism/features/session/views/widgets/report_problem_sheet.dart';
import 'package:Prism/features/session/views/widgets/settings_account_card.dart';
import 'package:Prism/features/theme_mode/views/widgets/diwali_decor.dart';
import 'package:Prism/features/theme_mode/views/widgets/spooky_decor.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_detail/data/wallpaper_tint_renderer.dart';
import 'package:Prism/features/wallpaper_history/data/history_wall_stores.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

const Set<String> _applyTargetKeys = <String>{'ask', 'home', 'lock', 'both'};

Map<String, String> _applyTargetLabels(AppLocalizations l10n) => <String, String>{
  'ask': l10n.accountAskEveryTime,
  'home': l10n.accountHomeScreen,
  'lock': l10n.accountLockScreen,
  'both': l10n.accountHomeAndLockScreens,
};

const String _privacyUrl = 'https://prismwalls.com/privacy';
const String _termsUrl = 'https://prismwalls.com/terms';
const int _savedOfflineLimitBytes = 512 * 1024 * 1024;

/// Signs the user out. Tests replace it.
@visibleForTesting
Future<bool> Function() settingsSignOut = () => globalGoogleAuth.signOutGoogle();

const String _androidSubscriptionsUrl = 'https://play.google.com/store/account/subscriptions?package=com.hash.prism';
const String _iosSubscriptionsUrl = 'https://apps.apple.com/account/subscriptions';

/// The Wallhaven category flag for anime is the second digit, so 110 and 111 both include it.
@visibleForTesting
bool animeEnabledFromCategories(int categories) => categories >= 110;

@visibleForTesting
int categoriesForAnime(bool enabled) => enabled ? 110 : 100;

@visibleForTesting
String formatStorageBytes(AppLocalizations l10n, int bytes) {
  final NumberFormat number = NumberFormat.decimalPattern(l10n.localeName);
  if (bytes < 1024) return l10n.accountStorageSizeBytes(number.format(bytes));
  if (bytes < 1024 * 1024) return l10n.accountStorageSizeKilobytes(number.format((bytes / 1024).round()));
  if (bytes < 1024 * 1024 * 1024) {
    number.minimumFractionDigits = 1;
    number.maximumFractionDigits = 1;
    return l10n.accountStorageSizeMegabytes(number.format(bytes / (1024 * 1024)));
  }
  number.minimumFractionDigits = 2;
  number.maximumFractionDigits = 2;
  return l10n.accountStorageSizeGigabytes(number.format(bytes / (1024 * 1024 * 1024)));
}

Future<int?> _imageCacheBytes() async {
  try {
    final Directory temp = await getTemporaryDirectory();
    int total = 0;
    for (final String name in <String>['libCachedImageData', 'prism_images', 'prism_full', tintedWallpaperFolder]) {
      final Directory dir = Directory(path.join(temp.path, name));
      if (!await dir.exists()) continue;
      await for (final FileSystemEntity entry in dir.list(recursive: true, followLinks: false)) {
        if (entry is File) total += await entry.length();
      }
    }
    return total;
  } catch (_) {
    return null;
  }
}

Future<int?> _downloadsCount() async {
  try {
    final DownloadItemsResult result = await PrismMediaHostApi().listDownloads();
    return result.success ? result.items.length : null;
  } catch (_) {
    return null;
  }
}

@RoutePage()
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final CacheMaintenanceService _cacheMaintenance = getIt<CacheMaintenanceService>();
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();

  late bool _showAnime;
  late bool _showSketchy;
  late bool _showAi;
  late String _defaultApplyTarget;
  bool _haptics = PrismHaptics.enabled;
  bool _lowData = LowDataMode.enabled.value;
  bool _shakeToReport = ShakeToReport.enabled.value;
  bool _saveViewingHistory = getIt<RecentlyViewedStore>().enabled;
  bool _savingViewingHistory = false;
  bool _restoring = false;
  bool _adPrivacyChoices = false;
  bool _iosShortcuts = false;
  bool _iosWidgets = false;
  int? _imageCacheSize;
  int? _downloads;
  int? _savedOfflineSize;

  @override
  void initState() {
    super.initState();
    _viewedStore.addListener(_onViewedStoreChanged);
    personalizedFeedSettingsRevision.addListener(_onAiSettingsChanged);
    _showAnime = animeEnabledFromCategories(_settingsLocal.get<int>('WHcategories', defaultValue: 100));
    _showSketchy = _settingsLocal.get<int>('WHpurity', defaultValue: 100) == 110;
    _showAi = AiContentFilter.showsAi(_settingsLocal);
    final String storedTarget = _settingsLocal.get<String>(PersistenceKeys.defaultApplyTarget, defaultValue: 'ask');
    _defaultApplyTarget = _applyTargetKeys.contains(storedTarget) ? storedTarget : 'ask';
    _loadStorageStats();
    unawaited(_loadAdPrivacyChoices());
    if (defaultTargetPlatform == TargetPlatform.iOS) unawaited(_loadIosShortcutsSupport());
    unawaited(_loadIosWidgetsSupport());
  }

  Future<void> _loadIosWidgetsSupport() async {
    final bool supported = await iosSupportsWidgets();
    if (!mounted || !supported) return;
    setState(() => _iosWidgets = true);
  }

  Future<void> _loadIosShortcutsSupport() async {
    final bool supported = await iosSupportsShortcuts();
    if (!mounted || !supported) return;
    setState(() => _iosShortcuts = true);
  }

  Future<void> _loadAdPrivacyChoices() async {
    final bool required = await AdConsent.instance.privacyOptionsRequired();
    if (!mounted || !required) return;
    setState(() => _adPrivacyChoices = true);
  }

  void _loadStorageStats() {
    unawaited(_loadImageAndDownloadStats());
    unawaited(_loadSavedOfflineSize());
  }

  Future<void> _loadImageAndDownloadStats() async {
    final int? images = await _imageCacheBytes();
    final int? downloads = await _downloadsCount();
    if (!mounted) return;
    setState(() {
      _imageCacheSize = images;
      _downloads = downloads;
    });
  }

  Future<void> _loadSavedOfflineSize() async {
    try {
      final int savedOffline = await _cacheMaintenance.retainedAssetBytes();
      if (!mounted) return;
      setState(() => _savedOfflineSize = savedOffline);
    } catch (error, stackTrace) {
      logger.w('Could not read saved offline storage size.', error: error, stackTrace: stackTrace);
    }
  }

  void _trackSettingsAction(AnalyticsActionValue action) {
    unawaited(
      analytics.track(
        SettingsActionTappedEvent(
          action: action,
          isSignedIn: app_state.prismUser.loggedIn,
          sourceContext: 'settings_screen',
        ),
      ),
    );
  }

  void _trackSettingsToggle(SettingValue setting, bool value) {
    unawaited(analytics.track(SettingsToggleChangedEvent(setting: setting, value: value)));
  }

  void _trackSettingsAuthResult({
    required AnalyticsActionValue action,
    required EventResultValue result,
    AnalyticsReasonValue? reason,
  }) {
    unawaited(analytics.track(SettingsAuthActionResultEvent(action: action, result: result, reason: reason)));
  }

  void _trackRow(String row) {
    unawaited(analytics.track(SettingsRowTappedEvent(row: row)));
  }

  Widget _group(String title, List<Widget> rows, {String? footnote}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PrismSectionHeader(
          title: title,
          small: true,
          padding: const EdgeInsetsDirectional.fromSTEB(PrismSpace.xs, PrismSpace.xl, 0, PrismSpace.xs),
        ),
        PrismGroup(children: rows),
        if (footnote != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(PrismSpace.xs, PrismSpace.xs, PrismSpace.xs, 0),
            child: Text(footnote, style: PrismTextStyles.caption(context)),
          ),
      ],
    );
  }

  void _signIn() {
    _trackSettingsAction(AnalyticsActionValue.signInTapped);
    // Routes through the shared popup so Apple is offered alongside Google.
    googleSignInPopUp(context, () {
      _trackSettingsAuthResult(action: AnalyticsActionValue.signInTapped, result: EventResultValue.success);
      main.RestartWidget.restartApp(context);
    });
  }

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  List<Widget> _accountRows() => <Widget>[
    PrismRow(
      icon: Icons.fact_check_rounded,
      title: context.l10n.accountReviewStatus,
      subtitle: context.l10n.accountTrackSubmittedWallpapers,
      onTap: () => context.router.push(ReviewRoute()),
    ),
    PrismRow(
      icon: Icons.person_off_rounded,
      title: context.l10n.accountBlockedAccounts,
      subtitle: context.l10n.accountManageBlockedPeople,
      onTap: () => context.router.push(const BlockedAccountsRoute()),
    ),
    const CreatorDirectoryOptOutRow(),
    PrismRow(
      icon: Icons.ios_share_rounded,
      title: context.l10n.accountShareYourProfile,
      subtitle: context.l10n.accountSendProfileLink,
      onTap: _shareProfile,
    ),
  ];

  Future<void> _shareProfile() async {
    final AppLocalizations l10n = context.l10n;
    try {
      await createUserDynamicLink(
        app_state.prismUser.name,
        app_state.prismUser.username,
        app_state.prismUser.email,
        app_state.prismUser.bio,
        app_state.prismUser.profilePhoto,
        context: context,
        l10n: l10n,
      );
    } catch (error, stackTrace) {
      logger.w('Sharing the profile link failed.', error: error, stackTrace: stackTrace);
      toasts.error(l10n.accountShareProfileLinkFailed);
    }
  }

  List<Widget> _appearanceRows() => <Widget>[
    PrismRow(
      icon: Icons.palette_rounded,
      title: context.l10n.accountThemes,
      subtitle: context.l10n.accountLightDarkAccentColour,
      onTap: () => context.router.push(const ThemeViewRoute()),
    ),
    PrismRow(
      icon: Icons.storefront_rounded,
      title: context.l10n.accountShop,
      subtitle: context.l10n.accountThemesIconsFrames,
      onTap: () {
        _trackRow('shop');
        context.router.push(const ShopRoute());
      },
    ),
    // Not a PrismSwitchRow: turning haptics off must stay silent, and turning them on plays one selection.
    MergeSemantics(
      child: PrismRow(
        icon: Icons.vibration_rounded,
        title: context.l10n.accountHapticFeedback,
        subtitle: context.l10n.accountVibrateOnTapsAndActions,
        onTap: () => _setHaptics(!_haptics),
        trailing: Switch(value: _haptics, onChanged: _setHaptics),
      ),
    ),
  ];

  void _setHaptics(bool value) {
    setState(() => _haptics = value);
    PrismHaptics.enabled = value;
    PrismHaptics.selection();
    _settingsLocal.set(PrismHaptics.settingsKey, value);
    _trackSettingsToggle(SettingValue.haptics, value);
  }

  List<Widget> _personaliseRows() => <Widget>[
    if (_iosWidgets)
      PrismRow(
        icon: Icons.widgets_rounded,
        title: context.l10n.widgetsSettingsTitle,
        subtitle: context.l10n.widgetsSettingsSubtitle,
        onTap: () => showWidgetGuideSheet(context, source: WidgetGuideSourceValue.settings),
      ),
    if (_iosShortcuts)
      PrismRow(
        icon: Icons.autorenew_rounded,
        title: context.l10n.accountChangeAutomatically,
        subtitle: context.l10n.accountUseShortcutsAutomation,
        onTap: () => context.router.push(const IosShortcutsGuideRoute()),
      ),
    if (_isAndroid) ..._androidPersonaliseRows(),
  ];

  List<Widget> _androidPersonaliseRows() => <Widget>[
    PrismRow(
      icon: Icons.autorenew_rounded,
      title: context.l10n.accountAutoRotateWallpapers,
      subtitle: context.l10n.accountChangeWallpaperOnTimer,
      onTap: () => context.router.push(AutoRotateRoute()),
    ),
    PrismRow(
      icon: Icons.motion_photos_on_outlined,
      title: context.l10n.accountLiveWallpapers,
      subtitle: context.l10n.accountMovingGradientsMotionVideo,
      onTap: () => context.router.push(LiveWallpaperRoute()),
    ),
    PrismRow(
      icon: Icons.grid_view_rounded,
      title: context.l10n.accountQuickTiles,
      subtitle: context.l10n.accountSetUpQuickTiles,
      onTap: () => context.router.push(const QuickTileSettingsRoute()),
    ),
    PrismRow(
      icon: Icons.history_rounded,
      title: context.l10n.accountWallpaperHistory,
      subtitle: context.l10n.accountWallpapersSetBefore,
      onTap: () => context.router.push(LibraryRoute(initialTab: LibraryTab.history)),
    ),
    PrismRow(
      icon: Icons.wallpaper_rounded,
      title: context.l10n.accountDefaultActionForSet,
      value: _applyTargetLabels(context.l10n)[_defaultApplyTarget],
      onTap: _showDefaultApplyTargetSheet,
    ),
  ];

  void _showDefaultApplyTargetSheet() {
    showPrismSheet<void>(
      context,
      builder: (ctx) {
        final ColorScheme cs = Theme.of(ctx).colorScheme;
        return PrismSheetBody(
          title: ctx.l10n.accountDefaultActionForSet,
          child: Column(
            children: <Widget>[
              for (final MapEntry<String, String> option in _applyTargetLabels(ctx.l10n).entries)
                PrismRow(
                  title: option.value,
                  padding: const EdgeInsets.symmetric(vertical: PrismSpace.sm),
                  showChevron: false,
                  trailing: option.key == _defaultApplyTarget ? Icon(Icons.check_rounded, color: cs.primary) : null,
                  onTap: () {
                    PrismHaptics.selection();
                    setState(() => _defaultApplyTarget = option.key);
                    _settingsLocal.set(PersistenceKeys.defaultApplyTarget, option.key);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _contentRows() => <Widget>[
    PrismSwitchRow(
      icon: Icons.animation_rounded,
      title: context.l10n.accountShowAnimeWallpapers,
      value: _showAnime,
      onChanged: (value) {
        setState(() => _showAnime = value);
        _applyContentFilter('WHcategories', categoriesForAnime(value));
        _trackSettingsToggle(SettingValue.animeWallpapers, value);
      },
    ),
    PrismSwitchRow(
      icon: Icons.auto_awesome_rounded,
      title: context.l10n.accountShowAiWallpapers,
      subtitle: context.l10n.accountShowAiWallpapersSubtitle,
      value: _showAi,
      onChanged: (value) async {
        if (_showAi == value) return;
        setState(() => _showAi = value);
        final bool changed;
        try {
          changed = await setShowAiWallpapers(_settingsLocal, value);
        } catch (_) {
          if (!mounted) return;
          setState(() => _showAi = AiContentFilter.showsAi(_settingsLocal));
          toasts.error(context.l10n.wallpaperFeedSaveError);
          return;
        }
        if (!changed) return;
        _trackSettingsToggle(SettingValue.aiWallpapers, value);
        if (!mounted) return;
        context.read<CategoryFeedBloc>().add(const CategoryFeedEvent.refreshRequested());
      },
    ),
    // App Store review: no sketchy content toggle on iOS, purity is forced SFW-only.
    if (!Platform.isIOS)
      PrismSwitchRow(
        icon: Icons.visibility_rounded,
        title: context.l10n.accountShowSketchyWallpapers,
        value: _showSketchy,
        onChanged: (value) {
          setState(() => _showSketchy = value);
          _applyContentFilter('WHpurity', value ? 110 : 100);
          _trackSettingsToggle(SettingValue.sketchyWallpapers, value);
        },
      ),
  ];

  Future<void> _applyContentFilter(String key, int value) async {
    await _settingsLocal.set(key, value);
    if (key == 'WHcategories' && defaultTargetPlatform == TargetPlatform.android) {
      await QuickTileDefaults.mirrorWallhavenCategories(_settingsLocal);
    }
    personalizedFeedSettingsRevision.value += 1;
    if (!mounted) return;
    context.read<CategoryFeedBloc>().add(const CategoryFeedEvent.refreshRequested());
  }

  List<Widget> _notificationRows() => <Widget>[
    PrismRow(
      icon: Icons.notifications_none_rounded,
      title: context.l10n.accountNotificationPreferences,
      subtitle: context.l10n.accountNotificationTypes,
      onTap: () => showNotificationSettingsSheet(context),
    ),
  ];

  List<Widget> _storageRows() => <Widget>[
    PrismSwitchRow(
      icon: Icons.data_saver_on_rounded,
      title: context.l10n.accountDataSaver,
      subtitle: context.l10n.accountDataSaverDescription,
      value: _lowData,
      onChanged: (value) {
        setState(() => _lowData = value);
        unawaited(LowDataMode.set(value));
        unawaited(analytics.track(DataSaverToggledEvent(value: value)));
      },
    ),
    PrismSwitchRow(
      icon: Icons.manage_history_rounded,
      title: context.l10n.settingsSaveViewingHistory,
      subtitle: context.l10n.settingsSaveViewingHistoryBody,
      value: _saveViewingHistory,
      onChanged: _savingViewingHistory ? null : _setViewingHistory,
    ),
    PrismRow(
      icon: Icons.cleaning_services_rounded,
      title: context.l10n.accountClearCacheTitle,
      subtitle: _imageCacheSize == null
          ? context.l10n.accountClearCachedImages
          : context.l10n.accountCachedImageSize(formatStorageBytes(context.l10n, _imageCacheSize!)),
      showChevron: false,
      onTap: _clearCache,
    ),
    PrismRow(
      icon: Icons.download_done_rounded,
      title: context.l10n.accountClearAllDownloads,
      subtitle: _downloads == null
          ? context.l10n.accountRemoveFilesDownloadsOfflineStay
          : context.l10n.accountDownloadedWallpaperCount(_downloads ?? 0),
      showChevron: false,
      onTap: _confirmClearDownloads,
    ),
    PrismRow(
      icon: Icons.offline_pin_rounded,
      title: context.l10n.accountSavedOffline,
      subtitle: _savedOfflineSize == null
          ? context.l10n.accountSavedOfflineStorageUnavailable(_savedOfflineLimitBytes ~/ (1024 * 1024))
          : context.l10n.accountSavedOfflineStorageUsed(
              formatStorageBytes(context.l10n, _savedOfflineSize!),
              _savedOfflineLimitBytes ~/ (1024 * 1024),
            ),
      showChevron: false,
      onTap: _confirmClearSavedOffline,
    ),
    if (app_state.prismUser.loggedIn)
      PrismRow(
        icon: Icons.favorite_border_rounded,
        title: context.l10n.accountClearFavouriteWallpapers,
        subtitle: context.l10n.accountRemoveAllFavouriteWallpapers,
        showChevron: false,
        onTap: () {
          _trackSettingsAction(AnalyticsActionValue.clearFavouriteWallsTapped);
          unawaited(_confirmClearFavourites());
        },
      ),
  ];

  late final RecentlyViewedStore _viewedStore = getIt<RecentlyViewedStore>();

  @override
  void dispose() {
    _viewedStore.removeListener(_onViewedStoreChanged);
    personalizedFeedSettingsRevision.removeListener(_onAiSettingsChanged);
    super.dispose();
  }

  void _onAiSettingsChanged() {
    if (!mounted) return;
    final bool showAi = AiContentFilter.showsAi(_settingsLocal);
    if (_showAi == showAi) return;
    setState(() => _showAi = showAi);
  }

  /// Follows changes made elsewhere, such as Turn on in History.
  void _onViewedStoreChanged() {
    if (!mounted || _savingViewingHistory || _saveViewingHistory == _viewedStore.enabled) return;
    setState(() => _saveViewingHistory = _viewedStore.enabled);
  }

  Future<void> _setViewingHistory(bool value) async {
    final RecentlyViewedStore store = getIt<RecentlyViewedStore>();
    setState(() => _savingViewingHistory = true);
    try {
      await store.setEnabled(value);
      unawaited(analytics.track(ViewingHistoryToggledEvent(value: value)));
    } catch (error, stackTrace) {
      logger.w('Saving viewing history preference failed.', error: error, stackTrace: stackTrace);
      if (mounted) toasts.error(context.l10n.coreSomethingWentWrong);
    } finally {
      if (mounted) {
        setState(() {
          _saveViewingHistory = store.enabled;
          _savingViewingHistory = false;
        });
      }
    }
  }

  Future<void> _clearCache() async {
    final AppLocalizations l10n = context.l10n;
    _trackSettingsAction(AnalyticsActionValue.clearCacheTapped);
    final int? size = _imageCacheSize;
    final bool confirmed = await showPrismConfirm(
      context,
      title: context.l10n.accountClearCacheQuestion,
      message: size == null
          ? context.l10n.accountClearCacheConfirmMessage
          : context.l10n.accountClearCacheConfirmSizeMessage(formatStorageBytes(l10n, size)),
      confirmLabel: context.l10n.accountClearCache,
      destructive: true,
    );
    if (!confirmed) return;
    final int? before = await _imageCacheBytes();
    await _cacheMaintenance.clearTransientCache();
    final int? after = await _imageCacheBytes();
    final int freed = (before ?? 0) - (after ?? 0);
    toasts.success(
      freed > 0 ? l10n.accountCacheClearedBytes(formatStorageBytes(l10n, freed)) : l10n.accountCacheCleared,
    );
    if (mounted) setState(() => _imageCacheSize = after);
  }

  Future<void> _confirmClearDownloads() async {
    final AppLocalizations l10n = context.l10n;
    final int? count = _downloads;
    final bool confirmed = await showPrismConfirm(
      context,
      title: context.l10n.accountDeleteAllDownloadsQuestion,
      message: count != null && count > 0
          ? context.l10n.accountDeleteDownloadsCountMessage(count)
          : context.l10n.accountDeleteDownloadsMessage,
      confirmLabel: context.l10n.accountDeleteAll,
      destructive: true,
    );
    if (!confirmed) return;
    OperationResult? result;
    try {
      result = await PrismMediaHostApi().clearDownloads();
    } catch (e) {
      logger.w('Clearing downloads failed.', error: e);
    }
    if (result != null && result.success) {
      await getIt<DownloadedWallIndex>().clear();
      toasts.success(l10n.accountDownloadsDeleted);
      if (mounted) setState(() => _downloads = 0);
    } else if (result?.errorCode == 'NO_DOWNLOADS') {
      toasts.success(l10n.accountNoDownloadsToRemove, haptic: false);
    } else {
      toasts.error(l10n.accountCouldNotDeleteDownloads);
    }
  }

  Future<void> _confirmClearSavedOffline() async {
    final AppLocalizations l10n = context.l10n;
    final int? size = _savedOfflineSize;
    final bool confirmed = await showPrismConfirm(
      context,
      title: context.l10n.accountRemoveSavedOfflineQuestion,
      message: size == null
          ? context.l10n.accountRemoveSavedOfflineMessage
          : context.l10n.accountRemoveSavedOfflineCountMessage(formatStorageBytes(l10n, size)),
      confirmLabel: context.l10n.accountRemoveSavedOffline,
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await _cacheMaintenance.clearRetainedAssets();
    } catch (error, stackTrace) {
      logger.w('Clearing saved offline wallpapers failed.', error: error, stackTrace: stackTrace);
      toasts.error(l10n.accountCouldNotRemoveSavedOffline);
      return;
    }
    int? after;
    try {
      after = await _cacheMaintenance.retainedAssetBytes();
    } catch (error, stackTrace) {
      logger.w('Could not refresh saved offline storage size.', error: error, stackTrace: stackTrace);
    }
    if (!mounted) return;
    setState(() => _savedOfflineSize = after);
    toasts.success(l10n.accountSavedOfflineRemoved);
  }

  Future<void> _confirmClearFavourites() async {
    final AppLocalizations l10n = context.l10n;
    int? count;
    try {
      count = (await context.favouriteWallsAdapter(listen: false).getDataBase())?.length;
    } catch (error) {
      logger.w('Counting favourites failed.', error: error);
    }
    if (!mounted) return;
    final bool confirmed = await showPrismConfirm(
      context,
      title: context.l10n.accountClearAllFavouritesQuestion,
      message: count != null && count > 0
          ? context.l10n.accountClearFavouritesCountMessage(count)
          : context.l10n.accountClearFavouritesMessage,
      confirmLabel: context.l10n.accountClearFavourites,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    _trackSettingsAction(AnalyticsActionValue.clearFavouriteWallsConfirmed);
    final cleared = await context.favouriteWallsAdapter(listen: false).deleteData();
    if (!mounted) return;
    if (cleared) {
      toasts.success(l10n.accountFavouritesCleared);
    } else {
      toasts.error(l10n.accountCouldNotClearFavourites);
    }
  }

  List<Widget> _purchaseRows() => <Widget>[
    if (!app_state.prismUser.premium)
      PrismRow(
        icon: Icons.workspace_premium_rounded,
        title: context.l10n.accountBuyPremium,
        subtitle: context.l10n.accountUnlimitedUploadsFilters,
        onTap: () {
          _trackSettingsAction(AnalyticsActionValue.buyPremiumTapped);
          PaywallOrchestrator.instance.presentOrRequireSignIn(
            context,
            placement: PaywallPlacement.mainUpsell,
            source: 'settings_buy_premium',
          );
        },
      ),
    PrismRow(
      icon: Icons.restore_rounded,
      title: context.l10n.accountRestorePurchases,
      subtitle: context.l10n.accountBringBackSubscription,
      showChevron: false,
      onTap: _restoring ? null : _restorePurchases,
    ),
    if (app_state.prismUser.premium)
      PrismRow(
        icon: Icons.card_membership_rounded,
        title: context.l10n.accountManageSubscription,
        subtitle: context.l10n.accountChangeOrCancelStore,
        trailing: Icon(
          Icons.open_in_new_rounded,
          size: 18,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
        ),
        onTap: _openManageSubscription,
      ),
  ];

  Future<void> _restorePurchases() async {
    if (!await requireSignedInAction(context) || !mounted) return;
    final String requestedUserId = app_state.prismUser.id.trim();
    final bool requestedLoggedIn = app_state.prismUser.loggedIn;
    bool isCurrentAccount() =>
        requestedUserId == app_state.prismUser.id.trim() && requestedLoggedIn == app_state.prismUser.loggedIn;
    final AppLocalizations l10n = context.l10n;
    _trackSettingsAction(AnalyticsActionValue.restorePurchaseTapped);
    setState(() => _restoring = true);
    toasts.success(l10n.accountRestoringPurchases, haptic: false);
    try {
      final PurchaseEntitlementStatus status = await PurchasesService.instance.restore();
      if (!mounted || !isCurrentAccount()) return;
      if (status == PurchaseEntitlementStatus.serverConfirmed) {
        toasts.success(l10n.accountPurchasesRestored);
      } else if (status == PurchaseEntitlementStatus.guestSignInRequired) {
        toasts.success(l10n.premiumGuestStorePurchaseActive);
      } else if (app_state.prismUser.premium) {
        toasts.success(l10n.accountPurchasesRestoredPending);
      } else {
        toasts.error(l10n.accountNoPurchasesToRestore);
      }
    } catch (e) {
      if (!mounted || !isCurrentAccount()) return;
      toasts.error(l10n.accountCouldNotRestorePurchases);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _openManageSubscription() async {
    final AppLocalizations l10n = context.l10n;
    final String url = defaultTargetPlatform == TargetPlatform.iOS ? _iosSubscriptionsUrl : _androidSubscriptionsUrl;
    bool launched = false;
    try {
      launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      logger.w('Opening the subscription page failed.', error: e);
    }
    if (!launched) toasts.error(l10n.accountCouldNotOpenStore);
  }

  Icon _external(BuildContext context) =>
      Icon(Icons.open_in_new_rounded, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35));

  List<Widget> _privacyRows() => <Widget>[
    PrismRow(
      icon: Icons.privacy_tip_outlined,
      title: context.l10n.accountPrivacyPolicy,
      trailing: _external(context),
      onTap: () => _openLink(_privacyUrl, 'privacy_policy'),
    ),
    PrismRow(
      icon: Icons.description_outlined,
      title: context.l10n.accountTermsOfUse,
      trailing: _external(context),
      onTap: () => _openLink(_termsUrl, 'terms'),
    ),
    if (_adPrivacyChoices)
      PrismRow(
        icon: Icons.tune_rounded,
        title: context.l10n.accountAdPrivacyChoices,
        subtitle: context.l10n.accountReviewOrChangeAdConsent,
        onTap: () {
          _trackRow('ad_privacy_choices');
          unawaited(AdConsent.instance.showPrivacyOptions());
        },
      ),
    PrismRow(
      icon: Icons.auto_awesome_outlined,
      title: context.l10n.accountClearLearnedTaste,
      subtitle: context.l10n.accountForgetFeedLearned,
      showChevron: false,
      onTap: _clearLearnedTaste,
    ),
    PrismRow(
      icon: Icons.file_download_outlined,
      title: context.l10n.accountExportFavourites,
      subtitle: context.l10n.accountSaveFavouritesAsFile,
      onTap: () {
        _trackRow('export_favourites');
        context.router.push(LibraryRoute());
      },
    ),
  ];

  Future<void> _openLink(String url, String row) async {
    final AppLocalizations l10n = context.l10n;
    _trackRow(row);
    bool opened = false;
    try {
      opened = await openPrismLink(context, url);
    } catch (error) {
      logger.w('Opening $url failed.', error: error);
    }
    if (!opened) toasts.error(l10n.accountCouldNotOpenLink);
  }

  Future<void> _clearLearnedTaste() async {
    final AppLocalizations l10n = context.l10n;
    _trackRow('clear_learned_taste');
    final TasteSignalStore store = getIt<TasteSignalStore>();
    final int learned = store.read().length;
    if (learned == 0) {
      toasts.info(l10n.accountNothingLearnedYet);
      return;
    }
    final bool confirmed = await showPrismConfirm(
      context,
      title: l10n.accountClearLearnedTasteQuestion,
      message: l10n.accountClearLearnedTasteCountMessage(learned),
      confirmLabel: l10n.accountClear,
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await store.clear();
    } catch (error) {
      logger.w('Clearing learned taste failed.', error: error);
      toasts.error(l10n.accountCouldNotClearLearnedTaste);
      return;
    }
    personalizedFeedSettingsRevision.value += 1;
    toasts.success(l10n.accountLearnedTasteCleared);
  }

  List<Widget> _adminRows() => <Widget>[
    PrismRow(
      icon: Icons.bug_report_rounded,
      title: context.l10n.accountDebugPanel,
      subtitle: context.l10n.accountLogsNetworkToolsStorage,
      onTap: () => context.router.pushPath('/debug-panel'),
    ),
    PrismRow(
      icon: Icons.shield_rounded,
      title: context.l10n.accountAdminModeration,
      subtitle: context.l10n.accountReviewSubmittedContent,
      onTap: () => context.router.push(AdminReviewRoute()),
    ),
    PrismRow(
      icon: Icons.analytics_rounded,
      title: context.l10n.accountFirestoreTelemetry,
      subtitle: context.l10n.accountDatabaseUsageStats,
      onTap: () => context.router.push(const FirestoreTelemetryRoute()),
    ),
  ];

  List<Widget> _helpRows() => <Widget>[
    PrismRow(
      icon: Icons.report_problem_outlined,
      title: context.l10n.accountReportAProblem,
      subtitle: context.l10n.accountReportProblemSubtitle,
      onTap: () {
        _trackRow('report_a_problem');
        unawaited(showReportProblemSheet(context, source: 'settings', trigger: ReportTrigger.settings));
      },
    ),
    PrismSwitchRow(
      icon: Icons.vibration_rounded,
      title: context.l10n.reportShakeToReport,
      subtitle: context.l10n.reportShakeToReportSubtitle,
      value: _shakeToReport,
      onChanged: (value) {
        setState(() => _shakeToReport = value);
        unawaited(ShakeToReport.set(value));
      },
    ),
    PrismRow(
      icon: Icons.info_rounded,
      title: context.l10n.accountAboutPrism,
      onTap: () => context.router.push(AboutRoute()),
    ),
  ];

  List<Widget> _sessionRows() => <Widget>[
    PrismRow(icon: Icons.logout_rounded, title: context.l10n.accountLogOut, showChevron: false, onTap: _confirmLogOut),
    PrismRow(
      icon: Icons.delete_forever_rounded,
      title: context.l10n.accountDeleteAccount,
      destructive: true,
      showChevron: false,
      onTap: _confirmDeleteAccount,
    ),
  ];

  Future<void> _confirmLogOut() async {
    final bool ok = await showPrismConfirm(
      context,
      title: context.l10n.accountLogOutQuestion,
      message: context.l10n.accountLogoutConfirmation,
      confirmLabel: context.l10n.accountLogOut,
    );
    if (!ok || !mounted) return;
    await _logout();
  }

  Future<void> _logout() async {
    final AppLocalizations l10n = context.l10n;
    _trackSettingsAction(AnalyticsActionValue.logoutTapped);
    try {
      final bool signedOut = await settingsSignOut();
      _trackSettingsAuthResult(
        action: AnalyticsActionValue.logoutTapped,
        result: signedOut ? EventResultValue.success : EventResultValue.failure,
        reason: signedOut ? null : AnalyticsReasonValue.error,
      );
      if (!signedOut) {
        toasts.error(l10n.accountLogoutFailed);
        return;
      }
      await resetOnboardingLocalState(_settingsLocal);
      if (mounted) {
        main.RestartWidget.restartApp(context);
      }
    } catch (error, stackTrace) {
      logger.e('Sign out failed from settings.', error: error, stackTrace: stackTrace);
      _trackSettingsAuthResult(
        action: AnalyticsActionValue.logoutTapped,
        result: EventResultValue.failure,
        reason: AnalyticsReasonValue.error,
      );
      toasts.error(l10n.accountLogoutFailed);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final bool premium = app_state.prismUser.premium;
    final bool? ok = await showPrismSheet<bool>(
      context,
      builder: (sheetContext) => PrismSheetBody(
        title: sheetContext.l10n.accountDeleteYourAccountQuestion,
        message: sheetContext.l10n.accountDeleteAccountConfirmation,
        mood: GlintMood.sad,
        centered: true,
        actions: <Widget>[
          PrismButton(
            label: sheetContext.l10n.accountDeleteAccount,
            expand: true,
            variant: PrismButtonVariant.danger,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          PrismButton(
            label: sheetContext.l10n.accountCancel,
            expand: true,
            variant: PrismButtonVariant.ghost,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
        child: Column(
          children: <Widget>[
            Text(
              sheetContext.l10n.accountDeleteAccountReauthNote,
              textAlign: TextAlign.center,
              style: PrismTextStyles.body(sheetContext).copyWith(height: 1.4),
            ),
            if (premium) ...<Widget>[
              const SizedBox(height: PrismSpace.sm),
              Text(
                sheetContext.l10n.accountAccountDeletionSubscriptionWarning,
                textAlign: TextAlign.center,
                style: PrismTextStyles.body(sheetContext).copyWith(height: 1.4),
              ),
              TextButton(onPressed: _openManageSubscription, child: Text(sheetContext.l10n.accountManageSubscription)),
            ],
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    final AppLocalizations l10n = context.l10n;
    final NavigatorState rootNavigator = Navigator.of(context, rootNavigator: true);
    unawaited(
      showPrismSheet<void>(
        context,
        barrierDismissible: false,
        swipeDismissible: false,
        useRootNavigator: true,
        builder: (_) => PopScope(
          canPop: false,
          child: PrismSheetBody(
            mood: GlintMood.curious,
            centered: true,
            title: l10n.accountDeletingYourAccount,
            showCloseButton: false,
            showHandle: false,
          ),
        ),
      ),
    );
    try {
      await DeleteAccountService.instance.deleteAccount();
      rootNavigator.pop();
      if (rootNavigator.mounted) main.RestartWidget.restartApp(rootNavigator.context);
    } catch (error) {
      rootNavigator.pop();
      if (isReauthCancelled(error)) return;
      if (error is WrongAccountException) {
        logger.w('Delete account cancelled: wrong account selected.', error: error);
        toasts.error(l10n.accountCurrentSignedInAccountRequired);
        return;
      }
      logger.e('Delete account failed.', error: error);
      final String message = error.toString().contains('requires-recent-login')
          ? l10n.accountSignInAgainToDelete
          : l10n.accountSomethingWentWrongTryAgain;
      toasts.error(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool loggedIn = app_state.prismUser.loggedIn;
    return PrismPage(
      title: context.l10n.accountSettings,
      body: Stack(
        children: <Widget>[
          ListView(
            padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xxxl),
            children: <Widget>[
              SettingsAccountCard(
                onSignIn: _signIn,
                onOpenProfile: () => context.router.push(ProfileRoute(profileIdentifier: app_state.prismUser.id)),
              ),
              if (loggedIn) _group(context.l10n.accountAccount, _accountRows()),
              _group(context.l10n.accountAppearance, _appearanceRows()),
              if (_isAndroid || _iosShortcuts || _iosWidgets)
                _group(context.l10n.accountPersonalise, _personaliseRows()),
              _group(
                context.l10n.accountContent,
                _contentRows(),
                footnote: context.l10n.accountShowAiWallpapersFootnote,
              ),
              _group(context.l10n.accountNotifications, _notificationRows()),
              _group(context.l10n.accountStorage, _storageRows()),
              _group(context.l10n.accountPurchases, _purchaseRows()),
              _group(context.l10n.accountPrivacyAndData, _privacyRows()),
              if (app_state.isAdminUser()) _group(context.l10n.accountAdmin, _adminRows()),
              _group(context.l10n.accountHelp, _helpRows()),
              if (loggedIn) ...<Widget>[const SizedBox(height: PrismSpace.xl), PrismGroup(children: _sessionRows())],
            ],
          ),
          const Positioned(top: 0, right: 0, child: SpookyWeb(right: true)),
          const Positioned(top: 0, right: 36, child: SpookySpider(size: 22)),
          const Positioned(top: 0, right: 40, child: DiwaliDiya(size: 26)),
        ],
      ),
    );
  }
}
