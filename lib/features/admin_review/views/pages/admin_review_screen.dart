import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/localized_relative_time.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/biz/depth_override.dart';
import 'package:Prism/features/admin_review/biz/drop_reserve.dart';
import 'package:Prism/features/admin_review/data/admin_moderation_repository.dart';
import 'package:Prism/features/admin_review/views/widgets/moderation_card.dart';
import 'package:Prism/features/admin_review/views/widgets/notification_sender_tab.dart';
import 'package:Prism/features/admin_review/views/widgets/reject_reason_sheet.dart';
import 'package:Prism/features/admin_review/views/widgets/report_cards.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

@RoutePage()
class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({super.key, this.repository});

  final AdminModerationRepository? repository;

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen> with SingleTickerProviderStateMixin {
  late TabController _controller;
  late final AdminModerationRepository _repository;
  late Stream<List<FirestoreDocument>> _pendingWallsStream;
  late Stream<List<FirestoreDocument>> _openReportsStream;
  late Stream<(int, int)> _pendingCountsStream;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? getIt<AdminModerationRepository>();
    _controller = TabController(length: 3, vsync: this)..addListener(() => setState(() {}));
    _subscribeStreams();
  }

  void _subscribeStreams() {
    _pendingWallsStream = _repository.watchPendingWalls();
    _openReportsStream = _repository.watchOpenContentReports();
    _pendingCountsStream = Rx.combineLatest2<int, int, (int, int)>(
      _repository.watchPendingWalls().map((List<FirestoreDocument> list) => list.length),
      _repository.watchOpenContentReports().map((List<FirestoreDocument> list) => list.length),
      (int a, int b) => (a, b),
    );
  }

  void _retryStreams() {
    PrismHaptics.tap();
    setState(_subscribeStreams);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<(int, int)>(
      stream: _pendingCountsStream,
      builder: (BuildContext context, AsyncSnapshot<(int, int)> countSnapshot) {
        final counts = countSnapshot.hasError || countSnapshot.connectionState == ConnectionState.waiting
            ? null
            : countSnapshot.data;
        String withCount(String name, int? n) => n == null ? name : '$name ($n)';
        final List<String> labels = <String>[
          withCount(context.l10n.adminWalls, counts?.$1),
          withCount(context.l10n.adminReports, counts?.$2),
          context.l10n.adminNotifications,
        ];
        return PrismPage(
          title: context.l10n.adminTitle,
          actions: <Widget>[
            PrismIconButton(
              icon: Icons.swipe_rounded,
              tooltip: context.l10n.adminSwipeReview,
              onPressed: () => context.router.push(const SwipeReviewRoute()),
            ),
          ],
          headerBottom: Padding(
            padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xxs, PrismSpace.page, PrismSpace.sm),
            child: PrismSegmented<int>(
              values: const <int>[0, 1, 2],
              selected: _controller.index,
              labelOf: (int i) => labels[i],
              onChanged: _controller.animateTo,
            ),
          ),
          body: TabBarView(
            controller: _controller,
            children: <Widget>[_buildWallTab(), _buildReportsTab(), const NotificationSenderTab()],
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
            (context.l10n.adminDepth, depthTierLabel(wallDepthTier(wall))),
            if (reserved) (context.l10n.adminDrop, context.l10n.adminReservedForNextDrop),
          ],
          reserved: reserved,
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
            await _repository.approveWall(wall);
            toasts.success(l10n.adminWallpaperApproved);
          },
          onReject: () => _confirmReject(
            context,
            onSubmit: (String reason) async {
              await _repository.rejectWall(wall, reason: reason);
              toasts.success(l10n.adminWallpaperRejected);
            },
          ),
        );
      },
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
            onConfirmRemoveWithReason: ({required Future<void> Function(String reason) onSubmit}) => _confirmReject(
              context,
              dialogTitle: context.l10n.adminRemoveWallpaper,
              confirmButtonLabel: context.l10n.adminRemoveWallpaper,
              onSubmit: onSubmit,
            ),
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
        return ListView.separated(
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
      },
    );
  }

  Future<void> _confirmReject(
    BuildContext context, {
    required Future<void> Function(String reason) onSubmit,
    String? dialogTitle,
    String? confirmButtonLabel,
  }) {
    return showRejectReasonSheet(context, title: dialogTitle, confirmLabel: confirmButtonLabel, onSubmit: onSubmit);
  }
}
