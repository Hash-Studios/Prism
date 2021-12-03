import 'package:flutter/material.dart';
import 'package:prism/widgets/navigation_bar.dart';
import 'package:prism/widgets/navigation_bar_theme.dart';
import 'package:prism/widgets/scroll_navigation_bar_controller.dart';

class ScrollNavigationBar extends StatefulWidget {
  ScrollNavigationBar({
    Key? key,
    required this.controller,
    required this.destinations,
    this.onDestinationSelected,
    this.selectedIndex = 0,
    this.elevation = 8.0,
    this.backgroundColor = Colors.white,
    this.labelBehavior = NavigationDestinationLabelBehavior.alwaysShow,
  })  : assert(destinations.length >= 2),
        assert(
          destinations.every((NavigationDestination? destination) =>
              destination?.label != null),
          'Every item must have a non-null title or label',
        ),
        assert(0 <= selectedIndex && selectedIndex < destinations.length),
        assert(elevation == null || elevation >= 0.0),
        super(key: key);

  final ScrollController controller;

  final List<NavigationDestination> destinations;

  final ValueChanged<int>? onDestinationSelected;

  final int selectedIndex;
  final double? elevation;
  final Color? backgroundColor;
  final NavigationDestinationLabelBehavior? labelBehavior;

  @override
  _ScrollNavigationBarState createState() => _ScrollNavigationBarState();
}

class _ScrollNavigationBarState extends State<ScrollNavigationBar> {
  Widget? navigationBar;

  double? elevation;

  Color? backgroundColor;
  NavigationDestinationLabelBehavior? labelBehavior;

  @override
  void didUpdateWidget(covariant ScrollNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _init();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.controller.bottomNavigationBar.tabNotifier,
      builder: _tab,
    );
  }

  void _init() {
    final NavigationBarThemeData bottomTheme = NavigationBarTheme.of(context);
    elevation = widget.elevation ?? 8.0;
    backgroundColor = widget.backgroundColor ?? bottomTheme.backgroundColor;
  }

  Widget _tab(BuildContext context, int index, Widget? child) {
    navigationBar = NavigationBar(
      labelBehavior: widget.labelBehavior,
      destinations: widget.destinations,
      onDestinationSelected: (value) {
        widget.onDestinationSelected!(value);
        widget.controller.bottomNavigationBar.setTab(value);
      },
      selectedIndex: index,
      backgroundColor: Colors.transparent,
    );

    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.bottomNavigationBar.pinNotifier,
      builder: _pin,
    );
  }

  Widget _pin(BuildContext context, bool isPinned, Widget? child) {
    if (isPinned) return _align(1.0);

    return ValueListenableBuilder<double>(
      valueListenable: widget.controller.bottomNavigationBar.heightNotifier,
      builder: _height,
    );
  }

  Widget _height(BuildContext context, double height, Widget? child) {
    return _align(height);
  }

  Widget _align(double heightFactor) {
    return Align(
      heightFactor: heightFactor,
      alignment: const Alignment(0, -1),
      child: _elevation(heightFactor),
    );
  }

  Widget _elevation(double heightFactor) {
    return Material(
      elevation: elevation ?? 8.0,
      type: MaterialType.canvas,
      child: _decoratedContainer(heightFactor),
    );
  }

  Widget _decoratedContainer(double heightFactor) {
    return Container(
      height: widget.controller.bottomNavigationBar.height,
      decoration: BoxDecoration(
        color: backgroundColor,
      ),
      child: _opacity(heightFactor),
    );
  }

  Widget _opacity(double heightFactor) {
    return Opacity(
      opacity: heightFactor,
      child: navigationBar,
    );
  }
}
