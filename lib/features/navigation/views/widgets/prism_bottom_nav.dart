import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/features/navigation/views/widgets/upload_bottom_panel.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

class PrismBottomNav extends StatefulWidget {
  const PrismBottomNav({super.key});

  @override
  State<PrismBottomNav> createState() => _PrismBottomNavState();
}

class _PrismBottomNavState extends State<PrismBottomNav> with SingleTickerProviderStateMixin {
  static const List<_NavTabConfig> _tabs = <_NavTabConfig>[
    _NavTabConfig(index: 0, label: 'Home', icon: JamIcons.home_f, value: NavTabValue.home),
    _NavTabConfig(index: 1, label: 'Search', icon: JamIcons.search, value: NavTabValue.search),
    _NavTabConfig(index: 2, label: 'Setups', icon: JamIcons.instant_picture_f, value: NavTabValue.setups),
    _NavTabConfig(index: 3, label: 'Profile', icon: JamIcons.cog_f, value: NavTabValue.profile),
  ];

  late final AnimationController _indicatorController;
  late final Animation<double> _indicatorWidth;
  String? _failedProfileImageUrl;

  @override
  void initState() {
    super.initState();
    _indicatorController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _indicatorWidth =
        Tween<double>(
          begin: 14,
          end: 20,
        ).animate(CurvedAnimation(parent: _indicatorController, curve: Curves.easeOutCubic))..addListener(() {
          if (mounted) {
            setState(() {});
          }
        });
    _indicatorController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    super.dispose();
  }

  void _trackTabSelection({required int fromIndex, required int toIndex}) {
    analytics.track(NavTabSelectedEvent(fromTab: _tabs[fromIndex].value, toTab: _tabs[toIndex].value));
  }

  void _switchTab({required TabsRouter tabsRouter, required int toIndex}) {
    final fromIndex = tabsRouter.activeIndex;
    if (fromIndex == toIndex) {
      logger.d('Currently on ${_tabs[toIndex].label}');
      return;
    }
    _trackTabSelection(fromIndex: fromIndex, toIndex: toIndex);
    tabsRouter.setActiveIndex(toIndex);
  }

  void _openUploadSheet() {
    if (!mounted) {
      return;
    }
    showModalBottomSheet(isScrollControlled: true, context: context, builder: (context) => const UploadBottomPanel());
  }

  void _onUploadPressed() {
    analytics.track(
      const UploadActionSelectedEvent(
        action: AnalyticsActionValue.uploadSheetOpened,
        entrypoint: EntryPointValue.bottomNav,
      ),
    );
    if (!app_state.prismUser.loggedIn) {
      googleSignInPopUp(context, () {
        if (mounted) {
          setState(() {
            _failedProfileImageUrl = null;
          });
          _openUploadSheet();
        }
      });
      return;
    }
    _openUploadSheet();
  }

  @override
  Widget build(BuildContext context) {
    final tabsRouter = AutoTabsRouter.of(context);
    final activeIndex = tabsRouter.activeIndex;

    return Container(
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
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _TabButton(
              tooltip: _tabs[0].label,
              isActive: activeIndex == _tabs[0].index,
              indicatorWidth: _indicatorWidth.value,
              padding: const EdgeInsets.fromLTRB(18, 10, 0, 10),
              icon: Icon(_tabs[0].icon, color: Theme.of(context).colorScheme.secondary),
              onPressed: () => _switchTab(tabsRouter: tabsRouter, toIndex: _tabs[0].index),
            ),
            _TabButton(
              tooltip: _tabs[1].label,
              isActive: activeIndex == _tabs[1].index,
              indicatorWidth: _indicatorWidth.value,
              icon: Icon(_tabs[1].icon, color: Theme.of(context).colorScheme.secondary),
              onPressed: () => _switchTab(tabsRouter: tabsRouter, toIndex: _tabs[1].index),
            ),
            _UploadButton(onPressed: _onUploadPressed),
            _TabButton(
              tooltip: _tabs[2].label,
              isActive: activeIndex == _tabs[2].index,
              indicatorWidth: _indicatorWidth.value,
              icon: Icon(_tabs[2].icon, color: Theme.of(context).colorScheme.secondary),
              onPressed: () => _switchTab(tabsRouter: tabsRouter, toIndex: _tabs[2].index),
            ),
            _TabButton(
              tooltip: _tabs[3].label,
              isActive: activeIndex == _tabs[3].index,
              indicatorWidth: _indicatorWidth.value,
              padding: const EdgeInsets.fromLTRB(0, 10, 18, 10),
              icon: _profileIcon(context),
              onPressed: () => _switchTab(tabsRouter: tabsRouter, toIndex: _tabs[3].index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileIcon(BuildContext context) {
    final isLoggedIn = app_state.prismUser.loggedIn;
    final profilePhoto = app_state.prismUser.profilePhoto;

    if (!isLoggedIn) {
      return Icon(JamIcons.cog_f, color: Theme.of(context).colorScheme.secondary);
    }

    if (_failedProfileImageUrl == profilePhoto) {
      return Icon(JamIcons.user_circle, color: Theme.of(context).primaryColor);
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(500),
        color: Theme.of(context).colorScheme.secondary,
      ),
      child: CircleAvatar(
        key: ValueKey<String>(profilePhoto),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        radius: 11,
        backgroundImage: NetworkImage(profilePhoto),
        onBackgroundImageError: (_, stackTrace) {
          if (!mounted) {
            return;
          }
          setState(() {
            _failedProfileImageUrl = profilePhoto;
          });
        },
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String tooltip;
  final bool isActive;
  final double indicatorWidth;
  final Widget icon;
  final VoidCallback onPressed;
  final EdgeInsets padding;

  const _TabButton({
    required this.tooltip,
    required this.isActive,
    required this.indicatorWidth,
    required this.icon,
    required this.onPressed,
    this.padding = const EdgeInsets.fromLTRB(2, 0, 2, 0),
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.error == Colors.black
        ? Colors.white24
        : Theme.of(context).colorScheme.error;

    return Padding(
      padding: padding,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: isActive ? 9 : 0),
            icon,
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(500),
                color: isActive ? activeColor : Theme.of(context).colorScheme.secondary,
              ),
              margin: isActive ? const EdgeInsets.all(3) : EdgeInsets.zero,
              width: isActive ? indicatorWidth : 0,
              height: isActive ? 3 : 0,
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _UploadButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDarkAccent = Theme.of(context).colorScheme.error == Colors.black;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 45,
            width: 45,
            decoration: BoxDecoration(
              border: Border.all(
                color: isDarkAccent ? Colors.black : Theme.of(context).colorScheme.error,
                width: isDarkAccent ? 1 : 0,
              ),
              color: isDarkAccent ? Colors.white24 : Theme.of(context).colorScheme.error,
              borderRadius: BorderRadius.circular(500),
            ),
          ),
          IconButton(
            tooltip: 'Upload',
            padding: EdgeInsets.zero,
            onPressed: onPressed,
            icon: Icon(JamIcons.plus, color: isDarkAccent ? Colors.white : Theme.of(context).colorScheme.secondary),
          ),
        ],
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
