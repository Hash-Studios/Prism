import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/biz/admin_review_localization.dart';
import 'package:Prism/features/admin_review/data/admin_moderation_repository.dart';
import 'package:Prism/features/admin_review/views/widgets/moderation_bits.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

typedef ConfirmRemoveWithReason = Future<void> Function({required Future<void> Function(String reason) onSubmit});

/// An open report on a wallpaper: the wallpaper, the reason, and Keep or Remove.
class WallContentReportCard extends StatefulWidget {
  const WallContentReportCard({
    super.key,
    required this.report,
    required this.targetDocId,
    required this.reason,
    required this.reporterUid,
    required this.timeStr,
    required this.repository,
    required this.onConfirmRemoveWithReason,
  });

  final FirestoreDocument report;
  final String targetDocId;
  final String reason;
  final String reporterUid;
  final String timeStr;
  final AdminModerationRepository repository;
  final ConfirmRemoveWithReason onConfirmRemoveWithReason;

  @override
  State<WallContentReportCard> createState() => _WallContentReportCardState();
}

class _WallContentReportCardState extends State<WallContentReportCard> {
  late final Future<Map<String, dynamic>?> _wallFuture;
  bool _isKeeping = false;

  @override
  void initState() {
    super.initState();
    _wallFuture = firestoreClient.getById<Map<String, dynamic>>(
      FirebaseCollections.walls,
      widget.targetDocId,
      (Map<String, dynamic> data, String _) => data,
      sourceTag: 'admin_review.report_wall_preview',
    );
  }

  Future<void> _openWallpaperDetail(BuildContext context) async {
    final AppLocalizations l10n = context.l10n;
    final PageRouteInfo? route = await const NotificationRouteMapper().fromRoute(
      route: 'wall',
      wallId: widget.targetDocId,
      profileIdentifier: '',
      sourceTag: 'admin.content_report',
      fallbackToInbox: false,
    );
    if (!context.mounted) {
      return;
    }
    if (route != null) {
      await context.router.push(route);
    } else {
      toasts.error(l10n.adminWallpaperNotFound);
    }
  }

  Future<void> _keepWallpaper() async {
    if (_isKeeping) return;
    final AppLocalizations l10n = context.l10n;
    setState(() => _isKeeping = true);
    try {
      await widget.repository.markContentReportReviewed(widget.report.id, resolution: 'dismissed');
      toasts.success(l10n.adminReportDismissedKept);
    } catch (e, st) {
      logger.e('mark report dismissed failed', tag: 'AdminReview', error: e, stackTrace: st);
      toasts.error(l10n.adminReportDismissFailed);
    } finally {
      if (mounted) setState(() => _isKeeping = false);
    }
  }

