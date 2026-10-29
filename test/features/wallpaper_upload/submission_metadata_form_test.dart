import 'package:Prism/features/wallpaper_upload/biz/submission_metadata.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/submission_metadata_form.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    GlobalKey<SubmissionMetadataFormState> key,
    ValueChanged<SubmissionMetadata> changed, {
    bool approved = false,
  }) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SubmissionMetadataForm(
              key: key,
              showCategory: !approved,
              initial: const SubmissionMetadata(
                title: 'Keep title',
                description: 'Keep description',
                requestId: 'request',
                requestText: 'Keep request',
              ),
              onChanged: changed,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('saving commits an unsent tag and keeps description and request context', (tester) async {
    final key = GlobalKey<SubmissionMetadataFormState>();
    SubmissionMetadata? value;
    await pump(tester, key, (next) => value = next);
    await tester.enterText(find.widgetWithText(TextField, 'Tags'), 'Evening');
    expect(key.currentState!.flush(), isTrue);
    await tester.pump();
    expect(value!.tags, ['evening']);
    expect(value!.description, 'Keep description');
    expect(value!.requestId, 'request');
  });

  testWidgets('last details copies category and tags without replacing text or linkage', (tester) async {
    final key = GlobalKey<SubmissionMetadataFormState>();
    SubmissionMetadata? value;
    await pump(tester, key, (next) => value = next);
    key.currentState!.useDetails(category: 'Nature', tags: ['forest']);
    await tester.pump();
    expect(value!.title, 'Keep title');
    expect(value!.description, 'Keep description');
    expect(value!.requestId, 'request');
    expect(value!.category, 'Nature');
    expect(value!.tags, ['forest']);
    expect(find.widgetWithText(InputChip, 'forest'), findsOneWidget);
  });

  testWidgets('approved mode exposes only text fields and reports unsafe input inline', (tester) async {
    final key = GlobalKey<SubmissionMetadataFormState>();
    await pump(tester, key, (_) {}, approved: true);
    expect(find.byType(ChoiceChip), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'n5fw porn');
    expect(key.currentState!.flush(), isFalse);
    await tester.pump();
    expect(find.textContaining('Check the'), findsOneWidget);
  });
}
