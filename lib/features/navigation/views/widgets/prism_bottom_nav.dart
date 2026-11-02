import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/layout_prefs/domain/entities/layout_prefs.dart';
import 'package:Prism/features/layout_prefs/views/layout_prefs_scope.dart';
import 'package:Prism/features/layout_prefs/views/nav_tab_view.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// The floating pill with the visible tab destinations, in the user's order, and a More entry for hidden tabs. A filled circle sits behind the active one. [axis] is vertical in
/// the side rail.
class PrismBottomNav extends StatefulWidget {
  const PrismBottomNav({this.axis = Axis.horizontal, super.key});

  final Axis axis;

  @override
  State<PrismBottomNav> createState() => _PrismBottomNavState();
}

class _PrismBottomNavState extends State<PrismBottomNav> {
  static const double _slot = 48;

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

  /// The dashboard keeps one route per [NavTab] in enum order, so a tab's index is its router index.
  void _switchTab(NavTab to) {
    final int fromIndex = _tabsRouter!.activeIndex;
    if (fromIndex == to.index) {
      _resetActiveTab(to.index);
      return;
    }
    PrismHaptics.selection();
    analytics.track(NavTabSelectedEvent(fromTab: NavTab.values[fromIndex].analyticsValue, toTab: to.analyticsValue));
    _tabsRouter!.setActiveIndex(to.index);
  }

  Future<void> _openMore(List<NavTab> hidden) async {
    PrismHaptics.selection();
    final NavTab? picked = await showPrismSheet<NavTab>(
      context,
      detents: const <PrismSheetDetent>[PrismSheetDetent.fit],
      builder: (sheetContext) => PrismSheetBody(
        title: sheetContext.l10n.navMore,
        child: PrismGroup(
          children: <Widget>[
            for (final NavTab tab in hidden)
              PrismRow(
                icon: tab.icon,
                title: tab.label(sheetContext),
                onTap: () => Navigator.of(sheetContext).pop(tab),
              ),
            PrismRow(
              icon: Icons.tune_rounded,
              title: sheetContext.l10n.navMoreEditTabs,
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.router.push(const LayoutSettingsRoute());
              },
            ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) _switchTab(picked);
  }

  @override
  Widget build(BuildContext context) {
    final NavTab active = NavTab.values[_tabsRouter?.activeIndex ?? 0];
    final LayoutPrefs prefs = LayoutPrefsScope.of(context, LayoutAspect.tabs);
    final List<NavTab> hidden = prefs.hiddenInOrder;

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
          for (final NavTab tab in prefs.visibleTabs)
            _TabButton(
              icon: tab.icon,
              label: tab.label(context),
              isActive: active == tab,
              onPressed: () => _switchTab(tab),
            ),
          if (hidden.isNotEmpty)
            _TabButton(
              icon: JamIcons.more_horizontal_f,
              label: context.l10n.navMore,
              isActive: hidden.contains(active),
              onPressed: () => _openMore(hidden),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.icon, required this.label, required this.isActive, required this.onPressed});

  final IconData icon;
  final String label;
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
        label: label,
        excludeSemantics: true,
        onTap: onPressed,
        child: Tooltip(
          message: label,
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
                  builder: (BuildContext context, Color? color, Widget? _) => Icon(icon, size: 19, color: color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
