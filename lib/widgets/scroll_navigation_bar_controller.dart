// The code below is from the master branch of scroll_bottom_navigation_bar package from pub.dev.

import 'package:flutter/material.dart';
import 'package:scroll_bars_common/scroll_bars_common.dart';

extension ScrollBottomNavigationBarControllerExt on ScrollController {
  static final _controllers = <int, _ScrollBottomNavigationBarController>{};

  _ScrollBottomNavigationBarController get bottomNavigationBar {
    if (_controllers.containsKey(hashCode)) {
      return _controllers[hashCode]!;
    }

    return _controllers[hashCode] = _ScrollBottomNavigationBarController(this);
  }
}

class _ScrollBottomNavigationBarController extends ScrollBarsController {
  _ScrollBottomNavigationBarController(ScrollController scrollController)
      : super(scrollController);

  @override
  double height = 80;

  /// Notifier of the active page index
  final tabNotifier = ValueNotifier<int>(0);

  /// Register a closure to be called when the tab changes
  void tabListener(Function(int) listener) {
    tabNotifier.addListener(() => listener(tabNotifier.value));
  }

  /// Set a new tab
  void setTab(int index) => tabNotifier.value = index;

  @override
  void dispose() {
    tabNotifier.dispose();
    super.dispose();
  }
}
