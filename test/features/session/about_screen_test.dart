import 'package:Prism/features/session/views/pages/about_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:github/github.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  final List<String> copied = <String>[];

  setUp(() {
    copied.clear();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(toastChannel, (call) async => true);
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map<Object?, Object?>)['text']! as String);
      }
      return null;
    });
  });

  tearDown(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(toastChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpAbout(WidgetTester tester, Future<List<Contributor>> Function() loader) async {
    tester.view.physicalSize = const Size(1000, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: AboutScreen(loadContributors: loader)));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('shows the brand, links, team, contributors and more', (tester) async {
    await pumpAbout(
      tester,
      () async => <Contributor>[
        Contributor(login: 'ada', contributions: 120),
        Contributor(login: 'grace', contributions: 80),
        Contributor(login: 'linus', contributions: 1),
        Contributor(login: 'extra', contributions: 7),
      ],
    );

    expect(find.text('About'), findsOneWidget);
    expect(find.text('Prism'), findsOneWidget);
    for (final String chip in <String>['GitHub', 'Rate Prism', 'X', 'Instagram', 'Telegram']) {
      expect(find.text(chip), findsOneWidget, reason: chip);
    }
    expect(find.text('Team'), findsOneWidget);
    expect(find.text('ada'), findsOneWidget);
    expect(find.text('120 commits'), findsOneWidget);
    expect(find.text('1 commit'), findsOneWidget);
    expect(find.text('Contributors'), findsOneWidget);
    expect(find.text('extra'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text("What's new"), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Wallpaper sources'), findsOneWidget);
    expect(find.text('Made in India with Flutter'), findsOneWidget);
  });

  testWidgets('a failed team load offers a retry', (tester) async {
    int calls = 0;
    await pumpAbout(tester, () async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return <Contributor>[Contributor(login: 'ada', contributions: 3)];
    });

    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ada'), findsOneWidget);
  });

  testWidgets('tapping the version copies it', (tester) async {
    await pumpAbout(tester, () async => <Contributor>[]);

    await tester.tap(find.textContaining('Version '));
    await tester.pump();

    expect(copied, hasLength(1));
    expect(copied.single, contains('+'));
  });

  testWidgets('wallpaper sources opens a sheet with the API links', (tester) async {
    await pumpAbout(tester, () async => <Contributor>[]);

    await tester.tap(find.text('Wallpaper sources'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('WallHaven API'), findsOneWidget);
    expect(find.text('Pexels API'), findsOneWidget);
  });
}
