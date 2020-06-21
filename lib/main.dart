import 'package:flare_splash_screen/flare_splash_screen.dart';
import 'package:flutter/material.dart';

void main() {
  SplashScreen.navigate(
    name: 'Prism Splash.flr',
    next: (_) => MyApp(),
    until: () => Future.delayed(Duration(seconds: 3)),
    startAnimation: 'Main',
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Material App',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Text('Material App Bar'),
        ),
        body: Center(
          child: Container(
            child: Text('Hello World'),
          ),
        ),
      ),
    );
  }
}
