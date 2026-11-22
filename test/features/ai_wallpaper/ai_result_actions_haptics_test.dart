import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_result_actions.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final haptics = <Object?>[];

  setUp(() {
    haptics.clear();
    PrismHaptics.enabled = true;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
      return null;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('prism/haptics'), (call) async {
      haptics.add(call.arguments);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(const MethodChannel('prism/haptics'), null);
  });

  testWidgets('save defers feedback to its outcome while other icons play one tap', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AiResultActions(
            showSave: true,
            showRefine: true,
            canSubmit: true,
            sharing: false,
            applying: false,
            onApply: () => calls.add('apply'),
            onSave: () => calls.add('save'),
            onShare: () => calls.add('share'),
            onRefine: () => calls.add('refine'),
            onSubmit: () => calls.add('submit'),
            onReport: () => calls.add('report'),
          ),
        ),
      ),
    );
    for (final tooltip in <String>['Save', 'Share', 'Submit for community review', 'Try another']) {
      haptics.clear();
      await tester.tap(find.byTooltip(tooltip));
      await tester.pump();
      expect(haptics, hasLength(tooltip == 'Save' ? 0 : 1), reason: tooltip);
    }
    // Report opens the report sheet, which plays its own tap.
    haptics.clear();
    await tester.tap(find.byTooltip('Report'));
    await tester.pump();
    expect(haptics, isEmpty);
    expect(calls, <String>['save', 'share', 'submit', 'refine', 'report']);
  });

  for (final bool showSave in <bool>[false, true]) {
    testWidgets('narrow large-text actions fit with showSave=$showSave', (tester) async {
      tester.view.physicalSize = const Size(240, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: AiResultActions(
              showSave: showSave,
              showRefine: true,
              canSubmit: true,
              sharing: false,
              applying: false,
              onApply: () {},
              onSave: () {},
              onShare: () {},
              onRefine: () {},
              onSubmit: () {},
              onReport: () {},
            ),
          ),
        ),
      );

      expect(find.byTooltip('Report'), findsOneWidget);
      expect(find.byTooltip('Share'), findsOneWidget);
      expect(find.byTooltip('Save'), showSave ? findsOneWidget : findsNothing);
      expect(find.text('Apply'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a long Apply label takes its own row instead of being cut off', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 358,
              child: AiResultActions(
                // iOS hides Save, which leaves four icons in the row.
                showSave: false,
                showRefine: true,
                canSubmit: true,
                sharing: false,
                applying: false,
                onApply: () {},
                onSave: () {},
                onShare: () {},
                onRefine: () {},
                onSubmit: () {},
                onReport: () {},
              ),
            ),
          ),
        ),
      ),
    );
    final Finder label = find.text('Übernehmen');
    expect(label, findsOneWidget);
    expect(tester.renderObject<RenderParagraph>(label).didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Apply takes its own row when Android pads five icons to 48', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 420,
              child: AiResultActions(
                showSave: true,
                showRefine: true,
                canSubmit: true,
                sharing: false,
                applying: false,
                onApply: () {},
                onSave: () {},
                onShare: () {},
                onRefine: () {},
                onSubmit: () {},
                onReport: () {},
              ),
            ),
          ),
        ),
      ),
    );
    final Finder label = find.text('Apply');
    expect(tester.renderObject<RenderParagraph>(label).didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });
}
