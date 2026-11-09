import 'package:Prism/features/wallpaper_upload/views/widgets/release_time_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _now = DateTime(2026, 11, 14, 10, 3);

Future<void> _pump(
  WidgetTester tester,
  ReleaseTimeRow row, {
  ThemeData? theme,
  double textScale = 1,
  bool narrow = false,
}) async {
  tester.view.physicalSize = narrow ? const Size(320, 800) : const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: theme,
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(padding: const EdgeInsets.all(16), child: row),
            ),
          ),
        ),
      ),
    ),
  );
}

Finder _textStartingWith(String prefix) =>
    find.byWidgetPredicate((Widget widget) => widget is Text && (widget.data ?? '').startsWith(prefix));

void main() {
  testWidgets('with no time set shows the segments and the when-approved help, and no date or time buttons', (
    tester,
  ) async {
    await _pump(tester, ReleaseTimeRow(releaseAt: null, onChanged: (_) {}, now: () => _now));

    expect(find.text('Release'), findsOneWidget);
    expect(find.text('When approved'), findsOneWidget);
    expect(find.text('At a set time'), findsOneWidget);
    expect(find.text('Goes live as soon as a moderator approves it.'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Release date: ')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('^Release time: ')), findsNothing);
  });

  testWidgets('tapping at a set time picks the next whole hour at least 20 minutes ahead', (tester) async {
    DateTime? picked;
    var calls = 0;
    await _pump(
      tester,
      ReleaseTimeRow(
        releaseAt: null,
        now: () => _now,
        onChanged: (DateTime? value) {
          calls++;
          picked = value;
        },
      ),
    );

    await tester.tap(find.text('At a set time'));
    await tester.pump();

    expect(calls, 1);
    expect(picked, DateTime(2026, 11, 14, 11).toUtc());
  });

  testWidgets('with a time set shows date and time buttons and the time zone line', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pump(
      tester,
      ReleaseTimeRow(releaseAt: DateTime(2026, 11, 15, 18).toUtc(), onChanged: (_) {}, now: () => _now),
    );

    expect(find.bySemanticsLabel(RegExp('^Release date: ')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Release time: ')), findsOneWidget);
    final Text zone = tester.widget<Text>(_textStartingWith('Times use your time zone ('));
    expect(zone.data, anyOf(contains('UTC+'), contains('UTC-')));
    semantics.dispose();
  });

  testWidgets('shows the too-soon problem for a time less than 15 minutes away', (tester) async {
    await _pump(
      tester,
      ReleaseTimeRow(releaseAt: _now.add(const Duration(minutes: 5)).toUtc(), onChanged: (_) {}, now: () => _now),
    );

    expect(find.text('Choose a time at least 15 minutes from now.'), findsOneWidget);
    expect(find.text('Choose a time within the next 30 days.'), findsNothing);
  });

  testWidgets('shows the too-late problem for a time more than 30 days away', (tester) async {
    await _pump(
      tester,
      ReleaseTimeRow(releaseAt: _now.add(const Duration(days: 40)).toUtc(), onChanged: (_) {}, now: () => _now),
    );

    expect(find.text('Choose a time within the next 30 days.'), findsOneWidget);
    expect(find.text('Choose a time at least 15 minutes from now.'), findsNothing);
  });

  testWidgets('allowWhenApproved false hides the when-approved segment', (tester) async {
    await _pump(
      tester,
      ReleaseTimeRow(
        releaseAt: DateTime(2026, 11, 15, 18).toUtc(),
        onChanged: (_) {},
        allowWhenApproved: false,
        now: () => _now,
      ),
    );

    expect(find.text('When approved'), findsNothing);
  });

  testWidgets('disabled row does not call onChanged when a segment is tapped', (tester) async {
    var calls = 0;
    await _pump(tester, ReleaseTimeRow(releaseAt: null, enabled: false, now: () => _now, onChanged: (_) => calls++));

    await tester.tap(find.text('At a set time'));
    await tester.pump();

    expect(calls, 0);
  });

  testWidgets('large text at 320 px keeps the date and time buttons and does not overflow', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pump(
      tester,
      ReleaseTimeRow(releaseAt: _now.add(const Duration(days: 2)).toUtc(), onChanged: (_) {}, now: () => _now),
      textScale: 2,
      narrow: true,
    );

    expect(find.bySemanticsLabel(RegExp('^Release date: ')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Release time: ')), findsOneWidget);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
