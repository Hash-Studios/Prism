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
import 'package:Prism/core/motion/prism_motion.dart';
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
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/core/heading_chip_bar.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_sheet_chrome.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/in_app_notifications/views/widgets/notification_settings_sheet.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart'
    show personalizedFeedSettingsRevision;
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/features/quick_tiles/data/quick_tile_defaults.dart';
import 'package:Prism/features/session/data/low_data_mode.dart';
import 'package:Prism/features/session/views/widgets/report_problem_sheet.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:animations/animations.dart';
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
    for (final String name in <String>['libCachedImageData', 'prism_images', 'prism_full']) {
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
  int? _imageCacheSize;
  int? _downloads;

  @override
  void initState() {
    super.initState();
    _showAnime = animeEnabledFromCategories(_settingsLocal.get<int>('WHcategories', defaultValue: 100));
    _showSketchy = _settingsLocal.get<int>('WHpurity', defaultValue: 100) == 110;
    final String storedTarget = _settingsLocal.get<String>(PersistenceKeys.defaultApplyTarget, defaultValue: 'ask');
    _defaultApplyTarget = _applyTargetLabels.containsKey(storedTarget) ? storedTarget : 'ask';
    _loadStorageStats();
    unawaited(_loadAdPrivacyChoices());
  }

  Future<void> _loadAdPrivacyChoices() async {
    final bool required = await AdConsent.instance.privacyOptionsRequired();
    if (!mounted || !required) return;
    setState(() => _adPrivacyChoices = true);
  }

  Future<void> _loadStorageStats() async {
    final int? images = await _imageCacheBytes();
    final int? downloads = await _downloadsCount();
    if (!mounted) return;
    setState(() {
      _imageCacheSize = images;
      _downloads = downloads;
    });
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

  Color get _accentColor => Theme.of(context).colorScheme.error;

  Color get _destructiveColor => PrismColors.destructive(Theme.of(context).brightness);

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card(
        color: Theme.of(context).cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: _accentColor,
                  fontFamily: 'Proxima Nova',
                ),
              ),
            ),
            ...children,
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  TextStyle get _titleStyle => TextStyle(
    color: Theme.of(context).colorScheme.secondary,
    fontWeight: FontWeight.w500,
    fontFamily: 'Proxima Nova',
  );

  static const TextStyle _subtitleStyle = TextStyle(fontSize: 12);

  Widget _appearanceSection() {
    return _sectionCard(
      title: 'APPEARANCE',
      children: [
        ListTile(
          leading: const Icon(JamIcons.wrench),
          title: Text('Themes', style: _titleStyle),
          subtitle: const Text('Accent colours, light and dark themes', style: _subtitleStyle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.router.push(const ThemeViewRoute()),
        ),
        SwitchListTile(
          activeThumbColor: _accentColor,
          secondary: const Icon(Icons.vibration_rounded),
          value: _haptics,
          title: Text('Haptic feedback', style: _titleStyle),
          subtitle: const Text('Vibrate on taps and actions', style: _subtitleStyle),
          onChanged: (value) {
            setState(() => _haptics = value);
            PrismHaptics.enabled = value;
            PrismHaptics.selection();
            _settingsLocal.set(PrismHaptics.settingsKey, value);
            _trackSettingsToggle(SettingValue.haptics, value);
          },
        ),
      ],
    );
  }

  Widget _contentFiltersSection() {
    return _sectionCard(
      title: 'CONTENT FILTERS',
      children: [
        SwitchListTile(
          activeThumbColor: _accentColor,
          secondary: const Icon(JamIcons.picture),
          value: _showAnime,
          title: Text('Show anime wallpapers', style: _titleStyle),
          subtitle: Text(
            _showAnime ? 'Disable to hide anime wallpapers' : 'Enable to show anime wallpapers',
            style: _subtitleStyle,
          ),
          onChanged: (value) {
            PrismHaptics.selection();
            setState(() => _showAnime = value);
            _applyContentFilter('WHcategories', categoriesForAnime(value));
            _trackSettingsToggle(SettingValue.animeWallpapers, value);
          },
        ),
        // App Store review: no sketchy content toggle on iOS, purity is forced SFW-only.
        if (!Platform.isIOS)
          SwitchListTile(
            activeThumbColor: _accentColor,
            secondary: const Icon(JamIcons.stop_sign),
            value: _showSketchy,
            title: Text('Show sketchy wallpapers', style: _titleStyle),
            subtitle: Text(
              _showSketchy ? 'Disable to hide sketchy wallpapers' : 'Enable to show sketchy wallpapers',
              style: _subtitleStyle,
            ),
            onChanged: (value) {
              PrismHaptics.selection();
              setState(() => _showSketchy = value);
              _applyContentFilter('WHpurity', value ? 110 : 100);
              _trackSettingsToggle(SettingValue.sketchyWallpapers, value);
            },
          ),
      ],
    );
  }

  Future<void> _applyContentFilter(String key, int value) async {
    await _settingsLocal.set(key, value);
    if (key == 'WHcategories' && defaultTargetPlatform == TargetPlatform.android) {
      await QuickTileDefaults.mirrorWallhavenCategories(_settingsLocal);
    }
    personalizedFeedSettingsRevision.value += 1;
    if (!mounted) return;
    context.read<CategoryFeedBloc>().add(const CategoryFeedEvent.refreshRequested());
  }

  Widget _notificationsSection() {
    return _sectionCard(
      title: 'NOTIFICATIONS',
      children: [
        ListTile(
          leading: const Icon(Icons.notifications_none_rounded),
          title: Text('Notification preferences', style: _titleStyle),
          subtitle: const Text('Wall of the Day, followers, posts and more', style: _subtitleStyle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showNotificationSettingsSheet(context),
        ),
      ],
    );
  }

  Widget _personaliseSection() {
    final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;
    return _sectionCard(
      title: 'PERSONALISE',
      children: [
        if (isAndroid)
          ListTile(
            leading: const Icon(Icons.autorenew_rounded),
            title: Text('Auto-rotate wallpapers', style: _titleStyle),
            subtitle: const Text('Change your wallpaper on a timer', style: _subtitleStyle),
            trailing: const Icon(Icons.chevron_right_rounded),
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
        if (isAndroid)
          ListTile(
            leading: const Icon(Icons.motion_photos_on_outlined),
            title: Text('Live wallpapers', style: _titleStyle),
            subtitle: const Text('Moving gradients, motion and video', style: _subtitleStyle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.router.push(LiveWallpaperRoute()),
          ),
        if (isAndroid)
          ListTile(
            leading: const Icon(Icons.grid_view_rounded),
            title: Text('Quick tiles', style: _titleStyle),
            subtitle: const Text('Configure Android Quick Settings tiles', style: _subtitleStyle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.router.push(const QuickTileSettingsRoute()),
          ),
        if (isAndroid)
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: Text('Wallpaper history', style: _titleStyle),
            subtitle: const Text('Wallpapers you set before', style: _subtitleStyle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.router.push(const WallpaperHistoryRoute()),
          ),
        if (isAndroid)
          ListTile(
            leading: const Icon(Icons.wallpaper_rounded),
            title: Text('Default action for Set', style: _titleStyle),
            subtitle: Text(_applyTargetLabels[_defaultApplyTarget]!, style: _subtitleStyle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _showDefaultApplyTargetSheet,
          ),
      ],
    );
  }

  void _showDefaultApplyTargetSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).primaryColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      sheetAnimationStyle: AnimationStyle(
        duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
        reverseDuration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
        curve: PrismCurves.enter,
        reverseCurve: PrismCurves.exit,
      ),
      builder: (ctx) {
        return RadioGroup<String>(
          groupValue: _defaultApplyTarget,
          onChanged: (target) {
            if (target == null) return;
            PrismHaptics.selection();
            setState(() => _defaultApplyTarget = target);
            _settingsLocal.set(PersistenceKeys.defaultApplyTarget, target);
            Navigator.pop(ctx);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AiSheetDragHandle(),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Default action for Set',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(color: Theme.of(ctx).colorScheme.secondary),
                  ),
                ),
                for (final MapEntry<String, String> option in _applyTargetLabels.entries)
                  RadioListTile<String>(
                    value: option.key,
                    activeColor: _accentColor,
                    title: Text(option.value, style: _titleStyle),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _storageSection() {
    return _sectionCard(
      title: 'STORAGE',
      children: [
        SwitchListTile(
          activeThumbColor: _accentColor,
          secondary: const Icon(Icons.data_saver_on_rounded),
          value: _lowData,
          title: Text('Data saver', style: _titleStyle),
          subtitle: const Text(
            'Saves mobile data. Wallpapers open as thumbnails, feeds do not load ahead and carousels do not autoplay.',
            style: _subtitleStyle,
          ),
          onChanged: (value) {
            PrismHaptics.selection();
            setState(() => _lowData = value);
            unawaited(LowDataMode.set(value));
            unawaited(analytics.track(DataSaverToggledEvent(value: value)));
          },
        ),
        ListTile(
          leading: const Icon(JamIcons.pie_chart_alt),
          title: Text('Clear cache', style: _titleStyle),
          subtitle: Text(
            _imageCacheSize == null
                ? 'Clear locally cached images'
                : '${formatStorageBytes(_imageCacheSize!)} of cached images',
            style: _subtitleStyle,
          ),
          onTap: _clearCache,
        ),
        ListTile(
          leading: const Icon(JamIcons.trash_alt),
          title: Text('Clear all downloads', style: _titleStyle),
          subtitle: Text(
            _downloads == null
                ? 'Remove all downloaded wallpapers'
                : _downloads == 0
                ? 'No downloaded wallpapers'
                : '$_downloads downloaded ${_downloads == 1 ? 'wallpaper' : 'wallpapers'}',
            style: _subtitleStyle,
          ),
          onTap: _showClearDownloadsDialog,
        ),
      ],
    );
  }

  Future<void> _clearCache() async {
    _trackSettingsAction(AnalyticsActionValue.clearCacheTapped);
    final int? size = _imageCacheSize;
    final bool confirmed = await _confirmDestructive(
      title: 'Clear cache?',
      message: size == null
          ? 'Cached images are removed. They load again when you need them.'
          : '${formatStorageBytes(size)} of cached images are removed. They load again when you need them.',
      confirmLabel: 'Clear cache',
    );
    if (!confirmed) return;
    final int? before = await _imageCacheBytes();
    await _cacheMaintenance.clearTransientCache();
    final int? after = await _imageCacheBytes();
    final int freed = (before ?? 0) - (after ?? 0);
    toasts.success(freed > 0 ? 'Cleared ${formatStorageBytes(freed)}.' : 'Cache cleared.');
    if (mounted) setState(() => _imageCacheSize = after);
  }

  Future<void> _showClearDownloadsDialog() async {
    final int? count = _downloads;
    final bool confirmed = await _confirmDestructive(
      title: 'Delete all downloads?',
      message: count != null && count > 0
          ? '${count == 1 ? '1 downloaded wallpaper is' : '$count downloaded wallpapers are'} deleted from this device. This cannot be undone.'
          : 'All downloaded wallpapers are deleted from this device. This cannot be undone.',
      confirmLabel: 'Delete all',
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

  /// A confirm dialog for an action that removes data. Resolves to true only on the confirm button.
  Future<bool> _confirmDestructive({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final bool? confirmed = await showModal<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel, style: TextStyle(color: _destructiveColor)),
          ),
        ],
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
    return confirmed ?? false;
  }

  Widget _accountSection() {
    if (!app_state.prismUser.loggedIn) {
      return _sectionCard(
        title: 'ACCOUNT',
        children: [
          ListTile(
            leading: const Icon(JamIcons.log_in),
            title: Text('Sign in', style: _titleStyle),
            subtitle: const Text(signInBenefitsLine, style: _subtitleStyle),
            onTap: () {
              _trackSettingsAction(AnalyticsActionValue.signInTapped);
              // Routes through the shared popup so Apple is offered alongside Google.
              googleSignInPopUp(context, () {
                _trackSettingsAuthResult(action: AnalyticsActionValue.signInTapped, result: EventResultValue.success);
                main.RestartWidget.restartApp(context);
              });
            },
          ),
        ],
      );
    }

    return _sectionCard(
      title: 'ACCOUNT',
      children: [
        ListTile(
          leading: CircleAvatar(
            radius: 16,
            backgroundImage: app_state.prismUser.profilePhoto.isNotEmpty
                ? NetworkImage(app_state.prismUser.profilePhoto)
                : null,
            child: app_state.prismUser.profilePhoto.isEmpty ? const Icon(Icons.person, size: 16) : null,
          ),
          title: Text(app_state.prismUser.name, style: _titleStyle),
          subtitle: Text(app_state.prismUser.email, style: _subtitleStyle),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
          leading: const Icon(JamIcons.check),
          title: Text('Review status', style: _titleStyle),
          subtitle: const Text('Track your submitted wallpaper reviews', style: _subtitleStyle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.router.push(const ReviewRoute()),
        ),
        ListTile(
          leading: const Icon(JamIcons.user_remove),
          title: Text('Blocked accounts', style: _titleStyle),
          subtitle: const Text('Manage users you have blocked', style: _subtitleStyle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.router.push(const BlockedAccountsRoute()),
        ),
        ListTile(
          leading: const Icon(JamIcons.share_alt),
          title: Text('Share your profile', style: _titleStyle),
          subtitle: const Text('Share a link to your Prism profile', style: _subtitleStyle),
          onTap: _shareProfile,
        ),
        ListTile(
          leading: const Icon(JamIcons.heart),
          title: Text('Clear favourite wallpapers', style: _titleStyle),
          subtitle: const Text('Remove all favourite wallpapers', style: _subtitleStyle),
          onTap: () {
            _trackSettingsAction(AnalyticsActionValue.clearFavouriteWallsTapped);
            unawaited(_showClearFavWallsDialog());
          },
        ),
        ListTile(
          leading: Icon(JamIcons.log_out, color: _accentColor),
          title: Text('Log out', style: _titleStyle.copyWith(color: _accentColor)),
          subtitle: Text(app_state.prismUser.email, style: _subtitleStyle),
          onTap: _showLogoutDialog,
        ),
      ],
    );
  }

  Future<void> _shareProfile() async {
    try {
      await createUserDynamicLink(
        app_state.prismUser.name,
        app_state.prismUser.username,
        app_state.prismUser.email,
        app_state.prismUser.bio,
        app_state.prismUser.profilePhoto,
        context: context,
      );
    } catch (error, stackTrace) {
      logger.w('Sharing the profile link failed.', error: error, stackTrace: stackTrace);
      toasts.error("Couldn't create the link. Try again.");
    }
  }

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

  void _showLogoutDialog() {
    showModal(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        title: const Text('Log out?'),
        content: const Text(logoutConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              unawaited(_logout());
            },
            child: const Text('Log out'),
          ),
        ],
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
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

  Future<void> _showClearFavWallsDialog() async {
    int? count;
    try {
      count = (await context.favouriteWallsAdapter(listen: false).getDataBase())?.length;
    } catch (error) {
      logger.w('Counting favourites failed.', error: error);
    }
    if (!mounted) return;
    final bool confirmed = await _confirmDestructive(
      title: 'Clear all favourites?',
      message: count != null && count > 0
          ? '${count == 1 ? '1 favourite wallpaper is' : '$count favourite wallpapers are'} removed from your account. This cannot be undone.'
          : 'All your favourite wallpapers are removed from your account. This cannot be undone.',
      confirmLabel: 'Clear favourites',
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

  void _showDeleteAccountDialog() {
    showModal(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        title: Text('Delete account', style: _titleStyle.copyWith(color: _destructiveColor)),
        content: SizedBox(
          width: 250,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will permanently delete your account, remove your personal data, and sign you out.\n\nYour uploaded wallpapers will remain visible as "Deleted Account".\n\nThis action cannot be undone.',
                ),
                const SizedBox(height: 12),
                const Text(deleteAccountReauthNote),
                if (app_state.prismUser.premium) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Your store subscription is not cancelled when you delete your account. '
                    'It keeps billing until you cancel it in the store.',
                  ),
                  TextButton(
                    onPressed: _openManageSubscription,
                    child: Text('Manage subscription', style: TextStyle(color: _accentColor)),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              unawaited(_deleteAccount());
            },
            child: Text('Delete account', style: TextStyle(color: _destructiveColor)),
          ),
        ],
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final NavigatorState rootNavigator = Navigator.of(context, rootNavigator: true);
    final loaderDialog = Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Theme.of(context).primaryColor),
        width: MediaQuery.of(context).size.width * .7,
        height: MediaQuery.of(context).size.height * .3,
        child: const GlintState(kind: GlintStateKind.loading, title: 'Deleting account...'),
      ),
    );
    unawaited(
      showDialog<void>(
        barrierDismissible: false,
        context: context,
        builder: (_) => PopScope(canPop: false, child: loaderDialog),
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

  Widget _premiumSection() {
    final bool premium = app_state.prismUser.premium;
    return _sectionCard(
      title: 'PREMIUM',
      children: [
        if (!premium)
          ListTile(
            leading: const Icon(JamIcons.instant_picture_f),
            title: Text('Buy premium', style: _titleStyle),
            subtitle: const Text('Get unlimited uploads and filters.', style: _subtitleStyle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              _trackSettingsAction(AnalyticsActionValue.buyPremiumTapped);
              PaywallOrchestrator.instance.presentOrRequireSignIn(
                context,
                placement: PaywallPlacement.mainUpsell,
                source: 'settings_buy_premium',
              );
            },
          ),
        ListTile(
          leading: const Icon(Icons.restore_rounded),
          title: Text('Restore purchases', style: _titleStyle),
          subtitle: const Text('Restore a previously purchased subscription', style: _subtitleStyle),
          onTap: _restoring ? null : _restorePurchases,
        ),
        if (premium)
          ListTile(
            leading: const Icon(Icons.card_membership_rounded),
            title: Text('Manage subscription', style: _titleStyle),
            subtitle: const Text('Change or cancel in the store', style: _subtitleStyle),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: _openManageSubscription,
          ),
      ],
    );
  }

  void _trackRow(String row) {
    unawaited(analytics.track(SettingsRowTappedEvent(row: row)));
  }

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
    final bool confirmed = await _confirmDestructive(
      title: 'Clear learned taste?',
      message:
          'Prism forgets ${learned == 1 ? 'the 1 thing' : 'the $learned things'} it learned from what you viewed and saved. Your feed uses your chosen interests again. This cannot be undone.',
      confirmLabel: 'Clear',
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

  Widget _privacySection() {
    return _sectionCard(
      title: 'PRIVACY AND DATA',
      children: [
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: Text('Privacy policy', style: _titleStyle),
          trailing: const Icon(Icons.open_in_new_rounded),
          onTap: () => _openLink(_privacyUrl, 'privacy_policy'),
        ),
        ListTile(
          leading: const Icon(JamIcons.file),
          title: Text('Terms of use', style: _titleStyle),
          trailing: const Icon(Icons.open_in_new_rounded),
          onTap: () => _openLink(_termsUrl, 'terms'),
        ),
        if (_adPrivacyChoices)
          ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: Text('Ad privacy choices', style: _titleStyle),
            subtitle: const Text('Review or change your ad consent', style: _subtitleStyle),
            onTap: () {
              _trackRow('ad_privacy_choices');
              unawaited(AdConsent.instance.showPrivacyOptions());
            },
          ),
        ListTile(
          leading: const Icon(Icons.auto_awesome_outlined),
          title: Text('Clear learned taste', style: _titleStyle),
          subtitle: const Text('Forget what your feed learned from you', style: _subtitleStyle),
          onTap: _clearLearnedTaste,
        ),
        ListTile(
          leading: const Icon(Icons.file_download_outlined),
          title: Text('Export favourites', style: _titleStyle),
          subtitle: const Text('Save a copy of your favourites as a file', style: _subtitleStyle),
          onTap: () {
            _trackRow('export_favourites');
            context.router.push(LibraryRoute());
          },
        ),
        if (app_state.prismUser.loggedIn)
          ListTile(
            leading: Icon(Icons.delete_forever_rounded, color: _destructiveColor),
            title: Text('Delete account', style: _titleStyle.copyWith(color: _destructiveColor)),
            subtitle: const Text('Permanently delete your account and data', style: _subtitleStyle),
            onTap: _showDeleteAccountDialog,
          ),
      ],
    );
  }

  Widget _adminSection() {
    if (!app_state.isAdminUser()) return const SizedBox.shrink();
    return _sectionCard(
      title: 'ADMIN',
      children: [
        ListTile(
          leading: const Icon(Icons.bug_report_outlined),
          title: Text('Debug panel', style: _titleStyle),
          subtitle: const Text('Logs, network, tools, storage inspector', style: _subtitleStyle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.router.pushPath('/debug-panel'),
        ),
        ListTile(
          leading: const Icon(JamIcons.shield_check),
          title: Text('Admin moderation', style: _titleStyle),
          subtitle: const Text('Review and moderate submitted content', style: _subtitleStyle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.router.push(AdminReviewRoute()),
        ),
        ListTile(
          leading: const Icon(JamIcons.file),
          title: Text('Firestore telemetry', style: _titleStyle),
          subtitle: const Text('Database usage and telemetry stats', style: _subtitleStyle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.router.push(const FirestoreTelemetryRoute()),
        ),
      ],
    );
  }

  Widget _helpSection() {
    return _sectionCard(
      title: 'HELP',
      children: [
        ListTile(
          leading: const Icon(Icons.report_problem_outlined),
          title: Text('Report a problem', style: _titleStyle),
          subtitle: const Text('Share your app logs with the Prism team', style: _subtitleStyle),
          onTap: () {
            _trackRow('report_a_problem');
            unawaited(showReportProblemSheet(context, source: 'settings'));
          },
        ),
        ListTile(
          leading: const Icon(JamIcons.info),
          title: Text('About Prism', style: _titleStyle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.router.push(const AboutRoute()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: const PreferredSize(
        preferredSize: Size(double.infinity, 55),
        child: HeadingChipBar(current: 'Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          _appearanceSection(),
          if (defaultTargetPlatform == TargetPlatform.android) _personaliseSection(),
          _contentFiltersSection(),
          _notificationsSection(),
          _storageSection(),
          _accountSection(),
          _premiumSection(),
          _privacySection(),
          _adminSection(),
          _helpSection(),
        ],
      ),
    );
  }
}
