import 'package:Prism/data/categories/provider/categoriesProvider.dart';
import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/data/pexels/provider/pexels.dart';
import 'package:Prism/data/wallhaven/provider/wallhaven.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/pages/splashScreen.dart';
import 'package:Prism/ui/pages/undefinedScreen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Prism/router.dart' as router;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Prism/globals.dart' as globals;
import 'package:flutter/cupertino.dart';
import 'package:Prism/theme/theme.dart';

SharedPreferences prefs;
var darkMode;
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.getInstance().then((prefs) {
    darkMode = prefs.getBool('darkMode') ?? true;
    if (darkMode)
      prefs.setBool('darkMode', true);
    else
      prefs.setBool('darkMode', false);
    runApp(
      RestartWidget(
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<WallHavenProvider>(
              create: (context) => WallHavenProvider(),
            ),
            ChangeNotifierProvider<PexelsProvider>(
              create: (context) => PexelsProvider(),
            ),
            ChangeNotifierProvider<CategoryProvider>(
              create: (context) => CategoryProvider(),
            ),
            ChangeNotifierProvider<FavouriteProvider>(
              create: (context) => FavouriteProvider(),
            ),
            ChangeNotifierProvider<ThemeModel>(
              create: (context) => ThemeModel(
                  darkMode ? kDarkTheme : kLightTheme,
                  darkMode ? ThemeType.Dark : ThemeType.Light),
            )
          ],
          child: MyApp(),
        ),
      ),
    );
  });
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  void getLoginStatus() async {
    prefs = await SharedPreferences.getInstance();
    globals.gAuth.googleSignIn.isSignedIn().then((value) {
      prefs.setBool("isLoggedin", value);
    });
  }

  @override
  void initState() {
    getLoginStatus();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateRoute: router.generateRoute,
      onUnknownRoute: (settings) => MaterialPageRoute(
          builder: (context) => UndefinedScreen(
                name: settings.name,
              )),
      theme: Provider.of<ThemeModel>(context).currentTheme,
      debugShowCheckedModeBanner: false,
      home: SplashWidget(),
    );
  }
}

class RestartWidget extends StatefulWidget {
  RestartWidget({this.child});

  final Widget child;

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>().restartApp();
  }

  @override
  _RestartWidgetState createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key key = UniqueKey();

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
    SharedPreferences.getInstance().then((prefs) {
      darkMode = prefs.getBool('darkMode') ?? true;
      if (darkMode)
        prefs.setBool('darkMode', true);
      else
        prefs.setBool('darkMode', false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key,
      child: widget.child,
    );
  }
}
