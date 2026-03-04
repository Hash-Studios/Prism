import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f0_auth_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f1_interests_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f2_starter_pack_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f3_first_wallpaper_page.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f4_paywall_gate_page.dart';
import 'package:Prism/features/profile_completeness/services/profile_completeness_nudge_service.dart';
import 'package:Prism/features/startup/services/tomorrow_hook_service.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage(name: 'OnboardingV2ShellRoute')
class OnboardingV2Shell extends StatefulWidget {
  const OnboardingV2Shell({super.key});

  @override
  State<OnboardingV2Shell> createState() => _OnboardingV2ShellState();
}

class _OnboardingV2ShellState extends State<OnboardingV2Shell> {
  late final OnboardingV2Bloc _bloc;
  late final PageController _pageController;

  static const List<Widget> _pages = [
    F0AuthPage(),
    F1InterestsPage(),
    F2StarterPackPage(),
    F3FirstWallpaperPage(),
    F4PaywallGatePage(),
  ];

  @override
  void initState() {
    super.initState();
    _bloc = getIt<OnboardingV2Bloc>();
    _pageController = PageController();
    _bloc.add(const OnboardingV2Event.started());
  }

  Future<void> _handleNavRequest(BuildContext context, OnboardingV2NavRequest request) async {
    switch (request) {
      case OnboardingV2NavRequest.openPaywall:
        if (!context.mounted) {
          return;
        }
        await PaywallOrchestrator.instance.present(
          context,
          placement: OnboardingV2Config.paywallPlacement,
          source: OnboardingV2Config.paywallSource,
        );
        if (!context.mounted) {
          return;
        }
        final isPremium = app_state.prismUser.premium;
        _bloc.add(OnboardingV2Event.paywallResultReceived(didPurchase: isPremium));

      case OnboardingV2NavRequest.completeOnboarding:
        if (!context.mounted) {
          return;
        }
        await ProfileCompletenessNudgeService.instance.maybeShowNudge(context, sourceContext: 'onboarding_v2_done');
        if (!context.mounted) {
          return;
        }
        await TomorrowHookService.instance.maybeRunTomorrowHookAtOnboardingDone(context);
        if (!context.mounted) {
          return;
        }
        context.router.replaceAll([const SplashWidgetRoute()]);
    }
  }

  void _animateToStep(OnboardingV2Step step) {
    final index = OnboardingV2Step.values.indexOf(step);
    final currentPage = _pageController.hasClients ? _pageController.page?.round() : null;
    logger.d(
      '_animateToStep step=$step index=$index hasClients=${_pageController.hasClients} currentPage=$currentPage',
      tag: 'OnboardingV2Shell',
    );
    if (_pageController.hasClients && currentPage != index) {
      _pageController.animateToPage(index, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      logger.d('animateToPage called → $index', tag: 'OnboardingV2Shell');
    } else {
      logger.d('animateToPage SKIPPED (already on page or no clients)', tag: 'OnboardingV2Shell');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocConsumer<OnboardingV2Bloc, OnboardingV2State>(
        listenWhen: (prev, curr) {
          final stepChanged = prev.step != curr.step;
          final navChanged = curr.navRequest != null && prev.navRequest != curr.navRequest;
          logger.d(
            'listenWhen prev.step=${prev.step} curr.step=${curr.step} stepChanged=$stepChanged navChanged=$navChanged',
            tag: 'OnboardingV2Shell',
          );
          return stepChanged || navChanged;
        },
        listener: (context, state) {
          logger.d('listener fired step=${state.step} navRequest=${state.navRequest}', tag: 'OnboardingV2Shell');
          _animateToStep(state.step);
          if (state.navRequest != null) {
            _handleNavRequest(context, state.navRequest!);
          }
        },
        buildWhen: (_, __) => false,
        builder: (context, state) {
          return PopScope(
            canPop: false,
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: _pages,
            ),
          );
        },
      ),
    );
  }
}
