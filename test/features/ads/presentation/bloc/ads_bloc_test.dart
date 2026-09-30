import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/ads/ads.dart';
import 'package:Prism/features/ads/domain/entities/ads_entity.dart';
import 'package:Prism/features/ads/domain/usecases/ads_usecases.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCreateRewardedAdUseCase extends Mock implements CreateRewardedAdUseCase {}

class _MockShowRewardedAdUseCase extends Mock implements ShowRewardedAdUseCase {}

void main() {
  const loaded = AdsEntity(rewardEarned: false, loadingAd: false, adLoaded: true, adFailed: false);
  const earned = AdsEntity(rewardEarned: true, loadingAd: false, adLoaded: false, adFailed: false);

  late _MockCreateRewardedAdUseCase createUseCase;
  late _MockShowRewardedAdUseCase showUseCase;
  late AdsBloc bloc;

  setUp(() {
    createUseCase = _MockCreateRewardedAdUseCase();
    showUseCase = _MockShowRewardedAdUseCase();
    when(() => createUseCase(const NoParams())).thenAnswer((_) async => Result.success(loaded));
    bloc = AdsBloc(createUseCase, showUseCase);
  });

  tearDown(() => bloc.close());

  void stubShow(List<Result<AdsEntity>> results) {
    when(() => showUseCase(const NoParams())).thenAnswer((_) async => results.removeAt(0));
  }

  test('reward earned unlocks the download', () async {
    stubShow([Result.success(earned)]);

    expect(await bloc.watchRewardedAd(), isTrue);
    await pumpEventQueue();
    expect(bloc.state.actionStatus, ActionStatus.idle);
    expect(bloc.state.shouldUnlockDownload, isFalse);
  });

  test('a later dismissed ad does not unlock after an earlier reward', () async {
    stubShow([Result.success(earned), Result.success(AdsEntity.empty)]);

    expect(await bloc.watchRewardedAd(), isTrue);
    expect(await bloc.watchRewardedAd(), isFalse);
  });

  test('a failed show does not unlock', () async {
    stubShow([Result.error(const ValidationFailure('Rewarded ad is not loaded'))]);

    expect(await bloc.watchRewardedAd(), isFalse);
  });

  test('a failed load skips the show', () async {
    when(() => createUseCase(const NoParams())).thenAnswer(
      (_) async =>
          Result.success(const AdsEntity(rewardEarned: false, loadingAd: false, adLoaded: false, adFailed: true)),
    );

    expect(await bloc.watchRewardedAd(), isFalse);
    verifyNever(() => showUseCase(const NoParams()));
  });
}
