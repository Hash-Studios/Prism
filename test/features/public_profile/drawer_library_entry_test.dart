import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/public_profile/views/widgets/drawer_widget.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _MockStackRouter extends Mock implements StackRouter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockStackRouter router;
  late FakeAppAnalytics analytics;
  late List<String> toasts;
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

  setUp(() {
    registerFallbackValue(LibraryRoute());
    router = _MockStackRouter();
    when(() => router.push(any())).thenAnswer((_) async => null);
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..id = 'user_1'
      ..loggedIn = true;
    toasts = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (
      call,
    ) async {
      if (call.method == 'showToast') toasts.add((call.arguments as Map)['msg'] as String);
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  Future<void> openDrawer(WidgetTester tester) async {
    // The drawer wraps its list tiles in a ColoredBox. Flutter reports that in debug builds. It is not under test.
    final void Function(FlutterErrorDetails)? original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('ListTile background color')) return;
      original?.call(details);
    };
    final GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: Scaffold(key: key, drawer: const ProfileDrawer(), body: const SizedBox()),
        ),
      ),
    );
    key.currentState!.openDrawer();
    await tester.pumpAndSettle();
  }

  testWidgets('one Library entry replaces the Favourites and Downloads entries', (tester) async {
    await openDrawer(tester);

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Favourite Wallpapers'), findsNothing);
    expect(find.text('Downloaded Walls'), findsNothing);
  });

  testWidgets('tapping Library closes the drawer and opens the Library page', (tester) async {
    await openDrawer(tester);

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();

    verify(() => router.push(any(that: isA<LibraryRoute>()))).called(1);
    expect(find.text('Library'), findsNothing);
    final tapped = analytics.events.whereType<SurfaceActionTappedEvent>().single;
    expect(tapped.action, AnalyticsActionValue.drawerLibraryTapped);
  });

  testWidgets('a share link that cannot be made shows an error toast', (tester) async {
    await openDrawer(tester);

    await tester.tap(find.text('Share your Profile'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();

    expect(toasts, contains("Couldn't create the link. Try again."));
    await tester.pump(const Duration(seconds: 2));
  });
}
