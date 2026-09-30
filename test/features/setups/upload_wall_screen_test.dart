import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as wall_store;
import 'package:Prism/features/setups/views/pages/upload_wall_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<File> makeImage(WidgetTester tester) async {
    final tempDirectory = (await tester.runAsync(() => Directory.systemTemp.createTemp('prism-upload-wall-')))!;
    addTearDown(() => tester.runAsync(() => tempDirectory.delete(recursive: true)));
    final image = File('${tempDirectory.path}/pixel.png');
    await tester.runAsync(
      () => image.writeAsBytes(
        base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC'),
      ),
    );
    return image;
  }

  Future<void> setViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpImagePreparation(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }

  testWidgets('prepares locally, blocks duplicate taps while busy, then returns setup result', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final fullUpload = Completer<GitHubContent>();
    final save = Completer<wall_store.WallSubmissionResult>();
    var uploadCalls = 0;
    var saveCalls = 0;
    Object? routeResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  routeResult = await Navigator.of(context).push<Object?>(
                    MaterialPageRoute(
                      builder: (_) => UploadWallScreen(
                        image: image,
                        fromSetupRoute: true,
                        prepareImageForTesting: () async {},
                        uploadFileForTesting: ({required isThumbnail}) {
                          uploadCalls++;
                          if (isThumbnail) {
                            return Future.value(
                              const GitHubContent(
                                downloadUrl: 'https://example.test/thumb.png',
                                path: 'thumb_pixel.png',
                                sha: 'thumb-sha',
                              ),
                            );
                          }
                          return fullUpload.future;
                        },
                        createRecordForTesting: () {
                          saveCalls++;
                          return save.future;
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Open uploader'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open uploader'));
    await pumpImagePreparation(tester);

    expect(find.text('Ready to submit'), findsOneWidget);
    expect(find.text('Use this wallpaper'), findsOneWidget);
    expect(uploadCalls, 0);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Use this wallpaper'));
    await tester.pump();
    expect(find.text('Uploading…'), findsOneWidget);
    await tester.tap(find.text('Uploading…'), warnIfMissed: false);
    await tester.pump();
    expect(uploadCalls, 1);
    expect(saveCalls, 0);

    fullUpload.complete(
      const GitHubContent(downloadUrl: 'https://example.test/wall.png', path: 'pixel.png', sha: 'wall-sha'),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Submitting…'), findsOneWidget);
    expect(saveCalls, 1);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(routeResult, isNull);

    save.complete(wall_store.WallSubmissionResult.submitted);
    await tester.pumpAndSettle();
    expect(routeResult, isA<List<Object?>>());
    expect((routeResult! as List<Object?>).first, 'https://example.test/wall.png');
    expect(find.text('Upload wallpaper'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a weekly quota result without retrying a save', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    var saveCalls = 0;
    final deletedFiles = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: UploadWallScreen(
          image: image,
          fromSetupRoute: false,
          prepareImageForTesting: () async {},
          uploadFileForTesting: ({required isThumbnail}) async => isThumbnail
              ? const GitHubContent(
                  downloadUrl: 'https://example.test/thumb.png',
                  path: 'thumb_pixel.png',
                  sha: 'thumb-sha',
                )
              : const GitHubContent(downloadUrl: 'https://example.test/wall.png', path: 'pixel.png', sha: 'wall-sha'),
          deleteFileForTesting: ({required path, required sha}) async {
            deletedFiles.add(path);
          },
          createRecordForTesting: () async {
            saveCalls++;
            return wall_store.WallSubmissionResult.quotaExceeded;
          },
        ),
      ),
    );
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();

    expect(find.text('Upload limit reached'), findsOneWidget);
    expect(find.text('You have reached this week’s free wallpaper upload limit.'), findsOneWidget);
    expect(saveCalls, 1);
    expect(deletedFiles, ['pixel.png', 'thumb_pixel.png']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps an uncertain save visible and offers status check, not retry', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    var saveCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UploadWallScreen(
          image: image,
          fromSetupRoute: false,
          prepareImageForTesting: () async {},
          uploadFileForTesting: ({required isThumbnail}) async => isThumbnail
              ? const GitHubContent(
                  downloadUrl: 'https://example.test/thumb.png',
                  path: 'thumb_pixel.png',
                  sha: 'thumb-sha',
                )
              : const GitHubContent(downloadUrl: 'https://example.test/wall.png', path: 'pixel.png', sha: 'wall-sha'),
          createRecordForTesting: () {
            saveCalls++;
            return Future<wall_store.WallSubmissionResult>.error(StateError('network response was lost'));
          },
        ),
      ),
    );
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();

    expect(find.text('Submission did not finish'), findsOneWidget);
    expect(find.text('Check review status'), findsOneWidget);
    expect(find.text('Retry submission'), findsNothing);
    expect(saveCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
