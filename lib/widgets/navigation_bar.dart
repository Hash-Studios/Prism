// The code below is from the master branch of Flutter framework.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:prism/widgets/navigation_bar_theme.dart' as nbt;

/// Material 3 Navigation Bar component.
///
/// Navigation bars offer a persistent and convenient way to switch between
/// primary destinations in an app.
///
/// This widget does not adjust its size with the [ThemeData.visualDensity].
///
/// The [MediaQueryData.textScaleFactor] does not adjust the size of this widget but
/// rather the size of the [Tooltip]s displayed on long presses of the
/// destinations.
///
/// The style for the icons and text are not affected by parent
/// [DefaultTextStyle]s or [IconTheme]s but rather controlled by parameters or
/// the [nbt.NavigationBarThemeData].
///
/// This widget holds a collection of destinations (usually
/// [NavigationDestination]s).
///
/// Usage:
/// ```dart
/// Scaffold(
///   bottomNavigationBar: NavigationBar(
///     onDestinationSelected: (int index) {
///       setState(() { _currentPageIndex = index; }),
///     },
///     selectedIndex: _currentPageIndex,
///     destinations: [
///       NavigationDestination(
///         icon: Icon(Icons.explore),
///         label: 'Explore',
///       ),
///       NavigationDestination(
///         icon: Icon(Icons.commute),
///         label: 'Commute',
///       ),
///       NavigationDestination(
///         selectedIcon: Icon(Icons.bookmark),
///         icon: Icon(Icons.bookmark_border),
///         label: 'Saved',
///       ),
///     ],
///   ),
/// ),
/// ```
class NavigationBar extends StatelessWidget {
  /// Creates a Material 3 Navigation Bar component.
  ///
  /// The value of [destinations] must be a list of two or more
  /// [NavigationDestination] values.
  const NavigationBar({
    Key? key,
    this.animationDuration,
    this.selectedIndex = 0,
    required this.destinations,
    this.onDestinationSelected,
    this.backgroundColor,
    this.height,
    this.labelBehavior,
  })  : assert(destinations.length >= 2),
        assert(0 <= selectedIndex && selectedIndex < destinations.length),
        super(key: key);

  /// Determines the transition time for each destination as it goes between
  /// selected and unselected.
  final Duration? animationDuration;

  /// Determines which one of the [destinations] is currently selected.
  ///
  /// When this is updated, the destination (from [destinations]) at
  /// [selectedIndex] goes from unselected to selected.
  final int selectedIndex;

  /// The list of destinations (usually [NavigationDestination]s) in this
  /// [NavigationBar].
  ///
  /// When [selectedIndex] is updated, the destination from this list at
  /// [selectedIndex] will animate from 0 (unselected) to 1.0 (selected). When
  /// the animation is increasing or completed, the destination is considered
  /// selected, when the animation is decreasing or dismissed, the destination
  /// is considered unselected.
  final List<Widget> destinations;

  /// Called when one of the [destinations] is selected.
  ///
  /// This callback usually updates the int passed to [selectedIndex].
  ///
  /// Upon updating [selectedIndex], the [NavigationBar] will be rebuilt.
  final ValueChanged<int>? onDestinationSelected;

  /// The color of the [NavigationBar] itself.
  ///
  /// If null, [nbt.NavigationBarThemeData.backgroundColor] is used. If that
  /// is also null, the default blends [ColorScheme.surface] and
  /// [ColorScheme.onSurface] using an [ElevationOverlay].
  final Color? backgroundColor;

  /// The height of the [NavigationBar] itself.
  ///
  /// If this is used in [Scaffold.bottomNavigationBar] and the scaffold is
  /// full-screen, the safe area padding is also added to the height
  /// automatically.
  ///
  /// The height does not adjust with [ThemeData.visualDensity] or
  /// [MediaQueryData.textScaleFactor] as this component loses usability at
  /// larger and smaller sizes due to the truncating of labels or smaller tap
  /// targets.
  ///
  /// If null, [nbt.NavigationBarThemeData.height] is used. If that
  /// is also null, the default is 80.
  final double? height;

  /// Defines how the [destinations]' labels will be laid out and when they'll
  /// be displayed.
  ///
  /// Can be used to show all labels, show only the selected label, or hide all
  /// labels.
  ///
  /// If null, [nbt.NavigationBarThemeData.labelBehavior] is used. If that
  /// is also null, the default is
  /// [NavigationDestinationLabelBehavior.alwaysShow].
  final NavigationDestinationLabelBehavior? labelBehavior;

