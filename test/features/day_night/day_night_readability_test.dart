import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/day_night/biz/bloc/day_night_bloc.j.dart';
import 'package:Prism/features/day_night/data/repositories/day_night_repository_impl.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/day_night/domain/repositories/day_night_repository.dart';
import 'package:Prism/features/day_night/views/widgets/day_night_readability_tip.dart';
import 'package:Prism/features/ios_shortcuts/data/native_asset_paths_store.dart';
import 'package:Prism/features/readability/data/readability_tips.dart';
import 'package:Prism/features/readability/domain/readability.dart';
import 'package:Prism/features/readability/views/readability_views.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:Prism/features/wallpaper_position/domain/repositories/wallpaper_position_repository.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:async_wallpaper/pigeon_impl_api.dart' as pigeon;
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/in_memory_local_store.dart';
import '../../support/profile_user_fixture.dart';

const String _snapshotKey = 'shortcuts.day_night';

const _codec = pigeon.WallpaperApi.pigeonChannelCodec;

const ReadabilityFix _clockDim = ReadabilityFix(ReadabilityZone.clock, ReadabilityFixKind.dim);
const ReadabilityFix _iconsBlur = ReadabilityFix(ReadabilityZone.icons, ReadabilityFixKind.blur);

/// Replaces the host handler for one WallpaperApi method and removes it after the test.
/// Same channel and teardown as async_wallpaper's daily_schedule_test.dart.
void _mockHostMethod(String method, Future<ByteData?> Function(ByteData? message) handler) {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channel = 'dev.flutter.pigeon.async_wallpaper.WallpaperApi.$method';
  messenger.setMockMessageHandler(channel, handler);
  addTearDown(() => messenger.setMockMessageHandler(channel, null));
}

const DayNightWall _httpsDay = DayNightWall(
  id: 'day',
  source: WallpaperSource.prism,
  fullUrl: 'https://example.com/day.jpg',
  thumbnailUrl: 'https://example.com/day-thumb.jpg',
);

const DayNightWall _httpsNight = DayNightWall(
  id: 'night',
  source: WallpaperSource.prism,
  fullUrl: 'https://example.com/night.jpg',
  thumbnailUrl: 'https://example.com/night-thumb.jpg',
);

const DayNightWall _protected = DayNightWall(
  id: 'locked',
  source: WallpaperSource.prism,
  fullUrl: '',
  thumbnailUrl: 'https://example.com/locked-thumb.jpg',
);

/// Keeps each https source under the retained root as `copy-<n>.jpg` without touching the disk.
class _FakeOfflineStore extends OfflineAssetStore {
  _FakeOfflineStore(this.root);

  final Directory root;
  final Map<String, String> retained = <String, String>{};

  @override
  Future<File> retain(String source, {File? file}) async {
    final String absolute = path.join(root.path, 'prism', 'offline', 'assets', 'copy-${retained.length}.jpg');
    retained[source] = absolute;
    return File(absolute);
  }

  @override
  Future<Map<String, String>> localPaths() async => retained;
}

class _MockDayNightRepository extends Mock implements DayNightRepository {}

class _MockDayNightBloc extends MockBloc<DayNightEvent, DayNightState> implements DayNightBloc {}

class _CopyPositionRepository implements WallpaperPositionRepository {
  _CopyPositionRepository(this.png, this.output);

  final Uint8List png;
  final Directory output;
  int renders = 0;

  @override
  Future<PlacementSource> load(String url) async {
    final ui.Codec codec = await ui.instantiateImageCodec(png);
    final ui.FrameInfo frame = await codec.getNextFrame();
    codec.dispose();
    return PlacementSource(image: frame.image, dominantColor: const ui.Color(0xFF000000));
  }

