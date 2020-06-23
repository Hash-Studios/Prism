import 'package:Prism/data/categories/provider/categoriesProvider.dart';
import 'package:Prism/data/pexels/provider/pexels.dart';
import 'package:Prism/data/wallhaven/provider/wallhaven.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/pages/splashScreen.dart';
import 'package:Prism/ui/pages/undefinedScreen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Prism/router.dart' as router;

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

class MyApp extends StatelessWidget {
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
