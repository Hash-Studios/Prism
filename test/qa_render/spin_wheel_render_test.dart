@Tags(<String>['qa_render'])
library;

import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/spin_wheel/domain/bulb_pattern.dart';
import 'package:Prism/features/spin_wheel/domain/wheel_motion.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_geometry.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_machine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'qa_harness.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(WallpaperDetailRoute());
  });
  setUpAll(loadFonts);

  qaScreen('wheel_only', height: 440, (QaShot shot) async {
    await shot.pump(
      Scaffold(
        body: Center(
          child: WheelMachine(
            segments: defaultWheel,
            geometry: const WheelGeometry(340),
            theta: ValueNotifier<double>(restAngle(8)),
            flapper: ValueNotifier<double>(0),
            bulbs: ValueNotifier<BulbFrame>(const BulbFrame()),
          ),
        ),
      ),
    );
    await shot.save('wheel_only');
  });
}
