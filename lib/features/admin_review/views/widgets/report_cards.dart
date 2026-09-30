import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/data/admin_moderation_repository.dart';
import 'package:Prism/features/admin_review/views/widgets/moderation_bits.dart';
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
    final PageRouteInfo? route = await const NotificationRouteMapper().fromRoute(
      route: 'wall',
      wallId: widget.targetDocId,
      profileIdentifier: '',
      sourceTag: 'admin.content_report',
    );
    if (!context.mounted) {
      return;
    }
    if (route != null) {
      await context.router.push(route);
    } else {
      toasts.error('Wallpaper not found');
    }
  }

  Future<void> _keepWallpaper() async {
    if (_isKeeping) return;
    setState(() => _isKeeping = true);
    try {
      await widget.repository.markContentReportReviewed(widget.report.id, resolution: 'dismissed');
      toasts.success('Report dismissed. Wallpaper kept.');
    } catch (e, st) {
      logger.e('mark report dismissed failed', tag: 'AdminReview', error: e, stackTrace: st);
      toasts.error('Could not dismiss the report. Try again.');
    } finally {
      if (mounted) setState(() => _isKeeping = false);
    }
  }

  Future<void> _removeWallpaper() {
    return widget.onConfirmRemoveWithReason(
      onSubmit: (String reason) async {
        final bool removed = await widget.repository.rejectWallByFirestoreDocumentId(
          widget.targetDocId,
          reason: reason,
        );
        await widget.repository.markContentReportReviewed(widget.report.id, resolution: 'content_removed');
        if (removed) {
          toasts.success('Wallpaper removed');
        } else {
          toasts.error('Wallpaper was already gone. Report closed.');
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
                    semanticLabel: 'Open wallpaper',
                    onTap: () => _openWallpaperDetail(context),
                  );
                },
              ),
              const SizedBox(width: PrismSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const PrismTag(label: 'Wallpaper report', tone: PrismTone.warning),
                    const SizedBox(height: PrismSpace.xs),
                    Text(
                      widget.reason.isEmpty ? 'No reason given' : widget.reason,
                      style: PrismTextStyles.cardTitle(context),
                    ),
                    const SizedBox(height: PrismSpace.xs),
                    ModerationFact(label: 'Reported', value: widget.timeStr.isEmpty ? 'Unknown' : widget.timeStr),
                    ModerationFact(label: 'Target', value: widget.targetDocId),
                    ModerationFact(
                      label: 'Reporter',
                      value: widget.reporterUid.isEmpty ? 'Unknown' : widget.reporterUid,
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
                tooltip: 'Open wallpaper',
                filled: true,
                onPressed: () => _openWallpaperDetail(context),
              ),
              const Spacer(),
              PrismButton(
                label: 'Keep wallpaper',
                variant: PrismButtonVariant.tonal,
                size: PrismButtonSize.compact,
                loading: _isKeeping,
                onPressed: _keepWallpaper,
              ),
              const SizedBox(width: PrismSpace.xs),
              ModerationDangerButton(label: 'Remove', onPressed: _isKeeping ? null : _removeWallpaper),
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
    setState(() => _busy = true);
    try {
      await widget.repository.markContentReportReviewed(widget.report.id);
      toasts.success('Marked reviewed');
    } catch (e, st) {
      logger.e('mark report failed', tag: 'AdminReview', error: e, stackTrace: st);
      toasts.error('Could not mark the report reviewed. Try again.');
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
              child: PrismTag(label: '${widget.contentType} report'),
            ),
            const SizedBox(height: PrismSpace.xs),
          ],
          Text(widget.reason.isEmpty ? 'No reason given' : widget.reason, style: PrismTextStyles.cardTitle(context)),
          const SizedBox(height: PrismSpace.xs),
          ModerationFact(label: 'Reported', value: widget.timeStr.isEmpty ? 'Unknown' : widget.timeStr),
          ModerationFact(label: 'Target', value: widget.targetDocId.isEmpty ? 'Unknown' : widget.targetDocId),
          ModerationFact(label: 'Reporter', value: widget.reporterUid.isEmpty ? 'Unknown' : widget.reporterUid),
          const SizedBox(height: PrismSpace.xxs),
          Align(
            alignment: Alignment.centerRight,
            child: PrismButton(
              label: 'Mark reviewed',
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
