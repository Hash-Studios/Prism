import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/system_accent_channel.dart';
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
  SystemAccent? _systemAccent;
  bool _matchSystemAccent = false;

  @override
  void initState() {
    super.initState();
    _loadSystemAccent();
  }

  Future<void> _loadSystemAccent() async {
    final SystemAccent? accent = await const SystemAccentChannel().read();
    if (!mounted || accent == null) return;
    final bool enabled = getIt<SettingsLocalDataSource>().get<bool>(
      SystemAccentChannel.settingsKey,
      defaultValue: false,
    );
    setState(() {
      _systemAccent = accent;
      _matchSystemAccent = enabled;
    });
    if (enabled) _applySystemAccent(accent);
  }

  void _applySystemAccent(SystemAccent accent) {
    if (context.prismLightAccentValue(listen: false) != accent.light.toARGB32()) {
      context.setPrismLightAccent(accent.light);
    }
    if (context.prismDarkAccentValue(listen: false) != accent.dark.toARGB32()) {
      context.setPrismDarkAccent(accent.dark);
    }
  }

  Future<void> _setMatchSystemAccent(bool enabled) async {
    setState(() => _matchSystemAccent = enabled);
    await getIt<SettingsLocalDataSource>().set(SystemAccentChannel.settingsKey, enabled);
    final SystemAccent? accent = _systemAccent;
    if (enabled && accent != null) _applySystemAccent(accent);
  }

  void _pickAccent() {
    if (_matchSystemAccent) _setMatchSystemAccent(false);
  }

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
          PrismIconButton(icon: Icons.check_rounded, tooltip: 'Done', onPressed: () => Navigator.pop(context)),
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
            if (_systemAccent != null)
              PrismSwitchRow(
                title: 'Match system colour',
                subtitle: 'Use the accent colour of your phone',
                value: _matchSystemAccent,
                onChanged: _setMatchSystemAccent,
              ),
            if (showLight) ...<Widget>[
              _heading(both ? 'Light accent' : 'Accent colour'),
              AccentWrap(
                selected: lightAccent,
                onSelect: (color) {
                  setState(() => changingLight = true);
                  _pickAccent();
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
                  _pickAccent();
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
