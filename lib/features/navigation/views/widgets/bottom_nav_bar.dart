import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/utils/side_safe_column.dart';
import 'package:Prism/features/layout_prefs/views/layout_prefs_scope.dart';
import 'package:Prism/features/navigation/views/widgets/account_controls.dart';
import 'package:Prism/features/navigation/views/widgets/prism_bottom_nav.dart';
import 'package:Prism/features/navigation/views/widgets/prism_fab.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart' as floating;

const double _createGap = 12;
const double _createSize = 56;
const double _controlSize = 44;

/// The space above and below the row inside the band.
const double _bandPadding = PrismSpace.xs;

/// The space the row leaves on each side of the screen.
const double _barInset = 10;

/// The band above the bottom safe area, plus a gap, so a tab snackbar sits clear of the band.
const double _snackBarBottomInset = _bandPadding + 56 + _bandPadding + PrismSpace.xs;

const double _compactRow = _controlSize + PrismSpace.xxs + _createGap + _createSize;

double _oneHandedRowSpace(BuildContext context) =>
    MediaQuery.sizeOf(context).width - MediaQuery.paddingOf(context).horizontal - 2 * _barInset;

/// The one-handed row keeps tab labels only where they fit next to both the avatar and the bell.
bool _oneHandedLabelsFit(BuildContext context) =>
    _oneHandedRowSpace(context) >= _compactRow + PrismBottomNav.maxLength(labels: true) + PrismSpace.xxs + _controlSize;

double _oneHandedPill(BuildContext context) => PrismBottomNav.maxLength(labels: _oneHandedLabelsFit(context));

/// Tab labels make the pill wider. They show only where the whole bottom row still fits with them. Else the tabs are
/// icons only, at the size they had before labels.
bool navLabelsFit(BuildContext context) => LayoutPrefsScope.oneHandedOf(context)
    ? _oneHandedLabelsFit(context)
    : _oneHandedRowSpace(context) >= PrismBottomNav.maxLength(labels: true) + _createGap + _createSize;

/// With one-handed controls on, the bottom row has room for both the avatar and the bell. Else the avatar alone holds
/// both, in a sheet.
bool oneHandedRowHasRoom(BuildContext context) =>
    _oneHandedRowSpace(context) >= _compactRow + _oneHandedPill(context) + PrismSpace.xxs + _controlSize;

/// Too narrow for the avatar in the row: it stands above the create button instead.
bool oneHandedAvatarAbove(BuildContext context) => _oneHandedRowSpace(context) < _compactRow + _oneHandedPill(context);

/// Hosts the tab content with a docked bar band under it, like an iOS tab bar: an opaque surface band with a top
/// hairline that covers the bottom safe area and holds the pill and the create button. The band slides away while the
/// user scrolls down and comes back when they scroll up. Tapping the active tab again takes its list back to the top.
///
/// Where iOS keeps a safe column on the right of a portrait screen (the iPhone Duo outer screen puts the status bar
/// there), the pill and the create button stand in that column instead, always visible.
///
/// With one-handed controls on, the profile and the notifications join the row, so they hide and show with it.
///
/// While the keyboard is up, the band fades out and stops taking taps.
class BottomBar extends StatefulWidget {
  final Widget? child;
  const BottomBar({this.child, super.key});

  /// Scrolls the list the user last dragged in the active tab back to the top. Does nothing outside a [BottomBar] or
  /// before the user has scrolled that tab.
  static void scrollActiveTabToTop(BuildContext context) =>
      context.findAncestorStateOfType<_BottomBarState>()?._scrollActiveTabToTop();

  @override
  State<BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<BottomBar> {
  int _activeTabIndex = 0;

  /// The vertical list the user last dragged in each tab.
  // ponytail: a tab with more than one list (Home feeds) scrolls only the one dragged last.
  final Map<int, BuildContext> _dragged = <int, BuildContext>{};

  bool _onScroll(ScrollNotification notification) {
    final BuildContext? scrolled = notification.context;
    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null &&
        notification.metrics.axis == Axis.vertical &&
        scrolled != null) {
      _dragged[_activeTabIndex] = scrolled;
    }
    return false;
  }

  void _scrollActiveTabToTop() {
    final BuildContext? scrolled = _dragged[_activeTabIndex];
    if (scrolled == null || !scrolled.mounted) return;
    final ScrollPosition? position = Scrollable.maybeOf(scrolled)?.position;
    if (position == null) return;
    // A NestedScrollView shares one offset between its header and its body. Driving the outer position to its top
    // takes both there.
    final NestedScrollViewState? nested = scrolled.findAncestorStateOfType<NestedScrollViewState>();
    final bool ownedByNested =
        nested != null &&
        <ScrollController>[
          nested.outerController,
          nested.innerController,
        ].any((ScrollController c) => c.positions.contains(position));
    final Iterable<ScrollPosition> targets = ownedByNested
        ? nested.outerController.positions
        : <ScrollPosition>[position];
    for (final ScrollPosition target in targets) {
      if (!target.hasPixels || !target.hasContentDimensions) continue;
      target.moveTo(target.minScrollExtent, duration: context.motion(PrismDurations.slow), curve: PrismCurves.enter);
    }
  }

