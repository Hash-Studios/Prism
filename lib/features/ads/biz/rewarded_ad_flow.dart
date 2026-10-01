import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/ads/biz/bloc/ads_bloc.j.dart';

const Duration rewardedAdLoadTimeout = Duration(seconds: 30);
const Duration rewardedAdWatchTimeout = Duration(seconds: 60);

final Expando<bool> _activeWatches = Expando<bool>();

/// Loads an ad if needed, shows it and returns true only when the user earned the reward.
Future<bool> watchRewardedAd(AdsBloc bloc) async {
  if (_activeWatches[bloc] == true) return false;
  _activeWatches[bloc] = true;
  try {
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
        try {
          final Future<AdsState> transientStateCleared = bloc.stream
              .firstWhere(
                (state) =>
                    state.actionStatus == ActionStatus.idle && !state.shouldUnlockDownload && !state.ads.adFailed,
              )
              .timeout(rewardedAdLoadTimeout);
          bloc.add(const AdsEvent.transientStateCleared());
          await transientStateCleared;
        } catch (_) {
          // The bloc may close while the ad is being shown.
        }
      }
    }
  } finally {
    _activeWatches[bloc] = false;
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
        .firstWhere(
          (state) =>
              state.actionStatus != ActionStatus.inProgress &&
              (state.ads.adLoaded ||
                  state.actionStatus == ActionStatus.success ||
                  state.actionStatus == ActionStatus.failure ||
                  state.ads.adFailed),
        )
        .timeout(rewardedAdLoadTimeout);
    return ready.ads.adLoaded;
  } catch (_) {
    return false;
  }
}
