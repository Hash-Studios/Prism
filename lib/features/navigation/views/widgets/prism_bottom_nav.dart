import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/animated/press_scale.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// The floating pill with the four tab destinations. A filled circle sits behind the active one. [axis] is vertical in
/// the side rail.
class PrismBottomNav extends StatefulWidget {
  const PrismBottomNav({this.axis = Axis.horizontal, super.key});

  final Axis axis;

  @override
  State<PrismBottomNav> createState() => _PrismBottomNavState();
}

class _PrismBottomNavState extends State<PrismBottomNav> {
  static const double _slot = 48;

  static const List<_NavTabConfig> _tabs = <_NavTabConfig>[
    _NavTabConfig(icon: JamIcons.home_f, value: NavTabValue.home),
    _NavTabConfig(icon: JamIcons.search, value: NavTabValue.search),
    _NavTabConfig(icon: JamIcons.gift_f, value: NavTabValue.streak),
    _NavTabConfig(icon: JamIcons.grid_f, value: NavTabValue.collection),
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
    final int activeIndex = _tabsRouter?.activeIndex ?? 0;

    final bool vertical = widget.axis == Axis.vertical;
    return Container(
      padding: const EdgeInsets.all(4),
      width: vertical ? 56 : null,
      height: vertical ? null : 56,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 4)),
        ],
        borderRadius: BorderRadius.circular(PrismRadius.pill),
      ),
      child: Flex(
        direction: widget.axis,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < _tabs.length; i++)
            _TabButton(
              config: _tabs[i],
              isActive: activeIndex == i,
              onPressed: () => _switchTab(toIndex: i),
            ),
        ],
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
    final ThemeData theme = Theme.of(context);
    final Color secondary = theme.colorScheme.secondary;
    final Duration duration = context.motion(PrismDurations.fast);
    return SizedBox(
      width: _PrismBottomNavState._slot,
      height: _PrismBottomNavState._slot,
      child: Semantics(
        button: true,
        selected: isActive,
        label: config.label(context),
        excludeSemantics: true,
        onTap: onPressed,
        child: Tooltip(
          message: config.label(context),
          excludeFromSemantics: true,
          child: PressScale(
            scale: 0.92,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPressed,
              child: AnimatedContainer(
                duration: duration,
                curve: PrismCurves.enter,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive
                      ? Color.alphaBlend(secondary.withValues(alpha: 0.15), theme.primaryColor)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: isActive ? secondary : secondary.withValues(alpha: 0.6)),
                  duration: duration,
                  curve: PrismCurves.enter,
                  builder: (BuildContext context, Color? color, Widget? _) => Icon(config.icon, size: 19, color: color),
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
  const _NavTabConfig({required this.icon, required this.value});

  /// The same glyph in both states, as on the current app. The active tab shows through the circle and the full ink.
  final IconData icon;
  final NavTabValue value;

  String label(BuildContext context) => switch (value) {
    NavTabValue.home => context.l10n.wallpaperNavHome,
    NavTabValue.search => context.l10n.wallpaperNavSearch,
    NavTabValue.streak => context.l10n.wallpaperNavRewards,
    NavTabValue.collection => context.l10n.wallpaperNavCollections,
  };
}
