import 'package:flutter/material.dart';
import 'package:Prism/theme/theme.dart';
import 'package:Prism/main.dart' as main;

// enum ThemeType { light, dark }
Map<String, ThemeData> themes = {
  "kLFrost White": kLightTheme,
  "kDMaterial Dark": kDarkTheme,
  "kLCream": kLightTheme2,
  "kDJust Black": kDarkTheme2,
  "kLSkin": kLightTheme3,
  "kLCotton Blue": kLightTheme4,
  "kDOlive": kLightTheme3,
  "kDDeep Ocean": kLightTheme3,
  "kDJungle": kLightTheme3,
  "kDPepper": kLightTheme3,
  "kDSky": kLightTheme3,
  "kLSteel": kLightTheme3,
};

class ThemeModel extends ChangeNotifier {
  ThemeData currentTheme = kDarkTheme;
  // ThemeType themeType = ThemeType.dark;

  ThemeModel(
    this.currentTheme,
    // this.themeType
  );

  // void toggleTheme() {
  //   if (themeType == ThemeType.dark) {
  //     main.prefs.put("darkMode", false);
  //     currentTheme = kLightTheme;
  //     themeType = ThemeType.light;
  //     debugPrint(main.prefs.get("darkMode").toString());
  //     return notifyListeners();
  //   }

  //   if (themeType == ThemeType.light) {
  //     main.prefs.put("darkMode", true);
  //     currentTheme = kDarkTheme;
  //     themeType = ThemeType.dark;
  //     debugPrint(main.prefs.get("darkMode").toString());
  //     return notifyListeners();
  //   }
  // }

  void changeAccentColor(int accentColor) {
    debugPrint(accentColor.toString());
    currentTheme = currentTheme.copyWith(errorColor: Color(accentColor));
    return notifyListeners();
  }

  void changeThemeByID(String themeID) {
    debugPrint(themeID);
    currentTheme = themes[themeID];
    main.prefs.put("themeID", themeID);
    return notifyListeners();
  }

  void changeThemeByThemeData(ThemeData themeData) {
    debugPrint(returnTheme(themeData));
    currentTheme = themeData;
    main.prefs.put("themeID", returnTheme(themeData));
    return notifyListeners();
  }

  // ThemeType returnTheme() {
  //   return themeType;
  // }
  String returnTheme(ThemeData themeData) {
    return themes.keys.firstWhere(
      (element) => themes[element] == themeData,
      orElse: () => null,
    );
  }

  int returnThemeIndex(ThemeData themeData) {
    return themes.keys.toList().indexOf(themes.keys.firstWhere(
          (element) => themes[element] == themeData,
          orElse: () => null,
        ));
  }

  String returnThemeType() {
    final String themeNow = themes.keys.firstWhere(
      (element) => themes[element] == currentTheme,
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
