import 'dart:io';
import 'package:Prism/core/state/app_state.dart' as app_state;

import 'package:Prism/features/live_wallpaper/data/live_texture_preparer.dart';
import 'package:Prism/features/live_wallpaper/data/repositories/live_wallpaper_repository_impl.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_apply_outcome.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_palette.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:async_wallpaper/src/wallpaper_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/profile_user_fixture.dart';

class _Client extends Mock implements WallpaperClient {}

class _Texture extends Mock implements LiveTexturePreparer {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Client client;
  late _Texture texture;
  late LiveWallpaperRepositoryImpl repository;
  late Directory directory;
  final palette = LivePalette.fromAccent(Colors.blue, dark: true);
  const pending = aw.WallpaperOperationResult(
    status: aw.WallpaperOperationStatus.awaitingUserConfirmation,
    requestedTarget: aw.WallpaperTarget.both,
  );
  const applied = aw.WallpaperOperationResult(
    status: aw.WallpaperOperationStatus.applied,
    requestedTarget: aw.WallpaperTarget.both,
  );
  setUpAll(() {
    registerFallbackValue(aw.OpenGlLiveWallpaperRequest(fragmentShader: 'shader'));
    registerFallbackValue(const aw.VideoWallpaperRequest(source: aw.WallpaperSource.filePath('/video.mp4')));
  });
  setUp(() {
    app_state.prismUser = profileUser();
    client = _Client();
    texture = _Texture();
    repository = LiveWallpaperRepositoryImpl(texturePreparer: texture);
    aw.AsyncWallpaper.debugSetClient(client);
    directory = Directory.systemTemp.createTempSync('prism_live_apply_test_');
  });
  tearDown(() {
    app_state.prismUser = profileUser(loggedIn: false);
    aw.AsyncWallpaper.debugResetClient();
    directory.deleteSync(recursive: true);
  });

  test('guest local premium cannot prepare textures or invoke any native live apply', () async {
    app_state.prismUser = profileUser(loggedIn: false, premium: true);
    final motion = await repository.applyMotion(
      imageUrl: '/local.jpg',
      style: MotionStyle.drift,
      palette: palette,
      screenAspectRatio: 0.5,
      batterySaver: false,
    );
    final gradient = await repository.applyGradient(style: GradientStyle.aurora, palette: palette, batterySaver: false);
    final video = await repository.applyVideo('/local.mp4');

    expect(<LiveApplyStatus>[motion.status, gradient.status, video.status], everyElement(LiveApplyStatus.cancelled));
    verifyZeroInteractions(texture);
    verifyZeroInteractions(client);
  });

  test('losing the session during texture preparation cancels before native apply', () async {
    when(() => texture.prepare('/local.jpg', 0.5)).thenAnswer((_) async {
      app_state.prismUser.loggedIn = false;
      return '/prepared.png';
    });

    final result = await repository.applyMotion(
      imageUrl: '/local.jpg',
      style: MotionStyle.drift,
      palette: palette,
      screenAspectRatio: 0.5,
      batterySaver: false,
    );

    expect(result.status, LiveApplyStatus.cancelled);
    verifyZeroInteractions(client);
  });

  test('capabilities reflect the host and gradient request uses battery saver without textures', () async {
    when(
      client.getCapabilities,
    ).thenAnswer((_) async => const aw.WallpaperCapabilities(supportsOpenGlLiveWallpaper: true, supportsTilt: true));
    final capabilities = await repository.getCapabilities();
    expect(capabilities.supportsShaders, isTrue);
    expect(capabilities.supportsVideo, isFalse);
    expect(capabilities.supportsTilt, isTrue);
    when(() => client.applyOpenGlWallpaper(any())).thenAnswer((_) async => applied);
    final outcome = await repository.applyGradient(style: GradientStyle.aurora, palette: palette, batterySaver: true);
    expect(outcome.status, LiveApplyStatus.applied);
    final request =
        verify(() => client.applyOpenGlWallpaper(captureAny())).captured.single as aw.OpenGlLiveWallpaperRequest;
    expect(request.frameRate, 15);
    expect(request.textures, isEmpty);
    expect(request.fragmentShader, contains('void main'));
  });

  test('motion prepares the requested aspect ratio and passes the resulting local texture to the host', () async {
    when(() => texture.prepare('https://example.test/wall.jpg', 0.5)).thenAnswer((_) async => '/prepared/texture.jpg');
    when(() => client.applyOpenGlWallpaper(any())).thenAnswer((_) async => pending);
    final outcome = await repository.applyMotion(
      imageUrl: 'https://example.test/wall.jpg',
      style: MotionStyle.drift,
      palette: palette,
      screenAspectRatio: 0.5,
      batterySaver: false,
    );
    expect(outcome.status, LiveApplyStatus.confirmInPreview);
    verify(() => texture.prepare('https://example.test/wall.jpg', 0.5)).called(1);
    final request =
        verify(() => client.applyOpenGlWallpaper(captureAny())).captured.single as aw.OpenGlLiveWallpaperRequest;
    expect(request.frameRate, 30);
    expect(request.textures.single.filePath, '/prepared/texture.jpg');
  });

  test('the 3D style without a depth map is unavailable and prepares nothing', () async {
    final outcome = await repository.applyMotion(
      imageUrl: 'https://example.test/wall.jpg',
      style: MotionStyle.depth,
      palette: palette,
      screenAspectRatio: 0.5,
      batterySaver: false,
    );
    expect(outcome.failure, LiveApplyFailure.styleUnavailable);
    verifyNever(() => texture.prepare(any(), any()));
    verifyNever(() => texture.prepareWithDepth(any(), any(), any()));
    verifyNever(() => client.applyOpenGlWallpaper(any()));
  });

