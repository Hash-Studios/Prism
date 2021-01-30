import 'package:flutter/material.dart';
import 'package:Prism/theme/theme.dart';
import 'package:Prism/main.dart' as main;

Map<String, ThemeMode> modes = {
  "Light": ThemeMode.light,
  "Dark": ThemeMode.dark,
  "System": ThemeMode.system,
};

class ThemeModeExtended extends ChangeNotifier {
  ThemeMode currentMode = ThemeMode.dark;

  ThemeModeExtended(
    this.currentMode,
  );

  ThemeMode getCurrentThemeMode() {
    return currentMode;
  }

  void changeThemeMode(String mode) {
    currentMode = modes[mode];
    main.prefs.put("themeMode", mode);
    return notifyListeners();
  }

  String getCurrentModeStyle(Brightness brightness) {
    if (currentMode == ThemeMode.light) {
      return "Light";
    } else if (currentMode == ThemeMode.dark) {
      return "Dark";
    } else if (currentMode == ThemeMode.system) {
      if (brightness == Brightness.light) {
        return "Light";
      } else {
        return "Dark";
      }
      // MediaQuery.of(context).platformBrightness
    }
  }

  String getCurrentModeAbs() {
    if (currentMode == ThemeMode.light) {
      return "Light";
    } else if (currentMode == ThemeMode.dark) {
      return "Dark";
    } else if (currentMode == ThemeMode.system) {
      return "System (Light/Dark)";
    }
  }
}
