import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/global/svg_assets.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const List<Color> _accentColors = [
  Color(0xFFE57697),
  Color(0xFFFF0000),
  Color(0xFFF44436),
  Color(0xFFe91e63),
  Color(0xFF9c27b0),
  Color(0xFF673ab7),
  Color(0xFF0000FF),
  Color(0xFF1976D2),
  Color(0xFF03a9f4),
  Color(0xFF00bcd4),
  Color(0xFF009688),
  Color(0xFF4caf50),
  Color(0xFF00FF00),
  Color(0xFF8bc34a),
  Color(0xFFcddc39),
  Color(0xFFffeb3b),
  Color(0xFFffc107),
  Color(0xFFff9800),
  Color(0xFFff5722),
  Color(0xFF795548),
  Color(0xFF9e9e9e),
  Color(0xFF607d8b),
];

String _themePreviewSvg(ThemeData theme, Color accent) => themePicture
    .replaceAll('181818', theme.primaryColor.rgbHex)
    .replaceAll('E57697', accent.rgbHex)
    .replaceAll('F0F0F0', theme.colorScheme.secondary.rgbHex)
    .replaceAll('2F2F2F', theme.hintColor.rgbHex);

@RoutePage(name: 'ThemeViewRoute')
class ThemeView extends StatefulWidget {
  const ThemeView();

  @override
  _ThemeViewState createState() => _ThemeViewState();
}

class _ThemeViewState extends State<ThemeView> {
  final SettingsLocalDataSource _settingsLocal = getIt<SettingsLocalDataSource>();
  late bool changingLight = !context.isDarkMode;

  // Theme and accent taps apply live, so every way out (Back, swipe, the check) keeps them.
  void _saveOverlayColor() {
    final Color accent = Color(context.prismLightAccentValue(listen: false));
    _settingsLocal.set('systemOverlayColor', accent.toARGB32());
    analytics.track(AccentChangedEvent(color: accent.rgbHex));
  }

