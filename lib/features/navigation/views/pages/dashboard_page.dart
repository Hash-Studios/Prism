import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/navigation/views/widgets/bottom_nav_bar.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter(
      routes: const [HomeTabRoute(), SearchTabRoute(), SetupsTabRoute(), AiTabRoute(), ProfileTabRoute()],
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
