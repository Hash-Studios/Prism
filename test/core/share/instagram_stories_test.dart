import 'package:Prism/core/platform/pigeon/prism_share_api.g.dart';
import 'package:Prism/core/share/instagram_stories.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeShareApi extends PrismShareHostApi {
  bool canAnswer = true;
  bool shareAnswer = true;
  PlatformException? error;
  int canCalls = 0;
  InstagramStoryTarget? canTarget;
  InstagramStoryTarget? shareTarget;
  String? sharedPath;

  @override
  Future<bool> canShareInstagramStory(InstagramStoryTarget target) async {
    canCalls++;
    canTarget = target;
    if (error != null) throw error!;
    return canAnswer;
  }

  @override
  Future<bool> shareInstagramStory(InstagramStoryTarget target, String imagePath) async {
    shareTarget = target;
    sharedPath = imagePath;
    if (error != null) throw error!;
    return shareAnswer;
  }
}

void _installFake(_FakeShareApi fake, {required String appId}) {
  final PrismShareHostApi originalApi = InstagramStories.api;
  final String originalAppId = InstagramStories.appId;
  addTearDown(() {
    InstagramStories.api = originalApi;
    InstagramStories.appId = originalAppId;
  });
  InstagramStories.api = fake;
  InstagramStories.appId = appId;
}

void main() {
  test('instagramStoryTarget builds the Meta sharing contract', () {
    final InstagramStoryTarget target = instagramStoryTarget('123');

    expect(target.iosUrl, 'instagram-stories://share?source_application=123');
    expect(target.iosPasteboardKey, 'com.instagram.sharedSticker.backgroundImage');
    expect(target.androidAction, 'com.instagram.share.ADD_TO_STORY');
    expect(target.androidPackage, 'com.instagram.android');
    expect(target.androidAppIdExtra, 'source_application');
    expect(target.mimeType, 'image/png');
    expect(target.appId, '123');
  });

  test('instagramStoryTarget percent-encodes special characters in the app id', () {
    final InstagramStoryTarget target = instagramStoryTarget('a b&c');

    expect(target.iosUrl, 'instagram-stories://share?source_application=a+b%26c');
    expect(target.iosUrl, isNot(contains('&c')));
  });

  for (final String blank in <String>['', '  ']) {
    test('available is false and never calls the api when the app id is "$blank"', () async {
      final _FakeShareApi fake = _FakeShareApi();
      _installFake(fake, appId: blank);

      expect(await InstagramStories.available(), isFalse);
      expect(fake.canCalls, 0);
    });
  }

  test('available returns the api answer and passes the built target when the app id is set', () async {
    final _FakeShareApi fake = _FakeShareApi()..canAnswer = true;
    _installFake(fake, appId: '123');

    expect(await InstagramStories.available(), isTrue);
    expect(fake.canCalls, 1);
    expect(fake.canTarget?.appId, '123');
    expect(fake.canTarget?.androidAction, 'com.instagram.share.ADD_TO_STORY');
  });

  test('available returns false when the api throws a PlatformException', () async {
    final _FakeShareApi fake = _FakeShareApi()..error = PlatformException(code: 'unavailable');
    _installFake(fake, appId: '123');

    expect(await InstagramStories.available(), isFalse);
  });

  test('share returns false when the api throws a PlatformException', () async {
    final _FakeShareApi fake = _FakeShareApi()..error = PlatformException(code: 'failed');
    _installFake(fake, appId: '123');

    expect(await InstagramStories.share('/tmp/card.png'), isFalse);
  });

  test('share forwards the image path and the built target', () async {
    final _FakeShareApi fake = _FakeShareApi()..shareAnswer = true;
    _installFake(fake, appId: '123');

    expect(await InstagramStories.share('/tmp/card.png'), isTrue);
    expect(fake.sharedPath, '/tmp/card.png');
    expect(fake.shareTarget?.appId, '123');
  });
}
