import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/popup/colorsPopUp.dart';
import 'package:flutter/material.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/themeModel.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:Prism/theme/config.dart' as config;

class GeneralList extends StatefulWidget {
  @override
  _GeneralListState createState() => _GeneralListState();
}

class _GeneralListState extends State<GeneralList> {
  bool optWall = main.prefs.get('optimisedWallpapers') ?? true;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: Icon(
        JamIcons.wrench,
      ),
      title: new Text(
        "General",
        style: TextStyle(
            color: Theme.of(context).accentColor,
            fontWeight: FontWeight.w500,
            fontFamily: "Proxima Nova"),
      ),
      subtitle: Text(
        "Change app look & settings",
        style: TextStyle(fontSize: 12, color: Theme.of(context).accentColor),
      ),
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
          onTap: () {
            showAccentColors(context);
          },
          leading: Icon(JamIcons.brush),
          title: Text(
            "Theme Accent Color",
            style: TextStyle(
                color: Theme.of(context).accentColor,
                fontWeight: FontWeight.w500,
                fontFamily: "Proxima Nova"),
          ),
          subtitle: Text(
            "Change app accent color",
            style: TextStyle(fontSize: 12),
          ),
          trailing: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Color(main.prefs.get("mainAccentColor")),
            ),
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
            activeColor: config.Colors().mainAccentColor(1),
            secondary: Icon(
              JamIcons.dashboard,
            ),
            value: optWall,
            title: Text(
              "Wallpaper Optimisation",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: optWall
                ? Text(
                    "Disabling this might lead to High Internet Usage",
                    style: TextStyle(fontSize: 12),
                  )
                : Text(
                    "Enable this to optimise Wallpapers according to your device",
                    style: TextStyle(fontSize: 12),
                  ),
            onChanged: (bool value) async {
              setState(() {
                optWall = value;
              });
              main.prefs.put('optimisedWallpapers', value);
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
    );
  }
}
