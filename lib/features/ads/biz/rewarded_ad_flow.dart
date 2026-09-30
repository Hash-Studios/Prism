import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/ads/biz/bloc/ads_bloc.j.dart';

const Duration rewardedAdLoadTimeout = Duration(seconds: 30);
const Duration rewardedAdWatchTimeout = Duration(seconds: 60);

/// Loads an ad if needed, shows it and returns true only when the user earned the reward.
Future<bool> watchRewardedAd(AdsBloc bloc) async {
  if (!await _ensureRewardedAdReady(bloc)) {
    return false;
  }
  bool watchRequested = false;
  try {
    final Future<AdsState> completion = bloc.stream
        .firstWhere(
          (state) =>
              state.shouldUnlockDownload ||
              state.actionStatus == ActionStatus.success ||
              state.actionStatus == ActionStatus.failure ||
              state.ads.adFailed,
        )
        .timeout(rewardedAdWatchTimeout);
    bloc.add(const AdsEvent.watchAdRequested());
    watchRequested = true;
    return (await completion).shouldUnlockDownload;
  } catch (_) {
    return false;
  } finally {
    if (watchRequested) {
      bloc.add(const AdsEvent.transientStateCleared());
    }
  }
}

Future<bool> _ensureRewardedAdReady(AdsBloc bloc) async {
  if (bloc.state.ads.adLoaded) {
    return true;
  }
  if (!bloc.state.ads.loadingAd) {
    bloc.add(const AdsEvent.started());
  }
  try {
    final AdsState ready = await bloc.stream
        .firstWhere((state) => state.ads.adLoaded || state.ads.adFailed)
        .timeout(rewardedAdLoadTimeout);
    return ready.ads.adLoaded;
  } catch (_) {
    return false;
  }
}
