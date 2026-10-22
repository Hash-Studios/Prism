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

  testWidgets('an unfolded iPhone Duo can turn, though its display still reports the outer screen', (tester) async {
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

    tester.view.devicePixelRatio = 3;
    tester.view.display.devicePixelRatio = 3;
    tester.view.display.size = const Size(1398, 2034);
    tester.view.physicalSize = const Size(1398, 2034);
    await applyAllowedOrientations(view: tester.view);
    calls.clear();

    tester.view.physicalSize = const Size(2007, 2853);
    await applyAllowedOrientations(view: tester.view);
    expect(calls.last, <String>[], reason: 'the unfolded inner screen is tablet-sized');

    tester.view.physicalSize = const Size(1398, 2034);
    await applyAllowedOrientations(view: tester.view);
    expect(calls.last, <String>['DeviceOrientation.portraitUp'], reason: 'the folded outer screen is a phone');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('an iOS tablet keeps its display policy in split view and Stage Manager', (tester) async {
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
    tester.view.display.size = const Size(2048, 2732);
    tester.view.physicalSize = const Size(2048, 2732);
    await applyAllowedOrientations(view: tester.view);

    tester.view.display.size = const Size(800, 1200);
    tester.view.physicalSize = const Size(800, 1200);
    await applyAllowedOrientations(view: tester.view);
    expect(calls.last, <String>['DeviceOrientation.portraitUp'], reason: 'the phone-sized display uses portrait');
    calls.clear();

    tester.view.display.size = const Size(2048, 2732);
    tester.view.physicalSize = const Size(900, 1200);
    await applyAllowedOrientations(view: tester.view);
    expect(calls, <Object?>[<String>[]], reason: 'Stage Manager size does not override the iPad display');

    tester.view.physicalSize = const Size(1200, 1800);
    await applyAllowedOrientations(view: tester.view);
    final int resizeCallCount = calls.length;
    expect(resizeCallCount, 1, reason: 'resizing an iPad window does not change its display orientation policy');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android display size stays authoritative when the window is larger', (tester) async {
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
    tester.view.display.size = const Size(2048, 2732);
    tester.view.physicalSize = const Size(2048, 2732);
    await applyAllowedOrientations(view: tester.view);

    tester.view.display.size = const Size(800, 1200);
    tester.view.physicalSize = const Size(800, 1200);
    await applyAllowedOrientations(view: tester.view);
    expect(calls.last, <String>['DeviceOrientation.portraitUp'], reason: 'the phone-sized display uses portrait');
    calls.clear();

    tester.view.physicalSize = const Size(1600, 2400);
    await applyAllowedOrientations(view: tester.view);
    expect(calls, isEmpty, reason: 'a larger Android window must not override the phone-sized display');
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Android letterboxing a tablet does not apply the phone window policy', (tester) async {
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
    tester.view.display.size = const Size(800, 1200);
    tester.view.physicalSize = const Size(800, 1200);
    await applyAllowedOrientations(view: tester.view);
    calls.clear();

    tester.view.display.size = const Size(2048, 2732);
    tester.view.physicalSize = const Size(900, 1200);
    await applyAllowedOrientations(view: tester.view);
    expect(calls, <Object?>[<String>[]], reason: 'the tablet display remains rotatable in a letterboxed window');
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

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

    tester.view.devicePixelRatio = 3;
    tester.view.display.devicePixelRatio = 3;
    tester.view.display.size = const Size(1398, 2034);
    tester.view.physicalSize = const Size(1398, 2034);
    await applyAllowedOrientations(view: tester.view);
    calls.clear();

    tester.view.physicalSize = Size.zero;
    tester.view.display.size = Size.zero;
    final OrientationPolicyObserver observer = OrientationPolicyObserver(view: tester.view);
    addTearDown(observer.dispose);
    await observer.start();
    expect(calls, isEmpty, reason: 'zero startup metrics must not lock orientation');

    tester.view.display.size = const Size(1398, 2034);
    tester.view.physicalSize = const Size(2007, 2853);
    await tester.pump();
    expect(calls.last, <String>[], reason: 'the unfolded Duo window is tablet-sized');

    tester.view.physicalSize = const Size(1398, 2034);
    await tester.pump();
    expect(calls.last, <String>['DeviceOrientation.portraitUp'], reason: 'folding restores the phone portrait lock');

    tester.view.physicalSize = const Size(2007, 2853);
    await tester.pump();
    expect(calls.last, <String>[], reason: 'unfolding removes the portrait lock');

    observer.dispose();
    final int beforeDisposeResize = calls.length;
    tester.view.physicalSize = const Size(1398, 2034);
    await tester.pump();
    expect(calls, hasLength(beforeDisposeResize), reason: 'disposed observers do not send orientation requests');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

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
