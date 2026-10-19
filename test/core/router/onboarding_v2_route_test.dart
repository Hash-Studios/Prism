import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/onboarding_v2/src/views/onboarding_v2_shell.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _OnboardingRouteTestRouter extends AppRouter {
  _OnboardingRouteTestRouter(this.onShellBuilt);

  final void Function(OnboardingV2Shell shell) onShellBuilt;

  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(
      path: '/',
      page: PageInfo('OnboardingRouteTestHost', builder: (_) => const Scaffold(body: Text('host'))),
    ),
    AutoRoute(
      path: '/onboarding/v2',
      page: PageInfo(
        OnboardingV2ShellRoute.name,
        builder: (data) {
          final shell = OnboardingV2ShellRoute.page.builder(data) as OnboardingV2Shell;
          onShellBuilt(shell);
          return const SizedBox.shrink();
        },
      ),
    ),
  ];
}

void main() {
  testWidgets('generated onboarding route forwards its key and recovery callback', (tester) async {
    const key = ValueKey<String>('onboarding-route-key');
    Future<bool> signOutForRecovery() async => true;
    OnboardingV2Shell? builtShell;
    final router = _OnboardingRouteTestRouter((shell) => builtShell = shell);

    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.config(),
      ),
    );
    await router.navigatePath('/');
    await tester.pumpAndSettle();
    await router.replaceAll(<PageRouteInfo>[OnboardingV2ShellRoute(key: key, signOutForRecovery: signOutForRecovery)]);
    await tester.pumpAndSettle();

    expect(builtShell, isNotNull);
    expect(builtShell!.key, same(key));
    expect(builtShell!.signOutForRecovery, same(signOutForRecovery));
  });
}
