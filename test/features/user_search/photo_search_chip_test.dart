import 'dart:convert';
import 'dart:typed_data';

import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/features/user_search/domain/entities/photo_query.dart';
import 'package:Prism/features/user_search/views/widgets/photo_search_chip.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final AppLocalizationsEn en = AppLocalizationsEn();

Uint8List _preview() =>
    base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

PhotoQuery _photo({
  PhotoLabelsStatus status = PhotoLabelsStatus.found,
  List<String> labels = const <String>['Sunset', 'Sky', 'Cloud', 'Evening'],
  List<PaletteShare>? palette,
}) => PhotoQuery(
  preview: _preview(),
  palette: palette ?? <PaletteShare>[(color: paletteColorById('orange')!, share: 1.0)],
  labels: labels,
  labelsStatus: status,
);

Future<void> _pumpChip(
  WidgetTester tester,
  PhotoQuery photo, {
  VoidCallback? onClear,
  double textScale = 1.0,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: PhotoSearchChip(photo: photo, onClear: onClear ?? () {}),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows labels, colour dots semantics, and calls onClear', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    int cleared = 0;
    await _pumpChip(
      tester,
      _photo(
        palette: <PaletteShare>[
          (color: paletteColorById('orange')!, share: 0.6),
          (color: paletteColorById('blue')!, share: 0.4),
        ],
      ),
      onClear: () {
        cleared++;
      },
    );

    expect(find.text('Matches for sunset, sky, cloud'), findsOneWidget);
    expect(find.bySemanticsLabel('Main colours: Orange, Blue'), findsOneWidget);
    expect(find.bySemanticsLabel('Your photo'), findsOneWidget);
    expect(find.bySemanticsLabel('Clear photo'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pump();

    expect(cleared, 1);
    handle.dispose();
  });

  testWidgets('a found photo shows the sent note', (tester) async {
    await _pumpChip(tester, _photo());

    expect(find.text(en.searchPhotoSentNote), findsOneWidget);
  });

  testWidgets('a guest photo shows the guest note', (tester) async {
    await _pumpChip(tester, _photo(status: PhotoLabelsStatus.guest, labels: const <String>[]));

    expect(find.text(en.searchPhotoGuestNote), findsOneWidget);
  });

  testWidgets('a capped photo shows the daily limit note', (tester) async {
    await _pumpChip(tester, _photo(status: PhotoLabelsStatus.capped, labels: const <String>[]));

    expect(find.text(en.searchPhotoCappedNote(20)), findsOneWidget);
  });

  testWidgets('an unavailable photo shows the unavailable note', (tester) async {
    await _pumpChip(tester, _photo(status: PhotoLabelsStatus.unavailable, labels: const <String>[]));

    expect(find.text(en.searchPhotoUnavailableNote), findsOneWidget);
  });

  testWidgets('large text at 2x wraps without overflow', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpChip(tester, _photo(), textScale: 2.0);

    expect(tester.takeException(), isNull);
    expect(find.text(en.searchPhotoSentNote), findsOneWidget);
  });

  testWidgets('dark theme renders', (tester) async {
    await _pumpChip(
      tester,
      _photo(status: PhotoLabelsStatus.guest, labels: const <String>[]),
      theme: ThemeData.dark(),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(en.searchPhotoGuestNote), findsOneWidget);
  });
}
