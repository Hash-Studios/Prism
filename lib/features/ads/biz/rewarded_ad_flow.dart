import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/ads/biz/bloc/ads_bloc.j.dart';

const Duration rewardedAdLoadTimeout = Duration(seconds: 30);
const Duration rewardedAdWatchTimeout = Duration(seconds: 60);

extension RewardedAdFlow on AdsBloc {
  /// Loads an ad if needed, shows it and returns true only when the user earned the reward.
  Future<bool> watchRewardedAd() async {
    if (!await _ensureRewardedAdReady()) {
      return false;
    }
    bool watchRequested = false;
    try {
      final Future<AdsState> completion = stream
          .firstWhere(
            (state) =>
                state.shouldUnlockDownload ||
                state.actionStatus == ActionStatus.success ||
                state.actionStatus == ActionStatus.failure ||
                state.ads.adFailed,
          )
          .timeout(rewardedAdWatchTimeout);
      add(const AdsEvent.watchAdRequested());
      watchRequested = true;
      return (await completion).shouldUnlockDownload;
    } catch (_) {
      return false;
    } finally {
      if (watchRequested) {
        add(const AdsEvent.transientStateCleared());
      }
    }
  }

  Future<bool> _ensureRewardedAdReady() async {
    if (state.ads.adLoaded) {
      return true;
    }
    if (!state.ads.loadingAd) {
      add(const AdsEvent.started());
    }
    try {
      final AdsState ready = await stream
          .firstWhere((state) => state.ads.adLoaded || state.ads.adFailed)
          .timeout(rewardedAdLoadTimeout);
      return ready.ads.adLoaded;
    } catch (_) {
      return false;
    }
  }
}
