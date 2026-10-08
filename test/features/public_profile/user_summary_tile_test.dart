import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/views/widgets/user_summary_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

UserSummaryEntity _user({String name = '', String username = ''}) => UserSummaryEntity(
  id: 'u1',
  email: 'ana@example.com',
  name: name,
  username: username,
  profilePhoto: '',
  isFollowedByCurrentUser: false,
);

void main() {
  setUp(() => AnalyticsRuntime.instance = FakeAppAnalytics());
  tearDown(AnalyticsRuntime.reset);

  Future<void> pumpTile(WidgetTester tester, UserSummaryEntity user) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: UserSummaryTile(user: user, onTap: () {}),
      ),
    ),
  );

  testWidgets('shows the name', (tester) async {
    await pumpTile(tester, _user(name: 'Ana', username: 'ana_w'));
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('falls back to the username, not the email', (tester) async {
    await pumpTile(tester, _user(username: 'ana_w'));
    expect(find.text('ana_w'), findsOneWidget);
    expect(find.textContaining('@example.com'), findsNothing);
  });

  testWidgets('falls back to Prism creator when there is no name or username', (tester) async {
    await pumpTile(tester, _user());
    expect(find.text('Prism creator'), findsOneWidget);
    expect(find.textContaining('ana@example.com'), findsNothing);
  });
}
