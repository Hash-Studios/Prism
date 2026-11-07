import 'package:Prism/core/coins/economy_state.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/features/drops/biz/bloc/drops_bloc.j.dart';
import 'package:Prism/features/drops/views/widgets/drop_actions.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel hapticChannel = MethodChannel('prism/haptics');
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  final List<String> haptics = <String>[];

  setUp(() {
    haptics.clear();
    PrismHaptics.enabled = true;
    final TestDefaultBinaryMessengerBinding binding = TestDefaultBinaryMessengerBinding.instance;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, (_) async => true);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(hapticChannel, (MethodCall call) async {
      if (call.method == 'play') haptics.add(call.arguments as String);
      return null;
    });
  });

  tearDown(() {
    final TestDefaultBinaryMessengerBinding binding = TestDefaultBinaryMessengerBinding.instance;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(hapticChannel, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(toastChannel, null);
  });

  testWidgets('unlock and rename outcomes play exactly one outcome haptic each, from the toast', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );

    toastUnlockResult(context, const DropUnlockResult(DropUnlockOutcome.unlocked));
    toastUnlockResult(context, const DropUnlockResult(DropUnlockOutcome.insufficient));
    toastUnlockResult(context, const DropUnlockResult(DropUnlockOutcome.failed));
    toastRenameResult(context, DropRenameResult(ok: true));
    toastRenameResult(context, DropRenameResult(ok: false));
    await tester.pump();

    expect(haptics, <String>['success', 'error', 'error', 'success', 'error']);
    // Let the toasts time out so no timer outlives the test.
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
  });
}
