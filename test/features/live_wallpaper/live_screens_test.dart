import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_screens.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveContentTag', () {
    test('encodes a motion style with the prism.live prefix', () {
      expect(const LiveContentTag(style: MotionStyle.ripple, applyId: 'abc').encode(), 'prism.live:motion:ripple:abc');
    });

    test('a motion tag parses back to an equal tag', () {
      const LiveContentTag tag = LiveContentTag(style: MotionStyle.ripple, applyId: 'abc');
      expect(LiveContentTag.parse(tag.encode()), tag);
    });

    test('encodes a gradient style and parses back to an equal tag', () {
      const LiveContentTag tag = LiveContentTag(style: GradientStyle.aurora, applyId: 'x');
      expect(tag.encode(), 'prism.live:gradient:aurora:x');
      expect(LiveContentTag.parse(tag.encode()), tag);
    });

    test('parse returns null for anything that is not a Prism tag', () {
      expect(LiveContentTag.parse(null), isNull);
      expect(LiveContentTag.parse(''), isNull);
      expect(LiveContentTag.parse('other:motion:ripple:abc'), isNull);
      expect(LiveContentTag.parse('prism.live:motion:nosuch:abc'), isNull);
      expect(LiveContentTag.parse('prism.live:motion:ripple'), isNull);
    });
  });

  group('LiveScreens.screensShowing', () {
    const LiveContentTag tag = LiveContentTag(style: MotionStyle.ripple, applyId: 'abc');
    const LiveContentTag other = LiveContentTag(style: MotionStyle.ripple, applyId: 'def');

    test('both screens showing the tag means both', () {
      const LiveScreens screens = LiveScreens(
        home: LiveScreenContent(showsPrism: true, tag: tag),
        lock: LiveScreenContent(showsPrism: true, tag: tag),
      );
      expect(screens.screensShowing(tag), WallpaperTarget.both);
    });

    test('only home showing the tag means home', () {
      const LiveScreens screens = LiveScreens(
        home: LiveScreenContent(showsPrism: true, tag: tag),
        lock: LiveScreenContent(showsPrism: true, tag: other),
      );
      expect(screens.screensShowing(tag), WallpaperTarget.home);
    });

    test('only lock showing the tag means lock', () {
      const LiveScreens screens = LiveScreens(
        home: LiveScreenContent.other,
        lock: LiveScreenContent(showsPrism: true, tag: tag),
      );
      expect(screens.screensShowing(tag), WallpaperTarget.lock);
    });

    test('no screen showing the tag means null', () {
      const LiveScreens screens = LiveScreens(
        home: LiveScreenContent(showsPrism: true, tag: other),
        lock: LiveScreenContent.other,
      );
      expect(screens.screensShowing(tag), isNull);
    });

    test('a matching tag is ignored when the host says that screen is not Prism', () {
      const LiveScreens screens = LiveScreens(
        home: LiveScreenContent(showsPrism: false, tag: tag),
        lock: LiveScreenContent.other,
      );
      expect(screens.screensShowing(tag), isNull);
    });
  });
}
