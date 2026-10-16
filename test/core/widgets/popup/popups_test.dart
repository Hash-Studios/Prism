import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/widgets/popup/changelog_pop_up.dart';
import 'package:Prism/core/widgets/popup/contri_pop_up.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_local_store.dart';

const String _cacheKey = 'remote_changelog_markdown_cache';

void main() {
  late SettingsLocalDataSource settings;

  setUp(() {
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
  });

  tearDown(getIt.reset);

  /// Opens a popup from a button and lets its sheet finish sliding in. Glint loops, so no `pumpAndSettle`.
  Future<void> open(WidgetTester tester, void Function(BuildContext) show) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: prismDarkThemes.first.theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(onPressed: () => show(context), child: const Text('open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('sign in sheet', () {
    testWidgets('asks to sign in with Glint, Google and a way out', (tester) async {
      await open(tester, (context) => googleSignInPopUp(context, () {}));

      expect(find.text('Sign in to Prism'), findsOneWidget);
      expect(find.text('Keep your favourites, uploads and coins on every device.'), findsOneWidget);
      expect(find.byType(Glint), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('Not now closes the sheet', (tester) async {
      await open(tester, (context) => googleSignInPopUp(context, () {}));

      await tester.tap(find.text('Not now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Sign in to Prism'), findsNothing);
    });
  });

  group('changelog sheet', () {
    const markdown = '### 3.1.0\n- Fix a crash on launch\n- Faster feed\n### 3.0.9\n- Improve download speed\n';

    testWidgets('lists each version with the newest tagged Latest', (tester) async {
      await settings.set(_cacheKey, markdown);
      await open(tester, showChangelog);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text("What's new"), findsOneWidget);
      expect(find.text('You are on version $currentAppVersion.'), findsOneWidget);
      expect(find.text('3.1.0'), findsOneWidget);
      expect(find.text('3.0.9'), findsOneWidget);
      expect(find.text('Latest'), findsOneWidget);
      expect(find.text('Fix a crash on launch'), findsOneWidget);
      expect(find.text('Improve download speed'), findsOneWidget);
      expect(find.text('See the full changelog'), findsOneWidget);
    });

    testWidgets('shows an error with a retry when nothing loads', (tester) async {
      await open(tester, showChangelog);

      expect(find.text('Could not load the changelog'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('runs the close callback when the sheet is dismissed', (tester) async {
      await settings.set(_cacheKey, markdown);
      var closed = 0;
      await open(tester, (context) => showChangelog(context, () => closed++));

      await tester.tapAt(const Offset(195, 40));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(closed, 1);
    });
  });

  group('contributor sheet', () {
    testWidgets('shows an error with a retry when the profile fails', (tester) async {
      await open(tester, (context) => showContributorDetails(context, 'octocat'));

      expect(find.text('Could not load this profile'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
