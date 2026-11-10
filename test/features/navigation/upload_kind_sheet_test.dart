import 'package:Prism/core/wallpaper/wall_live.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/upload_kind_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() {
    l10n = lookupAppLocalizations(const Locale('en'));
  });

  Future<void> pumpOpener(WidgetTester tester, {required void Function(WallKind?) onResult, double textScale = 1}) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => onResult(await showUploadKindSheet(context)),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the sheet offers Photo and Live', (tester) async {
    await pumpOpener(tester, onResult: (_) {});
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.uploadKindTitle), findsOneWidget);
    expect(find.text(l10n.uploadKindPhoto), findsOneWidget);
    expect(find.text(l10n.uploadKindPhotoBody), findsOneWidget);
    expect(find.text(l10n.uploadKindLive), findsOneWidget);
    expect(find.text(l10n.uploadKindLiveBody), findsOneWidget);
  });

  testWidgets('tapping Live pops WallKind.live', (tester) async {
    WallKind? result;
    await pumpOpener(tester, onResult: (value) => result = value);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.uploadKindLive));
    await tester.pumpAndSettle();

    expect(result, WallKind.live);
    expect(find.text(l10n.uploadKindTitle), findsNothing);
  });

  testWidgets('tapping Photo pops WallKind.still', (tester) async {
    WallKind? result;
    await pumpOpener(tester, onResult: (value) => result = value);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.uploadKindPhoto));
    await tester.pumpAndSettle();

    expect(result, WallKind.still);
  });

  testWidgets('at 2.0 text scale the sheet shows both rows without overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpOpener(tester, onResult: (_) {}, textScale: 2);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.uploadKindLive), findsOneWidget);
    expect(find.text(l10n.uploadKindLiveBody), findsOneWidget);
  });
}
