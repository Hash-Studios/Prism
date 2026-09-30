import 'package:Prism/core/error/failure.dart';
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

StartupConfigEntity _config({String obsoleteAppVersion = '2.6.9'}) => StartupConfigEntity(
  topImageLink: 'top',
  bannerText: 'banner',
  bannerTextOn: true,
  bannerUrl: 'url',
  obsoleteAppVersion: obsoleteAppVersion,
  verifiedUsers: const <String>['a@b.com'],
  premiumCollections: const <String>['space'],
  aiEnabled: true,
  aiRolloutPercent: 100,
  aiSubmitEnabled: true,
  aiVariationsEnabled: true,
  useRcPaywalls: true,
  onboardingV2Enabled: true,
);

void main() {
  late _MockBootstrapAppUseCase bootstrapUseCase;

  setUp(() {
    bootstrapUseCase = _MockBootstrapAppUseCase();
    when(() => bootstrapUseCase(const NoParams())).thenAnswer((_) async => Result.success(_config()));
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
    'does not treat a two digit minor version as older than a single digit one',
    build: () => StartupBloc(bootstrapUseCase),
    act: (bloc) => bloc.add(const StartupEvent.started(currentVersion: '2.10.0')),
    verify: (bloc) => expect(bloc.state.isObsoleteVersion, isFalse),
  );

  blocTest<StartupBloc, StartupState>(
    'a Remote Config version that is not a number does not fail startup',
    setUp: () => when(
      () => bootstrapUseCase(const NoParams()),
    ).thenAnswer((_) async => Result.success(_config(obsoleteAppVersion: 'soon'))),
    build: () => StartupBloc(bootstrapUseCase),
    act: (bloc) => bloc.add(const StartupEvent.started(currentVersion: '3.0.9')),
    verify: (bloc) {
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.isObsoleteVersion, isFalse);
    },
  );

  blocTest<StartupBloc, StartupState>(
    'reports failure when bootstrap fails, then recovers on a second started event',
    setUp: () => when(
      () => bootstrapUseCase(const NoParams()),
    ).thenAnswer((_) async => Result.error(const ServerFailure('offline'))),
    build: () => StartupBloc(bootstrapUseCase),
    act: (bloc) async {
      bloc.add(const StartupEvent.started(currentVersion: '3.0.9'));
      await bloc.stream.firstWhere((s) => s.status == LoadStatus.failure);
      when(() => bootstrapUseCase(const NoParams())).thenAnswer((_) async => Result.success(_config()));
      bloc.add(const StartupEvent.started(currentVersion: '3.0.9'));
    },
    verify: (bloc) => expect(bloc.state.status, LoadStatus.success),
  );
}
