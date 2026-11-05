import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/biz/reject_reasons.dart';
import 'package:Prism/features/admin_review/views/widgets/desktop_submission_card.dart';
import 'package:Prism/features/admin_review/views/widgets/reject_reason_sheet.dart';
import 'package:Prism/features/desktop_submission/desktop_submission.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

/// The Desktop tab: pending desktop versions, each approved or rejected from its card.
class DesktopSubmissionQueue extends StatefulWidget {
  const DesktopSubmissionQueue({super.key, required this.repository});

  final DesktopSubmissionRepository repository;

  @override
  State<DesktopSubmissionQueue> createState() => _DesktopSubmissionQueueState();
}

class _DesktopSubmissionQueueState extends State<DesktopSubmissionQueue> {
  late Stream<List<DesktopSubmission>> _queueStream;

  @override
  void initState() {
    super.initState();
    _queueStream = widget.repository.watchReviewQueue();
  }

  void _retry() {
    PrismHaptics.tap();
    setState(() => _queueStream = widget.repository.watchReviewQueue());
  }

  Future<void> _approve(DesktopSubmission submission) async {
    final AppLocalizations l10n = context.l10n;
    try {
      await widget.repository.review(submissionId: submission.id, approve: true);
    } on DesktopReviewWallUnavailable {
      toasts.error(l10n.adminDesktopWallUnavailable);
      return;
    } catch (error, stackTrace) {
      logger.e('Desktop version approve failed', tag: 'AdminReview', error: error, stackTrace: stackTrace);
      toasts.error(l10n.coreSomethingWentWrong);
      return;
    }
    unawaited(analytics.track(DesktopUploadApprovedEvent(wallId: submission.shareId)));
    toasts.success(l10n.adminDesktopApproved);
  }

  Future<void> _reject(DesktopSubmission submission) {
    final AppLocalizations l10n = context.l10n;
    return showRejectReasonSheet(
      context,
      title: l10n.adminDesktopRejectTitle,
      confirmLabel: l10n.adminDesktopRejectTitle,
      onSubmit: (String reason, RejectReason? picked) async {
        final String reasonCode = picked?.name ?? 'other';
        await widget.repository.review(
          submissionId: submission.id,
          approve: false,
          reason: reason,
          reasonCode: reasonCode,
        );
        unawaited(analytics.track(DesktopUploadRejectedEvent(wallId: submission.shareId, reason: reasonCode)));
        toasts.success(l10n.adminDesktopRejected);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DesktopSubmission>>(
      stream: _queueStream,
      builder: (BuildContext context, AsyncSnapshot<List<DesktopSubmission>> snapshot) {
        if (snapshot.hasError) {
          return GlintState(
            kind: GlintStateKind.error,
            title: context.l10n.adminDesktopLoadError,
            body: context.l10n.adminCheckConnectionRetry,
            actionLabel: context.l10n.adminTryAgain,
            onAction: _retry,
          );
        }
        if (!snapshot.hasData) {
          return PrismSkeleton.cards(height: 240);
        }
        final List<DesktopSubmission> submissions = snapshot.data!;
        if (submissions.isEmpty) {
          return GlintState(
            kind: GlintStateKind.nothingNew,
            title: context.l10n.adminDesktopEmptyTitle,
            body: context.l10n.adminDesktopEmptyBody,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xxl),
          itemCount: submissions.length,
          separatorBuilder: (_, _) => const SizedBox(height: PrismSpace.sm),
          findItemIndexCallback: (Key key) {
            final int index = submissions.indexWhere(
              (DesktopSubmission s) => 'desktop-${s.id}' == (key as ValueKey<String>).value,
            );
            return index < 0 ? null : index;
          },
          itemBuilder: (BuildContext context, int index) {
            final DesktopSubmission submission = submissions[index];
            return KeyedSubtree(
              key: ValueKey<String>('desktop-${submission.id}'),
              child: DesktopSubmissionCard(
                submission: submission,
                onApprove: () => _approve(submission),
                onReject: () => _reject(submission),
              ),
            );
          },
        );
      },
    );
  }
}
