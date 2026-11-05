const int desktopMinWidth = 1920;
const double desktopAspectTolerance = 0.02;

enum DesktopAspect {
  wide16x10('16:10', 16 / 10),
  wide16x9('16:9', 16 / 9);

  const DesktopAspect(this.label, this.ratio);

  final String label;
  final double ratio;
}

sealed class DesktopImageCheck {
  const DesktopImageCheck();

  static DesktopImageCheck of(int width, int height) {
    if (width <= 0 || height <= 0 || width <= height) return const DesktopImageNotLandscape();
    final double ratio = width / height;
    DesktopAspect? aspect;
    for (final DesktopAspect candidate in DesktopAspect.values) {
      if ((ratio - candidate.ratio).abs() / candidate.ratio <= desktopAspectTolerance) {
        aspect = candidate;
        break;
      }
    }
    if (aspect == null) return const DesktopImageWrongAspect();
    if (width < desktopMinWidth) return DesktopImageTooSmall(width);
    return DesktopImageOk(width, height, aspect);
  }
}

final class DesktopImageOk extends DesktopImageCheck {
  const DesktopImageOk(this.width, this.height, this.aspect);

  final int width;
  final int height;
  final DesktopAspect aspect;
}

final class DesktopImageNotLandscape extends DesktopImageCheck {
  const DesktopImageNotLandscape();
}

final class DesktopImageWrongAspect extends DesktopImageCheck {
  const DesktopImageWrongAspect();
}

final class DesktopImageTooSmall extends DesktopImageCheck {
  const DesktopImageTooSmall(this.width);

  final int width;
}
