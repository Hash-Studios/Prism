import 'dart:async';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/navigation/views/widgets/bottom_nav_bar.dart';
import 'package:Prism/features/profile_completeness/services/profile_completeness_nudge_service.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _checkedProfileCompletenessNudge = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checkedProfileCompletenessNudge) {
      return;
    }
    _checkedProfileCompletenessNudge = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(ProfileCompletenessNudgeService.instance.maybeShowNudge(context, sourceContext: 'dashboard_entry'));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter(
      routes: const [HomeTabRoute(), SearchTabRoute(), ProfileTabRoute()],
      builder: (context, child) {
        final tabsRouter = AutoTabsRouter.of(context);
        return PopScope(
          canPop: tabsRouter.activeIndex == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              tabsRouter.setActiveIndex(0);
            }
          },
          child: BottomBar(child: child),
        );
      },
    );
  }
}
