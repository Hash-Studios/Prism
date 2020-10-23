import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/theme.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/profile/animatedThemeSwitch.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/analytics/analytics_service.dart';

class ThemeView extends StatefulWidget {
  final List arguments;
  const ThemeView({@required this.arguments});
  @override
  _ThemeViewState createState() => _ThemeViewState();
}

class _ThemeViewState extends State<ThemeView> {
  ThemeData currentTheme;
  @override
  void initState() {
    currentTheme = widget.arguments[0] as ThemeData;
    super.initState();
  }

  Future<bool> onWillPop() async {
    if (Provider.of<ThemeModel>(context, listen: false).currentTheme ==
        currentTheme) {
    } else {
      Provider.of<ThemeModel>(context, listen: false).toggleTheme();
    }
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack.toString());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
              icon: const Icon(JamIcons.chevron_left),
              onPressed: () {
                if (Provider.of<ThemeModel>(context, listen: false)
                        .currentTheme ==
                    currentTheme) {
                } else {
                  Provider.of<ThemeModel>(context, listen: false).toggleTheme();
                }
                navStack.removeLast();
                debugPrint(navStack.toString());
                Navigator.pop(context);
              }),
          actions: <Widget>[
            IconButton(
                icon: const Icon(
                  JamIcons.check,
                  size: 30,
                ),
                onPressed: () {
                  main.RestartWidget.restartApp(context);
                })
          ],
          centerTitle: true,
          elevation: 0,
          title: Text(
            "Pick a Theme",
            style: Theme.of(context).textTheme.headline2,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Center(
              child: Stack(
                children: <Widget>[
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: Provider.of<ThemeModel>(context, listen: false)
                                .returnTheme() ==
                            ThemeType.dark
                        ? 1
                        : 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(17),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.9),
                            blurRadius: 38,
                            offset: const Offset(0, 19),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(.8),
                            blurRadius: 12,
                            offset: const Offset(0, 15),
                          )
                        ],
                        image: const DecorationImage(
                            image: AssetImage(
                              "assets/images/dark_theme.jpg",
                            ),
                            fit: BoxFit.fitWidth),
                      ),
                      width: MediaQuery.of(context).size.height *
                          0.6 *
                          0.52068473609,
                      height: MediaQuery.of(context).size.height * 0.6,
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: Provider.of<ThemeModel>(context, listen: false)
                                .returnTheme() ==
                            ThemeType.dark
                        ? 0
                        : 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(17),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.15),
                            blurRadius: 38,
                            offset: const Offset(0, 19),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(.10),
                            blurRadius: 12,
                            offset: const Offset(0, 15),
                          )
                        ],
                        image: const DecorationImage(
                            image: AssetImage(
                              "assets/images/light_theme.jpg",
                            ),
                            fit: BoxFit.fitWidth),
                      ),
                      width: MediaQuery.of(context).size.height *
                          0.6 *
                          0.52068473609,
                      height: MediaQuery.of(context).size.height * 0.6,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedToggle(
              values: currentTheme == kDarkTheme
                  ? ['Dark', 'Light']
                  : ['Light', 'Dark'],
              textColor: Theme.of(context).accentColor,
              backgroundColor: Theme.of(context).hintColor,
              buttonColor: Theme.of(context).primaryColor,
              shadows: Provider.of<ThemeModel>(context, listen: false)
                          .returnTheme() ==
                      ThemeType.dark
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(.8),
                        blurRadius: 38,
                        offset: const Offset(0, 19),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(.15),
                        blurRadius: 38,
                        offset: const Offset(0, 19),
                      ),
                    ],
              onToggleCallback: (index) {
                Provider.of<ThemeModel>(context, listen: false).toggleTheme();
                main.prefs.get("darkMode") == null
                    ? analytics.logEvent(
                        name: 'theme_changed', parameters: {'type': 'dark'})
                    : main.prefs.get("darkMode") as bool
                        ? analytics.logEvent(
                            name: 'theme_changed',
                            parameters: {'type': 'light'})
                        : analytics.logEvent(
                            name: 'theme_changed',
                            parameters: {'type': 'dark'});
                debugPrint("Theme Changed");
              },
            ),
          ],
        ),
      ),
    );
  }
}
