import 'package:Prism/features/wrapped/biz/bloc/wrapped_bloc.j.dart';
import 'package:Prism/features/wrapped/views/widgets/wrapped_home_card.dart';
import 'package:Prism/features/wrapped/wrapped_config.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wrapped_fixture.dart';

void main() {
  tearDown(() {
    WrappedConfig.override = null;
  });

  test('shows the Home card only inside the window for the loaded owner', () {
    WrappedConfig.override = (enabled: true, start: DateTime(2026, 12), end: DateTime(2027, 1, 15));
    final WrappedState ready = WrappedState.ready('u1', fixtureWrappedYear());

    expect(wrappedForHome(ready, 'u1', DateTime(2026, 11, 30, 23)), isNull);
    expect(wrappedForHome(ready, 'u1', DateTime(2026, 12, 1, 0, 5)), isNotNull);
    expect(wrappedForHome(ready, 'u1', DateTime(2027, 1, 15, 22)), isNotNull);
    expect(wrappedForHome(ready, 'u1', DateTime(2027, 1, 16)), isNull);
  });

  test('hides the Home card when the flag is off, for another uid, or when not loaded', () {
    final WrappedState ready = WrappedState.ready('u1', fixtureWrappedYear());
    final DateTime inWindow = DateTime(2026, 12, 10);

    WrappedConfig.override = (enabled: false, start: DateTime(2026, 12), end: DateTime(2027, 1, 15));
    expect(wrappedForHome(ready, 'u1', inWindow), isNull);

    WrappedConfig.override = (enabled: true, start: DateTime(2026, 12), end: DateTime(2027, 1, 15));
    expect(wrappedForHome(ready, 'u2', inWindow), isNull);
    expect(wrappedForHome(const WrappedState.notEligible('u1'), 'u1', inWindow), isNull);
    expect(wrappedForHome(const WrappedState.loading('u1'), 'u1', inWindow), isNull);
  });

  testWidgets('renders the title and subtitle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: WrappedHomeCard(year: fixtureWrappedYear(), memCacheHeight: 200)),
      ),
    );

    expect(find.text('Your 2026 in Prism'), findsOneWidget);
    expect(find.text('Your year in walls is ready.'), findsOneWidget);
  });
}
