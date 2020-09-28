import 'package:flutter/material.dart';
import 'package:Prism/theme/theme.dart';
import 'package:Prism/main.dart' as main;

enum ThemeType { light, dark }

class ThemeModel extends ChangeNotifier {
  ThemeData currentTheme = kDarkTheme;
  ThemeType themeType = ThemeType.dark;

  ThemeModel(this.currentTheme, this.themeType);

  void toggleTheme() {
    if (themeType == ThemeType.dark) {
      main.prefs.put("darkMode", false);
      currentTheme = kLightTheme;
      themeType = ThemeType.light;
      debugPrint(main.prefs.get("darkMode").toString());
      return notifyListeners();
    }

    if (themeType == ThemeType.light) {
      main.prefs.put("darkMode", true);
      currentTheme = kDarkTheme;
      themeType = ThemeType.dark;
      debugPrint(main.prefs.get("darkMode").toString());
      return notifyListeners();
    }
  }

  ThemeType returnTheme() {
    return themeType;
  }
}
