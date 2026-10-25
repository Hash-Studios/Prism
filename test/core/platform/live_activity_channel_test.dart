import 'dart:async';

import 'package:Prism/core/platform/live_activity_channel.dart';
import 'package:Prism/core/platform/pigeon/prism_live_activity_api.g.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLiveActivityApi extends PrismLiveActivityHostApi {
  int starts = 0;
  final List<String> calls = <String>[];
  String? startResult = 'abc';
  Object? startError;
  Object? finishError;
  Completer<void>? finishGate;

  @override
  Future<String?> startAiGeneration(AiActivityRequest request) async {
    starts++;
    if (startError != null) throw startError!;
    return startResult;
  }

  @override
  Future<void> finishAiGeneration(String activityId, String imageUrl) async {
    calls.add('finish:$activityId:$imageUrl');
    if (finishError != null) throw finishError!;
    await finishGate?.future;
  }

  @override
  Future<void> failAiGeneration(String activityId, String detail) async {
    calls.add('fail:$activityId:$detail');
  }

  @override
  Future<void> cancelAiGeneration(String activityId) async {
    calls.add('cancel:$activityId');
  }
}

AiActivityRequest _request() => AiActivityRequest(
  prompt: 'p',
  style: 's',
  accentArgb: 1,
  swatchArgb: <int>[],
  generatingTitle: 'g',
  readyTitle: 'r',
  failedTitle: 'f',
  staleTitle: 'st',
  openLabel: 'o',
);

void main() {
  final PrismLiveActivityHostApi defaultApi = LiveActivityChannel.api;
  final bool Function() defaultSupported = LiveActivityChannel.isSupportedPlatform;
  late _FakeLiveActivityApi fake;

  setUp(() {
    fake = _FakeLiveActivityApi();
    LiveActivityChannel.api = fake;
    LiveActivityChannel.isSupportedPlatform = () => true;
  });

  tearDown(() {
    LiveActivityChannel.api = defaultApi;
    LiveActivityChannel.isSupportedPlatform = defaultSupported;
  });

  test('does nothing on unsupported platforms', () async {
    LiveActivityChannel.isSupportedPlatform = () => false;
    expect(await LiveActivityChannel.startAiGeneration(_request()), isNull);
    expect(fake.starts, 0);
    expect(fake.calls, isEmpty);
  });

  test('the first settle call wins and later calls do nothing', () async {
    final AiGenerationActivity? activity = await LiveActivityChannel.startAiGeneration(_request());
    expect(activity?.id, 'abc');
    await activity!.finish('u');
    await activity.fail('x');
    await activity.cancel();
    expect(fake.calls, <String>['finish:abc:u']);
  });

  test('a null host id returns null', () async {
    fake.startResult = null;
    expect(await LiveActivityChannel.startAiGeneration(_request()), isNull);
  });

  test('a platform error returns null instead of throwing', () async {
    fake.startError = PlatformException(code: 'x');
    expect(await LiveActivityChannel.startAiGeneration(_request()), isNull);
  });

  test('an unexpected host error returns null instead of throwing', () async {
    fake.startError = StateError('host failed');
    expect(await LiveActivityChannel.startAiGeneration(_request()), isNull);
  });

  test('an unexpected settle error does not escape', () async {
    final AiGenerationActivity? activity = await LiveActivityChannel.startAiGeneration(_request());
    fake.finishError = StateError('host failed');
    await expectLater(activity!.finish('u'), completes);
  });

  test('an in-flight finish wins over concurrent fail and cancel calls', () async {
    final AiGenerationActivity? activity = await LiveActivityChannel.startAiGeneration(_request());
    fake.finishGate = Completer<void>();
    final Future<void> finishing = activity!.finish('u');
    await activity.fail('x');
    await activity.cancel();
    expect(fake.calls, <String>['finish:abc:u']);
    fake.finishGate!.complete();
    await finishing;
  });

  test('cancel before finish blocks finish', () async {
    final AiGenerationActivity? activity = await LiveActivityChannel.startAiGeneration(_request());
    await activity!.cancel();
    await activity.finish('u');
    expect(fake.calls, <String>['cancel:abc']);
  });
}
