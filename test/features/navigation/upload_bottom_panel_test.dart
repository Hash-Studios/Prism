import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/durable_json_store.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/upload_quota.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/navigation/views/widgets/upload_bottom_panel.dart';
import 'package:Prism/features/wallpaper_upload/biz/submission_metadata.dart';
import 'package:Prism/features/wallpaper_upload/data/upload_draft_store.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';
import '../../support/pending_image_picker.dart';
import '../../support/wait_for_real_io.dart';

class _Picker extends ImagePickerPlatform {
  _Picker(this.paths);

  final List<String> paths;
  int? multiLimit;
  int singleCalls = 0;

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async {
    multiLimit = options.limit;
    return paths.map(XFile.new).toList();
  }

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    singleCalls++;
    return XFile(paths.first);
  }
}

class _PanelRouter extends AppRouter {
  _PanelRouter(this.onEdit, {this.onResume, this.draftStore});

  final void Function(EditWallRouteArgs args) onEdit;
  final void Function(UploadWallRouteArgs args)? onResume;
  final UploadDraftStore? draftStore;

  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(
      path: '/',
      page: PageInfo(
        'PanelHost',
        builder: (_) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showPrismSheet<void>(context, builder: (_) => UploadBottomPanel(draftStoreForTesting: draftStore)),
              child: const Text('Open panel'),
            ),
          ),
        ),
      ),
    ),
    AutoRoute(
      path: '/edit-wall',
      page: PageInfo(
        EditWallRoute.name,
        builder: (data) {
          onEdit(data.argsAs<EditWallRouteArgs>());
          return const Scaffold(body: Text('edit-stub'));
        },
      ),
    ),
    AutoRoute(
      path: '/upload-wall',
      page: PageInfo(
        UploadWallRoute.name,
        builder: (data) {
          onResume?.call(data.argsAs<UploadWallRouteArgs>());
          return const Scaffold(body: Text('upload-resume-stub'));
        },
      ),
    ),
  ];
}

class _ObservedUploadDraftStore extends UploadDraftStore {
  _ObservedUploadDraftStore({required super.store, required super.directory});

  final Completer<void> latestLookupCompleted = Completer<void>();

  @override
  Future<UploadDraft?> latestForOwner(String owner) async {
    try {
      return await super.latestForOwner(owner);
    } finally {
      if (!latestLookupCompleted.isCompleted) latestLookupCompleted.complete();
    }
  }
}

class _EmptyUploadDraftStore extends UploadDraftStore {
  @override
  Future<UploadDraft?> latestForOwner(String owner) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ImagePickerPlatform previousPicker;
  late SettingsLocalDataSource settings;

