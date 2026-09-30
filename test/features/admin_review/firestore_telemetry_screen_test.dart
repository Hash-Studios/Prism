import 'dart:io';

import 'package:Prism/core/firestore/firestore_telemetry.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/views/pages/firestore_telemetry_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const String _longPath = 'usersv2/E7s2lJWVsuYSipV4Rm7OJ5qsK6i1/images';

String _line(String op, String collection, {int? count, String tag = 'test.tag'}) =>
    '{"operation":"$op","collection":"$collection","sourceTag":"$tag"${count == null ? '' : ',"resultCount":$count'}}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('telemetry_test');
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => dir.path,
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      dir.deleteSync(recursive: true);
    });
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
          home: const FirestoreTelemetryScreen(),
        ),
      );
      expect(find.byType(PrismSkeleton), findsOneWidget);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
    });
  }

  testWidgets('shows Glint when no telemetry was recorded', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Firestore telemetry'), findsOneWidget);
    expect(find.byType(GlintState), findsOneWidget);
    expect(find.text('No telemetry yet'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
  });

  testWidgets('summarises events and lists collections with shortened paths', (tester) async {
    File('${dir.path}/$firestoreTelemetryFileName').writeAsStringSync(
      <String>[
        _line('queryGet', 'walls', count: 10),
        _line('queryGet', 'walls', count: 5),
        _line('set', 'walls'),
        _line('docGet', _longPath, count: 1, tag: 'profile.images'),
      ].join('\n'),
    );
    await pumpScreen(tester);

    expect(find.text('Total events'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
    expect(find.text('walls'), findsOneWidget);
    expect(find.text('15 reads · 1 write · 3 ops'), findsOneWidget);
    expect(find.text('1 read · 0 writes · 1 op'), findsOneWidget);
    expect(find.textContaining('…'), findsOneWidget);
    expect(find.widgetWithText(PrismButton, 'Copy all data'), findsOneWidget);
    expect(find.text('By operation'), findsOneWidget);
  });
}
