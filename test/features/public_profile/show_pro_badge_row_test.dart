import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/features/public_profile/biz/show_pro_badge_cubit.dart';
import 'package:Prism/features/public_profile/views/widgets/show_pro_badge_row.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_firestore_client.dart';

const String _viewer = 'viewer';

class _FailingWriteClient extends FakeFirestoreClient {
  _FailingWriteClient({super.docs});

  @override
  Future<void> updateDoc(String collection, String id, Map<String, dynamic> data, {required String sourceTag}) =>
      throw StateError('offline');
}

Future<void> _pump(WidgetTester tester, ShowProBadgeCubit cubit) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ShowProBadgeRow(cubit: cubit)),
    ),
  );
  await tester.pump();
}

bool _switchValue(WidgetTester tester) => tester.widget<Switch>(find.byType(Switch)).value;

void main() {
  late FakeAppAnalytics analytics;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });

  tearDown(AnalyticsRuntime.reset);

  testWidgets('is on when the showProBadge field is missing', (tester) async {
    final FakeFirestoreClient client = FakeFirestoreClient(
      docs: <String, Map<String, Map<String, dynamic>>>{
        FirebaseCollections.usersV2: <String, Map<String, dynamic>>{
          _viewer: <String, dynamic>{'name': 'Ana'},
        },
      },
    );
    final ShowProBadgeCubit cubit = ShowProBadgeCubit(client, () => _viewer)..load();
    addTearDown(cubit.close);

    await _pump(tester, cubit);
    await tester.pump();

    expect(_switchValue(tester), isTrue);
  });

  testWidgets('is off when showProBadge is false', (tester) async {
    final FakeFirestoreClient client = FakeFirestoreClient(
      docs: <String, Map<String, Map<String, dynamic>>>{
        FirebaseCollections.usersV2: <String, Map<String, dynamic>>{
          _viewer: <String, dynamic>{'showProBadge': false},
        },
      },
    );
    final ShowProBadgeCubit cubit = ShowProBadgeCubit(client, () => _viewer)..load();
    addTearDown(cubit.close);

    await _pump(tester, cubit);
    await tester.pump();

    expect(_switchValue(tester), isFalse);
  });

  testWidgets('turning it off writes showProBadge false and tracks the toggle', (tester) async {
    final FakeFirestoreClient client = FakeFirestoreClient(
      docs: <String, Map<String, Map<String, dynamic>>>{
        FirebaseCollections.usersV2: <String, Map<String, dynamic>>{
          _viewer: <String, dynamic>{'name': 'Ana'},
        },
      },
    );
    final ShowProBadgeCubit cubit = ShowProBadgeCubit(client, () => _viewer)..load();
    addTearDown(cubit.close);

    await _pump(tester, cubit);
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(_switchValue(tester), isFalse);
    expect(client.writes.single.collection, FirebaseCollections.usersV2);
    expect(client.writes.single.id, _viewer);
    expect(client.writes.single.data, <String, dynamic>{'showProBadge': false});
    expect(analytics.events.single, isA<ProBadgeToggledEvent>());
  });

  testWidgets('a failed write puts the switch back on', (tester) async {
    final _FailingWriteClient client = _FailingWriteClient(
      docs: <String, Map<String, Map<String, dynamic>>>{
        FirebaseCollections.usersV2: <String, Map<String, dynamic>>{
          _viewer: <String, dynamic>{'name': 'Ana'},
        },
      },
    );
    final ShowProBadgeCubit cubit = ShowProBadgeCubit(client, () => _viewer)..load();
    addTearDown(cubit.close);

    await _pump(tester, cubit);
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(_switchValue(tester), isTrue);
  });
}
