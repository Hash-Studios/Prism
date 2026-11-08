import 'dart:async';

import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/deep_link_dispatcher.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/biz/admin_review_localization.dart';
import 'package:Prism/features/admin_review/biz/reject_reasons.dart';
import 'package:Prism/features/admin_review/data/admin_moderation_repository.dart';
import 'package:Prism/features/admin_review/views/widgets/moderation_bits.dart';
import 'package:Prism/features/folders/data/repositories/public_folders_repository_impl.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/views/widgets/folder_cover.dart';
import 'package:Prism/features/wall_comments/data/wall_comments_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

typedef ConfirmRemoveWithReason =
    Future<void> Function({required Future<void> Function(String reason, RejectReason? picked) onSubmit});

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
    await DeepLinkDispatcher.maybeOf(context.router)?.openActionLoader(
      () => const NotificationRouteMapper().actionFromRoute(
        route: 'wall',
        wallId: widget.targetDocId,
        sourceTag: 'admin.content_report',
        fallbackToInbox: false,
      ),
      rawUri: '/share/${widget.targetDocId}',
      source: DeepLinkSourceValue.inApp,
      targetType: TargetTypeValue.share,
    );
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
      onSubmit: (String reason, RejectReason? _) async {
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
                onPressed: () {
                  PrismHaptics.tap();
                  unawaited(_openWallpaperDetail(context));
                },
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

/// An open report on a comment: the comment, the reason, and Keep (shows it again) or Remove (deletes it).
class CommentReportCard extends StatefulWidget {
  const CommentReportCard({
    super.key,
    required this.report,
    required this.wallId,
    required this.commentId,
    required this.reason,
    required this.reporterUid,
    required this.timeStr,
    required this.repository,
  });

  final FirestoreDocument report;
  final String wallId;
  final String commentId;
  final String reason;
  final String reporterUid;
  final String timeStr;
  final AdminModerationRepository repository;

  @override
  State<CommentReportCard> createState() => _CommentReportCardState();
}

class _CommentReportCardState extends State<CommentReportCard> {
  late Future<Map<String, dynamic>?> _comment = _loadComment();

  Future<Map<String, dynamic>?> _loadComment() => firestoreClient.getById<Map<String, dynamic>>(
    FirebaseCollections.wallComments(widget.wallId),
    widget.commentId,
    (Map<String, dynamic> data, String _) => data,
    sourceTag: 'admin_review.report_comment',
  );
  bool _busy = false;

  @override
  void didUpdateWidget(CommentReportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wallId != widget.wallId || oldWidget.commentId != widget.commentId) {
      _comment = _loadComment();
    }
  }

  Future<void> _resolve({required bool keep}) async {
    if (_busy) return;
    final AppLocalizations l10n = context.l10n;
    final CommentReportCard target = widget;
    final WallCommentsRepository comments = getIt<WallCommentsRepository>();
    setState(() => _busy = true);
    try {
      if (keep) {
        await comments.setHidden(wallId: target.wallId, commentId: target.commentId, hidden: false);
      } else {
        await comments.delete(wallId: target.wallId, commentId: target.commentId);
      }
      await target.repository.markContentReportReviewed(
        target.report.id,
        resolution: keep ? 'dismissed' : 'content_removed',
      );
      toasts.success(keep ? l10n.adminCommentKept : l10n.adminCommentRemoved);
    } catch (e, st) {
      logger.e('resolve comment report failed', tag: 'AdminReview', error: e, stackTrace: st);
      toasts.error(l10n.adminMarkReviewedFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return PrismCard(
      padding: const EdgeInsets.all(PrismSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: PrismTag(label: l10n.adminCommentReport, tone: PrismTone.warning),
          ),
          const SizedBox(height: PrismSpace.xs),
          FutureBuilder<Map<String, dynamic>?>(
            future: _comment,
            builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>?> snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const PrismSkeleton(child: PrismBone(height: 40, radius: PrismRadius.sm));
              }
              final Map<String, dynamic>? data = snap.data;
              return Text(
                data == null ? l10n.adminCommentGone : '${data['authorName'] ?? ''}: ${data['text'] ?? ''}',
                style: PrismTextStyles.body(context).copyWith(color: Theme.of(context).colorScheme.onSurface),
              );
            },
          ),
          const SizedBox(height: PrismSpace.xs),
          Text(
            widget.reason.isEmpty ? l10n.adminNoReasonGiven : adminReviewReportReasonLabel(widget.reason, l10n),
            style: PrismTextStyles.cardTitle(context),
          ),
          ModerationFact(label: l10n.adminReported, value: widget.timeStr.isEmpty ? l10n.adminUnknown : widget.timeStr),
          ModerationFact(label: l10n.adminTarget, value: '${widget.wallId}:${widget.commentId}'),
          ModerationFact(
            label: l10n.adminReporter,
            value: widget.reporterUid.isEmpty ? l10n.adminUnknown : widget.reporterUid,
          ),
          const SizedBox(height: PrismSpace.xs),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: PrismSpace.xs,
            runSpacing: PrismSpace.xs,
            children: <Widget>[
              PrismButton(
                label: l10n.adminKeepComment,
                variant: PrismButtonVariant.tonal,
                size: PrismButtonSize.compact,
                loading: _busy,
                onPressed: () => _resolve(keep: true),
              ),
              ModerationDangerButton(label: l10n.adminRemove, onPressed: _busy ? null : () => _resolve(keep: false)),
            ],
          ),
        ],
      ),
    );
  }
}

