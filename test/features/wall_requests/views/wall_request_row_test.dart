import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/wall_requests/domain/entities/wall_request.dart';
import 'package:Prism/features/wall_requests/views/widgets/wall_request_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WallRequest _request({
  bool mine = false,
  bool voted = false,
  WallRequestStatus status = WallRequestStatus.open,
  WallRequestFiller? filledBy,
}) => WallRequest(
  id: 'r1',
  text: 'dark minimal mountains',
  tags: const <String>['Minimal', 'dreamy'],
  voteCount: 4,
  status: status,
  createdAt: DateTime(2026, 10, 28),
  requesterName: 'Ana',
  requesterPhoto: '',
  mine: mine,
  voted: voted,
  hidden: false,
  filledBy: filledBy,
);

Future<void> _pumpRow(WidgetTester tester, WallRequest request, {VoidCallback? onVote}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: WallRequestRow(request: request, onVote: onVote),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    app_state.prismUser = app_constants.createGuestPrismUser();
  });

  testWidgets('an open request not voted on shows an Upvote button', (tester) async {
    await _pumpRow(tester, _request(), onVote: () {});

    expect(find.byTooltip('Upvote'), findsOneWidget);
    expect(find.byTooltip('Remove upvote'), findsNothing);
    expect(find.text('dark minimal mountains'), findsOneWidget);
  });

  testWidgets('a voted request shows Remove upvote', (tester) async {
    await _pumpRow(tester, _request(voted: true), onVote: () {});

    expect(find.byTooltip('Remove upvote'), findsOneWidget);
    expect(find.byTooltip('Upvote'), findsNothing);
  });

  testWidgets('the user own request shows Your request and no upvote button', (tester) async {
    await _pumpRow(tester, _request(mine: true), onVote: () {});

    expect(find.text('Your request'), findsOneWidget);
    expect(find.byTooltip('Upvote'), findsNothing);
    expect(find.byTooltip('Remove upvote'), findsNothing);
  });

  testWidgets('a filled request has no upvote button', (tester) async {
    await _pumpRow(tester, _request(status: WallRequestStatus.filled, filledBy: WallRequestFiller.studio));

    expect(find.byTooltip('Upvote'), findsNothing);
    expect(find.byTooltip('Remove upvote'), findsNothing);
    expect(find.text('Made by Prism Studio'), findsOneWidget);
  });

  testWidgets('wallRequestAge words the age of a request', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext built) {
            context = built;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final DateTime now = DateTime(2026, 10, 29, 12);
    expect(wallRequestAge(context, now, now: now), 'Just now');
    expect(wallRequestAge(context, now.subtract(const Duration(minutes: 5)), now: now), '5 minutes ago');
    expect(wallRequestAge(context, now.subtract(const Duration(hours: 3)), now: now), '3 hours ago');
    expect(wallRequestAge(context, now.subtract(const Duration(days: 2)), now: now), '2 days ago');
    expect(wallRequestAge(context, now.subtract(const Duration(days: 21)), now: now), '3 weeks ago');
    expect(
      wallRequestErrorText(context, WallRequestError.accountTooNew),
      "Your account can request walls and vote once it's 10 days old.",
    );
  });
}
