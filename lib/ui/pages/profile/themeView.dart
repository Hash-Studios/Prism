import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/darkThemeModel.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/themeModeProvider.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/analytics/analytics_service.dart';

List<Color> accentColors = [
  const Color(0xFFE57697),
  const Color(0xFFFF0000),
  const Color(0xFFF44436),
  const Color(0xFFe91e63),
  const Color(0xFF9c27b0),
  const Color(0xFF673ab7),
  const Color(0xFF0000FF),
  const Color(0xFF1976D2),
  const Color(0xFF03a9f4),
  const Color(0xFF00bcd4),
  const Color(0xFF009688),
  const Color(0xFF4caf50),
  const Color(0xFF00FF00),
  const Color(0xFF8bc34a),
  const Color(0xFFcddc39),
  const Color(0xFFffeb3b),
  const Color(0xFFffc107),
  const Color(0xFFff9800),
  const Color(0xFFff5722),
  const Color(0xFF795548),
  const Color(0xFF9e9e9e),
  const Color(0xFF607d8b),
];

class ThemeView extends StatefulWidget {
  @override
  _ThemeViewState createState() => _ThemeViewState();
}

class _ThemeViewState extends State<ThemeView> {
  ThemeData currentTheme;
  ThemeData currentDarkTheme;
  Color selectedAccentColor;
  Color selectedDarkAccentColor;
  int selectedTheme;
  int selectedDarkTheme;
  bool changingLight;
  @override
  void initState() {
    currentTheme = Provider.of<ThemeModel>(context, listen: false).currentTheme;
    selectedTheme =
        Provider.of<ThemeModel>(context, listen: false).getIndex(currentTheme);
    currentDarkTheme =
        Provider.of<DarkThemeModel>(context, listen: false).currentTheme;
    selectedDarkTheme = Provider.of<DarkThemeModel>(context, listen: false)
        .getIndex(currentDarkTheme);
    selectedAccentColor = Color(int.parse(
        Provider.of<ThemeModel>(context, listen: false)
            .currentTheme
            .errorColor
            .toString()
            .replaceAll("MaterialColor(primary value: Color(0xff", "")
            .replaceAll("Color(", "")
            .replaceAll(")", "")));
    selectedDarkAccentColor = Color(int.parse(
        Provider.of<DarkThemeModel>(context, listen: false)
            .currentTheme
            .errorColor
            .toString()
            .replaceAll("MaterialColor(primary value: Color(0xff", "")
            .replaceAll("Color(", "")
            .replaceAll(")", "")));
    changingLight = Provider.of<ThemeModeExtended>(context, listen: false)
            .getCurrentModeStyle(
                SchedulerBinding.instance.window.platformBrightness) ==
        "Light";
    super.initState();
  }

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack.toString());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          actions: <Widget>[
            IconButton(
                icon: Icon(
                  JamIcons.check,
                  size: 30,
                  color: Theme.of(context).accentColor,
                ),
                onPressed: () {
                  final accentColor = int.parse(selectedAccentColor
                      .toString()
                      .replaceAll("MaterialColor(primary value: Color(0xff", "")
                      .replaceAll("Color(", "")
                      .replaceAll(")", ""));
                  final hexString = selectedAccentColor
                      .toString()
                      .replaceAll("MaterialColor(primary value: Color(0xff", "")
                      .replaceAll("Color(0xff", "")
                      .replaceAll(")", "");
                  main.prefs.put("systemOverlayColor", accentColor);
                  analytics.logEvent(
                      name: "accent_changed", parameters: {'color': hexString});
                  navStack.removeLast();
                  debugPrint(navStack.toString());
                  Navigator.pop(context);
                })
          ],
          elevation: 0,
          title: Row(
            children: [
              Text(
                "Theme Manager",
                style: Theme.of(context)
                    .textTheme
                    .headline3
                    .copyWith(color: Theme.of(context).accentColor),
              ),
              Container(
                margin: const EdgeInsets.only(left: 3, bottom: 5),
                decoration: BoxDecoration(
                    color: Theme.of(context).errorColor,
                    borderRadius: BorderRadius.circular(500)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 1.0, horizontal: 4),
                  child: Text(
                    "BETA",
                    style: TextStyle(
                      fontSize: 9,
                      color: Theme.of(context).accentColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            ListTile(
              onTap: () {
                showModalBottomSheet(
                  isScrollControlled: true,
                  context: context,
                  builder: (context) => PreferencePanel(
                    selectedValue: Provider.of<ThemeModeExtended>(context,
                                    listen: false)
                                .currentMode ==
                            ThemeMode.light
                        ? 1
                        : Provider.of<ThemeModeExtended>(context, listen: false)
                                    .currentMode ==
                                ThemeMode.dark
                            ? 2
                            : 0,
                    func: (bool value) {
                      setState(() {
                        changingLight = value;
                      });
                    },
                  ),
                );
              },
              leading: const Icon(JamIcons.brightness),
              title: Text(
                "Theme Preference",
                style: TextStyle(
                    color: Theme.of(context).accentColor,
                    fontWeight: FontWeight.w500,
                    fontFamily: "Proxima Nova"),
              ),
              subtitle: Text(
                Provider.of<ThemeModeExtended>(context).getCurrentModeAbs(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.15),
                      blurRadius: 38,
                      offset: const Offset(0, 19),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(.10),
                      blurRadius: 12,
                      offset: const Offset(0, 15),
                    )
                  ],
                ),
                width: Provider.of<ThemeModeExtended>(context).currentMode ==
                        ThemeMode.system
                    ? MediaQuery.of(context).size.height * 0.35 * 0.4993924666
                    : MediaQuery.of(context).size.height * 0.45 * 0.4993924666,
                height: Provider.of<ThemeModeExtended>(context).currentMode ==
                        ThemeMode.system
                    ? MediaQuery.of(context).size.height * 0.35
                    : MediaQuery.of(context).size.height * 0.45,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: changingLight
                      ? SvgPicture.string(
                          themePicture
                              .replaceAll(
                                  "181818",
                                  Provider.of<ThemeModel>(context)
                                      .currentTheme
                                      .primaryColor
                                      .value
                                      .toRadixString(16)
                                      .toString()
                                      .substring(2))
                              .replaceAll(
                                  "E57697",
                                  selectedAccentColor.value
                                      .toRadixString(16)
                                      .toString()
                                      .substring(2))
                              .replaceAll(
                                  "F0F0F0",
                                  Provider.of<ThemeModel>(context)
                                      .currentTheme
                                      .accentColor
                                      .value
                                      .toRadixString(16)
                                      .toString()
                                      .substring(2))
                              .replaceAll(
                                  "2F2F2F",
                                  Provider.of<ThemeModel>(context)
                                      .currentTheme
                                      .hintColor
                                      .value
                                      .toRadixString(16)
                                      .toString()
                                      .substring(2)),
                          fit: BoxFit.cover,
                        )
                      : SvgPicture.string(
                          themePicture
                              .replaceAll(
                                  "181818",
                                  Provider.of<DarkThemeModel>(context)
                                      .currentTheme
                                      .primaryColor
                                      .value
                                      .toRadixString(16)
                                      .toString()
                                      .substring(2))
                              .replaceAll(
                                  "E57697",
                                  selectedDarkAccentColor.value
                                      .toRadixString(16)
                                      .toString()
                                      .substring(2))
                              .replaceAll(
                                  "F0F0F0",
                                  Provider.of<DarkThemeModel>(context)
                                      .currentTheme
                                      .accentColor
                                      .value
                                      .toRadixString(16)
                                      .toString()
                                      .substring(2))
                              .replaceAll(
                                  "2F2F2F",
                                  Provider.of<DarkThemeModel>(context)
                                      .currentTheme
                                      .hintColor
                                      .value
                                      .toRadixString(16)
                                      .toString()
                                      .substring(2)),
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
            const Divider(),
            Provider.of<ThemeModeExtended>(context).currentMode !=
                    ThemeMode.dark
                ? Container(
                    width: MediaQuery.of(context).size.width,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Light Themes",
                      style: Theme.of(context).textTheme.headline4,
                    ),
                  )
                : Container(),
            Provider.of<ThemeModeExtended>(context).currentMode !=
                    ThemeMode.dark
                ? Container(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height * 0.07,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: themes.length,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: MaterialButton(
                              color: Theme.of(context).hintColor,
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                Provider.of<ThemeModel>(context, listen: false)
                                    .changeThemeByID(
                                        themes.keys.toList()[index]);
                                debugPrint(selectedAccentColor.toString());
                                setState(() {
                                  changingLight = true;
                                  selectedTheme = index;
                                  selectedAccentColor = Color(int.parse(Provider
                                          .of<ThemeModel>(context,
                                              listen: false)
                                      .currentTheme
                                      .errorColor
                                      .toString()
                                      .replaceAll(
                                          "MaterialColor(primary value: Color(0xff",
                                          "")
                                      .replaceAll("Color(", "")
                                      .replaceAll(")", "")));
                                });
                                debugPrint(selectedAccentColor.toString());
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    width:
                                        MediaQuery.of(context).size.width * 0.3,
                                    height: MediaQuery.of(context).size.height *
                                        0.06,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.black12),
                                      borderRadius: BorderRadius.circular(10),
                                      color: themes[themes.keys.toList()[index]]
                                          .hintColor,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Text(
                                            themes.keys
                                                .toList()[index]
                                                .substring(2),
                                            style: Theme.of(context)
                                                .textTheme
                                                .subtitle2
                                                .copyWith(
                                                    color: themes[themes.keys
                                                            .toList()[index]]
                                                        .accentColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  index == selectedTheme
                                      ? Container(
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.3,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.06,
                                          decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .accentColor
                                                  .withOpacity(0.5),
                                              border: Border.all(
                                                  color: Colors.black45),
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                JamIcons.check,
                                                color: Theme.of(context)
                                                    .primaryColor,
                                              ),
                                            ],
                                          ),
                                        )
                                      : Container(),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Container(),
            Provider.of<ThemeModeExtended>(context).currentMode !=
                    ThemeMode.light
                ? Container(
                    width: MediaQuery.of(context).size.width,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Dark Themes",
                      style: Theme.of(context).textTheme.headline4,
                    ),
                  )
                : Container(),
            Provider.of<ThemeModeExtended>(context).currentMode !=
                    ThemeMode.light
                ? Container(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height * 0.07,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: darkThemes.length,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: MaterialButton(
                              color: Theme.of(context).hintColor,
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                Provider.of<DarkThemeModel>(context,
                                        listen: false)
                                    .changeThemeByID(
                                        darkThemes.keys.toList()[index]);
                                debugPrint(selectedDarkAccentColor.toString());
                                setState(() {
                                  changingLight = false;
                                  selectedDarkTheme = index;
                                  selectedDarkAccentColor = Color(int.parse(
                                      Provider.of<DarkThemeModel>(context,
                                              listen: false)
                                          .currentTheme
                                          .errorColor
                                          .toString()
                                          .replaceAll(
                                              "MaterialColor(primary value: Color(0xff",
                                              "")
                                          .replaceAll("Color(", "")
                                          .replaceAll(")", "")));
                                });
                                debugPrint(selectedDarkAccentColor.toString());
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    width:
                                        MediaQuery.of(context).size.width * 0.3,
                                    height: MediaQuery.of(context).size.height *
                                        0.06,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.black12),
                                      borderRadius: BorderRadius.circular(10),
                                      color: darkThemes[
                                              darkThemes.keys.toList()[index]]
                                          .hintColor,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Text(
                                            darkThemes.keys
                                                .toList()[index]
                                                .substring(2),
                                            style: Theme.of(context)
                                                .textTheme
                                                .subtitle2
                                                .copyWith(
                                                    color: darkThemes[darkThemes
                                                            .keys
                                                            .toList()[index]]
                                                        .accentColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  index == selectedDarkTheme
                                      ? Container(
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.3,
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.06,
                                          decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .accentColor
                                                  .withOpacity(0.5),
                                              border: Border.all(
                                                  color: Colors.black45),
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                JamIcons.check,
                                                color: Theme.of(context)
                                                    .primaryColor,
                                              ),
                                            ],
                                          ),
                                        )
                                      : Container(),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Container(),
            const Divider(),
            Provider.of<ThemeModeExtended>(context).currentMode !=
                    ThemeMode.dark
                ? Container(
                    width: MediaQuery.of(context).size.width,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Light Accent Color",
                      style: Theme.of(context).textTheme.headline4,
                    ),
                  )
                : Container(),
            Provider.of<ThemeModeExtended>(context).currentMode !=
                    ThemeMode.dark
                ? Container(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height * 0.055,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: accentColors.length,
                      padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              changingLight = true;
                              selectedAccentColor = accentColors[index];
                            });
                            Provider.of<ThemeModel>(context, listen: false)
                                .changeAccent(selectedAccentColor);
                          },
                          child: Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.fromLTRB(8, 8, 0, 8),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selectedAccentColor ==
                                            accentColors[index]
                                        ? Colors.white
                                        : Colors.white38,
                                  ),
                                  color: accentColors[index],
                                  shape: BoxShape.circle,
                                ),
                                child: const SizedBox(
                                  width: 41,
                                  height: 41,
                                ),
                              ),
                              selectedAccentColor == accentColors[index]
                                  ? Container(
                                      margin:
                                          const EdgeInsets.fromLTRB(8, 8, 0, 8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .accentColor
                                            .withOpacity(0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: SizedBox(
                                        width: 41,
                                        height: 41,
                                        child: Icon(
                                          JamIcons.check,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    )
                                  : Container(),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                : Container(),
            Provider.of<ThemeModeExtended>(context).currentMode !=
                    ThemeMode.light
                ? Container(
                    width: MediaQuery.of(context).size.width,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Dark Accent Color",
                      style: Theme.of(context).textTheme.headline4,
                    ),
                  )
                : Container(),
            Provider.of<ThemeModeExtended>(context).currentMode !=
                    ThemeMode.light
                ? Container(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height * 0.055,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: accentColors.length,
                      padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              changingLight = false;
                              selectedDarkAccentColor = accentColors[index];
                            });
                            Provider.of<DarkThemeModel>(context, listen: false)
                                .changeAccent(selectedDarkAccentColor);
                          },
                          child: Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.fromLTRB(8, 8, 0, 8),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selectedDarkAccentColor ==
                                            accentColors[index]
                                        ? Colors.white
                                        : Colors.white38,
                                  ),
                                  color: accentColors[index],
                                  shape: BoxShape.circle,
                                ),
                                child: const SizedBox(
                                  width: 41,
                                  height: 41,
                                ),
                              ),
                              selectedDarkAccentColor == accentColors[index]
                                  ? Container(
                                      margin:
                                          const EdgeInsets.fromLTRB(8, 8, 0, 8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .accentColor
                                            .withOpacity(0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: SizedBox(
                                        width: 41,
                                        height: 41,
                                        child: Icon(
                                          JamIcons.check,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    )
                                  : Container(),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                : Container(),
          ],
        ),
      ),
    );
  }
}

