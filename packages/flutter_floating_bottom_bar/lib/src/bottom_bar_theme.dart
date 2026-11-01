import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

import 'config/bottom_bar_layout.dart';
import 'config/bottom_bar_motion.dart';
import 'config/bottom_bar_scroll_behavior.dart';

/// App-wide defaults for [BottomBar].
///
/// Add to your `ThemeData.extensions` to change the defaults across the app:
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     extensions: const [
///       BottomBarThemeData(iconWidth: 36, iconHeight: 36),
///     ],
///   ),
/// );
/// ```
///
/// Resolution order at build time, lowest → highest precedence:
/// 1. Built-in defaults (Material 3 colors).
/// 2. `Theme.of(context).extension<BottomBarThemeData>()`.
/// 3. The `theme:` argument on [BottomBar].
/// 4. Per-widget config arguments (`layout`, `motion`, `scrollBehavior`).
@immutable
class BottomBarThemeData extends ThemeExtension<BottomBarThemeData> {
  const BottomBarThemeData({
    this.barDecoration,
    this.iconDecoration,
    this.iconWidth,
    this.iconHeight,
    this.layout,
    this.motion,
    this.scrollBehavior,
  });

  /// Decoration applied to the floating bar's outer container.
  ///
  /// Defaults to `BoxDecoration(color: colorScheme.surfaceContainer,
  /// borderRadius: BorderRadius.circular(28))` when unset.
  final BoxDecoration? barDecoration;

  /// Decoration applied to the back-to-top icon's container.
  ///
  /// Defaults to `BoxDecoration(color: colorScheme.primary,
  /// shape: BoxShape.circle)` when unset.
  final BoxDecoration? iconDecoration;

  /// Width of the back-to-top icon in logical pixels. Defaults to `30`.
  final double? iconWidth;

  /// Height of the back-to-top icon in logical pixels. Defaults to `30`.
  final double? iconHeight;

  /// Theme-level layout defaults. Overridden by the `layout:` argument on
  /// the individual [BottomBar] widget.
  final BottomBarLayout? layout;

  /// Theme-level motion defaults. Overridden by the `motion:` argument on
  /// the individual [BottomBar] widget.
  final BottomBarMotion? motion;

  /// Theme-level scroll behaviour defaults. Overridden by the
  /// `scrollBehavior:` argument on the individual [BottomBar] widget.
  final BottomBarScrollBehavior? scrollBehavior;

  /// Returns a new theme where non-null fields of [other] override fields of
  /// `this`. Null fields of [other] preserve `this`.
  BottomBarThemeData merge(BottomBarThemeData? other) {
    if (other == null) return this;
    return BottomBarThemeData(
      barDecoration: other.barDecoration ?? barDecoration,
      iconDecoration: other.iconDecoration ?? iconDecoration,
      iconWidth: other.iconWidth ?? iconWidth,
      iconHeight: other.iconHeight ?? iconHeight,
      layout: other.layout ?? layout,
      motion: other.motion ?? motion,
      scrollBehavior: other.scrollBehavior ?? scrollBehavior,
    );
  }

  /// Returns a copy of this theme with the given fields replaced by
  /// non-null values. Null arguments leave the corresponding field unchanged.
  @override
  BottomBarThemeData copyWith({
    BoxDecoration? barDecoration,
    BoxDecoration? iconDecoration,
    double? iconWidth,
    double? iconHeight,
    BottomBarLayout? layout,
    BottomBarMotion? motion,
    BottomBarScrollBehavior? scrollBehavior,
  }) {
    return BottomBarThemeData(
      barDecoration: barDecoration ?? this.barDecoration,
      iconDecoration: iconDecoration ?? this.iconDecoration,
      iconWidth: iconWidth ?? this.iconWidth,
      iconHeight: iconHeight ?? this.iconHeight,
      layout: layout ?? this.layout,
      motion: motion ?? this.motion,
      scrollBehavior: scrollBehavior ?? this.scrollBehavior,
    );
  }

  /// Linearly interpolates between this theme and [other] at fraction [t].
  ///
  /// Decoration fields use [BoxDecoration.lerp]. Numeric fields use standard
  /// linear interpolation. Config objects ([layout], [motion], [scrollBehavior])
  /// step at `t == 0.5` — `this` for `t < 0.5`, [other] for `t >= 0.5`.
  @override
  BottomBarThemeData lerp(
    covariant ThemeExtension<BottomBarThemeData>? other,
    double t,
  ) {
    if (other is! BottomBarThemeData) return this;
    return BottomBarThemeData(
      barDecoration: BoxDecoration.lerp(barDecoration, other.barDecoration, t),
      iconDecoration: BoxDecoration.lerp(
        iconDecoration,
        other.iconDecoration,
        t,
      ),
      iconWidth: lerpDouble(iconWidth, other.iconWidth, t),
      iconHeight: lerpDouble(iconHeight, other.iconHeight, t),
      // Config objects are stepped at t < 0.5 → this, t >= 0.5 → other.
      layout: t < 0.5 ? layout : other.layout,
      motion: t < 0.5 ? motion : other.motion,
      scrollBehavior: t < 0.5 ? scrollBehavior : other.scrollBehavior,
    );
  }
}
