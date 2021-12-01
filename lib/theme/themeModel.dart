import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';

Map<String, ThemeData?> themes = {
  "kLFrost White": kLightTheme,
  "kLCoffee": kLightTheme2,
  "kLRose": kLightTheme3,
  "kLCotton Blue": kLightTheme4,
};

class ThemeModel extends ChangeNotifier {
  ThemeData? currentTheme = kLightTheme;

  ThemeModel(
    this.currentTheme,
    Color? accentColor,
  ) {
    changeAccent(accentColor);
  }

  void changeAccent(Color? accentColor) {
    ThemeData newTheme = currentTheme!;
    newTheme = newTheme.copyWith(
        errorColor: accentColor,
        colorScheme: ColorScheme.light(primary: accentColor!));
    currentTheme = newTheme;
    main.prefs.put(
        "lightAccent",
        int.parse(accentColor
            .toString()
            .replaceAll("Color(", "")
            .replaceAll(")", "")));
    return notifyListeners();
  }

  int? getIndex(ThemeData? currentThemeData) {
    return themes.values.toList().contains(currentThemeData)
        ? themes.values.toList().indexOf(currentThemeData)
        : null;
  }

  String getTheme(ThemeData currentThemeData) {
    return themes.keys.toList()[getIndex(currentThemeData) ?? 0];
  }

  void changeThemeByID(String themeID) {
    logger.d(themeID);
    currentTheme = themes[themeID];
    main.prefs.put("lightThemeID", themeID);
    main.prefs.put(
        "lightAccent",
        int.parse(currentTheme!.errorColor
            .toString()
            .replaceAll("Color(", "")
            .replaceAll(")", "")));
    return notifyListeners();
  }
}
