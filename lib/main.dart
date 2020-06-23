import 'package:Prism/data/categories/provider/categoriesProvider.dart';
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

SharedPreferences prefs;
void main() => runApp(
      MultiProvider(
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
          ChangeNotifierProvider<ThemeModel>(
            create: (context) => ThemeModel(),
          )
        ],
        child: MyApp(),
      ),
    );

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
