import 'dart:ui' show Offset, Rect, Size;

import 'package:Prism/features/watch_set/domain/entities/watch_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('apple40 is 324x394 rounded rect on Apple Watch', () {
    expect(WatchFormat.apple40.id, 'apple_40');
    expect(WatchFormat.apple40.width, 324);
    expect(WatchFormat.apple40.height, 394);
    expect(WatchFormat.apple40.shape, WatchShape.roundedRect);
    expect(WatchFormat.apple40.platform, WatchPlatform.appleWatch);
  });

  test('apple44 is 368x448 rounded rect on Apple Watch', () {
    expect(WatchFormat.apple44.id, 'apple_44');
    expect(WatchFormat.apple44.width, 368);
    expect(WatchFormat.apple44.height, 448);
    expect(WatchFormat.apple44.shape, WatchShape.roundedRect);
    expect(WatchFormat.apple44.platform, WatchPlatform.appleWatch);
  });

  test('apple41 is 352x430 rounded rect on Apple Watch', () {
    expect(WatchFormat.apple41.id, 'apple_41');
    expect(WatchFormat.apple41.width, 352);
    expect(WatchFormat.apple41.height, 430);
    expect(WatchFormat.apple41.shape, WatchShape.roundedRect);
    expect(WatchFormat.apple41.platform, WatchPlatform.appleWatch);
  });

  test('apple45 is 396x484 rounded rect on Apple Watch', () {
    expect(WatchFormat.apple45.id, 'apple_45');
    expect(WatchFormat.apple45.width, 396);
    expect(WatchFormat.apple45.height, 484);
    expect(WatchFormat.apple45.shape, WatchShape.roundedRect);
    expect(WatchFormat.apple45.platform, WatchPlatform.appleWatch);
  });

  test('apple42 is 374x446 rounded rect on Apple Watch', () {
    expect(WatchFormat.apple42.id, 'apple_42');
    expect(WatchFormat.apple42.width, 374);
    expect(WatchFormat.apple42.height, 446);
    expect(WatchFormat.apple42.shape, WatchShape.roundedRect);
    expect(WatchFormat.apple42.platform, WatchPlatform.appleWatch);
  });

  test('apple46 is 416x496 rounded rect on Apple Watch', () {
    expect(WatchFormat.apple46.id, 'apple_46');
    expect(WatchFormat.apple46.width, 416);
    expect(WatchFormat.apple46.height, 496);
    expect(WatchFormat.apple46.shape, WatchShape.roundedRect);
    expect(WatchFormat.apple46.platform, WatchPlatform.appleWatch);
  });

  test('appleUltra is 410x502 rounded rect on Apple Watch', () {
    expect(WatchFormat.appleUltra.id, 'apple_ultra');
    expect(WatchFormat.appleUltra.width, 410);
    expect(WatchFormat.appleUltra.height, 502);
    expect(WatchFormat.appleUltra.shape, WatchShape.roundedRect);
    expect(WatchFormat.appleUltra.platform, WatchPlatform.appleWatch);
  });

  test('appleUltra3 is 422x514 rounded rect on Apple Watch', () {
    expect(WatchFormat.appleUltra3.id, 'apple_ultra_3');
    expect(WatchFormat.appleUltra3.width, 422);
    expect(WatchFormat.appleUltra3.height, 514);
    expect(WatchFormat.appleUltra3.shape, WatchShape.roundedRect);
    expect(WatchFormat.appleUltra3.platform, WatchPlatform.appleWatch);
  });

  test('pixelWatch is 456x456 round on Wear OS', () {
    expect(WatchFormat.pixelWatch.id, 'pixel_watch');
    expect(WatchFormat.pixelWatch.width, 456);
    expect(WatchFormat.pixelWatch.height, 456);
    expect(WatchFormat.pixelWatch.shape, WatchShape.round);
    expect(WatchFormat.pixelWatch.platform, WatchPlatform.wearOs);
  });

  test('galaxySmall is 438x438 round on Wear OS', () {
    expect(WatchFormat.galaxySmall.id, 'galaxy_small');
    expect(WatchFormat.galaxySmall.width, 438);
    expect(WatchFormat.galaxySmall.height, 438);
    expect(WatchFormat.galaxySmall.shape, WatchShape.round);
    expect(WatchFormat.galaxySmall.platform, WatchPlatform.wearOs);
  });

  test('galaxyLarge is 480x480 round on Wear OS', () {
    expect(WatchFormat.galaxyLarge.id, 'galaxy_large');
    expect(WatchFormat.galaxyLarge.width, 480);
    expect(WatchFormat.galaxyLarge.height, 480);
    expect(WatchFormat.galaxyLarge.shape, WatchShape.round);
    expect(WatchFormat.galaxyLarge.platform, WatchPlatform.wearOs);
  });

  test('there are 11 formats with unique ids', () {
    expect(WatchFormat.values.length, 11);
    final Set<String> ids = WatchFormat.values.map((WatchFormat f) => f.id).toSet();
    expect(ids.length, WatchFormat.values.length);
  });

  test('every Wear OS format is round and square', () {
    for (final WatchFormat format in WatchFormat.values.where((WatchFormat f) => f.platform == WatchPlatform.wearOs)) {
      expect(format.shape, WatchShape.round, reason: format.id);
      expect(format.width, format.height, reason: format.id);
    }
  });

  test('every Apple Watch format is a rounded rect and taller than wide', () {
    for (final WatchFormat format in WatchFormat.values.where(
      (WatchFormat f) => f.platform == WatchPlatform.appleWatch,
    )) {
      expect(format.shape, WatchShape.roundedRect, reason: format.id);
      expect(format.height, greaterThan(format.width), reason: format.id);
    }
  });

  test('fromId finds a format by its id', () {
    expect(WatchFormat.fromId('apple_46'), WatchFormat.apple46);
  });

  test('fromId returns null for an unknown id', () {
    expect(WatchFormat.fromId('nope'), isNull);
  });

  test('fromId returns null for a null id', () {
    expect(WatchFormat.fromId(null), isNull);
  });

  group('WatchMask', () {
    test('round mask in a 100x100 frame has a corner radius of half the side', () {
      const WatchMask mask = WatchMask(WatchShape.round);
      expect(mask.cornerRadius(const Size(100, 100)), 50);
    });

    test('round mask outline is the circle inside the frame', () {
      const WatchMask mask = WatchMask(WatchShape.round);
      const Rect frame = Rect.fromLTWH(10, 20, 100, 100);
      final outline = mask.outline(frame);
      expect(outline.width, 100);
      expect(outline.tlRadiusX, 50);
    });

    test('round mask shows the centre of the frame', () {
      const WatchMask mask = WatchMask(WatchShape.round);
      const Rect frame = Rect.fromLTWH(10, 20, 100, 100);
      expect(mask.shows(frame, const Offset(60, 70)), isTrue);
    });

    test('round mask hides the corner of the frame', () {
      const WatchMask mask = WatchMask(WatchShape.round);
      const Rect frame = Rect.fromLTWH(10, 20, 100, 100);
      expect(mask.shows(frame, const Offset(12, 22)), isFalse);
    });

    test('round mask shows the middle of the top edge', () {
      const WatchMask mask = WatchMask(WatchShape.round);
      const Rect frame = Rect.fromLTWH(10, 20, 100, 100);
      expect(mask.shows(frame, const Offset(60, 21)), isTrue);
    });

    test('round mask in a 200x100 frame is a centred 100x100 circle', () {
      const WatchMask mask = WatchMask(WatchShape.round);
      const Rect frame = Rect.fromLTWH(0, 0, 200, 100);
      final outline = mask.outline(frame);
      expect(outline.left, 50);
      expect(outline.right, 150);
    });

    test('round mask hides the left end of a wide frame', () {
      const WatchMask mask = WatchMask(WatchShape.round);
      const Rect frame = Rect.fromLTWH(0, 0, 200, 100);
      expect(mask.shows(frame, const Offset(20, 50)), isFalse);
    });

    test('rounded rect corner radius is 22 percent of the short side', () {
      const WatchMask mask = WatchMask(WatchShape.roundedRect);
      expect(mask.cornerRadius(const Size(100, 120)), 22.0);
    });

    test('rounded rect hides its top left corner', () {
      const WatchMask mask = WatchMask(WatchShape.roundedRect);
      const Rect frame = Rect.fromLTWH(0, 0, 100, 120);
      expect(mask.shows(frame, const Offset(1, 1)), isFalse);
    });

    test('rounded rect shows the middle of the top edge', () {
      const WatchMask mask = WatchMask(WatchShape.roundedRect);
      const Rect frame = Rect.fromLTWH(0, 0, 100, 120);
      expect(mask.shows(frame, const Offset(50, 1)), isTrue);
    });

    test('rounded rect hides its bottom right corner', () {
      const WatchMask mask = WatchMask(WatchShape.roundedRect);
      const Rect frame = Rect.fromLTWH(0, 0, 100, 120);
      expect(mask.shows(frame, const Offset(99, 119)), isFalse);
    });
  });
}
