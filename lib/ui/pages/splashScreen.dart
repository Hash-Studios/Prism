import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/pages/pageManager.dart';
import 'package:flutter/material.dart';
import 'package:flare_splash_screen/flare_splash_screen.dart';
import 'package:Prism/theme/theme.dart';
import 'package:provider/provider.dart';

class SplashWidget extends StatelessWidget {
  const SplashWidget({
    Key key,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return SplashScreen(
      Provider.of<ThemeModel>(context).currentTheme == kLightTheme
          ? 'assets/animations/Prism Splash.flr'
          : 'assets/animations/Prism Splash Dark.flr',
      (context) => PageManager(),
      startAnimation:
          Provider.of<ThemeModel>(context).currentTheme == kLightTheme
              ? 'Main'
              : 'Dark',
      backgroundColor:
          Provider.of<ThemeModel>(context).currentTheme == kLightTheme
              ? Color(0xFFFFFFFF)
              : Color(0xFF181818),
      until: () => Future.delayed(Duration(seconds: 0)),
    );
  }
}
