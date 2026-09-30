import 'package:Prism/data/upload/wallpaper/setup_submission.dart';
import 'package:Prism/features/setups/views/widgets/setup_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  bool busy = false,
  bool isEdit = false,
  SetupDetails initial = const SetupDetails(),
  ValueChanged<SetupDetails>? onPost,
  ValueChanged<SetupDetails>? onSaveDraft,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SetupForm(
        isEdit: isEdit,
        busy: busy,
        initial: initial,
        preview: const SizedBox(),
        onPreviewTap: () {},
        onPost: onPost ?? (_) {},
        onSaveDraft: onSaveDraft,
      ),
    ),
  );
  // The avatar image cannot load from the test network.
  tester.takeException();
}

const SetupDetails _complete = SetupDetails(
  setupName: 'Dusk',
  setupDesc: 'Warm and calm',
  iconName: 'Lawnicons',
  iconUrl: 'https://icons.app',
  wallpaper: LinkWallpaper('https://example.com/w.jpg'),
);

void main() {
  testWidgets('post with missing fields does not submit', (tester) async {
    final List<SetupDetails> posted = <SetupDetails>[];
    await _pump(tester, onPost: posted.add);

    await tester.tap(find.text('Post'));
    await tester.pump();

    expect(posted, isEmpty);
  });

  testWidgets('post submits the initial details', (tester) async {
    final List<SetupDetails> posted = <SetupDetails>[];
    await _pump(tester, initial: _complete, onPost: posted.add);

    await tester.tap(find.text('Post'));
    await tester.pump();

    expect(posted, hasLength(1));
    expect(posted.single.setupName, 'Dusk');
    expect(posted.single.iconUrl, 'https://icons.app');
    expect(posted.single.wallpaper, isA<LinkWallpaper>());
    expect((posted.single.wallpaper as LinkWallpaper).url, 'https://example.com/w.jpg');
  });

  testWidgets('an app wallpaper with name and link wins over the link field', (tester) async {
    final List<SetupDetails> posted = <SetupDetails>[];
    await _pump(
      tester,
      initial: SetupDetails(
        setupName: _complete.setupName,
        setupDesc: _complete.setupDesc,
        iconName: _complete.iconName,
        iconUrl: _complete.iconUrl,
        wallpaper: const AppWallpaper(appName: 'Walli', link: 'https://walli.app', wallName: 'Dusk'),
      ),
      onPost: posted.add,
    );

    await tester.tap(find.text('Post'));
    await tester.pump();

    expect(posted.single.wallpaper, isA<AppWallpaper>());
    expect(posted.single.wallpaper.firestoreValue, <String>['Walli', 'https://walli.app', 'Dusk']);
  });

  testWidgets('an uploaded wallpaper keeps its wall id', (tester) async {
    final List<SetupDetails> posted = <SetupDetails>[];
    await _pump(
      tester,
      isEdit: true,
      initial: SetupDetails(
        setupName: _complete.setupName,
        setupDesc: _complete.setupDesc,
        iconName: _complete.iconName,
        iconUrl: _complete.iconUrl,
        wallpaper: const UploadedWallpaper(url: 'https://example.com/w.jpg', id: 'AB1C'),
      ),
      onPost: posted.add,
    );

    await tester.tap(find.text('Post'));
    await tester.pump();

    expect(posted.single.wallpaper.wallId, 'AB1C');
  });

  testWidgets('post and save are disabled while busy', (tester) async {
    final List<SetupDetails> posted = <SetupDetails>[];
    final List<SetupDetails> drafts = <SetupDetails>[];
    await _pump(tester, busy: true, initial: _complete, onPost: posted.add, onSaveDraft: drafts.add);

    await tester.tap(find.text('Post'));
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(posted, isEmpty);
    expect(drafts, isEmpty);
  });

  testWidgets('save draft skips validation', (tester) async {
    final List<SetupDetails> drafts = <SetupDetails>[];
    await _pump(tester, onSaveDraft: drafts.add);

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(drafts, hasLength(1));
    expect(drafts.single.setupName, isEmpty);
  });

  testWidgets('edit form has no draft button and its own title', (tester) async {
    await _pump(tester, isEdit: true);

    expect(find.text('Edit Setup'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('typed fields reach the submitted details', (tester) async {
    final List<SetupDetails> posted = <SetupDetails>[];
    await _pump(tester, initial: _complete, onPost: posted.add);

    await tester.enterText(find.byType(TextField).first, 'Night');
    await tester.tap(find.text('Post'));
    await tester.pump();

    expect(posted.single.setupName, 'Night');
  });
}
