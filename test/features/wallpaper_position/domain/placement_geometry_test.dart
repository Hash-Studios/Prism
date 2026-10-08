import 'dart:ui';

import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:Prism/features/wallpaper_position/domain/placement_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Size frame = Size(100, 200);

  group('contentSize', () {
    test('fill scales a wide wall to cover the frame', () {
      expect(PlacementGeometry.contentSize(const Size(400, 200), frame, PlacementFit.fill), const Size(400, 200));
    });

    test('fill scales a small portrait wall up to cover the frame', () {
      expect(PlacementGeometry.contentSize(const Size(50, 80), frame, PlacementFit.fill), const Size(125, 200));
    });

    test('the fit modes use the frame itself', () {
      expect(PlacementGeometry.contentSize(const Size(400, 200), frame, PlacementFit.fitBlur), frame);
      expect(PlacementGeometry.contentSize(const Size(400, 200), frame, PlacementFit.fitColor), frame);
    });
  });

  test('containRect centres the whole wall inside the frame', () {
    expect(PlacementGeometry.containRect(const Size(400, 200), frame), const Rect.fromLTWH(0, 75, 100, 50));
    expect(PlacementGeometry.containRect(const Size(50, 200), frame), const Rect.fromLTWH(25, 0, 50, 200));
  });

  group('translation', () {
    const Size content = Size(400, 200);

    test('centred at zoom 1 shows the middle of a wide wall', () {
      expect(PlacementGeometry.translation(content, frame, const WallpaperPlacement()), const Offset(-150, 0));
    });

    test('dx -1 shows the left edge and 1 shows the right edge', () {
      expect(PlacementGeometry.translation(content, frame, const WallpaperPlacement(dx: -1)).dx, 0);
      expect(PlacementGeometry.translation(content, frame, const WallpaperPlacement(dx: 1)).dx, -300);
    });

    test('zoom gives room on the other axis too', () {
      final Offset offset = PlacementGeometry.translation(content, frame, const WallpaperPlacement(zoom: 2, dy: 1));
      expect(offset.dy, -200);
    });

    test('an axis with no room stays at zero whatever dx or dy says', () {
      final Offset offset = PlacementGeometry.translation(frame, frame, const WallpaperPlacement(dx: 1, dy: -1));
      expect(offset, Offset.zero);
    });
  });

  group('focus', () {
    const Size content = Size(400, 200);

    test('reads back what translation made', () {
      for (final WallpaperPlacement placement in const <WallpaperPlacement>[
        WallpaperPlacement(dx: -0.4, dy: 0.7, zoom: 2.5),
        WallpaperPlacement(dx: 1, dy: -1, zoom: 4),
        WallpaperPlacement(dx: 0.25),
      ]) {
        final Offset offset = PlacementGeometry.translation(content, frame, placement);
        final focus = PlacementGeometry.focus(offset, content, frame, placement.zoom);
        expect(focus.dx, closeTo(placement.dx, 1e-9));
        expect(focus.dy, closeTo(placement.dy, 1e-9));
      }
    });

    test('is zero when there is no room to move', () {
      expect(PlacementGeometry.focus(Offset.zero, frame, frame, 1), (dx: 0.0, dy: 0.0));
    });

    test('clamps an offset outside the content', () {
      expect(PlacementGeometry.focus(const Offset(50, 0), content, frame, 1).dx, -1);
      expect(PlacementGeometry.focus(const Offset(-900, 0), content, frame, 1).dx, 1);
    });
  });

  group('WallpaperPlacement', () {
    test('copyWith keeps every value in range', () {
      final WallpaperPlacement placement = const WallpaperPlacement().copyWith(dx: 5, dy: -5, zoom: 9, dim: 1);
      expect((placement.dx, placement.dy, placement.zoom, placement.dim), (1.0, -1.0, 4.0, 0.6));
      expect(placement.copyWith(zoom: 0.2).zoom, 1);
    });

    test('isZoomed ignores a rounding error and dimBucket rounds to 10 percent steps', () {
      expect(const WallpaperPlacement(zoom: 1.005).isZoomed, isFalse);
      expect(const WallpaperPlacement(zoom: 1.5).isZoomed, isTrue);
      expect(const WallpaperPlacement().dimBucket, 0);
      expect(const WallpaperPlacement(dim: 0.34).dimBucket, 3);
      expect(const WallpaperPlacement(dim: 0.6).dimBucket, 6);
    });

    test('equal values are equal', () {
      expect(const WallpaperPlacement(dim: 0.2), const WallpaperPlacement(dim: 0.2));
      expect(const WallpaperPlacement(dim: 0.2), isNot(const WallpaperPlacement(dim: 0.3)));
    });
  });
}
