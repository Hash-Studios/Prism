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
    Color accentColor,
  ) {
    changeAccent(accentColor);
  }

  void changeAccent(Color accentColor) {
    ThemeData newTheme = currentTheme;
    newTheme = newTheme.copyWith(errorColor: accentColor);
    currentTheme = newTheme;
    main.prefs.put(
        "darkAccent",
        int.parse(accentColor
            .toString()
            .replaceAll("Color(", "")
            .replaceAll(")", "")));
    return notifyListeners();
  }

  void changeThemeByID(String themeID) {
    debugPrint(themeID);
    currentTheme = darkThemes[themeID];
    main.prefs.put("darkThemeID", themeID);
    return notifyListeners();
  }

  void changeThemeByThemeData(ThemeData themeData) {
    debugPrint(returnTheme(themeData));
    currentTheme = themeData;
    main.prefs.put("darkThemeID", returnTheme(themeData));
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
}
