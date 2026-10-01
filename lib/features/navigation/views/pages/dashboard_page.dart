import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/edge_to_edge_overlay_style.dart';
import 'package:Prism/features/badges/views/widgets/badge_celebrate_host.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:Prism/features/navigation/views/widgets/bottom_nav_bar.dart';
import 'package:Prism/features/profile_completeness/services/profile_completeness_nudge_service.dart';
import 'package:Prism/features/rewards/views/widgets/daily_claim_host.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _checkedProfileCompletenessNudge = false;
  bool _categoryFeedStarted = false;
  late final InAppNotificationsBloc _notificationsBloc;

  @override
  void initState() {
    super.initState();
    _notificationsBloc = getIt<InAppNotificationsBloc>()..add(const InAppNotificationsEvent.started());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_categoryFeedStarted) {
      _categoryFeedStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        context.read<CategoryFeedBloc>().add(const CategoryFeedEvent.started());
      });
    }
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
    final brightness = Theme.of(context).brightness;
    final overlayStyle = edgeToEdgeOverlayStyle(
      statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
    );
    return BlocProvider<InAppNotificationsBloc>.value(
      value: _notificationsBloc,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: AutoTabsRouter(
          routes: const [HomeTabRoute(), SearchTabRoute(), RewardsTabRoute(), CollectionTabRoute()],
          duration: PrismDurations.fast,
          transitionBuilder: (context, child, animation) {
            if (context.reduceMotion) return child;
            final Animation<double> t = animation.drive(CurveTween(curve: PrismCurves.enter));
            return FadeTransition(
              opacity: t,
              child: AnimatedBuilder(
                animation: t,
                builder: (context, child) => Transform.translate(offset: Offset(0, 6 * (1 - t.value)), child: child),
                child: child,
              ),
            );
          },
          builder: (context, child) {
            final tabsRouter = AutoTabsRouter.of(context);
            return PopScope(
              canPop: tabsRouter.activeIndex == 0,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop) {
                  tabsRouter.setActiveIndex(0);
                }
              },
              child: DailyClaimSheetHost(
                onSeeRewards: () => tabsRouter.setActiveIndex(2),
                child: BadgeCelebrateHost(
                  onSeeRewards: () => tabsRouter.setActiveIndex(2),
                  child: BottomBar(child: child),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
