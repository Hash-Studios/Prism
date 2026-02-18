import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

@RoutePage(name: 'ThemeViewRoute')
class ThemeView extends StatefulWidget {
  @override
  _ThemeViewState createState() => _ThemeViewState();
}

class _ThemeViewState extends State<ThemeView> {
  ThemeData? currentTheme;
  ThemeData? currentDarkTheme;
  Color? selectedAccentColor;
  Color? selectedDarkAccentColor;
  int? selectedTheme;
  int? selectedDarkTheme;
  late bool changingLight;
  @override
  void initState() {
    currentTheme = context.prismLightTheme(listen: false);
    selectedTheme = PrismThemeMapper.lightThemeIndex(context.prismLightThemeId(listen: false));
    currentDarkTheme = context.prismDarkTheme(listen: false);
    selectedDarkTheme = PrismThemeMapper.darkThemeIndex(context.prismDarkThemeId(listen: false));
    selectedAccentColor = Color(context.prismLightAccentValue(listen: false));
    selectedDarkAccentColor = Color(context.prismDarkAccentValue(listen: false));
    changingLight = context.prismModeStyleForWindow(listen: false) == "Light";
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: <Widget>[
          IconButton(
              icon: Icon(
                JamIcons.check,
                size: 30,
                color: Theme.of(context).colorScheme.secondary,
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
                analytics.logEvent(name: "accent_changed", parameters: {'color': hexString});
                Navigator.pop(context);
              })
        ],
        elevation: 0,
        title: Row(
          children: [
            Text(
              "Theme Manager",
              style: Theme.of(context).textTheme.displaySmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
            ),
            Container(
              margin: const EdgeInsets.only(left: 3, bottom: 5),
              decoration:
                  BoxDecoration(color: Theme.of(context).colorScheme.error, borderRadius: BorderRadius.circular(500)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 4),
                child: Text(
                  "BETA",
                  style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(context).colorScheme.secondary,
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
                  selectedValue: context.prismThemeMode(listen: false) == ThemeMode.light
                      ? 1
                      : context.prismThemeMode(listen: false) == ThemeMode.dark
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
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: Text(
              context.prismModeAbs(),
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
                    color: Colors.black.withValues(alpha: .15),
                    blurRadius: 38,
                    offset: const Offset(0, 19),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .10),
                    blurRadius: 12,
                    offset: const Offset(0, 15),
                  )
                ],
              ),
              width: context.prismThemeMode() == ThemeMode.system
                  ? MediaQuery.of(context).size.height * 0.35 * 0.4993924666
                  : MediaQuery.of(context).size.height * 0.45 * 0.4993924666,
              height: context.prismThemeMode() == ThemeMode.system
                  ? MediaQuery.of(context).size.height * 0.35
                  : MediaQuery.of(context).size.height * 0.45,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: changingLight
                    ? SvgPicture.string(
                        themePicture
                            .replaceAll("181818",
                                context.prismLightTheme().primaryColor.toARGB32().toRadixString(16).substring(2))
                            .replaceAll("E57697", selectedAccentColor!.toARGB32().toRadixString(16).substring(2))
                            .replaceAll(
                                "F0F0F0",
                                context
                                    .prismLightTheme()
                                    .colorScheme
                                    .secondary
                                    .toARGB32()
                                    .toRadixString(16)
                                    .substring(2))
                            .replaceAll("2F2F2F",
                                context.prismLightTheme().hintColor.toARGB32().toRadixString(16).substring(2)),
                        fit: BoxFit.cover,
                      )
                    : SvgPicture.string(
                        themePicture
                            .replaceAll("181818",
                                context.prismDarkTheme().primaryColor.toARGB32().toRadixString(16).substring(2))
                            .replaceAll("E57697", selectedDarkAccentColor!.toARGB32().toRadixString(16).substring(2))
                            .replaceAll(
                                "F0F0F0",
                                context
                                    .prismDarkTheme()
                                    .colorScheme
                                    .secondary
                                    .toARGB32()
                                    .toRadixString(16)
                                    .substring(2))
                            .replaceAll(
                                "2F2F2F", context.prismDarkTheme().hintColor.toARGB32().toRadixString(16).substring(2)),
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
          const Divider(),
          if (context.prismThemeMode() != ThemeMode.dark)
            Container(
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Light Themes",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            )
          else
            Container(),
          if (context.prismThemeMode() != ThemeMode.dark)
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height * 0.07,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: prismLightThemes.length,
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
                          context.setPrismLightTheme(prismLightThemes.keys.toList()[index]);
                          logger.d(selectedAccentColor.toString());
                          setState(() {
                            changingLight = true;
                            selectedTheme = index;
                            selectedAccentColor = Color(context.prismLightAccentValue(listen: false));
                          });
                          logger.d(selectedAccentColor.toString());
                        },
                        child: Stack(
                          children: [
                            Container(
                              width: MediaQuery.of(context).size.width * 0.3,
                              height: MediaQuery.of(context).size.height * 0.06,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black12),
                                borderRadius: BorderRadius.circular(10),
                                color: prismLightThemes[prismLightThemes.keys.toList()[index]]!.hintColor,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Text(
                                      prismLightThemes.keys.toList()[index].substring(2),
                                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                            color: prismLightThemes[prismLightThemes.keys.toList()[index]]!
                                                .colorScheme
                                                .secondary,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (index == selectedTheme)
                              Container(
                                width: MediaQuery.of(context).size.width * 0.3,
                                height: MediaQuery.of(context).size.height * 0.06,
                                decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                                    border: Border.all(color: Colors.black45),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      JamIcons.check,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Container(),
          if (context.prismThemeMode() != ThemeMode.light)
            Container(
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Dark Themes",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            )
          else
            Container(),
          if (context.prismThemeMode() != ThemeMode.light)
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height * 0.07,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: prismDarkThemes.length,
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
                          context.setPrismDarkTheme(prismDarkThemes.keys.toList()[index]);
                          logger.d(selectedDarkAccentColor.toString());
                          setState(() {
                            changingLight = false;
                            selectedDarkTheme = index;
                            selectedDarkAccentColor = Color(context.prismDarkAccentValue(listen: false));
                          });
                          logger.d(selectedDarkAccentColor.toString());
                        },
                        child: Stack(
                          children: [
                            Container(
                              width: MediaQuery.of(context).size.width * 0.3,
                              height: MediaQuery.of(context).size.height * 0.06,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black12),
                                borderRadius: BorderRadius.circular(10),
                                color: prismDarkThemes[prismDarkThemes.keys.toList()[index]]!.hintColor,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Text(
                                      prismDarkThemes.keys.toList()[index].substring(2),
                                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                            color: prismDarkThemes[prismDarkThemes.keys.toList()[index]]!
                                                .colorScheme
                                                .secondary,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (index == selectedDarkTheme)
                              Container(
                                width: MediaQuery.of(context).size.width * 0.3,
                                height: MediaQuery.of(context).size.height * 0.06,
                                decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                                    border: Border.all(color: Colors.black45),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      JamIcons.check,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Container(),
          const Divider(),
          if (context.prismThemeMode() != ThemeMode.dark)
            Container(
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Light Accent Color",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            )
          else
            Container(),
          if (context.prismThemeMode() != ThemeMode.dark)
            SizedBox(
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
                      context.setPrismLightAccent(selectedAccentColor);
                    },
                    child: Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.fromLTRB(8, 8, 0, 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selectedAccentColor == accentColors[index] ? Colors.white : Colors.white38,
                            ),
                            color: accentColors[index],
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox(
                            width: 41,
                            height: 41,
                          ),
                        ),
                        if (selectedAccentColor == accentColors[index])
                          Container(
                            margin: const EdgeInsets.fromLTRB(8, 8, 0, 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
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
                        else
                          Container(),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            Container(),
          if (context.prismThemeMode() != ThemeMode.light)
            Container(
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Dark Accent Color",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            )
          else
            Container(),
          if (context.prismThemeMode() != ThemeMode.light)
            SizedBox(
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
                      context.setPrismDarkAccent(selectedDarkAccentColor);
                    },
                    child: Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.fromLTRB(8, 8, 0, 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: selectedDarkAccentColor == accentColors[index] ? Colors.white : Colors.white38,
                            ),
                            color: accentColors[index],
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox(
                            width: 41,
                            height: 41,
                          ),
                        ),
                        if (selectedDarkAccentColor == accentColors[index])
                          Container(
                            margin: const EdgeInsets.fromLTRB(8, 8, 0, 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
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
                        else
                          Container(),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            Container(),
        ],
      ),
    );
  }
}

class PreferencePanel extends StatefulWidget {
  final int? selectedValue;
  final Function(bool value)? func;
  const PreferencePanel({
    super.key,
    this.selectedValue,
    this.func,
  });

  @override
  _PreferencePanelState createState() => _PreferencePanelState();
}

class _PreferencePanelState extends State<PreferencePanel> {
  late int? _selectedValue;

  @override
  void initState() {
    _selectedValue = widget.selectedValue;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.85;
    return Container(
      height: MediaQuery.of(context).size.height / 2 > 400 ? MediaQuery.of(context).size.height / 2 : 400,
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
                  decoration:
                      BoxDecoration(color: Theme.of(context).hintColor, borderRadius: BorderRadius.circular(500)),
                ),
              )
            ],
          ),
          const Spacer(),
          Text(
            "Theme Preference",
            style: Theme.of(context).textTheme.displayMedium,
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
                      _selectedValue = 0;
                    });
                    Navigator.pop(context);
                    context.setPrismThemeMode("System");
                    widget.func!(context.prismModeStyleForWindow(listen: false) == "Light");
                  },
                  child: SizedBox(
                    width: width - 20,
                    height: 60,
                    child: Container(
                      width: width - 14,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _selectedValue != 0
                            ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2)
                            : Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                        border: Border.all(
                            color: _selectedValue != 0
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context).colorScheme.error,
                            width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          "System",
                          style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.secondary,
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
                      _selectedValue = 1;
                    });
                    Navigator.pop(context);
                    context.setPrismThemeMode("Light");
                    widget.func!(true);
                  },
                  child: SizedBox(
                    width: width - 20,
                    height: 60,
                    child: Container(
                      width: width - 14,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _selectedValue != 1
                            ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2)
                            : Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                        border: Border.all(
                            color: _selectedValue != 1
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context).colorScheme.error,
                            width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          "Light",
                          style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.secondary,
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
                      _selectedValue = 2;
                    });
                    Navigator.pop(context);
                    context.setPrismThemeMode("Dark");
                    widget.func!(false);
                  },
                  child: SizedBox(
                    width: width - 20,
                    height: 60,
                    child: Container(
                      width: width - 14,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _selectedValue != 2
                            ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2)
                            : Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                        border: Border.all(
                            color: _selectedValue != 2
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context).colorScheme.error,
                            width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          "Dark",
                          style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.secondary,
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
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Text(
                "Select your preferred theme mode. System mode automatically switches between light and dark depending on your device mode.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.secondary,
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
