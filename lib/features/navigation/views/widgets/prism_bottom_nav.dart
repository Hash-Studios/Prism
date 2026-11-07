import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/layout_prefs/domain/entities/layout_prefs.dart';
import 'package:Prism/features/layout_prefs/views/layout_prefs_scope.dart';
import 'package:Prism/features/layout_prefs/views/nav_tab_view.dart';
import 'package:Prism/features/navigation/views/widgets/nav_glass.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// The floating glass pill with the visible tab destinations, in the user's order, and a More entry for hidden tabs. Each
/// tab shows its icon over a short label, and a tinted pill sits behind the active one. [axis] is vertical in the side rail.
/// The rail, and a row without [labels], shows icons only, with a filled circle behind the active one.
class PrismBottomNav extends StatefulWidget {
  const PrismBottomNav({this.axis = Axis.horizontal, this.labels = true, super.key});

  final Axis axis;

  /// Shows a label under each icon. The bottom row turns it off where the wider pill does not fit. The rail is always
  /// icons only.
  final bool labels;

  /// The pill length with every tab in it, the most it can hold.
  static double maxLength({required bool labels}) =>
      NavTab.values.length * (labels ? _PrismBottomNavState._slotWidth : _PrismBottomNavState._slot) + 8;

  @override
  State<PrismBottomNav> createState() => _PrismBottomNavState();
}

class _PrismBottomNavState extends State<PrismBottomNav> {
  static const double _slot = 48;

  /// A horizontal slot is wider than it is high, so the label under the icon fits.
  static const double _slotWidth = 64;

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
    final bool iconOnly = vertical || !widget.labels;
    return NavGlass(
      child: Container(
        padding: const EdgeInsets.all(4),
        width: vertical ? 56 : null,
        height: vertical ? null : 56,
        child: Flex(
          direction: widget.axis,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final NavTab tab in prefs.visibleTabs)
              _TabButton(
                icon: tab.icon,
                label: tab.label(context),
                isActive: active == tab,
                iconOnly: iconOnly,
                onPressed: () => _switchTab(tab),
              ),
            if (hidden.isNotEmpty)
              _TabButton(
                icon: JamIcons.more_horizontal_f,
                label: context.l10n.navMore,
                isActive: hidden.contains(active),
                iconOnly: iconOnly,
                onPressed: () => _openMore(hidden),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.iconOnly,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final bool iconOnly;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color secondary = theme.colorScheme.secondary;
    final Duration duration = context.motion(PrismDurations.fast);
    return SizedBox(
      width: iconOnly ? _PrismBottomNavState._slot : _PrismBottomNavState._slotWidth,
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPressed,
              child: AnimatedContainer(
                duration: duration,
                curve: PrismCurves.enter,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // Translucent, so the active pill tints with the glass behind it.
                  color: isActive ? secondary.withValues(alpha: 0.12) : Colors.transparent,
                  shape: iconOnly ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: iconOnly ? null : BorderRadius.circular(PrismRadius.pill),
                ),
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: isActive ? secondary : secondary.withValues(alpha: 0.6)),
                  duration: duration,
                  curve: PrismCurves.enter,
                  builder: (BuildContext context, Color? color, Widget? _) {
                    if (iconOnly) return Icon(icon, size: 19, color: color);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(icon, size: 20, color: color),
                        const SizedBox(height: 2),
                        MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: PrismTextStyles.caption(
                                context,
                              ).copyWith(fontSize: 10.5, fontWeight: FontWeight.w600, height: 1.2, color: color),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
