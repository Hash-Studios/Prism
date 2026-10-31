import 'package:flutter/widgets.dart';

/// Layout configuration for [BottomBar].
///
/// Group all sizing/positioning concerns into one immutable, const-friendly
/// value object so the [BottomBar] constructor stays readable.
///
/// [width] is always clamped by the host viewport, and optionally by
/// [maxWidth]. Use [BottomBarLayout.adaptive] when the bar should fill the
/// available host width up to a hard cap.
@immutable
class BottomBarLayout {
  const BottomBarLayout({
    this.width = 300,
    this.maxWidth,
    this.offset = 10,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.iconOffset = Offset.zero,
    this.alignment = Alignment.bottomCenter,
    this.fit = StackFit.loose,
    this.clip = Clip.hardEdge,
    this.respectSafeArea = true,
    this.avoidKeyboard = true,
  }) : assert(
         maxWidth == null || (maxWidth >= 0 && maxWidth < double.infinity),
       );

  /// Creates a layout that fills the available host width up to [maxWidth].
  ///
  /// This is equivalent to setting [width] to `double.infinity` while keeping
  /// the regular constructor's other defaults intact. [maxWidth] must be
  /// finite and non-negative.
  const BottomBarLayout.adaptive({
    required double maxWidth,
    this.offset = 10,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.iconOffset = Offset.zero,
    this.alignment = Alignment.bottomCenter,
    this.fit = StackFit.loose,
    this.clip = Clip.hardEdge,
    this.respectSafeArea = true,
    this.avoidKeyboard = true,
  }) : assert(maxWidth >= 0 && maxWidth < double.infinity),
       maxWidth = maxWidth,
       width = double.infinity;

  /// Requested width of the bar before viewport and [maxWidth] clamping.
  final double width;

  /// Maximum width of the bar after host constraints are applied.
  ///
  /// When null, [width] is the only explicit width cap. Must be finite and
  /// non-negative when provided.
  final double? maxWidth;

  /// Padding/offset from all sides of the host stack.
  ///
  /// This contributes to the layout footprint reported through
  /// [BottomBarScope.barHeight] and reserved by [BottomBarBodyPadding].
  final double offset;

  /// Border radius applied to the bar's default decoration.
  ///
  /// Defaults to a 28px Material 3 radius, matching the built-in theme.
  /// Pass [BorderRadius.zero] for a square bar.
  final BorderRadius borderRadius;

  /// Additional translation applied only to the built-in hidden action.
  ///
  /// For example, `Offset(0, 10)` moves the icon 10 logical pixels lower
  /// without changing the bar position.
  final Offset iconOffset;

  /// Alignment of the bar (and the built-in hidden action) within the host
  /// stack.
  final Alignment alignment;

  /// `Stack.fit` applied to the host stack.
  final StackFit fit;

  /// `Stack.clipBehavior` applied to the host stack.
  final Clip clip;

  /// When true, the bar is wrapped in a `SafeArea`; when false, the bar may
  /// extend into system UI areas.
  final bool respectSafeArea;

  /// When true, the bar and the built-in hidden action are padded by
  /// `MediaQuery.viewInsets.bottom` so they sit above the on-screen keyboard.
  ///
  /// Has no effect when `viewInsets.bottom` is already zero, which is the
  /// typical case for a `Scaffold` body since the `Scaffold` already shrinks
  /// its body to avoid the keyboard. Does not change [BottomBarScope.barHeight].
  final bool avoidKeyboard;

  /// Returns a copy of this layout with the given fields replaced by non-null
  /// values.
  ///
  /// Null arguments leave the corresponding field unchanged. Set
  /// [clearMaxWidth] to true to remove an existing [maxWidth] cap.
  BottomBarLayout copyWith({
    double? width,
    double? maxWidth,
    bool clearMaxWidth = false,
    double? offset,
    BorderRadius? borderRadius,
    Offset? iconOffset,
    Alignment? alignment,
    StackFit? fit,
    Clip? clip,
    bool? respectSafeArea,
    bool? avoidKeyboard,
  }) {
    assert(
      !clearMaxWidth || maxWidth == null,
      'maxWidth and clearMaxWidth cannot both be provided.',
    );
    return BottomBarLayout(
      width: width ?? this.width,
      maxWidth: clearMaxWidth ? null : (maxWidth ?? this.maxWidth),
      offset: offset ?? this.offset,
      borderRadius: borderRadius ?? this.borderRadius,
      iconOffset: iconOffset ?? this.iconOffset,
      alignment: alignment ?? this.alignment,
      fit: fit ?? this.fit,
      clip: clip ?? this.clip,
      respectSafeArea: respectSafeArea ?? this.respectSafeArea,
      avoidKeyboard: avoidKeyboard ?? this.avoidKeyboard,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BottomBarLayout &&
        other.width == width &&
        other.maxWidth == maxWidth &&
        other.offset == offset &&
        other.borderRadius == borderRadius &&
        other.iconOffset == iconOffset &&
        other.alignment == alignment &&
        other.fit == fit &&
        other.clip == clip &&
        other.respectSafeArea == respectSafeArea &&
        other.avoidKeyboard == avoidKeyboard;
  }

  @override
  int get hashCode => Object.hash(
    width,
    maxWidth,
    offset,
    borderRadius,
    iconOffset,
    alignment,
    fit,
    clip,
    respectSafeArea,
    avoidKeyboard,
  );
}
