import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/startup/biz/bloc/startup_bloc.j.dart';
import 'package:Prism/features/startup/domain/entities/startup_config_entity.dart';
import 'package:Prism/features/startup/domain/usecases/bootstrap_app_usecase.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBootstrapAppUseCase extends Mock implements BootstrapAppUseCase {}

StartupConfigEntity _startupConfig({required String obsoleteAppVersion}) => StartupConfigEntity(
  topImageLink: 'top',
  bannerText: 'banner',
  bannerTextOn: true,
  bannerUrl: 'url',
  obsoleteAppVersion: obsoleteAppVersion,
  verifiedUsers: <String>['a@b.com'],
  premiumCollections: <String>['space'],
  topTitleText: <String>['TOP'],
  categories: <Map<String, dynamic>>[],
  followersTab: true,
  aiEnabled: true,
  aiRolloutPercent: 100,
  aiSubmitEnabled: true,
  aiVariationsEnabled: true,
  useRcPaywalls: true,
  onboardingV2Enabled: true,
  onboardingStarterPack: <Map<String, dynamic>>[],
);

void main() {
  late _MockBootstrapAppUseCase bootstrapUseCase;

  setUp(() {
    bootstrapUseCase = _MockBootstrapAppUseCase();
    when(
      () => bootstrapUseCase(const NoParams()),
    ).thenAnswer((_) async => Result.success(_startupConfig(obsoleteAppVersion: '2.6.9')));
  });

  blocTest<StartupBloc, StartupState>(
    'marks app as obsolete when current version is lower',
    build: () => StartupBloc(bootstrapUseCase),
    act: (bloc) => bloc.add(const StartupEvent.started(currentVersion: '2.6.8')),
    verify: (bloc) {
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.isObsoleteVersion, isTrue);
      expect(bloc.state.config?.bannerText, 'banner');
    },
  );

  blocTest<StartupBloc, StartupState>(
    'fails open when started has no current version',
    build: () => StartupBloc(bootstrapUseCase),
    act: (bloc) async {
      final completed = bloc.stream.firstWhere((state) => state.status == LoadStatus.success);
      bloc.add(const StartupEvent.started());
      await completed;
    },
    verify: (bloc) {
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.isObsoleteVersion, isFalse);
    },
  );

  blocTest<StartupBloc, StartupState>(
    'fails open when retry has no current version',
    build: () => StartupBloc(bootstrapUseCase),
    act: (bloc) async {
      final started = bloc.stream.firstWhere((state) => state.status == LoadStatus.success);
      bloc.add(const StartupEvent.started(currentVersion: '2.6.8'));
      await started;
      expect(bloc.state.isObsoleteVersion, isTrue);
      final loading = bloc.stream.firstWhere((state) => state.status == LoadStatus.loading);
      final retried = bloc.stream.firstWhere((state) => state.status == LoadStatus.success);
      bloc.add(const StartupEvent.retryRequested());
      await loading;
      await retried;
    },
    verify: (bloc) {
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.isObsoleteVersion, isFalse);
    },
  );

  test('retry fails open and clears obsolete state when the threshold becomes malformed', () async {
    var callCount = 0;
    when(() => bootstrapUseCase(const NoParams())).thenAnswer((_) async {
      callCount++;
      return Result.success(_startupConfig(obsoleteAppVersion: callCount == 1 ? '2.6.9' : '4.bad.0'));
    });
    final bloc = StartupBloc(bootstrapUseCase);
    addTearDown(bloc.close);
    final started = bloc.stream.firstWhere((state) => state.status == LoadStatus.success);
    bloc.add(const StartupEvent.started(currentVersion: '2.6.8'));
    await started;
    expect(bloc.state.isObsoleteVersion, isTrue);

    final retried = bloc.stream.firstWhere(
      (state) => state.status == LoadStatus.success && state.config?.obsoleteAppVersion == '4.bad.0',
    );
    bloc.add(const StartupEvent.retryRequested(currentVersion: '2.6.8'));
    await retried;
    expect(bloc.state.isObsoleteVersion, isFalse);
  });

  group('isVersionLower', () {
    test('compares each part as a number', () {
      expect(isVersionLower('3.1.0', '3.0.10'), isFalse);
      expect(isVersionLower('3.0.9', '3.0.10'), isTrue);
      expect(isVersionLower('2.10.0', '3.0.9'), isTrue);
      expect(isVersionLower('2.6.8', '2.6.9'), isTrue);
    });

    test('treats equal and newer versions as not lower', () {
      expect(isVersionLower('3.0.9', '3.0.9'), isFalse);
      expect(isVersionLower('3.0.9', '2.6.0'), isFalse);
      expect(isVersionLower('3', '3.0.0'), isFalse);
      expect(isVersionLower('3', '3.0.1'), isTrue);
      expect(isVersionLower('3.0.0.1', '3.0.0'), isFalse);
      expect(isVersionLower('3.0', '3.0.0.1'), isTrue);
      expect(isVersionLower('03.00.09', '3.0.9'), isFalse);
      expect(isVersionLower('03.00.09', '3.0.10'), isTrue);
    });

    test('ignores build and pre-release suffixes and trims outer whitespace', () {
      expect(isVersionLower('3.0.9+336', '3.0.9'), isFalse);
      expect(isVersionLower('3.0.8+336-beta.2', '3.0.9'), isTrue);
      expect(isVersionLower('3.0.8-beta.2+336', '3.0.9'), isTrue);
      expect(isVersionLower('3.0.8', ' 3.0.9-beta '), isTrue);
      expect(isVersionLower(' 3.0.8 ', ' 3.0.9 '), isTrue);
    });

    const malformedVersions = <String>[
      '',
      '   ',
      'garbage',
      '3..0',
      '3.alpha.0',
      '0x3.0.0',
      '3. 0.0',
      '-3.0.0',
      '+3.0.0',
      '3.0.9.',
      '999999999999999999999999999999999999999999999999999999999999999999',
      '4.999999999999999999999999999999999999999999999999999999999999999999',
      '3.0.9+',
      '3.0.9-',
      '3.0.9++build',
      '3.0.9-beta..1',
      '3.0.9-beta. 1',
      '3.0.9!beta',
    ];
    for (final malformed in malformedVersions) {
      test('rejects malformed current version and threshold "$malformed"', () {
        expect(isVersionLower(malformed, '9.0.0'), isFalse, reason: 'invalid current version: "$malformed"');
        expect(isVersionLower('1.0.0', malformed), isFalse, reason: 'invalid threshold: "$malformed"');
      });
    }
  });
}
