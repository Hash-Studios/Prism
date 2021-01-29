import 'package:flutter/material.dart';
import 'package:Prism/theme/theme.dart';
import 'package:Prism/main.dart' as main;

Map<String, ThemeData> darkThemes = {
  "kDMaterial Dark": kDarkTheme,
  "kDAMOLED": kDarkTheme2,
  "kDOlive": kDarkTheme3,
  "kDDeep Ocean": kDarkTheme4,
  "kDJungle": kDarkTheme5,
  "kDPepper": kDarkTheme6,
  "kDSky": kDarkTheme7,
  "kDSteel": kDarkTheme8,
};

class DarkThemeModel extends ChangeNotifier {
  ThemeData currentTheme = kDarkTheme;

  DarkThemeModel(
    this.currentTheme,
  );

  void changeAccentColor(int accentColor) {
    debugPrint(accentColor.toString());
    currentTheme = currentTheme.copyWith(errorColor: Color(accentColor));
    return notifyListeners();
  }

  void changeThemeByID(String themeID) {
    debugPrint(themeID);
    currentTheme = darkThemes[themeID];
    main.prefs.put("themeID", themeID);
    return notifyListeners();
  }

  void changeThemeByThemeData(ThemeData themeData) {
    debugPrint(returnTheme(themeData));
    currentTheme = themeData;
    main.prefs.put("themeID", returnTheme(themeData));
    return notifyListeners();
  }

  String returnTheme(ThemeData themeData) {
    return darkThemes.keys.firstWhere(
      (element) => darkThemes[element] == themeData,
      orElse: () => null,
    );
  }

  int returnThemeIndex(ThemeData themeData) {
    return darkThemes.keys.toList().indexOf(darkThemes.keys.firstWhere(
          (element) => darkThemes[element] == themeData,
          orElse: () => null,
        ));
  }

  String returnThemeType() {
    final String themeNow = darkThemes.keys.firstWhere(
      (element) => darkThemes[element] == currentTheme,
      orElse: () => "kDMaterial Dark",
    );
    if (themeNow[1] == "L") {
      return "Light";
    } else if (themeNow[1] == "D") {
      return "Dark";
    } else {
      return "Dark";
    }
  }
}
