import 'package:Prism/features/desktop_submission/desktop_submission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('2560x1600 is an ok 16:10 image', () {
    final DesktopImageCheck check = DesktopImageCheck.of(2560, 1600);
    expect(check, isA<DesktopImageOk>());
    final DesktopImageOk ok = check as DesktopImageOk;
    expect(ok.width, 2560);
    expect(ok.height, 1600);
    expect(ok.aspect, DesktopAspect.wide16x10);
  });

  test('1920x1080 is an ok 16:9 image', () {
    final DesktopImageOk ok = DesktopImageCheck.of(1920, 1080) as DesktopImageOk;
    expect(ok.width, 1920);
    expect(ok.height, 1080);
    expect(ok.aspect, DesktopAspect.wide16x9);
  });

  test('1919x1200 is too small', () {
    final DesktopImageCheck check = DesktopImageCheck.of(1919, 1200);
    expect(check, isA<DesktopImageTooSmall>());
    expect((check as DesktopImageTooSmall).width, 1919);
  });

  test('1080x1920 is not landscape', () {
    expect(DesktopImageCheck.of(1080, 1920), isA<DesktopImageNotLandscape>());
  });

  test('1000x1000 is not landscape', () {
    expect(DesktopImageCheck.of(1000, 1000), isA<DesktopImageNotLandscape>());
  });

  test('2000x1500 (4:3) has the wrong aspect', () {
    expect(DesktopImageCheck.of(2000, 1500), isA<DesktopImageWrongAspect>());
  });

  test('1920x1188 is ok as 16:10 within the 2% tolerance', () {
    final DesktopImageOk ok = DesktopImageCheck.of(1920, 1188) as DesktopImageOk;
    expect(ok.aspect, DesktopAspect.wide16x10);
  });

  test('1920x1260 is outside the 2% tolerance and has the wrong aspect', () {
    expect(DesktopImageCheck.of(1920, 1260), isA<DesktopImageWrongAspect>());
  });
}