  setUp(() async {
    previousPicker = ImagePickerPlatform.instance;
    await getIt.reset();
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..loggedIn = true
      ..id = 'upload-user';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (_) async => true,
    );
  });

  tearDown(() async {
    ImagePickerPlatform.instance = previousPicker;
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      null,
    );
    await getIt.reset();
  });

  Future<List<EditWallRouteArgs>> openPanel(WidgetTester tester, ImagePickerPlatform picker) async {
    ImagePickerPlatform.instance = picker;
    final opened = <EditWallRouteArgs>[];
    final router = _PanelRouter(opened.add, draftStore: _EmptyUploadDraftStore());
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.config(),
      ),
    );
    await router.navigatePath('/');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open panel'));
    await tester.pumpAndSettle();
    return opened;
  }

  Future<List<EditWallRouteArgs>> pickWith(WidgetTester tester, _Picker picker) async {
    final opened = await openPanel(tester, picker);
    await tester.tap(find.text('Upload wallpaper'));
    await tester.pumpAndSettle();
    return opened;
  }

  for (final uploads in [0, UploadQuota.freeUploadsPerWeek]) {
    testWidgets('guest upload cancellation with $uploads previous uploads starts neither picker nor paywall', (
      tester,
    ) async {
      app_state.prismUser = app_constants.createGuestPrismUser();
      await settings.set('uploadsWeekStart', _thisWeekStart());
      await settings.set('uploadsThisWeek', uploads);
      final picker = _Picker(<String>['/tmp/unused.png']);
      final opened = await openPanel(tester, picker);
      final storeCalls = <String>[];
      final toasts = <String>[];
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const purchases = MethodChannel('purchases_flutter');
      const paywalls = MethodChannel('purchases_ui_flutter');
      const toast = MethodChannel('PonnamKarthik/fluttertoast');
      for (final channel in [purchases, paywalls]) {
        messenger.setMockMethodCallHandler(channel, (call) async {
          storeCalls.add(call.method);
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      }
      messenger.setMockMethodCallHandler(toast, (call) async {
        if (call.method == 'showToast') toasts.add((call.arguments as Map)['msg'] as String);
        return true;
      });

      await tester.tap(find.text('Upload wallpaper'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(picker.multiLimit, isNull);
      expect(storeCalls, isEmpty);
      expect(toasts, isEmpty);
      await tester.tap(find.text('Not now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(opened, isEmpty);
      expect(picker.multiLimit, isNull);
      expect(storeCalls, isEmpty);
      expect(toasts, isEmpty);
      expect(settings.get<int>('uploadsThisWeek', defaultValue: -1), uploads);
      expect(find.text('Upload wallpaper'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('a free user can pick as many images as the week has slots left', (tester) async {
    await settings.set('uploadsWeekStart', _thisWeekStart());
    await settings.set('uploadsThisWeek', 1);
    final picker = _Picker(<String>['/tmp/a.png', '/tmp/b.png']);

    final opened = await pickWith(tester, picker);

    expect(UploadQuota.remainingFreeUploadsThisWeek(), 2);
    expect(picker.multiLimit, 2);
    expect(opened.single.image.path, '/tmp/a.png');
    expect(opened.single.batch!.total, 2);
    expect(find.text('edit-stub'), findsOneWidget);
  });

  testWidgets('one image starts the normal single upload with no batch', (tester) async {
    final picker = _Picker(<String>['/tmp/a.png']);

    final opened = await pickWith(tester, picker);

    expect(opened.single.batch, isNull);
  });

  testWidgets('a Prism Pro user can pick ten and extra images are dropped', (tester) async {
    app_state.prismUser.premium = true;
    final picker = _Picker(<String>[for (var i = 0; i < 12; i++) '/tmp/$i.png']);

    final opened = await pickWith(tester, picker);

    expect(picker.multiLimit, 10);
    expect(opened.single.batch!.total, 10);
  });

  testWidgets('a second tap while the gallery is open does not open it again', (tester) async {
    final picker = PendingImagePicker();
    final opened = await openPanel(tester, picker);

    await tester.tap(find.text('Upload wallpaper'));
    await tester.pump();
    await tester.tap(find.text('Upload wallpaper'));
    await tester.pump();

    expect(picker.calls, 1);
    picker.finish(<String>['/tmp/a.png']);
    await tester.pumpAndSettle();
    expect(opened.single.image.path, '/tmp/a.png');
  });

  testWidgets('a gallery another screen holds open is not an error', (tester) async {
    final picker = PendingImagePicker();
    final opened = await openPanel(tester, picker);
    unawaited(picker.getImageFromSource(source: ImageSource.gallery));

    await tester.tap(find.text('Upload wallpaper'));
    await tester.pumpAndSettle();

    expect(picker.calls, 2);
    expect(opened, isEmpty);
    expect(find.text('Upload wallpaper'), findsOneWidget);
  });

  testWidgets('resumes the latest owner draft from its retained copy without opening the picker', (tester) async {
    final (Directory root, _ObservedUploadDraftStore drafts, File pickedOriginal, UploadDraft retained) = (await tester
        .runAsync(() async {
          final Directory root = await Directory.systemTemp.createTemp('prism-upload-entry-test');
          final _ObservedUploadDraftStore drafts = _ObservedUploadDraftStore(
            store: DurableJsonStore('upload_entry_test', directory: Directory('${root.path}/records')),
            directory: Directory('${root.path}/app-support/prism/offline/upload_drafts'),
          );
          final File original = File('${root.path}/picker-source.png')..writeAsBytesSync(utf8.encode('image-bytes'));
          final UploadDraft draft = await drafts.save(
            owner: 'upload-user',
            draftId: 'saved-draft',
            selectedFile: original,
            metadata: const SubmissionMetadata(title: 'My saved wallpaper'),
          );
          return (root, drafts, original, draft);
        }))!;
    addTearDown(() async {
      await tester.runAsync(() => root.delete(recursive: true));
    });
    await tester.runAsync(() async {
      await pickedOriginal.delete();
    });
    final picker = _Picker(<String>['/tmp/unused.png']);
    ImagePickerPlatform.instance = picker;
    final resumed = <UploadWallRouteArgs>[];
    final router = _PanelRouter((_) {}, onResume: resumed.add, draftStore: drafts);
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router.config(),
      ),
    );
    await router.navigatePath('/');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open panel'));
    await tester.pumpAndSettle();
    await waitForRealIo(
      tester,
      () => drafts.latestLookupCompleted.isCompleted && find.text('Resume saved upload').evaluate().isNotEmpty,
      reason: 'the retained upload draft lookup to complete and appear in the panel',
    );

    expect(find.text('Resume saved upload'), findsOneWidget);
    expect(find.text('My saved wallpaper'), findsOneWidget);
    await tester.tap(find.text('Resume saved upload'));
    await tester.pumpAndSettle();

    expect(resumed.single.image.path, retained.file.path);
    expect(await tester.runAsync(() => File(resumed.single.image.path).exists()), isTrue);
    expect(picker.multiLimit, isNull);
  });
}

String _thisWeekStart() {
  final now = DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - DateTime.monday)).toIso8601String();
}