  @override
  Widget build(BuildContext context) {
    _activeTabIndex = AutoTabsRouter.of(context, watch: true).activeIndex;
    final Widget child = NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: widget.child ?? const SizedBox.shrink(),
    );
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    final double railWidth = sideSafeColumnWidth(context);
    final bool oneHanded = LayoutPrefsScope.oneHandedOf(context);
    final bool avatarAbove = oneHanded && oneHandedAvatarAbove(context);
    if (railWidth > 0) {
      return ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: Row(
          textDirection: oneHanded ? TextDirection.ltr : null,
          children: [
            Expanded(
              child: SideSafeColumnScope(
                nativeWidth: railWidth,
                child: MediaQuery.removePadding(context: context, removeRight: true, child: child),
              ),
            ),
            SizedBox(
              width: railWidth,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 12;
                  return SingleChildScrollView(
                    primary: false,
                    reverse: true,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomPadding),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - bottomPadding).clamp(0.0, double.infinity),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (oneHanded) ...const [
                              ProfileAvatarButton(floating: true),
                              SizedBox(height: PrismSpace.xxs),
                              NotificationBell(source: NotificationsEntrySourceValue.bottom),
                              SizedBox(height: 12),
                            ],
                            const PrismBottomNav(axis: Axis.vertical),
                            const SizedBox(height: 12),
                            const PrismFab(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }
    return floating.BottomBar(
      layout: floating.BottomBarLayout(
        width: MediaQuery.sizeOf(context).width,
        offset: 0,
        borderRadius: BorderRadius.zero,
        fit: StackFit.expand,
        // The band pads itself for the bottom safe area, so its colour reaches the screen edge.
        respectSafeArea: false,
      ),
      theme: const floating.BottomBarThemeData(barDecoration: BoxDecoration()),
      showIcon: false,
      // The tab Scaffolds do not know about the band, so lift their floating snackbars above it.
      body: Theme(
        data: theme.copyWith(
          snackBarTheme: theme.snackBarTheme.copyWith(
            insetPadding: (theme.snackBarTheme.insetPadding ?? const EdgeInsets.fromLTRB(15, 5, 15, 10)).copyWith(
              bottom: _snackBarBottomInset + (avatarAbove ? _controlSize + PrismSpace.xs : 0),
            ),
          ),
        ),
        child: child,
      ),
      child: IgnorePointer(
        ignoring: keyboardUp,
        child: AnimatedOpacity(
          opacity: keyboardUp ? 0 : 1,
          duration: context.motion(PrismDurations.fast),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.onSurface.withValues(alpha: 0.08), width: 0.5)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                MediaQuery.paddingOf(context).left + _barInset,
                _bandPadding,
                MediaQuery.paddingOf(context).right + _barInset,
                _bandPadding + MediaQuery.paddingOf(context).bottom,
              ),
              child: Align(
                heightFactor: 1.0,
                child: oneHanded
                    ? _OneHandedRow(avatarAbove: avatarAbove, roomy: oneHandedRowHasRoom(context))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IntrinsicWidth(child: PrismBottomNav(labels: navLabelsFit(context))),
                          const SizedBox(width: _createGap),
                          const PrismFab(),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The avatar before the pill and the bell after the create button. A narrower screen gets the avatar alone, which
/// opens a sheet with both, and the narrowest stands it above the create button so the pill keeps its size.
class _OneHandedRow extends StatelessWidget {
  const _OneHandedRow({required this.avatarAbove, required this.roomy});

  final bool avatarAbove;
  final bool roomy;

  @override
  Widget build(BuildContext context) {
    final Widget tabsAndCreate = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IntrinsicWidth(child: PrismBottomNav(labels: _oneHandedLabelsFit(context))),
        const SizedBox(width: _createGap),
        const PrismFab(),
      ],
    );
    if (avatarAbove) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.only(end: (_createSize - _controlSize) / 2),
            child: AccountButton(),
          ),
          const SizedBox(height: PrismSpace.xs),
          tabsAndCreate,
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (roomy) const ProfileAvatarButton(floating: true) else const AccountButton(),
        const SizedBox(width: PrismSpace.xxs),
        tabsAndCreate,
        if (roomy) ...const [
          SizedBox(width: PrismSpace.xxs),
          NotificationBell(source: NotificationsEntrySourceValue.bottom),
        ],
      ],
    );
  }
}