  test('the 3D style sends the photo then the depth map as textures at 30 frames per second', () async {
    when(
      () => texture.prepareWithDepth('https://example.test/wall.jpg', 'https://example.test/map.png', 0.5),
    ).thenAnswer((_) async => (photo: '/p.jpg', depth: '/d.jpg'));
    when(() => client.applyOpenGlWallpaper(any())).thenAnswer((_) async => pending);
    final outcome = await repository.applyMotion(
      imageUrl: 'https://example.test/wall.jpg',
      style: MotionStyle.depth,
      palette: palette,
      screenAspectRatio: 0.5,
      batterySaver: false,
      depthMapUrl: 'https://example.test/map.png',
    );
    expect(outcome.status, LiveApplyStatus.confirmInPreview);
    final request =
        verify(() => client.applyOpenGlWallpaper(captureAny())).captured.single as aw.OpenGlLiveWallpaperRequest;
    expect(request.frameRate, 30);
    expect(request.textures.map((source) => source.filePath), <String>['/p.jpg', '/d.jpg']);
    expect(request.fragmentShader, isNot(contains('u_tilt')));
  });

  test('the 3D style with tilt declares u_tilt in the shader', () async {
    when(
      () => texture.prepareWithDepth('https://example.test/wall.jpg', 'https://example.test/map.png', 0.5),
    ).thenAnswer((_) async => (photo: '/p.jpg', depth: '/d.jpg'));
    when(() => client.applyOpenGlWallpaper(any())).thenAnswer((_) async => pending);
    await repository.applyMotion(
      imageUrl: 'https://example.test/wall.jpg',
      style: MotionStyle.depth,
      palette: palette,
      screenAspectRatio: 0.5,
      batterySaver: false,
      depthMapUrl: 'https://example.test/map.png',
      tilt: true,
    );
    final request =
        verify(() => client.applyOpenGlWallpaper(captureAny())).captured.single as aw.OpenGlLiveWallpaperRequest;
    expect(request.fragmentShader, contains('uniform vec2 u_tilt;'));
  });

  test('a depth-map download failure is reported and a later apply can retry', () async {
    var prepareCalls = 0;
    when(
      () => texture.prepareWithDepth('https://example.test/wall.jpg', 'https://example.test/map.png', 0.5),
    ).thenAnswer((_) async {
      prepareCalls++;
      if (prepareCalls == 1) throw const LiveTextureException(LiveApplyFailure.textureDownloadFailed);
      return (photo: '/p.jpg', depth: '/d.jpg');
    });
    when(() => client.applyOpenGlWallpaper(any())).thenAnswer((_) async => pending);

    final first = await repository.applyMotion(
      imageUrl: 'https://example.test/wall.jpg',
      style: MotionStyle.depth,
      palette: palette,
      screenAspectRatio: 0.5,
      batterySaver: false,
      depthMapUrl: 'https://example.test/map.png',
    );
    expect(first.failure, LiveApplyFailure.textureDownloadFailed);
    verifyNever(() => client.applyOpenGlWallpaper(any()));

    final retry = await repository.applyMotion(
      imageUrl: 'https://example.test/wall.jpg',
      style: MotionStyle.depth,
      palette: palette,
      screenAspectRatio: 0.5,
      batterySaver: false,
      depthMapUrl: 'https://example.test/map.png',
    );
    expect(retry.status, LiveApplyStatus.confirmInPreview);
    expect(prepareCalls, 2);
    final request =
        verify(() => client.applyOpenGlWallpaper(captureAny())).captured.single as aw.OpenGlLiveWallpaperRequest;
    expect(request.textures.map((source) => source.filePath), <String>['/p.jpg', '/d.jpg']);
  });

  test('texture preparation failure returns its reason without contacting the host', () async {
    when(() => texture.prepare('bad', 1)).thenThrow(const LiveTextureException(LiveApplyFailure.textureTooDetailed));
    final outcome = await repository.applyMotion(
      imageUrl: 'bad',
      style: MotionStyle.drift,
      palette: palette,
      screenAspectRatio: 1,
      batterySaver: false,
    );
    expect(outcome.failure, LiveApplyFailure.textureTooDetailed);
    verifyNever(() => client.applyOpenGlWallpaper(any()));
  });

  test('video preparation opens confirmation only when needed and preserves cancellation', () async {
    final file = File('${directory.path}/clip.mp4')..writeAsBytesSync([1, 2, 3]);
    when(() => client.prepareVideoWallpaper(any())).thenAnswer((_) async => pending);
    when(() => client.openLiveWallpaperPreview(any())).thenAnswer(
      (_) async => const aw.WallpaperOperationResult(
        status: aw.WallpaperOperationStatus.cancelled,
        requestedTarget: aw.WallpaperTarget.both,
      ),
    );
    expect((await repository.applyVideo(file.path)).status, LiveApplyStatus.cancelled);
    final request =
        verify(() => client.openLiveWallpaperPreview(captureAny())).captured.single as aw.VideoWallpaperRequest;
    expect(request.source.filePath, file.path);
    when(() => client.prepareVideoWallpaper(any())).thenAnswer((_) async => applied);
    expect((await repository.applyVideo(file.path)).status, LiveApplyStatus.applied);
    verifyNever(() => client.openLiveWallpaperPreview(any()));
    expect((await repository.applyVideo('${directory.path}/missing.mp4')).failure, LiveApplyFailure.videoReadFailed);
  });
}
