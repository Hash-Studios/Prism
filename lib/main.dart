import 'package:Prism/data/wallhaven/provider/wallhaven.dart';
import 'package:Prism/theme/theme.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:flare_splash_screen/flare_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() => runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WallHavenProvider>(
            create: (context) => WallHavenProvider(),
          ),
          ChangeNotifierProvider<ThemeModel>(
            create: (context) => ThemeModel(),
          )
        ],
        child: MyApp(),
      ),
    );

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: Provider.of<ThemeModel>(context).currentTheme,
      debugShowCheckedModeBanner: false,
      home: SplashScreen(
        Provider.of<ThemeModel>(context).currentTheme == kLightTheme
            ? 'assets/animations/Prism Splash.flr'
            : 'assets/animations/Prism Splash Dark.flr',
        (context) => MainWidget(),
        startAnimation:
            Provider.of<ThemeModel>(context).currentTheme == kLightTheme
                ? 'Main'
                : 'Dark',
        backgroundColor:
            Provider.of<ThemeModel>(context).currentTheme == kLightTheme
                ? Color(0xFFFFFFFF)
                : Color(0xFF181818),
        until: () => Future.delayed(Duration(seconds: 0)),
      ),
    );
  }
}

class MainWidget extends StatelessWidget {
  const MainWidget({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: Text('Material App Bar'),
        elevation: 0,
      ),
    );
  }
}
