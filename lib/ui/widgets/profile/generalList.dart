import 'package:Prism/data/notifications/model/inAppNotifModel.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:Prism/main.dart' as main;
import 'package:hive/hive.dart';

class GeneralList extends StatefulWidget {
  final bool expanded;
  const GeneralList({required this.expanded});
  @override
  _GeneralListState createState() => _GeneralListState();
}

class _GeneralListState extends State<GeneralList> {
  bool optWall = (main.prefs.get('optimisedWallpapers') ?? true) as bool;
  bool followers = (main.prefs.get('followersTab') ?? true) as bool;
  int categories = (main.prefs.get('WHcategories') ?? 100) as int;
  int purity = (main.prefs.get('WHpurity') ?? 100) as int;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: widget.expanded,
      leading: const Icon(
        JamIcons.wrench,
      ),
      title: Text(
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
            Navigator.pushNamed(
              context,
              themeViewRoute,
            );
          },
          leading: const Icon(JamIcons.wrench),
          title: Text(
            "Themes",
            style: TextStyle(
                color: Theme.of(context).accentColor,
                fontWeight: FontWeight.w500,
                fontFamily: "Proxima Nova"),
          ),
          subtitle: const Text(
            "Toggle app theme",
            style: TextStyle(fontSize: 12),
          ),
        ),
        ListTile(
            leading: const Icon(
              JamIcons.pie_chart_alt,
            ),
            title: Text(
              "Clear Cache",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: const Text(
              "Clear locally cached images",
              style: TextStyle(fontSize: 12),
            ),
            onTap: () async {
              DefaultCacheManager().emptyCache();
              PaintingBinding.instance!.imageCache!.clear();
              await Hive.box<InAppNotif>('inAppNotifs').deleteFromDisk();
              await Hive.openBox<InAppNotif>('inAppNotifs');
              main.prefs.delete('lastFetchTime');
              await Hive.box('setups').deleteFromDisk();
              await Hive.openBox('setups');
              toasts.codeSend("Cleared cache!");
            }),
        // SwitchListTile(
        //     activeColor: Theme.of(context).errorColor,
        //     secondary: const Icon(
        //       JamIcons.dashboard,
        //     ),
        //     value: optWall,
        //     title: Text(
        //       "Wallpaper Optimisation",
        //       style: TextStyle(
        //           color: Theme.of(context).accentColor,
        //           fontWeight: FontWeight.w500,
        //           fontFamily: "Proxima Nova"),
        //     ),
        //     subtitle: optWall
        //         ? const Text(
        //             "Disabling this might lead to High Internet Usage",
        //             style: TextStyle(fontSize: 12),
        //           )
        //         : const Text(
        //             "Enable this to optimise Wallpapers according to your device",
        //             style: TextStyle(fontSize: 12),
        //           ),
        //     onChanged: (bool value) async {
        //       setState(() {
        //         optWall = value;
        //       });
        //       main.prefs.put('optimisedWallpapers', value);
        //     }),
        SwitchListTile(
            activeColor: Theme.of(context).errorColor,
            secondary: const Icon(
              JamIcons.user_plus,
            ),
            value: followers,
            title: Text(
              "Show Following Feed",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: followers
                ? const Text(
                    "Disable this to hide the followers feed from home page.",
                    style: TextStyle(fontSize: 12),
                  )
                : const Text(
                    "Enable this to show the followers feed on home page.",
                    style: TextStyle(fontSize: 12),
                  ),
            onChanged: (bool value) async {
              setState(() {
                followers = value;
              });
              toasts.codeSend("This will take effect on restarting app.");
              main.prefs.put('followersTab', value);
            }),
        SwitchListTile(
            activeColor: Theme.of(context).errorColor,
            secondary: const Icon(
              JamIcons.picture,
            ),
            value: categories == 111,
            title: Text(
              "Show Anime Wallpapers",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: categories == 111
                ? const Text(
                    "Disable this to hide anime wallpapers",
                    style: TextStyle(fontSize: 12),
                  )
                : const Text(
                    "Enable this to show anime wallpapers",
                    style: TextStyle(fontSize: 12),
                  ),
            onChanged: (bool value) async {
              if (value == true) {
                setState(() {
                  categories = 111;
                });
                main.prefs.put('WHcategories', 111);
              } else {
                setState(() {
                  categories = 100;
                });
                main.prefs.put('WHcategories', 100);
              }
            }),
        SwitchListTile(
            activeColor: Theme.of(context).errorColor,
            secondary: const Icon(
              JamIcons.stop_sign,
            ),
            value: purity == 110,
            title: Text(
              "Show Sketchy Wallpapers",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: purity == 110
                ? const Text(
                    "Disable this to hide sketchy wallpapers",
                    style: TextStyle(fontSize: 12),
                  )
                : const Text(
                    "Enable this to show sketchy wallpapers",
                    style: TextStyle(fontSize: 12),
                  ),
            onChanged: (bool value) async {
              if (value == true) {
                setState(() {
                  purity = 110;
                });
                main.prefs.put('WHpurity', 110);
              } else {
                setState(() {
                  purity = 100;
                });
                main.prefs.put('WHpurity', 100);
              }
            }),
        ListTile(
          onTap: () {
            main.RestartWidget.restartApp(context);
          },
          leading: const Icon(JamIcons.refresh),
          title: Text(
            "Restart App",
            style: TextStyle(
                color: Theme.of(context).accentColor,
                fontWeight: FontWeight.w500,
                fontFamily: "Proxima Nova"),
          ),
          subtitle: const Text(
            "Force the application to restart",
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
