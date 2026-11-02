import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Color, Size;

import 'package:Prism/core/platform/pigeon/prism_live_photo_api.g.dart';
import 'package:Prism/features/live_photo/data/repositories/live_photo_repository_impl.dart';
import 'package:Prism/features/live_photo/domain/entities/live_export.dart';
import 'package:Prism/features/live_wallpaper/data/live_texture_preparer.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _phone = Size(1179, 2556);
const Color _tint = Color(0xFFE57697);

class _FakeTexturePreparer extends LiveTexturePreparer {
  _FakeTexturePreparer(this.path);

  final String path;
  final List<String> imageUrls = <String>[];

  @override
  Future<String> prepare(String imageUrl, double screenAspectRatio, {bool uniquePaths = false}) async {
    imageUrls.add(imageUrl);
    return path;
  }
}

class _FakeHostApi extends PrismLivePhotoHostApi {
  final List<LivePhotoExportRequest> exportRequests = <LivePhotoExportRequest>[];
  final List<String> cancelledIds = <String>[];
  final Completer<LivePhotoExportRequest> started = Completer<LivePhotoExportRequest>();
  final Completer<LivePhotoExportResult> answer = Completer<LivePhotoExportResult>();

  @override
  Future<LivePhotoExportResult> exportLivePhoto(LivePhotoExportRequest request) {
    exportRequests.add(request);
    started.complete(request);
    return answer.future;
  }

  @override
  Future<void> cancelLivePhotoExport(String exportId) async {
    cancelledIds.add(exportId);
  }
}

