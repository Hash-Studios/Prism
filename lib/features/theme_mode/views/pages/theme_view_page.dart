import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/system_accent_channel.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/theme_mode/views/pages/theme_view_widgets.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/global/svg_assets.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

String _themePreviewSvg(ThemeData theme, Color accent) => themePicture
    .replaceAll('181818', theme.primaryColor.rgbHex)
    .replaceAll('E57697', accent.rgbHex)
    .replaceAll('F0F0F0', theme.colorScheme.secondary.rgbHex)
    .replaceAll('2F2F2F', theme.colorScheme.surfaceContainerHigh.rgbHex);

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

  @override
  Widget build(BuildContext context) {
    final ThemeMode themeMode = context.prismThemeMode();
    final bool showLight = themeMode != ThemeMode.dark;
    final bool showDark = themeMode != ThemeMode.light;
    final Color lightAccent = Color(context.prismLightAccentValue());
    final Color darkAccent = Color(context.prismDarkAccentValue());
    final double screenHeight = MediaQuery.of(context).size.height;
    final double previewHeight =
        screenHeight * (themeMode == ThemeMode.system ? 0.35 : 0.45) -
        (_systemAccent == null ? 0 : screenHeight * 0.05);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _trackAccent();
      },
      child: Scaffold(
        appBar: AppBar(
          actions: <Widget>[
            IconButton(
              tooltip: 'Done',
              icon: Icon(JamIcons.check, size: 30, color: Theme.of(context).colorScheme.secondary),
              onPressed: () => Navigator.pop(context),
            ),
          ],
          elevation: 0,
          title: Text(
            'Themes',
            style: Theme.of(context).textTheme.displaySmall!.copyWith(color: Theme.of(context).colorScheme.secondary),
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
            if (_systemAccent != null)
              SwitchListTile(
                dense: true,
                value: _matchSystemAccent,
                onChanged: (enabled) {
                  PrismHaptics.selection();
                  _setMatchSystemAccent(enabled);
                },
                title: const Text('Match system colour'),
                subtitle: const Text('Use the accent colour of your phone', style: TextStyle(fontSize: 12)),
              ),
            if (showLight) ...[
              const _SectionTitle('Light Accent Color'),
              _AccentRow(
                selected: lightAccent,
                onSelect: (color) {
                  setState(() => changingLight = true);
                  _pickAccent();
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
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                padding: EdgeInsets.zero,
                onPressed: () {
                  PrismHaptics.selection();
                  onSelect(option);
                },
                child: Stack(
                  children: [
                    Container(
                      width: size.width * 0.3,
                      height: size.height * 0.06,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(10),
                        color: option.theme.colorScheme.surfaceContainerHigh,
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
        itemCount: prismAccentSwatches.length,
        padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
        itemBuilder: (context, index) {
          final Color color = prismAccentSwatches[index];
          return Semantics(
            button: true,
            selected: selected == color,
            label: 'Accent colour ${index + 1} of ${prismAccentSwatches.length}',
            child: GestureDetector(
              onTap: () {
                PrismHaptics.selection();
                onSelect(color);
              },
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
