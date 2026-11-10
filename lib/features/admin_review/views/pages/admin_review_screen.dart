import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/localized_relative_time.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/biz/depth_override.dart';
import 'package:Prism/features/admin_review/biz/drop_reserve.dart';
import 'package:Prism/features/admin_review/biz/reject_reasons.dart';
import 'package:Prism/features/admin_review/biz/wall_moderation.dart';
import 'package:Prism/features/admin_review/data/admin_moderation_repository.dart';
import 'package:Prism/features/admin_review/views/widgets/desktop_submission_queue.dart';
import 'package:Prism/features/admin_review/views/widgets/moderation_card.dart';
import 'package:Prism/features/admin_review/views/widgets/notification_sender_tab.dart';
import 'package:Prism/features/admin_review/views/widgets/reject_reason_sheet.dart';
import 'package:Prism/features/admin_review/views/widgets/report_cards.dart';
import 'package:Prism/features/admin_review/views/widgets/wall_resubmission_notice.dart';
import 'package:Prism/features/desktop_submission/desktop_submission.dart';
import 'package:Prism/features/editors_choice/biz/editors_choice_cubit.dart';
import 'package:Prism/features/editors_choice/domain/editors_choice_repository.dart';
import 'package:Prism/features/wallpaper_upload/biz/wall_release.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

