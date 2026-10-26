import 'package:Prism/features/theme_mode/views/widgets/custom_accent_sheet.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Host {
  Color? result;
  bool closed = false;
}

void main() {
  final AppLocalizationsEn en = AppLocalizationsEn();

  Future<_Host> pumpHost(WidgetTester tester, {Color surface = Colors.white}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final _Host host = _Host();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  host.result = await showCustomAccentSheet(
                    context,
                    initial: const Color(0xFFE57697),
                    surface: surface,
                  );
                  host.closed = true;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return host;
  }

  String fieldText(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).controller!.text;

  bool applyEnabled(WidgetTester tester) =>
      tester
          .widget<FilledButton>(find.ancestor(of: find.text('Use color'), matching: find.byType(FilledButton)))
          .onPressed !=
      null;

  testWidgets('entering a valid hex and tapping Use color returns that colour', (tester) async {
    final _Host host = await pumpHost(tester);

    await tester.enterText(find.byType(TextField), '#1976D2');
    await tester.pump();
    await tester.tap(find.text('Use color'));
    await tester.pumpAndSettle();

    expect(host.result, const Color(0xFF1976D2));
    expect(host.closed, isTrue);
  });

  testWidgets('an invalid hex shows the message and Use color does not close the sheet', (tester) async {
    final _Host host = await pumpHost(tester);

    await tester.enterText(find.byType(TextField), '#12');
    await tester.pump();
    expect(find.text(en.coreCustomAccentInvalidHex), findsOneWidget);
    expect(applyEnabled(tester), isFalse);

    await tester.tap(find.text('Use color'));
    await tester.pumpAndSettle();

    expect(host.result, isNull);
    expect(host.closed, isFalse);
    expect(find.text('Use color'), findsOneWidget);
  });

  testWidgets('a colour too close to the surface shows the low contrast message and disables Use color', (
    tester,
  ) async {
    await pumpHost(tester);

    await tester.enterText(find.byType(TextField), '#FAFAFA');
    await tester.pump();

    expect(find.text(en.coreCustomAccentLowContrast), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(applyEnabled(tester), isFalse);
  });

  testWidgets('dragging the lightness slider to its end writes white into the hex field', (tester) async {
    await pumpHost(tester);

    await tester.drag(find.byType(Slider).at(2), const Offset(2000, 0));
    await tester.pumpAndSettle();

    expect(fieldText(tester), '#FFFFFF');
  });
}
