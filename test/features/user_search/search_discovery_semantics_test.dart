import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/user_search/views/widgets/search_discovery_sections.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

class _DiscoveryRouter extends AppRouter {
  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(
      path: '/',
      page: PageInfo('DiscoveryHost', builder: (_) => const Scaffold(body: _DiscoveryHost())),
    ),
    AutoRoute(
      path: '/collection-view',
      page: PageInfo(
        CollectionViewRoute.name,
        builder: (data) => Scaffold(body: Text(data.argsAs<CollectionViewRouteArgs>().collectionName)),
      ),
    ),
  ];
}

final List<PrismPaletteColor> _tappedColours = <PrismPaletteColor>[];

class _DiscoveryHost extends StatelessWidget {
  const _DiscoveryHost();

  @override
  Widget build(BuildContext context) => ListView(
    children: <Widget>[
      const CategorySection(),
      ColourSection(onPressed: _tappedColours.add),
    ],
  );
}

void main() {
  testWidgets('category semantic tap opens its category route', (tester) async {
    final router = _DiscoveryRouter();
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router.config(),
        ),
      );
      await router.navigatePath('/');
      await tester.pumpAndSettle();

      final SemanticsNode node = tester.getSemantics(find.bySemanticsLabel('Category, AI Art'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: node.id),
      );
      await tester.pumpAndSettle();

      expect(find.text('category:AI%20Art'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('colour semantic tap reports the matching palette colour', (tester) async {
    _tappedColours.clear();
    final router = _DiscoveryRouter();
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router.config(),
        ),
      );
      await router.navigatePath('/');
      await tester.pumpAndSettle();

      final SemanticsNode node = tester.getSemantics(find.bySemanticsLabel('Red'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: node.id),
      );
      await tester.pumpAndSettle();

      expect(_tappedColours.map((PrismPaletteColor c) => c.name), <String>['Red']);
    } finally {
      semantics.dispose();
    }
  });
}