/// An open report on a public folder: the cover, name and owner, the reason, and Keep folder or Hide from discovery.
/// Hiding takes the folder out of the discover lists. It stays public and opens by link.
class FolderReportCard extends StatefulWidget {
  const FolderReportCard({
    super.key,
    required this.report,
    required this.folderId,
    required this.reason,
    required this.reporterUid,
    required this.timeStr,
    required this.repository,
  });

  final FirestoreDocument report;
  final String folderId;
  final String reason;
  final String reporterUid;
  final String timeStr;
  final AdminModerationRepository repository;

  @override
  State<FolderReportCard> createState() => _FolderReportCardState();
}

class _FolderReportCardState extends State<FolderReportCard> {
  late Future<PublicFolderEntity?> _folder = _load();
  bool _busy = false;

  Future<PublicFolderEntity?> _load() => firestoreClient.getById<PublicFolderEntity>(
    FirebaseCollections.publicFolders,
    widget.folderId,
    publicFolderFromDoc,
    sourceTag: 'admin_review.report_folder',
  );

  @override
  void didUpdateWidget(FolderReportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folderId != widget.folderId) _folder = _load();
  }

  Future<void> _resolve({required bool hide}) async {
    if (_busy) return;
    final AppLocalizations l10n = context.l10n;
    final FolderReportCard target = widget;
    setState(() => _busy = true);
    try {
      if (hide) await target.repository.setFolderDiscoveryHidden(target.folderId, hidden: true);
      await target.repository.markContentReportReviewed(
        target.report.id,
        resolution: hide ? 'hidden_from_discovery' : 'dismissed',
      );
      toasts.success(hide ? l10n.adminFolderHiddenFromDiscovery : l10n.adminFolderKept);
    } catch (e, st) {
      logger.e('resolve folder report failed', tag: 'AdminReview', error: e, stackTrace: st);
      toasts.error(l10n.adminMarkReviewedFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return PrismCard(
      padding: const EdgeInsets.all(PrismSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: PrismTag(label: l10n.adminFolderReport, tone: PrismTone.warning),
          ),
          const SizedBox(height: PrismSpace.xs),
          FutureBuilder<PublicFolderEntity?>(
            future: _folder,
            builder: (BuildContext context, AsyncSnapshot<PublicFolderEntity?> snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const PrismSkeleton(child: PrismBone(height: 72, radius: PrismRadius.sm));
              }
              final PublicFolderEntity? folder = snap.data;
              if (folder == null) return Text(l10n.foldersUnavailableTitle, style: PrismTextStyles.body(context));
              return Row(
                children: <Widget>[
                  FolderCover(covers: folder.covers, size: 72),
                  const SizedBox(width: PrismSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(folder.name, style: PrismTextStyles.rowTitle(context)),
                        Text(l10n.foldersItemCount(folder.itemCount), style: PrismTextStyles.caption(context)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: PrismSpace.xs),
          Text(
            widget.reason.isEmpty ? l10n.adminNoReasonGiven : adminReviewReportReasonLabel(widget.reason, l10n),
            style: PrismTextStyles.cardTitle(context),
          ),
          ModerationFact(label: l10n.adminReported, value: widget.timeStr.isEmpty ? l10n.adminUnknown : widget.timeStr),
          ModerationFact(label: l10n.adminTarget, value: widget.folderId),
          ModerationFact(
            label: l10n.adminReporter,
            value: widget.reporterUid.isEmpty ? l10n.adminUnknown : widget.reporterUid,
          ),
          const SizedBox(height: PrismSpace.xs),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: PrismSpace.xs,
            runSpacing: PrismSpace.xs,
            children: <Widget>[
              PrismButton(
                label: l10n.adminKeepFolder,
                variant: PrismButtonVariant.tonal,
                size: PrismButtonSize.compact,
                loading: _busy,
                onPressed: () => _resolve(hide: false),
              ),
              ModerationDangerButton(
                label: l10n.adminHideFromDiscovery,
                onPressed: _busy ? null : () => _resolve(hide: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
