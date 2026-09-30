import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/data/upload/github_content_api.dart';
import 'package:Prism/data/upload/wallpaper/wallfirestore.dart' as wall_store;
import 'package:Prism/features/wallpaper_upload/views/pages/upload_wall_screen.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/fake_app_analytics.dart';

class _TestAppRouter extends AppRouter {
  _TestAppRouter(this.uploadRoute);

  final UploadWallRoute Function() uploadRoute;

  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(
      path: '/',
      page: PageInfo('UploadRouteHost', builder: (_) => Scaffold(body: _UploadRouteHost(uploadRoute))),
    ),
    AutoRoute(path: '/upload-wall', page: UploadWallRoute.page),
    AutoRoute(
      path: '/review',
      page: PageInfo(ReviewRoute.name, builder: (_) => const Scaffold(body: Text('review-stub'))),
    ),
  ];
}

class _UploadRouteHost extends StatelessWidget {
  const _UploadRouteHost(this.uploadRoute);

  final UploadWallRoute Function() uploadRoute;

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: () => context.router.push<Object?>(uploadRoute()), child: const Text('Open uploader'));
}

/// Opens [route] from a host page inside a real [AppRouter], so a successful submit can push [ReviewRoute].
Future<void> pumpRoutedUpload(WidgetTester tester, UploadWallRoute Function() route) async {
  final router = _TestAppRouter(route);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
  await router.navigatePath('/');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open uploader'));
}

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

  testWidgets('prepares locally, blocks duplicate taps while busy, then opens review status', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final fullUpload = Completer<GitHubContent>();
    final save = Completer<wall_store.WallSubmissionResult>();
    var uploadCalls = 0;
    var saveCalls = 0;

    await pumpRoutedUpload(
      tester,
      () => UploadWallRoute(
        image: image,
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
    );
    await pumpImagePreparation(tester);
    await tester.pumpAndSettle();

    expect(find.text('Ready to submit'), findsOneWidget);
    expect(find.text('Submit for review'), findsOneWidget);
    expect(uploadCalls, 0);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Submit for review'));
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
    expect(find.text('Submitting…'), findsOneWidget);

    save.complete(wall_store.WallSubmissionResult.submitted);
    await tester.pumpAndSettle();
    expect(find.text('review-stub'), findsOneWidget);
    expect(find.text('Upload wallpaper'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tracks a confirmed upload once when the screen was popped while saving', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final save = Completer<wall_store.WallSubmissionResult>();
    final recorder = FakeAppAnalytics();
    AnalyticsRuntime.instance = recorder;
    addTearDown(AnalyticsRuntime.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => UploadWallScreen(
                    image: image,
                    prepareImageForTesting: () async {},
                    uploadFileForTesting: ({required isThumbnail}) async => isThumbnail
                        ? const GitHubContent(
                            downloadUrl: 'https://example.test/thumb.png',
                            path: 'thumb_pixel.png',
                            sha: 'thumb-sha',
                          )
                        : const GitHubContent(
                            downloadUrl: 'https://example.test/wall.png',
                            path: 'pixel.png',
                            sha: 'wall-sha',
                          ),
                    createRecordForTesting: () => save.future,
                  ),
                ),
              ),
              child: const Text('Open uploader'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open uploader'));
    await tester.pump(const Duration(milliseconds: 400));
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Submit for review'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Submitting wallpaper'), findsOneWidget);

    Navigator.of(tester.element(find.text('Submitting wallpaper'))).pop();
    await tester.pumpAndSettle();
    save.complete(wall_store.WallSubmissionResult.submitted);
    await tester.pump();

    final uploads = recorder.events.whereType<UploadWallpaperEvent>().toList();
    expect(uploads, hasLength(1));
    expect(uploads.single.assetId, isNotEmpty);
    expect(uploads.single.link, 'https://example.test/wall.png');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a confirmed submit closes the uploader and opens review status', (tester) async {
    await setViewport(tester);
    await pumpRoutedUpload(
      tester,
      () => UploadWallRoute(
        image: File('test-image.png'),
        prepareImageForTesting: () async {},
        uploadFileForTesting: ({required isThumbnail}) async => isThumbnail
            ? const GitHubContent(
                downloadUrl: 'https://example.test/thumb.png',
                path: 'thumb_test-image.png',
                sha: 'thumb-sha',
              )
            : const GitHubContent(
                downloadUrl: 'https://example.test/wall.png',
                path: 'test-image.png',
                sha: 'wall-sha',
              ),
        createRecordForTesting: () async => wall_store.WallSubmissionResult.submitted,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();

    expect(find.text('review-stub'), findsOneWidget);
    expect(find.text('Upload wallpaper'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stage title has readable contrast in every legacy theme', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final themes = <ThemeData>[
      kLightTheme,
      kLightTheme2,
      kLightTheme3,
      kLightTheme4,
      kDarkTheme,
      kDarkTheme2,
      kDarkTheme3,
      kDarkTheme4,
      kDarkTheme5,
      kDarkTheme6,
      kDarkTheme7,
      kDarkTheme8,
    ];

    for (final theme in themes) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          themeAnimationDuration: Duration.zero,
          home: UploadWallScreen(image: image, prepareImageForTesting: () async {}),
        ),
      );
      await pumpImagePreparation(tester);

      final titleFinder = find.text('Ready to submit');
      final effectiveTheme = Theme.of(tester.element(titleFinder));
      final titleColor = tester.widget<Text>(titleFinder).style!.color!;
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      final scaffoldBackground = scaffold.backgroundColor ?? effectiveTheme.scaffoldBackgroundColor;
      expect(_contrastRatio(titleColor, scaffoldBackground), greaterThanOrEqualTo(4.5));
      expect(titleColor, effectiveTheme.colorScheme.onSurface);
    }
  });

  testWidgets('shows a weekly quota result without retrying a save', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final recorder = FakeAppAnalytics();
    AnalyticsRuntime.instance = recorder;
    addTearDown(AnalyticsRuntime.reset);
    var saveCalls = 0;
    final deletedFiles = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: UploadWallScreen(
          image: image,
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
    expect(recorder.events.whereType<UploadWallpaperEvent>(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the quota screen open when file cleanup fails and lets Back retry cleanup', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    var deleteCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UploadWallScreen(
          image: image,
          prepareImageForTesting: () async {},
          uploadFileForTesting: ({required isThumbnail}) async => isThumbnail
              ? const GitHubContent(
                  downloadUrl: 'https://example.test/thumb.png',
                  path: 'thumb_pixel.png',
                  sha: 'thumb-sha',
                )
              : const GitHubContent(downloadUrl: 'https://example.test/wall.png', path: 'pixel.png', sha: 'wall-sha'),
          deleteFileForTesting: ({required path, required sha}) async {
            deleteCalls++;
            if (deleteCalls <= 2) throw StateError('temporary cleanup failure');
          },
          createRecordForTesting: () async => wall_store.WallSubmissionResult.quotaExceeded,
        ),
      ),
    );
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Discard this upload?'), findsOneWidget);
    await tester.tap(find.text('Discard upload'));
    await tester.pumpAndSettle();
    expect(find.text('Upload limit reached'), findsOneWidget);
    expect(find.text('Could not remove uploaded files. Try again.'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.text('Upload limit reached'))).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard upload'));
    await tester.pumpAndSettle();
    expect(find.text('Upload limit reached'), findsNothing);
    expect(deleteCalls, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps an uncertain save visible and offers status check, not retry', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final recorder = FakeAppAnalytics();
    AnalyticsRuntime.instance = recorder;
    addTearDown(AnalyticsRuntime.reset);
    var saveCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UploadWallScreen(
          image: image,
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
    expect(recorder.events.whereType<UploadWallpaperEvent>(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deletes the wallpaper when thumbnail upload fails after the screen is removed', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final thumbnailUpload = Completer<GitHubContent>();
    final deletedFiles = <String>[];
    var uploadCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UploadWallScreen(
          image: image,
          prepareImageForTesting: () async {},
          uploadFileForTesting: ({required isThumbnail}) {
            uploadCalls++;
            return isThumbnail
                ? thumbnailUpload.future
                : Future.value(
                    const GitHubContent(
                      downloadUrl: 'https://example.test/wall.png',
                      path: 'pixel.png',
                      sha: 'wall-sha',
                    ),
                  );
          },
          deleteFileForTesting: ({required path, required sha}) async => deletedFiles.add(path),
          createRecordForTesting: () async => wall_store.WallSubmissionResult.submitted,
        ),
      ),
    );
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Submit for review'));
    await tester.pump();
    await tester.pump();
    expect(uploadCalls, 2);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    thumbnailUpload.completeError(StateError('request failed'));
    await tester.pump();
    await tester.pump();

    expect(deletedFiles, ['pixel.png']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deletes staged files when the idle screen is removed externally', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final deletedFiles = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: UploadWallScreen(
          image: image,
          prepareImageForTesting: () async {},
          uploadFileForTesting: ({required isThumbnail}) async {
            if (isThumbnail) throw StateError('preview upload failed');
            return const GitHubContent(
              downloadUrl: 'https://example.test/wall.png',
              path: 'pixel.png',
              sha: 'wall-sha',
            );
          },
          deleteFileForTesting: ({required path, required sha}) async => deletedFiles.add(path),
        ),
      ),
    );
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();
    expect(find.text('Upload did not finish'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    expect(deletedFiles, ['pixel.png']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps partial GitHub file details so discard can remove an incomplete upload', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final deletedFiles = <String>[];
    Object? routeResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                routeResult = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute(
                    builder: (_) => UploadWallScreen(
                      image: image,
                      prepareImageForTesting: () async {},
                      uploadFileForTesting: ({required isThumbnail}) async =>
                          const GitHubContent(downloadUrl: null, path: 'pixel.png', sha: 'wall-sha'),
                      deleteFileForTesting: ({required path, required sha}) async => deletedFiles.add(path),
                    ),
                  ),
                );
              },
              child: const Text('Open uploader'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open uploader'));
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard this upload?'), findsOneWidget);
    await tester.tap(find.text('Discard upload'));
    await tester.pumpAndSettle();
    expect(deletedFiles, ['pixel.png']);
    expect(routeResult, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cleans an incomplete GitHub file before retrying its upload', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final deletedFiles = <String>[];
    var wallpaperCalls = 0;
    var thumbnailCalls = 0;

    await pumpRoutedUpload(
      tester,
      () => UploadWallRoute(
        image: image,
        prepareImageForTesting: () async {},
        uploadFileForTesting: ({required isThumbnail}) async {
          if (isThumbnail) {
            thumbnailCalls++;
            return const GitHubContent(
              downloadUrl: 'https://example.test/thumb.png',
              path: 'thumb_pixel.png',
              sha: 'thumb-sha',
            );
          }
          wallpaperCalls++;
          return GitHubContent(
            downloadUrl: wallpaperCalls == 1 ? null : 'https://example.test/wall.png',
            path: 'pixel.png',
            sha: 'wall-sha-$wallpaperCalls',
          );
        },
        deleteFileForTesting: ({required path, required sha}) async => deletedFiles.add(path),
        createRecordForTesting: () async => wall_store.WallSubmissionResult.submitted,
      ),
    );
    await pumpImagePreparation(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();

    expect(wallpaperCalls, 2);
    expect(thumbnailCalls, 1);
    expect(deletedFiles, ['pixel.png']);
    expect(find.text('Submission did not finish'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reuses the wallpaper and retries only the failed thumbnail upload', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    var wallpaperCalls = 0;
    var thumbnailCalls = 0;
    var saveCalls = 0;

    await pumpRoutedUpload(
      tester,
      () => UploadWallRoute(
        image: image,
        prepareImageForTesting: () async {},
        uploadFileForTesting: ({required isThumbnail}) async {
          if (isThumbnail) {
            thumbnailCalls++;
            if (thumbnailCalls == 1) throw StateError('temporary preview failure');
            return const GitHubContent(
              downloadUrl: 'https://example.test/thumb.png',
              path: 'thumb_pixel.png',
              sha: 'thumb-sha',
            );
          }
          wallpaperCalls++;
          return const GitHubContent(downloadUrl: 'https://example.test/wall.png', path: 'pixel.png', sha: 'wall-sha');
        },
        createRecordForTesting: () async {
          saveCalls++;
          return wall_store.WallSubmissionResult.submitted;
        },
      ),
    );
    await pumpImagePreparation(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();
    expect(find.text('Upload did not finish'), findsOneWidget);

    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();

    expect(wallpaperCalls, 1);
    expect(thumbnailCalls, 2);
    expect(saveCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the requested path to discard a response missing URL and path', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final deletedFiles = <String>[];
    Object? routeResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                routeResult = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute(
                    builder: (_) => UploadWallScreen(
                      image: image,
                      prepareImageForTesting: () async {},
                      uploadFileForTesting: ({required isThumbnail}) async =>
                          const GitHubContent(downloadUrl: null, path: null, sha: 'wall-sha'),
                      deleteFileForTesting: ({required path, required sha}) async => deletedFiles.add(path),
                    ),
                  ),
                );
              },
              child: const Text('Open uploader'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open uploader'));
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard this upload?'), findsOneWidget);
    await tester.tap(find.text('Discard upload'));
    await tester.pumpAndSettle();
    expect(deletedFiles, ['pixel.png']);
    expect(routeResult, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the thumbnail path to discard a response missing URL and path', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final deletedFiles = <String>[];
    Object? routeResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                routeResult = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute(
                    builder: (_) => UploadWallScreen(
                      image: image,
                      prepareImageForTesting: () async {},
                      uploadFileForTesting: ({required isThumbnail}) async => isThumbnail
                          ? const GitHubContent(downloadUrl: null, path: null, sha: 'thumb-sha')
                          : const GitHubContent(
                              downloadUrl: 'https://example.test/wall.png',
                              path: 'pixel.png',
                              sha: 'wall-sha',
                            ),
                      deleteFileForTesting: ({required path, required sha}) async => deletedFiles.add(path),
                    ),
                  ),
                );
              },
              child: const Text('Open uploader'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open uploader'));
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard this upload?'), findsOneWidget);
    await tester.tap(find.text('Discard upload'));
    await tester.pumpAndSettle();
    expect(deletedFiles, ['pixel.png', 'thumb_pixel.png']);
    expect(routeResult, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not restart an incomplete upload after direct pop during cleanup', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final cleanup = Completer<void>();
    var uploadCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => UploadWallScreen(
                      image: image,
                      prepareImageForTesting: () async {},
                      uploadFileForTesting: ({required isThumbnail}) async {
                        uploadCalls++;
                        return const GitHubContent(downloadUrl: null, path: 'pixel.png', sha: 'wall-sha');
                      },
                      deleteFileForTesting: ({required path, required sha}) => cleanup.future,
                    ),
                  ),
                );
              },
              child: const Text('Open uploader'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open uploader'));
    await pumpImagePreparation(tester);
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();
    expect(uploadCalls, 1);

    await tester.tap(find.text('Submit for review'));
    await tester.pump();
    Navigator.of(tester.element(find.text('Uploading…'))).pop();
    await tester.pump(const Duration(milliseconds: 10));
    cleanup.complete();
    await tester.pumpAndSettle();

    expect(uploadCalls, 1);
    expect(find.text('Upload wallpaper'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancels submission and removes both files when directly popped during thumbnail upload', (tester) async {
    await setViewport(tester);
    final image = await makeImage(tester);
    final thumbnailUpload = Completer<GitHubContent>();
    final deletedFiles = <String>[];
    var saveCalls = 0;
    Object? routeResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                routeResult = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute(
                    builder: (_) => UploadWallScreen(
                      image: image,
                      prepareImageForTesting: () async {},
                      uploadFileForTesting: ({required isThumbnail}) => isThumbnail
                          ? thumbnailUpload.future
                          : Future.value(
                              const GitHubContent(
                                downloadUrl: 'https://example.test/wall.png',
                                path: 'pixel.png',
                                sha: 'wall-sha',
                              ),
                            ),
                      deleteFileForTesting: ({required path, required sha}) async => deletedFiles.add(path),
                      createRecordForTesting: () async {
                        saveCalls++;
                        return wall_store.WallSubmissionResult.submitted;
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
    );
    await tester.tap(find.text('Open uploader'));
    await pumpImagePreparation(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit for review'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Uploading…'), findsOneWidget);

    Navigator.of(tester.element(find.text('Uploading…'))).pop();
    await tester.pump(const Duration(milliseconds: 10));
    thumbnailUpload.complete(
      const GitHubContent(downloadUrl: 'https://example.test/thumb.png', path: 'thumb_pixel.png', sha: 'thumb-sha'),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(saveCalls, 0);
    expect(deletedFiles, ['pixel.png', 'thumb_pixel.png']);
    expect(routeResult, isNull);
    expect(tester.takeException(), isNull);
  });
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance ? foregroundLuminance : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance ? backgroundLuminance : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