void main() {
  group('outcomeOf', () {
    LiveExportOutcome map(LivePhotoExportStatus status, {String? errorCode, String? assetId, bool? verifiedLive}) =>
        LivePhotoRepositoryImpl.outcomeOf(
          LivePhotoExportResult(status: status, errorCode: errorCode, assetId: assetId, verifiedLive: verifiedLive),
        );

    test('saved keeps the asset id and a null verified flag from add-only access', () {
      final LiveExportOutcome outcome = map(LivePhotoExportStatus.saved, assetId: 'x');
      expect(
        outcome,
        isA<LiveExportSaved>()
            .having((LiveExportSaved saved) => saved.assetId, 'assetId', 'x')
            .having((LiveExportSaved saved) => saved.verified, 'verified', isNull),
      );
    });

    test('cancelled maps to LiveExportCancelled', () {
      expect(map(LivePhotoExportStatus.cancelled), isA<LiveExportCancelled>());
    });

    test('permissionDenied maps to a refusal that is not restricted', () {
      expect(
        map(LivePhotoExportStatus.permissionDenied),
        isA<LiveExportRefused>().having((LiveExportRefused refused) => refused.restricted, 'restricted', false),
      );
    });

    test('permissionRestricted maps to a refusal that is restricted', () {
      expect(
        map(LivePhotoExportStatus.permissionRestricted),
        isA<LiveExportRefused>().having((LiveExportRefused refused) => refused.restricted, 'restricted', true),
      );
    });

    test('timedOut maps to LiveExportTimedOut', () {
      expect(map(LivePhotoExportStatus.timedOut), isA<LiveExportTimedOut>());
    });

    test('failed error codes map to their failure reasons', () {
      LiveExportFailure reasonFor(String? code) {
        final LiveExportOutcome outcome = map(LivePhotoExportStatus.failed, errorCode: code);
        return (outcome as LiveExportFailed).reason;
      }

      expect(reasonFor('not-live'), LiveExportFailure.notLive);
      expect(reasonFor('save-failed'), LiveExportFailure.saveFailed);
      expect(reasonFor('render-failed'), LiveExportFailure.renderFailed);
      expect(reasonFor('invalid-request'), LiveExportFailure.invalidRequest);
      expect(reasonFor('encode-failed'), LiveExportFailure.encodeFailed);
      expect(reasonFor(null), LiveExportFailure.encodeFailed);
    });
  });

  group('export', () {
    late Directory directory;
    late _FakeHostApi host;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      directory = Directory.systemTemp.createTempSync('live_photo_repository_test_');
      host = _FakeHostApi();
    });

    tearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    File textureFile() => File('${directory.path}/live_wallpaper_texture.jpg')..writeAsBytesSync(<int>[1, 2, 3]);

    test('sends the export request and deletes the temp texture afterwards', () async {
      final File texture = textureFile();
      final LivePhotoRepositoryImpl repository = LivePhotoRepositoryImpl(
        texturePreparer: _FakeTexturePreparer(texture.path),
        hostApi: host,
      );

      final Future<LiveExportOutcome> export = repository.export(
        const LiveExport(wallId: 'wall-1', style: MotionStyle.drift, sizePx: _phone),
        imageUrl: 'https://example.com/source.jpg',
        tint: _tint,
        onProgress: (double fraction) {},
      );
      final LivePhotoExportRequest request = await host.started.future;
      host.answer.complete(
        LivePhotoExportResult(status: LivePhotoExportStatus.saved, assetId: 'a', verifiedLive: true),
      );
      await export;

      expect(request.widthPx, 1179);
      expect(request.heightPx, 2556);
      expect(request.durationMs, 3000);
      expect(request.framesPerSecond, 30);
      expect(request.style, LivePhotoStyle.drift);
      expect(request.photoPath, texture.path);
      expect(request.depthPath, isNull);
      expect(request.tint, _tint.toARGB32());
      expect(request.timeoutMs, 45000);
      expect(texture.existsSync(), isFalse);
    });

    test('progress reaches the callback only for the active export id', () async {
      final List<double> fractions = <double>[];
      final LivePhotoRepositoryImpl repository = LivePhotoRepositoryImpl(
        texturePreparer: _FakeTexturePreparer(textureFile().path),
        hostApi: host,
      );

      final Future<LiveExportOutcome> export = repository.export(
        const LiveExport(wallId: 'wall-1', style: MotionStyle.drift, sizePx: _phone),
        imageUrl: 'https://example.com/source.jpg',
        tint: _tint,
        onProgress: fractions.add,
      );
      final LivePhotoExportRequest request = await host.started.future;

      repository.onLivePhotoExportProgress(request.exportId, 0.5);
      repository.onLivePhotoExportProgress('live-photo-stale-id', 0.9);
      expect(fractions, <double>[0.5]);

      host.answer.complete(LivePhotoExportResult(status: LivePhotoExportStatus.saved, assetId: 'a'));
      await export;

      repository.onLivePhotoExportProgress(request.exportId, 0.95);
      expect(fractions, <double>[0.5]);
    });

    Future<ByteData?> progressMessage(String id) {
      final Completer<ByteData?> reply = Completer<ByteData?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'dev.flutter.pigeon.Prism.PrismLivePhotoFlutterApi.onLivePhotoExportProgress',
        PrismLivePhotoFlutterApi.pigeonChannelCodec.encodeMessage(<Object?>[id, 0.5]),
        reply.complete,
      );
      return reply.future;
    }

    test('native permission and Photos save are outside the render deadline', () async {
      final LivePhotoRepositoryImpl repository = LivePhotoRepositoryImpl(
        texturePreparer: _FakeTexturePreparer(textureFile().path),
        hostApi: host,
      );
      final List<({Duration duration, Zone zone, void Function() callback, Timer timer})> timers = [];
      final Future<LiveExportOutcome> export = runZoned(
        () => repository.export(
          const LiveExport(wallId: 'wall-1', style: MotionStyle.drift, sizePx: _phone),
          imageUrl: 'https://example.com/source.jpg',
          tint: _tint,
          onProgress: (_) {},
        ),
        zoneSpecification: ZoneSpecification(
          createTimer: (self, parent, zone, duration, callback) {
            final Timer timer = parent.createTimer(zone, const Duration(days: 1), () {});
            timers.add((duration: duration, zone: zone, callback: callback, timer: timer));
            return timer;
          },
        ),
      );
      try {
        await host.started.future;
        for (final pending in timers) {
          if (pending.duration <= const Duration(seconds: 61) && pending.timer.isActive) {
            pending.timer.cancel();
            pending.zone.run(pending.callback);
          }
        }
        await Future<void>.delayed(Duration.zero);
        expect(host.cancelledIds, isEmpty);
        host.answer.complete(LivePhotoExportResult(status: LivePhotoExportStatus.saved, assetId: 'a'));
        expect(await export, isA<LiveExportSaved>());
      } finally {
        for (final pending in timers) {
          pending.timer.cancel();
        }
      }
    });

    test('unregisters the Flutter progress handler after completion', () async {
      final LivePhotoRepositoryImpl repository = LivePhotoRepositoryImpl(
        texturePreparer: _FakeTexturePreparer(textureFile().path),
        hostApi: host,
      );
      final Future<LiveExportOutcome> export = repository.export(
        const LiveExport(wallId: 'wall-1', style: MotionStyle.drift, sizePx: _phone),
        imageUrl: 'https://example.com/source.jpg',
        tint: _tint,
        onProgress: (_) {},
      );
      final LivePhotoExportRequest request = await host.started.future;
      expect(await progressMessage(request.exportId), isNotNull);
      host.answer.complete(LivePhotoExportResult(status: LivePhotoExportStatus.cancelled));
      await export;

      expect(await progressMessage(request.exportId), isNull);
    });

    test('cancel unregisters the handler before the native response arrives', () async {
      final LivePhotoRepositoryImpl repository = LivePhotoRepositoryImpl(
        texturePreparer: _FakeTexturePreparer(textureFile().path),
        hostApi: host,
      );
      final Future<LiveExportOutcome> export = repository.export(
        const LiveExport(wallId: 'wall-1', style: MotionStyle.drift, sizePx: _phone),
        imageUrl: 'https://example.com/source.jpg',
        tint: _tint,
        onProgress: (_) {},
      );
      final LivePhotoExportRequest request = await host.started.future;
      await repository.cancel();

      expect(await progressMessage(request.exportId), isNull);
      expect(host.cancelledIds, <String>[request.exportId]);
      host.answer.complete(LivePhotoExportResult(status: LivePhotoExportStatus.cancelled));
      await export;
    });

    test('a late native result cannot turn a cancelled export into a saved one', () async {
      final LivePhotoRepositoryImpl repository = LivePhotoRepositoryImpl(
        texturePreparer: _FakeTexturePreparer(textureFile().path),
        hostApi: host,
      );
      final Future<LiveExportOutcome> export = repository.export(
        const LiveExport(wallId: 'wall-1', style: MotionStyle.drift, sizePx: _phone),
        imageUrl: 'https://example.com/source.jpg',
        tint: _tint,
        onProgress: (_) {},
      );
      await host.started.future;
      await repository.cancel();
      host.answer.complete(LivePhotoExportResult(status: LivePhotoExportStatus.saved, assetId: 'old'));

      expect(await export, isA<LiveExportCancelled>());
    });

    test('3D without a depth map fails as an invalid request and never calls the host', () async {
      final _FakeTexturePreparer preparer = _FakeTexturePreparer(textureFile().path);
      final LivePhotoRepositoryImpl repository = LivePhotoRepositoryImpl(texturePreparer: preparer, hostApi: host);

      final LiveExportOutcome outcome = await repository.export(
        const LiveExport(wallId: 'wall-1', style: MotionStyle.depth, sizePx: _phone),
        imageUrl: 'https://example.com/source.jpg',
        tint: _tint,
        onProgress: (double fraction) {},
      );

      expect(
        outcome,
        isA<LiveExportFailed>().having(
          (LiveExportFailed failed) => failed.reason,
          'reason',
          LiveExportFailure.invalidRequest,
        ),
      );
      expect(host.exportRequests, isEmpty);
      expect(preparer.imageUrls, isEmpty);
    });
  });
}
