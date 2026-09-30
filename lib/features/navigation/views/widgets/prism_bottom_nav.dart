import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/features/navigation/views/widgets/nav_bar_surface.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The floating pill with the four tab destinations. A circle slides behind the active one.
class PrismBottomNav extends StatefulWidget {
  const PrismBottomNav({super.key});

  @override
  State<PrismBottomNav> createState() => _PrismBottomNavState();
}

class _PrismBottomNavState extends State<PrismBottomNav> {
  static const double _slot = 48;
  static const double _indicator = 44;
  static const double _height = 60;

  static const List<_NavTabConfig> _tabs = <_NavTabConfig>[
    _NavTabConfig(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home_rounded, value: NavTabValue.home),
    _NavTabConfig(
      label: 'Search',
      icon: Icons.search_rounded,
      activeIcon: Icons.search_rounded,
      value: NavTabValue.search,
    ),
    _NavTabConfig(
      label: 'Rewards',
      icon: Icons.card_giftcard_outlined,
      activeIcon: Icons.card_giftcard_rounded,
      value: NavTabValue.streak,
    ),
    _NavTabConfig(
      label: 'Collections',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      value: NavTabValue.collection,
    ),
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
      return;
    }
    HapticFeedback.selectionClick();
    _trackTabSelection(fromIndex: fromIndex, toIndex: toIndex);
    _tabsRouter!.setActiveIndex(toIndex);
  }

  @override
  Widget build(BuildContext context) {
    final int activeIndex = _tabsRouter?.activeIndex ?? 0;
    final Color indicator = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1);
    final double x = -1 + 2 * activeIndex / (_tabs.length - 1);

    return DecoratedBox(
      decoration: navBarDecoration(context),
      child: SizedBox(
        height: _height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: (_height - _slot) / 2),
          child: SizedBox(
            width: _slot * 4,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                AnimatedAlign(
                  alignment: Alignment(x, 0),
                  duration: context.motion(PrismDurations.base),
                  curve: PrismCurves.move,
                  child: SizedBox.square(
                    dimension: _slot,
                    child: Center(
                      child: Container(
                        width: _indicator,
                        height: _indicator,
                        decoration: BoxDecoration(color: indicator, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    for (var i = 0; i < _tabs.length; i++)
                      _TabButton(
                        config: _tabs[i],
                        isActive: activeIndex == i,
                        onPressed: () => _switchTab(toIndex: i),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.config, required this.isActive, required this.onPressed});

  final _NavTabConfig config;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color ink = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: _PrismBottomNavState._slot,
      height: _PrismBottomNavState._slot,
      child: Semantics(
        button: true,
        selected: isActive,
        label: config.label,
        excludeSemantics: true,
        onTap: onPressed,
        child: Tooltip(
          message: config.label,
          excludeFromSemantics: true,
          child: PressScale(
            scale: 0.92,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPressed,
              child: Center(
                child: AnimatedSwitcher(
                  duration: context.motion(PrismDurations.fast),
                  switchInCurve: PrismCurves.enter,
                  switchOutCurve: PrismCurves.enter,
                  child: Icon(
                    isActive ? config.activeIcon : config.icon,
                    key: ValueKey<bool>(isActive),
                    size: 22,
                    color: isActive ? ink : ink.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTabConfig {
  const _NavTabConfig({required this.label, required this.icon, required this.activeIcon, required this.value});

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final NavTabValue value;
}
