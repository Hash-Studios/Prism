import 'package:flutter/material.dart';
import 'package:Prism/theme/theme.dart';
import 'package:Prism/main.dart' as main;

Map<String, ThemeData> themes = {
  "kLFrost White": kLightTheme,
  "kLCoffee": kLightTheme2,
  "kLRose": kLightTheme3,
  "kLCotton Blue": kLightTheme4,
};

class ThemeModel extends ChangeNotifier {
  ThemeData currentTheme = kLightTheme;

  ThemeModel(
    this.currentTheme,
  );

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
      orElse: () => "kLFrost White",
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