  Future<void> _removeWallpaper() {
    final AppLocalizations l10n = context.l10n;
    return widget.onConfirmRemoveWithReason(
      onSubmit: (String reason) async {
        final bool removed = await widget.repository.rejectWallByFirestoreDocumentId(
          widget.targetDocId,
          reason: reason,
        );
        await widget.repository.markContentReportReviewed(widget.report.id, resolution: 'content_removed');
        if (removed) {
          toasts.success(l10n.adminWallpaperRemoved);
        } else {
          toasts.success(l10n.adminWallpaperAlreadyGone);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PrismCard(
      padding: const EdgeInsets.all(PrismSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FutureBuilder<Map<String, dynamic>?>(
                future: _wallFuture,
                builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>?> snap) {
                  final bool waiting = snap.connectionState != ConnectionState.done;
                  if (waiting) {
                    return const PrismSkeleton(child: PrismBone(width: 72, height: 128, radius: PrismRadius.sm));
                  }
                  return ModerationThumb(
                    url: snap.data?['wallpaper_thumb']?.toString() ?? '',
                    width: 72,
                    height: 128,
                    semanticLabel: context.l10n.adminOpenWallpaper,
                    onTap: () => _openWallpaperDetail(context),
                  );
                },
              ),
              const SizedBox(width: PrismSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    PrismTag(label: context.l10n.adminWallpaperReport, tone: PrismTone.warning),
                    const SizedBox(height: PrismSpace.xs),
                    Text(
                      widget.reason.isEmpty
                          ? context.l10n.adminNoReasonGiven
                          : adminReviewReportReasonLabel(widget.reason, context.l10n),
                      style: PrismTextStyles.cardTitle(context),
                    ),
                    const SizedBox(height: PrismSpace.xs),
                    ModerationFact(
                      label: context.l10n.adminReported,
                      value: widget.timeStr.isEmpty ? context.l10n.adminUnknown : widget.timeStr,
                    ),
                    ModerationFact(label: context.l10n.adminTarget, value: widget.targetDocId),
                    ModerationFact(
                      label: context.l10n.adminReporter,
                      value: widget.reporterUid.isEmpty ? context.l10n.adminUnknown : widget.reporterUid,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: PrismSpace.sm),
          Row(
            children: <Widget>[
              PrismIconButton(
                icon: Icons.open_in_new_rounded,
                tooltip: context.l10n.adminOpenWallpaper,
                filled: true,
                onPressed: () => _openWallpaperDetail(context),
              ),
              const SizedBox(width: PrismSpace.xs),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: PrismSpace.xs,
                  runSpacing: PrismSpace.xs,
                  children: <Widget>[
                    PrismButton(
                      label: context.l10n.adminKeepWallpaper,
                      variant: PrismButtonVariant.tonal,
                      size: PrismButtonSize.compact,
                      loading: _isKeeping,
                      onPressed: _keepWallpaper,
                    ),
                    ModerationDangerButton(
                      label: context.l10n.adminRemove,
                      onPressed: _isKeeping ? null : _removeWallpaper,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// An open report on anything other than a wallpaper: the reason, the ids, and Mark reviewed.
class GenericReportCard extends StatefulWidget {
  const GenericReportCard({
    super.key,
    required this.report,
    required this.contentType,
    required this.targetDocId,
    required this.reason,
    required this.reporterUid,
    required this.timeStr,
    required this.repository,
  });

  final FirestoreDocument report;
  final String contentType;
  final String targetDocId;
  final String reason;
  final String reporterUid;
  final String timeStr;
  final AdminModerationRepository repository;

  @override
  State<GenericReportCard> createState() => _GenericReportCardState();
}

class _GenericReportCardState extends State<GenericReportCard> {
  bool _busy = false;

  Future<void> _markReviewed() async {
    if (_busy) return;
    final AppLocalizations l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await widget.repository.markContentReportReviewed(widget.report.id);
      toasts.success(l10n.adminMarkedReviewed);
    } catch (e, st) {
      logger.e('mark report failed', tag: 'AdminReview', error: e, stackTrace: st);
      toasts.error(l10n.adminMarkReviewedFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrismCard(
      padding: const EdgeInsets.all(PrismSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.contentType.isNotEmpty) ...<Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: PrismTag(
                label: context.l10n.adminContentTypeReport(
                  adminReviewContentTypeLabel(widget.contentType, context.l10n),
                ),
              ),
            ),
            const SizedBox(height: PrismSpace.xs),
          ],
          Text(
            widget.reason.isEmpty
                ? context.l10n.adminNoReasonGiven
                : adminReviewReportReasonLabel(widget.reason, context.l10n),
            style: PrismTextStyles.cardTitle(context),
          ),
          const SizedBox(height: PrismSpace.xs),
          ModerationFact(
            label: context.l10n.adminReported,
            value: widget.timeStr.isEmpty ? context.l10n.adminUnknown : widget.timeStr,
          ),
          ModerationFact(
            label: context.l10n.adminTarget,
            value: widget.targetDocId.isEmpty ? context.l10n.adminUnknown : widget.targetDocId,
          ),
          ModerationFact(
            label: context.l10n.adminReporter,
            value: widget.reporterUid.isEmpty ? context.l10n.adminUnknown : widget.reporterUid,
          ),
          const SizedBox(height: PrismSpace.xxs),
          Align(
            alignment: Alignment.centerRight,
            child: PrismButton(
              label: context.l10n.adminMarkReviewed,
              variant: PrismButtonVariant.tonal,
              size: PrismButtonSize.compact,
              loading: _busy,
              onPressed: _markReviewed,
            ),
          ),
        ],
      ),
    );
  }
}
