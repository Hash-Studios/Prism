import 'package:Prism/data/wallhaven/provider/wallhaven.dart';
import 'package:flare_splash_screen/flare_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() => runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WallHavenProvider>(
            create: (context) => WallHavenProvider(),
          ),
        ],
        child: MyApp(),
      ),
    );

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(
        'assets/animations/Prism Splash.flr',
        (context) => MainWidget(),
        startAnimation: 'Main',
        backgroundColor: Color(0xFFFFFFFF),
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
      appBar: AppBar(
        title: Text('Material App Bar'),
      ),
      body: Center(
        child: Container(),
      ),
    );
  }
}