@RoutePage()
class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({super.key, this.repository, this.desktopRepository});

  final AdminModerationRepository? repository;
  final DesktopSubmissionRepository? desktopRepository;

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen> with SingleTickerProviderStateMixin {
  late TabController _controller;
  late final AdminModerationRepository _repository;
  late final DesktopSubmissionRepository _desktopRepository;
  late Stream<List<FirestoreDocument>> _pendingWallsStream;
  late Stream<List<FirestoreDocument>> _openReportsStream;
  late Stream<(int, int, int)> _pendingCountsStream;
  final Map<String, Future<String?>> _requestTexts = <String, Future<String?>>{};
  EditorsChoiceCubit? _picks;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? getIt<AdminModerationRepository>();
    _desktopRepository = widget.desktopRepository ?? getIt<DesktopSubmissionRepository>();
    _controller = TabController(length: 4, vsync: this)..addListener(() => setState(() {}));
    _subscribeStreams();
  }

  void _subscribeStreams() {
    _pendingWallsStream = _repository.watchPendingWalls();
    _openReportsStream = _repository.watchOpenContentReports();
    _pendingCountsStream = Rx.combineLatest3<int, int, int, (int, int, int)>(
      _repository.watchPendingWalls().map(
        (List<FirestoreDocument> list) => list.where((wall) => !AdminModerationRepository.awaitsRelease(wall)).length,
      ),
      _repository.watchOpenContentReports().map((List<FirestoreDocument> list) => list.length),
      _desktopRepository.watchReviewQueue().map((List<DesktopSubmission> list) => list.length),
      (int a, int b, int c) => (a, b, c),
    );
  }

  void _retryStreams() {
    PrismHaptics.tap();
    _requestTexts.clear();
    setState(_subscribeStreams);
  }

  Future<String?> _requestText(String requestId) {
    final Future<String?>? cached = _requestTexts[requestId];
    if (cached != null) return cached;

    late final Future<String?> request;
    request = _repository
        .requestText(requestId)
        .then(
          (String? text) => text,
          onError: (Object error, StackTrace stackTrace) {
            if (identical(_requestTexts[requestId], request)) _requestTexts.remove(requestId);
            Error.throwWithStackTrace(error, stackTrace);
          },
        );
    _requestTexts[requestId] = request;
    return request;
  }

  @override
  void dispose() {
    unawaited(_picks?.close());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<(int, int, int)>(
      stream: _pendingCountsStream,
      builder: (BuildContext context, AsyncSnapshot<(int, int, int)> countSnapshot) {
        final counts = countSnapshot.hasError || countSnapshot.connectionState == ConnectionState.waiting
            ? null
            : countSnapshot.data;
        String withCount(String name, int? n) => n == null ? name : '$name ($n)';
        final List<String> labels = <String>[
          withCount(context.l10n.adminWalls, counts?.$1),
          withCount(context.l10n.adminReports, counts?.$2),
          withCount(context.l10n.adminDesktop, counts?.$3),
          context.l10n.adminNotifications,
        ];
        return PrismPage(
          title: context.l10n.adminTitle,
          actions: <Widget>[
            PrismIconButton(
              icon: Icons.swipe_rounded,
              tooltip: context.l10n.adminSwipeReview,
              onPressed: () {
                PrismHaptics.tap();
                unawaited(context.router.push(const SwipeReviewRoute()));
              },
            ),
            PrismIconButton(
              icon: Icons.redeem_rounded,
              tooltip: context.l10n.promoAdminEntry,
              onPressed: () {
                PrismHaptics.tap();
                unawaited(context.router.push(PromoCodesAdminRoute()));
              },
            ),
          ],
          headerBottom: Padding(
            padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xxs, PrismSpace.page, PrismSpace.sm),
            child: PrismSegmented<int>(
              values: const <int>[0, 1, 2, 3],
              selected: _controller.index,
              labelOf: (int i) => labels[i],
              onChanged: _controller.animateTo,
            ),
          ),
          body: TabBarView(
            controller: _controller,
            children: <Widget>[
              _buildWallTab(),
              _buildReportsTab(),
              DesktopSubmissionQueue(repository: _desktopRepository),
              const NotificationSenderTab(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWallTab() {
    return _buildPendingTab(
      stream: _pendingWallsStream,
      keyPrefix: 'wall',
      emptyLabel: context.l10n.adminNothingToReview,
      emptyBody: context.l10n.adminNewWallpapersPending,
      errorLabel: context.l10n.adminPendingWallsLoadError,
      loadingHeight: 240,
      itemBuilder: (BuildContext context, FirestoreDocument wall) {
        final AppLocalizations l10n = context.l10n;
        final String previewUrl = wall.wallpaperThumb;
        final DateTime? createdAt = wall.createdAt;
        final bool reserved = wall.payload['dropReserved'] == true;
        final Object? rawRequestId = wall.payload['requestId'];
        final String requestId = rawRequestId is String ? rawRequestId : '';
        if (requestId.isEmpty) return _wallCard(context, wall, previewUrl, createdAt, reserved, null);
        return FutureBuilder<String?>(
          future: _requestText(requestId),
          builder: (BuildContext context, AsyncSnapshot<String?> snapshot) => _wallCard(
            context,
            wall,
            previewUrl,
            createdAt,
            reserved,
            snapshot.connectionState == ConnectionState.done ? snapshot.data ?? l10n.adminUnknown : '…',
          ),
        );
      },
    );
  }

  /// "Fri 18:00 · Fri 14 Nov, 12:30 UTC": the admin's local time and UTC, since creators pick in their own zone.
  String? _releaseWhen(BuildContext context, FirestoreDocument wall) {
    final DateTime? releaseAt = WallRelease.of(wall).releaseAt;
    if (releaseAt == null) return null;
    final String local = releaseWhenText(
      releaseAt,
      now: DateTime.now(),
      locale: context.l10n.localeName,
      use24h: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return '$local · ${releaseUtcText(releaseAt)}';
  }

  String? _releaseFact(BuildContext context, FirestoreDocument wall) {
    final String? when = _releaseWhen(context, wall);
    if (when == null) return null;
    return AdminModerationRepository.awaitsRelease(wall)
        ? context.l10n.adminReleaseApproved(when)
        : context.l10n.adminReleaseRequested(when);
  }

  Widget _wallCard(
    BuildContext context,
    FirestoreDocument wall,
    String previewUrl,
    DateTime? createdAt,
    bool reserved,
    String? requestText,
  ) {
    final AppLocalizations l10n = context.l10n;
    return ModerationCard(
      previewUrl: previewUrl,
      fullUrl: wall.wallpaperUrl.isNotEmpty ? wall.wallpaperUrl : previewUrl,
      facts: <(String, String)>[
        (context.l10n.adminWallId, wall.id),
        (context.l10n.adminBy, wall.by.isNotEmpty ? wall.by : context.l10n.adminUnknown),
        (context.l10n.adminEmail, wall.email.isNotEmpty ? wall.email : context.l10n.adminUnknown),
        (
          context.l10n.adminUploaded,
          createdAt != null
              ? localizedRelativeTime(context.l10n, createdAt, locale: Localizations.localeOf(context))
              : context.l10n.adminUnknown,
        ),
        (context.l10n.adminDepth, depthTierLabel(context.l10n, wallDepthTier(wall))),
        if (reserved) (context.l10n.adminDrop, context.l10n.adminReservedForNextDrop),
        if (requestText != null) (context.l10n.adminFillsRequest, requestText),
        if (_releaseFact(context, wall) case final String release) (context.l10n.wallReleaseTitle, release),
      ],
      reserved: reserved,
      moderation: wallModeration(wall),
      details: WallResubmissionNotice(wallDocId: wall.id),
      liveData: wall.data(),
      onToggleReserve: canReserveForDrop(wall)
          ? () async {
              if (reserved) {
                await _repository.undoReserveWallForDrop(wall);
                toasts.success(l10n.adminRemovedFromNextDrop);
              } else {
                await _repository.reserveWallForDrop(wall);
                toasts.success(l10n.adminReservedForNextDrop);
              }
            }
          : null,
      onApprove: () async {
        final String? release = _releaseWhen(context, wall);
        final bool scheduled = await _repository.approveWall(wall);
        toasts.success(scheduled && release != null ? l10n.adminReleaseApproved(release) : l10n.adminWallpaperApproved);
      },
      onApproveAndPick: reserved
          ? null
          : () async {
              final AppLocalizations l10n = context.l10n;
              await _repository.approveWall(wall);
              try {
                await (_picks ??= getIt<EditorsChoiceCubit>()).setPick(wallDocId: wall.id, picked: true);
                unawaited(analytics.track(const EditorsChoicePickChangedEvent(picked: true, surface: 'review')));
                toasts.success(l10n.editorsChoicePicked);
              } on EditorsChoiceNotEligible {
                toasts.success(l10n.adminApprovedPickLater);
              } catch (_) {
                toasts.error(l10n.coreSomethingWentWrong);
              }
            },
      onReject: () => _confirmReject(
        context,
        onSubmit: (String reason, RejectReason? _) async {
          await _repository.rejectWall(wall, reason: reason);
          toasts.success(l10n.adminWallpaperRejected);
        },
      ),
    );
  }

  Widget _buildReportsTab() {
    return _buildPendingTab(
      stream: _openReportsStream,
      keyPrefix: 'report',
      emptyLabel: context.l10n.adminNoOpenReports,
      emptyBody: context.l10n.adminUserReportsShowHere,
      errorLabel: context.l10n.adminOpenReportsLoadError,
      loadingHeight: 200,
      itemBuilder: (BuildContext context, FirestoreDocument r) {
        final Map<String, dynamic> m = r.data();
        final String ct = m['contentType']?.toString() ?? '';
        final String tid = m['targetFirestoreDocId']?.toString() ?? '';
        final String reason = m['reason']?.toString() ?? '';
        final String uid = m['reporterUid']?.toString() ?? '';
        final DateTime? created = r.createdAt;
        final String timeStr = created == null
            ? ''
            : localizedRelativeTime(context.l10n, created, locale: Localizations.localeOf(context));
        if (ct == 'wall' && tid.isNotEmpty) {
          return WallContentReportCard(
            report: r,
            targetDocId: tid,
            reason: reason,
            reporterUid: uid,
            timeStr: timeStr,
            repository: _repository,
            onConfirmRemoveWithReason:
                ({required Future<void> Function(String reason, RejectReason? picked) onSubmit}) => _confirmReject(
                  context,
                  dialogTitle: context.l10n.adminRemoveWallpaper,
                  confirmButtonLabel: context.l10n.adminRemoveWallpaper,
                  onSubmit: onSubmit,
                ),
          );
        }
        final int colon = tid.lastIndexOf(':');
        if (ct == 'comment' && colon > 0 && colon < tid.length - 1) {
          return CommentReportCard(
            report: r,
            wallId: tid.substring(0, colon),
            commentId: tid.substring(colon + 1),
            reason: reason,
            reporterUid: uid,
            timeStr: timeStr,
            repository: _repository,
          );
        }
        if (ct == 'folder' && tid.isNotEmpty) {
          return FolderReportCard(
            report: r,
            folderId: tid,
            reason: reason,
            reporterUid: uid,
            timeStr: timeStr,
            repository: _repository,
          );
        }
        return GenericReportCard(
          report: r,
          contentType: ct,
          targetDocId: tid,
          reason: reason,
          reporterUid: uid,
          timeStr: timeStr,
          repository: _repository,
        );
      },
    );
  }

  Widget _buildPendingTab({
    required Stream<List<FirestoreDocument>> stream,
    required String keyPrefix,
    required String emptyLabel,
    required String emptyBody,
    required String errorLabel,
    required double loadingHeight,
    required Widget Function(BuildContext context, FirestoreDocument doc) itemBuilder,
  }) {
    return StreamBuilder<List<FirestoreDocument>>(
      stream: stream,
      builder: (BuildContext context, AsyncSnapshot<List<FirestoreDocument>> snapshot) {
        if (snapshot.hasError) {
          return GlintState(
            kind: GlintStateKind.error,
            title: errorLabel,
            body: context.l10n.adminCheckConnectionRetry,
            actionLabel: context.l10n.adminTryAgain,
            onAction: _retryStreams,
          );
        }
        if (!snapshot.hasData) {
          return PrismSkeleton.cards(height: loadingHeight);
        }
        final List<FirestoreDocument> docs = snapshot.data!;
        if (docs.isEmpty) {
          return GlintState(kind: GlintStateKind.nothingNew, title: emptyLabel, body: emptyBody);
        }
        final Widget list = ListView.separated(
          padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xxl),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: PrismSpace.sm),
          findItemIndexCallback: (Key key) {
            final int index = docs.indexWhere(
              (FirestoreDocument doc) => '$keyPrefix-${doc.id}' == (key as ValueKey<String>).value,
            );
            return index < 0 ? null : index;
          },
          itemBuilder: (BuildContext context, int index) => KeyedSubtree(
            key: ValueKey<String>('$keyPrefix-${docs[index].id}'),
            child: itemBuilder(context, docs[index]),
          ),
        );
        return keyPrefix == 'wall'
            ? WallResubmissionScope(walls: docs, actions: _repository.metadataActions, child: list)
            : list;
      },
    );
  }

  Future<void> _confirmReject(
    BuildContext context, {
    required Future<void> Function(String reason, RejectReason? picked) onSubmit,
    String? dialogTitle,
    String? confirmButtonLabel,
  }) {
    return showRejectReasonSheet(context, title: dialogTitle, confirmLabel: confirmButtonLabel, onSubmit: onSubmit);
  }
}
