import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:flutter/material.dart';
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
  final List arguments;
  const ThemeView({@required this.arguments});
  @override
  _ThemeViewState createState() => _ThemeViewState();
}

class _ThemeViewState extends State<ThemeView> {
  ThemeData currentTheme;
  Color selectedAccentColor;
  int selectedTheme;
  @override
  void initState() {
    currentTheme = widget.arguments[0] as ThemeData;
    selectedAccentColor = widget.arguments[1] as Color;
    selectedTheme = widget.arguments[2] as int;
    super.initState();
  }

  Future<bool> onWillPop() async {
    if (Provider.of<ThemeModel>(context, listen: false).currentTheme ==
        currentTheme) {
    } else {
      Provider.of<ThemeModel>(context, listen: false)
          .changeThemeByThemeData(currentTheme);
    }
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
          leading: IconButton(
              icon: const Icon(JamIcons.close),
              onPressed: () {
                if (Provider.of<ThemeModel>(context, listen: false)
                        .currentTheme ==
                    currentTheme) {
                } else {
                  Provider.of<ThemeModel>(context, listen: false)
                      .changeThemeByThemeData(currentTheme);
                }
                navStack.removeLast();
                debugPrint(navStack.toString());
                Navigator.pop(context);
              }),
          actions: <Widget>[
            IconButton(
                icon: const Icon(
                  JamIcons.check,
                  size: 30,
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
                  main.prefs.put("mainAccentColor", accentColor);
                  analytics.logEvent(
                      name: "accent_changed", parameters: {'color': hexString});
                  main.RestartWidget.restartApp(context);
                })
          ],
          elevation: 0,
          title: Text(
            "Pick a Theme",
            style: Theme.of(context).textTheme.headline3,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
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
                width: MediaQuery.of(context).size.height * 0.55 * 0.4993924666,
                height: MediaQuery.of(context).size.height * 0.55,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: SvgPicture.string(
                    themePicture
                        .replaceAll(
                            "181818",
                            Theme.of(context)
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
                            Theme.of(context)
                                .accentColor
                                .value
                                .toRadixString(16)
                                .toString()
                                .substring(2))
                        .replaceAll(
                            "2F2F2F",
                            Theme.of(context)
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
            Container(
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Themes",
                style: Theme.of(context).textTheme.headline4,
              ),
            ),
            Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height * 0.07,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: themes.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 0, 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: MaterialButton(
                        color: Theme.of(context).hintColor,
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          Provider.of<ThemeModel>(context, listen: false)
                              .changeThemeByID(themes.keys.toList()[index]);
                          debugPrint(selectedAccentColor.toString());
                          setState(() {
                            selectedTheme = index;
                            selectedAccentColor = Color(int.parse(Provider.of<
                                    ThemeModel>(context, listen: false)
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
                              width: MediaQuery.of(context).size.width * 0.3,
                              height: MediaQuery.of(context).size.height * 0.06,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black12),
                                borderRadius: BorderRadius.circular(10),
                                color: themes[themes.keys.toList()[index]]
                                    .hintColor,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Text(
                                      themes.keys.toList()[index].substring(2),
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
                                    width:
                                        MediaQuery.of(context).size.width * 0.3,
                                    height: MediaQuery.of(context).size.height *
                                        0.06,
                                    decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .accentColor
                                            .withOpacity(0.5),
                                        border:
                                            Border.all(color: Colors.black45),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          JamIcons.check,
                                          color: Theme.of(context).primaryColor,
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
            ),
            const Divider(),
            Container(
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Accent Color",
                style: Theme.of(context).textTheme.headline4,
              ),
            ),
            Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height * 0.055,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: accentColors.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedAccentColor = accentColors[index];
                      });
                    },
                    child: Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.fromLTRB(8, 8, 0, 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selectedAccentColor == accentColors[index]
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
                                margin: const EdgeInsets.fromLTRB(8, 8, 0, 8),
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
          ],
        ),
      ),
    );
  }
}
