import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/features/personalized_feed/domain/entities/home_feed_chip.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The text tabs of the home feed, in the style of X: `For you`, `Following`, `Trending`, `Latest` and `Popular`.
/// An accent underline marks the chosen tab, and a hairline runs under the row.
///
/// [selected] is the tab the feed shows, and [controller] only draws the underline. A tap on the chosen `For you` tab
/// opens the feed settings through [onTuneTap]. On a screen too narrow for all tabs, the row scrolls and fades out at
/// the right edge while more tabs wait there.
class HomeFeedTabBar extends StatefulWidget implements PreferredSizeWidget {
  const HomeFeedTabBar({
    super.key,
    required this.controller,
    required this.selected,
    required this.onSelected,
    this.onTuneTap,
    this.isRefreshing = false,
  });

  static const double height = 44;

  /// Puts the first label under the profile picture of the top bar: 8 px of bar padding and 6 px around the picture,
  /// less the 8 px of label padding.
  static const double _startInset = 6;

  /// Leaves 16 px between labels. At 15 pt in the app font, the five tabs then fit a 390 pt screen.
  static const double _labelPadding = 8;
  static const double _fadeWidth = 24;

  final TabController controller;
  final HomeFeedChip selected;
  final ValueChanged<HomeFeedChip> onSelected;
  final VoidCallback? onTuneTap;

  /// Draws a thin bar on the hairline while cached walls are on screen and the fresh page loads.
  final bool isRefreshing;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  State<HomeFeedTabBar> createState() => _HomeFeedTabBarState();
}

class _HomeFeedTabBarState extends State<HomeFeedTabBar> {
  bool _moreToTheRight = false;

  bool _onScrollMetrics(Notification notification) {
    final ScrollMetrics? metrics = switch (notification) {
      ScrollNotification(:final ScrollMetrics metrics) => metrics,
      ScrollMetricsNotification(:final ScrollMetrics metrics) => metrics,
      _ => null,
    };
    if (metrics == null || metrics.axis != Axis.horizontal) {
      return false;
    }
    final bool more = metrics.extentAfter > 1;
    if (more != _moreToTheRight) {
      setState(() => _moreToTheRight = more);
    }
    return false;
  }

  Shader _fade(Rect bounds, {required bool fadeEnd}) {
    if (!fadeEnd) {
      return const LinearGradient(colors: <Color>[Colors.white, Colors.white]).createShader(bounds);
    }
    return LinearGradient(
      colors: const <Color>[Colors.white, Colors.white, Colors.transparent],
      stops: <double>[0, 1 - HomeFeedTabBar._fadeWidth / bounds.width, 1],
    ).createShader(bounds);
  }

  void _handleTap(int index) {
    final HomeFeedChip chip = HomeFeedChip.values[index];
    if (chip != widget.selected) {
      PrismHaptics.selection();
      widget.onSelected(chip);
      return;
    }
    final VoidCallback? tune = widget.onTuneTap;
    if (chip == HomeFeedChip.forYou && tune != null) {
      PrismHaptics.tap();
      tune();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextStyle labelStyle = PrismTextStyles.button.copyWith(fontWeight: FontWeight.w700);
    return SizedBox(
      height: HomeFeedTabBar.height,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 1,
            child: ColoredBox(color: cs.onSurface.withValues(alpha: 0.1)),
          ),
          NotificationListener<Notification>(
            onNotification: _onScrollMetrics,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              // A new closure each build, so the mask repaints when the fade turns on or off.
              shaderCallback: (Rect bounds) => _fade(bounds, fadeEnd: _moreToTheRight),
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.5,
                child: TabBar(
                  controller: widget.controller,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: const EdgeInsetsDirectional.only(start: HomeFeedTabBar._startInset),
                  labelPadding: const EdgeInsets.symmetric(horizontal: HomeFeedTabBar._labelPadding),
                  labelStyle: labelStyle,
                  unselectedLabelStyle: labelStyle,
                  indicator: UnderlineTabIndicator(
                    borderSide: BorderSide(width: 4, color: cs.primary),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
                  onTap: _handleTap,
                  tabs: <Widget>[
                    for (final HomeFeedChip chip in HomeFeedChip.values)
                      Tab(height: HomeFeedTabBar.height, child: _label(cs, chip)),
                  ],
                ),
              ),
            ),
          ),
          if (widget.isRefreshing)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 2,
              child: IgnorePointer(
                child: LinearProgressIndicator(semanticsLabel: 'Updating', backgroundColor: Colors.transparent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _label(ColorScheme cs, HomeFeedChip chip) {
    if (chip != HomeFeedChip.forYou || widget.onTuneTap == null) {
      return Text(chip.label, softWrap: false);
    }
    return Semantics(
      hint: widget.selected == chip ? 'Double tap to open feed settings' : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(chip.label, softWrap: false),
          Icon(PrismIcons.dropdownCaret, size: 18, color: cs.onSurface.withValues(alpha: 0.6)),
        ],
      ),
    );
  }
}
