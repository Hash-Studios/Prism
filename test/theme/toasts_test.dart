import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(toastChannel, (call) async {
      calls.add(call);
      return true;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(toastChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Map<Object?, Object?> shown() => calls.lastWhere((call) => call.method == 'showToast').arguments as Map;

  double contrast(Color a, Color b) {
    final double hi = a.computeLuminance() > b.computeLuminance() ? a.computeLuminance() : b.computeLuminance();
    final double lo = a.computeLuminance() > b.computeLuminance() ? b.computeLuminance() : a.computeLuminance();
    return (hi + 0.05) / (lo + 0.05);
  }

  test('a new toast cancels the one on screen first', () async {
    toasts.success('One');
    await Future<void>.delayed(Duration.zero);

    expect(calls.map((call) => call.method), <String>['cancel', 'showToast']);
    expect(shown()['msg'], 'One');
  });

  test('success and error toasts keep white text at 4.5:1 or better', () async {
    toasts.success('Saved', haptic: false);
    await Future<void>.delayed(Duration.zero);
    final Map<Object?, Object?> success = shown();
    toasts.error('Failed', haptic: false);
    await Future<void>.delayed(Duration.zero);
    final Map<Object?, Object?> error = shown();

    for (final Map<Object?, Object?> toast in <Map<Object?, Object?>>[success, error]) {
      expect(
        contrast(Color(toast['textcolor']! as int), Color(toast['bgcolor']! as int)),
        greaterThanOrEqualTo(4.5),
        reason: '${toast['msg']}',
      );
    }
  });

  test('info toast is neutral and readable', () async {
    toasts.info('Heads up');
    await Future<void>.delayed(Duration.zero);

    final Map<Object?, Object?> toast = shown();
    expect(toast['msg'], 'Heads up');
    expect(contrast(Color(toast['textcolor']! as int), Color(toast['bgcolor']! as int)), greaterThanOrEqualTo(4.5));
  });
}
