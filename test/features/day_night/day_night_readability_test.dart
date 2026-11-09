import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/day_night/biz/bloc/day_night_bloc.j.dart';
import 'package:Prism/features/day_night/data/repositories/day_night_repository_impl.dart';
import 'package:Prism/features/day_night/domain/entities/day_night_pair.dart';
import 'package:Prism/features/day_night/domain/repositories/day_night_repository.dart';
import 'package:Prism/features/ios_shortcuts/data/native_asset_paths_store.dart';
import 'package:Prism/features/readability/domain/readability.dart';
import 'package:async_wallpaper/pigeon_impl_api.dart' as pigeon;
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
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
