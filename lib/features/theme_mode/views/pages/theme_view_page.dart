import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/theme_mode/views/pages/theme_view_widgets.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage(name: 'ThemeViewRoute')
class ThemeView extends StatefulWidget {
  const ThemeView();

  @override
  _ThemeViewState createState() => _ThemeViewState();
}

class _ThemeViewState extends State<ThemeView> {
  late bool changingLight = !context.isDarkMode;

  // Theme and accent taps apply live, so every way out (Back, swipe, the check) keeps them.
  void _trackAccent() {
    final Color accent = Color(context.prismLightAccentValue(listen: false));
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

  static String _modeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  static IconData _modeIcon(ThemeMode mode) => switch (mode) {
    ThemeMode.system => Icons.brightness_auto_rounded,
    ThemeMode.light => Icons.light_mode_rounded,
    ThemeMode.dark => Icons.dark_mode_rounded,
  };

  Widget _heading(String title) => PrismSectionHeader(
    title: title,
    small: true,
    padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xl, PrismSpace.page, PrismSpace.sm),
  );

  @override
  Widget build(BuildContext context) {
    final ThemeMode themeMode = context.prismThemeMode();
    final bool showLight = themeMode != ThemeMode.dark;
    final bool showDark = themeMode != ThemeMode.light;
    final Color lightAccent = Color(context.prismLightAccentValue());
    final Color darkAccent = Color(context.prismDarkAccentValue());
    final String lightId = context.prismLightThemeId();
    final String darkId = context.prismDarkThemeId();
    final bool previewLight = changingLight && showLight || !showDark;
    final ThemeData previewTheme = previewLight ? context.prismLightTheme() : context.prismDarkTheme();
    final String previewId = previewLight ? lightId : darkId;
    final List<PrismThemeOption> previewOptions = previewLight ? prismLightThemes : prismDarkThemes;
    final String previewName = (prismThemeById(previewOptions, previewId) ?? previewOptions.first).label;
    final bool both = showLight && showDark;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _trackAccent();
      },
      child: PrismPage(
        title: 'Themes',
        actions: <Widget>[
          PrismIconButton(icon: Icons.check_rounded, tooltip: 'Apply theme', onPressed: () => Navigator.pop(context)),
        ],
        body: ListView(
          padding: const EdgeInsets.only(top: PrismSpace.xs, bottom: PrismSpace.xxxl),
          children: <Widget>[
            Padding(
              padding: PrismSpace.pageInsets,
              child: PrismSegmented<ThemeMode>(
                values: ThemeMode.values,
                selected: themeMode,
                labelOf: _modeLabel,
                iconOf: _modeIcon,
                onChanged: _selectThemeMode,
              ),
            ),
            const SizedBox(height: PrismSpace.xl),
            Center(
              child: ThemePreview(
                theme: previewTheme,
                previewKey: '$previewId-${previewTheme.colorScheme.primary.toARGB32()}',
              ),
            ),
            const SizedBox(height: PrismSpace.xs),
            Center(child: Text(previewName, style: PrismTextStyles.caption(context))),
            if (showLight) ...<Widget>[
              _heading('Light themes'),
              ThemeSwatchRow(
                themes: prismLightThemes,
                selectedId: lightId,
                accent: lightAccent,
                onSelect: (option) {
                  context.setPrismLightTheme(option.id);
                  setState(() => changingLight = true);
                },
              ),
            ],
            if (showDark) ...<Widget>[
              _heading('Dark themes'),
              ThemeSwatchRow(
                themes: prismDarkThemes,
                selectedId: darkId,
                accent: darkAccent,
                onSelect: (option) {
                  context.setPrismDarkTheme(option.id);
                  setState(() => changingLight = false);
                },
              ),
            ],
            if (showLight) ...<Widget>[
              _heading(both ? 'Light accent' : 'Accent colour'),
              AccentWrap(
                selected: lightAccent,
                onSelect: (color) {
                  setState(() => changingLight = true);
                  context.setPrismLightAccent(color);
                },
              ),
            ],
            if (showDark) ...<Widget>[
              _heading(both ? 'Dark accent' : 'Accent colour'),
              AccentWrap(
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
