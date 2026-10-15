import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/profile/profile_completeness_evaluator.dart';
import 'package:Prism/core/router/not_found_page.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/profile_completeness/views/widgets/profile_completeness_nudge_sheet.dart';
import 'package:Prism/features/startup/biz/bloc/startup_bloc.j.dart';
import 'package:Prism/features/startup/views/pages/old_version_screen.dart';
import 'package:Prism/features/startup/views/pages/splash_widget.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/in_memory_local_store.dart';

class _MockStartupBloc extends MockBloc<StartupEvent, StartupState> implements StartupBloc {}

/// The text colour a [Text] ends up with, and the fill of the surface under it.
void _expectReadable(WidgetTester tester, Finder label, {required String reason}) {
  expect(label, findsOneWidget, reason: reason);
  final Color foreground = tester
      .widget<RichText>(find.descendant(of: label, matching: find.byType(RichText)))
      .text
      .style!
      .color!;
  final Color background = tester
      .widgetList<Material>(find.ancestor(of: label, matching: find.byType(Material)))
      .map((material) => material.color)
      .firstWhere((color) => color != null && color.a > 0)!;

  expect(
    contrastRatio(Color.alphaBlend(foreground, background), background),
    greaterThanOrEqualTo(4.5),
    reason: reason,
  );
}

void main() {
  final List<PrismThemeOption> lightThemes = prismLightThemes;

  setUp(() {
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
  });

  tearDown(getIt.reset);

  for (final PrismThemeOption option in lightThemes) {
    group(option.label, () {
      Widget app(Widget home) => MaterialApp(theme: option.theme, home: home);

      testWidgets('not found page text reads on the page', (tester) async {
        await tester.pumpWidget(app(const NotFoundPage()));

        _expectReadable(tester, find.text('Page not found'), reason: 'title');
        _expectReadable(tester, find.text('The link you opened is invalid or no longer available.'), reason: 'body');
      });

      testWidgets('startup failure text reads on the page', (tester) async {
        final bloc = _MockStartupBloc();
        when(() => bloc.state).thenReturn(StartupState.initial().copyWith(status: LoadStatus.failure));
        await tester.pumpWidget(app(BlocProvider<StartupBloc>.value(value: bloc, child: const SplashWidget())));

        _expectReadable(tester, find.text("Prism couldn't start"), reason: 'title');
        _expectReadable(tester, find.text('Check your connection and try again.'), reason: 'body');
      });

      testWidgets('obsolete version screen reads on the page and its button fits at 1.5x text', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: option.theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: OldVersion(),
          ),
        );

        _expectReadable(
          tester,
          find.descendant(of: find.byType(AppBar), matching: find.text('Update')),
          reason: 'title',
        );
        expect(find.widgetWithText(FilledButton, 'Update'), findsOneWidget);
        expect(tester.takeException(), isNull);
        _expectReadable(tester, find.textContaining('is obsolete and no longer supported'), reason: 'body');
      });

      testWidgets('profile nudge sheet text reads on the sheet', (tester) async {
        const status = ProfileCompletenessStatus(
          missingSteps: <ProfileCompletenessStep>[ProfileCompletenessStep.bio, ProfileCompletenessStep.socialLink],
        );
        await tester.pumpWidget(
          app(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showProfileCompletenessNudgeSheet(context, status: status),
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        _expectReadable(
          tester,
          find.text('You are 50% complete. Add the remaining details to unlock your reward.'),
          reason: 'body',
        );
        for (final ProfileCompletenessStep step in status.missingSteps) {
          _expectReadable(tester, find.text(step.label), reason: 'step ${step.name}');
        }
        _expectReadable(tester, find.textContaining('Complete your profile to earn'), reason: 'title');
      });
    });
  }
}
