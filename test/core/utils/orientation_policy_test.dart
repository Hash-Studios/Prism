import 'package:Prism/core/utils/orientation_policy.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phones stay in portrait', () {
    for (final Size size in const <Size>[Size(320, 568), Size(393, 852), Size(440, 956), Size(599, 900)]) {
      expect(allowedOrientations(size), const <DeviceOrientation>[DeviceOrientation.portraitUp], reason: '$size');
    }
  });

  test('tablets turn in either orientation', () {
    for (final Size size in const <Size>[Size(744, 1133), Size(1032, 1376), Size(1376, 1032), Size(1280, 800)]) {
      expect(allowedOrientations(size), isEmpty, reason: '$size');
    }
  });

  test('a phone held sideways is still a phone', () {
    expect(allowedOrientations(const Size(852, 393)), const <DeviceOrientation>[DeviceOrientation.portraitUp]);
  });

  testWidgets('applies orientation from display metrics across startup, letterboxing, and folding', (tester) async {
    final List<Object?> calls = <Object?>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        calls.add(call.arguments);
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    addTearDown(() {
      tester.view.reset();
      tester.view.display.reset();
    });

    tester.view.physicalSize = Size.zero;
    tester.view.devicePixelRatio = 2;
    tester.view.display.size = Size.zero;
    tester.view.display.devicePixelRatio = 2;
    await applyAllowedOrientations(view: tester.view);
    expect(calls, isEmpty, reason: 'missing startup metrics must not lock the app to portrait');

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.display.size = const Size(800, 1600);
    await applyAllowedOrientations(view: tester.view);
    expect(calls, <Object?>[
      <String>['DeviceOrientation.portraitUp'],
    ]);

    tester.view.physicalSize = const Size(900, 1600);
    tester.view.display.size = const Size(1600, 2560);
    await applyAllowedOrientations(view: tester.view);
    expect(calls, <Object?>[
      <String>['DeviceOrientation.portraitUp'],
      <String>[],
    ], reason: 'a letterboxed view on a tablet must not keep the phone portrait lock');

    await applyAllowedOrientations(view: tester.view);
    expect(calls, hasLength(2), reason: 'unchanged display metrics must not resend the orientation policy');

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.display.size = const Size(800, 1600);
    await applyAllowedOrientations(view: tester.view);
    expect(calls, <Object?>[
      <String>['DeviceOrientation.portraitUp'],
      <String>[],
      <String>['DeviceOrientation.portraitUp'],
    ], reason: 'a folded display that becomes phone-sized must restore portrait');
  });

  testWidgets('retries orientation request after platform failure', (tester) async {
    final List<Object?> calls = <Object?>[];
    bool failNextCall = false;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        calls.add(call.arguments);
        if (failNextCall) {
          failNextCall = false;
          throw PlatformException(code: 'test_failure');
        }
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    addTearDown(() {
      tester.view.reset();
      tester.view.display.reset();
    });

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    tester.view.display.size = const Size(800, 1600);
    tester.view.display.devicePixelRatio = 2;
    await applyAllowedOrientations(view: tester.view);
    tester.view.display.size = const Size(1600, 2560);
    await applyAllowedOrientations(view: tester.view);
    tester.view.display.size = const Size(800, 1600);
    await applyAllowedOrientations(view: tester.view);
    final int callCount = calls.length;

    tester.view.display.size = const Size(1600, 2560);
    failNextCall = true;
    await expectLater(applyAllowedOrientations(view: tester.view), throwsA(isA<PlatformException>()));
    await applyAllowedOrientations(view: tester.view);

    expect(calls, hasLength(callCount + 2));
    expect(calls.sublist(callCount), <Object?>[<String>[], <String>[]]);
  });

  testWidgets('observer applies current metrics on start and stops after dispose', (tester) async {
    final List<Object?> calls = <Object?>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') calls.add(call.arguments);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    addTearDown(() {
      tester.view.reset();
      tester.view.display.reset();
    });

    tester.view.devicePixelRatio = 2;
    tester.view.display.devicePixelRatio = 2;
    tester.view.display.size = const Size(1600, 2560);
    await applyAllowedOrientations(view: tester.view);

    tester.view.physicalSize = Size.zero;
    tester.view.display.size = Size.zero;
    await applyAllowedOrientations(view: tester.view);
    final int beforeMissingMetrics = calls.length;

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.display.size = const Size(800, 1600);
    expect(calls, hasLength(beforeMissingMetrics), reason: 'no observer is installed during the startup gap');

    final OrientationPolicyObserver observer = OrientationPolicyObserver(view: tester.view);
    addTearDown(observer.dispose);
    await observer.start();
    expect(calls.last, <String>['DeviceOrientation.portraitUp']);

    tester.view.display.size = const Size(1600, 2560);
    await tester.pump();
    expect(calls.last, <String>[], reason: 'the observer reapplies policy when display metrics change');

    observer.dispose();
    final int beforeDisposeResize = calls.length;
    tester.view.display.size = const Size(800, 1600);
    await tester.pump();
    expect(calls, hasLength(beforeDisposeResize), reason: 'disposed observers do not send orientation requests');
  });

  testWidgets('uses the window size when the platform reports no display size, as Android does', (tester) async {
    final List<Object?> calls = <Object?>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') calls.add(call.arguments);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    addTearDown(() {
      tester.view.reset();
      tester.view.display.reset();
    });

    tester.view.display.size = Size.zero;
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(2560, 1600);
    await applyAllowedOrientations(view: tester.view);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1206, 2622);
    await applyAllowedOrientations(view: tester.view);
    expect(calls.last, <String>['DeviceOrientation.portraitUp'], reason: 'an Android phone keeps the portrait lock');

    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(2560, 1600);
    await applyAllowedOrientations(view: tester.view);
    expect(calls.last, <String>[], reason: 'an Android tablet can turn');
  });
}