  VoidCallback _handleTap(int index) {
    return onDestinationSelected != null
        ? () => onDestinationSelected!(index)
        : () {};
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final nbt.NavigationBarThemeData navigationBarTheme =
        nbt.NavigationBarTheme.of(context);
    final double effectiveHeight = height ?? navigationBarTheme.height ?? 80;
    final NavigationDestinationLabelBehavior effectiveLabelBehavior =
        labelBehavior ??
            navigationBarTheme.labelBehavior ??
            NavigationDestinationLabelBehavior.alwaysShow;
    final double additionalBottomPadding =
        MediaQuery.of(context).padding.bottom;

    return Material(
      // With Material 3, the NavigationBar uses an overlay blend for the
      // default color regardless of light/dark mode.
      color: backgroundColor ??
          navigationBarTheme.backgroundColor ??
          ElevationOverlay.colorWithOverlay(
              colorScheme.surface, colorScheme.onSurface, 3.0),
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.only(bottom: additionalBottomPadding),
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: SizedBox(
            height: effectiveHeight,
            child: Row(
              children: <Widget>[
                for (int i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _SelectableAnimatedBuilder(
                      duration: animationDuration ??
                          const Duration(milliseconds: 500),
                      isSelected: i == selectedIndex,
                      builder:
                          (BuildContext context, Animation<double> animation) {
                        return _NavigationDestinationInfo(
                          index: i,
                          totalNumberOfDestinations: destinations.length,
                          selectedAnimation: animation,
                          labelBehavior: effectiveLabelBehavior,
                          onTap: _handleTap(i),
                          child: destinations[i],
                        );
                      },
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

/// Specifies when each [NavigationDestination]'s label should appear.
///
/// This is used to determine the behavior of [NavigationBar]'s destinations.
enum NavigationDestinationLabelBehavior {
  /// Always shows all of the labels under each navigation bar destination,
  /// selected and unselected.
  alwaysShow,

  /// Never shows any of the labels under the navigation bar destinations,
  /// regardless of selected vs unselected.
  alwaysHide,

  /// Only shows the labels of the selected navigation bar destination.
  ///
  /// When a destination is unselected, the label will be faded out, and the
  /// icon will be centered.
  ///
  /// When a destination is selected, the label will fade in and the label and
  /// icon will slide up so that they are both centered.
  onlyShowSelected,
}

/// Destination Widget for displaying Icons + labels in the Material 3
/// Navigation Bars through [NavigationBar.destinations].
///
/// The destination this widget creates will look something like this:
/// =======
/// |
/// |  ☆  <-- [icon] (or [selectedIcon])
/// | text <-- [label]
/// |
/// =======
class NavigationDestination extends StatelessWidget {
  /// Creates a navigation bar destination with an icon and a label, to be used
  /// in the [NavigationBar.destinations].
  const NavigationDestination({
    Key? key,
    required this.icon,
    this.selectedIcon,
    required this.label,
    this.tooltip,
  }) : super(key: key);

  /// The [Widget] (usually an [Icon]) that's displayed for this
  /// [NavigationDestination].
  ///
  /// The icon will use [nbt.NavigationBarThemeData.iconTheme]. If this is
  /// null, the default [IconThemeData] would use a size of 24.0 and
  /// [ColorScheme.onSurface].
  final Widget icon;

  /// The optional [Widget] (usually an [Icon]) that's displayed when this
  /// [NavigationDestination] is selected.
  ///
  /// If [selectedIcon] is non-null, the destination will fade from
  /// [icon] to [selectedIcon] when this destination goes from unselected to
  /// selected.
  ///
  /// The icon will use [nbt.NavigationBarThemeData.iconTheme] with
  /// [MaterialState.selected]. If this is null, the default [IconThemeData]
  /// would use a size of 24.0 and [ColorScheme.onSurface].
  final Widget? selectedIcon;

  /// The text label that appears below the icon of this
  /// [NavigationDestination].
  ///
  /// The accompanying [Text] widget will use
  /// [nbt.NavigationBarThemeData.labelTextStyle]. If this are null, the default
  /// text style would use [TextTheme.overline] with [ColorScheme.onSurface].
  final String label;

  /// The text to display in the tooltip for this [NavigationDestination], when
  /// the user long presses the destination.
  ///
  /// If [tooltip] is an empty string, no tooltip will be used.
  ///
  /// Defaults to null, in which case the [label] text will be used.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final nbt.NavigationBarThemeData navigationBarTheme =
        nbt.NavigationBarTheme.of(context);
    final Animation<double> animation =
        _NavigationDestinationInfo.of(context).selectedAnimation;

    return _NavigationDestinationBuilder(
      label: label,
      tooltip: tooltip,
      buildIcon: (BuildContext context) {
        final IconThemeData defaultIconTheme = IconThemeData(
          size: 24,
          color: colorScheme.onSurface,
        );
        final Widget selectedIconWidget = IconTheme.merge(
          data: navigationBarTheme.iconTheme
                  ?.resolve(<MaterialState>{MaterialState.selected}) ??
              defaultIconTheme,
          child: selectedIcon ?? icon,
        );
        final Widget unselectedIconWidget = IconTheme.merge(
          data: navigationBarTheme.iconTheme?.resolve(<MaterialState>{}) ??
              defaultIconTheme,
          child: icon,
        );

        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            NavigationIndicator(
              animation: animation,
              color: navigationBarTheme.indicatorColor,
            ),
            _StatusTransitionWidgetBuilder(
              animation: animation,
              builder: (BuildContext context, Widget? child) {
                return _isForwardOrCompleted(animation)
                    ? selectedIconWidget
                    : unselectedIconWidget;
              },
            ),
          ],
        );
      },
      buildLabel: (BuildContext context) {
        final TextStyle? defaultTextStyle = theme.textTheme.overline?.copyWith(
          color: colorScheme.onSurface,
        );
        final TextStyle? effectiveSelectedLabelTextStyle = navigationBarTheme
                .labelTextStyle
                ?.resolve(<MaterialState>{MaterialState.selected}) ??
            defaultTextStyle;
        final TextStyle? effectiveUnselectedLabelTextStyle =
            navigationBarTheme.labelTextStyle?.resolve(<MaterialState>{}) ??
                defaultTextStyle;
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _ClampTextScaleFactor(
            // Don't scale labels of destinations, instead, tooltip text will
            // upscale.
            upperLimit: 1,
            child: Text(
              label,
              style: _isForwardOrCompleted(animation)
                  ? effectiveSelectedLabelTextStyle
                  : effectiveUnselectedLabelTextStyle,
            ),
          ),
        );
      },
    );
  }
}

/// Widget that handles the semantics and layout of a navigation bar
/// destination.
///
/// Prefer [NavigationDestination] over this widget, as it is a simpler
/// (although less customizable) way to get navigation bar destinations.
///
/// The icon and label of this destination are built with [buildIcon] and
/// [buildLabel]. They should build the unselected and selected icon and label
/// according to [_NavigationDestinationInfo.selectedAnimation], where an
/// animation value of 0 is unselected and 1 is selected.
///
/// See [NavigationDestination] for an example.
class _NavigationDestinationBuilder extends StatelessWidget {
  /// Builds a destination (icon + label) to use in a Material 3 [NavigationBar].
  const _NavigationDestinationBuilder({
    Key? key,
    required this.buildIcon,
    required this.buildLabel,
    required this.label,
    this.tooltip,
  }) : super(key: key);

  /// Builds the icon for an destination in a [NavigationBar].
  ///
  /// To animate between unselected and selected, build the icon based on
  /// [_NavigationDestinationInfo.selectedAnimation]. When the animation is 0,
  /// the destination is unselected, when the animation is 1, the destination is
  /// selected.
  ///
  /// The destination is considered selected as soon as the animation is
  /// increasing or completed, and it is considered unselected as soon as the
  /// animation is decreasing or dismissed.
  final WidgetBuilder buildIcon;

  /// Builds the label for an destination in a [NavigationBar].
  ///
  /// To animate between unselected and selected, build the icon based on
  /// [_NavigationDestinationInfo.selectedAnimation].  When the animation is
  /// 0, the destination is unselected, when the animation is 1, the destination
  /// is selected.
  ///
  /// The destination is considered selected as soon as the animation is
  /// increasing or completed, and it is considered unselected as soon as the
  /// animation is decreasing or dismissed.
  final WidgetBuilder buildLabel;

  /// The text value of what is in the label widget, this is required for
  /// semantics so that screen readers and tooltips can read the proper label.
  final String label;

  /// The text to display in the tooltip for this [NavigationDestination], when
  /// the user long presses the destination.
  ///
  /// If [tooltip] is an empty string, no tooltip will be used.
  ///
  /// Defaults to null, in which case the [label] text will be used.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final _NavigationDestinationInfo info =
        _NavigationDestinationInfo.of(context);
    return _NavigationBarDestinationSemantics(
      child: _NavigationBarDestinationTooltip(
        message: tooltip ?? label,
        child: InkWell(
          highlightColor: Colors.transparent,
          onTap: info.onTap,
          child: Row(
            children: <Widget>[
              Expanded(
                child: _NavigationBarDestinationLayout(
                  icon: buildIcon(context),
                  label: buildLabel(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inherited widget for passing data from the [NavigationBar] to the
/// [NavigationBar.destinations] children widgets.
///
/// Useful for building navigation destinations using:
/// `_NavigationDestinationInfo.of(context)`.
class _NavigationDestinationInfo extends InheritedWidget {
  /// Adds the information needed to build a navigation destination to the
  /// [child] and descendants.
  const _NavigationDestinationInfo({
    Key? key,
    required this.index,
    required this.totalNumberOfDestinations,
    required this.selectedAnimation,
    required this.labelBehavior,
    required this.onTap,
    required Widget child,
  }) : super(key: key, child: child);

  /// Which destination index is this in the navigation bar.
  ///
  /// For example:
  /// ```dart
  /// NavigationBar(
  ///   destinations: [
  ///     NavigationDestination(), // This is destination index 0.
  ///     NavigationDestination(), // This is destination index 1.
  ///     NavigationDestination(), // This is destination index 2.
  ///   ]
  /// )
  /// ```
  ///
  /// This is required for semantics, so that each destination can have a label
  /// "Tab 1 of 3", for example.
  final int index;

  /// How many total destinations are are in this navigation bar.
  ///
  /// This is required for semantics, so that each destination can have a label
  /// "Tab 1 of 4", for example.
  final int totalNumberOfDestinations;

  /// Indicates whether or not this destination is selected, from 0 (unselected)
  /// to 1 (selected).
  final Animation<double> selectedAnimation;

  /// Determines the behavior for how the labels will layout.
  ///
  /// Can be used to show all labels (the default), show only the selected
  /// label, or hide all labels.
  final NavigationDestinationLabelBehavior labelBehavior;

  /// The callback that should be called when this destination is tapped.
  ///
  /// This is computed by calling [NavigationBar.onDestinationSelected]
  /// with [index] passed in.
  final VoidCallback onTap;

  /// Returns a non null [_NavigationDestinationInfo].
  ///
  /// This will return an error if called with no [_NavigationDestinationInfo]
  /// ancestor.
  ///
  /// Used by widgets that are implementing a navigation destination info to
  /// get information like the selected animation and destination number.
  static _NavigationDestinationInfo of(BuildContext context) {
    final _NavigationDestinationInfo? result = context
        .dependOnInheritedWidgetOfExactType<_NavigationDestinationInfo>();
    assert(
      result != null,
      'Navigation destinations need a _NavigationDestinationInfo parent, '
      'which is usually provided by NavigationBar.',
    );
    return result!;
  }

  @override
  bool updateShouldNotify(_NavigationDestinationInfo oldWidget) {
    return index != oldWidget.index ||
        totalNumberOfDestinations != oldWidget.totalNumberOfDestinations ||
        selectedAnimation != oldWidget.selectedAnimation ||
        labelBehavior != oldWidget.labelBehavior ||
        onTap != oldWidget.onTap;
  }
}

/// Selection Indicator for the Material 3 [NavigationBar] and [NavigationRail]
/// components.
///
/// When [animation] is 0, the indicator is not present. As [animation] grows
/// from 0 to 1, the indicator scales in on the x axis.
///
/// Used in a [Stack] widget behind the icons in the Material 3 Navigation Bar
/// to illuminate the selected destination.
class NavigationIndicator extends StatelessWidget {
  /// Builds an indicator, usually used in a stack behind the icon of a
  /// navigation bar destination.
  const NavigationIndicator({
    Key? key,
    required this.animation,
    this.color,
    this.width = 64,
    this.height = 32,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  }) : super(key: key);

  /// Determines the scale of the indicator.
  ///
  /// When [animation] is 0, the indicator is not present. The indicator scales
  /// in as [animation] grows from 0 to 1.
  final Animation<double> animation;

  /// The fill color of this indicator.
  ///
  /// If null, defaults to [ColorScheme.secondary].
  final Color? color;

  /// The width of the container that holds in the indicator.
  ///
  /// Defaults to `64`.
  final double width;

  /// The height of the container that holds in the indicator.
  ///
  /// Defaults to `32`.
  final double height;

  /// The radius of the container that holds in the indicator.
  ///
  /// Defaults to `BorderRadius.circular(16)`.
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        // The scale should be 0 when the animation is unselected, as soon as
        // the animation starts, the scale jumps to 40%, and then animates to
        // 100% along a curve.
        final double scale = animation.isDismissed
            ? 0.0
            : Tween<double>(begin: .4, end: 1.0).transform(
                CurveTween(curve: Curves.easeInOutCubicEmphasized)
                    .transform(animation.value));

        return Transform(
          alignment: Alignment.center,
          // Scale in the X direction only.
          transform: Matrix4.diagonal3Values(
            scale,
            1.0,
            1.0,
          ),
          child: child,
        );
      },
      // Fade should be a 100ms animation whenever the parent animation changes
      // direction.
      child: _StatusTransitionWidgetBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? child) {
          return _SelectableAnimatedBuilder(
            isSelected: _isForwardOrCompleted(animation),
            duration: const Duration(milliseconds: 100),
            alwaysDoFullAnimation: true,
            builder: (BuildContext context, Animation<double> fadeAnimation) {
              return FadeTransition(
                opacity: fadeAnimation,
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    color: color ?? colorScheme.secondary.withOpacity(.24),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Widget that handles the layout of the icon + label in a navigation bar
/// destination, based on [_NavigationDestinationInfo.labelBehavior] and
/// [_NavigationDestinationInfo.selectedAnimation].
///
/// Depending on the [_NavigationDestinationInfo.labelBehavior], the labels
/// will shift and fade accordingly.
class _NavigationBarDestinationLayout extends StatelessWidget {
  /// Builds a widget to layout an icon + label for a destination in a Material
  /// 3 [NavigationBar].
  const _NavigationBarDestinationLayout({
    Key? key,
    required this.icon,
    required this.label,
  }) : super(key: key);

  /// The icon widget that sits on top of the label.
  ///
  /// See [NavigationDestination.icon].
  final Widget icon;

  /// The label widget that sits below the icon.
  ///
  /// This widget will sometimes be faded out, depending on
  /// [_NavigationDestinationInfo.selectedAnimation].
  ///
  /// See [NavigationDestination.label].
  final Widget label;

  static final Key _iconKey = UniqueKey();
  static final Key _labelKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return _DestinationLayoutAnimationBuilder(
      builder: (BuildContext context, Animation<double> animation) {
        return CustomMultiChildLayout(
          delegate: _NavigationDestinationLayoutDelegate(
            animation: animation,
          ),
          children: <Widget>[
            LayoutId(
              id: _NavigationDestinationLayoutDelegate.iconId,
              child: RepaintBoundary(
                key: _iconKey,
                child: icon,
              ),
            ),
            LayoutId(
              id: _NavigationDestinationLayoutDelegate.labelId,
              child: FadeTransition(
                alwaysIncludeSemantics: true,
                opacity: animation,
                child: RepaintBoundary(
                  key: _labelKey,
                  child: label,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Determines the appropriate [Curve] and [Animation] to use for laying out the
/// [NavigationDestination], based on
/// [_NavigationDestinationInfo.labelBehavior].
///
/// The animation controlling the position and fade of the labels differs
/// from the selection animation, depending on the
/// [NavigationDestinationLabelBehavior]. This widget determines what
/// animation should be used for the position and fade of the labels.
class _DestinationLayoutAnimationBuilder extends StatelessWidget {
  /// Builds a child with the appropriate animation [Curve] based on the
  /// [_NavigationDestinationInfo.labelBehavior].
  const _DestinationLayoutAnimationBuilder({Key? key, required this.builder})
      : super(key: key);

  /// Builds the child of this widget.
  ///
  /// The [Animation] will be the appropriate [Animation] to use for the layout
  /// and fade of the [NavigationDestination], either a curve, always
  /// showing (1), or always hiding (0).
  final Widget Function(BuildContext, Animation<double>) builder;

  @override
  Widget build(BuildContext context) {
    final _NavigationDestinationInfo info =
        _NavigationDestinationInfo.of(context);
    switch (info.labelBehavior) {
      case NavigationDestinationLabelBehavior.alwaysShow:
        return builder(context, kAlwaysCompleteAnimation);
      case NavigationDestinationLabelBehavior.alwaysHide:
        return builder(context, kAlwaysDismissedAnimation);
      case NavigationDestinationLabelBehavior.onlyShowSelected:
        return _CurvedAnimationBuilder(
          animation: info.selectedAnimation,
          curve: Curves.easeInOutCubicEmphasized,
          reverseCurve: Curves.easeInOutCubicEmphasized.flipped,
          builder: (BuildContext context, Animation<double> curvedAnimation) {
            return builder(context, curvedAnimation);
          },
        );
    }
  }
}

/// Semantics widget for a navigation bar destination.
///
/// Requires a [_NavigationDestinationInfo] parent (normally provided by the
/// [NavigationBar] by default).
///
/// Provides localized semantic labels to the destination, for example, it will
/// read "Home, Tab 1 of 3".
///
/// Used by [_NavigationDestinationBuilder].
class _NavigationBarDestinationSemantics extends StatelessWidget {
  /// Adds the appropriate semantics for navigation bar destinations to the
  /// [child].
  const _NavigationBarDestinationSemantics({
    Key? key,
    required this.child,
  }) : super(key: key);

  /// The widget that should receive the destination semantics.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations localizations =
        MaterialLocalizations.of(context);
    final _NavigationDestinationInfo destinationInfo =
        _NavigationDestinationInfo.of(context);
    // The AnimationStatusBuilder will make sure that the semantics update to
    // "selected" when the animation status changes.
    return _StatusTransitionWidgetBuilder(
      animation: destinationInfo.selectedAnimation,
      builder: (BuildContext context, Widget? child) {
        return Semantics(
          selected: _isForwardOrCompleted(destinationInfo.selectedAnimation),
          container: true,
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          child,
          Semantics(
            label: localizations.tabLabel(
              tabIndex: destinationInfo.index + 1,
              tabCount: destinationInfo.totalNumberOfDestinations,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tooltip widget for use in a [NavigationBar].
///
/// It appears just above the navigation bar when one of the destinations is
/// long pressed.
class _NavigationBarDestinationTooltip extends StatelessWidget {
  /// Adds a tooltip to the [child] widget.
  const _NavigationBarDestinationTooltip({
    Key? key,
    required this.message,
    required this.child,
  }) : super(key: key);

  /// The text that is rendered in the tooltip when it appears.
  final String message;

  /// The widget that, when pressed, will show a tooltip.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // if (message == null) {
    //   return child;
    // }
    return Tooltip(
      message: message,
      // TODO(johnsonmh): Make this value configurable/themable.
      verticalOffset: 42,
      excludeFromSemantics: true,
      preferBelow: false,
      child: child,
    );
  }
}

/// Custom layout delegate for shifting navigation bar destinations.
///
/// This will lay out the icon + label according to the [animation].
///
/// When the [animation] is 0, the icon will be centered, and the label will be
/// positioned directly below it.
///
/// When the [animation] is 1, the label will still be positioned directly below
/// the icon, but the icon + label combination will be centered.
///
/// Used in a [CustomMultiChildLayout] widget in the
/// [_NavigationDestinationBuilder].
class _NavigationDestinationLayoutDelegate extends MultiChildLayoutDelegate {
  _NavigationDestinationLayoutDelegate({required this.animation})
      : super(relayout: animation);

  /// The selection animation that indicates whether or not this destination is
  /// selected.
  ///
  /// See [_NavigationDestinationInfo.selectedAnimation].
  final Animation<double> animation;

  /// ID for the icon widget child.
  ///
  /// This is used by the [LayoutId] when this delegate is used in a
  /// [CustomMultiChildLayout].
  ///
  /// See [_NavigationDestinationBuilder].
  static const int iconId = 1;

  /// ID for the label widget child.
  ///
  /// This is used by the [LayoutId] when this delegate is used in a
  /// [CustomMultiChildLayout].
  ///
  /// See [_NavigationDestinationBuilder].
  static const int labelId = 2;

  @override
  void performLayout(Size size) {
    double halfWidth(Size size) => size.width / 2;
    double halfHeight(Size size) => size.height / 2;

    final Size iconSize = layoutChild(iconId, BoxConstraints.loose(size));
    final Size labelSize = layoutChild(labelId, BoxConstraints.loose(size));

    final double yPositionOffset = Tween<double>(
      // When unselected, the icon is centered vertically.
      begin: halfHeight(iconSize),
      // When selected, the icon and label are centered vertically.
      end: halfHeight(iconSize) + halfHeight(labelSize),
    ).transform(animation.value);
    final double iconYPosition = halfHeight(size) - yPositionOffset;

    // Position the icon.
    positionChild(
      iconId,
      Offset(
        // Center the icon horizontally.
        halfWidth(size) - halfWidth(iconSize),
        iconYPosition,
      ),
    );

    // Position the label.
    positionChild(
      labelId,
      Offset(
        // Center the label horizontally.
        halfWidth(size) - halfWidth(labelSize),
        // Label always appears directly below the icon.
        iconYPosition + iconSize.height,
      ),
    );
  }

  @override
  bool shouldRelayout(_NavigationDestinationLayoutDelegate oldDelegate) {
    return oldDelegate.animation != animation;
  }
}

/// Utility Widgets
/// Clamps [MediaQueryData.textScaleFactor] so that if it is greater than
/// [upperLimit] or less than [lowerLimit], [upperLimit] or [lowerLimit] will be
/// used instead for the [child] widget.
///
/// Example:
/// ```
/// _ClampTextScaleFactor(
///   upperLimit: 2.0,
///   child: Text('Foo'), // If textScaleFactor is 3.0, this will only scale 2x.
/// )
/// ```
class _ClampTextScaleFactor extends StatelessWidget {
  /// Clamps the text scale factor of descendants by modifying the [MediaQuery]
  /// surrounding [child].
  const _ClampTextScaleFactor({
    Key? key,
    this.lowerLimit = 0,
    this.upperLimit = double.infinity,
    required this.child,
  }) : super(key: key);

  /// The minimum amount that the text scale factor should be for the [child]
  /// widget.
  ///
  /// If this is `.5`, the textScaleFactor for child widgets will never be
  /// smaller than `.5`.
  final double lowerLimit;

  /// The maximum amount that the text scale factor should be for the [child]
  /// widget.
  ///
  /// If this is `1.5`, the textScaleFactor for child widgets will never be
  /// greater than `1.5`.
  final double upperLimit;

  /// The [Widget] that should have its (and its descendants) text scale factor
  /// clamped.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaleFactor: MediaQuery.of(context).textScaleFactor.clamp(
              lowerLimit,
              upperLimit,
            ),
      ),
      child: child,
    );
  }
}

/// Widget that listens to an animation, and rebuilds when the animation changes
/// [AnimationStatus].
///
/// This can be more efficient than just using an [AnimatedBuilder] when you
/// only need to rebuild when the [Animation.status] changes, since
/// [AnimatedBuilder] rebuilds every time the animation ticks.
class _StatusTransitionWidgetBuilder extends StatusTransitionWidget {
  /// Creates a widget that rebuilds when the given animation changes status.
  const _StatusTransitionWidgetBuilder({
    Key? key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(animation: animation, key: key);

  /// Called every time the [animation] changes [AnimationStatus].
  final TransitionBuilder builder;

  /// The child widget to pass to the [builder].
  ///
  /// If a [builder] callback's return value contains a subtree that does not
  /// depend on the animation, it's more efficient to build that subtree once
  /// instead of rebuilding it on every animation status change.
  ///
  /// Using this pre-built child is entirely optional, but can improve
  /// performance in some cases and is therefore a good practice.
  ///
  /// See: [AnimatedBuilder.child]
  final Widget? child;

  @override
  Widget build(BuildContext context) => builder(context, child);
}

/// Builder widget for widgets that need to be animated from 0 (unselected) to
/// 1.0 (selected).
///
/// This widget creates and manages an [AnimationController] that it passes down
/// to the child through the [builder] function.
///
/// When [isSelected] is `true`, the animation controller will animate from
/// 0 to 1 (for [duration] time).
///
/// When [isSelected] is `false`, the animation controller will animate from
/// 1 to 0 (for [duration] time).
///
/// If [isSelected] is updated while the widget is animating, the animation will
/// be reversed until it is either 0 or 1 again. If [alwaysDoFullAnimation] is
/// true, the animation will reset to 0 or 1 before beginning the animation, so
/// that the full animation is done.
///
/// Usage:
/// ```dart
/// _SelectableAnimatedBuilder(
///   isSelected: _isDrawerOpen,
///   builder: (context, animation) {
///     return AnimatedIcon(
///       icon: AnimatedIcons.menu_arrow,
///       progress: animation,
///       semanticLabel: 'Show menu',
///     );
///   }
/// )
/// ```
class _SelectableAnimatedBuilder extends StatefulWidget {
  /// Builds and maintains an [AnimationController] that will animate from 0 to
  /// 1 and back depending on when [isSelected] is true.
  const _SelectableAnimatedBuilder({
    Key? key,
    required this.isSelected,
    this.duration = const Duration(milliseconds: 200),
    this.alwaysDoFullAnimation = false,
    required this.builder,
  }) : super(key: key);

  /// When true, the widget will animate an animation controller from 0 to 1.
  ///
  /// The animation controller is passed to the child widget through [builder].
  final bool isSelected;

  /// How long the animation controller should animate for when [isSelected] is
  /// updated.
  ///
  /// If the animation is currently running and [isSelected] is updated, only
  /// the [duration] left to finish the animation will be run.
  final Duration duration;

  /// If true, the animation will always go all the way from 0 to 1 when
  /// [isSelected] is true, and from 1 to 0 when [isSelected] is false, even
  /// when the status changes mid animation.
  ///
  /// If this is false and the status changes mid animation, the animation will
  /// reverse direction from it's current point.
  ///
  /// Defaults to false.
  final bool alwaysDoFullAnimation;

  /// Builds the child widget based on the current animation status.
  ///
  /// When [isSelected] is updated to true, this builder will be called and the
  /// animation will animate up to 1. When [isSelected] is updated to
  /// `false`, this will be called and the animation will animate down to 0.
  final Widget Function(BuildContext, Animation<double>) builder;

  @override
  _SelectableAnimatedBuilderState createState() =>
      _SelectableAnimatedBuilderState();
}

/// State that manages the [AnimationController] that is passed to
/// [_SelectableAnimatedBuilder.builder].
class _SelectableAnimatedBuilderState extends State<_SelectableAnimatedBuilder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.duration = widget.duration;
    _controller.value = widget.isSelected ? 1.0 : 0.0;
  }

  @override
  void didUpdateWidget(_SelectableAnimatedBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.isSelected != widget.isSelected) {
      if (widget.isSelected) {
        _controller.forward(from: widget.alwaysDoFullAnimation ? 0 : null);
      } else {
        _controller.reverse(from: widget.alwaysDoFullAnimation ? 1 : null);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      _controller,
    );
  }
}

/// Watches [animation] and calls [builder] with the appropriate [Curve]
/// depending on the direction of the [animation] status.
///
/// If [animation.status] is forward or complete, [curve] is used. If
/// [animation.status] is reverse or dismissed, [reverseCurve] is used.
///
/// If the [animation] changes direction while it is already running, the curve
/// used will not change, this will keep the animations smooth until it
/// completes.
///
/// This is similar to [CurvedAnimation] except the animation status listeners
/// are removed when this widget is disposed.
class _CurvedAnimationBuilder extends StatefulWidget {
  const _CurvedAnimationBuilder({
    Key? key,
    required this.animation,
    required this.curve,
    required this.reverseCurve,
    required this.builder,
  }) : super(key: key);

  final Animation<double> animation;
  final Curve curve;
  final Curve reverseCurve;
  final Widget Function(BuildContext, Animation<double>) builder;

  @override
  _CurvedAnimationBuilderState createState() => _CurvedAnimationBuilderState();
}

class _CurvedAnimationBuilderState extends State<_CurvedAnimationBuilder> {
  late AnimationStatus _animationDirection;
  AnimationStatus? _preservedDirection;

  @override
  void initState() {
    super.initState();
    _animationDirection = widget.animation.status;
    _updateStatus(widget.animation.status);
    widget.animation.addStatusListener(_updateStatus);
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_updateStatus);
    super.dispose();
  }

  // Keeps track of the current animation status, as well as the "preserved
  // direction" when the animation changes direction mid animation.
  //
  // The preserved direction is reset when the animation finishes in either
  // direction.
  void _updateStatus(AnimationStatus status) {
    if (_animationDirection != status) {
      setState(() {
        _animationDirection = status;
      });
    }

    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      setState(() {
        _preservedDirection = null;
      });
    }

    if (_preservedDirection == null &&
        (status == AnimationStatus.forward ||
            status == AnimationStatus.reverse)) {
      setState(() {
        _preservedDirection = status;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool shouldUseForwardCurve =
        (_preservedDirection ?? _animationDirection) != AnimationStatus.reverse;

    final Animation<double> curvedAnimation = CurveTween(
      curve: shouldUseForwardCurve ? widget.curve : widget.reverseCurve,
    ).animate(widget.animation);

    return widget.builder(context, curvedAnimation);
  }
}

/// Returns `true` if this animation is ticking forward, or has completed,
/// based on [status].
bool _isForwardOrCompleted(Animation<double> animation) {
  return animation.status == AnimationStatus.forward ||
      animation.status == AnimationStatus.completed;
}
