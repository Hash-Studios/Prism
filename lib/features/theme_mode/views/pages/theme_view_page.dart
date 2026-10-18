import 'dart:math' as math;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/system_accent_channel.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/shop/domain/shop_catalog.dart';
import 'package:Prism/features/shop/views/widgets/shop_item_sheet.dart';
import 'package:Prism/features/theme_mode/data/legacy_themes.dart';
import 'package:Prism/features/theme_mode/views/pages/theme_view_widgets.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/global/svg_assets.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The text roles this page used on the current app. The redesign theme sets its own roles, so the page names them.
TextStyle _titleStyle(Color color) =>
    TextStyle(fontFamily: PrismFonts.proximaNova, fontSize: 20, fontWeight: FontWeight.w500, color: color);

TextStyle _sectionStyle(Color color) =>
    TextStyle(fontFamily: PrismFonts.proximaNova, fontSize: 16, fontWeight: FontWeight.w500, color: color);

TextStyle _panelTitleStyle(Color color) =>
    TextStyle(fontFamily: PrismFonts.proximaNova, fontSize: 24, fontWeight: FontWeight.w500, color: color);

TextStyle _chipLabelStyle(Color color) => TextStyle(
  fontFamily: PrismFonts.roboto,
  fontSize: 14,
  fontWeight: FontWeight.w500,
  letterSpacing: 0.1,
  color: color,
);

String _themePreviewSvg(ThemeData theme, Color accent) => themePicture
    .replaceAll('181818', theme.colorScheme.surface.rgbHex)
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
  late final Set<String> _legacyThemes = readLegacyThemes(getIt<SettingsLocalDataSource>());

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
              icon: Icon(JamIcons.check, size: 30, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
          ],
          elevation: 0,
          title: Text('Themes', style: _titleStyle(Theme.of(context).colorScheme.onSurface)),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    onTap: () {
                      showPrismSheet(
                        isScrollControlled: true,
                        context: context,
                        builder: (context) => _PreferencePanel(
                          selected: themeMode,
                          onSelected: (mode) {
                            PrismHaptics.selection();
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
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Proxima Nova',
                      ),
                    ),
                    subtitle: Text(context.prismModeAbs(), style: const TextStyle(fontSize: 12)),
                  ),
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(17),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.shadow.withValues(alpha: .15),
                            blurRadius: 38,
                            offset: const Offset(0, 19),
                          ),
                          BoxShadow(
                            color: Theme.of(context).colorScheme.shadow.withValues(alpha: .10),
                            blurRadius: 12,
                            offset: const Offset(0, 15),
                          ),
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
                      legacyThemes: _legacyThemes,
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
                      legacyThemes: _legacyThemes,
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
          ),
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
      child: Text(text, style: _sectionStyle(Theme.of(context).colorScheme.onSurface)),
    );
  }
}

class _ThemeChipRow extends StatelessWidget {
  const _ThemeChipRow({
    required this.themes,
    required this.selectedId,
    required this.legacyThemes,
    required this.onSelect,
  });

  final List<PrismThemeOption> themes;
  final String selectedId;

  /// Themes this device used before the coin shop sold them. They stay free.
  final Set<String> legacyThemes;
  final ValueChanged<PrismThemeOption> onSelect;

  /// A shop theme the user neither bought nor already uses. The selected theme is never locked.
  bool _locked(PrismThemeOption option, Inventory inventory) {
    final String? shopItemId = option.shopItemId;
    return shopItemId != null &&
        option.id != selectedId &&
        !legacyThemes.contains(option.id) &&
        !inventory.owns(shopItemId);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Inventory>(
      valueListenable: CoinsService.instance.inventoryNotifier,
      builder: (context, inventory, _) => _buildRow(context, inventory),
    );
  }

  Widget _buildRow(BuildContext context, Inventory inventory) {
    final Size size = MediaQuery.of(context).size;
    final double textHeight = MediaQuery.textScalerOf(context).scale(16);
    final bool anyLocked = themes.any((option) => _locked(option, inventory));
    final double baseChipHeight = size.height * 0.06 > textHeight + 20 ? size.height * 0.06 : textHeight + 20;
    final double chipHeight = baseChipHeight + (anyLocked ? textHeight + 6 : 0);
    final double rowHeight = size.height * 0.07 > chipHeight + 8 ? size.height * 0.07 : chipHeight + 8;
    return SizedBox(
      width: size.width,
      height: rowHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: themes.length,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        itemBuilder: (context, index) {
          final PrismThemeOption option = themes[index];
          final bool locked = _locked(option, inventory);
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: MaterialButton(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                padding: EdgeInsets.zero,
                onPressed: () {
                  PrismHaptics.selection();
                  if (locked) {
                    showShopItemSheet(context, shopItem(option.shopItemId!)!);
                  } else {
                    onSelect(option);
                  }
                },
                child: Stack(
                  children: [
                    Container(
                      width: math.min(size.width * 0.3, 150),
                      height: chipHeight,
                      decoration: BoxDecoration(
                        border: Border.all(color: option.theme.colorScheme.scrim.withValues(alpha: 0.12)),
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _chipLabelStyle(option.theme.colorScheme.onSurface),
                            ),
                          ),
                          if (locked)
                            const Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: PrismTag(label: 'Locked', icon: Icons.lock_rounded),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (option.id == selectedId)
                      Container(
                        width: math.min(size.width * 0.3, 150),
                        height: chipHeight,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          border: Border.all(color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.45)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Icon(JamIcons.check, color: Theme.of(context).colorScheme.surface)],
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
    final double rowHeight = MediaQuery.of(context).size.height * 0.055;
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: rowHeight < 57 ? 57 : rowHeight,
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
              behavior: HitTestBehavior.opaque,
              onTap: () {
                PrismHaptics.selection();
                onSelect(color);
              },
              child: Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(8, 8, 0, 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected == color
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                      ),
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(width: 41, height: 41),
                  ),
                  if (selected == color)
                    Container(
                      margin: const EdgeInsets.fromLTRB(8, 8, 0, 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(
                        width: 41,
                        height: 41,
                        child: Icon(JamIcons.check, color: Theme.of(context).colorScheme.surface),
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
    final ColorScheme colors = Theme.of(context).colorScheme;
    const String message =
        'Select your preferred theme mode. System mode automatically switches between light and dark depending on your device mode.';
    final TextStyle messageStyle = TextStyle(fontSize: 13, color: colors.onSurface);
    final double height = MediaQuery.of(context).size.height / 2 > 400 ? MediaQuery.of(context).size.height / 2 : 400;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                          color: Theme.of(context).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(500),
                        ),
                      ),
                    ),
                  ],
                ),
                Text('Theme Preference', style: _panelTitleStyle(Theme.of(context).colorScheme.onSurface)),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.8,
                    child: Text(message, textAlign: TextAlign.center, style: messageStyle),
                  ),
                ),
              ],
            ),
          ),
        ),
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
      child: Semantics(
        container: true,
        button: true,
        selected: selected,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: width - 20,
            height: 60,
            child: Container(
              width: width - 14,
              height: 60,
              decoration: BoxDecoration(
                color: selected ? colors.primary.withValues(alpha: 0.2) : colors.onSurface.withValues(alpha: 0.2),
                border: Border.all(color: selected ? colors.primary : colors.onSurface, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 16, color: colors.onSurface, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
