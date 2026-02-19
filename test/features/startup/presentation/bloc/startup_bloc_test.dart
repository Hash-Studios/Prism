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

void main() {
  late _MockBootstrapAppUseCase bootstrapUseCase;

  setUp(() {
    bootstrapUseCase = _MockBootstrapAppUseCase();
    when(() => bootstrapUseCase(const NoParams())).thenAnswer(
      (_) async => Result.success(
        const StartupConfigEntity(
          topImageLink: 'top',
          bannerText: 'banner',
          bannerTextOn: true,
          bannerUrl: 'url',
          obsoleteAppVersion: '2.6.9',
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
        ),
      ),
    );
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
}
