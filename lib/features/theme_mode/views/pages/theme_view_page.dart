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
import 'package:Prism/features/theme_mode/biz/bloc/theme_bloc.j.dart';
import 'package:Prism/features/theme_mode/data/legacy_themes.dart';
import 'package:Prism/features/theme_mode/views/pages/theme_view_widgets.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/features/theme_mode/views/widgets/custom_accent_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_color_scheme.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage(name: 'ThemeViewRoute')
class ThemeView extends StatefulWidget {
  const ThemeView();

  @override
  _ThemeViewState createState() => _ThemeViewState();
}

class _ThemeViewState extends State<ThemeView> {
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

  // Theme and accent taps apply live, so every way out (Back, swipe) keeps them.
  void _trackAccent() {
    final Color accent = Color(context.prismLightAccentValue(listen: false));
    analytics.track(AccentChangedEvent(color: accent.rgbHex));
  }

  void _selectTheme(PrismThemeOption option, {required bool light}) {
    if (light) {
      context.setPrismLightTheme(option.id);
    } else {
      context.setPrismDarkTheme(option.id);
    }
    analytics.track(ThemeChangedEvent(themeId: option.id));
  }

  String _modeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => context.l10n.wallpaperThemeModeSystem,
    ThemeMode.light => context.l10n.wallpaperThemeModeLight,
    ThemeMode.dark => context.l10n.wallpaperThemeModeDark,
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeState themeState = context.watch<ThemeBloc>().state;
    final ThemeMode themeMode = context.prismThemeMode();
    final bool showLight = themeMode != ThemeMode.dark;
    final bool showDark = themeMode != ThemeMode.light;
    final PrismThemeOption lightOption = themeState.themeOption(Brightness.light);
    final PrismThemeOption darkOption = themeState.themeOption(Brightness.dark);
    final bool showLightAccent = showLight && lightOption.usesAccent;
    final bool showDarkAccent = showDark && darkOption.usesAccent;
    final bool showMaterialYouNote = (showLight && !lightOption.usesAccent) || (showDark && !darkOption.usesAccent);
    final Color lightAccent = Color(context.prismLightAccentValue());
    final Color darkAccent = Color(context.prismDarkAccentValue());
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _trackAccent();
      },
      child: PrismPage(
        title: l10n.wallpaperThemeTitle,
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xxxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              PrismSegmented<ThemeMode>(
                values: const <ThemeMode>[ThemeMode.system, ThemeMode.light, ThemeMode.dark],
                selected: themeMode,
                labelOf: _modeLabel,
                iconOf: (mode) => switch (mode) {
                  ThemeMode.system => Icons.brightness_auto_rounded,
                  ThemeMode.light => Icons.light_mode_rounded,
                  ThemeMode.dark => Icons.dark_mode_rounded,
                },
                onChanged: context.setPrismThemeMode,
              ),
              if (showLight) ...<Widget>[
                PrismSectionHeader(title: l10n.wallpaperThemeLightThemes),
                _ThemeGrid(
                  key: const ValueKey<String>('theme-grid-light'),
                  themes: prismThemeOptions(Brightness.light, themeState.system),
                  selectedId: lightOption.id,
                  accent: lightAccent,
                  legacyThemes: _legacyThemes,
                  onSelect: (option) => _selectTheme(option, light: true),
                ),
              ],
              if (showDark) ...<Widget>[
                PrismSectionHeader(title: l10n.wallpaperThemeDarkThemes),
                _ThemeGrid(
                  key: const ValueKey<String>('theme-grid-dark'),
                  themes: prismThemeOptions(Brightness.dark, themeState.system),
                  selectedId: darkOption.id,
                  accent: darkAccent,
                  legacyThemes: _legacyThemes,
                  onSelect: (option) => _selectTheme(option, light: false),
                ),
              ],
              if (_systemAccent != null && (showLightAccent || showDarkAccent)) ...<Widget>[
                const SizedBox(height: PrismSpace.xl),
                PrismGroup(
                  children: <Widget>[
                    PrismSwitchRow(
                      icon: Icons.palette_rounded,
                      title: l10n.wallpaperMatchSystemColour,
                      subtitle: l10n.wallpaperUsePhoneAccent,
                      value: _matchSystemAccent,
                      onChanged: _setMatchSystemAccent,
                    ),
                  ],
                ),
              ],
              if (showLightAccent) ...<Widget>[
                PrismSectionHeader(title: l10n.wallpaperThemeLightAccent),
                _AccentPicker(
                  selected: lightAccent,
                  surface: context.prismLightTheme().colorScheme.surface,
                  onSelect: (color) {
                    _pickAccent();
                    context.setPrismLightAccent(color);
                  },
                ),
              ],
              if (showDarkAccent) ...<Widget>[
                PrismSectionHeader(title: l10n.wallpaperThemeDarkAccent),
                _AccentPicker(
                  selected: darkAccent,
                  surface: context.prismDarkTheme().colorScheme.surface,
                  onSelect: (color) {
                    _pickAccent();
                    context.setPrismDarkAccent(color);
                  },
                ),
              ],
              if (showMaterialYouNote) ...<Widget>[
                const SizedBox(height: PrismSpace.xl),
                Text(l10n.wallpaperThemeMaterialYouNote, style: PrismTextStyles.body(context)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A row of themes that scrolls sideways, each shown as a small app in its own colours with its name below.
class _ThemeGrid extends StatelessWidget {
  const _ThemeGrid({
    super.key,
    required this.themes,
    required this.selectedId,
    required this.accent,
    required this.legacyThemes,
    required this.onSelect,
  });

  final List<PrismThemeOption> themes;
  final String selectedId;

  /// The slot's accent, so a preview shows the theme as it will look.
  final Color accent;

  /// Themes this device used before the coin shop sold them. They stay free.
  final Set<String> legacyThemes;
  final ValueChanged<PrismThemeOption> onSelect;

  static const double _cardWidth = 104;
  static const double _gap = PrismSpace.md;

  /// A 104 point card: the preview with its ring (170 with the gap under it), then the name, which grows with the
  /// text size. The Locked tag sits on the preview.
  static const double _fixedHeight = 170;
  static const double _textHeight = 28;

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
      builder: (context, inventory, _) => SizedBox(
        height: _fixedHeight + MediaQuery.textScalerOf(context).scale(_textHeight),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          // The row starts at the page margin and scrolls out to the screen edge.
          clipBehavior: Clip.none,
          itemCount: themes.length,
          separatorBuilder: (_, _) => const SizedBox(width: _gap),
          itemBuilder: (context, index) {
            final PrismThemeOption option = themes[index];
            return SizedBox(
              width: _cardWidth,
              child: _ThemeTile(
                option: option,
                accent: accent,
                selected: option.id == selectedId,
                locked: _locked(option, inventory),
                onTap: () {
                  PrismHaptics.selection();
                  if (_locked(option, inventory)) {
                    showShopItemSheet(context, shopItem(option.shopItemId!)!);
                  } else {
                    onSelect(option);
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.option,
    required this.accent,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final PrismThemeOption option;
  final Color accent;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppLocalizations l10n = context.l10n;
    final String name = prismThemeDisplayName(option, l10n);
    final ThemeData theme = option.usesAccent ? withPrismAccent(option.theme, accent.toARGB32()) : option.theme;
    return Semantics(
      button: true,
      selected: selected,
      label: locked ? '$name, ${l10n.coreThemeLocked}' : name,
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            children: <Widget>[
              Stack(
                children: <Widget>[
                  // The ring keeps its width when not selected, so selecting a theme never shifts the grid.
                  AnimatedContainer(
                    duration: context.motion(PrismDurations.fast),
                    curve: PrismCurves.move,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(PrismRadius.sm + 3),
                      border: Border.all(color: selected ? cs.primary : Colors.transparent, width: 2),
                    ),
                    child: PrismThemePreview(theme: theme),
                  ),
                  if (selected)
                    PositionedDirectional(
                      top: PrismSpace.xs + 1,
                      end: PrismSpace.xs + 1,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                        child: Icon(Icons.check_rounded, size: 14, color: cs.onPrimary),
                      ),
                    ),
                  // A locked theme is never the selected one, so this never meets the check badge.
                  if (locked)
                    PositionedDirectional(
                      top: PrismSpace.xs + 1,
                      start: PrismSpace.xs + 1,
                      end: PrismSpace.xs + 1,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _LockedTag(label: l10n.coreThemeLocked),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: PrismSpace.xs),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: PrismTextStyles.rowTitle(
                  context,
                ).copyWith(fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Locked tag on a theme preview. It stays readable on any theme, so it is black with white text.
class _LockedTag extends StatelessWidget {
  const _LockedTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(PrismRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.lock_rounded, size: 12, color: Colors.white),
            const SizedBox(width: PrismSpace.xxs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PrismTextStyles.caption(context).copyWith(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The custom colour well first, then the swatches, as 44-point circles that wrap.
class _AccentPicker extends StatelessWidget {
  const _AccentPicker({required this.selected, required this.surface, required this.onSelect});

  final Color selected;

  /// The page background the custom accent must stay readable on.
  final Color surface;
  final ValueChanged<Color> onSelect;

  static const double _size = 44;

  /// The hue wheel on the custom colour well.
  static const List<Color> _hues = <Color>[
    Color(0xFFFF3B30),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF00C7BE),
    Color(0xFF007AFF),
    Color(0xFFAF52DE),
    Color(0xFFFF3B30),
  ];

  Future<void> _pickCustom(BuildContext context) async {
    PrismHaptics.selection();
    final Color? picked = await showCustomAccentSheet(context, initial: selected, surface: surface);
    if (picked != null && context.mounted) onSelect(picked);
  }

  @override
  Widget build(BuildContext context) {
    final bool isCustom = !prismAccentSwatches.contains(selected);
    return Wrap(
      spacing: PrismSpace.sm,
      runSpacing: PrismSpace.sm,
      children: <Widget>[
        _Swatch(
          label: context.l10n.coreCustomAccent,
          selected: isCustom,
          fill: isCustom ? selected : null,
          ring: const SweepGradient(colors: _hues),
          onTap: () => _pickCustom(context),
        ),
        for (int i = 0; i < prismAccentSwatches.length; i++)
          _Swatch(
            label: context.l10n.coreThemeAccentSemanticLabel(i + 1, prismAccentSwatches.length),
            selected: selected == prismAccentSwatches[i],
            fill: prismAccentSwatches[i],
            onTap: () {
              PrismHaptics.selection();
              onSelect(prismAccentSwatches[i]);
            },
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.label, required this.selected, required this.fill, required this.onTap, this.ring});

  final String label;
  final bool selected;

  /// The colour shown. Null on the custom well before a custom colour is picked.
  final Color? fill;

  /// Drawn around the custom well so it reads as "any colour".
  final Gradient? ring;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color? color = fill;
    // Selected: a 2-point ring in the swatch colour with a gap, as on iOS. A swatch near the page colour keeps a
    // hairline so it does not vanish.
    final Widget dot = Container(
      key: ValueKey<String>('accent-dot-$label'),
      decoration: BoxDecoration(
        color: color ?? cs.surface,
        shape: BoxShape.circle,
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: color == null
          ? Icon(Icons.colorize_rounded, size: 18, color: cs.onSurface)
          : selected
          ? Icon(Icons.check_rounded, size: 20, color: prismOnColor(color))
          : null,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: _AccentPicker._size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: ring,
              border: ring == null && selected ? Border.all(color: color ?? cs.onSurface, width: 2) : null,
            ),
            child: Padding(padding: EdgeInsets.all(ring != null ? 3 : (selected ? 4 : 0)), child: dot),
          ),
        ),
      ),
    );
  }
}
