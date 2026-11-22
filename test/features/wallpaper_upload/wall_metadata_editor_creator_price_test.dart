import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/features/creator_walls/creator_walls.dart';
import 'package:Prism/features/wallpaper_upload/biz/bloc/wall_metadata_cubit.dart';
import 'package:Prism/features/wallpaper_upload/domain/entities/wall_metadata.dart';
import 'package:Prism/features/wallpaper_upload/views/pages/wall_metadata_editor.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';

class _Cubit extends MockCubit<WallMetadataState> implements WallMetadataCubit {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const metadata = PendingWallMetadata(
    text: WallTextMetadata(title: 'Rain', description: 'Evening light'),
  );
  const snapshot = WallMetadataSnapshot(metadata: metadata, approved: true, revision: 'rev');
  const ready = WallMetadataState(
    status: WallMetadataStatus.ready,
    snapshot: snapshot,
    draft: metadata,
    formVersion: 1,
  );
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _Cubit cubit;
  late FakeAppAnalytics analytics;
  late List<Map<String, dynamic>> priceCalls;

  setUpAll(() => registerFallbackValue(metadata));

  setUp(() {
    cubit = _Cubit();
    when(() => cubit.load()).thenAnswer((_) async {});
    when(() => cubit.save()).thenAnswer((_) async {});
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    priceCalls = <Map<String, dynamic>>[];
    messenger.setMockMethodCallHandler(toastChannel, (MethodCall call) async => true);
    EconomyConfig.resetForTest();
    CreatorWallsFlag.debugEnabled = true;
    EconomyConfig.current = EconomyConfig.fromMap(<String, dynamic>{
      'flags': <String, dynamic>{'creatorWallsEnabled': true},
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(toastChannel, null);
    CreatorWallsFlag.debugEnabled = null;
    EconomyConfig.resetForTest();
  });

  Future<void> pump(
    WidgetTester tester, {
    Map<String, dynamic> wallData = const <String, dynamic>{},
    CreatorWallPrices? prices,
  }) async {
    whenListen(cubit, const Stream<WallMetadataState>.empty(), initialState: ready);
    await tester.pumpWidget(
      MaterialApp(
        theme: kLightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: WallMetadataEditor(
          wall: FirestoreDocument('doc', wallData),
          approved: true,
          cubit: cubit,
          creatorPrices:
              prices ??
              CreatorWallPrices(
                call: (input) async {
                  priceCalls.add(input);
                  return <String, dynamic>{'success': true, 'reason': 'ok'};
                },
              ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the price picker when selling is on', (tester) async {
    await pump(tester, wallData: <String, dynamic>{'creatorPrice': 20});
    expect(find.text('Sell this wall'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
  });

  testWidgets('hides the price picker when selling is off', (tester) async {
    CreatorWallsFlag.debugEnabled = false;
    await pump(tester);
    expect(find.text('Sell this wall'), findsNothing);
  });

  testWidgets('a tap on 40 calls setWallPrice with the wall doc id and 40', (tester) async {
    await pump(tester);
    await tester.ensureVisible(find.text('40'));
    await tester.pump();
    await tester.tap(find.text('40'));
    await tester.pump();
    await tester.pump();
    expect(priceCalls, <Map<String, dynamic>>[
      <String, dynamic>{'wallId': 'doc', 'price': 40},
    ]);
    expect(analytics.events.map((AnalyticsEvent e) => e.eventName), contains('creator_wall_price_set'));
    // The success toast holds a one second timer.
    await tester.pump(const Duration(seconds: 1));
  });
}
