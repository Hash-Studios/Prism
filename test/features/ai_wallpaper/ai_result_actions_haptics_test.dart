import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_result_actions.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
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

  testWidgets('each icon action plays exactly one haptic and calls its handler', (tester) async {
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
          ),
        ),
      ),
    );
    for (final tooltip in <String>['Save', 'Share', 'Submit for community review', 'Try another']) {
      haptics.clear();
      await tester.tap(find.byTooltip(tooltip));
      await tester.pump();
      expect(haptics, hasLength(1), reason: tooltip);
    }
    expect(calls, <String>['save', 'share', 'submit', 'refine']);
  });
}
