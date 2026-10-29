import 'package:Prism/features/wall_requests/domain/entities/wall_request.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/fills_request_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WallRequest _request({String id = 'req_1', String text = 'Neon city at night'}) => WallRequest(
  id: id,
  text: text,
  tags: const <String>[],
  voteCount: 3,
  status: WallRequestStatus.open,
  createdAt: DateTime(2026, 10),
  requesterName: 'Asha',
  requesterPhoto: '',
  mine: false,
  voted: false,
  hidden: false,
);

void main() {
  Future<void> pumpRow(
    WidgetTester tester, {
    String requestText = '',
    required ValueChanged<WallRequest?> onChanged,
    Future<WallRequest?> Function(BuildContext)? pick,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FillsRequestRow(requestText: requestText, onChanged: onChanged, pick: pick),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the hint and no clear button when no request is set', (tester) async {
    await pumpRow(tester, onChanged: (_) {});

    expect(find.text('Fills a request'), findsOneWidget);
    expect(find.text('Optional. Pick the request this wall answers.'), findsOneWidget);
    expect(find.byTooltip('Remove request'), findsNothing);
  });

  testWidgets('tapping the row opens the picker and reports the picked request', (tester) async {
    final List<WallRequest?> changes = <WallRequest?>[];
    final WallRequest picked = _request();
    var pickCalls = 0;

    await pumpRow(
      tester,
      onChanged: changes.add,
      pick: (_) async {
        pickCalls++;
        return picked;
      },
    );
    await tester.tap(find.text('Fills a request'));
    await tester.pumpAndSettle();

    expect(pickCalls, 1);
    expect(changes, <WallRequest?>[picked]);
  });

  testWidgets('a cancelled picker reports nothing', (tester) async {
    final List<WallRequest?> changes = <WallRequest?>[];

    await pumpRow(tester, onChanged: changes.add, pick: (_) async => null);
    await tester.tap(find.text('Fills a request'));
    await tester.pumpAndSettle();

    expect(changes, isEmpty);
  });

  testWidgets('with a request set it shows the text and a clear button that reports null', (tester) async {
    final List<WallRequest?> changes = <WallRequest?>[];

    await pumpRow(tester, requestText: 'Neon city at night', onChanged: changes.add);

    expect(find.text('Neon city at night'), findsOneWidget);
    expect(find.text('Optional. Pick the request this wall answers.'), findsNothing);
    await tester.tap(find.byTooltip('Remove request'));
    await tester.pump();

    expect(changes, <WallRequest?>[null]);
  });
}
