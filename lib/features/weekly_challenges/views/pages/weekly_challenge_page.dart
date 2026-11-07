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
import 'package:Prism/core/widgets/prism_refresh.dart';
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
  static const int _maxChallengeEntries = 3;
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
  void didUpdateWidget(covariant WeeklyChallengePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.challengeId != widget.challengeId) {
      _closeTimer?.cancel();
      _winnerViewed = null;
      unawaited(_cubit.load(widget.challengeId));
    }
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

  Future<void> _upload(WeeklyChallenge challenge, int myEntryCount) async {
    if (_picking || !_signedIn()) return;
    final int remainingEntries = (_maxChallengeEntries - myEntryCount).clamp(0, _maxChallengeEntries);
    if (remainingEntries == 0) return;
    final int limit = uploadPickLimit(
      isPremium: app_state.prismUser.premium,
      remainingFree: UploadQuota.remainingFreeUploadsThisWeek(),
    ).clamp(0, remainingEntries);
    if (limit < 1) {
      toasts.error(context.l10n.wallpaperUploadFreeQuotaMessage(UploadQuota.freeUploadsPerWeek));
      return;
    }
    _picking = true;
    try {
      final picker = ImagePicker();
      final List<XFile> picked;
      if (limit == 1) {
        final image = await picker.pickImage(source: ImageSource.gallery);
        picked = [if (image != null) image];
      } else {
        picked = await picker.pickMultiImage(limit: limit);
      }
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
  void _share(WeeklyChallenge challenge, ChallengeDetail detail) => showShareSheet(
    context,
    ShareCardContent(
      imageUrl: challenge.winner?.thumbUrl ?? detail.entries.firstOrNull?.thumbUrl ?? '',
      link: 'https://prismwalls.com/challenges/${challenge.id}',
      brandName: 'Prism',
      contextLine: challenge.theme,
    ),
    'weekly_challenge',
    onShared: () => analytics.track(ChallengeSharedEvent(challengeId: challenge.id)),
  );

  @override
  Widget build(BuildContext context) => BlocConsumer<WeeklyChallengesCubit, WeeklyChallengesState>(
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
      final detail = state.detail;
      final bool ready = !state.loading && !state.failed && detail != null;
      return PrismPage(
        title: context.l10n.challengeTitle,
        actions: [
          if (ready)
            PrismIconButton(
              icon: Icons.ios_share_rounded,
              tooltip: context.l10n.challengeShare,
              onPressed: () => _share(detail.challenge, detail),
            ),
        ],
        body: Builder(
          builder: (context) {
            if (state.loading) return PrismSkeleton.cards();
            if (state.failed || detail == null) {
              return GlintState(
                kind: GlintStateKind.error,
                title: state.error == ChallengeError.missing
                    ? context.l10n.challengeMissing
                    : context.l10n.challengeError,
                actionLabel: context.l10n.challengeRetry,
                actionVariant: PrismButtonVariant.tonal,
                onAction: () => _cubit.load(widget.challengeId),
              );
            }
            final challenge = detail.challenge;
            final open = challenge.isOpenAt(DateTime.now().toUtc());
            final l10n = context.l10n;
            return PrismRefresh(
              onRefresh: () => _cubit.load(widget.challengeId),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xl),
                children: [
                  Text(challenge.theme, style: PrismTextStyles.sectionTitle(context)),
                  const SizedBox(height: 12),
                  Text(l10n.challengeRules),
                  Text(
                    l10n.challengeVotingRules(
                      DateFormat.MMMEd(l10n.localeName).add_jm().format(challenge.closesAt.toLocal()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (open) ...[
                    if (detail.myEntryCount >= _maxChallengeEntries) Text(l10n.challengeLimit),
                    Row(
                      children: [
                        Expanded(
                          child: PrismButton(
                            label: l10n.challengeUpload,
                            expand: true,
                            onPressed: detail.myEntryCount >= _maxChallengeEntries
                                ? null
                                : () => _upload(challenge, detail.myEntryCount),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrismButton(
                            label: l10n.challengeAi,
                            variant: PrismButtonVariant.tonal,
                            expand: true,
                            onPressed: detail.myEntryCount >= _maxChallengeEntries
                                ? null
                                : () async {
                                    if (!_signedIn()) return;
                                    await context.router.push(AiTabRoute(challengeSeed: challenge.seed));
                                    if (mounted) unawaited(_cubit.load(widget.challengeId));
                                  },
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Text(switch (challenge.state) {
                      ChallengeState.votingClosed || ChallengeState.open => l10n.challengeWaiting,
                      ChallengeState.scheduled => l10n.challengeScheduled,
                      _ => challenge.noWinner ? l10n.challengeNoWinner : l10n.challengeClosed,
                    }),
                  if (challenge.winner case final winner?) ...[
                    Text(l10n.challengeWinner(winner.creatorName), style: PrismTextStyles.rowTitle(context)),
                    _entry(winner, [winner], 0, false),
                  ],
                  const SizedBox(height: 12),
                  PrismSegmented<ChallengeSort>(
                    values: const [ChallengeSort.top, ChallengeSort.newest],
                    selected: state.sort,
                    labelOf: (sort) => sort == ChallengeSort.top ? l10n.challengeTop : l10n.challengeNew,
                    onChanged: (sort) => _cubit.load(widget.challengeId, sort: sort),
                  ),
                  const SizedBox(height: 16),
                  if (detail.entries.isEmpty) ...[
                    if (_lastWeek(state.past, challenge.id) case final last?)
                      _LastWeek(
                        key: ValueKey(last.id),
                        challenge: last,
                        load: () => _cubit.topEntries(last.id),
                        onOpen: _open,
                      ),
                    SizedBox(
                      height: 240,
                      child: GlintState(kind: GlintStateKind.empty, title: l10n.challengeEmpty),
                    ),
                  ],
                  for (final (i, entry) in detail.entries.indexed) _entry(entry, detail.entries, i, open),
                  if (state.past.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    PrismSectionHeader(title: l10n.challengePast, padding: const EdgeInsets.only(bottom: 12)),
                    PrismGroup(
                      children: [
                        for (final past in state.past)
                          PrismRow(
                            title: past.theme,
                            subtitle: past.winner == null
                                ? past.noWinner
                                      ? l10n.challengeNoWinner
                                      : past.state == ChallengeState.votingClosed
                                      ? l10n.challengeWaiting
                                      : l10n.challengeClosed
                                : l10n.challengeWinner(past.winner!.creatorName),
                            onTap: () => context.router.push(WeeklyChallengeRoute(challengeId: past.id)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      );
    },
  );

  /// The most recent finished challenge that is not this one.
  WeeklyChallenge? _lastWeek(List<WeeklyChallenge> past, String currentId) {
    final rows = past.where((row) => row.id != currentId).toList()..sort((a, b) => b.closesAt.compareTo(a.closesAt));
    return rows.firstOrNull;
  }

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
          PrismRow(
            padding: const EdgeInsets.symmetric(vertical: 8),
            onTap: () => _open(entries, index),
            title: entry.title.isEmpty ? entry.creatorName : entry.title,
            subtitle: entry.creatorName,
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(l10n.challengeVotes(entry.voteCount)),
              if (open && !entry.mine)
                PrismButton(
                  icon: entry.voted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  label: entry.voted ? l10n.challengeUnvote : l10n.challengeVote,
                  variant: PrismButtonVariant.tonal,
                  size: PrismButtonSize.compact,
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

/// The top entries of the last challenge, under its theme. It shows nothing until entries load.
class _LastWeek extends StatefulWidget {
  const _LastWeek({super.key, required this.challenge, required this.load, required this.onOpen});
  final WeeklyChallenge challenge;
  final Future<List<ChallengeEntry>> Function() load;
  final Future<void> Function(List<ChallengeEntry> entries, int index) onOpen;
  @override
  State<_LastWeek> createState() => _LastWeekState();
}

class _LastWeekState extends State<_LastWeek> {
  late final Future<List<ChallengeEntry>> _entries = widget.load();
  @override
  Widget build(BuildContext context) => FutureBuilder<List<ChallengeEntry>>(
    future: _entries,
    builder: (context, snapshot) {
      final entries = snapshot.data ?? const <ChallengeEntry>[];
      if (entries.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrismSectionHeader(
            title: widget.challenge.theme,
            padding: const EdgeInsets.only(bottom: PrismSpace.sm),
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: PrismSpace.sm,
            crossAxisSpacing: PrismSpace.sm,
            childAspectRatio: 3 / 4,
            children: [
              for (final (i, entry) in entries.indexed)
                InkWell(
                  onTap: () => widget.onOpen(entries, i),
                  child: Semantics(
                    label: entry.title.isEmpty ? entry.creatorName : entry.title,
                    image: true,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: entry.thumbUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, _, _) =>
                            ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );
}
