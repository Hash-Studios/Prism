import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/google_auth.dart' show WrongAccountException;
import 'package:Prism/core/account/delete_account_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/cache_maintenance_service.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/state/auth_runtime.dart';
import 'package:Prism/core/widgets/home/core/heading_chip_bar.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_sheet_chrome.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:animations/animations.dart';
import 'package:auto_route/auto_route.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

enum _DownloadQuality {
  original('Original', 'Full resolution, larger file size'),
  compressed('Compressed', 'Smaller file size, slightly reduced quality');

  const _DownloadQuality(this.title, this.subtitle);

  final String title;
  final String subtitle;

  static _DownloadQuality fromName(String name) =>
      values.firstWhere((quality) => quality.name == name, orElse: () => original);
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

  static final Color _destructiveColor = Colors.red[400]!;

  late bool _showAnime;
  late bool _showSketchy;
  late bool _notifWotd;
  late bool _notifPromo;
  bool _restoring = false;
  late _DownloadQuality _downloadQuality;

  @override
  void initState() {
    super.initState();
    _showAnime = _settingsLocal.get<int>('WHcategories', defaultValue: 100) == 111;
    _showSketchy = _settingsLocal.get<int>('WHpurity', defaultValue: 100) == 110;
    _notifWotd = _settingsLocal.get<bool>(PersistenceKeys.notifWotd, defaultValue: true);
    _notifPromo = _settingsLocal.get<bool>('recommendationsSubscriber', defaultValue: true);
    _downloadQuality = _DownloadQuality.fromName(
      _settingsLocal.get<String>(PersistenceKeys.downloadQuality, defaultValue: _DownloadQuality.original.name),
    );
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

  Color get _accentColor {
    final c = Theme.of(context).colorScheme.error;
    return c == Colors.black ? Colors.grey : c;
  }

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
          subtitle: const Text('Accent colours, light & dark themes', style: _subtitleStyle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.router.push(const ThemeViewRoute()),
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
          title: Text('Show Anime Wallpapers', style: _titleStyle),
          subtitle: Text(
            _showAnime ? 'Disable to hide anime wallpapers' : 'Enable to show anime wallpapers',
            style: _subtitleStyle,
          ),
          onChanged: (value) {
            setState(() => _showAnime = value);
            _settingsLocal.set('WHcategories', value ? 111 : 100);
            _trackSettingsToggle(SettingValue.animeWallpapers, value);
          },
        ),
        // App Store review: no sketchy content toggle on iOS, purity is forced SFW-only.
        if (!Platform.isIOS)
          SwitchListTile(
            activeThumbColor: _accentColor,
            secondary: const Icon(JamIcons.stop_sign),
            value: _showSketchy,
            title: Text('Show Sketchy Wallpapers', style: _titleStyle),
            subtitle: Text(
              _showSketchy ? 'Disable to hide sketchy wallpapers' : 'Enable to show sketchy wallpapers',
              style: _subtitleStyle,
            ),
            onChanged: (value) {
              setState(() => _showSketchy = value);
              _settingsLocal.set('WHpurity', value ? 110 : 100);
              _trackSettingsToggle(SettingValue.sketchyWallpapers, value);
            },
          ),
        ListTile(
          leading: const Icon(Icons.high_quality_outlined),
          title: Text('Download Quality', style: _titleStyle),
          subtitle: Text(
            _downloadQuality == _DownloadQuality.original ? 'Original resolution' : 'Compressed',
            style: _subtitleStyle,
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _showDownloadQualitySheet,
        ),
      ],
    );
  }

  void _showDownloadQualitySheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).primaryColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return RadioGroup<_DownloadQuality>(
          groupValue: _downloadQuality,
          onChanged: (quality) {
            if (quality == null) return;
            setState(() => _downloadQuality = quality);
            _settingsLocal.set(PersistenceKeys.downloadQuality, quality.name);
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
                  child: Text('Download Quality', style: Theme.of(ctx).textTheme.titleMedium),
                ),
                for (final quality in _DownloadQuality.values)
                  RadioListTile<_DownloadQuality>(
                    value: quality,
                    activeColor: _accentColor,
                    title: Text(quality.title, style: _titleStyle),
                    subtitle: Text(quality.subtitle, style: _subtitleStyle),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _notificationsSection() {
    return _sectionCard(
      title: 'NOTIFICATIONS',
      children: [
        SwitchListTile(
          activeThumbColor: _accentColor,
          secondary: const Icon(Icons.wb_sunny_outlined),
          value: _notifWotd,
          title: Text('Wall of the Day', style: _titleStyle),
          subtitle: const Text('Daily wallpaper recommendation alert', style: _subtitleStyle),
          onChanged: (value) {
            setState(() => _notifWotd = value);
            _settingsLocal.set(PersistenceKeys.notifWotd, value);
            _setTopic('wall_of_the_day', value);
          },
        ),
        SwitchListTile(
          activeThumbColor: _accentColor,
          secondary: const Icon(Icons.campaign_outlined),
          value: _notifPromo,
          title: Text('Promotional Alerts', style: _titleStyle),
          subtitle: const Text('New features, events & announcements', style: _subtitleStyle),
          onChanged: (value) {
            setState(() => _notifPromo = value);
            _settingsLocal.set('recommendationsSubscriber', value);
            _trackSettingsToggle(SettingValue.recommendationsNotifications, value);
            _setTopic('recommendations', value);
          },
        ),
      ],
    );
  }

  void _setTopic(String topic, bool subscribed) {
    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    final String sourceTag = 'settings.$topic.${subscribed ? 'enable' : 'disable'}';
    unawaited(
      subscribed
          ? subscribeToTopicSafely(messaging, topic, sourceTag: sourceTag)
          : unsubscribeFromTopicSafely(messaging, topic, sourceTag: sourceTag),
    );
  }

  Widget _androidWidgetsSection() {
    return _sectionCard(
      title: 'ANDROID WIDGETS',
      children: [
        ListTile(
          leading: const Icon(Icons.grid_view_rounded),
          title: Text('Quick Tile Settings', style: _titleStyle),
          subtitle: const Text('Configure Android Quick Settings tiles', style: _subtitleStyle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.router.push(const QuickTileSettingsRoute()),
        ),
      ],
    );
  }

  Widget _storageSection() {
    return _sectionCard(
      title: 'STORAGE',
      children: [
        ListTile(
          leading: const Icon(JamIcons.pie_chart_alt),
          title: Text('Clear Cache', style: _titleStyle),
          subtitle: const Text('Clear locally cached images', style: _subtitleStyle),
          onTap: () async {
            _trackSettingsAction(AnalyticsActionValue.clearCacheTapped);
            await _cacheMaintenance.clearTransientCache();
            toasts.success('Cleared cache!');
          },
        ),
        ListTile(
          leading: const Icon(JamIcons.trash_alt),
          title: Text('Clear all Downloads', style: _titleStyle),
          subtitle: const Text('Remove all downloaded wallpapers', style: _subtitleStyle),
          onTap: () => _showClearDownloadsDialog(),
        ),
      ],
    );
  }

  void _showClearDownloadsDialog() {
    _showYesNoDialog('Do you want to remove all your downloads?', () async {
      bool deleted = false;
      try {
        final result = await PrismMediaHostApi().clearDownloads();
        deleted = result.success;
      } catch (e) {
        logger.w('Clearing downloads failed.', error: e);
      }
      if (deleted) {
        toasts.success('Deleted all downloads!');
      } else {
        toasts.error('No downloads found.');
      }
    });
  }

  void _showYesNoDialog(String message, FutureOr<void> Function() onYes) {
    showModal(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        content: SizedBox(height: 50, width: 250, child: Center(child: Text(message))),
        actions: [
          MaterialButton(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            onPressed: () {
              Navigator.of(ctx).pop();
              onYes();
            },
            child: Text('YES', style: TextStyle(fontSize: 16.0, color: _accentColor)),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: MaterialButton(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              color: _accentColor,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('NO', style: TextStyle(fontSize: 16.0, color: Colors.white)),
            ),
          ),
        ],
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _accountSection() {
    if (!app_state.prismUser.loggedIn) {
      return _sectionCard(
        title: 'ACCOUNT',
        children: [
          ListTile(
            leading: const Icon(JamIcons.log_in),
            title: Text('Sign in', style: _titleStyle),
            subtitle: const Text('Sign in to sync data across devices', style: _subtitleStyle),
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
          title: Text('Review Status', style: _titleStyle),
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
          title: Text('Share your Profile', style: _titleStyle),
          subtitle: const Text('Share a link to your Prism profile', style: _subtitleStyle),
          onTap: () => createUserDynamicLink(
            app_state.prismUser.name,
            app_state.prismUser.username,
            app_state.prismUser.email,
            app_state.prismUser.bio,
            app_state.prismUser.profilePhoto,
            context: context,
          ),
        ),
        ListTile(
          leading: const Icon(JamIcons.heart),
          title: Text('Clear favourite walls', style: _titleStyle),
          subtitle: const Text('Remove all favourite wallpapers', style: _subtitleStyle),
          onTap: () {
            _trackSettingsAction(AnalyticsActionValue.clearFavouriteWallsTapped);
            _showClearFavWallsDialog();
          },
        ),
        ListTile(
          leading: const Icon(Icons.restore_rounded),
          title: Text('Restore Purchases', style: _titleStyle),
          subtitle: const Text('Restore a previously purchased subscription', style: _subtitleStyle),
          onTap: _restoring
              ? null
              : () async {
                  _trackSettingsAction(AnalyticsActionValue.restorePurchaseTapped);
                  setState(() => _restoring = true);
                  toasts.success('Restoring purchases…');
                  try {
                    final bool premium = await PurchasesService.instance.restore();
                    premium
                        ? toasts.success('Purchases restored!')
                        : toasts.error('No purchases to restore for this account.');
                  } catch (e) {
                    toasts.error('Could not restore purchases. Please try again.');
                  } finally {
                    if (mounted) setState(() => _restoring = false);
                  }
                },
        ),
        ListTile(
          leading: Icon(Icons.delete_forever_rounded, color: _destructiveColor),
          title: Text('Delete Account', style: _titleStyle.copyWith(color: _destructiveColor)),
          subtitle: const Text('Permanently delete your account and data', style: _subtitleStyle),
          onTap: () => _showDeleteAccountDialog(),
        ),
        ListTile(
          leading: Icon(JamIcons.log_out, color: _accentColor),
          title: Text('Logout', style: _titleStyle.copyWith(color: _accentColor)),
          subtitle: Text(app_state.prismUser.email, style: _subtitleStyle),
          onTap: () async {
            _trackSettingsAction(AnalyticsActionValue.logoutTapped);
            try {
              final bool signedOut = await globalGoogleAuth.signOutGoogle();
              _trackSettingsAuthResult(
                action: AnalyticsActionValue.logoutTapped,
                result: signedOut ? EventResultValue.success : EventResultValue.failure,
                reason: signedOut ? null : AnalyticsReasonValue.error,
              );
              if (signedOut) {
                toasts.success('Log out Successful!');
                await resetOnboardingLocalState(_settingsLocal);
                if (context.mounted) {
                  // ignore: use_build_context_synchronously
                  main.RestartWidget.restartApp(context);
                }
              }
            } catch (error, stackTrace) {
              logger.e('Sign out failed from settings.', error: error, stackTrace: stackTrace);
              _trackSettingsAuthResult(
                action: AnalyticsActionValue.logoutTapped,
                result: EventResultValue.failure,
                reason: AnalyticsReasonValue.error,
              );
              toasts.error('Something went wrong, please try again!');
            }
          },
        ),
      ],
    );
  }

  void _showClearFavWallsDialog() {
    _showYesNoDialog('Do you want to remove all your favourite wallpapers?', () {
      _trackSettingsAction(AnalyticsActionValue.clearFavouriteWallsConfirmed);
      toasts.error('Cleared all favourite wallpapers!');
      context.favouriteWallsAdapter(listen: false).deleteData();
    });
  }

  void _showDeleteAccountDialog() {
    showModal(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        title: Text('Delete Account', style: _titleStyle.copyWith(color: _destructiveColor)),
        content: const SizedBox(
          width: 250,
          child: Text(
            'This will permanently delete your account, remove your personal data, and sign you out.\n\nYour uploaded wallpapers and setups will remain visible as "Deleted Account".\n\nThis action cannot be undone.',
          ),
        ),
        actions: [
          MaterialButton(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            color: _destructiveColor,
            onPressed: () async {
              Navigator.of(ctx).pop();
              final loaderDialog = Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Theme.of(context).primaryColor,
                  ),
                  width: MediaQuery.of(context).size.width * .7,
                  height: MediaQuery.of(context).size.height * .3,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Deleting account...')],
                    ),
                  ),
                ),
              );
              showDialog(barrierDismissible: false, context: context, builder: (_) => loaderDialog);
              try {
                await DeleteAccountService.instance.deleteAccount();
                if (!mounted) return;
                Navigator.pop(context);
                main.RestartWidget.restartApp(context);
              } catch (error) {
                if (!mounted) return;
                Navigator.pop(context);
                if (error is WrongAccountException) {
                  logger.w('Delete account cancelled: wrong account selected.', error: error);
                  toasts.error('Please select the account you are currently signed in with.');
                  return;
                }
                logger.e('Delete account failed.', error: error);
                final String message = error.toString().contains('requires-recent-login')
                    ? 'Please sign out and sign in again, then try deleting your account.'
                    : 'Something went wrong, please try again.';
                toasts.error(message);
              }
            },
            child: const Text('DELETE', style: TextStyle(fontSize: 16.0, color: Colors.white)),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: MaterialButton(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('CANCEL', style: TextStyle(fontSize: 16.0, color: _accentColor)),
            ),
          ),
        ],
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _premiumSection() {
    if (app_state.prismUser.premium) return const SizedBox.shrink();
    return _sectionCard(
      title: 'PREMIUM',
      children: [
        ListTile(
          leading: const Icon(JamIcons.instant_picture_f),
          title: Text('Buy Premium', style: _titleStyle),
          subtitle: const Text('Get unlimited setups and filters.', style: _subtitleStyle),
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
          title: Text('Debug Panel', style: _titleStyle),
          subtitle: const Text('Logs, network, tools, storage inspector', style: _subtitleStyle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.router.pushPath('/debug-panel'),
        ),
        ListTile(
          leading: const Icon(JamIcons.shield_check),
          title: Text('Admin Moderation', style: _titleStyle),
          subtitle: const Text('Review and moderate submitted content', style: _subtitleStyle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.router.push(const AdminReviewRoute()),
        ),
        ListTile(
          leading: const Icon(JamIcons.file),
          title: Text('Firestore Telemetry', style: _titleStyle),
          subtitle: const Text('Database usage and telemetry stats', style: _subtitleStyle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.router.push(const FirestoreTelemetryRoute()),
        ),
      ],
    );
  }

  Widget _aboutSection() {
    return _sectionCard(
      title: 'ABOUT',
      children: [
        ListTile(
          leading: const Icon(JamIcons.info),
          title: Text('About Prism', style: _titleStyle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.router.push(const AboutRoute()),
        ),
        ListTile(
          leading: const Icon(JamIcons.refresh),
          title: Text('Restart App', style: _titleStyle),
          subtitle: const Text('Force the application to restart', style: _subtitleStyle),
          onTap: () {
            _trackSettingsAction(AnalyticsActionValue.restartAppTapped);
            main.RestartWidget.restartApp(context);
          },
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
          _contentFiltersSection(),
          _notificationsSection(),
          if (Platform.isAndroid) _androidWidgetsSection(),
          _storageSection(),
          _accountSection(),
          _premiumSection(),
          _adminSection(),
          _aboutSection(),
        ],
      ),
    );
  }
}
