import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/cache_maintenance_service.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/home/core/headingChipBar.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:Prism/features/favourite_setups/views/favourite_setups_bloc_adapter.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:animations/animations.dart';
import 'package:auto_route/auto_route.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mailer/flutter_mailer.dart';
import 'package:fluttertoast/fluttertoast.dart';

@RoutePage()
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final CacheMaintenanceService _cacheMaintenance = getIt<CacheMaintenanceService>();
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();

  late int _categories;
  late int _purity;
  late bool _notifWotd;
  late bool _notifPromo;
  late String _downloadQuality;

  @override
  void initState() {
    super.initState();
    _categories = _settingsLocal.get<int>('WHcategories', defaultValue: 100);
    _purity = _settingsLocal.get<int>('WHpurity', defaultValue: 100);
    _notifWotd = _settingsLocal.get<bool>(PersistenceKeys.notifWotd, defaultValue: true);
    _notifPromo = _settingsLocal.get<bool>(PersistenceKeys.notifPromo, defaultValue: true);
    _downloadQuality = _settingsLocal.get<String>(PersistenceKeys.downloadQuality, defaultValue: 'original');
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

  // ── Helpers ─────────────────────────────────────────────────────────────────

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

  // ── Sections ─────────────────────────────────────────────────────────────────

  Widget _appearanceSection() {
    return _sectionCard(
      title: 'APPEARANCE',
      children: [
        ListTile(
          leading: const Icon(JamIcons.wrench),
          title: Text('Themes', style: _titleStyle),
          subtitle: const Text('Accent colours, light & dark themes', style: TextStyle(fontSize: 12)),
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
          activeColor: _accentColor,
          secondary: const Icon(JamIcons.picture),
          value: _categories == 111,
          title: Text('Show Anime Wallpapers', style: _titleStyle),
          subtitle: Text(
            _categories == 111 ? 'Disable to hide anime wallpapers' : 'Enable to show anime wallpapers',
            style: _subtitleStyle,
          ),
          onChanged: (value) {
            setState(() => _categories = value ? 111 : 100);
            _settingsLocal.set('WHcategories', _categories);
            _trackSettingsToggle(SettingValue.animeWallpapers, value);
          },
        ),
        SwitchListTile(
          activeColor: _accentColor,
          secondary: const Icon(JamIcons.stop_sign),
          value: _purity == 110,
          title: Text('Show Sketchy Wallpapers', style: _titleStyle),
          subtitle: Text(
            _purity == 110 ? 'Disable to hide sketchy wallpapers' : 'Enable to show sketchy wallpapers',
            style: _subtitleStyle,
          ),
          onChanged: (value) {
            setState(() => _purity = value ? 110 : 100);
            _settingsLocal.set('WHpurity', _purity);
            _trackSettingsToggle(SettingValue.sketchyWallpapers, value);
          },
        ),
        ListTile(
          leading: const Icon(Icons.high_quality_outlined),
          title: Text('Download Quality', style: _titleStyle),
          subtitle: Text(_downloadQuality == 'original' ? 'Original resolution' : 'Compressed', style: _subtitleStyle),
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
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 4,
                    width: 36,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Theme.of(ctx).hintColor, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('Download Quality', style: Theme.of(ctx).textTheme.titleMedium),
                  ),
                  RadioListTile<String>(
                    value: 'original',
                    groupValue: _downloadQuality,
                    activeColor: _accentColor,
                    title: Text('Original', style: _titleStyle),
                    subtitle: const Text('Full resolution, larger file size', style: TextStyle(fontSize: 12)),
                    onChanged: (v) {
                      setSheetState(() {});
                      setState(() => _downloadQuality = v!);
                      _settingsLocal.set(PersistenceKeys.downloadQuality, v!);
                      Navigator.pop(ctx);
                    },
                  ),
                  RadioListTile<String>(
                    value: 'compressed',
                    groupValue: _downloadQuality,
                    activeColor: _accentColor,
                    title: Text('Compressed', style: _titleStyle),
                    subtitle: const Text('Smaller file size, slightly reduced quality', style: TextStyle(fontSize: 12)),
                    onChanged: (v) {
                      setSheetState(() {});
                      setState(() => _downloadQuality = v!);
                      _settingsLocal.set(PersistenceKeys.downloadQuality, v!);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _notificationsSection() {
    return _sectionCard(
      title: 'NOTIFICATIONS',
      children: [
        SwitchListTile(
          activeColor: _accentColor,
          secondary: const Icon(Icons.wb_sunny_outlined),
          value: _notifWotd,
          title: Text('Wall of the Day', style: _titleStyle),
          subtitle: const Text('Daily wallpaper recommendation alert', style: TextStyle(fontSize: 12)),
          onChanged: (value) {
            setState(() => _notifWotd = value);
            _settingsLocal.set(PersistenceKeys.notifWotd, value);
          },
        ),
        SwitchListTile(
          activeColor: _accentColor,
          secondary: const Icon(Icons.campaign_outlined),
          value: _notifPromo,
          title: Text('Promotional Alerts', style: _titleStyle),
          subtitle: const Text('New features, events & announcements', style: TextStyle(fontSize: 12)),
          onChanged: (value) {
            setState(() => _notifPromo = value);
            _settingsLocal.set(PersistenceKeys.notifPromo, value);
          },
        ),
      ],
    );
  }

  Widget _androidWidgetsSection() {
    return _sectionCard(
      title: 'ANDROID WIDGETS',
      children: [
        ListTile(
          leading: const Icon(Icons.grid_view_rounded),
          title: Text('Quick Tile Settings', style: _titleStyle),
          subtitle: const Text('Configure Android Quick Settings tiles', style: TextStyle(fontSize: 12)),
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
          subtitle: const Text('Clear locally cached images', style: TextStyle(fontSize: 12)),
          onTap: () async {
            _trackSettingsAction(AnalyticsActionValue.clearCacheTapped);
            await _cacheMaintenance.clearTransientCache();
            toasts.codeSend('Cleared cache!');
          },
        ),
        ListTile(
          leading: const Icon(JamIcons.trash_alt),
          title: Text('Clear all Downloads', style: _titleStyle),
          subtitle: const Text('Remove all downloaded wallpapers', style: TextStyle(fontSize: 12)),
          onTap: () => _showClearDownloadsDialog(),
        ),
      ],
    );
  }

  void _showClearDownloadsDialog() {
    showModal(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        content: const SizedBox(
          height: 50,
          width: 250,
          child: Center(child: Text('Do you want to remove all your downloads?')),
        ),
        actions: [
          MaterialButton(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              bool deleted = false;
              try {
                final result = await PrismMediaHostApi().clearDownloads();
                deleted = result.success;
              } catch (e) {
                logger.d(e.toString());
              }
              Fluttertoast.showToast(
                msg: deleted ? 'Deleted all downloads!' : 'No downloads found.',
                toastLength: Toast.LENGTH_LONG,
                textColor: Colors.white,
                backgroundColor: deleted ? Colors.green[400] : Colors.red[400],
              );
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
            subtitle: const Text('Sign in to sync data across devices', style: TextStyle(fontSize: 12)),
            onTap: () async {
              _trackSettingsAction(AnalyticsActionValue.signInTapped);
              final loaderDialog = Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Theme.of(context).primaryColor,
                  ),
                  width: MediaQuery.of(context).size.width * .7,
                  height: MediaQuery.of(context).size.height * .3,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              );
              showDialog(barrierDismissible: false, context: context, builder: (_) => loaderDialog);
              try {
                final String signInResult = await app_state.gAuth.signInWithGoogle();
                if (!mounted) return;
                if (signInResult == GoogleAuth.signInCancelledResult) {
                  Navigator.pop(this.context);
                  app_state.prismUser.loggedIn = false;
                  app_state.persistPrismUser();
                  _trackSettingsAuthResult(
                    action: AnalyticsActionValue.signInTapped,
                    result: EventResultValue.cancelled,
                    reason: AnalyticsReasonValue.userCancelled,
                  );
                  toasts.codeSend('Sign in cancelled.');
                  return;
                }
                toasts.codeSend('Login Successful!');
                _trackSettingsAuthResult(action: AnalyticsActionValue.signInTapped, result: EventResultValue.success);
                app_state.prismUser.loggedIn = true;
                app_state.persistPrismUser();
                Navigator.pop(this.context);
                main.RestartWidget.restartApp(this.context);
              } catch (e) {
                if (!mounted) return;
                logger.d(e);
                Navigator.pop(this.context);
                _trackSettingsAuthResult(
                  action: AnalyticsActionValue.signInTapped,
                  result: EventResultValue.failure,
                  reason: AnalyticsReasonValue.error,
                );
                app_state.prismUser.loggedIn = false;
                app_state.persistPrismUser();
                toasts.error('Something went wrong, please try again!');
              }
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
          subtitle: const Text('Track your submitted wallpaper reviews', style: TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.router.push(const ReviewRoute()),
        ),
        ListTile(
          leading: const Icon(JamIcons.share_alt),
          title: Text('Share your Profile', style: _titleStyle),
          subtitle: const Text('Share a link to your Prism profile', style: TextStyle(fontSize: 12)),
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
          subtitle: const Text('Remove all favourite wallpapers', style: TextStyle(fontSize: 12)),
          onTap: () {
            _trackSettingsAction(AnalyticsActionValue.clearFavouriteWallsTapped);
            _showClearFavWallsDialog();
          },
        ),
        ListTile(
          leading: const Icon(JamIcons.heart),
          title: Text('Clear favourite setups', style: _titleStyle),
          subtitle: const Text('Remove all favourite setups', style: TextStyle(fontSize: 12)),
          onTap: () {
            _trackSettingsAction(AnalyticsActionValue.clearFavouriteSetupsTapped);
            _showClearFavSetupsDialog();
          },
        ),
        ListTile(
          leading: Icon(JamIcons.log_out, color: _accentColor),
          title: Text('Logout', style: _titleStyle.copyWith(color: _accentColor)),
          subtitle: Text(app_state.prismUser.email, style: _subtitleStyle),
          onTap: () async {
            _trackSettingsAction(AnalyticsActionValue.logoutTapped);
            try {
              final bool signedOut = await app_state.gAuth.signOutGoogle();
              _trackSettingsAuthResult(
                action: AnalyticsActionValue.logoutTapped,
                result: signedOut ? EventResultValue.success : EventResultValue.failure,
                reason: signedOut ? null : AnalyticsReasonValue.error,
              );
              if (signedOut) {
                toasts.codeSend('Log out Successful!');
                final settingsLocal = getIt<SettingsLocalDataSource>();
                await settingsLocal.set('onboarded_v2_new', false);
                await settingsLocal.set('onboarding_v2_interests', '');
                await settingsLocal.set('onboarding_v2_followed_creators', '');
                if (context.mounted) {
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
    showModal(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        content: const SizedBox(
          height: 50,
          width: 250,
          child: Center(child: Text('Do you want to remove all your favourite wallpapers?')),
        ),
        actions: [
          MaterialButton(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            onPressed: () {
              _trackSettingsAction(AnalyticsActionValue.clearFavouriteWallsConfirmed);
              Navigator.of(ctx).pop();
              toasts.error('Cleared all favourite wallpapers!');
              context.favouriteWallsAdapter(listen: false).deleteData();
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

  void _showClearFavSetupsDialog() {
    showModal(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        content: const SizedBox(
          height: 50,
          width: 250,
          child: Center(child: Text('Do you want to remove all your favourite setups?')),
        ),
        actions: [
          MaterialButton(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            onPressed: () {
              _trackSettingsAction(AnalyticsActionValue.clearFavouriteSetupsConfirmed);
              Navigator.of(ctx).pop();
              toasts.error('Cleared all favourite setups!');
              context.favouriteSetupsAdapter(listen: false).deleteData();
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

  Widget _premiumSection() {
    if (app_state.prismUser.premium == true) return const SizedBox.shrink();
    return _sectionCard(
      title: 'PREMIUM',
      children: [
        ListTile(
          leading: const Icon(JamIcons.instant_picture_f),
          title: Text('Buy Premium', style: _titleStyle),
          subtitle: const Text('Get unlimited setups and filters.', style: TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            _trackSettingsAction(AnalyticsActionValue.buyPremiumTapped);
            if (!app_state.prismUser.loggedIn) {
              googleSignInPopUp(context, () {
                if (app_state.prismUser.premium == true) {
                  main.RestartWidget.restartApp(context);
                } else {
                  PaywallOrchestrator.instance.present(
                    context,
                    placement: PaywallPlacement.mainUpsell,
                    source: 'settings_buy_premium',
                  );
                }
              });
            } else {
              PaywallOrchestrator.instance.present(
                context,
                placement: PaywallPlacement.mainUpsell,
                source: 'settings_buy_premium',
              );
            }
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
          subtitle: const Text('Logs, network, tools, storage inspector', style: TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.router.pushPath('/debug-panel'),
        ),
        ListTile(
          leading: const Icon(JamIcons.shield_check),
          title: Text('Admin Moderation', style: _titleStyle),
          subtitle: const Text('Review and moderate submitted content', style: TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.router.push(const AdminReviewRoute()),
        ),
        ListTile(
          leading: const Icon(JamIcons.file),
          title: Text('Firestore Telemetry', style: _titleStyle),
          subtitle: const Text('Database usage and telemetry stats', style: TextStyle(fontSize: 12)),
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
          leading: const Icon(JamIcons.bug),
          title: Text('Report a Bug', style: _titleStyle),
          subtitle: const Text('Send a bug report via email', style: TextStyle(fontSize: 12)),
          onTap: () async => _sendBugReport(),
        ),
        ListTile(
          leading: const Icon(JamIcons.refresh),
          title: Text('Restart App', style: _titleStyle),
          subtitle: const Text('Force the application to restart', style: TextStyle(fontSize: 12)),
          onTap: () {
            _trackSettingsAction(AnalyticsActionValue.restartAppTapped);
            main.RestartWidget.restartApp(context);
          },
        ),
      ],
    );
  }

  Future<void> _sendBugReport() async {
    if (!Platform.isAndroid) return;
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final release = androidInfo.version.release;
    final sdkInt = androidInfo.version.sdkInt;
    final manufacturer = androidInfo.manufacturer;
    final model = androidInfo.model;
    final String zipPath = await zipLogs();
    if (zipPath.startsWith(logExportDisabledMarker)) {
      toasts.error('Log export is temporarily disabled.');
      return;
    }
    final String encryptedZipKey = zipPath.split('::::').first;
    final String encryptedZipPath = zipPath.split('::::').last;
    final deviceBody =
        '----x-x-x----<br>Device info -<br><br>Android version: Android $release<br>SDK Number: SDK $sdkInt<br>Device Manufacturer: $manufacturer<br>Device Model: $model<br>----x-x-x----<br><br>Enter the bug/issue below -<br><br>';
    final MailOptions mailOptions = MailOptions(
      body: deviceBody,
      subject: '[BUG REPORT::PRISM] - $encryptedZipKey',
      recipients: ['hash.studios.inc@gmail.com'],
      isHTML: true,
      attachments: [encryptedZipPath],
      appSchema: 'com.google.android.gm',
    );
    final MailerResponse response = await FlutterMailer.send(mailOptions);
    if (response != MailerResponse.android) {
      final MailOptions fallback = MailOptions(
        body: deviceBody,
        subject: '[BUG REPORT::PRISM]',
        recipients: ['hash.studios.inc@gmail.com'],
        isHTML: true,
        attachments: [zipPath],
      );
      await FlutterMailer.send(fallback);
    } else {
      toasts.codeSend('Bug report sent!');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
          _androidWidgetsSection(),
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
