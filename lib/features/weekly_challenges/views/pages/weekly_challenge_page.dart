import 'dart:async';
import 'dart:io';
import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/purchases/upload_quota.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/share/share_card.dart';
import 'package:Prism/core/share/share_sheet.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/views/wallpaper_feed.dart';
import 'package:Prism/features/wallpaper_upload/biz/upload_batch.dart';
import 'package:Prism/features/weekly_challenges/biz/weekly_challenges_cubit.dart';
import 'package:Prism/features/weekly_challenges/domain/entities/weekly_challenge.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

export 'package:Prism/features/weekly_challenges/biz/weekly_challenges_cubit.dart' show WeeklyChallengesCubit;

@RoutePage()
class WeeklyChallengePage extends StatefulWidget {
  const WeeklyChallengePage({@PathParam('challengeId') required this.challengeId, this.cubit, super.key});
  final String challengeId;
  final WeeklyChallengesCubit? cubit;
  @override
  State<WeeklyChallengePage> createState() => _WeeklyChallengePageState();
}

class _WeeklyChallengePageState extends State<WeeklyChallengePage> with WidgetsBindingObserver {
  late final WeeklyChallengesCubit _cubit = widget.cubit ?? getIt<WeeklyChallengesCubit>();
  Timer? _closeTimer;
  bool _picking = false;
  String? _winnerViewed;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_cubit.load(widget.challengeId));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_cubit.load(widget.challengeId));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closeTimer?.cancel();
    if (widget.cubit == null) unawaited(_cubit.close());
    super.dispose();
  }

  bool _signedIn() {
    if (app_state.prismUser.loggedIn) return true;
    toasts.info(context.l10n.challengeSignIn);
    unawaited(
      googleSignInPopUp(context, () {
        if (mounted) unawaited(_cubit.load(widget.challengeId));
      }),
    );
    return false;
  }

  Future<void> _upload(WeeklyChallenge challenge) async {
    if (_picking || !_signedIn()) return;
    final int limit = uploadPickLimit(
      isPremium: app_state.prismUser.premium,
      remainingFree: UploadQuota.remainingFreeUploadsThisWeek(),
    );
    if (limit < 1) {
      toasts.error(context.l10n.wallpaperUploadFreeQuotaMessage(UploadQuota.freeUploadsPerWeek));
      return;
    }
    _picking = true;
    try {
      final picked = await ImagePicker().pickMultiImage(limit: limit);
      if (!mounted || picked.isEmpty) return;
      final files = picked.take(limit).map((row) => File(row.path)).toList();
      final batch = UploadBatch(files, challengeSeed: challenge.seed);
      await context.router.push(UploadWallRoute(image: files.first, batch: batch, challengeSeed: challenge.seed));
      if (mounted) unawaited(_cubit.load(widget.challengeId));
    } catch (_) {
      if (mounted) toasts.error(context.l10n.challengeError);
    } finally {
      _picking = false;
    }
  }

  Future<void> _open(List<ChallengeEntry> entries, int index) async {
    final wall = entries[index].wall;
    if (wall == null) return;
    await context.router.push(
      WallpaperDetailRoute(
        entity: FeedItemEntity.prism(id: wall.id, wallpaper: wall),
        feed: WallpaperFeed(
          grid: context,
          tiles: [
            for (final (i, entry) in entries.indexed)
              if (entry.wall case final item?)
                (
                  item: FeedItemEntity.prism(id: item.id, wallpaper: item),
                  index: i,
                  heroTag: 'challenge-${widget.challengeId}-${entry.id}',
                ),
          ],
        ),
      ),
    );
    if (mounted) unawaited(_cubit.load(widget.challengeId));
  }

  String _error(ChallengeError? error) => switch (error) {
    ChallengeError.signedOut => context.l10n.challengeSignIn,
    ChallengeError.entryLimit => context.l10n.challengeLimit,
    ChallengeError.closed => context.l10n.challengeClosed,
    ChallengeError.ownEntry => context.l10n.challengeOwnEntry,
    ChallengeError.dailyLimit => context.l10n.challengeDailyLimit,
    ChallengeError.missing => context.l10n.challengeMissing,
    _ => context.l10n.challengeVoteError,
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.challengeTitle)),
    body: BlocConsumer<WeeklyChallengesCubit, WeeklyChallengesState>(
      bloc: _cubit,
      listener: (context, state) {
        if (state.error != null && !state.failed) toasts.error(_error(state.error));
        final challenge = state.detail?.challenge;
        _closeTimer?.cancel();
        if (challenge != null && challenge.isOpenAt(DateTime.now().toUtc())) {
          _closeTimer = Timer(challenge.closesAt.difference(DateTime.now().toUtc()), () {
            if (mounted) unawaited(_cubit.load(widget.challengeId));
          });
        }
        if (challenge?.winner != null && _winnerViewed != challenge!.id) {
          _winnerViewed = challenge.id;
          analytics.track(ChallengeWinnerViewedEvent(challengeId: challenge.id));
        }
      },
      builder: (context, state) {
        if (state.loading) return const Center(child: CircularProgressIndicator());
        final detail = state.detail;
        if (state.failed || detail == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Glint(),
                  Text(
                    state.error == ChallengeError.missing ? context.l10n.challengeMissing : context.l10n.challengeError,
                  ),
                  TextButton(
                    onPressed: () => _cubit.load(widget.challengeId),
                    child: Text(context.l10n.challengeRetry),
                  ),
                ],
              ),
            ),
          );
        }
        final challenge = detail.challenge;
        final open = challenge.isOpenAt(DateTime.now().toUtc());
        final l10n = context.l10n;
        return RefreshIndicator(
          onRefresh: () => _cubit.load(widget.challengeId),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text(challenge.theme, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(l10n.challengeRules),
              Text(l10n.challengeVotingRules(DateFormat.yMMMd(l10n.localeName).add_Hm().format(challenge.closesAt))),
              const SizedBox(height: 16),
              if (open) ...[
                if (detail.myEntryCount >= 3) Text(l10n.challengeLimit),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: detail.myEntryCount >= 3 ? null : () => _upload(challenge),
                      child: Text(l10n.challengeUpload),
                    ),
                    OutlinedButton(
                      onPressed: detail.myEntryCount >= 3
                          ? null
                          : () async {
                              if (!_signedIn()) return;
                              await context.router.push(AiTabRoute(challengeSeed: challenge.seed));
                              if (mounted) unawaited(_cubit.load(widget.challengeId));
                            },
                      child: Text(l10n.challengeAi),
                    ),
                  ],
                ),
              ] else
                Text(switch (challenge.state) {
                  ChallengeState.votingClosed || ChallengeState.open => l10n.challengeWaiting,
                  ChallengeState.scheduled => l10n.challengeScheduled,
                  _ => challenge.noWinner ? l10n.challengeNoWinner : l10n.challengeClosed,
                }),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  icon: const Icon(Icons.share_outlined),
                  label: Text(l10n.challengeShare),
                  onPressed: () => showShareSheet(
                    context,
                    ShareCardContent(
                      imageUrl: challenge.winner?.thumbUrl ?? detail.entries.firstOrNull?.thumbUrl ?? '',
                      link: 'https://prismwalls.com/challenges/${challenge.id}',
                      brandName: 'Prism',
                      contextLine: challenge.theme,
                    ),
                    'weekly_challenge',
                    onShared: () => analytics.track(ChallengeSharedEvent(challengeId: challenge.id)),
                  ),
                ),
              ),
              if (challenge.winner case final winner?) ...[
                Text(l10n.challengeWinner(winner.creatorName), style: PrismTextStyles.rowTitle(context)),
                _entry(winner, [winner], 0, false),
              ],
              const SizedBox(height: 12),
              SegmentedButton<ChallengeSort>(
                segments: [
                  ButtonSegment(value: ChallengeSort.top, label: Text(l10n.challengeTop)),
                  ButtonSegment(value: ChallengeSort.newest, label: Text(l10n.challengeNew)),
                ],
                selected: {state.sort},
                onSelectionChanged: (sort) => _cubit.load(widget.challengeId, sort: sort.single),
              ),
              const SizedBox(height: 16),
              if (detail.entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(children: [const Glint(), Text(l10n.challengeEmpty)]),
                ),
              for (final (i, entry) in detail.entries.indexed) _entry(entry, detail.entries, i, open),
              if (state.past.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(l10n.challengePast, style: PrismTextStyles.rowTitle(context)),
                for (final past in state.past)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(past.theme),
                    subtitle: Text(
                      past.winner == null
                          ? past.noWinner
                                ? l10n.challengeNoWinner
                                : past.state == ChallengeState.votingClosed
                                ? l10n.challengeWaiting
                                : l10n.challengeClosed
                          : l10n.challengeWinner(past.winner!.creatorName),
                    ),
                    onTap: () => context.router.push(WeeklyChallengeRoute(challengeId: past.id)),
                  ),
              ],
            ],
          ),
        );
      },
    ),
  );
  Widget _entry(ChallengeEntry entry, List<ChallengeEntry> entries, int index, bool open) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.thumbUrl.isNotEmpty)
            InkWell(
              onTap: () => _open(entries, index),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: CachedNetworkImage(imageUrl: entry.thumbUrl, fit: BoxFit.cover),
                ),
              ),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => _open(entries, index),
            title: Text(entry.title.isEmpty ? entry.creatorName : entry.title),
            subtitle: Text(entry.creatorName),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(l10n.challengeVotes(entry.voteCount)),
              if (open && !entry.mine)
                OutlinedButton.icon(
                  icon: Icon(entry.voted ? Icons.favorite : Icons.favorite_border),
                  label: Text(entry.voted ? l10n.challengeUnvote : l10n.challengeVote),
                  onPressed: () {
                    if (_signedIn()) unawaited(_cubit.toggleVote(entry));
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
