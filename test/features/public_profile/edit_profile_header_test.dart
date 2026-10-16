import 'package:Prism/features/public_profile/views/widgets/edit_profile_header.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  int coverTaps = 0;
  int removeTaps = 0;

  setUp(() {
    coverTaps = 0;
    removeTaps = 0;
  });

  Future<void> pumpHeader(WidgetTester tester, {String? coverUrl}) async {
    await tester.pumpWidget(
      MaterialApp(
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
              onChangePhoto: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('the change cover control is the current one: a camera and "Edit cover" on a fade over the cover', (
    tester,
  ) async {
    await pumpHeader(tester);

    final Finder hint = find.ancestor(of: find.text('Edit cover'), matching: find.byType(IgnorePointer)).first;
    expect(find.byIcon(JamIcons.camera), findsOneWidget);
    expect(find.text('Edit cover'), findsOneWidget);
    // The hint is a full-width strip along the bottom of the cover, centred, and not a pill.
    final Rect cover = tester.getRect(find.byKey(EditProfileHeader.changeCoverKey));
    final Rect strip = tester.getRect(hint);
    expect(strip.width, cover.width);
    expect(strip.height, 52);
    expect(strip.bottom, cover.bottom);
    expect(tester.getCenter(find.text('Edit cover')).dx, closeTo(cover.center.dx + 11, 12));
    final BoxDecoration fade =
        tester.widget<Container>(find.descendant(of: hint, matching: find.byType(Container)).first).decoration!
            as BoxDecoration;
    expect(fade.gradient, isA<LinearGradient>());
    expect(fade.borderRadius, isNull);
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
}
