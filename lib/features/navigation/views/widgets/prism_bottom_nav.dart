import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

class PrismBottomNav extends StatefulWidget {
  const PrismBottomNav({super.key});

  @override
  State<PrismBottomNav> createState() => _PrismBottomNavState();
}

class _PrismBottomNavState extends State<PrismBottomNav> {
  static const List<_NavTabConfig> _tabs = <_NavTabConfig>[
    _NavTabConfig(label: 'Home', icon: JamIcons.home_f, value: NavTabValue.home),
    _NavTabConfig(label: 'Search', icon: JamIcons.search, value: NavTabValue.search),
    _NavTabConfig(label: 'Rewards', icon: JamIcons.gift_f, value: NavTabValue.streak),
    _NavTabConfig(label: 'Collections', icon: JamIcons.grid_f, value: NavTabValue.collection),
  ];

  TabsRouter? _tabsRouter;

  void _onRouterChange() => setState(() {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = AutoTabsRouter.of(context);
    if (router != _tabsRouter) {
      _tabsRouter?.removeListener(_onRouterChange);
      _tabsRouter = router;
      _tabsRouter!.addListener(_onRouterChange);
    }
  }

  @override
  void dispose() {
    _tabsRouter?.removeListener(_onRouterChange);
    super.dispose();
  }

  void _resetActiveTab(int index) {
    PrismHaptics.selection();
    final StackRouter? stack = _tabsRouter!.stackRouterOfIndex(index);
    if (stack != null && stack.canPop()) {
      stack.popUntilRoot();
      return;
    }
    final ScrollController? controller = PrimaryScrollController.maybeOf(context);
    if (controller != null && controller.hasClients && controller.offset > 0) {
      unawaited(controller.animateTo(0, duration: context.motion(PrismDurations.base), curve: PrismCurves.enter));
    }
  }

  void _trackTabSelection({required int fromIndex, required int toIndex}) {
    analytics.track(NavTabSelectedEvent(fromTab: _tabs[fromIndex].value, toTab: _tabs[toIndex].value));
  }

  void _switchTab({required int toIndex}) {
    final fromIndex = _tabsRouter!.activeIndex;
    if (fromIndex == toIndex) {
      _resetActiveTab(toIndex);
      return;
    }
    PrismHaptics.selection();
    _trackTabSelection(fromIndex: fromIndex, toIndex: toIndex);
    _tabsRouter!.setActiveIndex(toIndex);
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _tabsRouter?.activeIndex ?? 0;

    return Container(
      padding: const EdgeInsets.all(4),
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        boxShadow: [
          BoxShadow(color: const Color(0xFF000000).withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 4)),
        ],
        borderRadius: BorderRadius.circular(500),
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _tabs.length; i++)
              _TabButton(
                tooltip: _tabs[i].label,
                isActive: activeIndex == i,
                icon: _tabs[i].icon,
                onPressed: () => _switchTab(toIndex: i),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String tooltip;
  final bool isActive;
  final IconData icon;
  final VoidCallback onPressed;

  const _TabButton({required this.tooltip, required this.isActive, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final iconColor = isActive ? cs.onPrimary : cs.secondary.withValues(alpha: 0.4);

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: isActive ? cs.primary : Colors.transparent, shape: BoxShape.circle),
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        iconSize: 19,
        onPressed: onPressed,
        icon: Icon(icon, color: iconColor, size: 19),
      ),
    );
  }
}

class _NavTabConfig {
  final String label;
  final IconData icon;
  final NavTabValue value;

  const _NavTabConfig({required this.label, required this.icon, required this.value});
}
