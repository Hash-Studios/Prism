import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/cache_maintenance_service.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

class GeneralList extends StatefulWidget {
  final bool expanded;
  const GeneralList({required this.expanded});
  @override
  _GeneralListState createState() => _GeneralListState();
}

class _GeneralListState extends State<GeneralList> {
  final CacheMaintenanceService _cacheMaintenance = getIt<CacheMaintenanceService>();
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  bool optWall = getIt<SettingsLocalDataSource>().get<bool>('optimisedWallpapers', defaultValue: true);
  int categories = getIt<SettingsLocalDataSource>().get<int>('WHcategories', defaultValue: 100);
  int purity = getIt<SettingsLocalDataSource>().get<int>('WHpurity', defaultValue: 100);

  void _trackAction(AnalyticsActionValue action, {required String sourceContext}) {
    unawaited(
      analytics.track(
        SurfaceActionTappedEvent(
          surface: AnalyticsSurfaceValue.profileGeneralList,
          action: action,
          sourceContext: sourceContext,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: widget.expanded,
      leading: const Icon(JamIcons.wrench),
      title: Text(
        "General",
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.w500,
          fontFamily: "Proxima Nova",
        ),
      ),
      subtitle: Text(
        "Change app look & settings",
        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary),
      ),
      children: [
        ListTile(
          onTap: () {
            _trackAction(AnalyticsActionValue.openThemeTapped, sourceContext: 'profile_general_list_theme');
            context.router.push(const ThemeViewRoute());
          },
          leading: const Icon(JamIcons.wrench),
          title: Text(
            "Themes",
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w500,
              fontFamily: "Proxima Nova",
            ),
          ),
          subtitle: const Text("Toggle app theme", style: TextStyle(fontSize: 12)),
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
            _trackAction(AnalyticsActionValue.clearCacheTapped, sourceContext: 'profile_general_list_clear_cache');
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
            unawaited(analytics.track(SettingsToggleChangedEvent(setting: SettingValue.animeWallpapers, value: value)));
            if (value == true) {
              setState(() {
                categories = 111;
              });
              _settingsLocal.set('WHcategories', 111);
            } else {
              setState(() {
                categories = 100;
              });
              _settingsLocal.set('WHcategories', 100);
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
            unawaited(
              analytics.track(SettingsToggleChangedEvent(setting: SettingValue.sketchyWallpapers, value: value)),
            );
            if (value == true) {
              setState(() {
                purity = 110;
              });
              _settingsLocal.set('WHpurity', 110);
            } else {
              setState(() {
                purity = 100;
              });
              _settingsLocal.set('WHpurity', 100);
            }
          },
        ),
        ListTile(
          onTap: () {
            _trackAction(AnalyticsActionValue.restartAppTapped, sourceContext: 'profile_general_list_restart_app');
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
      ],
    );
  }
}
