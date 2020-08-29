import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/thumbModel.dart';
import 'package:flutter/material.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/themeModel.dart';
import 'package:hive/hive.dart';
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
                Navigator.pushNamed(context, ThemeViewRoute, arguments: [
                  Provider.of<ThemeModel>(context, listen: false).currentTheme
                ]);
              },
              leading: Icon(JamIcons.wrench),
              title: Text(
                "Themes",
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
                onTap: () async {
                  DefaultCacheManager().emptyCache();
                  PaintingBinding.instance.imageCache.clear();
                  await Hive.box('wallpapers').deleteFromDisk();
                  await Hive.openBox('wallpapers');
                  await Hive.box('collections').deleteFromDisk();
                  await Hive.openBox('collections');
                  toasts.codeSend("Cleared cache!");
                }),
            SwitchListTile(
                activeColor: Color(0xFFE57697),
                secondary: Icon(
                  JamIcons.dashboard,
                ),
                value: Provider.of<ThumbModel>(context).thumbType ==
                    ThumbType.High,
                title: Text(
                  "High Quality Thumbnails",
                  style: TextStyle(
                      color: Theme.of(context).accentColor,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Proxima Nova"),
                ),
                subtitle: Text(
                  "Disable this to reduce Internet consumption",
                  style: TextStyle(fontSize: 12),
                ),
                onChanged: (bool value) async {
                  Provider.of<ThumbModel>(context, listen: false).toggleThumb();
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
            ListTile(
              onTap: () {
                main.prefs.put("newDevice", true);
                main.prefs.put("newDevice2", true);
                main.RestartWidget.restartApp(context);
              },
              leading: Icon(JamIcons.help),
              title: Text(
                "Show Tutorial",
                style: TextStyle(
                    color: Theme.of(context).accentColor,
                    fontWeight: FontWeight.w500,
                    fontFamily: "Proxima Nova"),
              ),
              subtitle: Text(
                "Quick Guide to Prism",
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
