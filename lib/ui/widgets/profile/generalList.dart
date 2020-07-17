import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/analytics/analytics_service.dart';
import 'package:provider/provider.dart';

class GeneralList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'General',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).accentColor,
              ),
            ),
          ),
        ),
        Column(
          children: [
            ListTile(
              onTap: () {
                Navigator.pushNamed(context, ThemeViewRoute);
                // main.prefs.getBool("darkMode") == null
                //     ? analytics.logEvent(
                //         name: 'theme_changed', parameters: {'type': 'dark'})
                //     : main.prefs.getBool("darkMode")
                //         ? analytics.logEvent(
                //             name: 'theme_changed',
                //             parameters: {'type': 'light'})
                //         : analytics.logEvent(
                //             name: 'theme_changed',
                //             parameters: {'type': 'dark'});
                // Provider.of<ThemeModel>(context, listen: false).toggleTheme();
                // main.RestartWidget.restartApp(context);
              },
              leading: Icon(JamIcons.wrench),
              // leading: main.prefs.getBool("darkMode") == null
              //     ? Icon(JamIcons.moon_f)
              //     : main.prefs.getBool("darkMode")
              //         ? Icon(JamIcons.sun_f)
              //         : Icon(JamIcons.moon_f),
              title: Text(
                "Themes",
                // main.prefs.getBool("darkMode") == null
                //     ? "Dark Mode"
                //     : main.prefs.getBool("darkMode")
                //         ? "Light Mode"
                //         : "Dark Mode",
                style: TextStyle(
                    color: Theme.of(context).accentColor,
                    fontWeight: FontWeight.w500,
                    fontFamily: "Proxima Nova"),
              ),
              subtitle: Text(
                "Toggle app theme",
                style: TextStyle(fontSize: 12),
              ),
            ),
            ListTile(
                leading: Icon(
                  JamIcons.pie_chart_alt,
                ),
                title: Text(
                  "Clear Cache",
                  style: TextStyle(
                      color: Theme.of(context).accentColor,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Proxima Nova"),
                ),
                subtitle: Text(
                  "Clear locally cached images",
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  DefaultCacheManager().emptyCache();
                  toasts.clearCache();
                }),
            ListTile(
              onTap: () {
                main.RestartWidget.restartApp(context);
              },
              leading: Icon(JamIcons.refresh),
              title: Text(
                "Restart App",
                style: TextStyle(
                    color: Theme.of(context).accentColor,
                    fontWeight: FontWeight.w500,
                    fontFamily: "Proxima Nova"),
              ),
              subtitle: Text(
                "Force the application to restart",
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
