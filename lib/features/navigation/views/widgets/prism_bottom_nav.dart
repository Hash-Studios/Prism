import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/logger/logger.dart';
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
    _NavTabConfig(index: 0, label: 'Home', icon: JamIcons.home_f, value: NavTabValue.home),
    _NavTabConfig(index: 1, label: 'Search', icon: JamIcons.search, value: NavTabValue.search),
    _NavTabConfig(index: 2, label: 'Streak', icon: JamIcons.flame_f, value: NavTabValue.streak),
    _NavTabConfig(index: 3, label: 'Collections', icon: JamIcons.grid_f, value: NavTabValue.collection),
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

  void _trackTabSelection({required int fromIndex, required int toIndex}) {
    analytics.track(NavTabSelectedEvent(fromTab: _tabs[fromIndex].value, toTab: _tabs[toIndex].value));
  }

  void _switchTab({required int toIndex}) {
    final fromIndex = _tabsRouter!.activeIndex;
    if (fromIndex == toIndex) {
      logger.d('Currently on ${_tabs[toIndex].label}');
      return;
    }
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
            for (final tab in _tabs)
              _TabButton(
                tooltip: tab.label,
                isActive: activeIndex == tab.index,
                icon: tab.icon,
                onPressed: () => _switchTab(toIndex: tab.index),
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
    final iconColor = isActive
        ? Theme.of(context).colorScheme.secondary
        : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4);

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: isActive ? const Color(0xFF252525) : Colors.transparent, shape: BoxShape.circle),
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
  final int index;
  final String label;
  final IconData icon;
  final NavTabValue value;

  const _NavTabConfig({required this.index, required this.label, required this.icon, required this.value});
}
