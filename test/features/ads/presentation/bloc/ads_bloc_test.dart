import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/ads/domain/entities/ads_entity.dart';
import 'package:Prism/features/ads/domain/usecases/ads_usecases.dart';
import 'package:Prism/features/ads/presentation/bloc/ads_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCreateRewardedAdUseCase extends Mock
    implements CreateRewardedAdUseCase {}

class _MockAddRewardUseCase extends Mock implements AddRewardUseCase {}

class _MockResetAdsUseCase extends Mock implements ResetAdsUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(const AddRewardParams(rewardAmount: 0));
  });

  late _MockCreateRewardedAdUseCase createUseCase;
  late _MockAddRewardUseCase addRewardUseCase;
  late _MockResetAdsUseCase resetUseCase;

  setUp(() {
    createUseCase = _MockCreateRewardedAdUseCase();
    addRewardUseCase = _MockAddRewardUseCase();
    resetUseCase = _MockResetAdsUseCase();

    when(() => createUseCase(const NoParams())).thenAnswer(
      (_) async => Result.success(
        const AdsEntity(
          downloadCoins: 0,
          loadingAd: false,
          adLoaded: true,
          adFailed: false,
        ),
      ),
    );

    when(() => addRewardUseCase(any())).thenAnswer(
      (_) async => Result.success(
        const AdsEntity(
          downloadCoins: 10,
          loadingAd: false,
          adLoaded: true,
          adFailed: false,
        ),
      ),
    );

    when(() => resetUseCase(const NoParams())).thenAnswer(
      (_) async => Result.success(AdsEntity.empty),
    );
  });

  AdsBloc buildBloc() => AdsBloc(createUseCase, addRewardUseCase, resetUseCase);

  blocTest<AdsBloc, AdsState>(
    'rewardEarned unlocks when threshold is met',
    build: buildBloc,
    act: (bloc) => bloc
      ..add(const AdsEvent.started())
      ..add(const AdsEvent.rewardEarned(rewardAmount: 10, unlockThreshold: 10)),
    expect: () => <AdsState>[
      AdsState.initial().copyWith(
        status: LoadStatus.loading,
        actionStatus: ActionStatus.inProgress,
      ),
      AdsState.initial().copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.success,
        ads: const AdsEntity(
          downloadCoins: 0,
          loadingAd: false,
          adLoaded: true,
          adFailed: false,
        ),
      ),
      AdsState.initial().copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.inProgress,
        ads: const AdsEntity(
          downloadCoins: 0,
          loadingAd: false,
          adLoaded: true,
          adFailed: false,
        ),
      ),
      AdsState.initial().copyWith(
        status: LoadStatus.success,
        actionStatus: ActionStatus.success,
        shouldUnlockDownload: true,
        ads: const AdsEntity(
          downloadCoins: 10,
          loadingAd: false,
          adLoaded: true,
          adFailed: false,
        ),
      ),
    ],
  );
}
