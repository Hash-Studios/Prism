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
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/features/session/views/widgets/settings_account_card.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/notifications/notification_pref_keys.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
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
    _notifPromo = _settingsLocal.get<bool>(NotificationPrefKeys.recommendations, defaultValue: true);
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
      onTap: () => createUserDynamicLink(
        app_state.prismUser.name,
        app_state.prismUser.username,
        app_state.prismUser.email,
        app_state.prismUser.bio,
        app_state.prismUser.profilePhoto,
        context: context,
      ),
    ),
  ];

  List<Widget> _appearanceRows() => <Widget>[
    PrismRow(
      icon: Icons.palette_rounded,
      title: 'Themes',
      subtitle: 'Light, dark and accent colour',
      onTap: () => context.router.push(const ThemeViewRoute()),
    ),
    if (Platform.isAndroid)
      PrismRow(
        icon: Icons.grid_view_rounded,
        title: 'Quick tiles',
        subtitle: 'Set up your Quick Settings tiles',
        onTap: () => context.router.push(const QuickTileSettingsRoute()),
      ),
  ];

  List<Widget> _contentRows() => <Widget>[
    PrismSwitchRow(
      icon: Icons.animation_rounded,
      title: 'Show anime wallpapers',
      value: _showAnime,
      onChanged: (value) {
        setState(() => _showAnime = value);
        _settingsLocal.set('WHcategories', value ? 111 : 100);
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
          _settingsLocal.set('WHpurity', value ? 110 : 100);
          _trackSettingsToggle(SettingValue.sketchyWallpapers, value);
        },
      ),
    PrismRow(
      icon: Icons.high_quality_rounded,
      title: 'Download quality',
      value: _downloadQuality.title,
      onTap: _showDownloadQualitySheet,
    ),
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
  ];

  void _showDownloadQualitySheet() {
    showPrismSheet<void>(
      context: context,
      builder: (ctx) {
        final ColorScheme cs = Theme.of(ctx).colorScheme;
        return PrismSheetBody(
          title: 'Download quality',
          child: Column(
            children: <Widget>[
              for (final _DownloadQuality quality in _DownloadQuality.values)
                PrismRow(
                  title: quality.title,
                  subtitle: quality.subtitle,
                  padding: const EdgeInsets.symmetric(vertical: PrismSpace.sm),
                  showChevron: false,
                  trailing: quality == _downloadQuality ? Icon(Icons.check_rounded, color: cs.primary) : null,
                  onTap: () {
                    setState(() => _downloadQuality = quality);
                    _settingsLocal.set(PersistenceKeys.downloadQuality, quality.name);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _notificationRows() => <Widget>[
    PrismSwitchRow(
      icon: Icons.wb_sunny_rounded,
      title: 'Wall of the Day',
      subtitle: 'A daily wallpaper pick',
      value: _notifWotd,
      onChanged: (value) {
        setState(() => _notifWotd = value);
        _settingsLocal.set(PersistenceKeys.notifWotd, value);
        _setTopic('wall_of_the_day', value);
      },
    ),
    PrismSwitchRow(
      icon: Icons.campaign_rounded,
      title: 'Promotional alerts',
      subtitle: 'New features, events and announcements',
      value: _notifPromo,
      onChanged: (value) {
        setState(() => _notifPromo = value);
        _settingsLocal.set(NotificationPrefKeys.recommendations, value);
        _trackSettingsToggle(SettingValue.recommendationsNotifications, value);
        _setTopic('recommendations', value);
      },
    ),
  ];

  void _setTopic(String topic, bool subscribed) {
    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    final String sourceTag = 'settings.$topic.${subscribed ? 'enable' : 'disable'}';
    unawaited(
      subscribed
          ? subscribeToTopicSafely(messaging, topic, sourceTag: sourceTag)
          : unsubscribeFromTopicSafely(messaging, topic, sourceTag: sourceTag),
    );
  }

  List<Widget> _storageRows() => <Widget>[
    PrismRow(
      icon: Icons.cleaning_services_rounded,
      title: 'Clear cache',
      subtitle: 'Remove locally cached images',
      showChevron: false,
      onTap: () async {
        _trackSettingsAction(AnalyticsActionValue.clearCacheTapped);
        await _cacheMaintenance.clearTransientCache();
        toasts.success('Cache cleared');
      },
    ),
    PrismRow(
      icon: Icons.download_done_rounded,
      title: 'Clear all downloads',
      subtitle: 'Remove every downloaded wallpaper',
      showChevron: false,
      onTap: _confirmClearDownloads,
    ),
    if (app_state.prismUser.loggedIn)
      PrismRow(
        icon: Icons.favorite_border_rounded,
        title: 'Clear favourites',
        subtitle: 'Remove every favourite wallpaper',
        showChevron: false,
        onTap: () {
          _trackSettingsAction(AnalyticsActionValue.clearFavouriteWallsTapped);
          _confirmClearFavourites();
        },
      ),
  ];

  Future<void> _confirmClearDownloads() async {
    final bool ok = await showPrismConfirm(
      context,
      title: 'Clear all downloads?',
      message: 'Every wallpaper you downloaded will be removed from this device.',
      confirmLabel: 'Clear downloads',
      destructive: true,
    );
    if (!ok) return;
    bool deleted = false;
    try {
      final result = await PrismMediaHostApi().clearDownloads();
      deleted = result.success;
    } catch (e) {
      logger.w('Clearing downloads failed.', error: e);
    }
    if (deleted) {
      toasts.success('Downloads cleared');
    } else {
      toasts.error('No downloads found');
    }
  }

  Future<void> _confirmClearFavourites() async {
    final bool ok = await showPrismConfirm(
      context,
      title: 'Clear all favourites?',
      message: 'Every favourite wallpaper will be removed from your list.',
      confirmLabel: 'Clear favourites',
      destructive: true,
    );
    if (!ok || !mounted) return;
    _trackSettingsAction(AnalyticsActionValue.clearFavouriteWallsConfirmed);
    toasts.success('Favourites cleared');
    context.favouriteWallsAdapter(listen: false).deleteData();
  }

  List<Widget> _purchaseRows() => <Widget>[
    if (!app_state.prismUser.premium)
      PrismRow(
        icon: Icons.workspace_premium_rounded,
        title: 'Buy Premium',
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
    if (app_state.prismUser.loggedIn)
      PrismRow(
        icon: Icons.restore_rounded,
        title: 'Restore purchases',
        subtitle: 'Bring back a previous subscription',
        showChevron: false,
        onTap: _restoring ? null : _restorePurchases,
      ),
  ];

  Future<void> _restorePurchases() async {
    _trackSettingsAction(AnalyticsActionValue.restorePurchaseTapped);
    setState(() => _restoring = true);
    toasts.success('Restoring purchases…');
    try {
      final bool premium = await PurchasesService.instance.restore();
      premium ? toasts.success('Purchases restored') : toasts.error('No purchases to restore for this account.');
    } catch (e) {
      toasts.error('Could not restore purchases. Please try again.');
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
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

  List<Widget> _aboutRows() => <Widget>[
    PrismRow(icon: Icons.info_rounded, title: 'About Prism', onTap: () => context.router.push(const AboutRoute())),
    PrismRow(
      icon: Icons.refresh_rounded,
      title: 'Restart app',
      showChevron: false,
      onTap: () {
        _trackSettingsAction(AnalyticsActionValue.restartAppTapped);
        main.RestartWidget.restartApp(context);
      },
    ),
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
    _trackSettingsAction(AnalyticsActionValue.logoutTapped);
    final bool ok = await showPrismConfirm(
      context,
      title: 'Log out of Prism?',
      message: 'You can sign back in at any time.',
      confirmLabel: 'Log out',
    );
    if (!ok || !mounted) return;
    try {
      final bool signedOut = await globalGoogleAuth.signOutGoogle();
      _trackSettingsAuthResult(
        action: AnalyticsActionValue.logoutTapped,
        result: signedOut ? EventResultValue.success : EventResultValue.failure,
        reason: signedOut ? null : AnalyticsReasonValue.error,
      );
      if (signedOut) {
        toasts.success('Logged out');
        await resetOnboardingLocalState(_settingsLocal);
        if (mounted) {
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
  }

  Future<void> _confirmDeleteAccount() async {
    final bool ok = await showPrismConfirm(
      context,
      title: 'Delete your account?',
      message:
          'This permanently deletes your account, removes your personal data and signs you out. Your uploaded '
          'wallpapers stay visible as "Deleted Account". This cannot be undone.',
      confirmLabel: 'Delete account',
      destructive: true,
      mood: GlintMood.sad,
    );
    if (!ok || !mounted) return;
    unawaited(
      showPrismSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: PrismSheetBody(mood: GlintMood.curious, centered: true, title: 'Deleting your account'),
        ),
      ),
    );
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
  }

  @override
  Widget build(BuildContext context) {
    final bool loggedIn = app_state.prismUser.loggedIn;
    final List<Widget> purchaseRows = _purchaseRows();
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
          _group('Content', _contentRows()),
          _group('Notifications', _notificationRows()),
          _group('Storage', _storageRows()),
          if (purchaseRows.isNotEmpty) _group('Purchases', purchaseRows),
          if (app_state.isAdminUser()) _group('Admin', _adminRows()),
          _group('About', _aboutRows()),
          if (loggedIn) ...<Widget>[const SizedBox(height: PrismSpace.xl), PrismGroup(children: _sessionRows())],
        ],
      ),
    );
  }
}
