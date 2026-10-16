import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/platform/prism_media_api.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Answers [method] with [replies] in order and returns the call count.
  List<int> mock(String method, List<Object> replies) {
    final calls = <int>[0];
    final channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.Prism.PrismMediaHostApi.$method',
      PrismMediaHostApi.pigeonChannelCodec,
    );
    messenger.setMockDecodedMessageHandler<Object?>(channel, (_) async => <Object?>[replies[calls[0]++]]);
    addTearDown(() => messenger.setMockDecodedMessageHandler<Object?>(channel, null));
    return calls;
  }

  OperationResult detached() => OperationResult(success: false, errorCode: PrismMediaApi.engineDetached);
  OperationResult ok() => OperationResult(success: true);

  test('every call tries once more after ENGINE_DETACHED', () async {
    final api = PrismMediaApi();
    final save = mock('saveMedia', [detached(), ok()]);
    final download = mock('enqueueDownload', [detached(), ok()]);
    final clear = mock('clearDownloads', [detached(), ok()]);
    final delete = mock('deleteDownload', [detached(), ok()]);
    final list = mock('listDownloads', [
      DownloadItemsResult(success: false, items: <String>[], errorCode: PrismMediaApi.engineDetached),
      DownloadItemsResult(success: true, items: <String>['/a.jpg']),
    ]);

    expect(
      (await api.saveMedia(SaveMediaRequest(link: 'l', isLocalFile: false, kind: SaveMediaKind.wallpaper))).success,
      isTrue,
    );
    expect(
      (await api.enqueueDownload(
        DownloadRequest(link: 'l', isLocalFile: false, filenameWithoutExtension: 'f'),
      )).success,
      isTrue,
    );
    expect((await api.clearDownloads()).success, isTrue);
    expect((await api.deleteDownload('/a.jpg')).success, isTrue);
    expect((await api.listDownloads()).items, <String>['/a.jpg']);
    expect([save, download, clear, delete, list].map((calls) => calls[0]), everyElement(2));
  });

  test('a second ENGINE_DETACHED is returned, not retried again', () async {
    final calls = mock('clearDownloads', [detached(), detached(), ok()]);

    final result = await PrismMediaApi().clearDownloads();

    expect(result.errorCode, PrismMediaApi.engineDetached);
    expect(calls[0], 2);
  });

  test('other failures are returned at once', () async {
    final calls = mock('clearDownloads', [OperationResult(success: false, errorCode: 'NO_DOWNLOADS'), ok()]);

    final result = await PrismMediaApi().clearDownloads();

    expect(result.errorCode, 'NO_DOWNLOADS');
    expect(calls[0], 1);
  });
}