  @override
  Future<File> render(PlacementSource source, WallpaperPlacement placement, ui.Size outputSize) async {
    final ByteData data = (await source.image.toByteData(format: ui.ImageByteFormat.png))!;
    final Directory renderDirectory = Directory(path.join(output.path, 'render-${renders++}'))
      ..createSync(recursive: true);
    final File file = File(path.join(renderDirectory.path, 'wall.png'));
    await file.writeAsBytes(data.buffer.asUint8List());
    return file;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Future<File> Function(DayNightSlot slot, DayNightWall wall, String source) originalFixedCopy =
      DayNightRepositoryImpl.fixedCopyMaker;

  group('ReadabilityFix on DayNightWall', () {
    test('JSON round trip keeps fixes in order and drops unknown keys', () {
      final DayNightWall wall = _httpsDay.withFixes(const <ReadabilityFix>[_clockDim, _iconsBlur]);

      final Map<String, Object?> json = wall.toJson();

      expect(json['fixes'], <String>['clock-dim', 'icons-blur']);
      expect(DayNightWall.fromJson(json), wall);

      final Map<String, Object?> withUnknown = <String, Object?>{
        ...json,
        'fixes': <String>['clock-dim', 'sky-glow', 'icons-blur'],
      };
      expect(DayNightWall.fromJson(withUnknown)?.fixes, <ReadabilityFix>[_clockDim, _iconsBlur]);
    });

    test('a wall without fixes has no fixes key in JSON', () {
      expect(_httpsDay.toJson().containsKey('fixes'), isFalse);
    });

    test('walls that differ only in fixes are not equal', () {
      final DayNightWall fixed = _httpsDay.withFixes(const <ReadabilityFix>[_clockDim]);

      expect(fixed == _httpsDay, isFalse);
      expect(fixed.hashCode == _httpsDay.hashCode, isFalse);
      expect(fixed == _httpsDay.withFixes(const <ReadabilityFix>[_clockDim]), isTrue);
    });

    test('withFixes keeps id, source, urls and mainColor', () {
      const DayNightWall colored = DayNightWall(
        id: 'colored',
        source: WallpaperSource.wallhaven,
        fullUrl: 'https://example.com/colored.jpg',
        thumbnailUrl: 'https://example.com/colored-thumb.jpg',
        mainColor: '#663399',
      );

      final DayNightWall fixed = colored.withFixes(const <ReadabilityFix>[_iconsBlur]);

      expect(fixed.id, colored.id);
      expect(fixed.source, colored.source);
      expect(fixed.fullUrl, colored.fullUrl);
      expect(fixed.thumbnailUrl, colored.thumbnailUrl);
      expect(fixed.mainColor, colored.mainColor);
      expect(fixed.fixes, const <ReadabilityFix>[_iconsBlur]);
    });
  });

  testWidgets('a check that completes after two seconds does not show a late tip', (tester) async {
    ReadabilityTips.instance.reset();
    await ReadabilityTips.instance.setEnabled(true);
    expect(ReadabilityTips.instance.enabled, isTrue);
    expect(ReadabilityTips.instance.shownFor(_httpsDay.id), isFalse);
    final Completer<Map<ReadabilityZone, ReadabilityResult>> pending =
        Completer<Map<ReadabilityZone, ReadabilityResult>>();
    bool started = false;
    DayNightReadabilityTip.checkOverride = (ReadabilityKey _, Future<ui.Image> Function() _) {
      started = true;
      return pending.future;
    };
    addTearDown(() {
      DayNightReadabilityTip.checkOverride = null;
      ReadabilityTips.instance.reset();
    });

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DayNightReadabilityTip(slot: DayNightSlot.day, wall: _httpsDay, target: WallpaperTarget.lock),
        ),
      ),
    );
    expect(started, isTrue);
    await tester.pump(const Duration(seconds: 2));
    pending.complete(<ReadabilityZone, ReadabilityResult>{
      ReadabilityZone.clock: const ReadabilityResult(
        zone: ReadabilityZone.clock,
        lowContrastShare: 0.5,
        edgeShare: 0,
        fix: ReadabilityFixKind.dim,
      ),
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ReadabilityChip), findsNothing);
  });

  testWidgets('a result just before the shared budget keeps its tip after the deadline', (tester) async {
    ReadabilityTips.instance.reset();
    final Duration previousBudget = ReadabilityTips.budget;
    ReadabilityTips.budget = const Duration(milliseconds: 100);
    final Completer<Map<ReadabilityZone, ReadabilityResult>> pending =
        Completer<Map<ReadabilityZone, ReadabilityResult>>();
    DayNightReadabilityTip.checkOverride = (ReadabilityKey _, Future<ui.Image> Function() _) => pending.future;
    addTearDown(() {
      DayNightReadabilityTip.checkOverride = null;
      ReadabilityTips.budget = previousBudget;
      ReadabilityTips.instance.reset();
    });

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DayNightReadabilityTip(slot: DayNightSlot.day, wall: _httpsDay, target: WallpaperTarget.lock),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 99));
    expect(find.byType(ReadabilityChip), findsNothing);
    pending.complete(<ReadabilityZone, ReadabilityResult>{
      ReadabilityZone.clock: const ReadabilityResult(
        zone: ReadabilityZone.clock,
        lowContrastShare: 0.5,
        edgeShare: 0,
        fix: ReadabilityFixKind.dim,
      ),
    });
    await tester.pump();
    await tester.pump();
    expect(find.byType(ReadabilityChip), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ReadabilityChip), findsOneWidget);
  });

  testWidgets('tracking resets when the widget changes to another wall', (tester) async {
    ReadabilityTips.instance.reset();
    await ReadabilityTips.instance.setEnabled(true);
    DayNightReadabilityTip.checkOverride = (ReadabilityKey key, Future<ui.Image> Function() _) async =>
        <ReadabilityZone, ReadabilityResult>{
          ReadabilityZone.clock: const ReadabilityResult(
            zone: ReadabilityZone.clock,
            lowContrastShare: 0.5,
            edgeShare: 0,
            fix: ReadabilityFixKind.dim,
          ),
        };
    addTearDown(() {
      DayNightReadabilityTip.checkOverride = null;
      ReadabilityTips.instance.reset();
    });
    const DayNightWall otherWall = DayNightWall(
      id: 'other',
      source: WallpaperSource.prism,
      fullUrl: 'https://example.com/other.jpg',
      thumbnailUrl: 'https://example.com/other-thumb.jpg',
    );

    Widget screen(DayNightWall wall) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DayNightReadabilityTip(slot: DayNightSlot.day, wall: wall, target: WallpaperTarget.lock),
      ),
    );

    await tester.pumpWidget(screen(_httpsDay));
    await tester.pump();
    await tester.pump();
    expect(ReadabilityTips.instance.shownFor(_httpsDay.id), isTrue);
    await tester.pumpWidget(screen(otherWall));
    await tester.pump();
    await tester.pump();

    expect(ReadabilityTips.instance.shownFor(otherWall.id), isTrue);
  });

  testWidgets('a fix sheet opened for an old wall cannot apply to its replacement', (tester) async {
    ReadabilityTips.instance.reset();
    await ReadabilityTips.instance.setEnabled(true);
    final Completer<bool?> decision = Completer<bool?>();
    DayNightReadabilityTip.checkOverride = (ReadabilityKey _, Future<ui.Image> Function() _) async =>
        <ReadabilityZone, ReadabilityResult>{
          ReadabilityZone.clock: const ReadabilityResult(
            zone: ReadabilityZone.clock,
            lowContrastShare: 0.5,
            edgeShare: 0,
            fix: ReadabilityFixKind.dim,
          ),
        };
    DayNightReadabilityTip.sheetOverride = (BuildContext _, ReadabilityPreviewSource _, ReadabilityFix _) =>
        decision.future;
    addTearDown(() {
      DayNightReadabilityTip.checkOverride = null;
      DayNightReadabilityTip.sheetOverride = null;
      ReadabilityTips.instance.reset();
    });
    const DayNightWall replacement = DayNightWall(
      id: 'replacement',
      source: WallpaperSource.prism,
      fullUrl: 'https://example.com/replacement.jpg',
      thumbnailUrl: 'https://example.com/replacement-thumb.jpg',
    );
    final _MockDayNightBloc bloc = _MockDayNightBloc();

    Widget screen(DayNightWall wall) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<DayNightBloc>.value(
        value: bloc,
        child: Scaffold(
          body: DayNightReadabilityTip(slot: DayNightSlot.day, wall: wall, target: WallpaperTarget.lock),
        ),
      ),
    );

    await tester.pumpWidget(screen(_httpsDay));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byType(ReadabilityChip));
    await tester.pump();
    await tester.pumpWidget(screen(replacement));
    decision.complete(true);
    await tester.pump();
    await tester.pump();

    verifyNever(() => bloc.add(const DayNightEvent.fixesChanged(DayNightSlot.day, <ReadabilityFix>[_clockDim])));
  });

  testWidgets('the default fixed-copy renderer gives each publish an isolated output path', (tester) async {
    await tester.runAsync(() async {
      final Directory root = await Directory.systemTemp.createTemp('day-night-fixed-copy');
      final Directory support = Directory(path.join(root.path, 'support'))..createSync(recursive: true);
      final Directory renderOutput = Directory(path.join(root.path, 'rendered'))..createSync(recursive: true);
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = const Color(0xFFABCDEF));
      final ui.Image image = await recorder.endRecording().toImage(8, 8);
      final ByteData data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final Uint8List png = data.buffer.asUint8List();
      image.dispose();
      final _CopyPositionRepository position = _CopyPositionRepository(png, renderOutput);
      getIt.registerSingleton<WallpaperPositionRepository>(position);
      const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => support.path,
      );
      try {
        DayNightRepositoryImpl.fixedCopyMaker = originalFixedCopy;
        const ReadabilityFix fix = ReadabilityFix(ReadabilityZone.clock, ReadabilityFixKind.dim);
        final File first = await originalFixedCopy(DayNightSlot.day, _httpsDay.withFixes(<ReadabilityFix>[fix]), 'one');
        final List<int> firstBytes = await first.readAsBytes();
        final File second = await originalFixedCopy(
          DayNightSlot.day,
          _httpsDay.withFixes(<ReadabilityFix>[fix]),
          'two',
        );

        expect(first.path, isNot(second.path));
        expect(await first.readAsBytes(), firstBytes);
        expect(await second.exists(), isTrue);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
        await getIt.unregister<WallpaperPositionRepository>();
        await root.delete(recursive: true);
      }
    });
  });

  group('DayNightBloc fixesChanged', () {
    late _MockDayNightRepository repository;

    setUp(() async {
      repository = _MockDayNightRepository();
      app_state.prismUser = profileUser();
      await app_state.persistPrismUser();
      when(() => repository.save(any(), ownerId: any(named: 'ownerId'))).thenAnswer((_) async {});
      when(() => repository.publish(any())).thenAnswer((_) async {});
      when(() => repository.unpublish()).thenAnswer((_) async {});
      when(() => repository.runsOnDevice).thenReturn(false);
    });

    setUpAll(() {
      registerFallbackValue(DayNightPair());
    });

    tearDown(() async {
      app_state.prismUser = profileUser(id: '', loggedIn: false);
      await app_state.persistPrismUser();
    });

    blocTest<DayNightBloc, DayNightState>(
      'a disabled pair saves the day wall with the fix and keeps the night wall and fromVariants',
      build: () => DayNightBloc(repository),
      seed: () => DayNightState(
        pair: DayNightPair(day: _httpsDay, night: _httpsNight, fromVariants: true),
        loaded: true,
        isPro: true,
        userId: 'u1',
      ),
      act: (bloc) => bloc.add(const DayNightEvent.fixesChanged(DayNightSlot.day, <ReadabilityFix>[_clockDim])),
      expect: () => <DayNightState>[
        DayNightState(
          pair: DayNightPair(
            day: _httpsDay.withFixes(const <ReadabilityFix>[_clockDim]),
            night: _httpsNight,
            fromVariants: true,
          ),
          loaded: true,
          isPro: true,
          userId: 'u1',
        ),
      ],
      verify: (_) {
        verify(
          () => repository.save(
            DayNightPair(
              day: _httpsDay.withFixes(const <ReadabilityFix>[_clockDim]),
              night: _httpsNight,
              fromVariants: true,
            ),
            ownerId: 'u1',
          ),
        ).called(1);
        verifyNever(() => repository.publish(any()));
      },
    );

    blocTest<DayNightBloc, DayNightState>(
      'fixesChanged for an empty slot does nothing',
      build: () => DayNightBloc(repository),
      seed: () => DayNightState(
        pair: DayNightPair(day: _httpsDay),
        loaded: true,
        isPro: true,
        userId: 'u1',
      ),
      act: (bloc) => bloc.add(const DayNightEvent.fixesChanged(DayNightSlot.night, <ReadabilityFix>[_clockDim])),
      expect: () => <DayNightState>[],
      verify: (_) {
        verifyNever(() => repository.save(any(), ownerId: any(named: 'ownerId')));
        verifyNever(() => repository.publish(any()));
      },
    );
  });

  group('DayNightRepositoryImpl with fixes', () {
    late Directory root;
    late InMemoryLocalStore store;
    late DayNightRepositoryImpl repository;

    setUp(() async {
      DayNightRepositoryImpl.runsOnDeviceOverride = false;
      app_state.prismUser = profileUser(id: 'owner-a');
      SharedPreferences.setMockInitialValues(<String, Object>{});
      root = await Directory.systemTemp.createTemp('prism-day-night-fix-test');
      NativeAssetPathsStore.supportDirectoryOverride = root;
      NativeAssetPathsStore.documentsDirectoryOverride = Directory(path.join(root.path, 'documents'));
      OfflineAssetStore.testOverride = _FakeOfflineStore(root);
      store = InMemoryLocalStore();
      repository = DayNightRepositoryImpl(SettingsLocalDataSource(store));
    });

    tearDown(() async {
      DayNightRepositoryImpl.runsOnDeviceOverride = null;
      DayNightRepositoryImpl.fixedFolderOverride = null;
      DayNightRepositoryImpl.clock = DateTime.now;
      DayNightRepositoryImpl.fixedCopyMaker = originalFixedCopy;
      DayNightRepositoryImpl.downloadedOriginalOverride = null;
      debugDefaultTargetPlatformOverride = null;
      app_state.prismUser = profileUser(id: '', loggedIn: false);
      OfflineAssetStore.testOverride = null;
      NativeAssetPathsStore.supportDirectoryOverride = null;
      NativeAssetPathsStore.documentsDirectoryOverride = null;
      if (await root.exists()) await root.delete(recursive: true);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await SharedPreferences.getInstance();
    });

    Future<String?> snapshot() async => (await SharedPreferences.getInstance()).getString(_snapshotKey);

    group('Android', () {
      setUp(() {
        DayNightRepositoryImpl.runsOnDeviceOverride = true;
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
      });

      test('the schedule uses the fixed copy as a file source for the fixed day wall only', () async {
        final File fixedFile = File(path.join(root.path, 'fixed', 'day.png'));
        await fixedFile.create(recursive: true);
        final List<(DayNightSlot, DayNightWall, String)> calls = <(DayNightSlot, DayNightWall, String)>[];
        DayNightRepositoryImpl.fixedCopyMaker = (DayNightSlot slot, DayNightWall wall, String source) async {
          calls.add((slot, wall, source));
          return fixedFile;
        };
        final List<pigeon.DailyScheduleRequestData> scheduleRequests = <pigeon.DailyScheduleRequestData>[];
        _mockHostMethod('startDailySchedule', (ByteData? message) async {
          scheduleRequests.add((_codec.decodeMessage(message)! as List).single as pigeon.DailyScheduleRequestData);
          return _codec.encodeMessage(<Object?>[true]);
        });

        await repository.publish(
          DayNightPair(day: _httpsDay.withFixes(const <ReadabilityFix>[_clockDim]), night: _httpsNight),
        );

        expect(calls.single.$1, DayNightSlot.day);
        expect(calls.single.$2.id, 'day');
        expect(calls.single.$3, 'https://example.com/day.jpg');

        final pigeon.DailyScheduleRequestData request = scheduleRequests.single;
        expect(request.entries?.map((e) => e?.source?.sourceType).toList(), <pigeon.RotationSourceTypeData?>[
          pigeon.RotationSourceTypeData.file,
          pigeon.RotationSourceTypeData.url,
        ]);
        expect(request.entries?.map((e) => e?.source?.source).toList(), <String?>[
          fixedFile.path,
          'https://example.com/night.jpg',
        ]);
      });
    });

    test('a new iOS publish deletes the fixed copies of older publishes, and unpublish deletes the rest', () async {
      final Directory folder = Directory(path.join(root.path, 'prism', 'offline', 'assets', 'day_night_fixed'));
      DayNightRepositoryImpl.fixedFolderOverride = folder;
      // Each operation starts after every folder made so far, as when the user edits the pair a while later.
      DayNightRepositoryImpl.clock = () => DateTime.now().add(const Duration(hours: 1));
      final File old = File(path.join(folder.path, 'day-old', 'wall.png'));
      await old.create(recursive: true);
      int made = 0;
      DayNightRepositoryImpl.fixedCopyMaker = (DayNightSlot slot, DayNightWall wall, String source) async {
        final File copy = File(path.join(folder.path, '${slot.name}-${made++}', 'wall.png'));
        await copy.create(recursive: true);
        return copy;
      };
      final DayNightPair pair = DayNightPair(
        day: _httpsDay.withFixes(const <ReadabilityFix>[_clockDim]),
        night: _httpsNight.withFixes(const <ReadabilityFix>[_clockDim]),
      );

      await repository.publish(pair);

      expect(old.parent.existsSync(), isFalse);
      expect(folder.listSync().map((entry) => path.basename(entry.path)).toSet(), <String>{'day-0', 'night-1'});

      await repository.publish(pair);

      expect(folder.listSync().map((entry) => path.basename(entry.path)).toSet(), <String>{'day-2', 'night-3'});

      await repository.unpublish();

      expect(folder.listSync(), isEmpty);
    });

    test('a publish keeps the copies of a newer publish that rendered while it ran', () async {
      final Directory folder = Directory(path.join(root.path, 'prism', 'offline', 'assets', 'day_night_fixed'));
      DayNightRepositoryImpl.fixedFolderOverride = folder;
      final DateTime startedAt = DateTime.now();
      DayNightRepositoryImpl.clock = () => startedAt;
      final Directory old = await Directory(path.join(folder.path, 'day-old')).create(recursive: true);
      final ProcessResult touched = await Process.run('touch', <String>['-t', '202001010000', old.path]);
      expect(touched.exitCode, 0);
      late Directory newer;
      DayNightRepositoryImpl.fixedCopyMaker = (DayNightSlot slot, DayNightWall wall, String source) async {
        // Another publish renders its copy while this one runs.
        newer = await Directory(path.join(folder.path, 'day-newer')).create(recursive: true);
        final File copy = File(path.join(folder.path, '${slot.name}-0', 'wall.png'));
        await copy.create(recursive: true);
        return copy;
      };

      await repository.publish(
        DayNightPair(day: _httpsDay.withFixes(const <ReadabilityFix>[_clockDim]), night: _httpsNight),
      );

      expect(old.existsSync(), isFalse);
      expect(newer.existsSync(), isTrue);
      expect(folder.listSync().map((entry) => path.basename(entry.path)).toSet(), <String>{'day-0', 'day-newer'});
    });

    test('the iOS snapshot points the fixed day wall at its asset and maps the asset to a relative path', () async {
      final File fixedFile = File(path.join(root.path, 'prism', 'offline', 'assets', 'day_night_fixed', 'day.png'));
      await fixedFile.create(recursive: true);
      final List<(DayNightSlot, DayNightWall, String)> calls = <(DayNightSlot, DayNightWall, String)>[];
      DayNightRepositoryImpl.fixedCopyMaker = (DayNightSlot slot, DayNightWall wall, String source) async {
        calls.add((slot, wall, source));
        return fixedFile;
      };

      await repository.publish(
        DayNightPair(day: _httpsDay.withFixes(const <ReadabilityFix>[_clockDim]), night: _httpsNight),
      );

      expect(calls.single.$1, DayNightSlot.day);
      expect(calls.single.$3, 'https://example.com/day.jpg');

      final Map<String, Object?> snapshotJson = jsonDecode((await snapshot())!) as Map<String, Object?>;
      expect(snapshotJson['day'], <String, Object?>{'id': 'day', 'asset': 'daynight-fixed-day'});
      expect(snapshotJson['night'], <String, Object?>{'id': 'night', 'url': 'https://example.com/night.jpg'});

      final String? paths = (await SharedPreferences.getInstance()).getString('offline.native_asset_paths.daynight');
      expect(jsonDecode(paths!), <String, Object?>{
        'daynight-fixed-day': path.join('day_night_fixed', 'day.png'),
        'https://example.com/night.jpg': 'copy-0.jpg',
      });
    });

    test('publish with a fixed protected wall and no downloaded original throws needsDownload', () async {
      DayNightRepositoryImpl.downloadedOriginalOverride = (DayNightWall wall) async => null;
      final List<(DayNightSlot, DayNightWall, String)> calls = <(DayNightSlot, DayNightWall, String)>[];
      DayNightRepositoryImpl.fixedCopyMaker = (DayNightSlot slot, DayNightWall wall, String source) async {
        calls.add((slot, wall, source));
        return File(path.join(root.path, 'unused.png'));
      };

      await expectLater(
        repository.publish(
          DayNightPair(day: _httpsDay, night: _protected.withFixes(const <ReadabilityFix>[_clockDim])),
        ),
        throwsA(
          isA<DayNightPrepareException>()
              .having((e) => e.failure, 'failure', DayNightPrepareFailure.needsDownload)
              .having((e) => e.slot, 'slot', DayNightSlot.night),
        ),
      );

      expect(calls, isEmpty);
      expect(await snapshot(), isNull);
    });
  });
}
