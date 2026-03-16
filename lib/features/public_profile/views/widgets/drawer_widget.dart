import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/enterCodePanel.dart';
import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mailer/flutter_mailer.dart';

class ProfileDrawer extends StatelessWidget {
  const ProfileDrawer({super.key});

  void _trackDrawerAction(AnalyticsActionValue action, {required String sourceContext}) {
    unawaited(
      analytics.track(
        SurfaceActionTappedEvent(
          surface: AnalyticsSurfaceValue.profileDrawer,
          action: action,
          sourceContext: sourceContext,
          itemType: ItemTypeValue.user,
          itemId: app_state.prismUser.id,
        ),
      ),
    );
  }

  // ── Builder helpers ──────────────────────────────────────────────────────

  Widget _header(BuildContext context) {
    return SizedBox(
      height: 130,
      child: DrawerHeader(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                app_state.prismUser.premium == true ? 'Prism Pro' : 'Prism',
                style: Theme.of(context).textTheme.displaySmall!.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                app_state.prismUser.premium == true
                    ? 'Exclusive premium walls & setups!'
                    : 'Exclusive wallpapers & setups!',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String text, BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 0, 0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.displaySmall!.copyWith(
          fontSize: 11,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _item({
    required IconData icon,
    required String text,
    required BuildContext context,
    GestureTapCallback? onTap,
  }) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
      trailing: Icon(JamIcons.chevron_right, color: Theme.of(context).colorScheme.secondary),
      title: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          fontFamily: 'Proxima Nova',
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _footer(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            icon: Icon(JamIcons.cog, color: color, size: 18),
            label: Text('Settings', style: TextStyle(color: color, fontSize: 12)),
            onPressed: () {
              _trackDrawerAction(
                AnalyticsActionValue.notificationSettingsOpened,
                sourceContext: 'profile_drawer_settings',
              );
              Navigator.pop(context);
              context.router.push(const SettingsRoute());
            },
          ),
          TextButton.icon(
            icon: Icon(JamIcons.info, color: color, size: 18),
            label: Text('About', style: TextStyle(color: color, fontSize: 12)),
            onPressed: () {
              _trackDrawerAction(
                AnalyticsActionValue.actionChipTapped,
                sourceContext: 'profile_drawer_about',
              );
              Navigator.pop(context);
              context.router.push(const AboutRoute());
            },
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ColoredBox(
        color: Theme.of(context).primaryColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            _header(context),

            // ── YOUR CONTENT ───────────────────────────────────────────────
            _sectionHeader('YOUR CONTENT', context),
            _item(
              icon: JamIcons.picture,
              text: 'Favourite Wallpapers',
              context: context,
              onTap: () {
                _trackDrawerAction(
                  AnalyticsActionValue.drawerFavWallsTapped,
                  sourceContext: 'profile_drawer_fav_walls',
                );
                Navigator.pop(context);
                context.router.push(const FavouriteWallpaperRoute());
              },
            ),
            _item(
              icon: JamIcons.instant_picture,
              text: 'Favourite Setups',
              context: context,
              onTap: () {
                _trackDrawerAction(
                  AnalyticsActionValue.drawerFavSetupsTapped,
                  sourceContext: 'profile_drawer_fav_setups',
                );
                Navigator.pop(context);
                context.router.push(const FavouriteSetupRoute());
              },
            ),
            _item(
              icon: JamIcons.download,
              text: 'Downloaded Walls',
              context: context,
              onTap: () {
                _trackDrawerAction(
                  AnalyticsActionValue.drawerDownloadsTapped,
                  sourceContext: 'profile_drawer_downloads',
                );
                Navigator.pop(context);
                context.router.push(const DownloadRoute());
              },
            ),

            const Divider(),

            // ── ACCOUNT ────────────────────────────────────────────────────
            _sectionHeader('ACCOUNT', context),
            _item(
              icon: JamIcons.share_alt,
              text: 'Share your Profile',
              context: context,
              onTap: () {
                _trackDrawerAction(
                  AnalyticsActionValue.drawerSharePrismTapped,
                  sourceContext: 'profile_drawer_share_profile',
                );
                createUserDynamicLink(
                  app_state.prismUser.name,
                  app_state.prismUser.username,
                  app_state.prismUser.email,
                  app_state.prismUser.bio,
                  app_state.prismUser.profilePhoto,
                  context: context,
                );
              },
            ),
            _item(
              icon: JamIcons.log_out,
              text: 'Log out',
              context: context,
              onTap: () {
                _trackDrawerAction(
                  AnalyticsActionValue.drawerLogoutTapped,
                  sourceContext: 'profile_drawer_logout',
                );
                Navigator.pop(context);
                app_state.gAuth.signOutGoogle();
                toasts.codeSend('Log out Successful!');
                main.RestartWidget.restartApp(context);
              },
            ),

            const Divider(),

            // ── MORE ───────────────────────────────────────────────────────
            _sectionHeader('MORE', context),
            _item(
              icon: JamIcons.coin,
              text: 'Enter Code',
              context: context,
              onTap: () {
                _trackDrawerAction(
                  AnalyticsActionValue.drawerEnterCodeTapped,
                  sourceContext: 'profile_drawer_enter_code',
                );
                Navigator.pop(context);
                showModalBottomSheet(
                  isScrollControlled: true,
                  context: context,
                  builder: (_) => const EnterCodePanel(),
                );
              },
            ),
            _item(
              icon: JamIcons.bug,
              text: 'Report a Bug',
              context: context,
              onTap: () async {
                _trackDrawerAction(
                  AnalyticsActionValue.drawerContactSupportTapped,
                  sourceContext: 'profile_drawer_report_bug',
                );
                await _sendBugReport(context);
              },
            ),

            const Divider(),

            _footer(context),
          ],
        ),
      ),
    );
  }

  Future<void> _sendBugReport(BuildContext context) async {
    if (!Platform.isAndroid) return;
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final release = androidInfo.version.release;
    final sdkInt = androidInfo.version.sdkInt;
    final manufacturer = androidInfo.manufacturer;
    final model = androidInfo.model;
    logger.d('Android $release (SDK $sdkInt), $manufacturer $model');
    final String zipPath = await zipLogs();
    if (zipPath.startsWith(logExportDisabledMarker)) {
      toasts.error('Log export is temporarily disabled.');
      return;
    }
    final String encryptedZipKey = zipPath.split('::::').first;
    final String encryptedZipPath = zipPath.split('::::').last;
    final String deviceBody =
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
}
