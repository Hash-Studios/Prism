import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/utils/side_safe_column.dart';
import 'package:Prism/features/layout_prefs/views/layout_prefs_scope.dart';
import 'package:Prism/features/navigation/views/widgets/account_controls.dart';
import 'package:Prism/features/navigation/views/widgets/prism_bottom_nav.dart';
import 'package:Prism/features/navigation/views/widgets/prism_fab.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart' as floating;

/// The bar's default offset, the pill height, and a gap.
const double _snackBarBottomInset = 10 + 56 + PrismSpace.xs;

const double _createGap = 12;
const double _createSize = 56;
const double _controlSize = 44;

/// The space the floating bar leaves on each side of its row ([floating.BottomBarLayout.offset]).
const double _barInset = 10;

const double _compactRow = _controlSize + PrismSpace.xxs + _createGap + _createSize;

/// Height of the fade under the floating row, above the bottom safe area.
const double _fadeHeight = 90;

/// Size of the scroll-to-top button that takes the row's place while it hides.
const double _scrollTopSize = 44;

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

/// Hosts the tab content with the floating pill and create button above it. The bar hides while the user scrolls
/// down. The package's scroll-to-top button takes its place only after the user is more than two screens down and the
/// keyboard is not up.
///
/// Where iOS keeps a safe column on the right of a portrait screen (the iPhone Duo outer screen puts the status bar
/// there), the pill and the create button stand in that column instead, always visible.
///
/// With one-handed controls on, the profile and the notifications join the row, so they hide and show with it.
///
/// A fade to the page colour sits under the row, so content that scrolls under it does not fight the pill. While the
/// keyboard is up, the row fades out and stops taking taps.
class BottomBar extends StatefulWidget {
  final Widget? child;
  const BottomBar({this.child, super.key});

  @override
  State<BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<BottomBar> {
  /// More than two screens down the active vertical scroll view. Only then is scroll-to-top worth a button.
  bool _deep = false;

  bool _onScroll(ScrollNotification notification) {
    final ScrollMetrics metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) return false;
    final bool deep = metrics.pixels > 2 * metrics.viewportDimension;
    if (deep != _deep) setState(() => _deep = deep);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final Widget? child = widget.child;
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
                child: MediaQuery.removePadding(context: context, removeRight: true, child: child ?? const SizedBox()),
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
        borderRadius: BorderRadius.circular(500),
        fit: StackFit.expand,
      ),
      theme: floating.BottomBarThemeData(
        barDecoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(500)),
        // The circle is drawn by [icon], so it can fade and scale in. The package clips the icon to an oval, so a
        // shadow would be cut off.
        iconDecoration: const BoxDecoration(),
        iconWidth: _scrollTopSize,
        iconHeight: _scrollTopSize,
      ),
      showIcon: _deep && !keyboardUp,
      iconTooltip: context.l10n.navigationScrollToTop,
      icon: (width, height) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: context.motion(PrismDurations.fast),
        curve: PrismCurves.enter,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.95 + 0.05 * t, child: child),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface,
            shape: BoxShape.circle,
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
          ),
          child: Center(child: Icon(Icons.arrow_upward_rounded, color: cs.onSurface, size: 20)),
        ),
      ),
      // The tab Scaffolds do not know about the pill, so lift their floating snackbars above it.
      body: Theme(
        data: theme.copyWith(
          snackBarTheme: theme.snackBarTheme.copyWith(
            insetPadding: (theme.snackBarTheme.insetPadding ?? const EdgeInsets.fromLTRB(15, 5, 15, 10)).copyWith(
              bottom: _snackBarBottomInset + (avatarAbove ? _controlSize + PrismSpace.xs : 0),
            ),
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: MediaQuery.viewPaddingOf(context).bottom + _fadeHeight,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [cs.surface.withValues(alpha: 0), cs.surface.withValues(alpha: 0.85)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      child: IgnorePointer(
        ignoring: keyboardUp,
        child: AnimatedOpacity(
          opacity: keyboardUp ? 0 : 1,
          duration: context.motion(PrismDurations.fast),
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
