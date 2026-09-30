import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/data/admin_moderation_repository.dart';
import 'package:Prism/features/admin_review/views/widgets/moderation_card.dart';
import 'package:Prism/features/admin_review/views/widgets/notification_sender_tab.dart';
import 'package:Prism/features/admin_review/views/widgets/reject_reason_sheet.dart';
import 'package:Prism/features/admin_review/views/widgets/report_cards.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:timeago/timeago.dart' as timeago;

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
          withCount('Walls', counts?.$1),
          withCount('Reports', counts?.$2),
          'Notifications',
        ];
        return PrismPage(
          title: 'Admin moderation',
          actions: <Widget>[
            PrismIconButton(
              icon: Icons.swipe_rounded,
              tooltip: 'Swipe review',
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
      emptyLabel: 'Nothing to review',
      emptyBody: 'New wallpapers show up here when someone uploads one.',
      errorLabel: 'Could not load pending wallpapers.',
      loadingHeight: 240,
      itemBuilder: (BuildContext context, FirestoreDocument wall) {
        final String previewUrl = wall.wallpaperThumb;
        final DateTime? createdAt = wall.createdAt;
        return ModerationCard(
          previewUrl: previewUrl,
          fullUrl: wall.wallpaperUrl.isNotEmpty ? wall.wallpaperUrl : previewUrl,
          facts: <(String, String)>[
            ('ID', wall.id),
            ('By', wall.by.isNotEmpty ? wall.by : 'Unknown'),
            ('Email', wall.email.isNotEmpty ? wall.email : 'Unknown'),
            ('Uploaded', createdAt != null ? timeago.format(createdAt.toLocal()) : 'Unknown'),
          ],
          onApprove: () async {
            await _repository.approveWall(wall);
            toasts.success('Wallpaper approved');
          },
          onReject: () => _confirmReject(
            context,
            onSubmit: (String reason) async {
              await _repository.rejectWall(wall, reason: reason);
              toasts.error('Wallpaper rejected');
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
      emptyLabel: 'No open reports',
      emptyBody: 'Reports from users show up here.',
      errorLabel: 'Could not load open reports.',
      loadingHeight: 200,
      itemBuilder: (BuildContext context, FirestoreDocument r) {
        final Map<String, dynamic> m = r.data();
        final String ct = m['contentType']?.toString() ?? '';
        final String tid = m['targetFirestoreDocId']?.toString() ?? '';
        final String reason = m['reason']?.toString() ?? '';
        final String uid = m['reporterUid']?.toString() ?? '';
        final DateTime? created = r.createdAt;
        final String timeStr = created != null ? timeago.format(created) : '';
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
              dialogTitle: 'Remove wallpaper',
              confirmButtonLabel: 'Remove wallpaper',
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
            body: 'Check your connection, then try again.',
            actionLabel: 'Try again',
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
    String dialogTitle = 'Reject wallpaper',
    String confirmButtonLabel = 'Reject wallpaper',
  }) {
    return showRejectReasonSheet(context, title: dialogTitle, confirmLabel: confirmButtonLabel, onSubmit: onSubmit);
  }
}
