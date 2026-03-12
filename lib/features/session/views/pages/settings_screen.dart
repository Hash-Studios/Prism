import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/cache_maintenance_service.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/home/core/headingChipBar.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/features/favourite_setups/views/favourite_setups_bloc_adapter.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:animations/animations.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final CacheMaintenanceService _cacheMaintenance = getIt<CacheMaintenanceService>();
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  bool optWall = getIt<SettingsLocalDataSource>().get<bool>('optimisedWallpapers', defaultValue: true);
  int categories = getIt<SettingsLocalDataSource>().get<int>('WHcategories', defaultValue: 100);
  int purity = getIt<SettingsLocalDataSource>().get<int>('WHpurity', defaultValue: 100);

  void _trackSettingsAction(AnalyticsActionValue action) {
    analytics.track(
      SettingsActionTappedEvent(
        action: action,
        isSignedIn: app_state.prismUser.loggedIn,
        sourceContext: 'settings_screen',
      ),
    );
  }

  void _trackSettingsToggle(SettingValue setting, bool value) {
    analytics.track(SettingsToggleChangedEvent(setting: setting, value: value));
  }

  void _trackSettingsAuthResult({
    required AnalyticsActionValue action,
    required EventResultValue result,
    AnalyticsReasonValue? reason,
  }) {
    analytics.track(SettingsAuthActionResultEvent(action: action, result: result, reason: reason));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {}
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: const PreferredSize(
          preferredSize: Size(double.infinity, 55),
          child: HeadingChipBar(current: "Settings"),
        ),
        body: ListView(
          children: <Widget>[
            if (app_state.prismUser.premium == true)
              Container()
            else
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Premium',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.error == Colors.black
                          ? Colors.grey
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            Column(
              children: <Widget>[
                if (app_state.prismUser.premium == true)
                  Container()
                else
                  ListTile(
                    onTap: () {
                      _trackSettingsAction(AnalyticsActionValue.buyPremiumTapped);
                      if (app_state.prismUser.loggedIn == false) {
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
                    leading: const Icon(JamIcons.instant_picture_f),
                    title: Text(
                      "Buy Premium",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w500,
                        fontFamily: "Proxima Nova",
                      ),
                    ),
                    subtitle: const Text("Get unlimited setups and filters.", style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'General',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.error == Colors.black
                        ? Colors.grey
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.grid_view_rounded),
              title: Text(
                "Quick Tile Settings",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova",
                ),
              ),
              subtitle: const Text("Configure Android Quick Settings tiles", style: TextStyle(fontSize: 12)),
              onTap: () {
                context.router.push(const QuickTileSettingsRoute());
              },
            ),
            ListTile(
              leading: const Icon(JamIcons.pie_chart_alt),
              title: Text(
                "Clear Cache",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova",
                ),
              ),
              subtitle: const Text("Clear locally cached images", style: TextStyle(fontSize: 12)),
              onTap: () async {
                _trackSettingsAction(AnalyticsActionValue.clearCacheTapped);
                await _cacheMaintenance.clearTransientCache();
                toasts.codeSend("Cleared cache!");
              },
            ),
            SwitchListTile(
              activeThumbColor: Theme.of(context).colorScheme.error,
              secondary: const Icon(JamIcons.picture),
              value: categories == 111,
              title: Text(
                "Show Anime Wallpapers",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova",
                ),
              ),
              subtitle: categories == 111
                  ? const Text("Disable this to hide anime wallpapers", style: TextStyle(fontSize: 12))
                  : const Text("Enable this to show anime wallpapers", style: TextStyle(fontSize: 12)),
              onChanged: (bool value) {
                if (value == true) {
                  setState(() {
                    categories = 111;
                  });
                  _settingsLocal.set('WHcategories', 111);
                  _trackSettingsToggle(SettingValue.animeWallpapers, true);
                } else {
                  setState(() {
                    categories = 100;
                  });
                  _settingsLocal.set('WHcategories', 100);
                  _trackSettingsToggle(SettingValue.animeWallpapers, false);
                }
              },
            ),
            SwitchListTile(
              activeThumbColor: Theme.of(context).colorScheme.error,
              secondary: const Icon(JamIcons.stop_sign),
              value: purity == 110,
              title: Text(
                "Show Sketchy Wallpapers",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova",
                ),
              ),
              subtitle: purity == 110
                  ? const Text("Disable this to hide sketchy wallpapers", style: TextStyle(fontSize: 12))
                  : const Text("Enable this to show sketchy wallpapers", style: TextStyle(fontSize: 12)),
              onChanged: (bool value) {
                if (value == true) {
                  setState(() {
                    purity = 110;
                  });
                  _settingsLocal.set('WHpurity', 110);
                  _trackSettingsToggle(SettingValue.sketchyWallpapers, true);
                } else {
                  setState(() {
                    purity = 100;
                  });
                  _settingsLocal.set('WHpurity', 100);
                  _trackSettingsToggle(SettingValue.sketchyWallpapers, false);
                }
              },
            ),
            ListTile(
              onTap: () {
                _trackSettingsAction(AnalyticsActionValue.restartAppTapped);
                main.RestartWidget.restartApp(context);
              },
              leading: const Icon(JamIcons.refresh),
              title: Text(
                "Restart App",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova",
                ),
              ),
              subtitle: const Text("Force the application to restart", style: TextStyle(fontSize: 12)),
            ),
            if (app_state.isAdminUser()) ...[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Admin',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.error == Colors.black
                          ? Colors.grey
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: Text(
                  "Debug Panel",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w500,
                    fontFamily: "Proxima Nova",
                  ),
                ),
                subtitle: const Text("Logs, network, tools, storage inspector", style: TextStyle(fontSize: 12)),
                onTap: () => context.router.pushPath('/debug-panel'),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Account',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.error == Colors.black
                        ? Colors.grey
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),
            if (app_state.prismUser.loggedIn == false)
              ListTile(
                onTap: () async {
                  _trackSettingsAction(AnalyticsActionValue.signInTapped);
                  final Dialog loaderDialog = Dialog(
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
                  if (app_state.prismUser.loggedIn == false) {
                    showDialog(
                      barrierDismissible: false,
                      context: context,
                      builder: (BuildContext context) => loaderDialog,
                    );
                    try {
                      final String signInResult = await app_state.gAuth.signInWithGoogle();
                      if (!mounted) {
                        return;
                      }
                      if (signInResult == GoogleAuth.signInCancelledResult) {
                        Navigator.pop(this.context);
                        app_state.prismUser.loggedIn = false;
                        app_state.persistPrismUser();
                        _trackSettingsAuthResult(
                          action: AnalyticsActionValue.signInTapped,
                          result: EventResultValue.cancelled,
                          reason: AnalyticsReasonValue.userCancelled,
                        );
                        toasts.codeSend("Sign in cancelled.");
                        return;
                      }
                      toasts.codeSend("Login Successful!");
                      _trackSettingsAuthResult(
                        action: AnalyticsActionValue.signInTapped,
                        result: EventResultValue.success,
                      );
                      app_state.prismUser.loggedIn = true;
                      app_state.persistPrismUser();
                      Navigator.pop(this.context);
                      main.RestartWidget.restartApp(this.context);
                    } catch (e) {
                      if (!mounted) {
                        return;
                      }
                      logger.d(e);
                      Navigator.pop(this.context);
                      _trackSettingsAuthResult(
                        action: AnalyticsActionValue.signInTapped,
                        result: EventResultValue.failure,
                        reason: AnalyticsReasonValue.error,
                      );
                      app_state.prismUser.loggedIn = false;
                      app_state.persistPrismUser();
                      toasts.error("Something went wrong, please try again!");
                    }
                  } else {
                    main.RestartWidget.restartApp(context);
                  }
                },
                leading: const Icon(JamIcons.log_in),
                title: Text(
                  "Sign in",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w500,
                    fontFamily: "Proxima Nova",
                  ),
                ),
                subtitle: const Text("Sign in to sync data across devices", style: TextStyle(fontSize: 12)),
              )
            else
              Column(
                children: <Widget>[
                  if (app_state.prismUser.loggedIn == true)
                    Column(
                      children: [
                        ListTile(
                          leading: const Icon(JamIcons.heart),
                          title: Text(
                            "Clear favourite walls",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.w500,
                              fontFamily: "Proxima Nova",
                            ),
                          ),
                          subtitle: const Text("Remove all favourite wallpapers", style: TextStyle(fontSize: 12)),
                          onTap: () {
                            _trackSettingsAction(AnalyticsActionValue.clearFavouriteWallsTapped);
                            showModal(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                                content: SizedBox(
                                  height: 50,
                                  width: 250,
                                  child: Center(
                                    child: Text(
                                      "Do you want remove all your favourite wallpapers?",
                                      style: Theme.of(context).textTheme.headlineMedium,
                                    ),
                                  ),
                                ),
                                actions: <Widget>[
                                  MaterialButton(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                    onPressed: () {
                                      _trackSettingsAction(AnalyticsActionValue.clearFavouriteWallsConfirmed);
                                      Navigator.of(context).pop();
                                      toasts.error("Cleared all favourite wallpapers!");
                                      context.favouriteWallsAdapter(listen: false).deleteData();
                                    },
                                    child: Text(
                                      'YES',
                                      style: TextStyle(fontSize: 16.0, color: Theme.of(context).colorScheme.error),
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
                        ),
                        ListTile(
                          leading: const Icon(JamIcons.heart),
                          title: Text(
                            "Clear favourite setups",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.w500,
                              fontFamily: "Proxima Nova",
                            ),
                          ),
                          subtitle: const Text("Remove all favourite setups", style: TextStyle(fontSize: 12)),
                          onTap: () {
                            _trackSettingsAction(AnalyticsActionValue.clearFavouriteSetupsTapped);
                            showModal(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                                content: SizedBox(
                                  height: 50,
                                  width: 250,
                                  child: Center(
                                    child: Text(
                                      "Do you want remove all your favourite setups?",
                                      style: Theme.of(context).textTheme.headlineMedium,
                                    ),
                                  ),
                                ),
                                actions: <Widget>[
                                  MaterialButton(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                    onPressed: () {
                                      _trackSettingsAction(AnalyticsActionValue.clearFavouriteSetupsConfirmed);
                                      Navigator.of(context).pop();
                                      toasts.error("Cleared all favourite setups!");
                                      context.favouriteSetupsAdapter(listen: false).deleteData();
                                    },
                                    child: Text(
                                      'YES',
                                      style: TextStyle(fontSize: 16.0, color: Theme.of(context).colorScheme.error),
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
                        ),
                        ListTile(
                          leading: const Icon(JamIcons.log_out),
                          title: Text(
                            "Logout",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.w500,
                              fontFamily: "Proxima Nova",
                            ),
                          ),
                          subtitle: Text(app_state.prismUser.email, style: const TextStyle(fontSize: 12)),
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
                                toasts.codeSend("Log out Successful!");
                                main.RestartWidget.restartApp(context);
                              }
                            } catch (error, stackTrace) {
                              logger.e('Sign out failed from settings.', error: error, stackTrace: stackTrace);
                              _trackSettingsAuthResult(
                                action: AnalyticsActionValue.logoutTapped,
                                result: EventResultValue.failure,
                                reason: AnalyticsReasonValue.error,
                              );
                              toasts.error("Something went wrong, please try again!");
                            }
                          },
                        ),
                      ],
                    )
                  else
                    Container(),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
