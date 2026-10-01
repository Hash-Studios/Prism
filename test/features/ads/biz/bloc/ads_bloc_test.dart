import 'dart:async';

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

    expect(await watchRewardedAd(bloc), isTrue);
    await pumpEventQueue();
    expect(bloc.state.actionStatus, ActionStatus.idle);
    expect(bloc.state.shouldUnlockDownload, isFalse);
  });

  test('a later dismissed ad does not unlock after an earlier reward', () async {
    stubShow([Result.success(earned), Result.success(AdsEntity.empty)]);

    expect(await watchRewardedAd(bloc), isTrue);
    expect(await watchRewardedAd(bloc), isFalse);
  });

  test('a failed show does not unlock', () async {
    stubShow([Result.error(const ValidationFailure('Rewarded ad is not loaded'))]);

    expect(await watchRewardedAd(bloc), isFalse);
  });

  test('concurrent watches on one bloc show one ad and release the guard afterward', () async {
    final Completer<Result<AdsEntity>> firstShow = Completer<Result<AdsEntity>>();
    var showCalls = 0;
    when(() => showUseCase(const NoParams())).thenAnswer((_) {
      showCalls++;
      return showCalls == 1 ? firstShow.future : Future.value(Result.success(earned));
    });

    final Future<bool> firstWatch = watchRewardedAd(bloc);
    await pumpEventQueue();

    expect(showCalls, 1);
    expect(await watchRewardedAd(bloc), isFalse);
    expect(showCalls, 1);

    firstShow.complete(Result.success(earned));
    expect(await firstWatch, isTrue);
    await pumpEventQueue();

    expect(await watchRewardedAd(bloc), isTrue);
    expect(showCalls, 2);
  });

  test('a failed load skips the show', () async {
    when(() => createUseCase(const NoParams())).thenAnswer(
      (_) async =>
          Result.success(const AdsEntity(rewardEarned: false, loadingAd: false, adLoaded: false, adFailed: true)),
    );

    expect(await watchRewardedAd(bloc), isFalse);
    verifyNever(() => showUseCase(const NoParams()));
  });

  test('a failed load releases the watch guard for a later attempt', () async {
    var loadCalls = 0;
    when(() => createUseCase(const NoParams())).thenAnswer((_) async {
      loadCalls++;
      return loadCalls == 1
          ? Result.error(const ValidationFailure('Rewarded ad failed to load'))
          : Result.success(loaded);
    });
    stubShow([Result.success(earned)]);

    expect(await watchRewardedAd(bloc), isFalse);
    expect(await watchRewardedAd(bloc), isTrue);
    expect(loadCalls, 2);
  });

  test('a stale ad failure does not finish the next load before it completes', () async {
    final Completer<Result<AdsEntity>> retryLoad = Completer<Result<AdsEntity>>();
    var loadCalls = 0;
    when(() => createUseCase(const NoParams())).thenAnswer((_) {
      loadCalls++;
      return loadCalls == 1
          ? Future.value(
              Result.success(const AdsEntity(rewardEarned: false, loadingAd: false, adLoaded: false, adFailed: true)),
            )
          : retryLoad.future;
    });
    var showCalls = 0;
    when(() => showUseCase(const NoParams())).thenAnswer((_) async {
      showCalls++;
      return Result.success(earned);
    });

    expect(await watchRewardedAd(bloc), isFalse);
    final Future<bool> retry = watchRewardedAd(bloc);
    await pumpEventQueue();

    expect(loadCalls, 2);
    expect(showCalls, 0);

    retryLoad.complete(Result.success(loaded));
    expect(await retry, isTrue);
    expect(showCalls, 1);
  });
}