  void _selectThemeMode(ThemeMode mode) {
    context.setPrismThemeMode(mode);
    setState(() {
      changingLight = switch (mode) {
        ThemeMode.light => true,
        ThemeMode.dark => false,
        ThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.light,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeMode themeMode = context.prismThemeMode();
    final bool showLight = themeMode != ThemeMode.dark;
    final bool showDark = themeMode != ThemeMode.light;
    final Color lightAccent = Color(context.prismLightAccentValue());
    final Color darkAccent = Color(context.prismDarkAccentValue());
    final double screenHeight = MediaQuery.of(context).size.height;
    final double previewHeight = screenHeight * (themeMode == ThemeMode.system ? 0.35 : 0.45);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveOverlayColor();
      },
      child: Scaffold(
        appBar: AppBar(
          actions: <Widget>[
            IconButton(
              tooltip: 'Apply theme',
              icon: Icon(JamIcons.check, size: 30, color: Theme.of(context).colorScheme.secondary),
              onPressed: () => Navigator.pop(context),
            ),
          ],
          elevation: 0,
          title: Row(
            children: [
              Text(
                'Theme Manager',
                style: Theme.of(
                  context,
                ).textTheme.displaySmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
              Container(
                margin: const EdgeInsets.only(left: 3, bottom: 5),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(500),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 4),
                  child: Text('BETA', style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.secondary)),
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
                  builder: (context) => _PreferencePanel(
                    selected: themeMode,
                    onSelected: (mode) {
                      Navigator.pop(context);
                      _selectThemeMode(mode);
                    },
                  ),
                );
              },
              leading: const Icon(JamIcons.brightness),
              title: Text(
                'Theme Preference',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Proxima Nova',
                ),
              ),
              subtitle: Text(context.prismModeAbs(), style: const TextStyle(fontSize: 12)),
            ),
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 38, offset: const Offset(0, 19)),
                    BoxShadow(color: Colors.black.withValues(alpha: .10), blurRadius: 12, offset: const Offset(0, 15)),
                  ],
                ),
                width: previewHeight * 0.4993924666,
                height: previewHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: SvgPicture.string(
                    changingLight
                        ? _themePreviewSvg(context.prismLightTheme(), lightAccent)
                        : _themePreviewSvg(context.prismDarkTheme(), darkAccent),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const Divider(),
            if (showLight) ...[
              const _SectionTitle('Light Themes'),
              _ThemeChipRow(
                themes: prismLightThemes,
                selectedId: context.prismLightThemeId(),
                onSelect: (option) {
                  context.setPrismLightTheme(option.id);
                  setState(() => changingLight = true);
                },
              ),
            ],
            if (showDark) ...[
              const _SectionTitle('Dark Themes'),
              _ThemeChipRow(
                themes: prismDarkThemes,
                selectedId: context.prismDarkThemeId(),
                onSelect: (option) {
                  context.setPrismDarkTheme(option.id);
                  setState(() => changingLight = false);
                },
              ),
            ],
            const Divider(),
            if (showLight) ...[
              const _SectionTitle('Light Accent Color'),
              _AccentRow(
                selected: lightAccent,
                onSelect: (color) {
                  setState(() => changingLight = true);
                  context.setPrismLightAccent(color);
                },
              ),
            ],
            if (showDark) ...[
              const _SectionTitle('Dark Accent Color'),
              _AccentRow(
                selected: darkAccent,
                onSelect: (color) {
                  setState(() => changingLight = false);
                  context.setPrismDarkAccent(color);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(text, style: Theme.of(context).textTheme.headlineMedium),
    );
  }
}

class _ThemeChipRow extends StatelessWidget {
  const _ThemeChipRow({required this.themes, required this.selectedId, required this.onSelect});

  final List<PrismThemeOption> themes;
  final String selectedId;
  final ValueChanged<PrismThemeOption> onSelect;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    return SizedBox(
      width: size.width,
      height: size.height * 0.07,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: themes.length,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        itemBuilder: (context, index) {
          final PrismThemeOption option = themes[index];
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: MaterialButton(
                color: Theme.of(context).hintColor,
                padding: EdgeInsets.zero,
                onPressed: () => onSelect(option),
                child: Stack(
                  children: [
                    Container(
                      width: size.width * 0.3,
                      height: size.height * 0.06,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(10),
                        color: option.theme.hintColor,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text(
                              option.label,
                              style: Theme.of(
                                context,
                              ).textTheme.titleSmall!.copyWith(color: option.theme.colorScheme.secondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (option.id == selectedId)
                      Container(
                        width: size.width * 0.3,
                        height: size.height * 0.06,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                          border: Border.all(color: Colors.black45),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Icon(JamIcons.check, color: Theme.of(context).primaryColor)],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AccentRow extends StatelessWidget {
  const _AccentRow({required this.selected, required this.onSelect});

  final Color selected;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height * 0.055,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _accentColors.length,
        padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
        itemBuilder: (context, index) {
          final Color color = _accentColors[index];
          return Semantics(
            button: true,
            selected: selected == color,
            label: 'Accent colour ${index + 1} of ${_accentColors.length}',
            child: GestureDetector(
              onTap: () => onSelect(color),
              child: Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(8, 8, 0, 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: selected == color ? Colors.white : Colors.white38),
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(width: 41, height: 41),
                  ),
                  if (selected == color)
                    Container(
                      margin: const EdgeInsets.fromLTRB(8, 8, 0, 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(
                        width: 41,
                        height: 41,
                        child: Icon(JamIcons.check, color: Theme.of(context).primaryColor),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PreferencePanel extends StatelessWidget {
  const _PreferencePanel({required this.selected, required this.onSelected});

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height / 2;
    return Container(
      height: height > 400 ? height : 400,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
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
                    borderRadius: BorderRadius.circular(500),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text('Theme Preference', style: Theme.of(context).textTheme.displayMedium),
          const Spacer(flex: 2),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _PreferenceOption(
                label: 'System',
                selected: selected == ThemeMode.system,
                onTap: () => onSelected(ThemeMode.system),
              ),
              _PreferenceOption(
                label: 'Light',
                selected: selected == ThemeMode.light,
                onTap: () => onSelected(ThemeMode.light),
              ),
              _PreferenceOption(
                label: 'Dark',
                selected: selected == ThemeMode.dark,
                onTap: () => onSelected(ThemeMode.dark),
              ),
            ],
          ),
          const Spacer(flex: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Text(
                'Select your preferred theme mode. System mode automatically switches between light and dark depending on your device mode.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.secondary),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _PreferenceOption extends StatelessWidget {
  const _PreferenceOption({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double width = MediaQuery.of(context).size.width * 0.85;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: width - 20,
          height: 60,
          child: Container(
            width: width - 14,
            height: 60,
            decoration: BoxDecoration(
              color: selected ? colors.error.withValues(alpha: 0.2) : colors.secondary.withValues(alpha: 0.2),
              border: Border.all(color: selected ? colors.error : colors.secondary, width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(fontSize: 16, color: colors.secondary, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
