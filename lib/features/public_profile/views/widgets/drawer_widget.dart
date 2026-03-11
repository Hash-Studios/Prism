import 'dart:async';
import 'dart:io';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/cache_maintenance_service.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/enterCodePanel.dart';
import 'package:Prism/data/share/createDynamicLink.dart';
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

class ProfileDrawer extends StatelessWidget {
  final CacheMaintenanceService _cacheMaintenance = getIt<CacheMaintenanceService>();

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

  Widget createDrawerHeader(BuildContext context) {
    return SizedBox(
      height: 150,
      child: DrawerHeader(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        child: Stack(
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: SizedBox(
                  height: 70,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          app_state.prismUser.premium == true ? "Prism Pro" : "Prism",
                          style: Theme.of(
                            context,
                          ).textTheme.displaySmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
                        ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.6,
                        child: Text(
                          app_state.prismUser.premium == true
                              ? "Exclusive premium walls & setups!"
                              : "Exclusive wallpapers & setups!",
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget createDrawerBodyItem({
    IconData? icon,
    required String text,
    GestureTapCallback? onTap,
    required BuildContext context,
  }) {
    return ListTile(
      dense: true,
      trailing: Icon(JamIcons.chevron_right, color: Theme.of(context).colorScheme.secondary),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
      title: SizedBox(
        width: MediaQuery.of(context).size.width / 2,
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodySmall!.copyWith(fontFamily: "Proxima Nova", color: Theme.of(context).colorScheme.secondary),
        ),
      ),
      onTap: onTap,
    );
  }

  Widget createDrawerBodyHeader({required String text, required BuildContext context}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 0, 0),
      child: SizedBox(
        width: MediaQuery.of(context).size.width / 2,
        child: Text(
          text,
          style: Theme.of(context).textTheme.displaySmall!.copyWith(
            fontSize: 12,
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ColoredBox(
        color: Theme.of(context).primaryColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            createDrawerHeader(context),
            if (app_state.prismUser.premium == true)
              Container()
            else
              createDrawerBodyHeader(text: "PREMIUM", context: context),
            if (app_state.prismUser.premium == true)
              Container()
            else
              createDrawerBodyItem(
                icon: JamIcons.coin,
                text: 'Buy Premium',
                onTap: () {
                  _trackDrawerAction(
                    AnalyticsActionValue.drawerBuyPremiumTapped,
                    sourceContext: 'profile_drawer_buy_premium',
                  );
                  Navigator.pop(context);
                  PaywallOrchestrator.instance.present(
                    context,
                    placement: PaywallPlacement.mainUpsell,
                    source: 'drawer_buy_premium',
                  );
                },
                context: context,
              ),
            if (app_state.prismUser.premium == true) Container() else const Divider(),
            createDrawerBodyHeader(text: "FAVOURITES", context: context),
            createDrawerBodyItem(
              icon: JamIcons.picture,
              text: 'Wallpapers',
              onTap: () {
                _trackDrawerAction(
                  AnalyticsActionValue.drawerFavWallsTapped,
                  sourceContext: 'profile_drawer_fav_walls',
                );
                Navigator.pop(context);
                context.router.push(const FavouriteWallpaperRoute());
              },
              context: context,
            ),
            createDrawerBodyItem(
              icon: JamIcons.instant_picture,
              text: 'Setups',
              onTap: () {
                _trackDrawerAction(
                  AnalyticsActionValue.drawerFavSetupsTapped,
                  sourceContext: 'profile_drawer_fav_setups',
                );
                Navigator.pop(context);
                context.router.push(const FavouriteSetupRoute());
              },
              context: context,
            ),
            const Divider(),
            createDrawerBodyHeader(text: "DOWNLOADS", context: context),
            createDrawerBodyItem(
              icon: JamIcons.download,
              text: 'Downloaded Walls',
              onTap: () {
                _trackDrawerAction(
                  AnalyticsActionValue.drawerDownloadsTapped,
                  sourceContext: 'profile_drawer_downloads',
                );
                Navigator.pop(context);
                context.router.push(const DownloadRoute());
              },
              context: context,
            ),
            createDrawerBodyItem(
              icon: JamIcons.trash_alt,
              text: 'Clear all Downloads',
              onTap: () async {
                _trackDrawerAction(
                  AnalyticsActionValue.drawerClearDownloadsTapped,
                  sourceContext: 'profile_drawer_clear_downloads',
                );
                Navigator.pop(context);
                showModal(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    content: SizedBox(
                      height: 50,
                      width: 250,
                      child: Center(
                        child: Text(
                          "Do you want remove all your downloads?",
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                    ),
                    actions: <Widget>[
                      MaterialButton(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                        onPressed: () async {
                          _trackDrawerAction(
                            AnalyticsActionValue.drawerClearDownloadsConfirmed,
                            sourceContext: 'profile_drawer_clear_downloads_confirm',
                          );
                          Navigator.of(context).pop();
                          final dir = Directory("storage/emulated/0/Prism/");
                          final dir2 = Directory("storage/emulated/0/Pictures/Prism/");
                          bool deletedDir = false;
                          bool deletedDir2 = false;
                          try {
                            dir.deleteSync(recursive: true);
                            deletedDir = true;
                          } catch (e) {
                            logger.d(e.toString());
                          }
                          try {
                            dir2.deleteSync(recursive: true);
                            deletedDir2 = true;
                          } catch (e) {
                            logger.d(e.toString());
                          }
                          if (deletedDir || deletedDir2) {
                            Fluttertoast.showToast(
                              msg: "Deleted all downloads!",
                              toastLength: Toast.LENGTH_LONG,
                              textColor: Colors.white,
                              backgroundColor: Colors.green[400],
                            );
                          } else {
                            Fluttertoast.showToast(
                              msg: "No downloads!",
                              toastLength: Toast.LENGTH_LONG,
                              textColor: Colors.white,
                              backgroundColor: Colors.red[400],
                            );
                          }
                        },
                        child: Text(
                          'YES',
                          style: TextStyle(fontSize: 16.0, color: Theme.of(context).colorScheme.secondary),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: MaterialButton(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                          color: Theme.of(context).colorScheme.error,
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('NO', style: TextStyle(fontSize: 16.0, color: Colors.white)),
                        ),
                      ),
                    ],
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                );
              },
              context: context,
            ),
            const Divider(),
            createDrawerBodyHeader(text: "REVIEWS", context: context),
            createDrawerBodyItem(
              icon: JamIcons.check,
              text: 'Review Status',
              onTap: () {
                _trackDrawerAction(
                  AnalyticsActionValue.drawerReviewStatusTapped,
                  sourceContext: 'profile_drawer_review_status',
                );
                Navigator.pop(context);
                context.router.push(const ReviewRoute());
              },
              context: context,
            ),
            if (app_state.isAdminUser()) ...[
              createDrawerBodyItem(
                icon: JamIcons.shield_check,
                text: 'Admin Moderation',
                onTap: () {
                  Navigator.pop(context);
                  context.router.push(const AdminReviewRoute());
                },
                context: context,
              ),
              createDrawerBodyItem(
                icon: JamIcons.file,
                text: 'Firestore telemetry',
                onTap: () {
                  Navigator.pop(context);
                  context.router.push(const FirestoreTelemetryRoute());
                },
                context: context,
              ),
            ],
            const Divider(),
            createDrawerBodyHeader(text: "CUSTOMISATION", context: context),
            createDrawerBodyItem(
              icon: JamIcons.wrench,
              text: 'Themes',
              onTap: () {
                _trackDrawerAction(AnalyticsActionValue.openThemeTapped, sourceContext: 'profile_drawer_themes');
                Navigator.pop(context);
                context.router.push(const ThemeViewRoute());
              },
              context: context,
            ),
            const Divider(),
            createDrawerBodyHeader(text: "USER", context: context),
            createDrawerBodyItem(
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
            createDrawerBodyItem(
              icon: JamIcons.log_out,
              text: 'Log out',
              onTap: () {
                _trackDrawerAction(AnalyticsActionValue.drawerLogoutTapped, sourceContext: 'profile_drawer_logout');
                Navigator.pop(context);
                app_state.gAuth.signOutGoogle();
                toasts.codeSend("Log out Successful!");
                main.RestartWidget.restartApp(context);
              },
              context: context,
            ),
            const Divider(),
            createDrawerBodyHeader(text: "SETTINGS", context: context),
            createDrawerBodyItem(
              icon: JamIcons.pie_chart_alt,
              text: 'Clear cache',
              onTap: () async {
                _trackDrawerAction(AnalyticsActionValue.clearCacheTapped, sourceContext: 'profile_drawer_clear_cache');
                Navigator.pop(context);
                await _cacheMaintenance.clearTransientCache();
                toasts.codeSend("Cleared cache!");
              },
              context: context,
            ),
            createDrawerBodyItem(
              icon: JamIcons.cog,
              text: 'Settings',
              onTap: () {
                _trackDrawerAction(
                  AnalyticsActionValue.notificationSettingsOpened,
                  sourceContext: 'profile_drawer_settings',
                );
                Navigator.pop(context);
                context.router.push(const SettingsRoute());
              },
              context: context,
            ),
            createDrawerBodyItem(
              icon: JamIcons.info,
              text: 'About Prism',
              onTap: () {
                _trackDrawerAction(AnalyticsActionValue.actionChipTapped, sourceContext: 'profile_drawer_about');
                Navigator.pop(context);
                context.router.push(const AboutRoute());
              },
              context: context,
            ),
            const Divider(),
            createDrawerBodyHeader(text: "MORE", context: context),
            createDrawerBodyItem(
              icon: JamIcons.bug,
              text: 'Report a bug',
              context: context,
              onTap: () async {
                _trackDrawerAction(
                  AnalyticsActionValue.drawerContactSupportTapped,
                  sourceContext: 'profile_drawer_report_bug',
                );
                if (Platform.isAndroid) {
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
                  final String encryptedZipPath = zipPath.split("::::").last;
                  final String encryptedZipKey = zipPath.split("::::").first;
                  final MailOptions mailOptions = MailOptions(
                    body:
                        '----x-x-x----<br>Device info -<br><br>Android version: Android $release<br>SDK Number: SDK $sdkInt<br>Device Manufacturer: $manufacturer<br>Device Model: $model<br>----x-x-x----<br><br>Enter the bug/issue below -<br><br>',
                    subject: '[BUG REPORT::PRISM] - $encryptedZipKey',
                    recipients: ['hash.studios.inc@gmail.com'],
                    isHTML: true,
                    attachments: [encryptedZipPath],
                    appSchema: 'com.google.android.gm',
                  );
                  final MailerResponse response = await FlutterMailer.send(mailOptions);
                  if (response != MailerResponse.android) {
                    final MailOptions mailOptions = MailOptions(
                      body:
                          '----x-x-x----<br>Device info -<br><br>Android version: Android $release<br>SDK Number: SDK $sdkInt<br>Device Manufacturer: $manufacturer<br>Device Model: $model<br>----x-x-x----<br><br>Enter the bug/issue below -<br><br>',
                      subject: '[BUG REPORT::PRISM]',
                      recipients: ['hash.studios.inc@gmail.com'],
                      isHTML: true,
                      attachments: [zipPath],
                    );
                    await FlutterMailer.send(mailOptions);
                  } else {
                    toasts.codeSend("Bug report sent!");
                  }
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 100),
              child: createDrawerBodyItem(
                icon: JamIcons.coin,
                text: 'Enter Code',
                onTap: () {
                  _trackDrawerAction(
                    AnalyticsActionValue.drawerEnterCodeTapped,
                    sourceContext: 'profile_drawer_enter_code',
                  );
                  Navigator.pop(context);
                  showModalBottomSheet(
                    isScrollControlled: true,
                    context: context,
                    builder: (context) => const EnterCodePanel(),
                  );
                },
                context: context,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
