import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/user_search/views/widgets/search_discovery_sections.dart';
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
    AutoRoute(
      path: '/color',
      page: PageInfo(ColorRoute.name, builder: (data) => Scaffold(body: Text(data.argsAs<ColorRouteArgs>().hexColor))),
    ),
  ];
}

class _DiscoveryHost extends StatelessWidget {
  const _DiscoveryHost();

  @override
  Widget build(BuildContext context) => ListView(children: const <Widget>[CategorySection(), ColourSection()]);
}

void main() {
  testWidgets('category semantic tap opens its category route', (tester) async {
    final router = _DiscoveryRouter();
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
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

  testWidgets('colour semantic tap opens the matching colour route', (tester) async {
    final router = _DiscoveryRouter();
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
      await router.navigatePath('/');
      await tester.pumpAndSettle();

      final SemanticsNode node = tester.getSemantics(find.bySemanticsLabel('Red wallpapers'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: node.id),
      );
      await tester.pumpAndSettle();

      expect(find.text('b71c1c'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
