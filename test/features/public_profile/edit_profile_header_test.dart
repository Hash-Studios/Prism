import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/public_profile/views/widgets/edit_profile_header.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  int coverTaps = 0;
  int removeTaps = 0;
  int photoTaps = 0;
  int removePhotoTaps = 0;

  setUp(() {
    coverTaps = 0;
    removeTaps = 0;
    photoTaps = 0;
    removePhotoTaps = 0;
  });

  Future<void> pumpHeader(WidgetTester tester, {String? coverUrl, bool canRemovePhoto = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: Scaffold(
          body: SingleChildScrollView(
            child: EditProfileHeader(
              coverUrl: coverUrl,
              coverFile: null,
              avatarUrl: '',
              avatarFile: null,
              name: 'Ana Rivera',
              onChangeCover: () => coverTaps++,
              onRemoveCover: () => removeTaps++,
              onChangePhoto: () => photoTaps++,
              onRemovePhoto: canRemovePhoto ? () => removePhotoTaps++ : null,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('"Edit cover" is a dark on-image pill at the bottom end of the cover, with no grey fade', (tester) async {
    await pumpHeader(tester);

    final Finder hint = find.ancestor(of: find.text('Edit cover'), matching: find.byType(IgnorePointer)).first;
    expect(find.byIcon(Icons.photo_camera_rounded), findsNWidgets(2));
    expect(find.text('Edit cover'), findsOneWidget);
    final Rect cover = tester.getRect(find.byKey(EditProfileHeader.changeCoverKey));
    final Rect pill = tester.getRect(hint);
    expect(pill.width, lessThan(cover.width / 2));
    expect(cover.right - pill.right, PrismSpace.xs);
    expect(cover.bottom - pill.bottom, PrismSpace.xs);
    final BoxDecoration fill =
        tester.widget<DecoratedBox>(find.descendant(of: hint, matching: find.byType(DecoratedBox)).first).decoration
            as BoxDecoration;
    expect(fill.gradient, isNull);
    expect(fill.color, Colors.black.withValues(alpha: 0.38));
    expect(fill.borderRadius, BorderRadius.circular(PrismRadius.pill));
    expect(tester.widget<Text>(find.text('Edit cover')).style!.color, Colors.white);
  });

  testWidgets('the whole cover is the tap target and is a labelled button', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpHeader(tester);

      expect(
        tester.getSemantics(find.byKey(EditProfileHeader.changeCoverKey)),
        matchesSemantics(label: 'Change cover photo', isButton: true, hasTapAction: true),
      );
      final Size cover = tester.getSize(find.byKey(EditProfileHeader.changeCoverKey));
      expect(cover.height, 140);
      await tester.tapAt(tester.getTopLeft(find.byKey(EditProfileHeader.changeCoverKey)) + const Offset(40, 20));
      expect(coverTaps, 1);
      await tester.tap(find.text('Edit cover'), warnIfMissed: false);
      expect(coverTaps, 2);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('the remove button stays the redesign icon button and does not open the picker', (tester) async {
    await pumpHeader(tester, coverUrl: 'https://example.test/cover.png');

    await tester.tap(find.byTooltip('Remove cover photo'));
    expect(removeTaps, 1);
    expect(coverTaps, 0);
  });

  testWidgets('"Remove photo" shows only when the photo can be removed', (tester) async {
    await pumpHeader(tester);
    expect(find.text('Remove photo'), findsNothing);

    await pumpHeader(tester, canRemovePhoto: true);
    expect(find.text('Remove photo'), findsOneWidget);
  });

  testWidgets('"Remove photo" sits next to the avatar and does not open the picker', (tester) async {
    await pumpHeader(tester, canRemovePhoto: true);

    final Rect avatar = tester.getRect(find.bySemanticsLabel('Change photo'));
    final Rect cover = tester.getRect(find.byKey(EditProfileHeader.changeCoverKey));
    expect(tester.getRect(find.widgetWithText(PrismButton, 'Remove photo')).left, greaterThan(avatar.right));
    expect(tester.getRect(find.text('Remove photo')).top, greaterThan(cover.bottom));

    await tester.tap(find.text('Remove photo'));
    expect(removePhotoTaps, 1);
    expect(photoTaps, 0);
  });
}
