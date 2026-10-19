import 'dart:ui' as ui;

import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_edit_pipeline.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_edit/wallpaper_filters.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The bottom half of the wallpaper editor: a Filters tab with a strip of filter thumbnails and an Adjust tab with
/// five sliders. It holds no state: the editor owns the filter stack and the adjustments.
class FilterEditorPanel extends StatelessWidget {
  const FilterEditorPanel({
    super.key,
    required this.thumbProvider,
    required this.stack,
    required this.adjustments,
    required this.effectsAvailable,
    required this.kernelThumbFilters,
    required this.onClear,
    required this.onToggle,
    required this.onAdjust,
  });

  /// A small copy of the wallpaper, drawn under every filter.
  final ImageProvider thumbProvider;

  /// The filters in use, in the order they were picked.
  final List<WallpaperFilter> stack;
  final WallpaperAdjustments adjustments;
  final bool effectsAvailable;

  /// Filters for the effect thumbnails. Filled as tiles are built, so they are not rebuilt on every frame.
  final Map<KernelEffect, ui.ImageFilter> kernelThumbFilters;
  final VoidCallback onClear;
  final ValueChanged<WallpaperFilter> onToggle;

  /// Gets a change to the adjustments. It receives the current adjustments, not the ones this panel was built with, so
  /// two changes in one frame both stay.
  final ValueChanged<WallpaperAdjustments Function(WallpaperAdjustments)> onAdjust;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: SizedBox(
        height: 244 + MediaQuery.paddingOf(context).bottom,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
          child: Column(
            children: [
              TabBar(
                onTap: (_) => PrismHaptics.selection(),
                indicatorSize: TabBarIndicatorSize.label,
                tabs: [
                  Tab(text: context.l10n.wallpaperFilterTabFilters),
                  Tab(text: context.l10n.wallpaperFilterTabAdjustments),
                ],
              ),
              Expanded(child: TabBarView(children: [_buildFiltersTab(context, cs), _buildAdjustTab(context, cs)])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersTab(BuildContext context, ColorScheme cs) {
    final List<Widget> tiles = <Widget>[
      _buildTile(
        context,
        cs,
        name: context.l10n.wallpaperFilterOriginal,
        selected: stack.isEmpty,
        order: 0,
        onTap: () {
          PrismHaptics.selection();
          onClear();
        },
        thumb: _thumb(),
      ),
      for (final ColorPreset preset in colorPresets)
        _buildTile(
          context,
          cs,
          name: preset.name,
          selected: stack.contains(preset),
          order: stack.indexOf(preset) + 1,
          onTap: () => onToggle(preset),
          thumb: ColorFiltered(colorFilter: ColorFilter.matrix(preset.matrix), child: _thumb()),
        ),
      if (effectsAvailable) ...[
        Center(child: Container(width: 1, height: 72, color: cs.onSurface.withValues(alpha: 0.12))),
        for (final KernelEffect effect in kernelEffects)
          _buildTile(
            context,
            cs,
            name: switch (effect.name) {
              'Sharpen' => context.l10n.wallpaperFilterEffectSharpen,
              'High Pass' => context.l10n.wallpaperFilterEffectHighPass,
              'Edge' => context.l10n.wallpaperFilterEffectEdge,
              'Emboss' => context.l10n.wallpaperFilterEffectEmboss,
              _ => effect.name,
            },
            selected: stack.contains(effect),
            order: stack.indexOf(effect) + 1,
            onTap: () => onToggle(effect),
            thumb: ImageFiltered(
              imageFilter: kernelThumbFilters.putIfAbsent(effect, () => kernelImageFilter(effect)),
              child: _thumb(),
            ),
          ),
      ],
    ];
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md),
      scrollDirection: Axis.horizontal,
      itemCount: tiles.length,
      separatorBuilder: (_, _) => const SizedBox(width: PrismSpace.xxs),
      itemBuilder: (_, index) => tiles[index],
    );
  }

  Widget _thumb() => Image(image: thumbProvider, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink());

  Widget _buildTile(
    BuildContext context,
    ColorScheme cs, {
    required String name,
    required bool selected,
    required int order,
    required VoidCallback onTap,
    required Widget thumb,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      onTap: onTap,
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: 84,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    AnimatedContainer(
                      duration: context.motion(PrismDurations.fast),
                      width: 64,
                      height: 92,
                      foregroundDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(PrismRadius.sm),
                        border: Border.all(color: selected ? cs.primary : Colors.transparent, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(PrismRadius.sm),
                        child: SizedBox.expand(child: thumb),
                      ),
                    ),
                    if (selected)
                      PositionedDirectional(
                        top: PrismSpace.xxs,
                        end: PrismSpace.xxs,
                        child: Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                          child: stack.length > 1
                              ? Text(
                                  NumberFormat.decimalPattern(context.l10n.localeName).format(order),
                                  style: PrismTextStyles.caption(
                                    context,
                                  ).copyWith(color: cs.onPrimary, fontSize: 10, fontWeight: FontWeight.w700),
                                )
                              : Icon(Icons.check_rounded, size: 12, color: cs.onPrimary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: PrismTextStyles.caption(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdjustTab(BuildContext context, ColorScheme cs) {
    final WallpaperAdjustments a = adjustments;
    final NumberFormat numberFormat = NumberFormat.decimalPattern(context.l10n.localeName);
    String localizedNumber(double value) => numberFormat.format(value.round());
    String signed(double value) => value.round() > 0 ? '+${localizedNumber(value)}' : localizedNumber(value);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md),
      children: [
        if (!effectsAvailable)
          Text(context.l10n.wallpaperFilterLightnessUnavailable, style: PrismTextStyles.caption(context)),
        _adjustRow(
          context,
          cs,
          icon: Icons.blur_on_rounded,
          label: context.l10n.wallpaperFilterBlur,
          value: a.blur * 100,
          min: 0,
          max: 100,
          text: localizedNumber(a.blur * 100),
          onChanged: (v) => onAdjust((current) => current.copyWith(blur: v / 100)),
          onReset: () => onAdjust((current) => current.copyWith(blur: 0)),
        ),
        _adjustRow(
          context,
          cs,
          icon: Icons.palette_outlined,
          label: context.l10n.wallpaperFilterHue,
          value: a.hue,
          min: -180,
          max: 180,
          text: '${localizedNumber(a.hue)}°',
          onChanged: (v) => onAdjust((current) => current.copyWith(hue: v)),
          onReset: () => onAdjust((current) => current.copyWith(hue: 0)),
        ),
        _adjustRow(
          context,
          cs,
          icon: JamIcons.water_drop,
          label: context.l10n.wallpaperFilterSaturation,
          value: a.saturation * 100,
          min: -100,
          max: 100,
          text: signed(a.saturation * 100),
          onChanged: (v) => onAdjust((current) => current.copyWith(saturation: v / 100)),
          onReset: () => onAdjust((current) => current.copyWith(saturation: 0)),
        ),
        _adjustRow(
          context,
          cs,
          icon: Icons.light_mode_outlined,
          label: context.l10n.wallpaperFilterLightness,
          value: a.lightness * 100,
          min: -100,
          max: 100,
          text: signed(a.lightness * 100),
          enabled: effectsAvailable,
          onChanged: (v) => onAdjust((current) => current.copyWith(lightness: v / 100)),
          onReset: () => onAdjust((current) => current.copyWith(lightness: 0)),
        ),
        _adjustRow(
          context,
          cs,
          icon: JamIcons.brightness,
          label: context.l10n.wallpaperFilterBrightness,
          value: a.brightness * 100,
          min: -100,
          max: 100,
          text: signed(a.brightness * 100),
          onChanged: (v) => onAdjust((current) => current.copyWith(brightness: v / 100)),
          onReset: () => onAdjust((current) => current.copyWith(brightness: 0)),
        ),
      ],
    );
  }

  Widget _adjustRow(
    BuildContext context,
    ColorScheme cs, {
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required String text,
    bool enabled = true,
    required ValueChanged<double> onChanged,
    required VoidCallback onReset,
  }) {
    return Row(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: onReset,
          child: Row(
            children: [
              Icon(icon, size: 24, color: cs.onSurface),
              SizedBox(
                width: 84,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: PrismSpace.xs),
                  child: Text(label, style: PrismTextStyles.rowTitle(context)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Semantics(
            label: label,
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              semanticFormatterCallback: (v) => NumberFormat.decimalPattern(context.l10n.localeName).format(v.round()),
              onChanged: enabled ? onChanged : null,
              onChangeEnd: (_) => PrismHaptics.selection(),
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(text, textAlign: TextAlign.end, style: PrismTextStyles.body(context)),
        ),
      ],
    );
  }
}