class PreferencePanel extends StatefulWidget {
  int selectedValue;
  final Function(bool value) func;
  PreferencePanel({
    Key key,
    this.selectedValue,
    this.func,
  }) : super(key: key);

  @override
  _PreferencePanelState createState() => _PreferencePanelState();
}

class _PreferencePanelState extends State<PreferencePanel> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.85;
    return Container(
      height: MediaQuery.of(context).size.height / 2 > 400
          ? MediaQuery.of(context).size.height / 2
          : 400,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  height: 5,
                  width: 30,
                  decoration: BoxDecoration(
                      color: Theme.of(context).hintColor,
                      borderRadius: BorderRadius.circular(500)),
                ),
              )
            ],
          ),
          const Spacer(),
          Text(
            "Theme Preference",
            style: Theme.of(context).textTheme.headline2,
          ),
          const Spacer(flex: 2),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      widget.selectedValue = 0;
                    });
                    Navigator.pop(context);
                    Provider.of<ThemeModeExtended>(context, listen: false)
                        .changeThemeMode("System");
                    widget.func(
                        Provider.of<ThemeModeExtended>(context, listen: false)
                                .getCurrentModeStyle(SchedulerBinding
                                    .instance.window.platformBrightness) ==
                            "Light");
                  },
                  child: Container(
                    width: width - 20,
                    height: 60,
                    child: Container(
                      width: width - 14,
                      height: 60,
                      decoration: BoxDecoration(
                        color: widget.selectedValue != 0
                            ? Theme.of(context).accentColor.withOpacity(0.2)
                            : Theme.of(context).errorColor.withOpacity(0.2),
                        border: Border.all(
                            color: widget.selectedValue != 0
                                ? Theme.of(context).accentColor
                                : Theme.of(context).errorColor,
                            width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          "System",
                          style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).accentColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      widget.selectedValue = 1;
                    });
                    Navigator.pop(context);
                    Provider.of<ThemeModeExtended>(context, listen: false)
                        .changeThemeMode("Light");
                    widget.func(true);
                  },
                  child: Container(
                    width: width - 20,
                    height: 60,
                    child: Container(
                      width: width - 14,
                      height: 60,
                      decoration: BoxDecoration(
                        color: widget.selectedValue != 1
                            ? Theme.of(context).accentColor.withOpacity(0.2)
                            : Theme.of(context).errorColor.withOpacity(0.2),
                        border: Border.all(
                            color: widget.selectedValue != 1
                                ? Theme.of(context).accentColor
                                : Theme.of(context).errorColor,
                            width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          "Light",
                          style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).accentColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      widget.selectedValue = 2;
                    });
                    Navigator.pop(context);
                    Provider.of<ThemeModeExtended>(context, listen: false)
                        .changeThemeMode("Dark");
                    widget.func(false);
                  },
                  child: Container(
                    width: width - 20,
                    height: 60,
                    child: Container(
                      width: width - 14,
                      height: 60,
                      decoration: BoxDecoration(
                        color: widget.selectedValue != 2
                            ? Theme.of(context).accentColor.withOpacity(0.2)
                            : Theme.of(context).errorColor.withOpacity(0.2),
                        border: Border.all(
                            color: widget.selectedValue != 2
                                ? Theme.of(context).accentColor
                                : Theme.of(context).errorColor,
                            width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          "Dark",
                          style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).accentColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(flex: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Text(
                "Select your preferred theme mode. System mode automatically switches between light and dark depending on your device mode.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).accentColor,
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
