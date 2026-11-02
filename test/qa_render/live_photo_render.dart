@Tags(<String>['qa_render'])
library;

import 'dart:async';
import 'dart:io';

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/core/widgets/prism_sheet/device_corner_radius.dart';
import 'package:Prism/features/live_photo/biz/bloc/live_photo_bloc.j.dart';
import 'package:Prism/features/live_photo/domain/entities/live_export.dart';
import 'package:Prism/features/live_photo/views/live_photo_sheet.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/clock_overlay.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../features/live_photo/fake_live_photo_repository.dart';
import 'qa_harness.dart';

final File _wall = File('assets/images/prism.webp').absolute;

Future<BuildContext> _home(QaShot shot) async {
  PrismDeviceCornerRadius.setValueForTesting(55);
  await shot.pump(
    Scaffold(
      body: SizedBox.expand(child: Image.file(_wall, fit: BoxFit.cover)),
    ),
  );
  return shot.tester.element(find.byType(Scaffold));
}

/// Opens the sheet on a bloc driven by a fake repository, so every state renders without native code.
Future<(LivePhotoBloc, FakeLivePhotoRepository)> _sheet(QaShot shot, {bool pro = true, String? depthMapUrl}) async {
  final BuildContext context = await _home(shot);
  final FakeLivePhotoRepository repository = FakeLivePhotoRepository();
  final LivePhotoBloc bloc = LivePhotoBloc(
    repository,
    wallId: 'wall-1',
    resolveSource: () async => _wall.path,
    isPro: pro,
    depthMapUrl: depthMapUrl,
  );
  unawaited(
    showPrismSheet<void>(
      context,
      builder: (_) => BlocProvider<LivePhotoBloc>.value(
        value: bloc,
        child: LivePhotoSheet(preview: FileImage(_wall)),
      ),
    ),
  );
  await shot.settle();
  return (bloc, repository);
}

Future<void> _export(QaShot shot) async {
  await shot.tester.tap(find.text('Save Live Photo'));
  await shot.settle(frames: 2);
}

Future<void> _finish(QaShot shot, FakeLivePhotoRepository repository, LiveExportOutcome outcome) async {
  repository.complete(outcome);
  await shot.settle(frames: 2);
}

void _largeText(QaShot shot) {
  shot.tester.platformDispatcher.textScaleFactorTestValue = 1.6;
  addTearDown(shot.tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  setUpAll(() async {
    registerFallbackValue(WallpaperDetailRoute());
    await loadFonts();
  });

  qaScreen('live photo set screen ios', (QaShot shot) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final BuildContext context = await _home(shot);
      unawaited(
        pushClockPreview(
          context,
          link: _wall.path,
          file: true,
          saveAction: (String label) => PrismButton(label: label, onPressed: () {}),
          livePhotoAction: (_, _) {},
        ),
      );
      await shot.settle(frames: 10);
      await shot.save('live_photo_01_set_screen');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  qaScreen('live photo picking', (QaShot shot) async {
    await _sheet(shot, depthMapUrl: 'https://example.com/depth.png');
    await shot.save('live_photo_02_picking');
  });

  qaScreen('live photo picking locked', (QaShot shot) async {
    await _sheet(shot, pro: false);
    await shot.save('live_photo_02b_picking_free_user');
  });

  qaScreen('live photo progress', (QaShot shot) async {
    final (LivePhotoBloc _, FakeLivePhotoRepository repository) = await _sheet(shot);
    await _export(shot);
    repository.lastOnProgress!(0.4);
    await shot.settle(frames: 2);
    await shot.save('live_photo_03_progress');
    await _finish(shot, repository, const LiveExportCancelled());
  });

  qaScreen('live photo refused', (QaShot shot) async {
    final (LivePhotoBloc _, FakeLivePhotoRepository repository) = await _sheet(shot);
    await _export(shot);
    await _finish(shot, repository, const LiveExportRefused(restricted: false));
    await shot.save('live_photo_07_refused');
  });

  qaScreen('live photo restricted', (QaShot shot) async {
    final (LivePhotoBloc _, FakeLivePhotoRepository repository) = await _sheet(shot);
    await _export(shot);
    await _finish(shot, repository, const LiveExportRefused(restricted: true));
    await shot.save('live_photo_07b_restricted');
  });

  qaScreen('live photo failed', (QaShot shot) async {
    final (LivePhotoBloc _, FakeLivePhotoRepository repository) = await _sheet(shot);
    await _export(shot);
    await _finish(shot, repository, const LiveExportTimedOut());
    await shot.save('live_photo_07c_timed_out');
  });

  qaScreen('live photo guide', (QaShot shot) async {
    final BuildContext context = await _home(shot);
    unawaited(showPrismSheet<void>(context, builder: (_) => const LivePhotoGuideSheet()));
    await shot.settle();
    await shot.save('live_photo_04_guide');
  });

  qaScreen('live photo picking large text', (QaShot shot) async {
    _largeText(shot);
    await _sheet(shot);
    await shot.save('live_photo_08_picking_large_text');
  });

  qaScreen('live photo guide large text', (QaShot shot) async {
    _largeText(shot);
    final BuildContext context = await _home(shot);
    unawaited(showPrismSheet<void>(context, builder: (_) => const LivePhotoGuideSheet()));
    await shot.settle();
    await shot.save('live_photo_09_guide_large_text');
  });
}
