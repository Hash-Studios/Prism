import 'package:flutter/material.dart';
import 'package:Prism/theme/theme.dart';

enum ThemeType { Light, Dark }

class ThemeModel extends ChangeNotifier {
  ThemeData currentTheme = kDarkTheme;
  ThemeType _themeType = ThemeType.Dark;

  toggleTheme() {
    if (this._themeType == ThemeType.Dark) {
      this.currentTheme = kLightTheme;
      this._themeType = ThemeType.Light;
      return notifyListeners();
    }

    if (this._themeType == ThemeType.Light) {
      this.currentTheme = kDarkTheme;
      this._themeType = ThemeType.Dark;
      return notifyListeners();
    }
  }

  returnTheme() {
    return _themeType;
  }
}
