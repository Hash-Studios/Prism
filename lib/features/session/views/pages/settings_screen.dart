import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/google_auth.dart' show WrongAccountException;
import 'package:Prism/core/account/account_copy.dart';
import 'package:Prism/core/account/delete_account_service.dart';
import 'package:Prism/core/account/reauth_cancelled.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/cache_maintenance_service.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/state/auth_runtime.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/in_app_notifications/views/widgets/notification_settings_sheet.dart';
import 'package:Prism/features/ios_shortcuts/data/ios_shortcuts_support.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart'
    show personalizedFeedSettingsRevision;
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/features/quick_tiles/data/quick_tile_defaults.dart';
import 'package:Prism/features/session/data/low_data_mode.dart';
import 'package:Prism/features/session/views/widgets/report_problem_sheet.dart';
import 'package:Prism/features/session/views/widgets/settings_account_card.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_detail/data/wallpaper_tint_renderer.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

const Map<String, String> _applyTargetLabels = <String, String>{
  'ask': 'Ask every time',
  'home': 'Home screen',
  'lock': 'Lock screen',
  'both': 'Home and lock screens',
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
String formatStorageBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
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
  late String _defaultApplyTarget;
  bool _haptics = PrismHaptics.enabled;
  bool _lowData = LowDataMode.enabled.value;
  bool _restoring = false;
  bool _adPrivacyChoices = false;
  bool _iosShortcuts = false;
  int? _imageCacheSize;
  int? _downloads;
  int? _savedOfflineSize;

  @override
  void initState() {
    super.initState();
    _showAnime = animeEnabledFromCategories(_settingsLocal.get<int>('WHcategories', defaultValue: 100));
    _showSketchy = _settingsLocal.get<int>('WHpurity', defaultValue: 100) == 110;
    final String storedTarget = _settingsLocal.get<String>(PersistenceKeys.defaultApplyTarget, defaultValue: 'ask');
    _defaultApplyTarget = _applyTargetLabels.containsKey(storedTarget) ? storedTarget : 'ask';
    _loadStorageStats();
    unawaited(_loadAdPrivacyChoices());
    if (defaultTargetPlatform == TargetPlatform.iOS) unawaited(_loadIosShortcutsSupport());
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

  Widget _group(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PrismSectionHeader(
          title: title,
          small: true,
          padding: const EdgeInsets.fromLTRB(PrismSpace.xs, PrismSpace.xl, 0, PrismSpace.xs),
        ),
        PrismGroup(children: rows),
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
      title: 'Review status',
      subtitle: 'Track your submitted wallpapers',
      onTap: () => context.router.push(const ReviewRoute()),
    ),
    PrismRow(
      icon: Icons.person_off_rounded,
      title: 'Blocked accounts',
      subtitle: 'Manage people you have blocked',
      onTap: () => context.router.push(const BlockedAccountsRoute()),
    ),
    PrismRow(
      icon: Icons.ios_share_rounded,
      title: 'Share your profile',
      subtitle: 'Send a link to your Prism profile',
      onTap: _shareProfile,
    ),
  ];

  Future<void> _shareProfile() async {
    try {
      await createUserDynamicLink(
        app_state.prismUser.name,
        app_state.prismUser.username,
        app_state.prismUser.email,
        app_state.prismUser.bio,
        app_state.prismUser.profilePhoto,
        context: context,
        followerCount: app_state.prismUser.followers.length,
      );
    } catch (error, stackTrace) {
      logger.w('Sharing the profile link failed.', error: error, stackTrace: stackTrace);
      toasts.error("Couldn't create the link. Try again.");
    }
  }

  List<Widget> _appearanceRows() => <Widget>[
    PrismRow(
      icon: Icons.palette_rounded,
      title: 'Themes',
      subtitle: 'Light, dark and accent colour',
      onTap: () => context.router.push(const ThemeViewRoute()),
    ),
    // Not a PrismSwitchRow: turning haptics off must stay silent, and turning them on plays one selection.
    MergeSemantics(
      child: PrismRow(
        icon: Icons.vibration_rounded,
        title: 'Haptic feedback',
        subtitle: 'Vibrate on taps and actions',
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
    if (_iosShortcuts)
      PrismRow(
        icon: Icons.autorenew_rounded,
        title: 'Change automatically',
        subtitle: 'Use a Shortcuts automation',
        onTap: () => context.router.push(const IosShortcutsGuideRoute()),
      ),
    if (_isAndroid) ..._androidPersonaliseRows(),
  ];

  List<Widget> _androidPersonaliseRows() => <Widget>[
    PrismRow(
      icon: Icons.autorenew_rounded,
      title: 'Auto-rotate wallpapers',
      subtitle: 'Change your wallpaper on a timer',
      onTap: () {
        if (app_state.prismUser.premium) {
          context.router.push(const AutoRotateRoute());
        } else {
          PaywallOrchestrator.instance.presentOrRequireSignIn(
            context,
            placement: PaywallPlacement.autoRotate,
            source: 'settings_auto_rotate',
          );
        }
      },
    ),
    PrismRow(
      icon: Icons.motion_photos_on_outlined,
      title: 'Live wallpapers',
      subtitle: 'Moving gradients, motion and video',
      onTap: () => context.router.push(LiveWallpaperRoute()),
    ),
    PrismRow(
      icon: Icons.grid_view_rounded,
      title: 'Quick tiles',
      subtitle: 'Set up your Quick Settings tiles',
      onTap: () => context.router.push(const QuickTileSettingsRoute()),
    ),
    PrismRow(
      icon: Icons.history_rounded,
      title: 'Wallpaper history',
      subtitle: 'Wallpapers you set before',
      onTap: () => context.router.push(const WallpaperHistoryRoute()),
    ),
    PrismRow(
      icon: Icons.wallpaper_rounded,
      title: 'Default action for Set',
      value: _applyTargetLabels[_defaultApplyTarget],
      onTap: _showDefaultApplyTargetSheet,
    ),
  ];

  void _showDefaultApplyTargetSheet() {
    showPrismSheet<void>(
      context: context,
      builder: (ctx) {
        final ColorScheme cs = Theme.of(ctx).colorScheme;
        return PrismSheetBody(
          title: 'Default action for Set',
          child: Column(
            children: <Widget>[
              for (final MapEntry<String, String> option in _applyTargetLabels.entries)
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
      title: 'Show anime wallpapers',
      value: _showAnime,
      onChanged: (value) {
        setState(() => _showAnime = value);
        _applyContentFilter('WHcategories', categoriesForAnime(value));
        _trackSettingsToggle(SettingValue.animeWallpapers, value);
      },
    ),
    // App Store review: no sketchy content toggle on iOS, purity is forced SFW-only.
    if (!Platform.isIOS)
      PrismSwitchRow(
        icon: Icons.visibility_rounded,
        title: 'Show sketchy wallpapers',
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
      title: 'Notification preferences',
      subtitle: 'Wall of the Day, followers, posts and more',
      onTap: () => showNotificationSettingsSheet(context),
    ),
  ];

  List<Widget> _storageRows() => <Widget>[
    PrismSwitchRow(
      icon: Icons.data_saver_on_rounded,
      title: 'Data saver',
      subtitle:
          'Saves mobile data. Wallpapers open as thumbnails, feeds do not load ahead and carousels do not autoplay.',
      value: _lowData,
      onChanged: (value) {
        setState(() => _lowData = value);
        unawaited(LowDataMode.set(value));
        unawaited(analytics.track(DataSaverToggledEvent(value: value)));
      },
    ),
    PrismRow(
      icon: Icons.cleaning_services_rounded,
      title: 'Clear cache',
      subtitle: _imageCacheSize == null
          ? 'Clear locally cached images'
          : '${formatStorageBytes(_imageCacheSize!)} of cached images',
      showChevron: false,
      onTap: _clearCache,
    ),
    PrismRow(
      icon: Icons.download_done_rounded,
      title: 'Clear all downloads',
      subtitle: _downloads == null
          ? 'Remove files from Downloads; saved offline copies stay'
          : _downloads == 0
          ? 'No downloaded wallpapers; saved offline copies stay'
          : '$_downloads downloaded ${_downloads == 1 ? 'wallpaper' : 'wallpapers'} · saved offline copies stay',
      showChevron: false,
      onTap: _confirmClearDownloads,
    ),
    PrismRow(
      icon: Icons.offline_pin_rounded,
      title: 'Saved offline',
      subtitle: _savedOfflineSize == null
          ? 'Storage unavailable · ${_savedOfflineLimitBytes ~/ (1024 * 1024)} MiB limit'
          : '${formatStorageBytes(_savedOfflineSize!)} used · ${_savedOfflineLimitBytes ~/ (1024 * 1024)} MiB limit',
      showChevron: false,
      onTap: _confirmClearSavedOffline,
    ),
    if (app_state.prismUser.loggedIn)
      PrismRow(
        icon: Icons.favorite_border_rounded,
        title: 'Clear favourite wallpapers',
        subtitle: 'Remove all favourite wallpapers',
        showChevron: false,
        onTap: () {
          _trackSettingsAction(AnalyticsActionValue.clearFavouriteWallsTapped);
          unawaited(_confirmClearFavourites());
        },
      ),
  ];

  Future<void> _clearCache() async {
    _trackSettingsAction(AnalyticsActionValue.clearCacheTapped);
    final int? size = _imageCacheSize;
    final bool confirmed = await showPrismConfirm(
      context,
      title: 'Clear cache?',
      message: size == null
          ? 'Cached images are removed. They load again when you need them.'
          : '${formatStorageBytes(size)} of cached images are removed. They load again when you need them.',
      confirmLabel: 'Clear cache',
      destructive: true,
    );
    if (!confirmed) return;
    final int? before = await _imageCacheBytes();
    await _cacheMaintenance.clearTransientCache();
    final int? after = await _imageCacheBytes();
    final int freed = (before ?? 0) - (after ?? 0);
    toasts.success(freed > 0 ? 'Cleared ${formatStorageBytes(freed)}.' : 'Cache cleared.');
    if (mounted) setState(() => _imageCacheSize = after);
  }

  Future<void> _confirmClearDownloads() async {
    final int? count = _downloads;
    final bool confirmed = await showPrismConfirm(
      context,
      title: 'Delete all downloads?',
      message: count != null && count > 0
          ? '${count == 1 ? '1 downloaded wallpaper is' : '$count downloaded wallpapers are'} deleted from Downloads. Saved offline copies are not affected. This cannot be undone.'
          : 'Downloaded wallpapers are deleted from Downloads. Saved offline copies are not affected. This cannot be undone.',
      confirmLabel: 'Delete all',
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
      toasts.success('Deleted all downloads.');
      if (mounted) setState(() => _downloads = 0);
    } else if (result?.errorCode == 'NO_DOWNLOADS') {
      toasts.success('You have no downloads to remove.', haptic: false);
    } else {
      toasts.error(result?.message ?? "Couldn't delete downloads. Try again.");
    }
  }

  Future<void> _confirmClearSavedOffline() async {
    final int? size = _savedOfflineSize;
    final bool confirmed = await showPrismConfirm(
      context,
      title: 'Remove saved offline wallpapers?',
      message: size == null
          ? 'Remove retained offline originals from this device. Downloads, drafts and catalog data stay untouched.'
          : '${formatStorageBytes(size)} of retained offline originals are removed. Downloads, drafts and catalog data stay untouched.',
      confirmLabel: 'Remove saved offline',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await _cacheMaintenance.clearRetainedAssets();
    } catch (error, stackTrace) {
      logger.w('Clearing saved offline wallpapers failed.', error: error, stackTrace: stackTrace);
      toasts.error("Couldn't remove saved offline wallpapers. Try again.");
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
    toasts.success('Saved offline wallpapers removed.');
  }

  Future<void> _confirmClearFavourites() async {
    int? count;
    try {
      count = (await context.favouriteWallsAdapter(listen: false).getDataBase())?.length;
    } catch (error) {
      logger.w('Counting favourites failed.', error: error);
    }
    if (!mounted) return;
    final bool confirmed = await showPrismConfirm(
      context,
      title: 'Clear all favourites?',
      message: count != null && count > 0
          ? '${count == 1 ? '1 favourite wallpaper is' : '$count favourite wallpapers are'} removed from your account. This cannot be undone.'
          : 'All your favourite wallpapers are removed from your account. This cannot be undone.',
      confirmLabel: 'Clear favourites',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    _trackSettingsAction(AnalyticsActionValue.clearFavouriteWallsConfirmed);
    final cleared = await context.favouriteWallsAdapter(listen: false).deleteData();
    if (!mounted) return;
    if (cleared) {
      toasts.success('Cleared all favourite wallpapers.');
    } else {
      toasts.error("Couldn't clear favourite wallpapers. Try again.");
    }
  }

  List<Widget> _purchaseRows() => <Widget>[
    if (!app_state.prismUser.premium)
      PrismRow(
        icon: Icons.workspace_premium_rounded,
        title: 'Buy premium',
        subtitle: 'Unlimited uploads and filters',
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
      title: 'Restore purchases',
      subtitle: 'Bring back a previous subscription',
      showChevron: false,
      onTap: _restoring ? null : _restorePurchases,
    ),
    if (app_state.prismUser.premium)
      PrismRow(
        icon: Icons.card_membership_rounded,
        title: 'Manage subscription',
        subtitle: 'Change or cancel in the store',
        trailing: Icon(
          Icons.open_in_new_rounded,
          size: 18,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
        ),
        onTap: _openManageSubscription,
      ),
  ];

  Future<void> _restorePurchases() async {
    _trackSettingsAction(AnalyticsActionValue.restorePurchaseTapped);
    setState(() => _restoring = true);
    toasts.success('Restoring purchases…', haptic: false);
    try {
      final bool premium = await PurchasesService.instance.restore();
      premium ? toasts.success('Purchases restored.') : toasts.error('No purchases to restore for this account.');
    } catch (e) {
      toasts.error('Could not restore purchases. Try again.');
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _openManageSubscription() async {
    final String url = defaultTargetPlatform == TargetPlatform.iOS ? _iosSubscriptionsUrl : _androidSubscriptionsUrl;
    bool launched = false;
    try {
      launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      logger.w('Opening the subscription page failed.', error: e);
    }
    if (!launched) toasts.error("Couldn't open the store. Try again.");
  }

  Icon _external(BuildContext context) =>
      Icon(Icons.open_in_new_rounded, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35));

  List<Widget> _privacyRows() => <Widget>[
    PrismRow(
      icon: Icons.privacy_tip_outlined,
      title: 'Privacy policy',
      trailing: _external(context),
      onTap: () => _openLink(_privacyUrl, 'privacy_policy'),
    ),
    PrismRow(
      icon: Icons.description_outlined,
      title: 'Terms of use',
      trailing: _external(context),
      onTap: () => _openLink(_termsUrl, 'terms'),
    ),
    if (_adPrivacyChoices)
      PrismRow(
        icon: Icons.tune_rounded,
        title: 'Ad privacy choices',
        subtitle: 'Review or change your ad consent',
        onTap: () {
          _trackRow('ad_privacy_choices');
          unawaited(AdConsent.instance.showPrivacyOptions());
        },
      ),
    PrismRow(
      icon: Icons.auto_awesome_outlined,
      title: 'Clear learned taste',
      subtitle: 'Forget what your feed learned from you',
      showChevron: false,
      onTap: _clearLearnedTaste,
    ),
    PrismRow(
      icon: Icons.file_download_outlined,
      title: 'Export favourites',
      subtitle: 'Save a copy of your favourites as a file',
      onTap: () {
        _trackRow('export_favourites');
        context.router.push(LibraryRoute());
      },
    ),
  ];

  Future<void> _openLink(String url, String row) async {
    _trackRow(row);
    bool opened = false;
    try {
      opened = await openPrismLink(context, url);
    } catch (error) {
      logger.w('Opening $url failed.', error: error);
    }
    if (!opened) toasts.error("Couldn't open the link. Try again.");
  }

  Future<void> _clearLearnedTaste() async {
    _trackRow('clear_learned_taste');
    final TasteSignalStore store = getIt<TasteSignalStore>();
    final int learned = store.read().length;
    if (learned == 0) {
      toasts.info('Prism has not learned anything yet.');
      return;
    }
    final bool confirmed = await showPrismConfirm(
      context,
      title: 'Clear learned taste?',
      message:
          'Prism forgets ${learned == 1 ? 'the 1 thing' : 'the $learned things'} it learned from what you viewed and saved. Your feed uses your chosen interests again. This cannot be undone.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await store.clear();
    } catch (error) {
      logger.w('Clearing learned taste failed.', error: error);
      toasts.error("Couldn't clear learned taste. Try again.");
      return;
    }
    personalizedFeedSettingsRevision.value += 1;
    toasts.success('Learned taste cleared.');
  }

  List<Widget> _adminRows() => <Widget>[
    PrismRow(
      icon: Icons.bug_report_rounded,
      title: 'Debug panel',
      subtitle: 'Logs, network, tools and storage',
      onTap: () => context.router.pushPath('/debug-panel'),
    ),
    PrismRow(
      icon: Icons.shield_rounded,
      title: 'Admin moderation',
      subtitle: 'Review submitted content',
      onTap: () => context.router.push(AdminReviewRoute()),
    ),
    PrismRow(
      icon: Icons.analytics_rounded,
      title: 'Firestore telemetry',
      subtitle: 'Database usage and stats',
      onTap: () => context.router.push(const FirestoreTelemetryRoute()),
    ),
  ];

  List<Widget> _helpRows() => <Widget>[
    PrismRow(
      icon: Icons.report_problem_outlined,
      title: 'Report a problem',
      subtitle: 'Share your app logs with the Prism team',
      onTap: () {
        _trackRow('report_a_problem');
        unawaited(showReportProblemSheet(context, source: 'settings'));
      },
    ),
    PrismRow(icon: Icons.info_rounded, title: 'About Prism', onTap: () => context.router.push(AboutRoute())),
  ];

  List<Widget> _sessionRows() => <Widget>[
    PrismRow(icon: Icons.logout_rounded, title: 'Log out', showChevron: false, onTap: _confirmLogOut),
    PrismRow(
      icon: Icons.delete_forever_rounded,
      title: 'Delete account',
      destructive: true,
      showChevron: false,
      onTap: _confirmDeleteAccount,
    ),
  ];

  Future<void> _confirmLogOut() async {
    final bool ok = await showPrismConfirm(
      context,
      title: 'Log out?',
      message: logoutConfirmMessage,
      confirmLabel: 'Log out',
    );
    if (!ok || !mounted) return;
    await _logout();
  }

  Future<void> _logout() async {
    _trackSettingsAction(AnalyticsActionValue.logoutTapped);
    try {
      final bool signedOut = await settingsSignOut();
      _trackSettingsAuthResult(
        action: AnalyticsActionValue.logoutTapped,
        result: signedOut ? EventResultValue.success : EventResultValue.failure,
        reason: signedOut ? null : AnalyticsReasonValue.error,
      );
      if (!signedOut) {
        toasts.error(logoutFailedMessage);
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
      toasts.error(logoutFailedMessage);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final bool premium = app_state.prismUser.premium;
    final bool? ok = await showPrismSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => PrismSheetBody(
        title: 'Delete your account?',
        message:
            'This will permanently delete your account, remove your personal data, and sign you out.\n\nYour uploaded wallpapers will remain visible as "Deleted Account".\n\nThis action cannot be undone.',
        mood: GlintMood.sad,
        centered: true,
        actions: <Widget>[
          PrismButton(
            label: 'Delete account',
            expand: true,
            variant: PrismButtonVariant.danger,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          PrismButton(
            label: 'Cancel',
            expand: true,
            variant: PrismButtonVariant.ghost,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
        child: Column(
          children: <Widget>[
            Text(
              deleteAccountReauthNote,
              textAlign: TextAlign.center,
              style: PrismTextStyles.body(sheetContext).copyWith(height: 1.4),
            ),
            if (premium) ...<Widget>[
              const SizedBox(height: PrismSpace.sm),
              Text(
                'Your store subscription is not cancelled when you delete your account. '
                'It keeps billing until you cancel it in the store.',
                textAlign: TextAlign.center,
                style: PrismTextStyles.body(sheetContext).copyWith(height: 1.4),
              ),
              TextButton(onPressed: _openManageSubscription, child: const Text('Manage subscription')),
            ],
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    final NavigatorState rootNavigator = Navigator.of(context, rootNavigator: true);
    unawaited(
      showPrismSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        useRootNavigator: true,
        builder: (_) => const PopScope(
          canPop: false,
          child: PrismSheetBody(mood: GlintMood.curious, centered: true, title: 'Deleting your account'),
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
        toasts.error('Please select the account you are currently signed in with.');
        return;
      }
      logger.e('Delete account failed.', error: error);
      final String message = error.toString().contains('requires-recent-login')
          ? 'Please sign out and sign in again, then try deleting your account.'
          : 'Something went wrong. Try again.';
      toasts.error(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool loggedIn = app_state.prismUser.loggedIn;
    return PrismPage(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xxxl),
        children: <Widget>[
          SettingsAccountCard(
            onSignIn: _signIn,
            onOpenProfile: () => context.router.push(ProfileRoute(profileIdentifier: app_state.prismUser.email)),
          ),
          if (loggedIn) _group('Account', _accountRows()),
          _group('Appearance', _appearanceRows()),
          if (_isAndroid || _iosShortcuts) _group('Personalise', _personaliseRows()),
          _group('Content', _contentRows()),
          _group('Notifications', _notificationRows()),
          _group('Storage', _storageRows()),
          _group('Purchases', _purchaseRows()),
          _group('Privacy and data', _privacyRows()),
          if (app_state.isAdminUser()) _group('Admin', _adminRows()),
          _group('Help', _helpRows()),
          if (loggedIn) ...<Widget>[const SizedBox(height: PrismSpace.xl), PrismGroup(children: _sessionRows())],
        ],
      ),
    );
  }
}
