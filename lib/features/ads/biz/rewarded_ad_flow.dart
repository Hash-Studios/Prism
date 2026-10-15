import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/ads/biz/bloc/ads_bloc.j.dart';
import 'package:Prism/features/ads/domain/entities/ads_entity.dart';

const Duration rewardedAdLoadTimeout = Duration(seconds: 30);
const Duration rewardedAdWatchTimeout = Duration(seconds: 60);

final Expando<bool> _activeWatches = Expando<bool>();

/// Outcome of one rewarded ad. [failure] says why no ad played, and is null when the cause is unknown.
class RewardedAdResult {
  const RewardedAdResult.earned() : earned = true, failure = null;
  const RewardedAdResult.notEarned([this.failure]) : earned = false;

  final bool earned;
  final AdFailureReason? failure;
}

/// Loads an ad if needed and shows it. The result says whether the user earned the reward, and why not when no ad
/// played.
Future<RewardedAdResult> watchRewardedAdResult(AdsBloc bloc) async {
  if (_activeWatches[bloc] == true) return const RewardedAdResult.notEarned();
  _activeWatches[bloc] = true;
  try {
    final (bool ready, AdFailureReason? failure) = await _ensureRewardedAdReady(bloc);
    if (!ready) {
      return RewardedAdResult.notEarned(failure);
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
      return (await completion).shouldUnlockDownload
          ? const RewardedAdResult.earned()
          : const RewardedAdResult.notEarned();
    } catch (_) {
      return const RewardedAdResult.notEarned();
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

Future<(bool, AdFailureReason?)> _ensureRewardedAdReady(AdsBloc bloc) async {
  if (bloc.state.ads.adLoaded) {
    return (true, null);
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
    if (ready.ads.adLoaded) return (true, null);
    return (
      false,
      ready.ads.adFailed ? ready.ads.failureReason : (ready.failure == null ? null : AdFailureReason.timeout),
    );
  } catch (_) {
    return (false, AdFailureReason.timeout);
  }
}
