import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/utils/localized_relative_time.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/views/widgets/full_screen_image_view.dart';
import 'package:Prism/features/admin_review/views/widgets/moderation_bits.dart';
import 'package:Prism/features/desktop_submission/desktop_submission.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A pending desktop version: the phone wallpaper beside the wide image, its facts, and Approve or Reject.
class DesktopSubmissionCard extends StatefulWidget {
  const DesktopSubmissionCard({super.key, required this.submission, required this.onApprove, required this.onReject});

  final DesktopSubmission submission;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;

  @override
  State<DesktopSubmissionCard> createState() => _DesktopSubmissionCardState();
}

class _DesktopSubmissionCardState extends State<DesktopSubmissionCard> {
  bool _isBusy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final DesktopSubmission submission = widget.submission;
    final bool stacked = MediaQuery.textScalerOf(context).scale(16) / 16 >= 1.6;
    final DateTime? createdAt = submission.createdAt;
    return PrismCard(
      padding: const EdgeInsets.all(PrismSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _previews(context, stacked: stacked),
          const SizedBox(height: PrismSpace.sm),
          Text(
            submission.wallTitle.isEmpty ? l10n.adminUnknown : submission.wallTitle,
            style: PrismTextStyles.cardTitle(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: PrismSpace.xs),
          ModerationFact(
            label: l10n.adminBy,
            value: submission.creatorName.isNotEmpty ? submission.creatorName : l10n.adminUnknown,
          ),
          ModerationFact(
            label: l10n.adminDesktopUploadSize,
            value: l10n.desktopUploadSize(submission.sourceWidth, submission.sourceHeight, submission.aspect),
          ),
          ModerationFact(
            label: l10n.adminUploaded,
            value: createdAt != null
                ? localizedRelativeTime(l10n, createdAt, locale: Localizations.localeOf(context))
                : l10n.adminUnknown,
          ),
          if (submission.replaces)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(l10n.adminDesktopReplaces, style: PrismTextStyles.caption(context)),
            ),
          const SizedBox(height: PrismSpace.sm),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: PrismSpace.xs,
            runSpacing: PrismSpace.xs,
            children: <Widget>[
              // Reject opens the reason sheet, which shows its own loading state while it saves.
              ModerationDangerButton(label: l10n.adminReject, onPressed: _isBusy ? null : widget.onReject),
              PrismButton(
                label: l10n.adminApprove,
                size: PrismButtonSize.compact,
                loading: _isBusy,
                onPressed: _isBusy ? null : () => _run(widget.onApprove),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previews(BuildContext context, {required bool stacked}) {
    final AppLocalizations l10n = context.l10n;
    final DesktopSubmission submission = widget.submission;
    final VoidCallback? openFull = submission.thumbUrl.isEmpty
        ? null
        : () {
            PrismHaptics.tap();
            FullScreenImageView.show(context, submission.thumbUrl);
          };
    final Widget phone = AspectRatio(
      aspectRatio: 9 / 19.5,
      child: Semantics(
        image: true,
        label: l10n.desktopUploadPhoneSemantic,
        child: _image(context, submission.wallThumb),
      ),
    );
    final Widget desktop = AspectRatio(
      aspectRatio: 16 / 10,
      child: Semantics(
        image: true,
        label: l10n.desktopUploadDesktopSemantic(submission.sourceWidth, submission.sourceHeight),
        onTap: openFull,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: openFull,
          child: _image(context, submission.thumbUrl),
        ),
      ),
    );
    if (stacked) {
      return Column(
        children: <Widget>[
          SizedBox(width: 140, child: phone),
          const SizedBox(height: PrismSpace.sm),
          desktop,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(flex: 2, child: phone),
        const SizedBox(width: PrismSpace.sm),
        Expanded(flex: 5, child: desktop),
      ],
    );
  }

  Widget _image(BuildContext context, String url) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    Widget missing() => ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(child: Icon(Icons.image_not_supported_outlined, color: cs.onSurface.withValues(alpha: 0.5))),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(PrismRadius.sm),
      child: url.isEmpty
          ? missing()
          : CachedNetworkImage(
              cacheManager: PrismImageCache.instance,
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, _) => ColoredBox(color: cs.surfaceContainerHighest),
              errorWidget: (_, _, _) => missing(),
            ),
    );
  }
}
